import Foundation
import FirebaseFirestore

struct DirectMessage: Identifiable, Codable {
    var id: String
    var conversationId: String
    var senderId: String
    var text: String
    var createdAt: Date
    var isSystem: Bool?
    var readBy: [String]? // uids that have read this message
    
    // MARK: - Bot & Matchmaking Support
    var messageType: MessageType?
    var matchmakingData: MatchmakingMessageData?
    
    enum MessageType: String, Codable {
        case regular = "regular"
        case system = "system"
        case botMatchmaking = "bot_matchmaking"
        case botWelcome = "bot_welcome"
        case botReminder = "bot_reminder"
    }
}

struct MatchmakingMessageData: Codable {
    let matchedUserId: String
    let matchedUsername: String
    let matchedDisplayName: String
    let matchedProfileImageUrl: String?
    let sharedArtists: [String]
    let sharedGenres: [String]
    let similarityScore: Double
    let weekId: String
}

struct Conversation: Identifiable, Codable, Equatable {
    var id: String
    var participantIds: [String]
    var participantKey: String
    var inboxFor: [String]
    var requestFor: [String]
    var lastMessage: String?
    var lastTimestamp: Date?
    var lastReadAtByUser: [String: Date]?
    
    // MARK: - Bot & Matchmaking Support
    var conversationType: ConversationType?
    var isBotConversation: Bool { 
        participantIds.contains(MatchmakingBotService.botUserId) 
    }

    static func makeParticipantKey(_ ids: [String]) -> String {
        ids.sorted().joined(separator: "_")
    }
    
    enum ConversationType: String, Codable {
        case regular = "regular"
        case bot = "bot"
        case matchmaking = "matchmaking"
        case system = "system"
    }
}