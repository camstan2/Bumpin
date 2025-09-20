import SwiftUI

struct PromptResponseDetailView: View {
    let response: PromptResponse
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var comments: [PromptResponseComment] = []
    @State private var newCommentText = ""
    @State private var isSubmittingComment = false
    @State private var showCommentInput = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Response card
                    PromptResponseCard(
                        response: response,
                        coordinator: coordinator,
                        showUserInfo: true,
                        onTap: nil
                    )
                    
                    // Comments section
                    commentsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // Space for comment input
            }
            .navigationTitle("Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                commentInputSection
            }
        }
        .onAppear {
            loadComments()
        }
    }
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Comments")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(comments.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Be the first to share your thoughts!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(comments, id: \.id) { comment in
                        CommentRow(comment: comment, coordinator: coordinator)
                    }
                }
            }
        }
    }
    
    private var commentInputSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(1...4)
                
                Button(action: submitComment) {
                    if isSubmittingComment {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(
                        newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                        Color.gray : Color.purple
                    )
                )
                .foregroundColor(.white)
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingComment)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    private func loadComments() {
        comments = coordinator.interactionService.responseComments[response.id] ?? []
        
        Task {
            await coordinator.interactionService.loadCommentsForResponse(response.id)
            
            await MainActor.run {
                comments = coordinator.interactionService.responseComments[response.id] ?? []
            }
        }
    }
    
    private func submitComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSubmittingComment = true
        
        Task {
            let success = await coordinator.addComment(to: response, text: text)
            
            await MainActor.run {
                isSubmittingComment = false
                
                if success {
                    newCommentText = ""
                    // Reload comments
                    comments = coordinator.interactionService.responseComments[response.id] ?? []
                }
            }
        }
    }
}

struct CommentRow: View {
    let comment: PromptResponseComment
    let coordinator: DailyPromptCoordinator
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile picture
            AsyncImage(url: URL(string: comment.userProfilePictureUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    )
            }
            
            // Comment content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(timeAgo(comment.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Like button for comment
                Button(action: {
                    Task {
                        await coordinator.interactionService.toggleLikeComment(comment.id, responseId: comment.responseId)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: coordinator.interactionService.isCommentLiked(comment.id) ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor(coordinator.interactionService.isCommentLiked(comment.id) ? .red : .secondary)
                        
                        let likeCount = coordinator.interactionService.getCommentLikeCount(for: comment.id)
                        if likeCount > 0 {
                            Text("\(likeCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    PromptResponseDetailView(
        response: PromptResponse(
            promptId: "test",
            userId: "user1",
            username: "MusicLover",
            userProfilePictureUrl: nil,
            songId: "123",
            songTitle: "Good 4 U",
            artistName: "Olivia Rodrigo",
            explanation: "This song perfectly captures that vacation energy!"
        ),
        coordinator: DailyPromptCoordinator()
    )
}
