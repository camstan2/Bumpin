import SwiftUI
import FirebaseAuth

struct EnhancedCommentRowView: View {
    let comment: ReviewComment
    let logId: String
    let isExpanded: Bool
    let replies: [ReviewComment]
    let onToggleExpand: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    
    @State private var isLiked = false
    @State private var likeCount: Int = 0
    @State private var showDeleteConfirmation = false
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    
    private var isOwnComment: Bool {
        Auth.auth().currentUser?.uid == comment.userId
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main comment
            HStack(alignment: .top, spacing: 12) {
                // User avatar
                if let urlString = comment.userProfilePictureUrl, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(comment.username.prefix(1)).uppercased())
                                .foregroundColor(.white)
                                .font(.headline)
                        )
                }
                
                // Comment content
                VStack(alignment: .leading, spacing: 6) {
                    // Username and timestamp
                    HStack {
                        Text(comment.username)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(timeAgoString(from: comment.createdAt))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()

                    // Report / Block menu
                    Menu {
                        ReportMenuButton(
                            contentId: comment.id,
                            contentType: .comment,
                            reportedUserId: comment.userId,
                            reportedUsername: comment.username,
                            contentPreview: comment.text,
                            onReport: { showReportSheet = true },
                            onBlock: { showBlockSheet = true }
                        )
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                        
                        // Delete button (only for own comments)
                        if isOwnComment {
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                    }
                    
                    // Comment text
                    Text(comment.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        // Like button with animation
                        Button(action: {
                            // Haptic feedback
                            if isLiked {
                                LogEngagementHaptics.unlike()
                            } else {
                                LogEngagementHaptics.like()
                            }
                            toggleLike()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.subheadline)
                                    .foregroundColor(isLiked ? .red : .gray)
                                    .symbolEffect(.bounce, value: isLiked)
                                
                                if likeCount > 0 {
                                    Text("\(likeCount)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
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
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text("Reply")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            
            // View replies button
            if let replyCount = comment.replyCount, replyCount > 0 {
                Button(action: onToggleExpand) {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                        
                        Text(isExpanded ? "Hide replies" : "View \(replyCount) \(replyCount == 1 ? "reply" : "replies")")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.leading, 52) // Align with comment text
            }
            
            // Replies (expanded)
            if isExpanded && !replies.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(replies) { reply in
                        ReplyRowView(
                            reply: reply,
                            logId: logId,
                            onDelete: {
                                deleteReply(reply)
                            }
                        )
                        .padding(.leading, 52) // Indent replies
                        
                        if reply.id != replies.last?.id {
                            Divider()
                                .background(Color.gray.opacity(0.1))
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .contextMenu {
            Button {
                showReportSheet = true
            } label: {
                Label("Report Comment", systemImage: "flag")
            }
            
            Button {
                showBlockSheet = true
            } label: {
                Label("Block User", systemImage: "hand.raised")
            }
            
            if isOwnComment {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Comment", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete Comment", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
        .onAppear {
            loadLikeStatus()
            likeCount = comment.likeCount ?? 0
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentId: comment.id,
                contentType: .comment,
                reportedUserId: comment.userId,
                reportedUsername: comment.username,
                contentPreview: comment.text
            )
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockUserView(
                userId: comment.userId,
                username: comment.username,
                profilePictureUrl: comment.userProfilePictureUrl
            )
        }
    }
    
    // MARK: - Actions
    
    private func loadLikeStatus() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        CommentService.shared.hasUserLikedComment(logId: logId, commentId: comment.id, userId: userId) { hasLiked, _ in
            DispatchQueue.main.async {
                self.isLiked = hasLiked
            }
        }
    }
    
    private func toggleLike() {
        let previousLikeState = isLiked
        let previousCount = likeCount
        
        // Optimistic update
        isLiked.toggle()
        likeCount = isLiked ? likeCount + 1 : max(0, likeCount - 1)
        
        CommentService.shared.toggleCommentLike(logId: logId, commentId: comment.id) { newLikeState, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error toggling like: \(error.localizedDescription)")
                    // Revert on error
                    self.isLiked = previousLikeState
                    self.likeCount = previousCount
                }
            }
        }
    }
    
    private func deleteReply(_ reply: ReviewComment) {
        CommentService.shared.deleteComment(logId: logId, commentId: reply.id) { error in
            if let error = error {
                print("❌ Error deleting reply: \(error.localizedDescription)")
            } else {
                // Trigger parent refresh
                onToggleExpand()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onToggleExpand()
                }
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Reply Row View

struct ReplyRowView: View {
    let reply: ReviewComment
    let logId: String
    let onDelete: () -> Void
    
    @State private var isLiked = false
    @State private var likeCount: Int = 0
    @State private var showDeleteConfirmation = false
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    
    private var isOwnReply: Bool {
        Auth.auth().currentUser?.uid == reply.userId
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar (smaller)
            if let urlString = reply.userProfilePictureUrl, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(reply.username.prefix(1)).uppercased())
                            .foregroundColor(.white)
                            .font(.caption)
                    )
            }
            
            // Reply content
            VStack(alignment: .leading, spacing: 6) {
                // Username and timestamp
                HStack {
                    Text(reply.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("•")
                        .foregroundColor(.gray)
                        .font(.caption2)
                    
                    Text(timeAgoString(from: reply.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Delete button (only for own replies)
                    if isOwnReply {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                }
                
                // Reply text
                Text(reply.text)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Like button
                Button(action: toggleLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor(isLiked ? .red : .gray)
                        
                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .confirmationDialog("Delete Reply", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this reply?")
        }
        .onAppear {
            loadLikeStatus()
            likeCount = reply.likeCount ?? 0
        }
    }
    
    // MARK: - Actions
    
    private func loadLikeStatus() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        CommentService.shared.hasUserLikedComment(logId: logId, commentId: reply.id, userId: userId) { hasLiked, _ in
            DispatchQueue.main.async {
                self.isLiked = hasLiked
            }
        }
    }
    
    private func toggleLike() {
        let previousLikeState = isLiked
        let previousCount = likeCount
        
        // Optimistic update
        isLiked.toggle()
        likeCount = isLiked ? likeCount + 1 : max(0, likeCount - 1)
        
        CommentService.shared.toggleCommentLike(logId: logId, commentId: reply.id) { newLikeState, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error toggling like: \(error.localizedDescription)")
                    // Revert on error
                    self.isLiked = previousLikeState
                    self.likeCount = previousCount
                }
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

