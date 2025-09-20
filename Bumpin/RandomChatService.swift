import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class RandomChatService: ObservableObject {
    static let shared = RandomChatService()
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    // Published properties for real-time updates
    @Published var currentQueueRequest: QueueRequest?
    @Published var queueStatus: QueueStatus = .waiting
    @Published var matchedChat: TopicChat?
    @Published var error: Error?
    
    // Stats
    @Published var activeChatsCount: Int = 0
    @Published var queuedUsersCount: Int = 0
    @Published var averageWaitTime: Int = 0
    
    private init() {
        // Start listening to stats
        setupStatsListeners()
    }
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - Queue Management
    
    func joinQueue(groupSize: Int = 1, genderPreference: GenderPreference = .any) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ RandomChatService: User not authenticated")
            throw RandomChatError.notAuthenticated
        }
        
        print("✅ RandomChatService: Joining queue for user \(currentUser.uid)")
        
        // Create queue request
        let request = QueueRequest(
            userId: currentUser.uid,
            userName: currentUser.displayName ?? "Anonymous",
            groupSize: groupSize,
            genderPreference: genderPreference
        )
        
        print("📝 RandomChatService: Created queue request \(request.id)")
        
        // Add to queue collection
        do {
            try await db.collection("randomChatQueue").document(request.id).setData([
                "id": request.id,
                "userId": request.userId,
                "userName": request.userName,
                "groupSize": request.groupSize,
                "genderPreference": request.genderPreference?.rawValue ?? "any",
                "timestamp": FieldValue.serverTimestamp(),
                "groupMembers": request.groupMembers,
                "status": QueueStatus.waiting.rawValue
            ])
            
            print("✅ RandomChatService: Successfully added to queue")
            
            // Start listening for updates
            listenToQueueRequest(request.id)
        } catch {
            print("❌ RandomChatService: Failed to join queue: \(error)")
            throw error
        }
    }
    
    func leaveQueue() async throws {
        guard let requestId = currentQueueRequest?.id else { return }
        
        // Remove from queue
        try await db.collection("randomChatQueue").document(requestId).delete()
        
        // Clean up
        currentQueueRequest = nil
        queueStatus = .waiting
        removeAllListeners()
    }
    
    // MARK: - Group Management
    
    func inviteFriend(_ friendId: String) async throws {
        guard let request = currentQueueRequest else {
            throw RandomChatError.notInQueue
        }
        
        // Create invitation
        try await db.collection("randomChatInvites").document().setData([
            "queueRequestId": request.id,
            "fromUserId": request.userId,
            "toUserId": friendId,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "pending"
        ])
    }
    
    func acceptInvitation(_ inviteId: String) async throws {
        let inviteRef = db.collection("randomChatInvites").document(inviteId)
        let queueRef = db.collection("randomChatQueue")
        
        try await db.runTransaction { transaction, errorPointer in
            do {
                // Get invitation
                let inviteDoc = try transaction.getDocument(inviteRef)
                guard let invite = inviteDoc.data(),
                      let queueRequestId = invite["queueRequestId"] as? String else {
                    errorPointer?.pointee = NSError(domain: "RandomChatError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid invitation"])
                    return nil
                }
                
                // Get queue request
                let queueDoc = try transaction.getDocument(queueRef.document(queueRequestId))
                guard var request = try? Firestore.Decoder().decode(QueueRequest.self, from: queueDoc.data() ?? [:]) else {
                    errorPointer?.pointee = NSError(domain: "RandomChatError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid queue request"])
                    return nil
                }
                
                // Update group members
                if !request.groupMembers.contains(Auth.auth().currentUser?.uid ?? "") {
                    request.groupMembers.append(Auth.auth().currentUser?.uid ?? "")
                }
                
                // Update documents
                transaction.updateData([
                    "groupMembers": request.groupMembers
                ], forDocument: queueRef.document(queueRequestId))
                
                transaction.updateData([
                    "status": "accepted"
                ], forDocument: inviteRef)
                
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
    
    // MARK: - Listeners
    
    private func listenToQueueRequest(_ requestId: String) {
        let listener = db.collection("randomChatQueue").document(requestId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = error
                    return
                }
                
                guard let data = snapshot?.data(),
                      let request = try? Firestore.Decoder().decode(QueueRequest.self, from: data) else {
                    self?.error = RandomChatError.invalidQueueRequest
                    return
                }
                
                self?.currentQueueRequest = request
                self?.queueStatus = request.status
                
                // If matched, fetch the chat details
                if request.status == .matched {
                    if let chatId = data["matchedChatId"] as? String {
                        Task {
                            await self?.fetchMatchedChat(chatId)
                        }
                    }
                }
            }
        
        listeners.append(listener)
    }
    
    private func fetchMatchedChat(_ chatId: String) async {
        do {
            let doc = try await db.collection("randomChats").document(chatId).getDocument()
            if let data = doc.data(),
               let chat = try? Firestore.Decoder().decode(TopicChat.self, from: data) {
                await MainActor.run {
                    self.matchedChat = chat
                }
            }
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Chat Management
    
    func updateCurrentDiscussion(chatId: String, topic: String) async throws {
        let ref = db.collection("randomChats").document(chatId)
        try await ref.updateData([
            "currentDiscussion": topic,
            "lastUpdated": FieldValue.serverTimestamp()
        ])
    }
    
    func leaveRandomChat(chatId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw RandomChatError.notAuthenticated
        }
        
        let ref = db.collection("randomChats").document(chatId)
        let doc = try await ref.getDocument()
        
        guard var chat = try? Firestore.Decoder().decode(TopicChat.self, from: doc.data() ?? [:]) else {
            throw RandomChatError.invalidQueueRequest
        }
        
        // Remove user from participants, speakers, and listeners
        chat.participants.removeAll { $0.id == userId }
        chat.speakers.removeAll { $0 == userId }
        chat.listeners.removeAll { $0 == userId }
        
        // If no participants left, mark chat as inactive
        let isActive = !chat.participants.isEmpty
        
        try await ref.updateData([
            "participants": chat.participants.map { ["id": $0.id, "name": $0.name, "isHost": $0.isHost] },
            "speakers": chat.speakers,
            "listeners": chat.listeners,
            "isActive": isActive,
            "lastUpdated": FieldValue.serverTimestamp()
        ])
        
        // End social interaction tracking
        await SocialInteractionTracker.shared.endRandomChatInteraction(chatId: chatId)
    }
    
    private func setupStatsListeners() {
        // Listen for active chats count
        let activeChatsListener = db.collection("randomChats")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.activeChatsCount = snapshot?.documents.count ?? 0
            }
        
        // Listen for queued users count
        let queuedUsersListener = db.collection("randomChatQueue")
            .whereField("status", isEqualTo: QueueStatus.waiting.rawValue)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.queuedUsersCount = snapshot?.documents.count ?? 0
            }
        
        listeners.append(contentsOf: [activeChatsListener, queuedUsersListener])
        
        // Calculate average wait time
        calculateAverageWaitTime()
    }
    
    private func calculateAverageWaitTime() {
        // Get completed matches from last hour
        let oneHourAgo = Date().addingTimeInterval(-3600)
        
        db.collection("randomChats")
            .whereField("createdAt", isGreaterThan: oneHourAgo)
            .whereField("queueTime", isGreaterThan: 0)
            .getDocuments { [weak self] snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                
                let totalTime = documents.compactMap { doc -> Int? in
                    return doc.data()["queueTime"] as? Int
                }.reduce(0, +)
                
                self?.averageWaitTime = documents.isEmpty ? 0 : totalTime / documents.count
            }
    }
    
    private func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// MARK: - Errors
enum RandomChatError: LocalizedError {
    case notAuthenticated
    case notInQueue
    case invalidInvitation
    case invalidQueueRequest
    case matchingFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to use random chat"
        case .notInQueue:
            return "You are not currently in the queue"
        case .invalidInvitation:
            return "The invitation is invalid or expired"
        case .invalidQueueRequest:
            return "Invalid queue request"
        case .matchingFailed:
            return "Failed to find a match. Please try again"
        }
    }
}
