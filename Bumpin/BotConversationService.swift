import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Bot Conversation Service

@MainActor
class BotConversationService: ObservableObject {
    
    static let shared = BotConversationService()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // MARK: - Conversation Management
    
    /// Get or create a conversation with a matched user from a bot message
    func startConversationWithMatch(matchData: MatchmakingMessageData) async throws -> Conversation? {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw BotConversationError.userNotAuthenticated
        }
        
        // Check if conversation already exists
        let existingConversation = try await findExistingConversation(
            userId1: currentUserId,
            userId2: matchData.matchedUserId
        )
        
        if let existing = existingConversation {
            return existing
        }
        
        // Create new conversation
        return try await createNewConversation(
            currentUserId: currentUserId,
            matchedUserId: matchData.matchedUserId,
            matchData: matchData
        )
    }
    
    /// Track when user responds to a match
    func trackMatchResponse(matchData: MatchmakingMessageData) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Update the weekly match record
        let matchId = "\(currentUserId)_\(matchData.matchedUserId)_\(matchData.weekId)"
        
        let updates: [String: Any] = [
            "userResponded": true,
            "responseTimestamp": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("weeklyMatches").document(matchId).updateData(updates)
            print("✅ Tracked match response for \(matchId)")
        } catch {
            print("❌ Error tracking match response: \(error.localizedDescription)")
        }
    }
    
    /// Track successful connection (when users start messaging)
    func trackMatchSuccess(matchData: MatchmakingMessageData) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let matchId = "\(currentUserId)_\(matchData.matchedUserId)_\(matchData.weekId)"
        
        let updates: [String: Any] = [
            "matchSuccess": true,
            "connectionQuality": "connection"
        ]
        
        do {
            try await db.collection("weeklyMatches").document(matchId).updateData(updates)
            print("✅ Tracked match success for \(matchId)")
        } catch {
            print("❌ Error tracking match success: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func findExistingConversation(userId1: String, userId2: String) async throws -> Conversation? {
        let participantKey = Conversation.makeParticipantKey([userId1, userId2])
        
        let snapshot = try await db.collection("conversations")
            .whereField("participantKey", isEqualTo: participantKey)
            .limit(to: 1)
            .getDocuments()

        if let doc = snapshot.documents.first {
            return try doc.data(as: Conversation.self)
        }
        return nil
    }
    
    private func createNewConversation(
        currentUserId: String,
        matchedUserId: String,
        matchData: MatchmakingMessageData
    ) async throws -> Conversation {
        
        let conversationId = UUID().uuidString
        let participantKey = Conversation.makeParticipantKey([currentUserId, matchedUserId])
        
        let conversation = Conversation(
            id: conversationId,
            participantIds: [currentUserId, matchedUserId],
            participantKey: participantKey,
            inboxFor: [currentUserId, matchedUserId],
            requestFor: [],
            lastMessage: "Started from music match",
            lastTimestamp: Date(),
            conversationType: .matchmaking
        )
        
        // Save conversation to Firestore
        try await db.collection("conversations").document(conversationId).setData(from: conversation)
        
        // Send initial system message
        try await sendInitialMatchMessage(
            conversationId: conversationId,
            currentUserId: currentUserId,
            matchData: matchData
        )
        
        print("✅ Created new matchmaking conversation: \(conversationId)")
        return conversation
    }
    
    private func sendInitialMatchMessage(
        conversationId: String,
        currentUserId: String,
        matchData: MatchmakingMessageData
    ) async throws {
        
        let messageText = "You both love \(matchData.sharedArtists.prefix(2).joined(separator: " and "))! Start the conversation 🎵"
        
        let message = DirectMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: currentUserId,
            text: messageText,
            createdAt: Date(),
            isSystem: true,
            messageType: .system
        )
        
        try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(message.id)
            .setData(from: message)
        
        // Update conversation last message
        let conversationUpdates: [String: Any] = [
            "lastMessage": messageText,
            "lastTimestamp": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("conversations")
            .document(conversationId)
            .updateData(conversationUpdates)
    }
    
    // MARK: - Bot Message Handling
    
    /// Handle actions from bot matchmaking messages
    func handleMatchAction(_ action: MatchAction, matchData: MatchmakingMessageData) async {
        switch action {
        case .viewProfile:
            // This will be handled by the UI
            print("📱 Viewing profile for \(matchData.matchedUserId)")
            
        case .startConversation:
            do {
                await trackMatchResponse(matchData: matchData)
                let conversation = try await startConversationWithMatch(matchData: matchData)
                if conversation != nil {
                    await trackMatchSuccess(matchData: matchData)
                }
            } catch {
                print("❌ Error starting conversation: \(error.localizedDescription)")
            }
            
        case .dismiss:
            print("🚫 User dismissed match")
        }
    }
}

// MARK: - Supporting Types

enum MatchAction {
    case viewProfile
    case startConversation  
    case dismiss
}

enum BotConversationError: Error, LocalizedError {
    case userNotAuthenticated
    case conversationCreationFailed
    case messageDeliveryFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .conversationCreationFailed:
            return "Failed to create conversation"
        case .messageDeliveryFailed:
            return "Failed to deliver message"
        }
    }
}

// MARK: - Extensions

extension BotConversationService {
    
    /// Get all bot conversations for the current user
    func getBotConversations() async throws -> [Conversation] {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw BotConversationError.userNotAuthenticated
        }
        
        let snapshot = try await db.collection("conversations")
            .whereField("participantIds", arrayContains: currentUserId)
            .whereField("conversationType", isEqualTo: "bot")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Conversation.self)
        }
    }
    
    /// Check if a conversation is a matchmaking conversation
    func isMatchmakingConversation(_ conversation: Conversation) -> Bool {
        return conversation.conversationType == .matchmaking || 
               conversation.conversationType == .bot ||
               conversation.isBotConversation
    }
    
    /// Get match context for a conversation if it exists
    func getMatchContext(for conversation: Conversation) async -> MatchmakingMessageData? {
        // Look for the most recent bot matchmaking message in this conversation
        do {
            let snapshot = try await db.collection("conversations")
                .document(conversation.id)
                .collection("messages")
                .whereField("messageType", isEqualTo: "bot_matchmaking")
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            if let messageDoc = snapshot.documents.first,
               let message = try? messageDoc.data(as: DirectMessage.self) {
                return message.matchmakingData
            }
        } catch {
            print("❌ Error getting match context: \(error.localizedDescription)")
        }
        
        return nil
    }
}
