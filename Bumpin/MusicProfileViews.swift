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
    var likes: Int
    var dislikes: Int
    var userLiked: Bool?
    var userDisliked: Bool?
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
    let totalLogs: Int // Total number of logs (rated + unrated)
    let totalLikes: Int
    let totalDislikes: Int
    let userRating: Double? // Changed from Int? to Double? for half-star support
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
    @State private var communityLogs: [MusicLog] = [] // Changed from comments to logs
    @State private var lastCommentsDoc: DocumentSnapshot? = nil
    @State private var hasMoreComments: Bool = true
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var universalTrackId: String? // Store universal track ID for analytics
    @State private var userRating: Double = 0.0 // Changed from Int to Double to support half stars
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
    @State private var trackRatingsLoadedIds: Set<String> = []
    @State private var isLoadingTracks: Bool = false
    
    private var aggregatedRatingStats: (average: Double, total: Int) {
        let logRatings = communityLogs.compactMap { $0.rating }
        if !logRatings.isEmpty {
            let total = logRatings.count
            let sum = logRatings.reduce(0.0, +)
            let average = sum / Double(total)
            let clamped = max(0.0, min(5.0, average))
            let rounded = (clamped * 10).rounded() / 10
            return (rounded, total)
        }
        if let profile = profile, profile.totalRatings > 0 {
            let clamped = max(0.0, min(5.0, profile.averageRating))
            let rounded = (clamped * 10).rounded() / 10
            return (rounded, profile.totalRatings)
        }
        return (0.0, 0)
    }

    // Listen Later integration
    @State private var isAddingToListenLater = false
    @State private var listenLaterSuccess = false
    
    // Track navigation
    @State private var selectedTrack: MusicSearchResult?
    @State private var showArtistProfile = false
    @State private var showArtistPicker = false
    @State private var artistPickerOptions: [String] = []
    @State private var selectedArtistNameForProfile: String?
    
    // Cross-platform data
    @State private var universalProfile: UniversalMusicProfileService.UniversalMusicProfile?
    @State private var isLoadingUniversalProfile = false
    
    var body: some View {
        Group {
            // Debug: Check if this is being used for an artist
            // Reduced logging - only log on initial load, not every re-render
            
            // Redirect artists to the enhanced ArtistProfileView
            if musicItem.itemType == "artist" {
                ArtistProfileView(artistName: musicItem.title)
            } else {
                // Add loading state to prevent white screen
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    musicProfileContent
                }
            }
        }
        .onAppear {
            // Ensure we start loading immediately
            if profile == nil {
                loadProfile()
                loadComments()
                loadFriendIds()
            }
        }
    }
    
    private func handleArtistSubtitleTap() {
        let artists = parsedArtistNames()
        if let first = artists.first, artists.count == 1 {
            selectedArtistNameForProfile = first
            showArtistProfile = true
        } else if artists.count > 1 {
            artistPickerOptions = artists
            showArtistPicker = true
        } else if !musicItem.artistName.isEmpty {
            selectedArtistNameForProfile = musicItem.artistName
            showArtistProfile = true
        }
    }
    
    private func parsedArtistNames() -> [String] {
        let parsed = ArtistNameParser.splitArtists(from: musicItem.artistName)
        if parsed.isEmpty {
            let trimmed = musicItem.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        return parsed
    }
    
    // MARK: - Music Profile Content (for non-artists)
    private var musicProfileContent: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ProfileDesignSystem.Spacing.sectionGap) {
                    // Hero Header Section (with cross-platform data)
                    ProfileHeaderComponent(
                        title: musicItem.title,
                        subtitle: musicItem.artistName,
                        itemType: musicItem.itemType,
                        artworkURL: musicItem.artworkURL,
                        averageRating: profile?.averageRating ?? 0.0,
                        totalRatings: profile?.totalRatings ?? 0,
                        totalLogs: profile?.totalLogs ?? 0,
                        onActionTapped: { addItemToListenLater() },
                        crossPlatformInfo: universalProfile?.crossPlatformPopularity,
                        itemId: musicItem.id,
                        platform: musicItem.platform,
                        onSubtitleTapped: {
                            handleArtistSubtitleTap()
                        }
                    )
                    .profileSection()

                    // Highlighted review (when arriving from a specific log)
                    if let pinnedLog = pinnedLog {
                        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
                            ProfileSectionHeader(
                                title: "Highlighted Review",
                                subtitle: "From your navigation",
                                icon: "pin.fill"
                            )
                            EnhancedReviewView(log: pinnedLog, showFullDetails: true)
                            FriendsCommentsPreview(log: pinnedLog, maxCount: 3, alwaysShowMock: true)
                        }
                        .padding(ProfileDesignSystem.Spacing.cardPadding)
                        .profileCard()
                        .profileSection()
                    }
                    
                    // Rating & Community Section
                    DisplayOnlyRatingView(
                        userRating: userRating,
                        averageRating: aggregatedRatingStats.average,
                        totalRatings: aggregatedRatingStats.total
                    )
                    .profileSection()
                    
                    // Rating Distribution Section
                    if let universalId = universalTrackId {
                        EnhancedRatingDistributionView(
                            itemId: musicItem.id,
                            universalTrackId: universalId,
                            itemType: musicItem.itemType,
                            itemTitle: musicItem.title
                        )
                        .profileSection()
                    } else {
                        // Fallback to old behavior if universal track ID not available
                        EnhancedRatingDistributionView(
                            itemId: musicItem.id,
                            universalTrackId: nil,
                            itemType: musicItem.itemType,
                            itemTitle: musicItem.title
                        )
                        .profileSection()
                    }
                    
                // Analytics Section
                if let universalId = universalTrackId {
                    EnhancedPopularityGraphView(
                        itemId: musicItem.id,
                        universalTrackId: universalId,
                        itemType: musicItem.itemType,
                        itemTitle: musicItem.title
                    )
                    .profileSection()
                } else {
                    // Fallback to old behavior if universal track ID not available
                    EnhancedPopularityGraphView(
                        itemId: musicItem.id,
                        universalTrackId: nil,
                        itemType: musicItem.itemType,
                        itemTitle: musicItem.title
                    )
                    .profileSection()
                }
                
                // Tracklist Section (only for albums) - moved up
                if musicItem.itemType == "album" {
                    enhancedTracklistSection
                }
                
                // Social Section
                EnhancedSocialSection(
                    musicItem: musicItem,
                    logs: communityLogs,
                    onViewAllLogs: {
                        // Navigation handled by View All button in EnhancedSocialSection
                    }
                )
                .profileSection()
                
                // Friends' Logs Section
                EnhancedFriendsLogsSection(
                    itemId: musicItem.id,
                    itemType: musicItem.itemType,
                    itemTitle: musicItem.title,
                    musicItem: musicItem
                )
                .profileSection()
                
                
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Plus button removed from navigation bar
        }
        .fullScreenCover(isPresented: $showLogForm) {
            LogMusicFormView(searchResult: musicItem)
        }
        .fullScreenCover(item: $selectedTrack) { track in
            MusicProfileView(musicItem: track, pinnedLog: nil)
        }
        .sheet(isPresented: $showingEditCommentSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edit Comment")
                            .font(.headline)
                            .padding(.top)
                        
                        // Show the original comment
                        if let comment = selectedCommentForEdit {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.comment)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Text editor for editing comment
                    TextEditor(text: $editCommentText)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2))
                        )
                        .padding(.horizontal)
                        .onAppear {
                            if let comment = selectedCommentForEdit {
                                editCommentText = comment.comment
                            }
                        }
                    
                    Spacer()
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingEditCommentSheet = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            // Saving handled elsewhere
                            showingEditCommentSheet = false
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert("Delete Comment", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                commentToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteComment()
            }
        } message: {
            Text("Are you sure you want to delete this comment? This action cannot be undone.")
        }
        .sheet(isPresented: $showingNotificationsSheet) {
            NavigationView {
                VStack {
                    if isLoadingNotifications {
                        ProgressView("Loading notifications...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if notifications.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No notifications yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("You'll see notifications here when people interact with your comments")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(notifications) { notification in
                            notificationRow(notification)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            showingNotificationsSheet = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark All Read") {
                            markAllNotificationsAsRead()
                        }
                        .disabled(notifications.isEmpty)
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showingReplySheet) {
            NavigationView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reply to \(selectedCommentForReply?.username ?? "")")
                            .font(.headline)
                            .padding(.top)
                        
                        // Show the comment being replied to
                        if let comment = selectedCommentForReply {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.comment)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Reply text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your reply")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $replyText)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: replyText) { newValue in
                                    detectMentions(in: newValue)
                                }
                            
                            // Mention suggestions overlay
                            if showingMentionSuggestions && !mentionSuggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(mentionSuggestions, id: \.self) { username in
                                        Button(action: {
                                            replyText = insertMention(username, into: replyText)
                                            showingMentionSuggestions = false
                                        }) {
                                            HStack {
                                                Image(systemName: "person.circle.fill")
                                                    .foregroundColor(.blue)
                                                Text("@\(username)")
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemBackground))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if username != mentionSuggestions.last {
                                            Divider()
                                        }
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                .offset(y: 40)
                                .zIndex(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Submit button
                    Button(action: submitReply) {
                        HStack {
                            if isSubmittingReply {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Send Reply")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingReply 
                            ? Color.gray 
                            : Color.blue
                        )
                        .cornerRadius(12)
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingReply)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
                .navigationTitle("Reply")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingReplySheet = false
                            replyText = ""
                            selectedCommentForReply = nil
                        }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .navigationTitle(musicItem.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                        .font(.title2)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showLogForm = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.purple))
                        .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .accessibilityLabel("Log this music")
            }
        }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadProfile()
            loadFriendIds()
            loadUniversalProfile()
            if musicItem.itemType == "album" {
                loadAlbumTracks()
            }
        }
        .onDisappear { }
        .refreshable {
            await refreshData()
        }
        .fullScreenCover(isPresented: $showArtistProfile) {
            ArtistProfileView(artistName: selectedArtistNameForProfile ?? musicItem.artistName)
                .onDisappear {
                    selectedArtistNameForProfile = nil
                }
        }
        .confirmationDialog("Choose an artist", isPresented: $showArtistPicker, titleVisibility: .visible) {
            ForEach(artistPickerOptions, id: \.self) { artist in
                Button(artist) {
                    selectedArtistNameForProfile = artist
                    showArtistProfile = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Enhanced Sections
    
    private var enhancedFriendsActivitySection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            ProfileSectionHeader(
                title: "Follower Activity",
                subtitle: "See what your followers think",
                icon: "person.2.fill"
            )
            
            // This would show friend logs - keeping existing logic for now
            friendsLogsSection
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
        .profileSection()
    }
    
    private var enhancedTracklistSection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            ProfileSectionHeader(
                title: "Tracklist",
                subtitle: albumTracks.isEmpty ? "Loading tracks..." : "\(albumTracks.count) tracks",
                icon: "list.bullet"
            )
            
            if isLoadingTracks {
                VStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading album tracks...")
                        .font(ProfileDesignSystem.Typography.captionLarge)
                        .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                }
                .frame(height: 80)
            } else if albumTracks.isEmpty {
                VStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    Image(systemName: "music.note.list")
                        .font(ProfileDesignSystem.Typography.headlineSmall)
                        .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                    Text("No tracks found")
                        .font(ProfileDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                    Text("Unable to load album tracklist")
                        .font(ProfileDesignSystem.Typography.captionLarge)
                        .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                }
                .frame(height: 80)
            } else {
                LazyVStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    ForEach(Array(albumTracks.enumerated()), id: \.element.id) { index, track in
                        trackListRow(track, trackNumber: index + 1)
                    }
                }
            }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
        .profileSection()
        .task {
            let ids = Set(albumTracks.map { $0.id })
            if ids != trackRatingsLoadedIds {
                await loadTrackRatings()
            }
        }
    }
    
    private func enhancedTrackRow(_ track: MusicSearchResult, trackNumber: Int) -> some View {
        Button(action: {
            // Navigate to track profile - keeping existing logic
            print("Navigate to track: \(track.title)")
        }) {
            HStack(spacing: ProfileDesignSystem.Spacing.md) {
                // Track number
                Text("\(trackNumber)")
                    .font(ProfileDesignSystem.Typography.captionLarge)
                    .fontWeight(.bold)
                    .foregroundColor(ProfileDesignSystem.Colors.primary)
                    .frame(width: 24, alignment: .center)
                    .padding(.vertical, 4)
                    .background(
                        Circle()
                            .fill(ProfileDesignSystem.Colors.primary.opacity(0.1))
                    )
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(ProfileDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !track.artistName.isEmpty {
                        Text(track.artistName)
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                // Rating if available
                if let rating = trackRatings[track.id], rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(ProfileDesignSystem.Typography.captionSmall)
                            .foregroundColor(ProfileDesignSystem.Colors.ratingGold)
                        Text(String(format: "%.1f", rating))
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .fontWeight(.medium)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                }
                
                // Navigation chevron
                Image(systemName: "chevron.right")
                    .font(ProfileDesignSystem.Typography.captionSmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            }
            .padding(ProfileDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Track List Row for Albums
    private func trackListRow(_ track: MusicSearchResult, trackNumber: Int) -> some View {
        Button(action: {
            // Navigate to song profile using item-based fullScreenCover
            print("🎯 Navigate to song: \(track.title)")
            selectedTrack = track
        }) {
            HStack(spacing: ProfileDesignSystem.Spacing.md) {
                // Track number
                Text("\(trackNumber)")
                    .font(ProfileDesignSystem.Typography.captionLarge)
                    .fontWeight(.bold)
                    .foregroundColor(ProfileDesignSystem.Colors.primary)
                    .frame(width: 24, alignment: .center)
                    .padding(.vertical, 4)
                    .background(
                        Circle()
                            .fill(ProfileDesignSystem.Colors.primary.opacity(0.1))
                    )
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(ProfileDesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !track.artistName.isEmpty {
                        Text(track.artistName)
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                // Rating if available
                if let rating = trackRatings[track.id], rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(ProfileDesignSystem.Typography.captionSmall)
                            .foregroundColor(ProfileDesignSystem.Colors.ratingGold)
                        Text(String(format: "%.1f", rating))
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .fontWeight(.medium)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                }
                
                // Navigation chevron
                Image(systemName: "chevron.right")
                    .font(ProfileDesignSystem.Typography.captionSmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            }
            .padding(ProfileDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Artwork
            if let artworkURL = musicItem.artworkURL,
               let url = URL(string: artworkURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: musicItem.itemType == "artist" ? "person.fill" : "music.note")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 120, height: 120)
                .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: musicItem.itemType == "artist" ? "person.fill" : "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            
            // Title and Artist
            VStack(spacing: 4) {
                Text(musicItem.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if musicItem.itemType != "artist" {
                    Text("by \(musicItem.artistName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(musicItem.itemType.capitalized)
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.purple.opacity(0.1))
                    )
            }
        }
    }
    
    // MARK: - Rating Section
    private var ratingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Rating")
                    .font(.headline)
                Spacer()
                if let profile = profile {
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", profile.averageRating))
                            .font(.headline)
                            .foregroundColor(.orange)
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("(\(profile.totalRatings))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
        // Display Average Rating Stars (Read-only)
        StarRatingDisplayView(
            rating: profile?.averageRating ?? 0,
            starSize: 22,
            spacing: 4,
            showNumber: false
        )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    

    
    // MARK: - Comments Section
    /* DEPRECATED: Old comments section - now using EnhancedSocialSection with logs
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comments")
                    .font(.headline)
                Spacer()
                Text("\(comments.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(action: {
                    print("🔄 Manually refreshing comments...")
                    loadComments()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Be the first to share your thoughts!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(comments) { comment in
                        commentRow(comment)
                    }
                    if hasMoreComments {
                        HStack {
                            Spacer()
                            Button("Load more") { loadMoreComments() }
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Comment Row
    private func commentRow(_ comment: MusicComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // User Avatar
                if let profileImage = comment.userProfileImage,
                   let url = URL(string: profileImage) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(comment.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        // Show user's rating if available
                        if let userRating = getUserRating(for: comment.userId) {
                            StarRatingDisplayView(
                                rating: Double(userRating),
                                starSize: 10,
                                spacing: 1
                            )
                        }
                    }
                    Text(timeAgoString(from: comment.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(alignment: .top) {
                            // Display comment with clickable mentions
            displayTextWithMentions(comment.comment)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                
                // Show edit indicator for user's own comments
                if comment.userId == Auth.auth().currentUser?.uid {
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .opacity(0.7)
                }
            }
            .contextMenu {
                // Only show edit/delete for current user's comments
                if comment.userId == Auth.auth().currentUser?.uid {
                    Button(action: {
                        selectedCommentForEdit = comment
                        editCommentText = comment.comment
                        showingEditCommentSheet = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        commentToDelete = comment
                        showingDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            
            // Comment Engagement
            HStack(spacing: 16) {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleCommentLike(comment)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.userLiked == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.caption)
                            .foregroundColor(comment.userLiked == true ? .green : .gray)
                            .scaleEffect(comment.userLiked == true ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: comment.userLiked)
                        Text("\(comment.likes)")
                            .font(.caption)
                            .foregroundColor(comment.userLiked == true ? .green : .secondary)
                            .fontWeight(comment.userLiked == true ? .semibold : .regular)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleCommentDislike(comment)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.userDisliked == true ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.caption)
                            .foregroundColor(comment.userDisliked == true ? .red : .gray)
                            .scaleEffect(comment.userDisliked == true ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: comment.userDisliked)
                        Text("\(comment.dislikes)")
                            .font(.caption)
                            .foregroundColor(comment.userDisliked == true ? .red : .secondary)
                            .fontWeight(comment.userDisliked == true ? .semibold : .regular)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Reply button
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showReplySheet(for: comment)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(comment.replies.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .onTapGesture {
                    print("💬 Reply button tapped for comment: \(comment.id)")
                    print("   Comment has \(comment.replies.count) replies")
                    for (index, reply) in comment.replies.enumerated() {
                        print("   Reply \(index + 1): '\(reply.reply)' by \(reply.username)")
                    }
                }
                
                Spacer()
                
                // Engagement score indicator
                let totalEngagement = comment.likes + comment.dislikes + (comment.replies.count * 3)
                if totalEngagement > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(totalEngagement)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
            
            // Replies section
            if !comment.replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Show/hide replies button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            toggleReplies(for: comment)
                        }
                    }) {
                        HStack {
                            Image(systemName: comment.isExpanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("\(comment.replies.count) replies")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Replies list
                    if comment.isExpanded {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(comment.replies) { reply in
                                replyRow(reply, parentComment: comment)
                            }
                        }
                        .padding(.leading, 16)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    */ // END DEPRECATED COMMENTS SECTION - Views above
    
    private func getUserRating(for userId: String) -> Int? {
        return userRatingsCache[userId]
    }
    
    private func loadUserRatings() {
        let db = Firestore.firestore()
        
        // Load all logs for this song to get user ratings
        db.collection("logs")
            .whereField("itemId", isEqualTo: musicItem.id)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading user ratings: \(error.localizedDescription)")
                    return
                }
                
                let documents = snapshot?.documents ?? []
                var ratings: [String: Int] = [:]
                
                for doc in documents {
                    let data = doc.data()
                    if let userId = data["userId"] as? String,
                       let rating = data["rating"] as? Int {
                        ratings[userId] = rating
                    }
                }
                
                DispatchQueue.main.async {
                    self.userRatingsCache = ratings
                    print("✅ Loaded \(ratings.count) user ratings")
                }
            }
    }
    
    private func loadProfile() {
        print("🔍 [MusicProfile] Starting to load profile for: \(musicItem.title)")
        let profileStartTime = Date()
        
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Set a timeout for the query
        let timeoutSeconds: Double = 5.0
        var hasCompleted = false
        
        // Start timeout timer
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) {
            if !hasCompleted {
                print("⚠️ [MusicProfile] Query timeout after \(timeoutSeconds)s - showing empty profile")
                self.isLoading = false
                // Show empty profile with no logs
                self.profile = MusicProfile(
                    id: self.musicItem.id,
                    title: self.musicItem.title,
                    artistName: self.musicItem.artistName,
                    artworkURL: self.musicItem.artworkURL,
                    itemType: self.musicItem.itemType,
                    averageRating: 0.0,
                    totalRatings: 0,
                    totalLogs: 0,
                    totalLikes: 0,
                    totalDislikes: 0,
                    userRating: nil,
                    userLiked: nil,
                    userDisliked: nil
                )
            }
        }
        
        // Load ratings using universal track ID for cross-platform unification
        Task {
            let platform = musicItem.platform ?? "apple_music"
            guard let universalTrackId = await getUniversalTrackId(for: musicItem.id, platform: platform) else {
                print("⚠️ Could not find universal track for item: \(musicItem.id), falling back to itemId query")
                // Fallback to old method if universal track not found
                loadProfileByItemId(profileStartTime: profileStartTime, userId: userId, db: db, onComplete: { completed in
                    hasCompleted = completed
                })
                return
            }
            
            // Store the universal track ID for use in analytics
            await MainActor.run {
                self.universalTrackId = universalTrackId
            }
            
            print("🎯 Loading profile for universal track: \(universalTrackId)")
            
            db.collection("logs")
                .whereField("universalTrackId", isEqualTo: universalTrackId)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        hasCompleted = true
                        let elapsedTime = Date().timeIntervalSince(profileStartTime)
                        print("🔍 [MusicProfile] Query completed in \(String(format: "%.2f", elapsedTime))s")
                        
                        if let error = error {
                            print("Error loading profile: \(error.localizedDescription)")
                            self.errorMessage = "Failed to load song profile"
                            self.isLoading = false
                            return
                        }
                        
                        let documents = snapshot?.documents ?? []
                        print("🔍 [MusicProfile] Found \(documents.count) logs for universal track")
                        self.calculateAverageRatingFromAllUsers(documents: documents, currentUserId: userId)
                        self.loadComments()
                        self.loadUserRatings()
                    }
                }
        }
    }
    
    // Fallback method for old logs without universal track ID
    private func loadProfileByItemId(profileStartTime: Date, userId: String, db: Firestore, onComplete: @escaping (Bool) -> Void) {
        db.collection("logs")
            .whereField("itemId", isEqualTo: musicItem.id)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    onComplete(true)
                    let elapsedTime = Date().timeIntervalSince(profileStartTime)
                    print("🔍 [MusicProfile] Fallback query completed in \(String(format: "%.2f", elapsedTime))s")
                    
                    if let error = error {
                        print("Error loading profile: \(error.localizedDescription)")
                        self.errorMessage = "Failed to load song profile"
                        self.isLoading = false
                        return
                    }
                    
                    let documents = snapshot?.documents ?? []
                    print("🔍 [MusicProfile] Found \(documents.count) logs for this item (fallback)")
                    self.calculateAverageRatingFromAllUsers(documents: documents, currentUserId: userId)
                    self.loadComments()
                    self.loadUserRatings()
                }
            }
    }
    
    private func calculateAverageRatingFromAllUsers(documents: [QueryDocumentSnapshot], currentUserId: String) {
        var totalRating = 0.0
        var ratingCount = 0
        var currentUserRating: Double? // Changed from Int? to Double? for half-star support
        var totalLikes = 0
        var totalDislikes = 0
        var currentUserLiked: Bool?
        var currentUserDisliked: Bool?
        var mostRecentUserLog: (rating: Double, dateLogged: Date, isLiked: Bool?, thumbsDown: Bool?)? = nil
        
        // Reduced verbose logging
        
        for document in documents {
            let data = document.data()
            
            // Calculate ratings - handle both Int and Double for backwards compatibility
            var rating: Double? = nil
            if let doubleRating = data["rating"] as? Double {
                rating = doubleRating
            } else if let intRating = data["rating"] as? Int {
                rating = Double(intRating)
            }
            
            if let rating = rating {
                totalRating += rating
                ratingCount += 1
                
                // Check if this is the current user's log and track the most recent one
                if data["userId"] as? String == currentUserId {
                    let dateLogged = (data["dateLogged"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    let isLiked = data["isLiked"] as? Bool
                    let thumbsDown = data["thumbsDown"] as? Bool
                    
                    // Update if this is the first user log or if it's more recent
                    if mostRecentUserLog == nil || dateLogged > mostRecentUserLog!.dateLogged {
                        mostRecentUserLog = (rating: rating, dateLogged: dateLogged, isLiked: isLiked, thumbsDown: thumbsDown)
                    }
                }
            }
            
            // Calculate likes/dislikes
            if let isLiked = data["isLiked"] as? Bool, isLiked {
                totalLikes += 1
            }
            if let thumbsDown = data["thumbsDown"] as? Bool, thumbsDown {
                totalDislikes += 1
            }
        }
        
        // Use the most recent user log if available - NO ROUNDING for half-star support
        if let recentLog = mostRecentUserLog {
            currentUserRating = recentLog.rating // Keep as Double, don't round
            currentUserLiked = recentLog.isLiked
            currentUserDisliked = recentLog.thumbsDown
        }
        
        let averageRating = ratingCount > 0 ? totalRating / Double(ratingCount) : 0.0
        
        // Reduced verbose calculation logging
        
        let profile = MusicProfile(
            id: musicItem.id,
            title: musicItem.title,
            artistName: musicItem.artistName,
            artworkURL: musicItem.artworkURL,
            itemType: musicItem.itemType,
            averageRating: averageRating,
            totalRatings: ratingCount,
            totalLogs: documents.count, // Total logs (rated + unrated)
            totalLikes: totalLikes,
            totalDislikes: totalDislikes,
            userRating: currentUserRating,
            userLiked: currentUserLiked,
            userDisliked: currentUserDisliked
        )
        
        self.profile = profile
        self.userRating = currentUserRating ?? 0.0 // Changed from 0 to 0.0 for Double
        self.isLoading = false
    }
    

    // MARK: - Universal Track Helper
    
    /// Get universal track ID from platform-specific ID for cross-platform queries
    private func getUniversalTrackId(for platformItemId: String, platform: String) async -> String? {
        let normalizedPlatform = platform.lowercased()
        
        if normalizedPlatform == "apple_music" {
            let appleMusicId = isLikelyAppleMusicId(platformItemId) ? platformItemId : nil
            let track = await TrackMatchingService.shared.getUniversalTrack(
                title: musicItem.title,
                artist: musicItem.artistName,
                albumName: musicItem.albumName,
                appleMusicId: appleMusicId
            )
            return track.id
        } else if normalizedPlatform == "spotify" {
            let track = await TrackMatchingService.shared.getUniversalTrack(
                title: musicItem.title,
                artist: musicItem.artistName,
                albumName: musicItem.albumName,
                spotifyId: platformItemId
            )
            return track.id
        } else {
            // Local/offline items: fall back to fuzzy matching without platform ID
            let track = await TrackMatchingService.shared.getUniversalTrack(
                title: musicItem.title,
                artist: musicItem.artistName,
                albumName: musicItem.albumName,
                appleMusicId: nil
            )
            return track.id
        }
    }
    
    private func isLikelyAppleMusicId(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        let digits = CharacterSet.decimalDigits
        let isNumeric = id.unicodeScalars.allSatisfy { digits.contains($0) }
        // Apple Music IDs are typically <= 15 digits; persistent IDs are usually longer
        return isNumeric && (5...15).contains(id.count)
    }
    
    private func loadComments() {
        // First get the universal track ID for cross-platform queries
        Task {
            let platform = musicItem.platform ?? "apple_music" // Detect from musicItem
            guard let universalTrackId = await getUniversalTrackId(for: musicItem.id, platform: platform) else {
                print("⚠️ Could not find universal track for item: \(musicItem.id)")
                // Fallback to old method if universal track not found
                await loadCommentsByItemId()
                return
            }
            
            print("🎯 Loading logs for universal track: \(universalTrackId)")
            
            let db = Firestore.firestore()
            
            // Query by universalTrackId instead of itemId for cross-platform unification
            db.collection("logs")
                .whereField("universalTrackId", isEqualTo: universalTrackId)
                .order(by: "dateLogged", descending: true)
                .limit(to: 10)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Error loading community logs: \(error.localizedDescription)")
                            return
                        }
                        
                        let documents = snapshot?.documents ?? []
                        let logs = documents.compactMap { doc -> MusicLog? in
                            try? doc.data(as: MusicLog.self)
                        }
                        
                        print("✅ Loaded \(logs.count) cross-platform logs")
                        
                        // Sort by engagement score
                        self.communityLogs = EngagementScoringService.shared.sortByEngagement(logs)
                    }
                }
        }
    }
    
    /// Fallback method for backwards compatibility with old logs without universalTrackId
    private func loadCommentsByItemId() async {
        let db = Firestore.firestore()
        
        await MainActor.run {
            db.collection("logs")
                .whereField("itemId", isEqualTo: musicItem.id)
                .order(by: "dateLogged", descending: true)
                .limit(to: 10)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Error loading community logs (fallback): \(error.localizedDescription)")
                            return
                        }
                        
                        let documents = snapshot?.documents ?? []
                        let logs = documents.compactMap { doc -> MusicLog? in
                            try? doc.data(as: MusicLog.self)
                        }
                        
                        print("⚠️ Loaded \(logs.count) logs using fallback itemId query")
                        
                        // Sort by engagement score
                        self.communityLogs = EngagementScoringService.shared.sortByEngagement(logs)
                    }
                }
        }
    }
    
    private func toggleCommentLike(_ comment: MusicComment) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        let db = Firestore.firestore()
        let interactionId = "\(currentUserId)_\(comment.id)"
        
        // Check if user already liked this comment
        db.collection("commentInteractions")
            .document(interactionId)
            .getDocument { snapshot, error in
                if let existingInteraction = snapshot?.data(),
                   let interactionType = existingInteraction["interactionType"] as? String {
                    
                    if interactionType == "like" {
                        // Remove like
                        self.removeCommentInteraction(commentId: comment.id, userId: currentUserId, interactionType: "like")
                    } else if interactionType == "dislike" {
                        // Change dislike to like
                        self.updateCommentInteraction(commentId: comment.id, userId: currentUserId, fromType: "dislike", toType: "like")
                    }
                } else {
                    // Add new like
                    self.addCommentInteraction(commentId: comment.id, userId: currentUserId, interactionType: "like")
                    
                    // Create notification for comment owner
                    self.createNotification(
                        for: comment.userId,
                        type: "like",
                        commentId: comment.id,
                        triggeredBy: currentUserId,
                        username: self.getCurrentUsername(),
                        userProfileImage: nil
                    )
                }
            }
    }
    
    private func toggleCommentDislike(_ comment: MusicComment) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        let db = Firestore.firestore()
        let interactionId = "\(currentUserId)_\(comment.id)"
        
        // Check if user already disliked this comment
        db.collection("commentInteractions")
            .document(interactionId)
            .getDocument { snapshot, error in
                if let existingInteraction = snapshot?.data(),
                   let interactionType = existingInteraction["interactionType"] as? String {
                    
                    if interactionType == "dislike" {
                        // Remove dislike
                        self.removeCommentInteraction(commentId: comment.id, userId: currentUserId, interactionType: "dislike")
                    } else if interactionType == "like" {
                        // Change like to dislike
                        self.updateCommentInteraction(commentId: comment.id, userId: currentUserId, fromType: "like", toType: "dislike")
                    }
                } else {
                    // Add new dislike
                    self.addCommentInteraction(commentId: comment.id, userId: currentUserId, interactionType: "dislike")
                }
            }
    }
    
    private func addCommentInteraction(commentId: String, userId: String, interactionType: String) {
        let db = Firestore.firestore()
        let interactionId = "\(userId)_\(commentId)"
        
        let interaction = CommentInteraction(
            id: interactionId,
            commentId: commentId,
            userId: userId,
            interactionType: interactionType,
            timestamp: Date()
        )
        
        do {
            try db.collection("commentInteractions").document(interactionId).setData(from: interaction) { error in
                if let error = error {
                    print("❌ Error adding comment interaction: \(error.localizedDescription)")
                } else {
                    print("✅ Added \(interactionType) for comment: \(commentId)")
                    self.refreshComments()
                }
            }
        } catch {
            print("❌ Error creating comment interaction: \(error.localizedDescription)")
        }
    }
    
    private func removeCommentInteraction(commentId: String, userId: String, interactionType: String) {
        let db = Firestore.firestore()
        let interactionId = "\(userId)_\(commentId)"
        
        db.collection("commentInteractions").document(interactionId).delete { error in
            if let error = error {
                print("❌ Error removing comment interaction: \(error.localizedDescription)")
            } else {
                print("✅ Removed \(interactionType) for comment: \(commentId)")
                self.refreshComments()
            }
        }
    }
    
    private func updateCommentInteraction(commentId: String, userId: String, fromType: String, toType: String) {
        let db = Firestore.firestore()
        let interactionId = "\(userId)_\(commentId)"
        
        let interaction = CommentInteraction(
            id: interactionId,
            commentId: commentId,
            userId: userId,
            interactionType: toType,
            timestamp: Date()
        )
        
        do {
            try db.collection("commentInteractions").document(interactionId).setData(from: interaction) { error in
                if let error = error {
                    print("❌ Error updating comment interaction: \(error.localizedDescription)")
                } else {
                    print("✅ Updated interaction from \(fromType) to \(toType) for comment: \(commentId)")
                    self.refreshComments()
                }
            }
        } catch {
            print("❌ Error updating comment interaction: \(error.localizedDescription)")
        }
    }
    
    private func refreshComments() {
        // Reload comments to update interaction states
        loadComments()
    }
    
    private func refreshProfile() {
        loadProfile()
    }
    
    private func loadFriendIds() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snap, _ in
            let ids = (snap?.data()? ["following"] as? [String]) ?? []
            DispatchQueue.main.async {
                self.friendIds = ids
            }
        }
    }

    func refreshData() async {
        await MainActor.run {
            loadProfile()
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Reply Functions
    
    private func showReplySheet(for comment: MusicComment) {
        selectedCommentForReply = comment
        replyText = ""
        showingReplySheet = true
    }
    
    private func submitReply() {
        guard let comment = selectedCommentForReply,
              let currentUserId = Auth.auth().currentUser?.uid,
              !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isSubmittingReply = true
        
        // Get current user profile
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { userSnapshot, userError in
            let username = userSnapshot?.data()?["username"] as? String ?? "Anonymous"
            let userProfileImage = userSnapshot?.data()?["profilePictureUrl"] as? String
            
            let reply = CommentReply(
                id: UUID().uuidString,
                commentId: comment.id,
                userId: currentUserId,
                username: username,
                userProfileImage: userProfileImage,
                reply: replyText.trimmingCharacters(in: .whitespacesAndNewlines),
                timestamp: Date(),
                likes: 0,
                dislikes: 0,
                userLiked: nil,
                userDisliked: nil
            )
            
            // Save reply to Firestore
            do {
                try db.collection("commentReplies").document(reply.id).setData(from: reply) { error in
                    DispatchQueue.main.async {
                        isSubmittingReply = false
                        if let error = error {
                            print("❌ Error saving reply: \(error.localizedDescription)")
                        } else {
                            print("✅ Reply saved successfully")
                            
                            // Create notification for comment owner
                            self.createNotification(
                                for: comment.userId,
                                type: "reply",
                                commentId: comment.id,
                                triggeredBy: currentUserId,
                                username: username,
                                userProfileImage: userProfileImage
                            )
                            
                            showingReplySheet = false
                            replyText = ""
                            selectedCommentForReply = nil
                            refreshComments()
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isSubmittingReply = false
                    print("❌ Error creating reply: \(error.localizedDescription)")
                }
            }
        }
    }

    /* DEPRECATED: Old comment functions
    private func loadMoreComments() {
        let db = Firestore.firestore()
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        guard let last = lastCommentsDoc else { return }
        var q: Query = db.collection("logs")
            .whereField("itemId", isEqualTo: musicItem.id)
            .order(by: "dateLogged", descending: true)
            .start(afterDocument: last)
            .limit(to: 25)
        q.getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let error = error { print("Load more comments error: \(error.localizedDescription)"); return }
                let documents = snapshot?.documents ?? []
                self.lastCommentsDoc = documents.last
                if documents.count < 25 { self.hasMoreComments = false }
                var more: [MusicComment] = []
                let group = DispatchGroup()
                for doc in documents {
                    let data = doc.data()
                    let review = data["review"] as? String ?? ""
                    let comment = data["comment"] as? String ?? ""
                    let actualComment = review.isEmpty ? comment : review
                    let timestamp = (data["dateLogged"] as? Timestamp)?.dateValue() ?? Date()
                    let userId = data["userId"] as? String ?? ""
                    let id = doc.documentID
                    if !actualComment.isEmpty {
                        group.enter()
                        let userDoc = db.collection("users").document(userId)
                        userDoc.getDocument { userSnapshot, _ in
                            let username = userSnapshot?.data()?["username"] as? String ?? "Anonymous"
                            let userProfileImage = userSnapshot?.data()?["profilePictureUrl"] as? String
                            let interactionId = "\(currentUserId)_\(id)"
                            db.collection("commentInteractions").document(interactionId).getDocument { interactionSnapshot, _ in
                                var userLiked: Bool? = nil
                                var userDisliked: Bool? = nil
                                if let interactionData = interactionSnapshot?.data(), let interactionType = interactionData["interactionType"] as? String {
                                    userLiked = interactionType == "like"
                                    userDisliked = interactionType == "dislike"
                                }
                                let musicComment = MusicComment(
                                    id: id,
                                    userId: userId,
                                    username: username,
                                    userProfileImage: userProfileImage,
                                    comment: actualComment,
                                    timestamp: timestamp,
                                    likes: data["likes"] as? Int ?? 0,
                                    dislikes: data["dislikes"] as? Int ?? 0,
                                    userLiked: userLiked,
                                    userDisliked: userDisliked
                                )
                                more.append(musicComment)
                                group.leave()
                            }
                        }
                    }
                }
                group.notify(queue: .main) {
                    self.comments.append(contentsOf: more)
                }
            }
        }
    }
    
    private func toggleReplies(for comment: MusicComment) {
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index].isExpanded.toggle()
        }
    }
    */ // END DEPRECATED COMMENT FUNCTIONS
    
    // MARK: - Reply Row View
    private func replyRow(_ reply: CommentReply, parentComment: MusicComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // User Avatar
                if let profileImage = reply.userProfileImage,
                   let url = URL(string: profileImage) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.caption2)
                        )
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text(reply.username)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        // Show user's rating if available
                        if let userRating = getUserRating(for: reply.userId) {
                            StarRatingDisplayView(
                                rating: Double(userRating),
                                starSize: 10,
                                spacing: 1
                            )
                        }
                    }
                    Text(timeAgoString(from: reply.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            displayTextWithMentions(reply.reply)
                .font(.caption)
                .multilineTextAlignment(.leading)
            
            // Reply Engagement
            HStack(spacing: 12) {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleReplyLike(reply)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: reply.userLiked == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.caption2)
                            .foregroundColor(reply.userLiked == true ? .green : .gray)
                            .scaleEffect(reply.userLiked == true ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: reply.userLiked)
                        Text("\(reply.likes)")
                            .font(.caption2)
                            .foregroundColor(reply.userLiked == true ? .green : .secondary)
                            .fontWeight(reply.userLiked == true ? .semibold : .regular)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleReplyDislike(reply)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: reply.userDisliked == true ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.caption2)
                            .foregroundColor(reply.userDisliked == true ? .red : .gray)
                            .scaleEffect(reply.userDisliked == true ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: reply.userDisliked)
                        Text("\(reply.dislikes)")
                            .font(.caption2)
                            .foregroundColor(reply.userDisliked == true ? .red : .secondary)
                            .fontWeight(reply.userDisliked == true ? .semibold : .regular)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Engagement score indicator
                if reply.engagementScore != 0 {
                    HStack(spacing: 1) {
                        Image(systemName: reply.engagementScore > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundColor(reply.engagementScore > 0 ? .green : .red)
                        Text("\(abs(reply.engagementScore))")
                            .font(.caption2)
                            .foregroundColor(reply.engagementScore > 0 ? .green : .red)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(reply.engagementScore > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
    
    // MARK: - Reply Interaction Functions
    private func toggleReplyLike(_ reply: CommentReply) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        let db = Firestore.firestore()
        let interactionId = "\(currentUserId)_\(reply.id)"
        
        // Check if user already liked this reply
        db.collection("replyInteractions")
            .document(interactionId)
            .getDocument { snapshot, error in
                if let existingInteraction = snapshot?.data(),
                   let interactionType = existingInteraction["interactionType"] as? String {
                    
                    if interactionType == "like" {
                        // Remove like
                        self.removeReplyInteraction(replyId: reply.id, userId: currentUserId, interactionType: "like")
                    } else if interactionType == "dislike" {
                        // Change dislike to like
                        self.updateReplyInteraction(replyId: reply.id, userId: currentUserId, fromType: "dislike", toType: "like")
                    }
                } else {
                    // Add new like
                    self.addReplyInteraction(replyId: reply.id, userId: currentUserId, interactionType: "like")
                }
            }
    }
    
    private func toggleReplyDislike(_ reply: CommentReply) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        let db = Firestore.firestore()
        let interactionId = "\(currentUserId)_\(reply.id)"
        
        // Check if user already disliked this reply
        db.collection("replyInteractions")
            .document(interactionId)
            .getDocument { snapshot, error in
                if let existingInteraction = snapshot?.data(),
                   let interactionType = existingInteraction["interactionType"] as? String {
                    
                    if interactionType == "dislike" {
                        // Remove dislike
                        self.removeReplyInteraction(replyId: reply.id, userId: currentUserId, interactionType: "dislike")
                    } else if interactionType == "like" {
                        // Change like to dislike
                        self.updateReplyInteraction(replyId: reply.id, userId: currentUserId, fromType: "like", toType: "dislike")
                    }
                } else {
                    // Add new dislike
                    self.addReplyInteraction(replyId: reply.id, userId: currentUserId, interactionType: "dislike")
                }
            }
    }
    
    private func addReplyInteraction(replyId: String, userId: String, interactionType: String) {
        let db = Firestore.firestore()
        let interactionId = "\(userId)_\(replyId)"
        
        let interaction = CommentInteraction(
            id: interactionId,
            commentId: replyId, // Using replyId as commentId for consistency
            userId: userId,
            interactionType: interactionType,
            timestamp: Date()
        )
        
        do {
            try db.collection("replyInteractions").document(interactionId).setData(from: interaction) { error in
                if let error = error {
                    print("❌ Error adding reply interaction: \(error.localizedDescription)")
                } else {
                    print("✅ Added \(interactionType) for reply: \(replyId)")
                    self.refreshComments()
                }
            }
        } catch {
            print("❌ Error creating reply interaction: \(error.localizedDescription)")
        }
    }
    
    private func removeReplyInteraction(replyId: String, userId: String, interactionType: String) {
        let db = Firestore.firestore()
        let interactionId = "\(userId)_\(replyId)"
        
        db.collection("replyInteractions").document(interactionId).delete { error in
            if let error = error {
                print("❌ Error removing reply interaction: \(error.localizedDescription)")
            } else {
                print("✅ Removed \(interactionType) for reply: \(replyId)")
                self.refreshComments()
            }
        }
    }
    
    private func updateReplyInteraction(replyId: String, userId: String, fromType: String, toType: String) {
        let db = Firestore.firestore()
        let interactionId = "\(userId)_\(replyId)"
        
        let interaction = CommentInteraction(
            id: interactionId,
            commentId: replyId,
            userId: userId,
            interactionType: toType,
            timestamp: Date()
        )
        
        do {
            try db.collection("replyInteractions").document(interactionId).setData(from: interaction) { error in
                if let error = error {
                    print("❌ Error updating reply interaction: \(error.localizedDescription)")
                } else {
                    print("✅ Updated reply interaction from \(fromType) to \(toType) for reply: \(replyId)")
                    self.refreshComments()
                }
            }
        } catch {
            print("❌ Error updating reply interaction: \(error.localizedDescription)")
        }
    }
    
    private func saveEditedComment() {
        guard let comment = selectedCommentForEdit,
              let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == comment.userId,
              !editCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isEditingComment = true
        
        let db = Firestore.firestore()
        
        // Update the comment in the logs collection
        db.collection("logs").document(comment.id).updateData([
            "review": editCommentText.trimmingCharacters(in: .whitespacesAndNewlines),
            "comment": editCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        ]) { error in
            DispatchQueue.main.async {
                isEditingComment = false
                if let error = error {
                    print("❌ Error updating comment: \(error.localizedDescription)")
                } else {
                    print("✅ Comment updated successfully")
                    showingEditCommentSheet = false
                    editCommentText = ""
                    selectedCommentForEdit = nil
                    refreshComments()
                }
            }
        }
    }
    
    private func deleteComment() {
        guard let comment = commentToDelete,
              let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == comment.userId else {
            return
        }
        
        let db = Firestore.firestore()
        
        // Delete the comment from logs collection
        db.collection("logs").document(comment.id).delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error deleting comment: \(error.localizedDescription)")
                } else {
                    print("✅ Comment deleted successfully")
                    
                    // Also delete all replies to this comment
                    db.collection("commentReplies")
                        .whereField("commentId", isEqualTo: comment.id)
                        .getDocuments { repliesSnapshot, repliesError in
                            if let replies = repliesSnapshot?.documents {
                                let group = DispatchGroup()
                                for reply in replies {
                                    group.enter()
                                    reply.reference.delete { _ in
                                        group.leave()
                                    }
                                }
                                group.notify(queue: .main) {
                                    print("✅ Deleted \(replies.count) replies")
                                    commentToDelete = nil
                                    refreshComments()
                                }
                            } else {
                                commentToDelete = nil
                                refreshComments()
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - User Mentions Functions
    
    private func detectMentions(in text: String) {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var currentIndex = 0
        
        for (wordIndex, word) in words.enumerated() {
            if word.hasPrefix("@") {
                let query = String(word.dropFirst()) // Remove @ symbol
                if !query.isEmpty {
                    currentMentionQuery = query
                    mentionStartIndex = currentIndex
                    searchUsers(query: query)
                    showingMentionSuggestions = true
                    return
                }
            }
            currentIndex += word.count + 1 // +1 for space
        }
        
        // No mention detected
        showingMentionSuggestions = false
    }
    
    private func searchUsers(query: String) {
        let db = Firestore.firestore()
        
        // Search users by username (case-insensitive)
        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThan: query + "\u{f8ff}")
            .limit(to: 5)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error searching users: \(error.localizedDescription)")
                        self.mentionSuggestions = []
                        return
                    }
                    
                    let usernames = snapshot?.documents.compactMap { doc in
                        doc.data()["username"] as? String
                    } ?? []
                    
                    // Filter out current user and limit results
                    let currentUserId = Auth.auth().currentUser?.uid
                    self.mentionSuggestions = usernames.filter { username in
                        username.lowercased().contains(query.lowercased()) &&
                        username != self.getCurrentUsername()
                    }.prefix(5).map { $0 }
                    
                    print("🔍 Found \(self.mentionSuggestions.count) users for query: '\(query)'")
                }
            }
    }
    
    private func getCurrentUsername() -> String {
        // This would ideally come from user profile, but for now return a placeholder
        // In a real app, you'd fetch this from the user's profile
        return "CurrentUser"
    }
    
    private func insertMention(_ username: String, into text: String) -> String {
        let mention = "@\(username) "
        
        // Find the last @ symbol and replace everything from there
        if let lastAtIndex = text.lastIndex(of: "@") {
            let beforeMention = String(text[..<lastAtIndex])
            return beforeMention + mention
        }
        
        return text + mention
    }
    
    private func processMentions(in text: String) -> String {
        // This function would process mentions for storage/display
        // For now, just return the text as-is
        return text
    }
    
    private func displayTextWithMentions(_ text: String) -> some View {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                if word.hasPrefix("@") {
                    Button(action: {
                        // Navigate to user profile (placeholder for now)
                        print("📱 Navigate to user profile: \(word)")
                    }) {
                        Text(word)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Text(word)
                }
                
                if index < words.count - 1 {
                    Text(" ")
                }
            }
        }
    }
    
    // MARK: - Notification Functions
    
    private func loadNotifications() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingNotifications = true
        let db = Firestore.firestore()
        
        db.collection("commentNotifications")
            .whereField("targetUserId", isEqualTo: currentUserId)
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoadingNotifications = false
                    
                    if let error = error {
                        print("❌ Error loading notifications: \(error.localizedDescription)")
                        return
                    }
                    
                    let notifications = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: CommentNotification.self)
                    } ?? []
                    
                    self.notifications = notifications
                    print("✅ Loaded \(notifications.count) notifications")
                }
            }
    }
    
    private func createNotification(
        for targetUserId: String,
        type: String,
        commentId: String,
        triggeredBy userId: String,
        username: String,
        userProfileImage: String?
    ) {
        guard targetUserId != userId else { return } // Don't notify yourself
        
        let notification = CommentNotification(
            id: UUID().uuidString,
            userId: userId,
            username: username,
            userProfileImage: userProfileImage,
            targetUserId: targetUserId,
            commentId: commentId,
            songTitle: musicItem.title,
            songArtist: musicItem.artistName,
            notificationType: type,
            timestamp: Date(),
            isRead: false
        )
        
        let db = Firestore.firestore()
        do {
            try db.collection("commentNotifications").document(notification.id).setData(from: notification) { error in
                if let error = error {
                    print("❌ Error creating notification: \(error.localizedDescription)")
                } else {
                    print("✅ Created \(type) notification for user: \(targetUserId)")
                }
            }
        } catch {
            print("❌ Error creating notification: \(error.localizedDescription)")
        }
    }
    
    private func markAllNotificationsAsRead() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for notification in notifications where !notification.isRead {
            let ref = db.collection("commentNotifications").document(notification.id)
            batch.updateData(["isRead": true], forDocument: ref)
        }
        
        batch.commit { error in
            if let error = error {
                print("❌ Error marking notifications as read: \(error.localizedDescription)")
            } else {
                print("✅ Marked all notifications as read")
                loadNotifications() // Refresh the list
            }
        }
    }
    
    private func notificationRow(_ notification: CommentNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            if let profileImage = notification.userProfileImage,
               let url = URL(string: profileImage) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(notification.displayText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text("on \(notification.songTitle) by \(notification.songArtist)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(timeAgoString(from: notification.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tracklist Section
extension MusicProfileView {
    private var tracklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tracklist")
                    .font(.headline)
                Spacer()
                Text("\(albumTracks.count) songs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(action: {
                    loadAlbumTracks()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if isLoadingTracks {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading tracks...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if albumTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No tracks available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Track information not available for this album")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(albumTracks.enumerated()), id: \.element.id) { index, track in
                        trackRow(track, trackNumber: index + 1)
                    }
                }
            }
        }
    }
    
    private func trackRow(_ track: MusicSearchResult, trackNumber: Int) -> some View {
        NavigationLink(destination: MusicProfileView(musicItem: track, pinnedLog: nil)) {
            HStack(spacing: 12) {
                // Track number
                Text("\(trackNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !track.artistName.isEmpty {
                        Text(track.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Track rating
                let avg = trackRatings[track.id] ?? 0.0
                StarRatingDisplayView(
                    rating: avg,
                    starSize: 10,
                    spacing: 1
                )
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func loadAlbumTracks() {
        guard musicItem.itemType == "album" else { return }
        
        isLoadingTracks = true
        print("🎵 Loading tracks for album: \(musicItem.title) by \(musicItem.artistName)")
        
        Task {
            do {
                var foundTracks: [MusicSearchResult] = []
                
                // Strategy 1: Try to get the exact album using the album ID from musicItem
                let albumID = MusicItemID(musicItem.id)
                print("🎵 Attempting to fetch album with ID: \(albumID)")
                
                // Request the album with tracks relationship explicitly
                let albumRequest = MusicCatalogResourceRequest<MusicKit.Album>(matching: \.id, equalTo: albumID)
                let albumResponse = try await albumRequest.response()
                
                if let album = albumResponse.items.first {
                    print("✅ Found album: \(album.title) by \(album.artistName)")
                    
                    // Try multiple approaches to get tracks
                    foundTracks = await getTracksForAlbum(album: album)
                    
                    if foundTracks.isEmpty {
                        print("⚠️ No tracks found with direct methods, trying fallback approach")
                        foundTracks = await searchForAlbumTracks(album: album)
                    }
                } else {
                    print("⚠️ Album not found with ID, trying search approach")
                    foundTracks = await searchForAlbumTracks(album: nil)
                }
                
                await MainActor.run {
                    self.albumTracks = foundTracks
                    self.isLoadingTracks = false
                    self.trackRatings = [:]
                    Task { await self.loadTrackRatings() }
                    print("📱 Updated UI with \(foundTracks.count) tracks")
                }
                
            } catch {
                print("❌ Error loading album tracks: \(error)")
                await MainActor.run {
                    self.albumTracks = []
                    self.isLoadingTracks = false
                }
            }
        }
    }
    
    private func getTracksForAlbum(album: MusicKit.Album) async -> [MusicSearchResult] {
        print("🎵 Attempting to get tracks for: \(album.title) by \(album.artistName)")
        
        do {
            // Method 1: Try to get tracks using the album's tracks property directly
            if let directTracks = album.tracks, !directTracks.isEmpty {
                print("✅ Found \(directTracks.count) tracks directly from album.tracks")
                let albumTracks = directTracks.map { track in
                    MusicSearchResult(
                        id: track.id.rawValue,
                        title: track.title,
                        artistName: track.artistName,
                        albumName: album.title,
                        artworkURL: track.artwork?.url(width: 100, height: 100)?.absoluteString,
                        itemType: "song",
                        popularity: 0
                    )
                }
                print("🎵 Returning \(albumTracks.count) tracks from album.tracks")
                return albumTracks
            }
            
            // Method 1.5: Attempt to fetch missing relationship via .with(\.tracks)
            do {
                let detailedAlbum = try await album.with(.tracks)
                if let relTracks = detailedAlbum.tracks, !relTracks.isEmpty {
                    print("✅ Loaded \(relTracks.count) tracks via album.with(\\.tracks)")
                    let albumTracks = relTracks.map { track in
                        MusicSearchResult(
                            id: track.id.rawValue,
                            title: track.title,
                            artistName: track.artistName,
                            albumName: album.title,
                            artworkURL: track.artwork?.url(width: 100, height: 100)?.absoluteString,
                            itemType: "song",
                            popularity: 0
                        )
                    }
                    return albumTracks
                }
            } catch {
                print("⚠️ Failed to load tracks via album.with(\\.tracks): \(error)")
            }
            
            // Method 2: Search for songs with album-specific criteria
            print("🎵 Trying search-based approach for album tracks")
            let searchTerm = "\(album.title) \(album.artistName)"
            var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Song.self])
            searchRequest.limit = 25
            let searchResponse = try await searchRequest.response()
            
            // Filter songs to only include those from this specific album
            let albumTracks = searchResponse.songs.filter { song in
                // Artist must match exactly
                let artistMatch = song.artistName.lowercased() == album.artistName.lowercased()
                
                // Song title should not be the album title (to avoid false positives)
                let titleNotAlbum = song.title.lowercased() != album.title.lowercased()
                
                return artistMatch && titleNotAlbum
            }
            
            if !albumTracks.isEmpty {
                print("✅ Found \(albumTracks.count) tracks using search approach")
                
                let tracks = albumTracks.map { song in
                    MusicSearchResult(
                        id: song.id.rawValue,
                        title: song.title,
                        artistName: song.artistName,
                        albumName: song.albumTitle ?? "",
                        artworkURL: song.artwork?.url(width: 100, height: 100)?.absoluteString,
                        itemType: "song",
                        popularity: 0
                    )
                }
                
                print("🎵 Returning \(tracks.count) tracks from search approach")
                return tracks
            } else {
                print("⚠️ No tracks found with any method")
                return []
            }
            
        } catch {
            print("❌ Error getting album tracks: \(error)")
            return []
        }
    }
    
    private func searchForAlbumTracks(album: MusicKit.Album?) async -> [MusicSearchResult] {
        var foundTracks: [MusicSearchResult] = []
        
        // More precise search strategies
        let searchStrategies = [
            "\(musicItem.title) \(musicItem.artistName) album",
            "\(musicItem.artistName) \(musicItem.title) album",
            "\(musicItem.title) \(musicItem.artistName)"
        ]
        
        for strategy in searchStrategies {
            do {
                print("🔍 Trying search strategy: \(strategy)")
                
                // First, try to find the exact album
                var albumSearchRequest = MusicCatalogSearchRequest(term: strategy, types: [MusicKit.Album.self])
                albumSearchRequest.limit = 5
                let albumSearchResponse = try await albumSearchRequest.response()
                
                // Find the most matching album
                let matchingAlbum = albumSearchResponse.albums.first { album in
                    let titleMatch = album.title.lowercased().contains(musicItem.title.lowercased()) ||
                                   musicItem.title.lowercased().contains(album.title.lowercased())
                    let artistMatch = album.artistName.lowercased().contains(musicItem.artistName.lowercased()) ||
                                   musicItem.artistName.lowercased().contains(album.artistName.lowercased())
                    return titleMatch && artistMatch
                }
                
                if let album = matchingAlbum {
                    print("🎵 Found matching album: \(album.title) by \(album.artistName)")
                    
                    // Now search for songs from this specific album
                    let albumSongsSearch = "\(album.title) \(album.artistName)"
                    var songsSearchRequest = MusicCatalogSearchRequest(term: albumSongsSearch, types: [MusicKit.Song.self])
                    songsSearchRequest.limit = 25
                    let songsResponse = try await songsSearchRequest.response()
                    
                                         // Filter songs to only include those from this specific album
                     let albumSongs = songsResponse.songs.filter { song in
                         let artistMatch = song.artistName.lowercased().contains(album.artistName.lowercased()) ||
                                         album.artistName.lowercased().contains(song.artistName.lowercased())
                         
                         // More strict filtering - song should be from this album
                         // Since song.albumName doesn't exist, we'll use title matching as a proxy
                         let titleMatch = song.title.lowercased().contains(album.title.lowercased()) ||
                                        album.title.lowercased().contains(song.title.lowercased())
                         
                         return artistMatch && titleMatch
                     }
                    
                    if !albumSongs.isEmpty {
                        print("🎵 Found \(albumSongs.count) tracks from album")
                        
                        // Remove duplicates and sort by track number if available
                        let uniqueSongs = Array(Set(albumSongs.map { $0.title })).compactMap { title in
                            albumSongs.first { $0.title == title }
                        }
                        
                        foundTracks = uniqueSongs.map { song in
                            print("🎼 Found track: \(song.title) by \(song.artistName)")
                            return MusicSearchResult(
                                id: song.id.rawValue,
                                title: song.title,
                                artistName: song.artistName,
                                albumName: song.albumTitle ?? "",
                                artworkURL: song.artwork?.url(width: 100, height: 100)?.absoluteString,
                                itemType: "song",
                                popularity: 0
                            )
                        }
                        
                        // Limit to reasonable number of tracks
                        if foundTracks.count > 30 {
                            foundTracks = Array(foundTracks.prefix(30))
                        }
                        
                        break // Use first successful strategy
                    }
                }
            } catch {
                print("❌ Error with search strategy '\(strategy)': \(error)")
                continue
            }
        }
        
        return foundTracks
    }
    
    // MARK: - Track Ratings Loader
    private func loadTrackRatings() async {
        let db = Firestore.firestore()
        var final: [String: Double] = [:]
        
        await withTaskGroup(of: (String, Double).self) { group in
            for track in albumTracks {
                group.addTask {
                    let average = await fetchAverageRating(for: track, db: db)
                    return (track.id, average)
                }
            }
            
            for await (id, avg) in group {
                final[id] = avg
            }
        }
        
        await MainActor.run {
            self.trackRatings = final
            self.trackRatingsLoadedIds = Set(albumTracks.map { $0.id })
        }
    }
    
    private func fetchAverageRating(for track: MusicSearchResult, db: Firestore) async -> Double {
        do {
            // Prefer universal track ID for cross-platform aggregation
            if let universalId = await getUniversalTrackId(
                itemId: track.id,
                title: track.title,
                artistName: track.artistName,
                albumName: track.albumName
            ) {
                if let avg = try await averageRating(universalTrackId: universalId, db: db) {
                    return avg
                }
            }
            
            // Fallback to itemId/itemType
            if let avg = try await averageRating(itemId: track.id, itemType: track.itemType, db: db) {
                return avg
            }
        } catch {
            print("❌ Error fetching rating for track \(track.title): \(error)")
        }
        
        return 0.0
    }
    
    private func averageRating(universalTrackId: String, db: Firestore) async throws -> Double? {
        let snapshot = try await db.collection("logs")
            .whereField("universalTrackId", isEqualTo: universalTrackId)
            .getDocuments()
        return computeAverage(from: snapshot)
    }
    
    private func averageRating(itemId: String, itemType: String, db: Firestore) async throws -> Double? {
        let snapshot = try await db.collection("logs")
            .whereField("itemId", isEqualTo: itemId)
            .whereField("itemType", isEqualTo: itemType)
            .getDocuments()
        return computeAverage(from: snapshot)
    }
    
    private func computeAverage(from snapshot: QuerySnapshot) -> Double? {
        var total = 0.0
        var count = 0
        for doc in snapshot.documents {
            let data = doc.data()
            if let rating = data["rating"] as? Double {
                total += rating
                count += 1
            } else if let ratingInt = data["rating"] as? Int {
                total += Double(ratingInt)
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return total / Double(count)
    }
    
    /// Get universal track ID for cross-platform rating aggregation
    private func getUniversalTrackId(
        itemId: String,
        title: String,
        artistName: String,
        albumName: String?
    ) async -> String? {
        let universalTrack = await TrackMatchingService.shared.getUniversalTrack(
            title: title,
            artist: artistName,
            albumName: albumName,
            appleMusicId: itemId
        )
        return universalTrack.id
    }

    private func navigateToSongProfile(_ track: MusicSearchResult) {
        // Present the song's profile view
        // This will be handled by the parent view that presents MusicProfileView
        // For now, we'll print the action
        print("🎵 Navigate to song profile: \(track.title) by \(track.artistName)")
        
        // TODO: Implement navigation to song profile
        // This would typically involve presenting a new MusicProfileView for the track
    }

    
    // MARK: - Listen Later Integration
    private func addItemToListenLater() {
        print("🎯 addItemToListenLater called for: \(musicItem.title)")
        guard !isAddingToListenLater else { 
            print("⚠️ Already adding to listen later, ignoring request")
            return 
        }
        
        isAddingToListenLater = true
        print("🔄 Starting listen later process...")
        
        Task {
            // Determine the item type for Listen Later
            let itemType: ListenLaterItemType
            switch musicItem.itemType.lowercased() {
            case "album":
                itemType = .album
            case "artist":
                itemType = .artist
            default:
                itemType = .song
            }
            
            print("📝 Item details:")
            print("   Title: \(musicItem.title)")
            print("   Artist: \(musicItem.artistName)")
            print("   ID: \(musicItem.id)")
            print("   Type: \(itemType.rawValue)")
            print("   Artwork: \(musicItem.artworkURL ?? "nil")")
            
            // Add to Listen Later using the service
            let success = await ListenLaterService.shared.addItem(musicItem, type: itemType)
            
            await MainActor.run {
                isAddingToListenLater = false
                if success {
                    print("✅ Successfully added to Listen Later!")
                    listenLaterSuccess = true
                    // Show success feedback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        listenLaterSuccess = false
                    }
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Trigger service refresh to update UI immediately
                    ListenLaterService.shared.refreshAllSections()
                } else {
                    print("❌ Failed to add to Listen Later")
                }
            }
            
            print("✅ \(musicItem.itemType.capitalized) '\(musicItem.title)' added to Listen Later: \(success)")
        }
    }
    
    // MARK: - Universal Profile Loading
    
    private func loadUniversalProfile() {
        guard musicItem.itemType == "song" else { return } // Only for songs initially
        
        isLoadingUniversalProfile = true
        
        Task {
            let profile = await UniversalMusicProfileService.shared.loadUniversalProfileBySearch(
                title: musicItem.title,
                artist: musicItem.artistName,
                platformId: musicItem.id,
                platform: "apple_music" // TODO: Detect actual platform
            )
            
            await MainActor.run {
                self.universalProfile = profile
                self.isLoadingUniversalProfile = false
                
                if let profile = profile {
                    print("🌍 Loaded universal profile: \(profile.title)")
                    print("   Total ratings: \(profile.totalRatings)")
                    print("   Average rating: \(String(format: "%.1f", profile.averageRating))")
                    print("   Platform distribution: \(profile.platformDistribution)")
                }
            }
        }
    }
} 
