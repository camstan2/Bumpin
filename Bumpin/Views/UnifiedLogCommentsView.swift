import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Unified Log Comments View

struct UnifiedLogCommentsView: View {
    let log: MusicLog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var comments: [CommentWithReplies] = []
    @State private var isLoading = false
    @State private var commentText = ""
    @State private var sortOption: CommentSortOption = .mostPopular
    @State private var showingSortMenu = false
    @State private var replyingTo: CommentWithReplies?
    @State private var userProfile: UserProfile?
    @State private var userRatingsMap: [String: Double] = [:] // userId -> rating
    @State private var currentUserAvatarUrl: String?
    
    // Log engagement state
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var hasThumbsDown: Bool = false
    @State private var thumbsDownCount: Int = 0
    @State private var hasReposted: Bool = false
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    @State private var repostCount: Int = 0
    @State private var showActivity = false
    
    // Mention state
    @State private var mentionSuggestions: [MentionSuggestion] = []
    @State private var showMentionSuggestions = false
    @State private var currentMentionQuery = ""
    @State private var mentionStartIndex: String.Index?
    
    // Focus state for auto-focus keyboard
    @FocusState private var isCommentFieldFocused: Bool
    
    // Profile navigation state
    @State private var selectedProfileUserId: String?
    @State private var selectedProfile: UserProfile?
    @State private var showUserProfile = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        // Log Header
                        logHeaderSection
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                        
                        Divider()
                            .padding(.vertical, 12)
                        
