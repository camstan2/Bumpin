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
    var attachments: [MessageAttachment]?
    var replyToMessageId: String?
    var status: MessageDeliveryStatus?
    
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

struct MessageAttachment: Codable, Identifiable {
    enum AttachmentType: String, Codable {
        case audio
        case link
        case image
    }
    
    let id: String
    let type: AttachmentType
    let url: String
    let thumbnailUrl: String?
    let metadata: [String: String]?
}

enum MessageDeliveryStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
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
    var participantCount: Int?
    var createdBy: String?
    var groupName: String?
    var groupAvatarUrl: String?
    var inboxFor: [String]
    var requestFor: [String]
    var lastMessage: String?
    var lastSenderId: String?
    var lastTimestamp: Date?
    var lastReadAtByUser: [String: Date]?
    var conversationType: ConversationType?
    
    var isGroupConversation: Bool {
        (conversationType == .group) || (participantIds.count > 2)
    }
    
    // MARK: - Bot & Matchmaking Support
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
        case group = "group"
    }
}