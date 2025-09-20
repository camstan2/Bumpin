import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Matchmaking Bot Service

@MainActor
class MatchmakingBotService: ObservableObject {
    
    static let shared = MatchmakingBotService()
    
    // MARK: - Bot Configuration
    
    static let botUserId = "matchmaking_bot_system"
    static let botUsername = "Bumpin Matchmaker"
    static let botDisplayName = "🎵 Bumpin Matchmaker"
    
    // MARK: - Published Properties
    
    @Published var isProcessingMatches = false
    @Published var lastMatchingRun: Date?
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    
    private init() {
        // Ensure bot user exists in database
        Task {
            await ensureBotUserExists()
        }
    }
    
    // MARK: - Bot User Management
    
    /// Ensures the bot user account exists in Firestore
    private func ensureBotUserExists() async {
        do {
            let botRef = db.collection("users").document(Self.botUserId)
            let snapshot = try await botRef.getDocument()
            
            if !snapshot.exists {
                // Create bot user profile
                let botProfile: [String: Any] = [
                    "uid": Self.botUserId,
                    "email": "bot@bumpin.app",
                    "username": Self.botUsername,
                    "username_lower": Self.botUsername.lowercased(),
                    "displayName": Self.botDisplayName,
                    "displayName_lower": Self.botDisplayName.lowercased(),
                    "bio": "Your weekly music matchmaker! I connect you with people who share your music taste every Thursday at 1PM.",
                    "profilePictureUrl": "", // Could add a bot avatar URL
                    "createdAt": FieldValue.serverTimestamp(),
                    "followers": [],
                    "following": [],
                    "isVerified": true,
                    "roles": ["bot", "system"],
                    "isBot": true
                ]
                
                try await botRef.setData(botProfile)
                print("✅ Created matchmaking bot user account")
            }
        } catch {
            print("❌ Error ensuring bot user exists: \(error.localizedDescription)")
            self.errorMessage = "Failed to initialize bot system"
        }
    }
    
    // MARK: - Bot Messaging
    
    /// Send a matchmaking message from the bot to a user
    func sendMatchmakingMessage(to userId: String, matchedUser: UserProfile, sharedInterests: [String], completion: @escaping (Error?) -> Void) {
        Task {
            do {
                // Get or create conversation with the bot
                let conversation = try await getOrCreateBotConversation(with: userId)
                
                // Generate personalized message
                let message = generateMatchMessage(for: matchedUser, with: sharedInterests)
                
                // Send the message
                try await sendBotMessage(conversationId: conversation.id, text: message)
                
                // Log the match in our tracking system
                try await logMatch(userId: userId, matchedUserId: matchedUser.uid, week: getCurrentWeekId())
                
                completion(nil)
            } catch {
                print("❌ Error sending matchmaking message: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    /// Get or create a conversation between the bot and a user
    private func getOrCreateBotConversation(with userId: String) async throws -> Conversation {
        let participantKey = Conversation.makeParticipantKey([Self.botUserId, userId])
        
        // Check if conversation already exists
        let query = db.collection("conversations")
            .whereField("participantKey", isEqualTo: participantKey)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        if let existingDoc = snapshot.documents.first,
           let existingConversation = try? existingDoc.data(as: Conversation.self) {
            return existingConversation
        }
        
        // Create new conversation
        let conversationId = UUID().uuidString
        let conversation = Conversation(
            id: conversationId,
            participantIds: [Self.botUserId, userId],
            participantKey: participantKey,
            inboxFor: [userId], // Bot conversations appear in user's inbox immediately
            requestFor: [], // No request needed for bot conversations
            lastMessage: nil,
            lastTimestamp: nil,
            lastReadAtByUser: [:]
        )
        
        try db.collection("conversations").document(conversationId).setData(from: conversation)
        return conversation
    }
    
    /// Send a message from the bot
    private func sendBotMessage(conversationId: String, text: String) async throws {
        let messageId = UUID().uuidString
        let message = DirectMessage(
            id: messageId,
            conversationId: conversationId,
            senderId: Self.botUserId,
            text: text,
            createdAt: Date(),
            isSystem: true, // Mark as system message
            readBy: [Self.botUserId] // Bot has "read" its own message
        )
        
        let messageRef = db.collection("conversations").document(conversationId).collection("messages").document(messageId)
        try messageRef.setData(from: message)
        
        // Update conversation metadata
        let conversationRef = db.collection("conversations").document(conversationId)
        try await conversationRef.updateData([
            "lastMessage": text,
            "lastTimestamp": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Message Generation
    
    /// Generate a personalized match message
    private func generateMatchMessage(for matchedUser: UserProfile, with sharedInterests: [String]) -> String {
        let firstName = matchedUser.displayName.components(separatedBy: " ").first ?? matchedUser.username
        
        var message = "🎵 You should connect with \(firstName)! "
        
        if sharedInterests.count > 0 {
            if sharedInterests.count == 1 {
                message += "You both love \(sharedInterests[0])."
            } else if sharedInterests.count == 2 {
                message += "You both love \(sharedInterests[0]) and \(sharedInterests[1])."
            } else {
                let firstTwo = sharedInterests.prefix(2).joined(separator: ", ")
                message += "You both love \(firstTwo), and \(sharedInterests.count - 2) other artists."
            }
        } else {
            message += "You have similar music taste!"
        }
        
        message += "\n\nTap their name to start a conversation! 💬"
        
        return message
    }
    
    // MARK: - Match Tracking
    
    /// Log a match for tracking and preventing duplicates
    private func logMatch(userId: String, matchedUserId: String, week: String) async throws {
        let matchId = "\(userId)_\(matchedUserId)_\(week)"
        let matchData: [String: Any] = [
            "id": matchId,
            "userId": userId,
            "matchedUserId": matchedUserId,
            "week": week,
            "timestamp": FieldValue.serverTimestamp(),
            "botMessageSent": true,
            "userResponded": false // Will be updated if user messages the match
        ]
        
        try await db.collection("weeklyMatches").document(matchId).setData(matchData)
    }
    
    /// Get current week identifier (format: YYYY-W##)
    private func getCurrentWeekId() -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let week = calendar.component(.weekOfYear, from: Date())
        return "\(year)-W\(String(format: "%02d", week))"
    }
    
    // MARK: - Batch Processing
    
    /// Process all eligible users for weekly matching (called by Firebase Function)
    func processWeeklyMatches() async {
        isProcessingMatches = true
        errorMessage = nil
        
        do {
            // Delegate to the main matchmaking service
            await MusicMatchmakingService.shared.executeWeeklyMatching()
            lastMatchingRun = Date()
            
            print("✅ Weekly matchmaking processing complete")
        } catch {
            print("❌ Error processing weekly matches: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isProcessingMatches = false
    }
    
    /// Get users who are eligible for matchmaking
    private func getEligibleUsers() async throws -> [UserProfile] {
        let query = db.collection("users")
            .whereField("matchmakingOptIn", isEqualTo: true)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: UserProfile.self)
        }
    }
}

// MARK: - Supporting Models
// Note: WeeklyMatch and other models are defined in MatchmakingModels.swift
