import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PromptHistoryView: View {
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
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
        .fullScreenCover(isPresented: $showPromptDetail) {
            if let prompt = selectedPrompt {
                PromptDetailView(prompt: prompt, coordinator: coordinator)
                    .environmentObject(navigationCoordinator)
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
                        
                        Text(timeAgo(prompt.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
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
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Data state
    @State private var topSongs: [SongRanking] = []
    @State private var popularResponses: [PromptResponse] = []
    @State private var friendResponses: [PromptResponse] = []
    @State private var userResponse: PromptResponse?
    @State private var selectedResponse: PromptResponse?
    
    // Loading states
    @State private var isLoadingSongs = false
    @State private var isLoadingPopular = false
    @State private var isLoadingFriends = false
    @State private var isLoadingUser = false
    
    // Pagination state
    @State private var topSongsVisibleCount = 3
    @State private var popularVisibleCount = 3
    @State private var friendVisibleCount = 3
    
    private let pageSize = 3
    
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
        .fullScreenCover(isPresented: $navigationCoordinator.showingMusicProfile) {
            if let item = navigationCoordinator.selectedMusicItem {
                MusicProfileView(musicItem: item, pinnedLog: nil)
                    .environmentObject(navigationCoordinator)
            }
        }
        .fullScreenCover(isPresented: $navigationCoordinator.showingArtistProfile) {
            if let name = navigationCoordinator.selectedArtist {
                ArtistProfileView(artistName: name)
                    .environmentObject(navigationCoordinator)
            }
        }
        .fullScreenCover(isPresented: $navigationCoordinator.showingUserProfile) {
            if let uid = navigationCoordinator.selectedUserId {
                UserProfileView(userId: uid, showDismissButton: true)
                    .environmentObject(navigationCoordinator)
            }
        }
        .onAppear {
            loadAllData()
        }
        .fullScreenCover(item: $selectedResponse) { response in
            PromptResponseDetailView(response: response, coordinator: coordinator)
                .environmentObject(navigationCoordinator)
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
                
                VStack(spacing: 4) {
                    Text(dateFormatter.string(from: prompt.date))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                Text("Prompt Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                onTap: {
                    selectedResponse = response
                }
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
                ForEach(Array(topSongs.prefix(topSongsVisibleCount).enumerated()), id: \.offset) { index, song in
                    Button(action: {
                        navigationCoordinator.navigateToMusicProfile(
                            TrendingItem(
                                title: song.songTitle,
                                subtitle: song.artistName,
                                artworkUrl: song.artworkUrl,
                                logCount: song.voteCount,
                                averageRating: nil,
                                itemType: "song",
                                itemId: song.id
                            )
                        )
                    }) {
                    SongRankingRow(ranking: song, rank: index + 1)
                }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if topSongs.count > pageSize {
                    Button(titleForPagination(current: topSongsVisibleCount, total: topSongs.count)) {
                        togglePagination(current: &topSongsVisibleCount, total: topSongs.count)
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.top, 8)
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
                ForEach(popularResponses.prefix(popularVisibleCount), id: \.id) { response in
                    PromptResponseCard(
                        response: response,
                        coordinator: coordinator,
                        showUserInfo: true,
                        onTap: {
                            selectedResponse = response
                        }
                    )
                }
                
                if popularResponses.count > pageSize {
                    Button(titleForPagination(current: popularVisibleCount, total: popularResponses.count)) {
                        togglePagination(current: &popularVisibleCount, total: popularResponses.count)
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Friend Responses Section
    
    private var friendResponsesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friend Responses")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
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
                ForEach(friendResponses.prefix(friendVisibleCount), id: \.id) { response in
                    PromptResponseCard(
                        response: response,
                        coordinator: coordinator,
                        showUserInfo: true,
                        onTap: {
                            selectedResponse = response
                        }
                    )
                }
                
                if friendResponses.count > pageSize {
                    Button(titleForPagination(current: friendVisibleCount, total: friendResponses.count)) {
                        togglePagination(current: &friendVisibleCount, total: friendResponses.count)
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.top, 8)
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
                topSongsVisibleCount = min(pageSize, topSongs.count)
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
            popularVisibleCount = min(pageSize, popularResponses.count)
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
            friendVisibleCount = min(pageSize, friendResponses.count)
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
    
    // MARK: - Pagination Helpers
    
    private func titleForPagination(current: Int, total: Int) -> String {
        if current >= total {
            return "See Less"
        }
        if current + pageSize >= total {
            return "See All"
        }
        return "Load More"
    }
    
    private func togglePagination(current: inout Int, total: Int) {
        if current >= total {
            current = min(pageSize, total)
        } else {
            current = min(current + pageSize, total)
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
            .navigationTitle("Friend Responses")
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
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("❌ No current user for friend responses")
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            do {
                // Fetch user's following list from Firestore
                let db = Firestore.firestore()
                let followingSnapshot = try await db.collection("users")
                    .document(currentUserId)
                    .collection("following")
                    .getDocuments()
                
                let followingUserIds = Set(followingSnapshot.documents.map { $0.documentID })
                
                print("📊 [FriendResponses] Found \(followingUserIds.count) following users")
                
                // Fetch all responses for this prompt
                let allResponses = await coordinator.promptService.fetchResponsesForPrompt(prompt.id, limit: 500)
                
                print("📊 [FriendResponses] Found \(allResponses.count) total responses")
                
                // Filter to only include responses from users we follow
                let friendResponses = allResponses.filter { response in
                    followingUserIds.contains(response.userId)
                }
                
                print("📊 [FriendResponses] Found \(friendResponses.count) friend responses")
                
                // Sort by engagement (likes + comments)
                let sortedResponses = friendResponses.sorted { response1, response2 in
                    let engagement1 = response1.likeCount + response1.commentCount
                    let engagement2 = response2.likeCount + response2.commentCount
                    
                    // If engagement is equal, sort by likes
                    if engagement1 == engagement2 {
                        return response1.likeCount > response2.likeCount
                    }
                    
                    return engagement1 > engagement2
                }
                
                await MainActor.run {
                    allFriendResponses = sortedResponses
                    isLoading = false
                }
                
            } catch {
                print("❌ [FriendResponses] Error loading: \(error)")
                await MainActor.run {
                    allFriendResponses = []
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    PromptHistoryView(coordinator: DailyPromptCoordinator())
        .environmentObject(NavigationCoordinator())
}
