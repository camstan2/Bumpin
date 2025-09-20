import SwiftUI

struct PromptLeaderboardView: View {
    let prompt: DailyPrompt
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: LeaderboardTab = .songs
    @State private var responses: [PromptResponse] = []
    @State private var isLoadingResponses = false
    
    enum LeaderboardTab: String, CaseIterable, Identifiable {
        case songs = "Top Songs"
        case responses = "All Responses"
        case friends = "Friends"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .songs: return "chart.bar.fill"
            case .responses: return "music.note.list"
            case .friends: return "person.2.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab selector
                tabSelector
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 12) {
                        switch selectedTab {
                        case .songs:
                            songsLeaderboardContent
                        case .responses:
                            allResponsesContent
                        case .friends:
                            friendsResponsesContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: shareLeaderboard) {
                            Label("Share Leaderboard", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            coordinator.trackPromptEngagement("leaderboard_refresh_tapped")
                            Task { await coordinator.refreshAll() }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .onAppear {
            coordinator.trackPromptEngagement("leaderboard_viewed", promptId: prompt.id)
            loadAllResponses()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Prompt info
            VStack(spacing: 8) {
                CategoryBadge(category: prompt.category)
                
                Text(prompt.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let description = prompt.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Stats row
            HStack(spacing: 32) {
                LeaderboardStatItem(
                    value: "\(prompt.totalResponses)",
                    label: "Responses",
                    color: .blue
                )
                
                if let leaderboard = coordinator.getCurrentLeaderboard() {
                    LeaderboardStatItem(
                        value: "\(leaderboard.songRankings.count)",
                        label: "Songs",
                        color: .purple
                    )
                    
                    LeaderboardStatItem(
                        value: "\(leaderboard.topGenres.count)",
                        label: "Genres",
                        color: .green
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(LeaderboardTab.allCases) { tab in
                Button(action: {
                    selectedTab = tab
                    coordinator.trackPromptEngagement("leaderboard_tab_changed", promptId: prompt.id)
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(selectedTab == tab ? .purple : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.purple : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Songs Leaderboard Content
    
    private var songsLeaderboardContent: some View {
        Group {
            if let leaderboard = coordinator.getCurrentLeaderboard(),
               !leaderboard.songRankings.isEmpty {
                
                ForEach(Array(leaderboard.songRankings.enumerated()), id: \.element.id) { index, ranking in
                    LeaderboardSongRow(
                        ranking: ranking,
                        rank: index + 1,
                        coordinator: coordinator,
                        onTap: {
                            coordinator.trackPromptEngagement("leaderboard_song_tapped")
                        }
                    )
                }
                
            } else {
                emptyStateView("No songs yet", "Be the first to respond!")
            }
        }
    }
    
    // MARK: - All Responses Content
    
    private var allResponsesContent: some View {
        Group {
            if isLoadingResponses {
                ForEach(0..<5, id: \.self) { _ in
                    ResponseCardSkeleton()
                }
            } else if !responses.isEmpty {
                ForEach(responses, id: \.id) { response in
                    PromptResponseCard(
                        response: response,
                        coordinator: coordinator,
                        showUserInfo: true,
                        onTap: {
                            // Could open response detail
                        }
                    )
                }
            } else {
                emptyStateView("No responses yet", "Be the first to share your song!")
            }
        }
    }
    
    // MARK: - Friends Responses Content
    
    private var friendsResponsesContent: some View {
        Group {
            if isLoadingResponses {
                ForEach(0..<3, id: \.self) { _ in
                    ResponseCardSkeleton()
                }
            } else {
                let friendsResponses = responses.filter { response in
                    // This would need to check if user is following this person
                    // For now, show all responses
                    return true
                }
                
                if !friendsResponses.isEmpty {
                    ForEach(friendsResponses, id: \.id) { response in
                        PromptResponseCard(
                            response: response,
                            coordinator: coordinator,
                            showUserInfo: true,
                            onTap: {
                                // Could open response detail
                            }
                        )
                    }
                } else {
                    emptyStateView("No friends have responded", "Share the prompt with your friends!")
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func emptyStateView(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func shareLeaderboard() {
        let shareText = "Check out the leaderboard for today's prompt: \"\(prompt.title)\" on Bumpin! 🎵"
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
        
        coordinator.trackPromptEngagement("leaderboard_shared", promptId: prompt.id)
    }
    
    private func loadAllResponses() {
        isLoadingResponses = true
        
        Task {
            let allResponses = await coordinator.getResponsesForCurrentPrompt(includeFriends: true)
            
            await MainActor.run {
                self.responses = allResponses
                self.isLoadingResponses = false
            }
        }
    }
}

// MARK: - Leaderboard Song Row

struct LeaderboardSongRow: View {
    let ranking: SongRanking
    let rank: Int
    let coordinator: DailyPromptCoordinator
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Rank indicator
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                    
                    if rank <= 3 {
                        Image(systemName: rankIcon)
                            .font(.caption)
                            .foregroundColor(.white)
                    } else {
                        Text("\(rank)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                // Song artwork
                AsyncImage(url: URL(string: ranking.artworkUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.8))
                        )
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(ranking.songTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(ranking.artistName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Sample users who chose this song
                    if !ranking.sampleUsers.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(ranking.sampleUsers.prefix(3)), id: \.id) { user in
                                AsyncImage(url: URL(string: user.profilePictureUrl ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 16, height: 16)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        )
                                }
                            }
                            
                            if ranking.sampleUsers.count > 3 {
                                Text("+\(ranking.sampleUsers.count - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Vote stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(ranking.voteCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(Int(ranking.percentage))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(ranking.voteCount == 1 ? "vote" : "votes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .purple
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
}

// MARK: - Response Card Skeleton

struct ResponseCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info skeleton
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 10)
                }
                
                Spacer()
            }
            
            // Song info skeleton
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 14)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 10)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .opacity(isAnimating ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Leaderboard Stat Item

struct LeaderboardStatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PromptLeaderboardView(
        prompt: DailyPrompt(
            title: "First song you play on vacation",
            description: "That perfect song that kicks off your getaway mood",
            category: .activity,
            createdBy: "admin",
            expiresAt: Date().addingTimeInterval(3600)
        ),
        coordinator: DailyPromptCoordinator()
    )
}