                        // Sort toggle
                        sortToggleSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        
                        // Comments list
                        if isLoading && comments.isEmpty {
                            loadingView
                        } else if comments.isEmpty {
                            emptyCommentsView
                        } else {
                            commentsListView
                        }
                    }
                }
                // Allow tap anywhere in the content area to dismiss the keyboard
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            isCommentFieldFocused = false
                        }
                )
                
                Divider()
                
                // Fixed bottom comment input
                commentInputSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .foregroundColor(.blue)
                    }
                }
            }
            .onAppear {
                loadUserProfile()
                loadComments()
                loadLogEngagement()
            }
            .fullScreenCover(isPresented: $showActivity) {
                LogActivityView(logId: log.id, log: log)
            }
            .fullScreenCover(isPresented: $showUserProfile) {
                if let userId = selectedProfileUserId {
                    UserProfileView(
                        userId: userId,
                        showFullProfile: false,
                        prefetchedProfile: selectedProfile,
                        showDismissButton: true
                    )
                    .onDisappear {
                        showUserProfile = false
                    }
                }
            }
            .sheet(isPresented: $showReportSheet) {
                ReportContentView(
                    contentId: log.id,
                    contentType: .musicReview,
                    reportedUserId: log.userId,
                    reportedUsername: userProfile?.username ?? "user",
                    contentPreview: log.title
                )
            }
            .sheet(isPresented: $showBlockSheet) {
                BlockUserView(
                    userId: log.userId,
                    username: userProfile?.username ?? "user",
                    profilePictureUrl: userProfile?.profilePictureUrl
                )
            }
        }
    }
    
    // MARK: - Log Header Section
    
    private var logHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info and navigation
            HStack(spacing: 12) {
                // User avatar
                AsyncImage(url: URL(string: userProfile?.profilePictureUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Group {
                        if userProfile?.profilePictureUrl == nil {
                            Text(String(userProfile?.username.prefix(1) ?? "U").uppercased())
                                .font(.headline)
                                .foregroundColor(.purple)
                        }
                    }
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Username
                    Text(userProfile?.username ?? "User")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Star rating + time
                    HStack(spacing: 8) {
                        if let rating = log.rating {
                            StarRatingDisplayView(
                                rating: rating,
                                starSize: 14,
                                spacing: 1
                            )
                        }
                        
                        Text(timeAgoString(from: log.dateLogged))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()

                // Report / Block menu for the log
                Menu {
                    ReportMenuButton(
                        contentId: log.id,
                        contentType: .musicReview,
                        reportedUserId: log.userId,
                        reportedUsername: userProfile?.username ?? "user",
                        contentPreview: log.title,
                        onReport: { showReportSheet = true },
                        onBlock: { showBlockSheet = true }
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                openUserProfile(userId: log.userId, prefetchedProfile: userProfile)
            }
            
            // Song/Album info
            HStack(spacing: 12) {
                // Artwork
                AsyncImage(url: URL(string: log.artworkUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(log.artistName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Review text (full, no truncation)
            if let review = log.review, !review.isEmpty {
                Text(review)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Engagement buttons
            HStack(spacing: 20) {
                // Like button
                Button(action: { 
                    HapticManager.impact(style: isLiked ? .light : .medium)
                    toggleLike() 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                            .symbolEffect(.bounce, value: isLiked)
                        Text("\(likeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                .scaleEffect(isLiked ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                .animation(.smooth, value: likeCount)
                
                // Comment count (non-interactive, just shows count)
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.secondary)
                    Text("\(log.commentCount ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Thumbs down
                Button(action: { 
                    HapticManager.impact(style: .medium)
                    toggleThumbsDown() 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: hasThumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .foregroundColor(hasThumbsDown ? .orange : .secondary)
                            .symbolEffect(.bounce, value: hasThumbsDown)
                        if thumbsDownCount > 0 {
                            Text("\(thumbsDownCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .scaleEffect(hasThumbsDown ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasThumbsDown)
                .animation(.smooth, value: thumbsDownCount)
                
                // Repost
                Button(action: { 
                    HapticManager.impact(style: hasReposted ? .light : .medium)
                    handleRepost() 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(hasReposted ? .green : .secondary)
                            .symbolEffect(.bounce, value: hasReposted)
                        if repostCount > 0 {
                            Text("\(repostCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .scaleEffect(hasReposted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasReposted)
                .animation(.smooth, value: repostCount)
                
                Spacer()
                
                // View Activity button
                Button(action: { 
                    HapticManager.impact(style: .light)
                    showActivity = true 
                }) {
                    Text("View Activity")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
            }
            .font(.body)
        }
        .contextMenu {
            Button {
                showReportSheet = true
            } label: {
                Label("Report", systemImage: "flag")
            }
        }
    }
    
    // MARK: - Sort Toggle Section
    
    private var sortToggleSection: some View {
        HStack {
            Text("Comments")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            // Sort menu button
            Menu {
                Button(action: { sortOption = .mostPopular }) {
                    HStack {
                        Text("Most Popular")
                        if sortOption == .mostPopular {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: { sortOption = .mostRecent }) {
                    HStack {
                        Text("Most Recent")
                        if sortOption == .mostRecent {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOption.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.purple)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private func openUserProfile(userId: String, prefetchedProfile: UserProfile? = nil) {
        selectedProfileUserId = userId
        selectedProfile = prefetchedProfile
        showUserProfile = true
    }
    
    // MARK: - Comments List View
    
    private var commentsListView: some View {
        LazyVStack(spacing: 16) {
            ForEach(sortedComments) { commentWithReplies in
                CommentRowView(
                    comment: commentWithReplies,
                    userRating: userRatingsMap[commentWithReplies.comment.userId],
                    logItemId: log.itemId,
                    onLike: { likeComment(commentWithReplies.comment) },
                    onReply: { replyToComment(commentWithReplies) },
                    onShowReplies: { toggleReplies(for: commentWithReplies) },
                    onUserTap: { userId in
                        openUserProfile(userId: userId)
                    }
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty Comments View
    
    private var emptyCommentsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No comments yet. Be the first!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading comments...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Comment Input Section
    
    private var commentInputSection: some View {
        VStack(spacing: 0) {
            // Mention suggestions list
            if showMentionSuggestions && !mentionSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(mentionSuggestions) { suggestion in
                            Button(action: {
                                insertMention(suggestion)
                            }) {
                                HStack(spacing: 8) {
                                    // Profile picture
                                    AsyncImage(url: URL(string: suggestion.profilePictureUrl ?? "")) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        default:
                                            Circle()
                                                .fill(Color.purple.opacity(0.2))
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                                    .overlay(
                                        Group {
                                            if suggestion.profilePictureUrl == nil {
                                                Text(String(suggestion.username.prefix(1)).uppercased())
                                                    .font(.caption)
                                                    .foregroundColor(.purple)
                                            }
                                        }
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.username)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        if suggestion.displayName != suggestion.username {
                                            Text(suggestion.displayName)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
                
                Divider()
            }
            
            // Comment input field
            HStack(spacing: 12) {
                // User avatar (small)
                AsyncImage(url: URL(string: currentUserAvatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(
                    Group {
                        if currentUserAvatarUrl == nil {
                            Text(String(Auth.auth().currentUser?.displayName?.prefix(1) ?? "U").uppercased())
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                )
                
                // Text field
                TextField("Add a comment...", text: $commentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isCommentFieldFocused)
                    .onChange(of: commentText) { oldValue, newValue in
                        handleTextChange(newValue)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button(action: {
                                // Insert @ at cursor position
                                commentText += "@"
                                handleTextChange(commentText)
                            }) {
                                Text("@")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                    .frame(width: 44, height: 44)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                        }
                    }
                
                // Send button
                Button(action: { submitComment() }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(commentText.isEmpty ? .gray : .purple)
                        .font(.system(size: 20))
                }
                .disabled(commentText.isEmpty)
            }
            .onAppear {
                loadCurrentUserAvatarIfNeeded()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var sortedComments: [CommentWithReplies] {
        switch sortOption {
        case .mostPopular:
            return comments.sorted { $0.engagementScore > $1.engagementScore }
        case .mostRecent:
            return comments.sorted { $0.comment.timestamp > $1.comment.timestamp }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadUserProfile() {
        let userId = log.userId
        
        Task {
            let db = Firestore.firestore()
            do {
                let doc = try await db.collection("users").document(userId).getDocument()
                if let profile = try? doc.data(as: UserProfile.self) {
                    await MainActor.run {
                        self.userProfile = profile
                    }
                }
            } catch {
                print("❌ Error loading user profile: \(error)")
            }
        }
    }
    
    private func loadComments() {
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            let db = Firestore.firestore()
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                await MainActor.run { isLoading = false }
                return
            }
            
            do {
                // Load comments for this log
                let snapshot = try await db.collection("logs")
                    .document(log.id)
                    .collection("comments")
                    .order(by: "timestamp", descending: false)
                    .getDocuments()
                
                var loadedComments: [CommentWithReplies] = []
                
                for doc in snapshot.documents {
                    if var comment = try? doc.data(as: MusicComment.self) {
                        // Check if current user liked this comment
                        let likeDoc = try await db.collection("logs")
                            .document(log.id)
                            .collection("comments")
                            .document(comment.id)
                            .collection("likes")
                            .document(currentUserId)
                            .getDocument()
                        
                        comment.userLiked = likeDoc.exists
                        
                        // Load replies for this comment
                        let repliesSnapshot = try await db.collection("logs")
                            .document(log.id)
                            .collection("comments")
                            .document(comment.id)
                            .collection("replies")
                            .order(by: "timestamp", descending: false)
                            .getDocuments()
                        
                        let replies = repliesSnapshot.documents.compactMap { try? $0.data(as: CommentReply.self) }
                        
                        loadedComments.append(CommentWithReplies(
                            comment: comment,
                            replies: replies,
                            showingReplies: false
                        ))
                    }
                }
                
                // Load user ratings for all commenters
                let userIds = Set(loadedComments.map { $0.comment.userId })
                await loadUserRatings(for: Array(userIds))
                
                await MainActor.run {
                    self.comments = loadedComments
                    self.isLoading = false
                }
                
            } catch {
                print("❌ Error loading comments: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadUserRatings(for userIds: [String]) async {
        let db = Firestore.firestore()
        
        for userId in userIds {
            do {
                let snapshot = try await db.collection("logs")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("itemId", isEqualTo: log.itemId)
                    .limit(to: 1)
                    .getDocuments()
                
                if let userLog = snapshot.documents.first,
                   let rating = userLog.data()["rating"] as? Double {
                    await MainActor.run {
                        userRatingsMap[userId] = rating
                    }
                }
            } catch {
                print("❌ Error loading rating for user \(userId): \(error)")
            }
        }
    }

    // Load the current user's profile picture for the input avatar
    private func loadCurrentUserAvatarIfNeeded() {
        guard currentUserAvatarUrl == nil, let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            let db = Firestore.firestore()
            do {
                let doc = try await db.collection("users").document(uid).getDocument()
                if let profile = try? doc.data(as: UserProfile.self),
                   let url = profile.profilePictureUrl {
                    await MainActor.run {
                        self.currentUserAvatarUrl = url
                    }
                }
            } catch {
                print("❌ Error loading current user avatar: \(error)")
            }
        }
    }
    
    private func loadLogEngagement() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Set initial counts from log (will be updated with fresh data from Firestore)
        likeCount = log.likeCount ?? 0
        thumbsDownCount = log.thumbsDownCount ?? 0
        repostCount = log.repostCount ?? 0
        
        // Fetch latest counts and user engagement status from Firestore
        Task {
            let db = Firestore.firestore()
            
            // Fetch the latest log document to get accurate counts
            do {
                let logDoc = try await db.collection("logs").document(log.id).getDocument()
                if let data = logDoc.data() {
                    let freshLikeCount = data["likeCount"] as? Int ?? 0
                    let freshThumbsDownCount = data["thumbsDownCount"] as? Int ?? 0
                    let freshRepostCount = data["repostCount"] as? Int ?? 0
                    
                    await MainActor.run {
                        self.likeCount = freshLikeCount
                        self.thumbsDownCount = freshThumbsDownCount
                        self.repostCount = freshRepostCount
                    }
                    
                    print("📊 [loadLogEngagement] Fresh counts - likes: \(freshLikeCount), thumbsDown: \(freshThumbsDownCount), reposts: \(freshRepostCount)")
                }
            } catch {
                print("⚠️ [loadLogEngagement] Could not fetch fresh counts: \(error.localizedDescription)")
                // Continue with stale counts from log object
            }
            
            // Check for like
            let likeDoc = try? await db.collection("logs")
                .document(log.id)
                .collection("likes")
                .document(currentUserId)
                .getDocument()
            
            // Check for thumbs down
            let thumbsDownDoc = try? await db.collection("logs")
                .document(log.id)
                .collection("thumbsDown")
                .document(currentUserId)
                .getDocument()
            
            // Check for repost
            let repostDoc = try? await db.collection("logs")
                .document(log.id)
                .collection("reposts")
                .document(currentUserId)
                .getDocument()
            
            await MainActor.run {
                self.isLiked = likeDoc?.exists ?? false
                self.hasThumbsDown = thumbsDownDoc?.exists ?? false
                self.hasReposted = repostDoc?.exists ?? false
            }
        }
    }
    
    // MARK: - Actions
    
    private func submitComment() {
        guard !commentText.isEmpty,
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let db = Firestore.firestore()
            
            // Fetch actual username from Firestore
            guard let userDoc = try? await db.collection("users").document(currentUserId).getDocument(),
                  let username = userDoc.data()?["username"] as? String else {
                print("❌ Error: Could not fetch username")
                return
            }
            
            do {
                if let replyingTo = replyingTo {
                    // Submit as reply
                    let reply = CommentReply(
                        id: UUID().uuidString,
                        commentId: replyingTo.comment.id,
                        userId: currentUserId,
                        username: username,
                        userProfileImage: nil,
                        reply: commentText,
                        timestamp: Date(),
                        likes: 0,
                        dislikes: 0,
                        userLiked: nil,
                        userDisliked: nil
                    )
                    
                    try db.collection("logs")
                        .document(log.id)
                        .collection("comments")
                        .document(replyingTo.comment.id)
                        .collection("replies")
                        .document(reply.id)
                        .setData(from: reply)
                    
                } else {
                    // Submit as new comment
                    let comment = MusicComment(
                        id: UUID().uuidString,
                        userId: currentUserId,
                        username: username,
                        userProfileImage: nil,
                        comment: commentText,
                        timestamp: Date(),
                        likes: 0,
                        dislikes: 0,
                        userLiked: nil,
                        userDisliked: nil,
                        replies: [],
                        isExpanded: false
                    )
                    
                    try db.collection("logs")
                        .document(log.id)
                        .collection("comments")
                        .document(comment.id)
                        .setData(from: comment)
                    
                    // Update comment count
                    try await db.collection("logs")
                        .document(log.id)
                        .updateData(["commentCount": FieldValue.increment(Int64(1))])
                    
                    // Create comment notification (only for new comments, not replies)
                    await NotificationService.shared.createCommentNotification(
                        logId: log.id,
                        logOwnerId: log.userId,
                        log: log,
                        commentText: commentText
                    )
                }
                
                // Send mention notifications
                let contentType = replyingTo != nil ? "reply" : "comment"
                let contentId = replyingTo != nil ? (replyingTo?.comment.id ?? "") : ""
                
                await MentionService.shared.sendMentionNotifications(
                    text: commentText,
                    contentType: contentType,
                    contentId: contentId,
                    logId: log.id,
                    logTitle: log.title,
                    logArtist: log.artistName,
                    mentionerUserId: currentUserId,
                    mentionerUsername: username,
                    mentionerProfilePicture: userProfile?.profilePictureUrl
                )
                
                await MainActor.run {
                    commentText = ""
                    self.replyingTo = nil
                }
                
                // Reload comments
                loadComments()
                
            } catch {
                print("❌ Error submitting comment: \(error)")
            }
        }
    }
    
    private func likeComment(_ comment: MusicComment) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let db = Firestore.firestore()
            let likeRef = db.collection("logs")
                .document(log.id)
                .collection("comments")
                .document(comment.id)
                .collection("likes")
                .document(currentUserId)
            
            do {
                // Check if already liked
                let likeDoc = try await likeRef.getDocument()
                
                if likeDoc.exists {
                    // Unlike - delete the like
                    try await likeRef.delete()
                    
                    // Decrement like count
                    try await db.collection("logs")
                        .document(log.id)
                        .collection("comments")
                        .document(comment.id)
                        .updateData([
                            "likes": FieldValue.increment(Int64(-1))
                        ])
                    
                    // Update local state immediately
                    await MainActor.run {
                        if let index = comments.firstIndex(where: { $0.comment.id == comment.id }) {
                            comments[index].comment.userLiked = false
                            comments[index].comment.likes = max(0, comments[index].comment.likes - 1)
                        }
                    }
                    
                    print("✅ Comment unliked: \(comment.id)")
                } else {
                    // Like - create the like
                    try await likeRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    
                    // Increment like count
                    try await db.collection("logs")
                        .document(log.id)
                        .collection("comments")
                        .document(comment.id)
                        .updateData([
                            "likes": FieldValue.increment(Int64(1))
                        ])
                    
                    // Update local state immediately
                    await MainActor.run {
                        if let index = comments.firstIndex(where: { $0.comment.id == comment.id }) {
                            comments[index].comment.userLiked = true
                            comments[index].comment.likes += 1
                        }
                    }
                    
                    print("✅ Comment liked: \(comment.id)")
                }
                
            } catch {
                print("❌ Error liking comment: \(error)")
            }
        }
    }
    
    private func replyToComment(_ commentWithReplies: CommentWithReplies) {
        // Set the comment to reply to
        replyingTo = commentWithReplies
        
        // Auto-populate @username in the text field
        commentText = "@\(commentWithReplies.comment.username) "
        
        // Auto-focus the keyboard
        isCommentFieldFocused = true
    }
    
    // MARK: - Mention Handling
    
    private func handleTextChange(_ newValue: String) {
        // Detect if user is typing a mention
        if let lastAtIndex = newValue.lastIndex(of: "@") {
            // Check if @ is at the start or preceded by a space
            let isValidMention: Bool
            if lastAtIndex == newValue.startIndex {
                isValidMention = true
            } else {
                let charBeforeAt = newValue[newValue.index(before: lastAtIndex)]
                isValidMention = charBeforeAt.isWhitespace
            }
            
            if isValidMention {
                // Extract the query after @
                let afterAtIndex = newValue.index(after: lastAtIndex)
                let afterAt = String(newValue[afterAtIndex...])
                
                // Check if there's a space after @ (if so, stop suggesting)
                if let spaceIndex = afterAt.firstIndex(of: " ") {
                    let query = String(afterAt[..<spaceIndex])
                    if query.isEmpty {
                        showMentionSuggestions = false
                        mentionSuggestions = []
                    }
                } else {
                    // Continue suggesting
                    currentMentionQuery = afterAt
                    mentionStartIndex = lastAtIndex
                    showMentionSuggestions = true
                    fetchMentionSuggestions(query: afterAt)
                }
            } else {
                showMentionSuggestions = false
            }
        } else {
            // No @ found, hide suggestions
            showMentionSuggestions = false
            mentionSuggestions = []
        }
    }
    
    private func fetchMentionSuggestions(query: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let suggestions = await MentionService.shared.getSuggestions(
                query: query,
                logId: log.id,
                currentUserId: currentUserId
            )
            
            await MainActor.run {
                mentionSuggestions = suggestions
            }
        }
    }
    
    private func insertMention(_ suggestion: MentionSuggestion) {
        guard let startIndex = mentionStartIndex else { return }
        
        // Replace from @ to current position with @username
        let beforeAt = String(commentText[..<startIndex])
        let mentionText = "@\(suggestion.username) "
        
        commentText = beforeAt + mentionText
        
        // Hide suggestions
        showMentionSuggestions = false
        mentionSuggestions = []
        mentionStartIndex = nil
    }
    
    private func toggleReplies(for commentWithReplies: CommentWithReplies) {
        if let index = comments.firstIndex(where: { $0.id == commentWithReplies.id }) {
            comments[index].showingReplies.toggle()
        }
    }
    
    private func toggleLike() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let db = Firestore.firestore()
            let likeRef = db.collection("logs").document(log.id).collection("likes").document(currentUserId)
            
            do {
                if isLiked {
                    // Unlike - delete the like document
                    try await likeRef.delete()
                    
                    // Decrement the like count on the log
                    try await db.collection("logs").document(log.id).updateData([
                        "likeCount": FieldValue.increment(Int64(-1))
                    ])
                    
                    await MainActor.run {
                        isLiked = false
                        likeCount -= 1
                    }
                } else {
                    // Like - create the like document
                    try await likeRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    
                    // Increment the like count on the log
                    try await db.collection("logs").document(log.id).updateData([
                        "likeCount": FieldValue.increment(Int64(1))
                    ])
                    
                    await MainActor.run {
                        isLiked = true
                        likeCount += 1
                    }
                }
            } catch {
                print("❌ Error toggling like: \(error)")
            }
        }
    }
    
    private func toggleThumbsDown() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let db = Firestore.firestore()
            let thumbsDownRef = db.collection("logs").document(log.id).collection("thumbsDown").document(currentUserId)
            
            do {
                if hasThumbsDown {
                    // Remove thumbs down
                    try await thumbsDownRef.delete()
                    
                    // Decrement the thumbs down count on the log
                    try await db.collection("logs").document(log.id).updateData([
                        "thumbsDownCount": FieldValue.increment(Int64(-1))
                    ])
                    
                    await MainActor.run {
                        hasThumbsDown = false
                        thumbsDownCount = max(0, thumbsDownCount - 1)
                    }
                } else {
                    // Add thumbs down
                    try await thumbsDownRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    
                    // Increment the thumbs down count on the log
                    try await db.collection("logs").document(log.id).updateData([
                        "thumbsDownCount": FieldValue.increment(Int64(1))
                    ])
                    
                    await MainActor.run {
                        hasThumbsDown = true
                        thumbsDownCount += 1
                    }
                }
            } catch {
                print("❌ Error toggling thumbs down: \(error)")
            }
        }
    }
    
    private func handleRepost() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let db = Firestore.firestore()
            let repostRef = db.collection("logs").document(log.id).collection("reposts").document(currentUserId)
            
            do {
                // Check if already reposted
                let repostDoc = try await repostRef.getDocument()
                
                if repostDoc.exists {
                    // Un-repost - delete the repost
                    try await repostRef.delete()
                    
                    // Decrement repost count
                    try await db.collection("logs").document(log.id).updateData([
                        "repostCount": FieldValue.increment(Int64(-1))
                    ])
                    
                    // Update local state immediately
                    await MainActor.run {
                        hasReposted = false
                        repostCount = max(0, repostCount - 1)
                    }
                    
                    print("✅ Log unreposted: \(log.id)")
                } else {
                    // Repost - create the repost document
                    try await repostRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp(),
                        "originalLogId": log.id,
                        "originalUserId": log.userId
                    ])
                    
                    // Increment repost count
                    try await db.collection("logs").document(log.id).updateData([
                        "repostCount": FieldValue.increment(Int64(1))
                    ])
                    
                    // Update local state immediately
                    await MainActor.run {
                        hasReposted = true
                        repostCount += 1
                    }
                    
                    print("✅ Log reposted: \(log.id)")
                    
                    // Create notification for the log owner (if not reposting your own log)
                    if currentUserId != log.userId {
                        await NotificationService.shared.createRepostNotification(
                            logId: log.id,
                            logOwnerId: log.userId,
                            log: log
                        )
                    }
                }
            } catch {
                print("❌ Error handling repost: \(error)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y ago"
        } else if let months = components.month, months > 0 {
            return "\(months)mo ago"
        } else if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Comment Sort Option

enum CommentSortOption: String, CaseIterable {
    case mostPopular = "Most Popular"
    case mostRecent = "Most Recent"
}

// MARK: - Comment With Replies Model

struct CommentWithReplies: Identifiable {
    let id = UUID()
    var comment: MusicComment
    var replies: [CommentReply]
    var showingReplies: Bool
    
    var engagementScore: Int {
        // Calculate engagement score for sorting
        return (comment.likes * 2) + replies.count - comment.dislikes
    }
}

// MARK: - Comment Row View

private struct CommentRowView: View {
    let comment: CommentWithReplies
    let userRating: Double?
    let logItemId: String
    let onLike: () -> Void
    let onReply: () -> Void
    let onShowReplies: () -> Void
    let onUserTap: (String) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showUserLog = false
    @State private var userLog: MusicLog?
    @State private var userProfileImage: String?
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    
    // Local state for animations
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main comment
            HStack(alignment: .top, spacing: 12) {
                // User avatar - tappable
                Button(action: {
                    onUserTap(comment.comment.userId)
                }) {
                    AsyncImage(url: URL(string: userProfileImage ?? comment.comment.userProfileImage ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(
                        Group {
                            if (userProfileImage ?? comment.comment.userProfileImage) == nil {
                                Text(String(comment.comment.username.prefix(1)).uppercased())
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 8) {
                    // Username and rating
                    HStack(spacing: 8) {
                        // Username - tappable
                        Button(action: {
                            onUserTap(comment.comment.userId)
                        }) {
                            Text(comment.comment.username)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Show user's rating if they've rated this item - tappable
                        if let rating = userRating {
                            Button(action: {
                                fetchAndShowUserLog()
                            }) {
                                StarRatingDisplayView(
                                    rating: rating,
                                    starSize: 10,
                                    spacing: 1,
                                    showNumber: false
                                )
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()
                        
                        // Time ago
                        Text(timeAgoString(from: comment.comment.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Comment text with tappable mentions
                    InteractiveMentionText(
                        comment.comment.comment,
                        font: .body,
                        color: .primary,
                        mentionColor: .purple
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        // Like button with animation
                        Button(action: {
                            // Haptic feedback
                            if isLiked {
                                LogEngagementHaptics.unlike()
                            } else {
                                LogEngagementHaptics.like()
                            }
                            // Optimistic UI update
                            isLiked.toggle()
                            likeCount += isLiked ? 1 : -1
                            // Call the actual like action
                            onLike()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(isLiked ? .red : .secondary)
                                    .symbolEffect(.bounce, value: isLiked)
                                if likeCount > 0 {
                                    Text("\(likeCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                        .scaleEffect(isLiked ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                        .animation(.smooth, value: likeCount)
                        
                        // Reply button with haptic
                        Button(action: {
                            LogEngagementHaptics.comment()
                            onReply()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left")
                                    .foregroundColor(.secondary)
                                Text("Reply")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .font(.caption)
                }
            }
            
            // Show replies button (if there are replies)
            if !comment.replies.isEmpty {
                Button(action: onShowReplies) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.showingReplies ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                        Text(comment.showingReplies ? "Hide replies" : "Show \(comment.replies.count) \(comment.replies.count == 1 ? "reply" : "replies")")
                            .font(.caption)
                    }
                    .foregroundColor(.purple)
                }
                .padding(.leading, 48)
                
                // Replies list (if showing)
                if comment.showingReplies {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(comment.replies) { reply in
                            UnifiedReplyRowView(reply: reply) {
                                onUserTap(reply.userId)
                            }
                        }
                    }
                    .padding(.leading, 48)
                }
            }
        }
        .contextMenu {
            Button {
                showReportSheet = true
            } label: {
                Label("Report Comment", systemImage: "flag")
            }
        }
        .onAppear {
            // Initialize local state from comment data
            isLiked = comment.comment.userLiked == true
            likeCount = comment.comment.likes
            
            if comment.comment.userProfileImage == nil && userProfileImage == nil {
                loadUserProfileImage()
            }
        }
        .fullScreenCover(isPresented: $showUserLog) {
            if let userLog = userLog {
                UnifiedLogCommentsView(log: userLog)
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentId: comment.comment.id,
                contentType: .comment,
                reportedUserId: comment.comment.userId,
                reportedUsername: comment.comment.username,
                contentPreview: comment.comment.comment
            )
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockUserView(
                userId: comment.comment.userId,
                username: comment.comment.username,
                profilePictureUrl: comment.comment.userProfileImage
            )
        }
    }
    
    private func loadUserProfileImage() {
        guard userProfileImage == nil else { return }
        
        Task {
            let db = Firestore.firestore()
            do {
                let doc = try await db.collection("users").document(comment.comment.userId).getDocument()
                if let profile = try? doc.data(as: UserProfile.self),
                   let imageUrl = profile.profilePictureUrl {
                    await MainActor.run {
                        self.userProfileImage = imageUrl
                    }
                }
            } catch {
                print("❌ Error loading user profile image for comment: \(error)")
            }
        }
    }
    
    private func fetchAndShowUserLog() {
        // Fetch the user's log for this item
        Task {
            let db = Firestore.firestore()
            do {
                let snapshot = try await db.collection("logs")
                    .whereField("userId", isEqualTo: comment.comment.userId)
                    .whereField("itemId", isEqualTo: logItemId)
                    .limit(to: 1)
                    .getDocuments()
                
                if let doc = snapshot.documents.first,
                   let log = try? doc.data(as: MusicLog.self) {
                    await MainActor.run {
                        self.userLog = log
                        self.showUserLog = true
                    }
                }
            } catch {
                print("❌ Error fetching user's log: \(error)")
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y"
        } else if let months = components.month, months > 0 {
            return "\(months)mo"
        } else if let days = components.day, days > 0 {
            return "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
}

// MARK: - Unified Reply Row View

private struct UnifiedReplyRowView: View {
    let reply: CommentReply
    var onUserTap: () -> Void = {}
    
    @State private var userProfileImage: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar (smaller)
            Button(action: onUserTap) {
                AsyncImage(url: URL(string: userProfileImage ?? reply.userProfileImage ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(
                    Group {
                        if (userProfileImage ?? reply.userProfileImage) == nil {
                            Text(String(reply.username.prefix(1)).uppercased())
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                    }
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
                if reply.userProfileImage == nil && userProfileImage == nil {
                    loadUserProfileImage()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Username and time
                HStack {
                    Button(action: onUserTap) {
                        Text(reply.username)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text(timeAgoString(from: reply.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Reply text with tappable mentions
                InteractiveMentionText(
                    reply.reply,
                    font: .caption,
                    color: .primary,
                    mentionColor: .purple
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func loadUserProfileImage() {
        guard userProfileImage == nil else { return }
        
        Task {
            let db = Firestore.firestore()
            do {
                let doc = try await db.collection("users").document(reply.userId).getDocument()
                if let profile = try? doc.data(as: UserProfile.self),
                   let imageUrl = profile.profilePictureUrl {
                    await MainActor.run {
                        self.userProfileImage = imageUrl
                    }
                }
            } catch {
                print("❌ Error loading user profile image for reply: \(error)")
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y"
        } else if let months = components.month, months > 0 {
            return "\(months)mo"
        } else if let days = components.day, days > 0 {
            return "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
}

#Preview {
    UnifiedLogCommentsView(
        log: MusicLog(
            id: "sample-id",
            userId: "user123",
            itemId: "song123",
            itemType: "song",
            title: "EVIL JORDAN",
            artistName: "Playboi Carti",
            artworkUrl: nil,
            dateLogged: Date(),
            rating: 4.0,
            review: "Bop",
            notes: nil,
            commentCount: 4,
            helpfulCount: nil,
            unhelpfulCount: nil,
            reviewPhotos: nil,
            isLiked: nil,
            thumbsUp: nil,
            thumbsDown: nil
        )
    )
}

