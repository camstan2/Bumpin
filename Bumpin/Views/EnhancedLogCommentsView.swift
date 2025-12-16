import SwiftUI
import FirebaseAuth

struct EnhancedLogCommentsView: View {
    let log: MusicLog
    @Environment(\.dismiss) private var dismiss
    
    @State private var comments: [ReviewComment] = []
    @State private var expandedComments: Set<String> = []
    @State private var commentReplies: [String: [ReviewComment]] = [:]
    @State private var isLoading = false
    @State private var newCommentText = ""
    @State private var replyingTo: ReviewComment? = nil
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Comments list
                    ScrollView {
                        if isLoading {
                            loadingView
                        } else if comments.isEmpty {
                            emptyStateView
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(comments) { comment in
                                    EnhancedCommentRowView(
                                        comment: comment,
                                        logId: log.id,
                                        isExpanded: expandedComments.contains(comment.id),
                                        replies: commentReplies[comment.id] ?? [],
                                        onToggleExpand: {
                                            toggleExpanded(comment)
                                        },
                                        onReply: {
                                            startReply(to: comment)
                                        },
                                        onDelete: {
                                            deleteComment(comment)
                                        }
                                    )
                                    
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80) // Space for input bar
                        }
                    }
                    
                    Spacer()
                }
                
                // Fixed input bar at bottom
                VStack {
                    Spacer()
                    CommentInputBar(
                        text: $newCommentText,
                        replyingTo: replyingTo,
                        isInputFocused: _isInputFocused,
                        onCancel: {
                            cancelReply()
                        },
                        onSend: {
                            sendComment()
                        }
                    )
                }
            }
            // Allow tapping anywhere above the input bar to dismiss the keyboard
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        isInputFocused = false
                    }
            )
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadComments()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            Text("Loading comments...")
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No comments yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Be the first to share your thoughts!")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Actions
    
    private func loadComments() {
        isLoading = true
        CommentService.shared.fetchComments(logId: log.id) { fetchedComments, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Error loading comments: \(error.localizedDescription)")
                    return
                }
                
                self.comments = fetchedComments ?? []
            }
        }
    }
    
    private func toggleExpanded(_ comment: ReviewComment) {
        if expandedComments.contains(comment.id) {
            expandedComments.remove(comment.id)
            commentReplies[comment.id] = nil
        } else {
            expandedComments.insert(comment.id)
            loadReplies(for: comment)
        }
    }
    
    private func loadReplies(for comment: ReviewComment) {
        CommentService.shared.fetchReplies(logId: log.id, commentId: comment.id) { replies, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading replies: \(error.localizedDescription)")
                    return
                }
                
                self.commentReplies[comment.id] = replies ?? []
            }
        }
    }
    
    private func startReply(to comment: ReviewComment) {
        replyingTo = comment
        isInputFocused = true
    }
    
    private func cancelReply() {
        replyingTo = nil
        newCommentText = ""
        isInputFocused = false
    }
    
    private func sendComment() {
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        CommentService.shared.addComment(
            logId: log.id,
            text: trimmedText,
            parentCommentId: replyingTo?.id
        ) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error posting comment: \(error.localizedDescription)")
                    return
                }
                
                // Clear input and reload
                self.newCommentText = ""
                self.replyingTo = nil
                self.isInputFocused = false
                self.loadComments()
            }
        }
    }
    
    private func deleteComment(_ comment: ReviewComment) {
        CommentService.shared.deleteComment(logId: log.id, commentId: comment.id) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error deleting comment: \(error.localizedDescription)")
                    return
                }
                
                // Reload comments
                self.loadComments()
            }
        }
    }
}

// MARK: - Comment Input Bar Component

struct CommentInputBar: View {
    @Binding var text: String
    let replyingTo: ReviewComment?
    @FocusState var isInputFocused: Bool
    let onCancel: () -> Void
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Reply indicator
            if let replyingTo = replyingTo {
                HStack {
                    Text("Replying to @\(replyingTo.username)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Input field
            HStack(spacing: 12) {
                // User avatar placeholder
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                // Text field
                TextField("Add a comment...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                
                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.black)
        }
        .background(Color.black)
    }
}

