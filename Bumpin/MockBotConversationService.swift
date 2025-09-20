import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Mock Bot Conversation Service

@MainActor
class MockBotConversationService: ObservableObject {
    
    static let shared = MockBotConversationService()
    private init() {}
    
    private let db = Firestore.firestore()
    
    /// Create a mock bot conversation for demonstration purposes
    func createMockBotConversation() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated")
            return
        }
        
        print("🎭 Creating mock bot conversation for demo...")
        
        do {
            // Create bot conversation
            let conversationId = "mock_bot_\(currentUserId)"
            let botUserId = MatchmakingBotService.botUserId
            
            let conversation = Conversation(
                id: conversationId,
                participantIds: [currentUserId, botUserId],
                participantKey: Conversation.makeParticipantKey([currentUserId, botUserId]),
                inboxFor: [currentUserId],
                requestFor: [],
                lastMessage: "🎵 You've got a new music match! Meet Alex...",
                lastTimestamp: Date(),
                conversationType: .bot
            )
            
            // Save conversation to Firestore
            try await db.collection("conversations").document(conversationId).setData(from: conversation)
            
            // Create welcome message
            await createMockWelcomeMessage(conversationId: conversationId, botUserId: botUserId)
            
            // Create matchmaking message with rich data
            await createMockMatchMessage(conversationId: conversationId, botUserId: botUserId)
            
            print("✅ Mock bot conversation created successfully!")
            
        } catch {
            print("❌ Error creating mock conversation: \(error.localizedDescription)")
        }
    }
    
    /// Remove mock bot conversation
    func removeMockBotConversation() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let conversationId = "mock_bot_\(currentUserId)"
        
        do {
            // Delete all messages in the conversation
            let messagesSnapshot = try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .getDocuments()
            
            for messageDoc in messagesSnapshot.documents {
                try await messageDoc.reference.delete()
            }
            
            // Delete the conversation
            try await db.collection("conversations").document(conversationId).delete()
            
            print("✅ Mock bot conversation removed")
            
        } catch {
            print("❌ Error removing mock conversation: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Mock Message Creation
    
    private func createMockWelcomeMessage(conversationId: String, botUserId: String) async {
        let welcomeMessage = DirectMessage(
            id: "welcome_\(conversationId)",
            conversationId: conversationId,
            senderId: botUserId,
            text: "👋 Welcome to Music Matchmaking! I help connect people through their shared love of music. Your first match is coming up!",
            createdAt: Date().addingTimeInterval(-300), // 5 minutes ago
            isSystem: false,
            messageType: .botWelcome
        )
        
        do {
            try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(welcomeMessage.id)
                .setData(from: welcomeMessage)
        } catch {
            print("❌ Error creating welcome message: \(error.localizedDescription)")
        }
    }
    
    private func createMockMatchMessage(conversationId: String, botUserId: String) async {
        let matchData = MatchmakingMessageData(
            matchedUserId: "mock_user_alex",
            matchedUsername: "alexmusic",
            matchedDisplayName: "Alex Johnson",
            matchedProfileImageUrl: nil,
            sharedArtists: ["Taylor Swift", "The Weeknd", "Billie Eilish"],
            sharedGenres: ["Pop", "Alternative", "R&B"],
            similarityScore: 0.87,
            weekId: getCurrentWeekId()
        )
        
        let matchMessage = DirectMessage(
            id: "match_\(conversationId)",
            conversationId: conversationId,
            senderId: botUserId,
            text: "🎵 You've got a new music match! Meet Alex - you both love Taylor Swift and The Weeknd. Your compatibility: 87%",
            createdAt: Date(),
            isSystem: false,
            messageType: .botMatchmaking,
            matchmakingData: matchData
        )
        
        do {
            try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(matchMessage.id)
                .setData(from: matchMessage)
            
            // Update conversation last message
            try await db.collection("conversations")
                .document(conversationId)
                .updateData([
                    "lastMessage": matchMessage.text,
                    "lastTimestamp": FieldValue.serverTimestamp()
                ])
                
        } catch {
            print("❌ Error creating match message: \(error.localizedDescription)")
        }
    }
    
    private func getCurrentWeekId() -> String {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.yearForWeekOfYear, from: now)
        let week = calendar.component(.weekOfYear, from: now)
        return String(format: "%d-W%02d", year, week)
    }
    
    /// Check if mock conversation already exists
    func mockConversationExists() async -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        
        let conversationId = "mock_bot_\(currentUserId)"
        
        do {
            let doc = try await db.collection("conversations").document(conversationId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }
}
