import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LogCommentsView: View {
    let log: MusicLog
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [ReviewComment] = []
    @State private var isLoading = false
    @State private var newCommentText = ""
    @State private var replyingTo: ReviewComment? = nil
    @State private var expandedComments: Set<String> = []
    @State private var commentReplies: [String: [ReviewComment]] = [:]
    @State private var commentLikeStatus: [String: Bool] = [:] // commentId -> isLiked
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments list
                if comments.isEmpty && !isLoading {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(comments) { comment in
                                LogCommentRow(
                                    comment: comment,
                                    log: log,
                                    isExpanded: expandedComments.contains(comment.id),
                                    replies: commentReplies[comment.id] ?? [],
                                    isLiked: commentLikeStatus[comment.id] ?? false,
                                    onToggleExpand: {
                                        toggleExpanded(comment)
                                    },
                                    onLoadMoreReplies: {
                                        loadMoreReplies(for: comment)
                                    },
                                    onReply: {
                                        startReply(to: comment)
                                    },
                                    onLike: {
                                        toggleLike(for: comment)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                // Input bar at bottom
                commentInputBar
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading && comments.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.9))
                }
            }
        }
        .onAppear {
            loadComments()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No comments yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Be the first to comment on this log!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Comment Input Bar
    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 12) {
                // Reply indicator
                if let replyingTo = replyingTo {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Replying to \(replyingTo.username)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: { self.replyingTo = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                }
                
                HStack(spacing: 12) {
                    // Text field
                    TextField(replyingTo != nil ? "Write a reply..." : "Add a comment...", text: $newCommentText, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                    
                    // Send button
                    Button(action: sendComment) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    private func loadComments() {
        guard !isLoading else { return }
        isLoading = true
        
        // Fetch top-level comments only (no parentCommentId)
        let db = Firestore.firestore()
        db.collection("logs").document(log.id)
            .collection("comments")
            .whereField("parentCommentId", isEqualTo: NSNull())
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading comments: \(error.localizedDescription)")
                    isLoading = false
                    return
                }
                
                var fetchedComments = snapshot?.documents.compactMap { try? $0.data(as: ReviewComment.self) } ?? []
                
                // Sort by engagement score (likes + replies)
                fetchedComments.sort { $0.engagementScore > $1.engagementScore }
                
                self.comments = fetchedComments
                
                // Load like status for all comments
                loadLikeStatusForComments()
                
                isLoading = false
            }
    }
    
    private func loadLikeStatusForComments() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        for comment in comments {
            CommentLike.hasUserLiked(logId: log.id, commentId: comment.id, userId: currentUserId) { isLiked, _ in
                DispatchQueue.main.async {
                    commentLikeStatus[comment.id] = isLiked
                }
            }
        }
    }
    
    private func toggleExpanded(_ comment: ReviewComment) {
        if expandedComments.contains(comment.id) {
            // Hide replies
            expandedComments.remove(comment.id)
            commentReplies[comment.id] = []
        } else {
            // Show replies - load first 3
            expandedComments.insert(comment.id)
            loadReplies(for: comment, limit: 3)
        }
    }
    
    private func loadReplies(for comment: ReviewComment, limit: Int = 3) {
        ReviewComment.fetchRepliesForComment(logId: log.id, parentCommentId: comment.id, limit: limit) { replies, error in
            if let error = error {
                print("❌ Error loading replies: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self.commentReplies[comment.id] = replies ?? []
                
                // Load like status for replies
                if let replies = replies {
                    for reply in replies {
                        loadLikeStatusForComment(reply)
                    }
                }
            }
        }
    }
    
    private func loadMoreReplies(for comment: ReviewComment) {
        guard let existingReplies = commentReplies[comment.id], !existingReplies.isEmpty else { return }
        
        let lastReplyId = existingReplies.last?.id
        
        ReviewComment.fetchRepliesForComment(logId: log.id, parentCommentId: comment.id, limit: 3, startAfter: lastReplyId) { newReplies, error in
            if let error = error {
                print("❌ Error loading more replies: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                if let newReplies = newReplies, !newReplies.isEmpty {
                    self.commentReplies[comment.id]? += newReplies
                    
                    // Load like status for new replies
                    for reply in newReplies {
                        loadLikeStatusForComment(reply)
                    }
                }
            }
        }
    }
    
    private func loadLikeStatusForComment(_ comment: ReviewComment) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        CommentLike.hasUserLiked(logId: log.id, commentId: comment.id, userId: currentUserId) { isLiked, _ in
            DispatchQueue.main.async {
                commentLikeStatus[comment.id] = isLiked
            }
        }
    }
    
    private func startReply(to comment: ReviewComment) {
        replyingTo = comment
        isInputFocused = true
    }
    
    private func toggleLike(for comment: ReviewComment) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let wasLiked = commentLikeStatus[comment.id] ?? false
        
        // Optimistic UI update
        commentLikeStatus[comment.id] = !wasLiked
        
        // Update in local array
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index].likeCount = wasLiked ? max(0, (comments[index].likeCount ?? 0) - 1) : (comments[index].likeCount ?? 0) + 1
        }
        
        // Check if it's in replies
        for (parentId, replies) in commentReplies {
            if let replyIndex = replies.firstIndex(where: { $0.id == comment.id }) {
                commentReplies[parentId]?[replyIndex].likeCount = wasLiked ? max(0, (replies[replyIndex].likeCount ?? 0) - 1) : (replies[replyIndex].likeCount ?? 0) + 1
            }
        }
        
        if wasLiked {
            // Unlike
            CommentLike.removeLike(logId: log.id, commentId: comment.id, userId: currentUserId) { error in
                if let error = error {
                    print("❌ Error removing comment like: \(error.localizedDescription)")
                    // Revert on error
                    DispatchQueue.main.async {
                        commentLikeStatus[comment.id] = true
                    }
                }
            }
        } else {
            // Like
            let like = CommentLike(commentId: comment.id, userId: currentUserId)
            CommentLike.addLike(like, logId: log.id) { error in
                if let error = error {
                    print("❌ Error adding comment like: \(error.localizedDescription)")
                    // Revert on error
                    DispatchQueue.main.async {
                        commentLikeStatus[comment.id] = false
                    }
                }
            }
        }
    }
    
    private func sendComment() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        Task {
            guard let context = await ReviewComment.currentUserContext() else { return }
            
            let comment = ReviewComment(
                logId: log.id,
                userId: context.userId,
                username: context.username,
                userProfilePictureUrl: context.profilePictureUrl,
                text: trimmed,
                parentCommentId: replyingTo?.id
            )
            
            ReviewComment.addComment(comment) { error in
                if let error = error {
                    print("❌ Error adding comment: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        newCommentText = ""
                        
                        if replyingTo != nil {
                            if let parentId = replyingTo?.id {
                                loadReplies(for: replyingTo!, limit: (commentReplies[parentId]?.count ?? 0) + 1)
                            }
                            replyingTo = nil
                        } else {
                            loadComments()
                        }
                        
                        isInputFocused = false
                    }
                }
            }
        }
    }
}

