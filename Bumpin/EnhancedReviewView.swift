import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EnhancedReviewView: View {
    let log: MusicLog
    let showFullDetails: Bool
    @State private var showingComments = false // Now navigates to UnifiedLogCommentsView
    @State private var comments: [ReviewComment] = []
    @State private var newCommentText = ""
    @State private var isLoadingComments = false
    @State private var isAddingComment = false
    @State private var friendLikers: [UserLike] = []
    
    // Engagement state
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var hasThumbsDown: Bool = false
    @State private var hasReposted: Bool = false
    @State private var repostCount: Int = 0
    @State private var showActivity = false
    
    // Context menu state
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    @State private var showUserProfile = false
    @State private var userProfile: UserProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with music info and rating
            HStack(alignment: .top, spacing: 12) {
                // Artwork
                if let url = log.artworkUrl, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.title)
                                .font(.headline)
                                .lineLimit(2)

                            Text(log.artistName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(timeAgoString(from: log.dateLogged))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 8) {
                        // Rating display with stars
                        if let rating = log.rating {
                            // Always show with numeric rating and partial stars
                            // For owner: make it editable
                            if let uid = Auth.auth().currentUser?.uid, uid == log.userId {
                                Button(action: {
                                    // Could open a rating editor sheet here if needed
                                    // For now, just display
                                }) {
                                    StarRatingDisplayView(rating: rating, starSize: 12, spacing: 2, showNumber: true)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                // For others: display-only with partial stars
                                StarRatingDisplayView(rating: rating, starSize: 12, spacing: 2, showNumber: true)
                            }
                        }
                        Spacer()
                        if log.isPublic == false {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill").font(.caption2)
                                Text("Private").font(.caption2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            
            // Review text
            if let review = log.review, !review.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(review)
                        .font(.body)
                        .lineLimit(showFullDetails ? nil : 5)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    // Review photos (if any)
                    if let photos = log.reviewPhotos, !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photos, id: \.self) { photoUrl in
                                    if let url = URL(string: photoUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.2))
                                        }
                                        .frame(width: 80, height: 80)
                                        .cornerRadius(8)
                                        .clipped()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            // Interaction buttons
            HStack(spacing: 16) {
                // Like button
                Button(action: { 
                    if isLiked {
                        LogEngagementHaptics.unlike()
                    } else {
                        LogEngagementHaptics.like()
                    }
                    toggleLike() 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .symbolEffect(.bounce, value: isLiked)
                        Text("\(likeCount)")
                            .contentTransition(.numericText())
                    }
                    .font(.caption)
                    .foregroundColor(isLiked ? .red : .secondary)
                }
                .scaleEffect(isLiked ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
                .animation(.smooth, value: likeCount)
                .buttonStyle(PlainButtonStyle())
                
                // Comment button - Navigate to full comment view
                Button(action: { 
                    LogEngagementHaptics.comment()
                    showingComments = true 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text("\(log.commentCount ?? 0)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Thumbs down button
                Button(action: { 
                    LogEngagementHaptics.thumbsDown()
                    toggleThumbsDown() 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: hasThumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .symbolEffect(.bounce, value: hasThumbsDown)
                        if hasThumbsDown {
                            Text("1")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .scaleEffect(hasThumbsDown ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasThumbsDown)
                .buttonStyle(PlainButtonStyle())
                
                // Repost button
                Button(action: { 
                    if hasReposted {
                        LogEngagementHaptics.unrepost()
                    } else {
                        LogEngagementHaptics.repost()
                    }
                    handleRepost() 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .foregroundColor(hasReposted ? .green : .secondary)
                            .symbolEffect(.bounce, value: hasReposted)
                        if repostCount > 0 {
                            Text("\(repostCount)")
                                .contentTransition(.numericText())
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .scaleEffect(hasReposted ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasReposted)
                .animation(.smooth, value: repostCount)
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // View Activity button
                Button(action: { 
                    LogEngagementHaptics.viewActivity()
                    showActivity = true 
                }) {
                    Text("View Activity")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onAppear {
                loadEngagement()
            }
            .fullScreenCover(isPresented: $showActivity) {
                LogActivityView(logId: log.id, log: log)
            }
            .fullScreenCover(isPresented: $showingComments) {
                UnifiedLogCommentsView(log: log)
            }
            
            // Friends' comments preview (always shown, not just when collapsed)
            FriendsCommentsPreview(log: log, maxCount: 2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .contextMenu {
            Button {
                showReportSheet = true
            } label: {
                Label("Report", systemImage: "flag")
            }
        }
        .onAppear {
            loadUserProfileForContextMenu()
        }
        .fullScreenCover(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView(userId: log.userId)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                showUserProfile = false
                            }
                            .foregroundColor(.purple)
                        }
                    }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentId: log.id,
                contentType: .musicReview,
                reportedUserId: log.userId,
                reportedUsername: userProfile?.username ?? "user",
                contentPreview: log.review
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
    
    // MARK: - Load User Profile for Context Menu
    private func loadUserProfileForContextMenu() {
        guard userProfile == nil else { return }
        Task {
            let db = Firestore.firestore()
            do {
                let doc = try await db.collection("users").document(log.userId).getDocument()
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
    
    // MARK: - Relative Time Formatting
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if interval < 604800 { // Less than 7 days
            let days = Int(interval / 86400)
            return "\(days)d"
        } else if interval < 2592000 { // Less than 30 days
            let weeks = Int(interval / 604800)
            return "\(weeks)w"
        } else {
            let months = Int(interval / 2592000)
            return "\(months)mo"
        }
    }
    
    private func loadFriendLikersPreview() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Set(followingIds).intersection(Set(followerIds))
            UserLike.getItemLikes(itemId: log.id, itemType: .review) { likes, _ in
                let likes = likes ?? []
                let filtered = likes.filter { mutuals.contains($0.userId) }
                // Optional: sort recency
                let sorted = filtered.sorted { $0.createdAt > $1.createdAt }
                self.friendLikers = Array(sorted.prefix(3))
            }
        }
    }
    
    private func loadComments() {
        isLoadingComments = true
        ReviewComment.fetchCommentsForLog(logId: log.id, limit: 25) { fetchedComments, error in
            DispatchQueue.main.async {
                isLoadingComments = false
                if let error = error {
                    print("Error loading comments: \(error)")
                } else {
                    comments = fetchedComments ?? []
                }
            }
        }
    }
    
    private func addComment() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isAddingComment = true
        
        Task {
            guard let context = await ReviewComment.currentUserContext() else {
                await MainActor.run { isAddingComment = false }
                return
            }
            
            let comment = ReviewComment(
                logId: log.id,
                userId: context.userId,
                username: context.username,
                userProfilePictureUrl: context.profilePictureUrl,
                text: trimmed
            )
            
            ReviewComment.addComment(comment) { error in
                DispatchQueue.main.async {
                    isAddingComment = false
                    if let error = error {
                        print("Error adding comment: \(error)")
                    } else {
                        newCommentText = ""
                        loadComments()
                    }
                }
            }
        }
    }

    // Quick inline rating update
    private func updateRating(_ newValue: Double) {
        guard Auth.auth().currentUser?.uid == log.userId else { return }
        var updated = log
        updated.rating = newValue
        MusicLog.updateLog(updated) { _ in }
    }
    
    // MARK: - Engagement Actions
    
    private func loadEngagement() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        likeCount = log.likeCount ?? 0
        repostCount = log.repostCount ?? 0
        
        Task {
            let engagement = await LogEngagementCache.shared.getEngagement(logId: log.id, userId: currentUserId)
            await MainActor.run {
                isLiked = engagement.isLiked
                hasThumbsDown = engagement.hasThumbsDown
                hasReposted = engagement.hasReposted
            }
        }
    }
    
    private func toggleLike() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let db = Firestore.firestore()
            let likeRef = db.collection("logs").document(log.id).collection("likes").document(currentUserId)
            
            do {
                if isLiked {
                    try await likeRef.delete()
                    try await db.collection("logs").document(log.id).updateData([
                        "likeCount": FieldValue.increment(Int64(-1))
                    ])
                    
                    await MainActor.run {
                        isLiked = false
                        likeCount -= 1
                        LogEngagementCache.shared.updateEngagement(logId: log.id, isLiked: false)
                    }
                } else {
                    try await likeRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    try await db.collection("logs").document(log.id).updateData([
                        "likeCount": FieldValue.increment(Int64(1))
                    ])
                    
                    // Create like notification
                    await NotificationService.shared.createLikeNotification(
                        logId: log.id,
                        logOwnerId: log.userId,
                        log: log
                    )
                    
                    await MainActor.run {
                        isLiked = true
                        likeCount += 1
                        LogEngagementCache.shared.updateEngagement(logId: log.id, isLiked: true)
                    }
                }
            } catch {
                print("❌ Error toggling like: \(error)")
            }
        }
    }
    
    private func toggleThumbsDown() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🔍 toggleThumbsDown called - current state: \(hasThumbsDown)")
        
        Task {
            let db = Firestore.firestore()
            let thumbsDownRef = db.collection("logs").document(log.id).collection("thumbsDown").document(currentUserId)
            
            do {
                if hasThumbsDown {
                    print("🔍 Deleting thumbs down...")
                    try await thumbsDownRef.delete()
                    
                    // ✅ Decrement the thumbs down count on the log
                    try await db.collection("logs").document(log.id).updateData([
                        "thumbsDownCount": FieldValue.increment(Int64(-1))
                    ])
                    
                    await MainActor.run {
                        hasThumbsDown = false
                        print("✅ Thumbs down removed - new state: \(hasThumbsDown)")
                        LogEngagementCache.shared.updateEngagement(logId: log.id, hasThumbsDown: false)
                    }
                } else {
                    print("🔍 Adding thumbs down...")
                    try await thumbsDownRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    
                    // ✅ Increment the thumbs down count on the log
                    try await db.collection("logs").document(log.id).updateData([
                        "thumbsDownCount": FieldValue.increment(Int64(1))
                    ])
                    
                    // Create dislike notification
                    await NotificationService.shared.createDislikeNotification(
                        logId: log.id,
                        logOwnerId: log.userId,
                        log: log
                    )
                    
                    await MainActor.run {
                        hasThumbsDown = true
                        print("✅ Thumbs down added - new state: \(hasThumbsDown)")
                        LogEngagementCache.shared.updateEngagement(logId: log.id, hasThumbsDown: true)
                    }
                }
            } catch {
                print("❌ Error toggling thumbs down: \(error)")
            }
        }
    }
    
    private func handleRepost() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("🔍 handleRepost called - current state: hasReposted=\(hasReposted), count=\(repostCount)")
        
        Task {
            let db = Firestore.firestore()
            let repostRef = db.collection("logs").document(log.id).collection("reposts").document(currentUserId)
            
            do {
                if hasReposted {
                    print("🔍 Deleting repost...")
                    try await repostRef.delete()
                    try await db.collection("logs").document(log.id).updateData([
                        "repostCount": FieldValue.increment(Int64(-1))
                    ])
                    
                    await MainActor.run {
                        hasReposted = false
                        repostCount = max(0, repostCount - 1)
                        print("✅ Repost removed - new state: hasReposted=\(hasReposted), count=\(repostCount)")
                        LogEngagementCache.shared.updateEngagement(logId: log.id, hasReposted: false)
                    }
                } else {
                    print("🔍 Adding repost...")
                    try await repostRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    try await db.collection("logs").document(log.id).updateData([
                        "repostCount": FieldValue.increment(Int64(1))
                    ])
                    
                    // Create repost notification
                    await NotificationService.shared.createRepostNotification(
                        logId: log.id,
                        logOwnerId: log.userId,
                        log: log
                    )
                    
                    await MainActor.run {
                        hasReposted = true
                        repostCount += 1
                        print("✅ Repost added - new state: hasReposted=\(hasReposted), count=\(repostCount)")
                        LogEngagementCache.shared.updateEngagement(logId: log.id, hasReposted: true)
                    }
                }
            } catch {
                print("❌ Error handling repost: \(error)")
            }
        }
    }
}

// CommentView is already defined in MyDiaryView.swift, so we reuse it here

#if DEBUG
struct EnhancedReviewView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleLog = MusicLog(
            id: "sample-id",
            userId: "user-id",
            itemId: "song-id",
            itemType: "song",
            title: "Sample Song",
            artistName: "Sample Artist",
            artworkUrl: nil,
            dateLogged: Date(),
            rating: 4,
            review: "This is a sample review that demonstrates the enhanced review display component with multiple lines of text to show how it looks.",
            notes: nil,
            commentCount: 3,
            helpfulCount: 5,
            unhelpfulCount: 1,
            reviewPhotos: nil
        )
        
        EnhancedReviewView(log: sampleLog, showFullDetails: true)
            .padding()
    }
}
#endif 