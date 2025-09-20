import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - DJ Chat Service

@MainActor
class DJChatService: ObservableObject {
    
    static let shared = DJChatService()
    
    // MARK: - Published Properties
    
    @Published var messages: [DJChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var onlineUsers: [DJChatUser] = []
    @Published var userCount = 0
    
    // MARK: - Models
    
    struct DJChatMessage: Codable, Identifiable, Equatable {
        let id: String
        let streamId: String
        let userId: String
        let username: String
        let userProfileImage: String?
        let message: String
        let timestamp: Date
        let messageType: MessageType
        
        enum MessageType: String, Codable {
            case user = "user"
            case system = "system"
            case djAnnouncement = "dj_announcement"
        }
        
        enum CodingKeys: String, CodingKey {
            case id, streamId, userId, username, userProfileImage, message, timestamp, messageType
        }
        
        static func == (lhs: DJChatMessage, rhs: DJChatMessage) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    struct DJChatUser: Codable, Identifiable {
        let id: String
        let username: String
        let profileImage: String?
        let joinedAt: Date
        let isDJ: Bool
        
        enum CodingKeys: String, CodingKey {
            case id, username, profileImage, joinedAt, isDJ
        }
    }
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var messagesListener: ListenerRegistration?
    private var usersListener: ListenerRegistration?
    private var currentStreamId: String?
    private var currentUser: User? {
        return Auth.auth().currentUser
    }
    
    private init() {}
    
    deinit {
        // Clean up listeners
        messagesListener?.remove()
        usersListener?.remove()
    }
    
    // MARK: - Public Methods
    
    func joinChat(streamId: String, isDJ: Bool) async {
        guard let user = currentUser else {
            print("❌ No authenticated user for DJ chat")
            return
        }
        
        self.currentStreamId = streamId
        
        // Add user to chat participants
        await addUserToChat(streamId: streamId, user: user, isDJ: isDJ)
        
        // Start listening for messages
        startMessagesListener(streamId: streamId)
        
        // Start listening for online users
        startUsersListener(streamId: streamId)
        
        print("✅ Joined DJ chat: \(streamId)")
    }
    
    func leaveChat() {
        guard let streamId = currentStreamId,
              let user = currentUser else { return }
        
        // Remove listeners
        messagesListener?.remove()
        usersListener?.remove()
        messagesListener = nil
        usersListener = nil
        
        // Remove user from chat participants
        Task {
            do {
                try await db.collection("djChatUsers")
                    .document("\(streamId)_\(user.uid)")
                    .delete()
                
                print("✅ Left DJ chat: \(streamId)")
            } catch {
                print("❌ Failed to leave DJ chat: \(error)")
            }
        }
        
        // Clear local state
        currentStreamId = nil
        messages.removeAll()
        onlineUsers.removeAll()
        userCount = 0
    }
    
    func sendMessage(_ text: String, messageType: DJChatMessage.MessageType = .user) async {
        guard let user = currentUser,
              let streamId = currentStreamId else {
            print("❌ Cannot send message: No user or stream")
            return
        }
        
        let messageData: [String: Any] = [
            "id": UUID().uuidString,
            "streamId": streamId,
            "userId": user.uid,
            "username": user.displayName ?? "Anonymous",
            "userProfileImage": user.photoURL?.absoluteString ?? "",
            "message": text,
            "timestamp": Timestamp(),
            "messageType": messageType.rawValue
        ]
        
        do {
            try await db.collection("djChatMessages").addDocument(data: messageData)
            print("✅ DJ chat message sent")
        } catch {
            print("❌ Failed to send DJ chat message: \(error)")
            errorMessage = "Failed to send message"
        }
    }
    
    func sendDJAnnouncement(_ text: String) async {
        await sendMessage(text, messageType: .djAnnouncement)
    }
    
    // MARK: - Private Methods
    
    private func addUserToChat(streamId: String, user: User, isDJ: Bool) async {
        let userData: [String: Any] = [
            "id": user.uid,
            "username": user.displayName ?? "Anonymous",
            "profileImage": user.photoURL?.absoluteString ?? "",
            "joinedAt": Timestamp(),
            "isDJ": isDJ,
            "lastSeen": Timestamp()
        ]
        
        do {
            try await db.collection("djChatUsers")
                .document("\(streamId)_\(user.uid)")
                .setData(userData)
            
            // Send system message
            await sendMessage("\(user.displayName ?? "Someone") joined the chat", messageType: .system)
            
            print("✅ Added user to DJ chat: \(user.uid)")
        } catch {
            print("❌ Failed to add user to DJ chat: \(error)")
        }
    }
    
    private func startMessagesListener(streamId: String) {
        messagesListener?.remove()
        
        messagesListener = db.collection("djChatMessages")
            .whereField("streamId", isEqualTo: streamId)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ DJ chat messages listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let newMessages = documents.compactMap { doc -> DJChatMessage? in
                    return try? doc.data(as: DJChatMessage.self)
                }
                .sorted { $0.timestamp < $1.timestamp }
                
                Task { @MainActor in
                    self.messages = newMessages
                    print("🎯 Loaded \(newMessages.count) DJ chat messages")
                }
            }
    }
    
    private func startUsersListener(streamId: String) {
        usersListener?.remove()
        
        usersListener = db.collection("djChatUsers")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ DJ chat users listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let users = documents.compactMap { doc -> DJChatUser? in
                    guard doc.documentID.hasPrefix("\(streamId)_") else { return nil }
                    return try? doc.data(as: DJChatUser.self)
                }
                
                Task { @MainActor in
                    self.onlineUsers = users
                    self.userCount = users.count
                }
            }
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    func isCurrentUserDJ() -> Bool {
        guard let user = currentUser else { return false }
        return onlineUsers.first(where: { $0.id == user.uid })?.isDJ == true
    }
    
    func getCurrentUsername() -> String {
        return currentUser?.displayName ?? "Anonymous"
    }
}