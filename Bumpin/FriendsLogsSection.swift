import SwiftUI
import FirebaseFirestore

// MARK: - Enhanced Friends Logs Section

struct EnhancedFriendsLogsSection: View {
    let itemId: String
    let itemType: String
    let itemTitle: String
    
    @State private var friendsLogs: [MusicLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            // Section header
            ProfileSectionHeader(
                title: "Friends' Activity",
                subtitle: friendsLogs.isEmpty ? "No friend activity yet" : "\(friendsLogs.count) friend logs",
                icon: "person.2.fill",
                action: friendsLogs.count > 3 ? { /* Show all friends logs */ } : nil,
                actionTitle: friendsLogs.count > 3 ? "View All" : nil
            )
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if friendsLogs.isEmpty {
                emptyView
            } else {
                friendsLogsContent
            }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
        .onAppear {
            Task { await loadFriendsLogs() }
        }
    }
    
    private var friendsLogsContent: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            ForEach(Array(friendsLogs.prefix(3))) { log in
                FriendLogRow(log: log)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading friends' activity...")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.warning)
            Text("Unable to load friends' activity")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
            Text(message)
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            Image(systemName: "person.2.circle")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            Text("No friends' activity")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
            Text("Your friends haven't logged this \(itemType) yet")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadFriendsLogs() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // This would fetch friends' logs for this specific item
            // For now, using mock data to demonstrate the UI
            print("🎯 Loading friends' logs for \(itemType): \(itemTitle)")
            
            // Simulate loading delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Mock data for demonstration
            friendsLogs = []
            print("📊 Found \(friendsLogs.count) friends' logs")
        } catch {
            print("❌ Error loading friends' logs: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            friendsLogs = []
        }
        
        isLoading = false
    }
}

// MARK: - Friend Log Row Component

struct FriendLogRow: View {
    let log: MusicLog
    
    var body: some View {
        HStack(alignment: .top, spacing: ProfileDesignSystem.Spacing.md) {
            // Friend avatar
            Circle()
                .fill(ProfileDesignSystem.Colors.surface)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("F") // Would use friend's initial
                        .font(ProfileDesignSystem.Typography.captionLarge)
                        .fontWeight(.bold)
                        .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.xs) {
                // Friend name and rating
                HStack(alignment: .center, spacing: ProfileDesignSystem.Spacing.sm) {
                    Text("Friend Name") // Would use actual friend name
                        .font(ProfileDesignSystem.Typography.captionLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                    
                    // Friend's rating
                    if let rating = log.rating, rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundColor(star <= rating ? ProfileDesignSystem.Colors.ratingGold : ProfileDesignSystem.Colors.ratingInactive)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ProfileDesignSystem.Colors.ratingGold.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                    
                    Text(log.dateLogged, style: .relative)
                        .font(ProfileDesignSystem.Typography.captionSmall)
                        .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                }
                
                // Review text if available
                if let review = log.review, !review.isEmpty {
                    Text(review)
                        .font(ProfileDesignSystem.Typography.bodySmall)
                        .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                }
                
                // Engagement indicators
                HStack(spacing: ProfileDesignSystem.Spacing.md) {
                    if log.isLiked == true {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                            Text("Liked")
                        }
                        .font(ProfileDesignSystem.Typography.captionSmall)
                        .foregroundColor(ProfileDesignSystem.Colors.error)
                    }
                    
                    if log.thumbsUp == true {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.2.squarepath")
                            Text("Reposted")
                        }
                        .font(ProfileDesignSystem.Typography.captionSmall)
                        .foregroundColor(ProfileDesignSystem.Colors.info)
                    }
                    
                    if let commentCount = log.commentCount, commentCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                            Text("\(commentCount)")
                        }
                        .font(ProfileDesignSystem.Typography.captionSmall)
                        .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(ProfileDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                .fill(ProfileDesignSystem.Colors.surfaceSecondary)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedFriendsLogsSection(
            itemId: "sample-id",
            itemType: "song",
            itemTitle: "Sample Song"
        )
    }
    .padding()
}