import SwiftUI

struct PromptHistoryView: View {
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPrompt: DailyPrompt?
    @State private var showPromptDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(coordinator.promptService.promptHistory, id: \.id) { prompt in
                        PromptHistoryRow(prompt: prompt) {
                            selectedPrompt = prompt
                            showPromptDetail = true
                        }
                    }
                    
                    if coordinator.promptService.promptHistory.isEmpty {
                        emptyStateView
                    } else {
                        loadMoreButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Prompt History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await coordinator.refreshAll()
            }
        }
        .sheet(isPresented: $showPromptDetail) {
            if let prompt = selectedPrompt {
                PromptDetailView(prompt: prompt, coordinator: coordinator)
            }
        }
        .onAppear {
            coordinator.trackPromptEngagement("history_viewed")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Previous Prompts")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Past daily prompts will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var loadMoreButton: some View {
        Button("Load More") {
            Task {
                await coordinator.promptService.loadMorePromptHistory()
            }
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.purple.opacity(0.1))
        .foregroundColor(.purple)
        .clipShape(Capsule())
        .padding(.top, 20)
    }
}

struct PromptHistoryRow: View {
    let prompt: DailyPrompt
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Date indicator
                VStack(spacing: 4) {
                    Text(dayFormatter.string(from: prompt.date))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(monthFormatter.string(from: prompt.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50)
                
                // Prompt info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        CategoryBadge(category: prompt.category)
                        Spacer()
                        
                        if prompt.isActive {
                            Text("ACTIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(prompt.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let description = prompt.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(prompt.totalResponses)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.secondary)
                        
                        Text(timeAgo(prompt.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Enhanced Prompt Detail View

struct PromptDetailView: View {
    let prompt: DailyPrompt
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    
    // Data state
    @State private var topSongs: [SongRanking] = []
    @State private var popularResponses: [PromptResponse] = []
    @State private var friendResponses: [PromptResponse] = []
    @State private var userResponse: PromptResponse?
    
    // Loading states
    @State private var isLoadingSongs = false
    @State private var isLoadingPopular = false
    @State private var isLoadingFriends = false
    @State private var isLoadingUser = false
    
    // Show more states
    @State private var showAllSongs = false
    @State private var showAllPopular = false
    @State private var showAllFriends = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Prompt header
                    promptHeaderSection
                    
                    // User's own response (if exists)
                    if let userResponse = userResponse {
                        userResponseSection(userResponse)
                    }
                    
                    // Top 5 most popular songs
                    topSongsSection
                    
                    // Top 5 most popular responses (by likes)
                    popularResponsesSection
                    
                    // Top 5 friend responses
                    friendResponsesSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Prompt Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showAllSongs) {
            AllSongsView(prompt: prompt, coordinator: coordinator)
        }
        .sheet(isPresented: $showAllPopular) {
            AllPopularResponsesView(prompt: prompt, coordinator: coordinator)
        }
        .sheet(isPresented: $showAllFriends) {
            AllFriendResponsesView(prompt: prompt, coordinator: coordinator)
        }
        .onAppear {
            loadAllData()
        }
    }
    
    private var promptHeaderSection: some View {
        VStack(spacing: 16) {
            CategoryBadge(category: prompt.category)
            
            Text(prompt.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            if let description = prompt.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(prompt.totalResponses)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Responses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text(dateFormatter.string(from: prompt.date))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    Text("Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - User Response Section
    
    private func userResponseSection(_ response: PromptResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Response")
                .font(.headline)
                .fontWeight(.bold)
            
            PromptResponseCard(
                response: response,
                coordinator: coordinator,
                showUserInfo: false,
                onTap: nil
            )
        }
    }
    
    // MARK: - Top Songs Section
    
    private var topSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Most Popular Songs")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if topSongs.count > 5 {
                    Button("See All") {
                        showAllSongs = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
            
            if isLoadingSongs {
                ForEach(0..<3, id: \.self) { _ in
                    SongRankingSkeleton()
                }
            } else if topSongs.isEmpty {
                Text("No songs selected yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(topSongs.prefix(5).enumerated()), id: \.offset) { index, song in
                    SongRankingRow(ranking: song, rank: index + 1)
                }
            }
        }
    }
    
    // MARK: - Popular Responses Section
    
    private var popularResponsesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Most Liked Responses")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if popularResponses.count > 5 {
                    Button("See All") {
                        showAllPopular = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
            
            if isLoadingPopular {
                ForEach(0..<3, id: \.self) { _ in
                    ResponseCardSkeleton()
                }
            } else if popularResponses.isEmpty {
                Text("No responses yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(popularResponses.prefix(5), id: \.id) { response in
                    PromptResponseCard(
                        response: response,
                        coordinator: coordinator,
                        showUserInfo: true,
                        onTap: nil
                    )
                }
            }
        }
    }
    
    // MARK: - Friend Responses Section
    
    private var friendResponsesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friends' Responses")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if friendResponses.count > 5 {
                    Button("See All") {
                        showAllFriends = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
            
            if isLoadingFriends {
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
                ForEach(friendResponses.prefix(5), id: \.id) { response in
                    PromptResponseCard(
                        response: response,
                        coordinator: coordinator,
                        showUserInfo: true,
                        onTap: nil
                    )
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadAllData() {
        Task {
            await loadTopSongs()
            await loadPopularResponses()
            await loadFriendResponses()
            await loadUserResponse()
        }
    }
    
    private func loadTopSongs() async {
        isLoadingSongs = true
        defer { isLoadingSongs = false }
        
        // Load leaderboard data for this prompt
        if let leaderboard = await coordinator.promptService.fetchLeaderboard(for: prompt.id) {
            await MainActor.run {
                topSongs = leaderboard.songRankings.sorted { $0.voteCount > $1.voteCount }
            }
        }
    }
    
    private func loadPopularResponses() async {
        isLoadingPopular = true
        defer { isLoadingPopular = false }
        
        // Load responses sorted by like count
        let responses = await coordinator.promptService.fetchResponsesForPrompt(prompt.id, limit: 50)
        let sortedByLikes = responses.sorted { $0.likeCount > $1.likeCount }
        
        await MainActor.run {
            popularResponses = sortedByLikes
        }
    }
    
    private func loadFriendResponses() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        
        // Load responses from friends only
        let allResponses = await coordinator.promptService.fetchResponsesForPrompt(prompt.id, limit: 100)
        
        // Filter to only include friends (this would need friend list implementation)
        // For now, we'll show all responses as placeholder
        let friendsOnly = allResponses // TODO: Filter by actual friends
        
        await MainActor.run {
            friendResponses = friendsOnly
        }
    }
    
    private func loadUserResponse() async {
        isLoadingUser = true
        defer { isLoadingUser = false }
        
        // Check if current user responded to this prompt
        let currentUserId = coordinator.promptService.currentUserId
        if !currentUserId.isEmpty {
            let allResponses = await coordinator.promptService.fetchResponsesForPrompt(prompt.id, limit: 100)
            let userResp = allResponses.first { $0.userId == currentUserId }
            
            await MainActor.run {
                userResponse = userResp
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// MARK: - Supporting Components

struct SongRankingRow: View {
    let ranking: SongRanking
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank number
            Text("\(rank)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.purple)
                .frame(width: 30)
            
            // Album artwork
            AsyncImage(url: URL(string: ranking.artworkUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
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
            
            // Vote count and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ranking.voteCount)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("\(String(format: "%.1f", ranking.percentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

struct SongRankingSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 30, height: 30)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: 120)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 12)
                    .frame(maxWidth: 80)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}


// MARK: - See All Views

struct AllSongsView: View {
    let prompt: DailyPrompt
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var allSongs: [SongRanking] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ForEach(0..<10, id: \.self) { _ in
                            SongRankingSkeleton()
                        }
                    } else {
                        ForEach(Array(allSongs.enumerated()), id: \.offset) { index, song in
                            SongRankingRow(ranking: song, rank: index + 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("All Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            loadAllSongs()
        }
    }
    
    private func loadAllSongs() {
        isLoading = true
        Task {
            if let leaderboard = await coordinator.promptService.fetchLeaderboard(for: prompt.id) {
                await MainActor.run {
                    allSongs = leaderboard.songRankings.sorted { $0.voteCount > $1.voteCount }
                    isLoading = false
                }
            }
        }
    }
}

struct AllPopularResponsesView: View {
    let prompt: DailyPrompt
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var allResponses: [PromptResponse] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ForEach(0..<10, id: \.self) { _ in
                            ResponseCardSkeleton()
                        }
                    } else {
                        ForEach(allResponses, id: \.id) { response in
                            PromptResponseCard(
                                response: response,
                                coordinator: coordinator,
                                showUserInfo: true,
                                onTap: nil
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Popular Responses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            loadAllResponses()
        }
    }
    
    private func loadAllResponses() {
        isLoading = true
        Task {
            let responses = await coordinator.promptService.fetchResponsesForPrompt(prompt.id, limit: 100)
            let sortedByLikes = responses.sorted { $0.likeCount > $1.likeCount }
            
            await MainActor.run {
                allResponses = sortedByLikes
                isLoading = false
            }
        }
    }
}

struct AllFriendResponsesView: View {
    let prompt: DailyPrompt
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var allFriendResponses: [PromptResponse] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ForEach(0..<10, id: \.self) { _ in
                            ResponseCardSkeleton()
                        }
                    } else {
                        ForEach(allFriendResponses, id: \.id) { response in
                            PromptResponseCard(
                                response: response,
                                coordinator: coordinator,
                                showUserInfo: true,
                                onTap: nil
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Friends' Responses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            loadAllFriendResponses()
        }
    }
    
    private func loadAllFriendResponses() {
        isLoading = true
        Task {
            let allResponses = await coordinator.promptService.fetchResponsesForPrompt(prompt.id, limit: 100)
            
            // Filter to only include friends (placeholder implementation)
            let friendsOnly = allResponses // TODO: Filter by actual friends
            
            await MainActor.run {
                allFriendResponses = friendsOnly
                isLoading = false
            }
        }
    }
}

#Preview {
    PromptHistoryView(coordinator: DailyPromptCoordinator())
}
