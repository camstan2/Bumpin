import SwiftUI
import FirebaseAuth

struct DailyPromptTabView: View {
    @StateObject private var coordinator = DailyPromptCoordinator()
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var showResponseSubmission = false
    @State private var showLeaderboard = false
    @State private var showPromptHistory = false
    @State private var selectedResponse: PromptResponse?
    @State private var showResponseDetail = false
    
    // New state for enhanced sections
    @State private var showAllTopSongs = false
    @State private var showAllTopResponses = false
    @State private var showAllFriendsResponses = false
    @State private var showAllRecentPrompts = false
    
    // Expand/collapse states
    @State private var topSongsExpanded = false
    @State private var topResponsesExpanded = false
    @State private var friendsResponsesExpanded = false
    @State private var recentPromptsExpanded = false
    
    // Data loading states
    @State private var topResponses: [PromptResponse] = []
    @State private var friendResponses: [PromptResponse] = []
    @State private var isLoadingTopResponses = false
    @State private var isLoadingFriendResponses = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with daily prompt title
                headerSection
                
                // Main prompt card
                if let prompt = coordinator.currentPrompt {
                    currentPromptSection(prompt)
                } else {
                    noActivePromptSection
                }
                
                // User's response (if submitted)
                if let userResponse = coordinator.currentUserResponse {
                    userResponseSection(userResponse)
                }
                
                // Only show enhanced sections if user has responded
                if coordinator.hasRespondedToCurrentPrompt {
                    // Top Songs section
                    topSongsSection
                    
                    // Top Responses section  
                    topResponsesSection
                    
                    // Enhanced Friends' Responses section
                    enhancedFriendsResponsesSection
                    
                    // Recent Prompts section
                    recentPromptsSection
                }
                
