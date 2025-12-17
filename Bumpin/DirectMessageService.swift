import Foundation
import FirebaseAuth
import FirebaseFirestore

final class DirectMessageService {
    static let shared = DirectMessageService()
    private init() {}
    private var db: Firestore { Firestore.firestore() }
    
    private enum DMError: LocalizedError {
        case unauthenticated
        
        var errorDescription: String? {
            switch self {
            case .unauthenticated: return "You must be signed in to send messages."
            }
        }
    }
    
    // MARK: - Conversation Management
    
    func getOrCreateConversation(with otherUserId: String, completion: @escaping (Conversation?, Error?) -> Void) {
        getOrCreateConversation(with: [otherUserId], groupName: nil, completion: completion)
    }
    
    func getOrCreateConversation(with participantIds: [String], groupName: String? = nil, completion: @escaping (Conversation?, Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(nil, DMError.unauthenticated)
            return
        }
        
        var uniqueIds = Set(participantIds)
        uniqueIds.remove(currentUserId)
        uniqueIds.insert(currentUserId)
        let participants = Array(uniqueIds)
        
        Task {
            do {
                let conversation = try await self.findOrCreateConversation(
                    participantIds: participants,
                    groupName: groupName,
                    initiator: currentUserId
                )
                completion(conversation, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    private func findOrCreateConversation(participantIds: [String], groupName: String?, initiator: String) async throws -> Conversation {
        let sortedIds = participantIds.sorted()
        let participantKey = Conversation.makeParticipantKey(sortedIds)
        
        // For 1:1 conversations, try to find an existing one
        if sortedIds.count == 2 {
            do {
                let snapshot = try await db.collection("conversations")
                    .whereField("participantKey", isEqualTo: participantKey)
                    .limit(to: 1)
                    .getDocuments()
                if let existing = snapshot.documents.compactMap({ try? $0.data(as: Conversation.self) }).first {
                    print("✅ Found existing conversation: \(existing.id)")
                    return existing
                }
            } catch {
                // Query may fail due to Firestore security rules on collection queries
                // This is expected when no conversation exists yet - proceed to create one
                print("⚠️ Could not query existing conversations (expected for new chats): \(error.localizedDescription)")
            }
        }
        
        print("📝 Creating new conversation with participants: \(sortedIds)")
        return try await createConversation(
            participantIds: sortedIds,
            participantKey: participantKey,
            groupName: groupName,
            initiator: initiator
        )
    }
    
    private func createConversation(participantIds: [String],
                                    participantKey: String,
                                    groupName: String?,
                                    initiator: String) async throws -> Conversation {
        let docRef = db.collection("conversations").document()
        let meta = await computeInboxMetadata(initiator: initiator, participantIds: participantIds)
        let type: Conversation.ConversationType = participantIds.count > 2 ? .group : .regular
        
        let name: String?
        if type == .group {
            if let provided = groupName, !provided.isEmpty {
                name = provided
            } else {
                name = await defaultGroupName(participantIds: participantIds, excluding: initiator)
            }
        } else {
            name = nil
        }
        let now = Date()
        
        let conversation = Conversation(
            id: docRef.documentID,
            participantIds: participantIds,
            participantKey: participantKey,
            participantCount: participantIds.count,
            createdBy: initiator,
            groupName: name,
            groupAvatarUrl: nil,
            inboxFor: meta.inbox,
            requestFor: meta.requests,
            lastMessage: nil,
            lastSenderId: nil,
            lastTimestamp: now,
            lastReadAtByUser: [initiator: now],
            conversationType: type
        )
        
        print("📝 Creating conversation document: \(docRef.documentID)")
        print("   Participants: \(participantIds)")
        print("   ParticipantKey: \(participantKey)")
        print("   InboxFor: \(meta.inbox)")
        print("   RequestFor: \(meta.requests)")
        
        do {
            try docRef.setData(from: conversation)
            print("✅ Conversation created successfully: \(docRef.documentID)")
            return conversation
        } catch {
            print("❌ Failed to create conversation: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Messaging
    
    func sendMessage(conversationId: String, text: String, completion: @escaping (Error?) -> Void) {
        guard let myId = Auth.auth().currentUser?.uid else {
            completion(DMError.unauthenticated)
            return
        }
        
        let message = DirectMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: myId,
            text: text,
            createdAt: Date(),
            isSystem: nil,
            readBy: [myId],
            attachments: nil,
            replyToMessageId: nil,
            status: .sent
        )
        
        let convoRef = db.collection("conversations").document(conversationId)
        do {
            try convoRef.collection("messages").document(message.id).setData(from: message) { [weak self] error in
                if let error = error {
                    completion(error)
                    return
                }
                
                convoRef.updateData([
                    "lastMessage": text,
                    "lastSenderId": myId,
                    "lastTimestamp": FieldValue.serverTimestamp(),
                    "lastReadAtByUser.\(myId)": FieldValue.serverTimestamp()
                ]) { metaError in
                    completion(metaError)
                }
                
                Task {
                    await self?.refreshInboxStateIfNeeded(conversationId: conversationId, senderId: myId)
                }
            }
        } catch {
            completion(error)
        }
    }
    
    // Mark messages read up to the newest message for this user
    func markConversationRead(conversationId: String, userId: String, completion: ((Error?) -> Void)? = nil) {
        let convoRef = db.collection("conversations").document(conversationId)
        convoRef.updateData([
            "lastReadAtByUser.\(userId)": FieldValue.serverTimestamp()
        ]) { err in
            completion?(err)
        }
    }
    
    func acceptRequest(conversationId: String, userId: String, completion: @escaping (Error?) -> Void) {
        let ref = db.collection("conversations").document(conversationId)
        ref.updateData([
            "inboxFor": FieldValue.arrayUnion([userId]),
            "requestFor": FieldValue.arrayRemove([userId])
        ], completion: completion)
    }
    
    func declineRequest(conversationId: String, userId: String, completion: @escaping (Error?) -> Void) {
        let ref = db.collection("conversations").document(conversationId)
        ref.updateData([
            "requestFor": FieldValue.arrayRemove([userId]),
            "inboxFor": FieldValue.arrayRemove([userId])
        ], completion: completion)
    }
    
    // MARK: - Observers
    
    func observeInbox(for userId: String? = Auth.auth().currentUser?.uid, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration? {
        guard let uid = userId else { return nil }
        let q = db.collection("conversations")
            .whereField("inboxFor", arrayContains: uid)
            .order(by: "lastTimestamp", descending: true)
        
        return q.addSnapshotListener { [weak self] snap, _ in
            let items = snap?.documents.compactMap { try? $0.data(as: Conversation.self) } ?? []
            if let self {
                onChange(self.deduplicateConversations(items))
            } else {
                onChange(items)
            }
        }
    }
    
    func observeRequests(for userId: String? = Auth.auth().currentUser?.uid, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration? {
        guard let uid = userId else { return nil }
        let q = db.collection("conversations")
            .whereField("requestFor", arrayContains: uid)
            .order(by: "lastTimestamp", descending: true)
        
        return q.addSnapshotListener { [weak self] snap, _ in
            let items = snap?.documents.compactMap { try? $0.data(as: Conversation.self) } ?? []
            if let self {
                onChange(self.deduplicateConversations(items))
            } else {
                onChange(items)
            }
        }
    }
    
    func observeMessages(conversationId: String, limit: Int = 50, onChange: @escaping ([DirectMessage]) -> Void) -> ListenerRegistration {
        let q = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
        
        return q.addSnapshotListener { snap, _ in
            let msgs = snap?.documents.compactMap { try? $0.data(as: DirectMessage.self) } ?? []
            onChange(msgs)
        }
    }
    
    func fetchMoreMessages(conversationId: String, after message: DirectMessage?, limit: Int = 50, completion: @escaping ([DirectMessage], Error?) -> Void) {
        var q: Query = db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
        
        if let message = message {
            q = q.start(after: [message.createdAt])
        }
        
        q.getDocuments { snap, err in
            if let err = err { completion([], err); return }
            let msgs = snap?.documents.compactMap { try? $0.data(as: DirectMessage.self) } ?? []
            completion(msgs, nil)
        }
    }
    
    // MARK: - Typing indicators (presence)
    
    func setTyping(conversationId: String, userId: String, isTyping: Bool) {
        let ref = db.collection("conversations").document(conversationId)
            .collection("presence").document(userId)
        ref.setData([
            "typing": isTyping,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    func observeOtherTyping(conversationId: String, currentUserId: String, onChange: @escaping (Bool) -> Void) -> ListenerRegistration {
        let presence = db.collection("conversations").document(conversationId).collection("presence")
        return presence.addSnapshotListener { snap, _ in
            guard let docs = snap?.documents else { onChange(false); return }
            let someoneElseTyping = docs.contains { doc in
                let uid = doc.documentID
                guard uid != currentUserId else { return false }
                let data = doc.data()
                let typing = data["typing"] as? Bool ?? false
                return typing
            }
            onChange(someoneElseTyping)
        }
    }
    
    // MARK: - Helpers
    
    private func defaultGroupName(participantIds: [String], excluding initiator: String) async -> String {
        let others = participantIds.filter { $0 != initiator }
        var displayNames: [String] = []
        for uid in others.prefix(2) {
            if let profile = await UserProfileCache.shared.getProfile(userId: uid) {
                displayNames.append(profile.displayName)
            }
        }
        
        if displayNames.isEmpty {
            return "Group Chat"
        } else if others.count <= 2 {
            return displayNames.joined(separator: ", ")
        } else {
            let remaining = others.count - displayNames.count
            return "\(displayNames.joined(separator: ", ")), +\(remaining)"
        }
    }
    
    private func computeInboxMetadata(initiator: String, participantIds: [String]) async -> (inbox: [String], requests: [String]) {
        var inbox = Set<String>([initiator])
        var requests = Set<String>()
        
        await withTaskGroup(of: (String, Bool).self) { group in
            for uid in participantIds where uid != initiator {
                group.addTask {
                    let mutual = await self.areMutualFollowers(uid, initiator: initiator)
                    return (uid, mutual)
                }
            }
            
            for await result in group {
                if result.1 {
                    inbox.insert(result.0)
                } else {
                    requests.insert(result.0)
                }
            }
        }
        
        return (Array(inbox), Array(requests))
    }
    
    private func areMutualFollowers(_ userId: String, initiator: String) async -> Bool {
        async let initiatorFollows = user(initiator, follows: userId)
        async let userFollowsInitiator = user(userId, follows: initiator)
        let results = await (initiatorFollows, userFollowsInitiator)
        return results.0 && results.1
    }
    
    private func user(_ userId: String, follows otherId: String) async -> Bool {
        do {
            let doc = try await db.collection("users").document(userId).collection("following").document(otherId).getDocument()
            if doc.exists { return true }
            
            let fallback = try await db.collection("users").document(userId).getDocument()
            if let profile = try? fallback.data(as: UserProfile.self), let following = profile.following {
                return following.contains(otherId)
            }
            if let data = fallback.data(), let inline = data["following"] as? [String] {
                return inline.contains(otherId)
            }
            return false
        } catch {
            print("Follow lookup failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func refreshInboxStateIfNeeded(conversationId: String, senderId: String) async {
        do {
            let snapshot = try await db.collection("conversations").document(conversationId).getDocument()
            guard var conversation = try? snapshot.data(as: Conversation.self) else { return }
            conversation.id = snapshot.documentID
            
            var inboxAdds: [String] = []
            var requestAdds: [String] = []
            var requestRemovals: [String] = []
            
            for participant in conversation.participantIds where participant != senderId {
                let mutual = await areMutualFollowers(participant, initiator: senderId)
                if mutual {
                    if !conversation.inboxFor.contains(participant) {
                        inboxAdds.append(participant)
                    }
                    if conversation.requestFor.contains(participant) {
                        requestRemovals.append(participant)
                    }
                } else if !conversation.requestFor.contains(participant) && !conversation.inboxFor.contains(participant) {
                    requestAdds.append(participant)
                }
            }
            
            var updates: [String: Any] = [:]
            if !inboxAdds.isEmpty {
                updates["inboxFor"] = FieldValue.arrayUnion(inboxAdds)
            }
            if !requestAdds.isEmpty {
                updates["requestFor"] = FieldValue.arrayUnion(requestAdds)
            }
            
            if !updates.isEmpty {
                try await db.collection("conversations").document(conversationId).updateData(updates)
            }
            if !requestRemovals.isEmpty {
                try await db.collection("conversations").document(conversationId).updateData([
                    "requestFor": FieldValue.arrayRemove(requestRemovals)
                ])
            }
        } catch {
            print("refreshInboxState error: \(error.localizedDescription)")
        }
    }
    
    private func selectMostRecentConversation(from conversations: [Conversation]) -> Conversation? {
        conversations
            .sorted { ($0.lastTimestamp ?? Date.distantPast) > ($1.lastTimestamp ?? Date.distantPast) }
            .first
    }
    
    private func deduplicateConversations(_ conversations: [Conversation]) -> [Conversation] {
        var bestByKey: [String: Conversation] = [:]
        
        for conversation in conversations {
            let key = normalizedParticipantKey(for: conversation)
            if let existing = bestByKey[key] {
                let existingDate = existing.lastTimestamp ?? Date.distantPast
                let newDate = conversation.lastTimestamp ?? Date.distantPast
                if newDate > existingDate {
                    bestByKey[key] = conversation
                }
            } else {
                bestByKey[key] = conversation
            }
        }
        
        return bestByKey.values.sorted {
            ($0.lastTimestamp ?? Date.distantPast) > ($1.lastTimestamp ?? Date.distantPast)
        }
    }
    
    private func normalizedParticipantKey(for conversation: Conversation) -> String {
        if !conversation.participantKey.isEmpty {
            return conversation.participantKey
        }
        return Conversation.makeParticipantKey(conversation.participantIds)
    }
}