// MARK: - Log Comment Row
struct LogCommentRow: View {
    let comment: ReviewComment
    let log: MusicLog
    let isExpanded: Bool
    let replies: [ReviewComment]
    let isLiked: Bool
    let onToggleExpand: () -> Void
    let onLoadMoreReplies: () -> Void
    let onReply: () -> Void
    let onLike: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main comment
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                UserAvatarView(
                    userId: comment.userId,
                    existingUrl: comment.userProfilePictureUrl,
                    initials: comment.username,
                    size: 36
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    // Username
                    Text(comment.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    // Comment text
                    Text(comment.text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    // Actions
                    HStack(spacing: 16) {
                        // Like button
                        Button(action: onLike) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.caption)
                                    .foregroundColor(isLiked ? .red : .secondary)
                                if let likeCount = comment.likeCount, likeCount > 0 {
                                    Text("\(likeCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Reply button
                        Button(action: onReply) {
                            Text("Reply")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Time ago
                        Text(comment.createdAt.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Show/Hide replies button
            if let replyCount = comment.replyCount, replyCount > 0 {
                Button(action: onToggleExpand) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                        Text(isExpanded ? "Hide replies" : "Show replies (\(replyCount))")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.leading, 48)
            }
            
            // Replies
            if isExpanded && !replies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(replies) { reply in
                        ReplyRow(
                            reply: reply,
                            log: log,
                            isLiked: false, // TODO: Load like status for replies
                            onLike: { /* TODO: Implement reply like */ }
                        )
                    }
                    
                    // Load more replies button
                    if let replyCount = comment.replyCount, replies.count < replyCount {
                        Button(action: onLoadMoreReplies) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.caption)
                                Text("Show more replies")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.leading, 48)
            }
        }
    }
}

// MARK: - Reply Row
struct ReplyRow: View {
    let reply: ReviewComment
    let log: MusicLog
    let isLiked: Bool
    let onLike: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile picture (smaller for replies)
            if let urlStr = reply.userProfilePictureUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(reply.username.prefix(1)).uppercased())
                            .font(.caption2)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Username
                Text(reply.username)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                // Reply text
                Text(reply.text)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                // Actions
                HStack(spacing: 12) {
                    // Like button
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.caption2)
                                .foregroundColor(isLiked ? .red : .secondary)
                            if let likeCount = reply.likeCount, likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Time ago
                    Text(reply.createdAt.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Date Extension for Time Ago
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    LogCommentsView(log: MusicLog(
        id: "1",
        userId: "user1",
        itemId: "song1",
        itemType: "song",
        title: "Test Song",
        artistName: "Test Artist",
        artworkUrl: nil,
        dateLogged: Date(),
        rating: 4,
        review: "Great song!",
        notes: nil,
        commentCount: 5,
        helpfulCount: nil,
        unhelpfulCount: nil,
        likeCount: 10,
        reviewPhotos: nil,
        isLiked: false,
        thumbsUp: false,
        thumbsDown: false,
        isPublic: true,
        appleMusicGenres: nil,
        primaryGenre: "hip-hop",
        genres: ["hip-hop"],
        userCorrectedGenre: nil,
        genreConfidenceScore: nil,
        classificationMethod: nil,
        universalTrackId: nil,
        musicPlatform: nil,
        platformMatchingConfidence: nil
    ))
}

