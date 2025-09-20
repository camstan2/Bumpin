import Foundation
import FirebaseAuth
import FirebaseFirestore

final class DirectMessageService {
    static let shared = DirectMessageService()
    private init() {}
    private var db: Firestore { Firestore.firestore() }

    private func isMutual(a: UserProfile, b: UserProfile) -> Bool {
        let aFollowsB = a.following?.contains(b.uid) ?? false
        let bFollowsA = b.followers?.contains(a.uid) ?? false
        return aFollowsB && bFollowsA
    }

    func getOrCreateConversation(with otherUserId: String, completion: @escaping (Conversation?, Error?) -> Void) {
        guard let myId = Auth.auth().currentUser?.uid else { completion(nil, NSError(domain: "auth", code: 401)); return }
        let key = Conversation.makeParticipantKey([myId, otherUserId])
        db.collection("conversations").whereField("participantKey", isEqualTo: key).limit(to: 1).getDocuments { snap, err in
            if let err = err { completion(nil, err); return }
            if let doc = snap?.documents.first, let existing = try? doc.data(as: Conversation.self) {
                completion(existing, nil)
                return
            }
            // Create
            let users = self.db.collection("users")
            users.document(myId).getDocument { meDoc, _ in
                users.document(otherUserId).getDocument { otherDoc, _ in
                    let me = try? meDoc?.data(as: UserProfile.self)
                    let other = try? otherDoc?.data(as: UserProfile.self)
                    let mutual = (me != nil && other != nil) ? self.isMutual(a: me!, b: other!) : false
                    let convo = Conversation(
                        id: UUID().uuidString,
                        participantIds: [myId, otherUserId],
                        participantKey: key,
                        inboxFor: mutual ? [myId, otherUserId] : [myId],
                        requestFor: mutual ? [] : [otherUserId],
                        lastMessage: nil,
                        lastTimestamp: nil,
                        lastReadAtByUser: [:]
                    )
                    do {
                        try self.db.collection("conversations").document(convo.id).setData(from: convo) { writeErr in
                            completion(writeErr == nil ? convo : nil, writeErr)
                        }
                    } catch {
                        completion(nil, error)
                    }
                }
            }
        }
    }

    func sendMessage(conversationId: String, text: String, completion: @escaping (Error?) -> Void) {
        guard let myId = Auth.auth().currentUser?.uid else { completion(NSError(domain: "auth", code: 401)); return }
        let msg = DirectMessage(id: UUID().uuidString, conversationId: conversationId, senderId: myId, text: text, createdAt: Date(), isSystem: nil, readBy: [myId])
        let convoRef = db.collection("conversations").document(conversationId)
        do {
            try convoRef.collection("messages").document(msg.id).setData(from: msg) { err in
                if let err = err { completion(err); return }
                convoRef.updateData([
                    "lastMessage": text,
                    "lastTimestamp": FieldValue.serverTimestamp()
                ]) { metaErr in
                    completion(metaErr)
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
        // Remove user from requestFor and inboxFor so it no longer appears in their lists
        let ref = db.collection("conversations").document(conversationId)
        ref.updateData([
            "requestFor": FieldValue.arrayRemove([userId]),
            "inboxFor": FieldValue.arrayRemove([userId])
        ], completion: completion)
    }

    func observeInbox(for userId: String? = Auth.auth().currentUser?.uid, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration? {
        guard let uid = userId else { return nil }
        let q = db.collection("conversations").whereField("inboxFor", arrayContains: uid).order(by: "lastTimestamp", descending: true)
        return q.addSnapshotListener { snap, _ in
            let items = snap?.documents.compactMap { try? $0.data(as: Conversation.self) } ?? []
            onChange(items)
        }
    }

    func observeRequests(for userId: String? = Auth.auth().currentUser?.uid, onChange: @escaping ([Conversation]) -> Void) -> ListenerRegistration? {
        guard let uid = userId else { return nil }
        let q = db.collection("conversations").whereField("requestFor", arrayContains: uid).order(by: "lastTimestamp", descending: true)
        return q.addSnapshotListener { snap, _ in
            let items = snap?.documents.compactMap { try? $0.data(as: Conversation.self) } ?? []
            onChange(items)
        }
    }

    func observeMessages(conversationId: String, limit: Int = 50, onChange: @escaping ([DirectMessage]) -> Void) -> ListenerRegistration {
        let q = db.collection("conversations").document(conversationId).collection("messages").order(by: "createdAt", descending: false).limit(to: limit)
        return q.addSnapshotListener { snap, _ in
            let msgs = snap?.documents.compactMap { try? $0.data(as: DirectMessage.self) } ?? []
            onChange(msgs)
        }
    }

    func fetchMoreMessages(conversationId: String, after message: DirectMessage?, limit: Int = 50, completion: @escaping ([DirectMessage], Error?) -> Void) {
        var q: Query = db.collection("conversations").document(conversationId).collection("messages").order(by: "createdAt", descending: false).limit(to: limit)
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
                // Optional: ignore stale updates (older than ~10s) if needed
                return typing
            }
            onChange(someoneElseTyping)
        }
    }
}