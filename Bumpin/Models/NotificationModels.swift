import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Enhanced Notification Models

struct AppNotification: Identifiable, Codable {
    var id: String { notificationId }
    let notificationId: String
    let type: NotificationType
    let timestamp: Date
    let isRead: Bool
    
    // User info
    let fromUserId: String?
    let fromUserName: String?
    let fromUserUsername: String?
    let fromUserProfilePictureUrl: String?
    
    // Context-specific data
    let contextId: String? // partyId, logId, promptId, etc.
    let contextTitle: String? // party name, song title, etc.
    let contextSubtitle: String? // artist name, additional info
    let contextImageUrl: String?
    
    // Message for system notifications
    let message: String?
    
    init(notificationId: String = UUID().uuidString, type: NotificationType, timestamp: Date = Date(), isRead: Bool = false, fromUserId: String? = nil, fromUserName: String? = nil, fromUserUsername: String? = nil, fromUserProfilePictureUrl: String? = nil, contextId: String? = nil, contextTitle: String? = nil, contextSubtitle: String? = nil, contextImageUrl: String? = nil, message: String? = nil) {
        self.notificationId = notificationId
        self.type = type
        self.timestamp = timestamp
        self.isRead = isRead
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserUsername = fromUserUsername
        self.fromUserProfilePictureUrl = fromUserProfilePictureUrl
        self.contextId = contextId
        self.contextTitle = contextTitle
        self.contextSubtitle = contextSubtitle
        self.contextImageUrl = contextImageUrl
        self.message = message
    }
}

enum NotificationType: String, Codable, CaseIterable {
    // Social
    case newFollower = "new_follower"
    case musicLogLiked = "music_log_liked"
    case musicLogCommented = "music_log_commented"
    case musicLogReposted = "music_log_reposted"
    case commentReplied = "comment_replied"
    case userMentioned = "user_mentioned"
    case friendJoinedApp = "friend_joined_app"
    case followBack = "follow_back"
    
    // Party
    case partyInvite = "party_invite"
    case partyJoined = "party_joined"
    case friendStartedParty = "friend_started_party"
    case partyEnded = "party_ended"
    case partyHostChanged = "party_host_changed"
    case partySongAdded = "party_song_added"
    
    // Daily Prompt
    case newDailyPrompt = "new_daily_prompt"
    case promptResponseLiked = "prompt_response_liked"
    case promptResponseCommented = "prompt_response_commented"
    case promptLeaderboard = "prompt_leaderboard"
    case friendCompletedPrompt = "friend_completed_prompt"
    
    // DJ Stream
    case djStreamStarted = "dj_stream_started"
    case djStreamLive = "dj_stream_live"
    case djStreamEnded = "dj_stream_ended"
    
    // Direct Messages
    case newMessage = "new_message"
    case messageRequest = "message_request"
    
    // Achievements & Milestones
    case firstMusicLog = "first_music_log"
    case streakMilestone = "streak_milestone"
    case followersmilestone = "followers_milestone"
    
    // System
    case appUpdate = "app_update"
    case featureAnnouncement = "feature_announcement"
    case maintenance = "maintenance"
    
    var icon: String {
        switch self {
        case .newFollower: return "person.badge.plus"
        case .musicLogLiked: return "heart.fill"
        case .musicLogCommented: return "bubble.left"
        case .musicLogReposted: return "arrowshape.turn.up.right"
        case .commentReplied: return "arrowshape.turn.up.left"
        case .userMentioned: return "at"
        case .friendJoinedApp: return "person.2.badge.plus"
        case .followBack: return "person.badge.checkmark"
        case .partyInvite: return "envelope"
        case .partyJoined: return "person.2"
        case .friendStartedParty: return "music.note.house"
        case .partyEnded: return "music.note.house.fill"
        case .partyHostChanged: return "crown"
        case .partySongAdded: return "music.note.list"
        case .newDailyPrompt: return "calendar.badge.exclamationmark"
        case .promptResponseLiked: return "heart.fill"
        case .promptResponseCommented: return "bubble.left"
        case .promptLeaderboard: return "trophy"
        case .friendCompletedPrompt: return "checkmark.circle"
        case .djStreamStarted: return "radio"
        case .djStreamLive: return "dot.radiowaves.left.and.right"
        case .djStreamEnded: return "radio.fill"
        case .newMessage: return "message"
        case .messageRequest: return "envelope.badge"
        case .firstMusicLog: return "star"
        case .streakMilestone: return "flame"
        case .followersmilestone: return "person.3"
        case .appUpdate: return "arrow.down.circle"
        case .featureAnnouncement: return "megaphone"
        case .maintenance: return "wrench"
        }
    }
    
    var color: Color {
        switch self {
        case .newFollower, .followBack: return .blue
        case .musicLogLiked, .promptResponseLiked: return .red
        case .musicLogCommented, .commentReplied, .promptResponseCommented: return .green
        case .musicLogReposted: return .cyan
        case .userMentioned: return .orange
        case .friendJoinedApp: return .mint
        case .partyInvite, .partyJoined, .friendStartedParty, .partyEnded, .partyHostChanged, .partySongAdded: return .purple
        case .newDailyPrompt, .promptLeaderboard, .friendCompletedPrompt: return .yellow
        case .djStreamStarted, .djStreamLive, .djStreamEnded: return .pink
        case .newMessage, .messageRequest: return .blue
        case .firstMusicLog, .streakMilestone, .followersmilestone: return .indigo
        case .appUpdate, .featureAnnouncement, .maintenance: return .gray
        }
    }
}
