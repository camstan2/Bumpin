import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct PromptResponseDetailView: View {
    let response: PromptResponse
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var comments: [PromptResponseComment] = []
    @State private var newCommentText = ""
    @State private var isSubmittingComment = false
    @State private var showCommentInput = false
    
    @State private var replyingTo: PromptResponseComment?
    @State private var expandedComments: Set<String> = []
    @State private var showMentionBar = false
    @State private var mentionCandidates: [MentionCandidate] = []
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    PromptResponseCard(
                        response: response,
                        coordinator: coordinator,
                        showUserInfo: true,
                        onTap: nil
                    )
                    
                    commentsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
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
        .onReceive(coordinator.interactionService.$responseComments) { map in
            if let updated = map[response.id] {
                comments = updated
            }
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
            
            if topLevelComments.isEmpty {
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
                    ForEach(topLevelComments, id: \.id) { comment in
                        CommentRow(
                            comment: comment,
                            replies: replies(for: comment),
                            isExpanded: expandedComments.contains(comment.id),
                            coordinator: coordinator,
                            onToggleReplies: { toggleReplies(for: comment) },
                            onReply: { startReply(to: comment) }
                        )
                    }
                }
            }
        }
    }
    
    private var commentInputSection: some View {
        VStack(spacing: 0) {
            if let replyingTo = replyingTo {
                HStack(spacing: 8) {
                    Text("Replying to \(replyingTo.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        self.replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            
            if showMentionBar && !mentionCandidates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mentionCandidates) { candidate in
                            Button {
                                selectMention(candidate)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "at")
                                    Text(candidate.name)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
            
            Divider()
            
            HStack(spacing: 12) {
                TextField(
                    replyingTo != nil ? "Write a reply..." : "Add a comment...",
                    text: $newCommentText,
                    axis: .vertical
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onChange(of: newCommentText, initial: false) { _, _ in
                    updateMentionCandidates()
                }
                
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
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }
    
    private var topLevelComments: [PromptResponseComment] {
        comments
            .filter { $0.replyToCommentId == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private func replies(for comment: PromptResponseComment) -> [PromptResponseComment] {
        comments
            .filter { $0.replyToCommentId == comment.id }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private func toggleReplies(for comment: PromptResponseComment) {
        if expandedComments.contains(comment.id) {
            expandedComments.remove(comment.id)
        } else {
            expandedComments.insert(comment.id)
        }
    }
    
    private func startReply(to comment: PromptResponseComment) {
        replyingTo = comment
        expandedComments.insert(comment.id)
        isInputFocused = true
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
        
        let replyTarget = replyingTo
        isSubmittingComment = true
        
        Task {
            let success = await coordinator.addComment(
                to: response,
                text: text,
                replyTo: replyTarget
            )
            
            await MainActor.run {
                isSubmittingComment = false
                
                if success {
                    newCommentText = ""
                    if let target = replyTarget {
                        expandedComments.insert(target.id)
                    }
                    replyingTo = nil
                    clearMentionSuggestions()
                    comments = coordinator.interactionService.responseComments[response.id] ?? []
                }
            }
        }
    }
    
    private func updateMentionCandidates() {
        guard let atIndex = newCommentText.lastIndex(of: "@") else {
            clearMentionSuggestions()
            return
        }
        
        let afterIndex = newCommentText.index(after: atIndex)
        if afterIndex > newCommentText.endIndex {
            clearMentionSuggestions()
            return
        }
        
        let suffix = newCommentText[afterIndex...]
        let allowed = CharacterSet.alphanumerics
        var token = ""
        for scalar in suffix.unicodeScalars {
            if allowed.contains(scalar) {
                token.unicodeScalars.append(scalar)
            } else {
                break
            }
        }
        
        if token.isEmpty && suffix.isEmpty {
            clearMentionSuggestions()
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            clearMentionSuggestions()
            return
        }
        
        Firestore.firestore().collection("users").document(currentUserId).getDocument { snapshot, _ in
            let following = (snapshot?.data()?["following"] as? [String]) ?? []
            if following.isEmpty {
                DispatchQueue.main.async {
                    self.clearMentionSuggestions()
                }
                return
            }
            
            let batches = following.chunked(into: 10)
            var aggregated: [MentionCandidate] = []
            let group = DispatchGroup()
            
            for batch in batches {
                group.enter()
                Firestore.firestore().collection("users")
                    .whereField("uid", in: batch)
                    .getDocuments { documents, _ in
                        defer { group.leave() }
                        let users = documents?.documents ?? []
                        for doc in users {
                            let data = doc.data()
                            let uid = data["uid"] as? String ?? doc.documentID
                            let displayName = (data["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            let username = (data["username"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            let name = !displayName.isEmpty ? displayName : username
                            aggregated.append(MentionCandidate(id: uid, name: name))
                        }
                    }
            }
            
            group.notify(queue: .main) {
                let normalized = token.lowercased()
                let filtered = aggregated.filter {
                    $0.name.replacingOccurrences(of: " ", with: "").lowercased().hasPrefix(normalized)
                }
                self.mentionCandidates = Array(filtered.prefix(10))
                self.showMentionBar = !self.mentionCandidates.isEmpty
            }
        }
    }
    
    private func selectMention(_ candidate: MentionCandidate) {
        guard let atIndex = newCommentText.lastIndex(of: "@") else { return }
        let afterIndex = newCommentText.index(after: atIndex)
        let suffix = newCommentText[afterIndex...]
        let allowed = CharacterSet.alphanumerics
        var consumed = 0
        for scalar in suffix.unicodeScalars {
            if allowed.contains(scalar) {
                consumed += 1
            } else {
                break
            }
        }
        let tokenEnd = newCommentText.index(afterIndex, offsetBy: consumed, limitedBy: newCommentText.endIndex) ?? newCommentText.endIndex
        let prefix = newCommentText[..<atIndex]
        let remainder = newCommentText[tokenEnd...]
        let sanitized = candidate.name.replacingOccurrences(of: " ", with: "")
        newCommentText = String(prefix) + "@" + sanitized + " " + String(remainder)
        clearMentionSuggestions()
    }
    
    private func clearMentionSuggestions() {
        showMentionBar = false
        mentionCandidates = []
    }
}

struct CommentRow: View {
    let comment: PromptResponseComment
    let replies: [PromptResponseComment]
    let isExpanded: Bool
    let coordinator: DailyPromptCoordinator
    let onToggleReplies: () -> Void
    let onReply: () -> Void
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: navigateToUserProfile) {
                    UserAvatarView(
                        userId: comment.userId,
                        existingUrl: comment.userProfilePictureUrl,
                        initials: comment.username,
                        size: 28
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button(action: navigateToUserProfile) {
                            Text(comment.username)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(timeAgoString(for: comment.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text(comment.text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 16) {
                        likeButton
                        
                        Button(action: onReply) {
                            Text("Reply")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            if !replies.isEmpty {
                Button(action: onToggleReplies) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                        Text(isExpanded ? "Hide replies" : "Show replies (\(replies.count))")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.purple)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 44)
            }
            
            if isExpanded && !replies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(replies, id: \.id) { reply in
                        PromptResponseReplyRow(reply: reply, coordinator: coordinator)
                    }
                }
                .padding(.leading, 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    private var likeButton: some View {
        Button(action: {
            Task {
                await coordinator.interactionService.toggleLikeComment(comment.id, responseId: comment.responseId)
            }
        }) {
            HStack(spacing: 4) {
                let isLiked = coordinator.interactionService.isCommentLiked(comment.id)
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundColor(isLiked ? .red : .secondary)
                
                let liveCount = coordinator.interactionService.getCommentLikeCount(for: comment.id)
                let count = liveCount > 0 ? liveCount : comment.likeCount
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func navigateToUserProfile() {
        navigationCoordinator.navigateToUserProfile(comment.userId)
    }
}

struct PromptResponseReplyRow: View {
    let reply: PromptResponseComment
    let coordinator: DailyPromptCoordinator
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: navigateToUserProfile) {
                UserAvatarView(
                    userId: reply.userId,
                    existingUrl: reply.userProfilePictureUrl,
                    initials: reply.username,
                    size: 24
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Button(action: navigateToUserProfile) {
                        Text(reply.username)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(timeAgoString(for: reply.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if let target = reply.replyToUsername, !target.isEmpty {
                    Text("Replying to @\(target)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(reply.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Button(action: {
                    Task {
                        await coordinator.interactionService.toggleLikeComment(reply.id, responseId: reply.responseId)
                    }
                }) {
                    HStack(spacing: 4) {
                        let isLiked = coordinator.interactionService.isCommentLiked(reply.id)
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.caption2)
                            .foregroundColor(isLiked ? .red : .secondary)
                        
                        let liveCount = coordinator.interactionService.getCommentLikeCount(for: reply.id)
                        let count = liveCount > 0 ? liveCount : reply.likeCount
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func navigateToUserProfile() {
        navigationCoordinator.navigateToUserProfile(reply.userId)
    }
}

private struct MentionCandidate: Identifiable, Equatable {
    let id: String
    let name: String
}

private func timeAgoString(for date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
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
