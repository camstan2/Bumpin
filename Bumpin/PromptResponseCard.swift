import SwiftUI

struct PromptResponseCard: View {
    let response: PromptResponse
    let coordinator: DailyPromptCoordinator
    let showUserInfo: Bool
    let onTap: (() -> Void)?
    
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var commentCount = 0
    @State private var isSubmittingLike = false
    
    init(response: PromptResponse, coordinator: DailyPromptCoordinator, showUserInfo: Bool = true, onTap: (() -> Void)? = nil) {
        self.response = response
        self.coordinator = coordinator
        self.showUserInfo = showUserInfo
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info (if enabled)
            if showUserInfo {
                userInfoSection
            }
            
            // Song info
            songInfoSection
            
            // Explanation (if provided)
            if let explanation = response.explanation, !explanation.isEmpty {
                explanationSection(explanation)
            }
            
            // Engagement row
            engagementSection
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            loadInteractionData()
        }
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        HStack(spacing: 12) {
            // Profile picture
            AsyncImage(url: URL(string: response.userProfilePictureUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            
            // User name and timestamp
            VStack(alignment: .leading, spacing: 2) {
                Text(response.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(timeAgo(response.submittedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Menu button
            Menu {
                Button(action: {
                    // Share response
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                if response.userId != coordinator.promptService.currentUserId {
                    Button(action: {
                        // Report response
                        Task {
                            await coordinator.interactionService.reportResponse(response.id, reason: "inappropriate")
                        }
                    }) {
                        Label("Report", systemImage: "flag")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color(.tertiarySystemBackground)))
            }
        }
    }
    
    // MARK: - Song Info Section
    
    private var songInfoSection: some View {
        HStack(spacing: 16) {
            // Album artwork
            AsyncImage(url: URL(string: response.artworkUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
            
            // Song details
            VStack(alignment: .leading, spacing: 4) {
                Text(response.songTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(response.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let albumName = response.albumName, !albumName.isEmpty {
                    Text(albumName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Play button (if Apple Music URL available)
            if let appleMusicUrl = response.appleMusicUrl,
               let url = URL(string: appleMusicUrl) {
                Button(action: {
                    UIApplication.shared.open(url)
                    coordinator.trackPromptEngagement("song_play_tapped")
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
            }
        }
    }
    
    // MARK: - Explanation Section
    
    private func explanationSection(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            Text(explanation)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
    }
    
    // MARK: - Engagement Section
    
    private var engagementSection: some View {
        HStack(spacing: 20) {
            // Like button
            Button(action: {
                toggleLike()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundColor(isLiked ? .red : .secondary)
                    
                    if likeCount > 0 {
                        Text("\(likeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(isSubmittingLike)
            .buttonStyle(PlainButtonStyle())
            
            // Comment button
            Button(action: {
                onTap?() // Open detail view for commenting
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if commentCount > 0 {
                        Text("\(commentCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Response time indicator
            if showUserInfo {
                Text("Responded \(timeAgo(response.submittedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Helper Methods
    
    private func loadInteractionData() {
        // Load like status and counts
        isLiked = coordinator.interactionService.isResponseLiked(response.id)
        likeCount = coordinator.interactionService.getLikeCount(for: response.id)
        commentCount = coordinator.interactionService.getCommentCount(for: response.id)
        
        // Start listening for updates
        Task {
            await coordinator.interactionService.loadLikesForResponse(response.id)
            await coordinator.interactionService.loadCommentsForResponse(response.id)
        }
    }
    
    private func toggleLike() {
        guard !isSubmittingLike else { return }
        
        isSubmittingLike = true
        
        // Optimistic update
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        Task {
            let success = await coordinator.toggleLikeResponse(response)
            
            await MainActor.run {
                isSubmittingLike = false
                
                if !success {
                    // Revert optimistic update
                    isLiked = wasLiked
                    likeCount += wasLiked ? 1 : -1
                }
                
                // Update from service state
                isLiked = coordinator.interactionService.isResponseLiked(response.id)
                likeCount = coordinator.interactionService.getLikeCount(for: response.id)
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Compact Response Card

struct CompactPromptResponseCard: View {
    let response: PromptResponse
    let coordinator: DailyPromptCoordinator
    let onTap: (() -> Void)?
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Album artwork
                AsyncImage(url: URL(string: response.artworkUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        )
                }
                
                // Song and user info
                VStack(alignment: .leading, spacing: 2) {
                    Text(response.songTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(response.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(response.username)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Like count
                let likeCount = coordinator.interactionService.getLikeCount(for: response.id)
                if likeCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Text("\(likeCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        PromptResponseCard(
            response: PromptResponse(
                promptId: "test",
                userId: "user1",
                username: "MusicLover",
                userProfilePictureUrl: nil,
                songId: "123",
                songTitle: "Good 4 U",
                artistName: "Olivia Rodrigo",
                albumName: "SOUR",
                explanation: "This song perfectly captures that vacation energy - carefree, upbeat, and ready for adventure!"
            ),
            coordinator: DailyPromptCoordinator()
        )
        
        CompactPromptResponseCard(
            response: PromptResponse(
                promptId: "test",
                userId: "user2",
                username: "VinylCollector",
                userProfilePictureUrl: nil,
                songId: "456",
                songTitle: "Blinding Lights",
                artistName: "The Weeknd"
            ),
            coordinator: DailyPromptCoordinator(),
            onTap: {}
        )
    }
    .padding()
}
