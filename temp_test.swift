import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UIKit
import MusicKit

// MARK: - Music Profile Models

struct CommentInteraction: Identifiable, Codable {
    let id: String
    let commentId: String
    let userId: String
    let interactionType: String // "like" or "dislike"
    let timestamp: Date
}

struct CommentReply: Identifiable, Codable {
    let id: String
    let commentId: String // ID of the parent comment
    let userId: String
    let username: String
    let userProfileImage: String?
    let reply: String
    let timestamp: Date
    let likes: Int
    let dislikes: Int
    let userLiked: Bool?
    let userDisliked: Bool?
    
    var engagementScore: Int {
        return likes - dislikes
    }
}

struct CommentNotification: Identifiable, Codable {
    let id: String
    let userId: String // User who triggered the notification
    let username: String
    let userProfileImage: String?
    let targetUserId: String // User receiving the notification
    let commentId: String
    let songTitle: String
    let songArtist: String
    let notificationType: String // "reply", "like", "mention"
    let timestamp: Date
    let isRead: Bool
    
    var displayText: String {
        switch notificationType {
        case "reply":
            return "replied to your comment"
        case "like":
            return "liked your comment"
        case "mention":
            return "mentioned you in a comment"
        default:
            return "interacted with your comment"
        }
    }
}

struct MusicComment: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let userProfileImage: String?
    let comment: String
    let timestamp: Date
    let likes: Int
    let dislikes: Int
    let userLiked: Bool?
    let userDisliked: Bool?
    var replies: [CommentReply] = []
    var isExpanded: Bool = false
    
    var engagementScore: Int {
        return likes - dislikes
    }
}

struct MusicRating: Codable {
    let userId: String
    let rating: Int
    let timestamp: Date
}

struct MusicProfile: Codable {
    let id: String
    let title: String
    let artistName: String
    let artworkURL: String?
    let itemType: String // "song", "album", "artist"
    let averageRating: Double
    let totalRatings: Int
    let totalLikes: Int
    let totalDislikes: Int
    let userRating: Int?
    let userLiked: Bool?
    let userDisliked: Bool?
}

// MARK: - Music Profile View

struct MusicProfileView: View {
    let musicItem: MusicSearchResult
    let pinnedLog: MusicLog?
    
    @State private var showLogForm = false
    @Environment(\.dismiss) private var dismiss
    @State private var profile: MusicProfile?
    @State private var comments: [MusicComment] = []
    @State private var lastCommentsDoc: DocumentSnapshot? = nil
    @State private var hasMoreComments: Bool = true
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var userRating: Int = 0
    @State private var showingReplySheet: Bool = false
    @State private var selectedCommentForReply: MusicComment?
    @State private var replyText: String = ""
    @State private var isSubmittingReply: Bool = false
    @State private var userRatingsCache: [String: Int] = [:]
    @State private var showingEditCommentSheet: Bool = false
    @State private var selectedCommentForEdit: MusicComment?
    @State private var editCommentText: String = ""
    @State private var isEditingComment: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var commentToDelete: MusicComment?
    @State private var showingMentionSuggestions: Bool = false
    @State private var mentionSuggestions: [String] = []
    @State private var currentMentionQuery: String = ""
    @State private var mentionStartIndex: Int = 0
    @State private var showingNotificationsSheet: Bool = false
    @State private var notifications: [CommentNotification] = []
    @State private var isLoadingNotifications: Bool = false
    
    @State var friendIds: [String] = []
    @State private var albumTracks: [MusicSearchResult] = []
    @State private var trackRatings: [String: Double] = [:]
    @State private var isLoadingTracks: Bool = false
    @State private var hasRepostedItem: Bool = false
    
    var body: some View {
        Group {
            // Debug: Check if this is being used for an artist
            let _ = print("🎯 MusicProfileView: Showing profile for \(musicItem.title) (type: \(musicItem.itemType))")
            
            // Redirect artists to the enhanced ArtistProfileView
            if musicItem.itemType == "artist" {
                ArtistProfileView(artistName: musicItem.title)
                    .environmentObject(NavigationCoordinator())
            } else {
                musicProfileContent
            }
        }
    }
    
    // MARK: - Music Profile Content (for non-artists)
    private var musicProfileContent: some View {
        NavigationView {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                headerSection
                
                // Repost item action (song/album/artist)
                HStack {
                    Button(action: { toggleItemRepost() }) {
                        Label(hasRepostedItem ? "Unrepost" : "Repost", systemImage: "arrow.2.squarepath")
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    Spacer()
                }
                
                // Rating Section
                ratingSection
                
                // Pinned user's log (full detail) when navigating from a specific log
                if let pinnedLog = pinnedLog {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Highlighted Log")
                            .font(.headline)
                        EnhancedReviewView(log: pinnedLog, showFullDetails: true)
                        // Show a few comments on this specific log
                        FriendsCommentsPreview(log: pinnedLog, maxCount: 3, alwaysShowMock: true)
                    }
                }
                
                // Comments Section
                commentsSection
                
                // Friends Logs Section (moved below comments)
                friendsLogsSection
                
                // Tracklist Section (only for albums)
                if musicItem.itemType == "album" {
                    tracklistSection
                }
            }
            .padding()
}