                // Quick stats section (moved to bottom)
                userStatsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Extra padding for tab bar
        }
        .refreshable {
            await coordinator.refreshAll()
            loadEnhancedSectionData()
        }
        .onAppear {
            coordinator.trackPromptEngagement("tab_viewed")
            loadEnhancedSectionData()
        }
        .fullScreenCover(isPresented: $showResponseSubmission) {
            PromptResponseSubmissionView(coordinator: coordinator)
                .environmentObject(navigationCoordinator)
        }
        .sheet(isPresented: $showLeaderboard) {
            if let prompt = coordinator.currentPrompt {
                PromptLeaderboardView(prompt: prompt, coordinator: coordinator)
            }
        }
        .sheet(isPresented: $showPromptHistory) {
            PromptHistoryView(coordinator: coordinator)
        }
        .sheet(isPresented: $showResponseDetail) {
            if let response = selectedResponse {
                PromptResponseDetailView(response: response, coordinator: coordinator)
            }
        }
        .sheet(isPresented: $showAllTopSongs) {
            if let prompt = coordinator.currentPrompt {
                AllSongsView(prompt: prompt, coordinator: coordinator)
            }
        }
        .sheet(isPresented: $showAllTopResponses) {
            if let prompt = coordinator.currentPrompt {
                AllPopularResponsesView(prompt: prompt, coordinator: coordinator)
            }
        }
        .sheet(isPresented: $showAllFriendsResponses) {
            if let prompt = coordinator.currentPrompt {
                AllFriendResponsesView(prompt: prompt, coordinator: coordinator)
            }
        }
        .sheet(isPresented: $showAllRecentPrompts) {
            PromptHistoryView(coordinator: coordinator)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Daily Prompt")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let timeRemaining = coordinator.formatTimeRemaining() {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text(timeRemaining)
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Current Prompt Section
    
    private func currentPromptSection(_ prompt: DailyPrompt) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category badge and response count
            HStack {
                CategoryBadge(category: prompt.category)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(prompt.totalResponses)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.secondary)
            }
            
            // Prompt title and description
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if let description = prompt.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Action button
            if coordinator.canRespondToCurrentPrompt {
                Button(action: {
                    showResponseSubmission = true
                    coordinator.trackPromptEngagement("response_button_tapped", promptId: prompt.id)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                        Text("Pick Your Song")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(ScaleButtonStyle())
            } else if coordinator.hasRespondedToCurrentPrompt {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You've responded!")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                    Text("Prompt Expired")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - No Active Prompt Section
    
    private var noActivePromptSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Active Prompt")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Check back tomorrow for a new daily prompt!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showPromptHistory = true }) {
                Text("View Past Prompts")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - User Response Section
    
    private func userResponseSection(_ response: PromptResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Response")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("Submitted \(timeAgo(response.submittedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            PromptResponseCard(
                response: response,
                coordinator: coordinator,
                showUserInfo: false,
                onTap: {
                    selectedResponse = response
                    showResponseDetail = true
                }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - User Stats Section
    
    private var userStatsSection: some View {
        HStack(spacing: 20) {
            PromptStatCard(
                title: "Streak",
                value: "\(coordinator.userStreak)",
                subtitle: coordinator.userStreak == 1 ? "day" : "days",
                color: .orange,
                icon: "flame.fill"
            )
            
            PromptStatCard(
                title: "Total",
                value: "\(coordinator.userTotalResponses)",
                subtitle: coordinator.userTotalResponses == 1 ? "response" : "responses",
                color: .purple,
                icon: "music.note"
            )
            
            if let stats = coordinator.getUserStats(),
               stats.longestStreak > 0 {
                PromptStatCard(
                    title: "Best",
                    value: "\(stats.longestStreak)",
                    subtitle: stats.longestStreak == 1 ? "day" : "days",
                    color: .green,
                    icon: "crown.fill"
                )
            }
        }
    }
    
    // MARK: - Top Songs Section
    
    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Songs")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    showAllTopSongs = true
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            if let leaderboard = coordinator.getCurrentLeaderboard() {
                let songsToShow = topSongsExpanded ? leaderboard.songRankings : Array(leaderboard.songRankings.prefix(5))
                
                LazyVStack(spacing: 8) {
                    ForEach(Array(songsToShow.enumerated()), id: \.element.id) { index, ranking in
                        LeaderboardRowPreview(ranking: ranking, rank: index + 1)
                    }
                }
                
                if leaderboard.songRankings.count > 5 {
                    Button(topSongsExpanded ? "Load Less" : "Load More") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            topSongsExpanded.toggle()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
            } else {
                Text("No songs selected yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Top Responses Section
    
    private var topResponsesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Responses")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    showAllTopResponses = true
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            if isLoadingTopResponses {
                ForEach(0..<3, id: \.self) { _ in
                    ResponseCardSkeleton()
                }
            } else if topResponses.isEmpty {
                Text("No responses yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                let responsesToShow = topResponsesExpanded ? topResponses : Array(topResponses.prefix(5))
                
                LazyVStack(spacing: 12) {
                    ForEach(responsesToShow, id: \.id) { response in
                        PromptResponseCard(
                            response: response,
                            coordinator: coordinator,
                            showUserInfo: true,
                            onTap: {
                                selectedResponse = response
                                showResponseDetail = true
                            }
                        )
                    }
                }
                
                if topResponses.count > 5 {
                    Button(topResponsesExpanded ? "Load Less" : "Load More") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            topResponsesExpanded.toggle()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Enhanced Friends Responses Section
    
    private var enhancedFriendsResponsesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friends' Responses")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    showAllFriendsResponses = true
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            if isLoadingFriendResponses {
                ForEach(0..<3, id: \.self) { _ in
                    ResponseCardSkeleton()
                }
            } else if friendResponses.isEmpty {
                Text("No friend responses yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                let responsesToShow = friendsResponsesExpanded ? friendResponses : Array(friendResponses.prefix(5))
                
                LazyVStack(spacing: 12) {
                    ForEach(responsesToShow, id: \.id) { response in
                        PromptResponseCard(
                            response: response,
                            coordinator: coordinator,
                            showUserInfo: true,
                            onTap: {
                                selectedResponse = response
                                showResponseDetail = true
                            }
                        )
                    }
                }
                
                if friendResponses.count > 5 {
                    Button(friendsResponsesExpanded ? "Load Less" : "Load More") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            friendsResponsesExpanded.toggle()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Recent Prompts Section
    
    private var recentPromptsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Prompts")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    showAllRecentPrompts = true
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            let promptsToShow = recentPromptsExpanded ? coordinator.promptService.promptHistory : Array(coordinator.promptService.promptHistory.prefix(5))
            
            LazyVStack(spacing: 12) {
                ForEach(promptsToShow, id: \.id) { prompt in
                    PromptHistoryCard(prompt: prompt) {
                        coordinator.showPromptDetail(prompt)
                    }
                }
            }
            
            if coordinator.promptService.promptHistory.count > 5 {
                Button(recentPromptsExpanded ? "Load Less" : "Load More") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        recentPromptsExpanded.toggle()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.top, 8)
            }
            
            if coordinator.promptService.promptHistory.isEmpty {
                Text("No previous prompts available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    
    // MARK: - Data Loading Functions
    
    private func loadEnhancedSectionData() {
        guard let prompt = coordinator.currentPrompt else { return }
        
        Task {
            await loadTopResponses(for: prompt.id)
            await loadFriendResponses(for: prompt.id)
        }
    }
    
    private func loadTopResponses(for promptId: String) async {
        isLoadingTopResponses = true
        defer { isLoadingTopResponses = false }
        
        let responses = await coordinator.promptService.fetchResponsesForPrompt(promptId, limit: 50)
        let sortedByEngagement = responses.sorted { 
            ($0.likeCount + $0.commentCount) > ($1.likeCount + $1.commentCount)
        }
        
        await MainActor.run {
            topResponses = sortedByEngagement
        }
    }
    
    private func loadFriendResponses(for promptId: String) async {
        isLoadingFriendResponses = true
        defer { isLoadingFriendResponses = false }
        
        let allResponses = await coordinator.promptService.fetchResponsesForPrompt(promptId, limit: 100)
        
        // Filter to only include friends (placeholder implementation)
        // TODO: Implement actual friend filtering when friend system is available
        let friendsOnly = allResponses
        
        await MainActor.run {
            friendResponses = friendsOnly
        }
    }
    
    // MARK: - Helper Functions
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct StreakBadge: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text("\(streak)")
                .fontWeight(.bold)
                .foregroundColor(.orange)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.orange.opacity(0.15))
        )
    }
}

struct CategoryBadge: View {
    let category: PromptCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
            Text(category.displayName)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.color.opacity(0.15))
        .foregroundColor(category.color)
        .clipShape(Capsule())
    }
}

struct PromptStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct FriendsResponsePreview: View {
    let ranking: SongRanking
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(
                        rank == 1 ? Color.yellow :
                        rank == 2 ? Color.gray :
                        Color.brown
                    )
                )
            
            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.songTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(ranking.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Vote count
            Text("\(ranking.voteCount)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.purple)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

struct LeaderboardRowPreview: View {
    let ranking: SongRanking
    let rank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.songTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(ranking.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ranking.voteCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("\(Int(ranking.percentage))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct PromptHistoryCard: View {
    let prompt: DailyPrompt
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                CategoryBadge(category: prompt.category)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(timeAgo(prompt.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(prompt.totalResponses)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Note: ScaleButtonStyle already exists in ArtistProfileView

#Preview {
    DailyPromptTabView()
        .environmentObject(NavigationCoordinator())
}

