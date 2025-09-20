import SwiftUI

// IdentifiableString is defined in ComprehensiveSearchView.swift

struct DiscussionView: View {
    enum Tab {
        case topics
        case randomChat
        case games
    }
    
    @State private var selectedTab: Tab = .topics
    @EnvironmentObject var discussionManager: DiscussionManager
    @StateObject private var discussionPreferences = DiscussionPreferencesService.shared
    @StateObject private var topicSystemManager = TopicSystemManager.shared
    @StateObject private var gameService = GameService.shared
    
    // Topics expansion states
    @State private var expandedTrendingTopics = false
    @State private var expandedMovieTopics = false
    @State private var expandedSportsTopics = false
    @State private var expandedPoliticsTopics = false
    @State private var expandedGamingTopics = false
    @State private var expandedMusicTopics = false
    @State private var expandedEntertainmentTopics = false
    @State private var expandedBusinessTopics = false
    @State private var expandedArtsCultureTopics = false
    @State private var expandedFoodDiningTopics = false
    @State private var expandedLifestyleTopics = false
    @State private var expandedEducationTopics = false
    @State private var expandedScienceTechTopics = false
    @State private var expandedWorldNewsTopics = false
    @State private var expandedHealthFitnessTopics = false
    @State private var expandedAutomotiveTopics = false
    
    // Topics "See All" sheet states
    @State private var showingTrendingTopicsAll = false
    @State private var showingMovieTopicsAll = false
    @State private var showingSportsTopicsAll = false
    @State private var showingPoliticsTopicsAll = false
    @State private var showingGamingTopicsAll = false
    @State private var showingMusicTopicsAll = false
    @State private var showingEntertainmentTopicsAll = false
    @State private var showingBusinessTopicsAll = false
    @State private var showingArtsCultureTopicsAll = false
    @State private var showingFoodDiningTopicsAll = false
    @State private var showingLifestyleTopicsAll = false
    @State private var showingEducationTopicsAll = false
    @State private var showingScienceTechTopicsAll = false
    @State private var showingWorldNewsTopicsAll = false
    @State private var showingHealthFitnessTopicsAll = false
    @State private var showingAutomotiveTopicsAll = false
    
    // Topics preview state
    @State private var selectedTopic: TopicChat? = nil
    
    // User profile navigation state
    @State private var selectedUserIdForProfile: String?
    
    // Topics state
    @State private var topicChats: [TopicChat] = []
    @State private var isLoadingTopics = false
    
    // Global search across all discussions
    @State private var globalSearchText: String = ""
    
    // Topic discussion creation state
    @State private var showingTopicDiscussionCreation = false
    @State private var selectedDiscussionTopic: DiscussionTopic?
    
    // Game-related state
    @State private var showingGameCreation = false
    @State private var selectedGameType: GameType = .imposter
    @State private var showingGameLobby = false
    @State private var selectedGameSession: GameSession?
    
    // Group-related state
    @State private var showingGroupCreation = false
    @State private var showingGroupInvites = false
    @State private var showingTrendingGames = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with picker and settings
            HStack {
                Picker("View", selection: $selectedTab) {
                    Text("Topics").tag(Tab.topics)
                    Text("Random Chat").tag(Tab.randomChat)
                    Text("Games").tag(Tab.games)
                }
                .pickerStyle(.segmented)
                
                // Settings button (only show on topics tab)
                if selectedTab == .topics {
                    Button(action: {
                        discussionPreferences.showDiscussionSettings = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                    .padding(.leading, 12)
                }
            }
            .padding()
            
            // Tab Content
            Group {
                if selectedTab == .topics {
                    topicsView
                } else if selectedTab == .randomChat {
                    RandomChatView()
                } else if selectedTab == .games {
                    gamesView
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Create Topic Discussion Button (only show on topics tab)
            if selectedTab == .topics {
                VStack(spacing: 12) {
                    // Lightweight mock preview button (for testing UI quickly)
                    Button {
                        presentMockDiscussion()
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.green)
                            .clipShape(Circle())
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button {
                        showingTopicDiscussionCreation = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.purple)
                            .clipShape(Circle())
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 100) // Above tab bar
            }
        }
        .sheet(isPresented: $showingTopicDiscussionCreation) {
            let defaultTopic = DiscussionTopic(
                name: "General Discussion",
                category: .trending,
                createdBy: "system"
            )
            TopicDiscussionCreationView(
                selectedTopic: selectedDiscussionTopic ?? defaultTopic,
                onDiscussionCreated: { topicChat in
                    showingTopicDiscussionCreation = false
                    // Handle the created discussion
                },
                onCancel: {
                    showingTopicDiscussionCreation = false
                }
            )
        }
        // Present the unified discussion view for topic chats
        .fullScreenCover(isPresented: $discussionManager.showDiscussionView) {
            if let chat = discussionManager.currentDiscussion,
               discussionManager.currentDiscussionType == .topicChat {
                UnifiedDiscussionView(
                    chat: chat,
                    discussionType: .topicChat,
                    onClose: {
                        discussionManager.leaveDiscussion()
                    }
                )
            }
        }
    }
    
    private var topicsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Global search bar
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search discussions...", text: $globalSearchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    if !globalSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search Results").font(.headline).padding(.horizontal)
                            LazyVStack(spacing: 12) {
                                ForEach(globalFilteredResults) { chat in
                                    TopicChatCard_Discussion(
                                        topic: chat, 
                                        onJoin: {},
                                        onOpenProfile: { userId in
                                            selectedUserIdForProfile = userId
                                        }
                                    )
                                        .onTapGesture { selectedTopic = chat }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
                
                // Sections below search (filtered by preferences)
                VStack(spacing: 32) {
                    if discussionPreferences.isSectionEnabled(.trending) {
                        topicsSection(
                            title: "Trending Topics",
                            icon: "flame.fill",
                            iconColor: .orange,
                            topics: trendingTopicsForCategory,
                            isExpanded: expandedTrendingTopics,
                            onToggleExpanded: { expandedTrendingTopics.toggle() },
                            onSeeAll: { showingTrendingTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.sports) {
                        topicsSection(
                            title: "Sports",
                            icon: "sportscourt.fill",
                            iconColor: .green,
                            topics: sportsTopics + convertTrendingTopicsToChats(category: .sports),
                            isExpanded: expandedSportsTopics,
                            onToggleExpanded: { expandedSportsTopics.toggle() },
                            onSeeAll: { showingSportsTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.politics) {
                        topicsSection(
                            title: "Politics",
                            icon: "building.columns.fill",
                            iconColor: .red,
                            topics: politicsTopics + convertTrendingTopicsToChats(category: .politics),
                            isExpanded: expandedPoliticsTopics,
                            onToggleExpanded: { expandedPoliticsTopics.toggle() },
                            onSeeAll: { showingPoliticsTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.movies) {
                        topicsSection(
                            title: "Movies & TV",
                            icon: "tv.fill",
                            iconColor: .purple,
                            topics: movieTopics + convertTrendingTopicsToChats(category: .movies),
                            isExpanded: expandedMovieTopics,
                            onToggleExpanded: { expandedMovieTopics.toggle() },
                            onSeeAll: { showingMovieTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.gaming) {
                        topicsSection(
                            title: "Gaming",
                            icon: "gamecontroller.fill",
                            iconColor: .pink,
                            topics: gamingTopicsForCategory,
                            isExpanded: expandedGamingTopics,
                            onToggleExpanded: { expandedGamingTopics.toggle() },
                            onSeeAll: { showingGamingTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.music) {
                        topicsSection(
                            title: "Music",
                            icon: "music.note",
                            iconColor: .blue,
                            topics: musicTopicsForCategory,
                            isExpanded: expandedMusicTopics,
                            onToggleExpanded: { expandedMusicTopics.toggle() },
                            onSeeAll: { showingMusicTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.entertainment) {
                        topicsSection(
                            title: "Entertainment",
                            icon: "star.fill",
                            iconColor: .yellow,
                            topics: entertainmentTopicsForCategory,
                            isExpanded: expandedEntertainmentTopics,
                            onToggleExpanded: { expandedEntertainmentTopics.toggle() },
                            onSeeAll: { showingEntertainmentTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.business) {
                        topicsSection(
                            title: "Business",
                            icon: "briefcase.fill",
                            iconColor: .gray,
                            topics: businessTopicsForCategory,
                            isExpanded: expandedBusinessTopics,
                            onToggleExpanded: { expandedBusinessTopics.toggle() },
                            onSeeAll: { showingBusinessTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.arts) {
                        topicsSection(
                            title: "Arts & Culture",
                            icon: "paintbrush.fill",
                            iconColor: .indigo,
                            topics: artsCultureTopicsForCategory,
                            isExpanded: expandedArtsCultureTopics,
                            onToggleExpanded: { expandedArtsCultureTopics.toggle() },
                            onSeeAll: { showingArtsCultureTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.food) {
                        topicsSection(
                            title: "Food & Dining",
                            icon: "fork.knife",
                            iconColor: .brown,
                            topics: foodDiningTopicsForCategory,
                            isExpanded: expandedFoodDiningTopics,
                            onToggleExpanded: { expandedFoodDiningTopics.toggle() },
                            onSeeAll: { showingFoodDiningTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.lifestyle) {
                        topicsSection(
                            title: "Lifestyle",
                            icon: "heart.fill",
                            iconColor: .cyan,
                            topics: lifestyleTopicsForCategory,
                            isExpanded: expandedLifestyleTopics,
                            onToggleExpanded: { expandedLifestyleTopics.toggle() },
                            onSeeAll: { showingLifestyleTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.education) {
                        topicsSection(
                            title: "Education",
                            icon: "graduationcap.fill",
                            iconColor: .teal,
                            topics: educationTopicsForCategory,
                            isExpanded: expandedEducationTopics,
                            onToggleExpanded: { expandedEducationTopics.toggle() },
                            onSeeAll: { showingEducationTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.science) {
                        topicsSection(
                            title: "Science & Tech",
                            icon: "atom",
                            iconColor: .mint,
                            topics: scienceTechTopicsForCategory,
                            isExpanded: expandedScienceTechTopics,
                            onToggleExpanded: { expandedScienceTechTopics.toggle() },
                            onSeeAll: { showingScienceTechTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.worldNews) {
                        topicsSection(
                            title: "World News",
                            icon: "globe",
                            iconColor: .blue,
                            topics: worldNewsTopicsForCategory,
                            isExpanded: expandedWorldNewsTopics,
                            onToggleExpanded: { expandedWorldNewsTopics.toggle() },
                            onSeeAll: { showingWorldNewsTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.health) {
                        topicsSection(
                            title: "Health & Fitness",
                            icon: "cross.fill",
                            iconColor: .green,
                            topics: healthFitnessTopicsForCategory,
                            isExpanded: expandedHealthFitnessTopics,
                            onToggleExpanded: { expandedHealthFitnessTopics.toggle() },
                            onSeeAll: { showingHealthFitnessTopicsAll = true }
                        )
                    }
                    
                    if discussionPreferences.isSectionEnabled(.automotive) {
                        topicsSection(
                            title: "Automotive",
                            icon: "car.fill",
                            iconColor: .orange,
                            topics: automotiveTopicsForCategory,
                            isExpanded: expandedAutomotiveTopics,
                            onToggleExpanded: { expandedAutomotiveTopics.toggle() },
                            onSeeAll: { showingAutomotiveTopicsAll = true }
                        )
                    }
                    
                    // Show message if no sections are enabled
                    if discussionPreferences.enabledSections.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No Discussion Sections Enabled")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Enable discussion sections in settings to see topics")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Open Settings") {
                                discussionPreferences.showDiscussionSettings = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                        }
                        .padding(.vertical, 40)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .fullScreenCover(item: $selectedTopic) { topic in
            TopicPreviewView_Discussion(topic: topic) {
                selectedTopic = nil
            }
        }
        .sheet(isPresented: $showingTrendingTopicsAll) {
            CategoryExplorerView(category: .trending, allChats: topicChats.filter { $0.category == .trending })
        }
        .sheet(isPresented: $showingSportsTopicsAll) {
            CategoryExplorerView(category: .sports, allChats: topicChats.filter { $0.category == .sports })
        }
        .sheet(isPresented: $showingPoliticsTopicsAll) {
            CategoryExplorerView(category: .politics, allChats: topicChats.filter { $0.category == .politics })
        }
        .sheet(isPresented: $showingMovieTopicsAll) {
            CategoryExplorerView(category: .movies, allChats: topicChats.filter { $0.category == .movies })
        }
        .sheet(isPresented: $showingGamingTopicsAll) {
            CategoryExplorerView(category: .gaming, allChats: topicChats.filter { $0.category == .gaming })
        }
        .sheet(isPresented: $showingMusicTopicsAll) {
            CategoryExplorerView(category: .music, allChats: topicChats.filter { $0.category == .music })
        }
        .sheet(isPresented: $showingEntertainmentTopicsAll) {
            CategoryExplorerView(category: .entertainment, allChats: topicChats.filter { $0.category == .entertainment })
        }
        .sheet(isPresented: $showingBusinessTopicsAll) {
            CategoryExplorerView(category: .business, allChats: topicChats.filter { $0.category == .business })
        }
        .sheet(isPresented: $showingArtsCultureTopicsAll) {
            CategoryExplorerView(category: .arts, allChats: topicChats.filter { $0.category == .arts })
        }
        .sheet(isPresented: $showingFoodDiningTopicsAll) {
            CategoryExplorerView(category: .food, allChats: topicChats.filter { $0.category == .food })
        }
        .sheet(isPresented: $showingLifestyleTopicsAll) {
            CategoryExplorerView(category: .lifestyle, allChats: topicChats.filter { $0.category == .lifestyle })
        }
        .sheet(isPresented: $showingEducationTopicsAll) {
            CategoryExplorerView(category: .education, allChats: topicChats.filter { $0.category == .education })
        }
        .sheet(isPresented: $showingScienceTechTopicsAll) {
            CategoryExplorerView(category: .science, allChats: topicChats.filter { $0.category == .science })
        }
        .sheet(isPresented: $showingWorldNewsTopicsAll) {
            CategoryExplorerView(category: .worldNews, allChats: topicChats.filter { $0.category == .worldNews })
        }
        .sheet(isPresented: $showingHealthFitnessTopicsAll) {
            CategoryExplorerView(category: .health, allChats: topicChats.filter { $0.category == .health })
        }
        .sheet(isPresented: $showingAutomotiveTopicsAll) {
            CategoryExplorerView(category: .automotive, allChats: topicChats.filter { $0.category == .automotive })
        }
        .sheet(isPresented: $discussionPreferences.showDiscussionSettings) {
            DiscussionSettingsView()
        }
        .fullScreenCover(item: Binding<IdentifiableString?>(
            get: { selectedUserIdForProfile.map(IdentifiableString.init) },
            set: { selectedUserIdForProfile = $0?.value }
        )) { userIdWrapper in
            NavigationView {
                UserProfileView(userId: userIdWrapper.value)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                selectedUserIdForProfile = nil
                            }
                            .foregroundColor(.purple)
                        }
                    }
            }
        }
        .onAppear {
            loadEnabledCategories()
            Task { 
                await loadTopicChats()
                await topicSystemManager.initialize()
                
                // Initialize topic system for all categories
                // The TopicSystemManager handles real-time updates internally
            }
            
            // Listen for user profile navigation from nested views
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenUserProfile"),
                object: nil,
                queue: .main
            ) { notification in
                if let userId = notification.object as? String {
                    selectedUserIdForProfile = userId
                }
            }
        }
        .onDisappear {
            // TopicSystemManager handles cleanup internally
            // Remove notification observer
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("OpenUserProfile"), object: nil)
        }
    }
    
    private var globalFilteredResults: [TopicChat] {
        let q = globalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return topicChats.filter { discussionMatches($0, query: q) }
            .sorted { ($0.trendingScore ?? Double($0.participants.count)) > ($1.trendingScore ?? Double($1.participants.count)) }
    }
    
    // MARK: - Trending Topics Computed Properties
    
    private var trendingTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .trending)
    }
    
    private var gamingTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .gaming)
    }
    
    private var musicTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .music)
    }
    
    private var entertainmentTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .entertainment)
    }
    
    private var businessTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .business)
    }
    
    private var artsCultureTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .arts)
    }
    
    private var foodDiningTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .food)
    }
    
    private var lifestyleTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .lifestyle)
    }
    
    private var educationTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .education)
    }
    
    private var scienceTechTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .science)
    }
    
    private var worldNewsTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .worldNews)
    }
    
    private var healthFitnessTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .health)
    }
    
    private var automotiveTopicsForCategory: [TopicChat] {
        return convertTrendingTopicsToChats(category: .automotive)
    }
    
    // MARK: - Games Helper Methods
    
    private func gameStatTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func gamesSection(title: String, icon: String, games: [GameSession], showAll: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if showAll && games.count > 3 {
                    Button("See All") {
                        // TODO: Show all games
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
            }
            .padding(.horizontal)
            
            if games.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No games available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(games.prefix(showAll ? games.count : 3)), id: \.id) { game in
                        gameSessionRow(game)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func gameSessionRow(_ session: GameSession) -> some View {
        Button(action: {
            if session.canAcceptSpectators {
                Task {
                    try await gameService.spectateGameSession(session)
                }
            } else if !session.isFull {
                Task {
                    try await gameService.joinGameSession(session)
                }
            }
        }) {
            HStack(spacing: 12) {
                // Game type icon
                Image(systemName: session.gameType.iconName)
                    .font(.title2)
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.topicChat.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Game status badge
                        gameStatusBadge(session.gameStatus)
                    }
                    
                    HStack {
                        Text(session.gameType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(session.activePlayerCount)/\(session.gameConfig.maxPlayers) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if session.spectatorCount > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(session.spectatorCount) watching")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                // Action indicator
                Image(systemName: session.isFull ? "eye.fill" : "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(session.isFull ? .orange : .green)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func gameStatusBadge(_ status: GameStatus) -> some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.2))
            .foregroundColor(statusColor(status))
            .cornerRadius(4)
    }
    
    private func statusColor(_ status: GameStatus) -> Color {
        switch status {
        case .waiting:
            return .blue
        case .starting:
            return .orange
        case .inProgress:
            return .green
        case .paused:
            return .yellow
        case .finished:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    private func loadGamesData() async {
        await gameService.fetchAvailableGames()
        await gameService.fetchFriendsGames()
        await gameService.fetchTrendingGames()
    }
    
    // MARK: - Games View
    
    private var gamesView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Header section with game stats
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Social Games")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Play interactive games with friends and others")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Game stats row
                    HStack(spacing: 20) {
                        gameStatTile(title: "Active Games", value: "\(gameService.availableGames.count)")
                        gameStatTile(title: "In Queue", value: gameService.currentQueue != nil ? "\(gameService.queuePosition)" : "0")
                        gameStatTile(title: "Trending", value: "\(gameService.trendingGames.count)")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Quick Actions")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        // Create Game Button
                        Button(action: {
                            showingGameCreation = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.purple)
                                
                                Text("Create Game")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Join Queue Button
                        Button(action: {
                            Task {
                                try await gameService.joinQueue(gameType: selectedGameType, group: gameService.currentPlayerGroup)
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: gameService.currentQueue != nil ? "clock.fill" : "person.2.fill")
                                    .font(.title)
                                    .foregroundColor(gameService.currentQueue != nil ? .orange : .blue)
                                
                                Text(gameService.currentQueue != nil ? "In Queue" : "Join Queue")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .disabled(gameService.currentQueue != nil)
                        
                        // Create Group Button
                        Button(action: {
                            showingGroupCreation = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: gameService.currentPlayerGroup != nil ? "person.2.circle.fill" : "person.2.circle")
                                    .font(.title)
                                    .foregroundColor(gameService.currentPlayerGroup != nil ? .green : .blue)
                                
                                Text(gameService.currentPlayerGroup != nil ? "In Group (\(gameService.currentPlayerGroup!.memberCount))" : "Create Group")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Group Invites Button
                        Button(action: {
                            showingGroupInvites = true
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Image(systemName: "envelope.fill")
                                        .font(.title)
                                        .foregroundColor(.orange)
                                    
                                    if !gameService.groupInvites.isEmpty {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Text("\(gameService.groupInvites.count)")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            )
                                            .offset(x: 12, y: -12)
                                    }
                                }
                                
                                Text("Invites")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Friends' Games Section
                if !gameService.friendsGames.isEmpty {
                    gamesSection(
                        title: "Friends Playing",
                        icon: "person.2.fill",
                        games: gameService.friendsGames,
                        showAll: false
                    )
                }
                
                // Trending Games Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            
                            Text("Trending Games")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Button("View All") {
                            showingTrendingGames = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    if gameService.trendingGames.isEmpty {
                        EmptyGamesSectionView(
                            icon: "flame.fill",
                            title: "No Trending Games",
                            message: "No games are currently trending. Start a game to get the party started!"
                        )
                        .padding(.horizontal)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(gameService.trendingGames.prefix(5)), id: \.id) { gameSession in
                                    TrendingGamePreviewCard(gameSession: gameSession) {
                                        showingTrendingGames = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Available Games Section
                gamesSection(
                    title: "Available Games",
                    icon: "gamecontroller",
                    games: gameService.availableGames,
                    showAll: true
                )
                
                Spacer(minLength: 100) // Space for floating button
            }
        }
        .refreshable {
            await loadGamesData()
        }
        .onAppear {
            Task {
                await loadGamesData()
                await gameService.fetchGroupInvites()
            }
        }
        .sheet(isPresented: $showingGameCreation) {
            GameCreationView(
                selectedGameType: $selectedGameType,
                onGameCreated: { gameSession in
                    selectedGameSession = gameSession
                    showingGameLobby = true
                }
            )
        }
        .sheet(isPresented: $showingGameLobby) {
            if let gameSession = selectedGameSession {
                GameLobbyView(gameSession: gameSession)
            }
        }
        .sheet(isPresented: $showingGroupCreation) {
            GroupCreationView(
                gameType: selectedGameType,
                onGroupCreated: { group in
                    showingGroupCreation = false
                    // Optionally show a success message or navigate to queue
                },
                onCancel: {
                    showingGroupCreation = false
                }
            )
        }
        .sheet(isPresented: $showingGroupInvites) {
            GroupInvitesView()
        }
        .sheet(isPresented: $showingTrendingGames) {
            TrendingGamesView()
        }
    }
    
    private func discussionMatches(_ c: TopicChat, query: String) -> Bool {
        let q = query.lowercased()
        if c.title.lowercased().contains(q) { return true }
        if c.hostName.lowercased().contains(q) { return true }
        if c.primaryTopic?.lowercased().contains(q) == true { return true }
        if c.currentDiscussion?.lowercased().contains(q) == true { return true }
        if c.topicKeywords.contains(q) { return true }
        return false
    }
    
    private func presentTopicResults(category: TopicCategory, topic: String) {
        // deprecated by CategoryExplorerView; kept no-op for safety
    }
    
    // MARK: - Trending Topics Helper
    
    private func convertTrendingTopicsToChats(category: TopicCategory) -> [TopicChat] {
        // Use the new user-statistics-based system
        let discussionTopics = topicSystemManager.categoryTopics[category] ?? []
        
        // Sort by trending score (user activity)
        let sortedTopics = discussionTopics.sorted { topic1, topic2 in
            // First sort by trending score
            if topic1.trendingScore != topic2.trendingScore {
                return topic1.trendingScore > topic2.trendingScore
            }
            // Then by total discussions
            if topic1.totalDiscussions != topic2.totalDiscussions {
                return topic1.totalDiscussions > topic2.totalDiscussions
            }
            // Finally by last activity
            return topic1.lastActivity > topic2.lastActivity
        }
        
        return sortedTopics.map { discussionTopic in
            var chat = TopicChat(
                title: discussionTopic.name,
                description: discussionTopic.description ?? "Join the discussion about \(discussionTopic.name)",
                category: category,
                hostId: "trending_system",
                hostName: "Trending"
            )
            
            // Set trending-specific properties from user statistics
            chat.primaryTopic = discussionTopic.name
            chat.topicKeywords = discussionTopic.tags
            chat.trendingScore = discussionTopic.trendingScore
            chat.isVerified = false // DiscussionTopic doesn't have isVerified field
            
            return chat
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapDiscussionSectionToTopicCategory(_ section: DiscussionSection) -> TopicCategory? {
        switch section {
        case .trending: return .trending
        case .movies: return .movies
        case .sports: return .sports
        case .gaming: return .gaming
        case .music: return .music
        case .entertainment: return .entertainment
        case .politics: return .politics
        case .business: return .business
        case .arts: return .arts
        case .food: return .food
        case .lifestyle: return .lifestyle
        case .education: return .education
        case .science: return .science
        case .worldNews: return .worldNews
        case .health: return .health
        case .automotive: return .automotive
        }
    }
    
    // MARK: - Mock Presenter
    private func presentMockDiscussion() {
        var mock = TopicChat(
            title: "Mock Discussion",
            description: "This is a mock topic discussion for preview",
            category: .trending,
            hostId: "mock_host",
            hostName: "Host"
        )
        mock.currentDiscussion = "What should we talk about first?"
        mock.voiceChatEnabled = true
        mock.voiceChatActive = true
        mock.participants = [
            TopicParticipant(id: "mock_host", name: "Host", isHost: true),
            TopicParticipant(id: "u1", name: "Taylor", isHost: false),
            TopicParticipant(id: "u2", name: "Chris", isHost: false),
            TopicParticipant(id: "u3", name: "Sam", isHost: false),
            TopicParticipant(id: "u4", name: "Lee", isHost: false)
        ]
        mock.speakers = ["mock_host", "u1"]
        mock.listeners = ["u2", "u3", "u4"]
        discussionManager.joinDiscussion(mock, type: .topicChat)
    }
    
    // MARK: - Topics Computed Properties
    private var trendingTopics: [TopicChat] {
        topicChats.filter { $0.category == .trending }
    }
    private var movieTopics: [TopicChat] {
        topicChats.filter { $0.category == .movies }
    }
    private var sportsTopics: [TopicChat] {
        topicChats.filter { $0.category == .sports }
    }
    private var politicsTopics: [TopicChat] {
        topicChats.filter { $0.category == .politics }
    }
    
    // MARK: - Topics Section Helper
    private func topicsSection(
        title: String,
        icon: String,
        iconColor: Color,
        topics: [TopicChat],
        isExpanded: Bool,
        onToggleExpanded: @escaping () -> Void,
        onSeeAll: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if topics.count > 3 {
                    Button("See All") { onSeeAll() }
                        .font(.subheadline)
                        .foregroundColor(iconColor)
                }
            }
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                let displayTopics = isExpanded ? topics : Array(topics.prefix(4))
                ForEach(displayTopics) { topic in
                    TopicChatCard_Discussion(
                        topic: topic,
                        onJoin: {
                            AnalyticsService.shared.logDiscoveryQuickJoin(tab: "topics", partyId: topic.id)
                        },
                        onOpenProfile: { userId in
                            selectedUserIdForProfile = userId
                        }
                    )
                    .onTapGesture { selectedTopic = topic }
                    .onAppear { AnalyticsService.shared.logDiscoveryPartyImpression(tab: "topics", partyId: topic.id) }
                }
            }
            .padding(.horizontal, 16)
            
            if topics.count > 4 {
                Button(action: onToggleExpanded) {
                    HStack {
                        Text(isExpanded ? "See Less" : "See More")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(iconColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Topics Section Detail View
    private struct TopicsSectionDetailView_Discussion: View {
        let title: String
        let topics: [TopicChat]
        let onSelect: (TopicChat) -> Void
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(topics) { t in
                            TopicChatCard_Discussion(
                                topic: t, 
                                onJoin: {},
                                onOpenProfile: { userId in
                                    // Note: This is in a nested view, so we'll use NotificationCenter here
                                    NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: userId)
                                }
                            )
                                .onTapGesture { onSelect(t) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
    
    // MARK: - Loaders
    private func loadEnabledCategories() {
        if let savedCategories = UserDefaults.standard.array(forKey: "enabledTopicCategories") as? [String] {
            _ = savedCategories.compactMap { TopicCategory(rawValue: $0) }
        }
    }
    
    private func loadTopicChats() async {
        isLoadingTopics = true
        await MainActor.run {
            self.topicChats = createMockTopicChats()
            self.isLoadingTopics = false
        }
    }
    
    private func createMockTopicChats() -> [TopicChat] {
        var mock: [TopicChat] = []
        
        // Trending (5+)
        for i in 0..<6 {
            var t = TopicChat(
                title: i == 0 ? "Latest Tech News Discussion" : "Trending Topic #\(i)",
                description: i == 0 ? "Discussing the newest developments in AI and technology" : "Hot topic number #\(i) everyone is discussing",
                category: .trending,
                hostId: "trend_host_\(i)",
                hostName: i == 0 ? "Alex" : "TrendHost\(i)"
            )
            t.participants = Array(0..<(6 + i)).map { j in TopicParticipant(id: "t_\(i)_u\(j)", name: "User\(j)", isHost: false) }
            t.participants.insert(TopicParticipant(id: "trend_host_\(i)", name: t.hostName, isHost: true), at: 0)
            t.currentDiscussion = i == 0 ? "What do you think about the latest AI developments?" : "Let's talk about #\(i)"
            t.primaryTopic = i == 0 ? "AI Developments" : "Trending #\(i)"
            t.topicKeywords = [t.primaryTopic?.lowercased() ?? "", "ai", "news"].filter { !$0.isEmpty }
            t.voiceChatEnabled = true
            t.voiceChatActive = i % 2 == 0
            t.speakers = [t.hostId]
            t.listeners = t.participants.dropFirst().map { $0.id }
            mock.append(t)
        }
        
        // Movies (5+)
        for i in 0..<5 {
            var m = TopicChat(
                title: i == 0 ? "Marvel Phase 5 Discussion" : "Movie Night #\(i)",
                description: i == 0 ? "Discussing the latest Marvel movies and shows" : "Chat about movies #\(i)",
                category: .movies,
                hostId: "movie_host_\(i)",
                hostName: i == 0 ? "Mike" : "MovieHost\(i)"
            )
            m.participants = Array(0..<(8 + i)).map { j in TopicParticipant(id: "m_\(i)_u\(j)", name: "Fan\(j)", isHost: false) }
            m.participants.insert(TopicParticipant(id: m.hostId, name: m.hostName, isHost: true), at: 0)
            m.currentDiscussion = i == 0 ? "What did you think of the latest Marvel release?" : "Which film should we watch next?"
            m.primaryTopic = i == 0 ? "Marvel Phase 5" : "Movies #\(i)"
            m.topicKeywords = [m.primaryTopic!.lowercased(), "marvel", "phase", "movie"].filter { !$0.isEmpty }
            m.voiceChatEnabled = true
            m.voiceChatActive = true
            m.speakers = [m.hostId]
            m.listeners = m.participants.dropFirst().map { $0.id }
            mock.append(m)
        }
        
        // Sports (5+)
        for i in 0..<5 {
            var s = TopicChat(
                title: i == 0 ? "NBA Playoffs Discussion" : "Sports Talk #\(i)",
                description: i == 0 ? "Discussing the current NBA playoff race" : "Sports roundup #\(i)",
                category: .sports,
                hostId: "sports_host_\(i)",
                hostName: i == 0 ? "Chris" : "Sporty\(i)"
            )
            s.participants = Array(0..<(10 + i)).map { j in TopicParticipant(id: "s_\(i)_u\(j)", name: "Athlete\(j)", isHost: false) }
            s.participants.insert(TopicParticipant(id: s.hostId, name: s.hostName, isHost: true), at: 0)
            s.currentDiscussion = i == 0 ? "Who will win the championship?" : "Biggest upset this week?"
            s.primaryTopic = i == 0 ? "NBA Playoffs" : "Sports #\(i)"
            s.topicKeywords = [s.primaryTopic!.lowercased(), "nba", "playoffs", "basketball"].filter { !$0.isEmpty }
            s.voiceChatEnabled = true
            s.voiceChatActive = i % 2 == 1
            s.speakers = [s.hostId]
            s.listeners = s.participants.dropFirst().map { $0.id }
            mock.append(s)
        }
        
        // Politics (5+)
        for i in 0..<5 {
            var p = TopicChat(
                title: i == 0 ? "Current Events Discussion" : "Policy Chat #\(i)",
                description: i == 0 ? "Civil discussion about political developments" : "Discuss policy topic #\(i)",
                category: .politics,
                hostId: "politics_host_\(i)",
                hostName: i == 0 ? "Policy" : "Analyst\(i)"
            )
            p.participants = Array(0..<(7 + i)).map { j in TopicParticipant(id: "p_\(i)_u\(j)", name: "Citizen\(j)", isHost: false) }
            p.participants.insert(TopicParticipant(id: p.hostId, name: p.hostName, isHost: true), at: 0)
            p.currentDiscussion = i == 0 ? "What policy changes would you like to see?" : "Debate #\(i)"
            p.primaryTopic = i == 0 ? "Current Events" : "Policy #\(i)"
            p.topicKeywords = [p.primaryTopic!.lowercased(), "policy", "politics"].filter { !$0.isEmpty }
            mock.append(p)
        }
        
        return mock
    }
}

// MARK: - Category Explorer (See All screen)
struct CategoryExplorerView: View {
    let category: TopicCategory
    let allChats: [TopicChat]
    
    @Environment(\.dismiss) private var dismiss
    @State private var visibleAllCount: Int = 6
    @State private var extraChats: [TopicChat] = []
    @State private var previewTopic: TopicChat? = nil
    @State private var searchText: String = ""
    
    private let pageSize = 6
    
    private var sortedAll: [TopicChat] {
        allChats.sorted {
            let l = $0.trendingScore ?? Double($0.participants.count)
            let r = $1.trendingScore ?? Double($1.participants.count)
            return l > r
        }
    }
    
    private var combinedAll: [TopicChat] { sortedAll + extraChats }
    private var filteredAll: [TopicChat] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return combinedAll }
        return combinedAll.filter { discussionMatches($0, query: q) }
    }
    
    private var topTopics: [String] {
        switch category {
        case .movies: return ["Marvel Phase 5", "Dune Part Two", "Batman vs Superman", "Top Gun Maverick", "Avatar Way of Water", "Black Panther Legacy", "Spider-Man Multiverse", "The Batman Sequel", "Wonder Woman 3", "Fast X Racing"]
        case .sports: return ["NBA Playoffs", "Super Bowl", "World Cup", "March Madness", "Champions League", "UFC", "Formula 1", "Tennis Grand Slam", "College Football", "Trade Deadline"]
        case .politics: return ["Current Events", "Elections", "Policy Debates", "International Relations", "Local Government", "Tax Reform", "Infrastructure", "Voting Rights", "Foreign Policy", "Education Policy"]
        case .trending: return ["AI Developments", "Streaming Wars", "Social Media Trends", "Celebrity News", "Internet Memes", "Breaking News", "Fashion Trends", "Viral TikTok", "Tech IPOs", "Crypto"]
        default: return ["General"]
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search bar for category explorer
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Search in \(category.displayName)", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(12)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // ALL section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("All")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredAll.prefix(visibleAllCount))) { chat in
                                TopicChatCard_Discussion(
                                    topic: chat, 
                                    onJoin: {},
                                    onOpenProfile: { userId in
                                        // Note: This is in a nested view, so we'll use NotificationCenter here
                                        NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: userId)
                                    }
                                )
                                    .onTapGesture { previewTopic = chat }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                loadMoreAll()
                            } label: { HStack { Image(systemName: "chevron.down"); Text("See More") } }
                            .buttonStyle(.bordered)
                            .tint(category.color)
                            
                            if visibleAllCount > 6 {
                                Button {
                                    visibleAllCount = 6
                                } label: { HStack { Image(systemName: "chevron.up"); Text("See Less") } }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Trending Topics list (buttons only)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Trending Topics")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(Array(topTopics.enumerated()), id: \.offset) { idx, topic in
                                NavigationLink {
                                    TopicTopicResultsView(category: category, topic: topic, allChats: allChats)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("#\(idx + 1)")
                                            .font(.headline)
                                            .foregroundColor(category.color)
                                        Text(topic)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("\(category.displayName) · See All")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() } } }
        }
        .fullScreenCover(item: $previewTopic) { t in
            TopicPreviewView_Discussion(topic: t) { previewTopic = nil }
        }
    }
    
    private func navigateToTopicAll(_ topic: String) {
        let view = TopicTopicResultsView(category: category, topic: topic, allChats: allChats)
        let host = UIHostingController(rootView: view)
        UIApplication.shared.windows.first?.rootViewController?.present(host, animated: true)
    }
    
    private func loadMoreAll() {
        // If we already have more loaded than visible, just reveal additional
        if visibleAllCount < filteredAll.count {
            visibleAllCount = min(visibleAllCount + pageSize, filteredAll.count)
            return
        }
        // Otherwise synthesize more mock rows (dev UX) – replace with Firestore in prod
        var newItems: [TopicChat] = []
        let start = extraChats.count
        for i in 0..<pageSize {
            let idx = start + i + 1
            var chat = TopicChat(
                title: generatedTitle(index: idx),
                description: generatedDescription(index: idx),
                category: category,
                hostId: "extra_host_\(idx)",
                hostName: "ExtraHost\(idx)"
            )
            chat.primaryTopic = generatedPrimaryTopic()
            chat.topicKeywords = [chat.primaryTopic?.lowercased() ?? ""]
            chat.trendingScore = Double(50 - idx)
            chat.participants = Array(0..<(6 + (idx % 5))).map { j in TopicParticipant(id: "extra_\(idx)_u\(j)", name: "User\(j)") }
            chat.participants.insert(TopicParticipant(id: chat.hostId, name: chat.hostName, isHost: true), at: 0)
            newItems.append(chat)
        }
        extraChats.append(contentsOf: newItems)
        visibleAllCount = min(visibleAllCount + pageSize, combinedAll.count)
    }
    
    private func generatedTitle(index: Int) -> String {
        switch category {
        case .politics: return "Policy Chat #\(index)"
        case .sports: return "Sports Talk Extra #\(index)"
        case .movies: return "Movie Night Extra #\(index)"
        case .trending: return "Trending Extra #\(index)"
        default: return "Discussion Extra #\(index)"
        }
    }
    
    private func generatedDescription(index: Int) -> String {
        switch category {
        case .politics: return "Discuss policy topic #\(index)"
        case .sports: return "Sports roundup #\(index)"
        case .movies: return "Film discussion #\(index)"
        case .trending: return "Hot topic #\(index) everyone is discussing"
        default: return "General discussion #\(index)"
        }
    }
    
    private func generatedPrimaryTopic() -> String {
        switch category {
        case .politics: return "Current Events"
        case .sports: return "NBA Playoffs"
        case .movies: return "Marvel Phase 5"
        case .trending: return "AI Developments"
        default: return "General"
        }
    }
    
    private func discussionMatches(_ c: TopicChat, query: String) -> Bool {
        let q = query.lowercased()
        if c.title.lowercased().contains(q) { return true }
        if c.hostName.lowercased().contains(q) { return true }
        if c.primaryTopic?.lowercased().contains(q) == true { return true }
        if c.currentDiscussion?.lowercased().contains(q) == true { return true }
        if c.topicKeywords.contains(q) { return true }
        return false
    }
}

// MARK: - Topic-specific full results
struct TopicTopicResultsView: View {
    let category: TopicCategory
    let topic: String
    let allChats: [TopicChat]
    
    @Environment(\.dismiss) private var dismiss
    @State private var visibleCount: Int = 12
    @State private var previewTopic: TopicChat? = nil
    @State private var searchText: String = ""
    private let pageSize = 12
    
    private var matches: [TopicChat] {
        allChats.filter { c in
            c.category == category && (
                (c.primaryTopic?.localizedCaseInsensitiveContains(topic) ?? false) ||
                (c.currentDiscussion?.localizedCaseInsensitiveContains(topic) ?? false) ||
                c.topicKeywords.contains(topic.lowercased())
            )
        }
        .sorted { ( $0.trendingScore ?? Double($0.participants.count) ) > ( $1.trendingScore ?? Double($1.participants.count) ) }
    }
    
    private var filteredMatches: [TopicChat] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return matches }
        return matches.filter { discussionMatches($0, query: q) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search in \(topic)", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredMatches.prefix(visibleCount))) { chat in
                            TopicChatCard_Discussion(
                                topic: chat, 
                                onJoin: {},
                                onOpenProfile: { userId in
                                    // Note: This is in a nested view, so we'll use NotificationCenter here
                                    NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: userId)
                                }
                            )
                                .onTapGesture { previewTopic = chat }
                        }
                        if visibleCount < filteredMatches.count {
                            Button {
                                visibleCount = min(visibleCount + pageSize, filteredMatches.count)
                            } label: {
                                HStack { Image(systemName: "arrow.down.circle"); Text("Load More") }
                                    .foregroundColor(category.color)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(category.color.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("\(topic)")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() } } }
        }
        .fullScreenCover(item: $previewTopic) { t in
            TopicPreviewView_Discussion(topic: t) { previewTopic = nil }
        }
    }
    
    private func discussionMatches(_ c: TopicChat, query: String) -> Bool {
        let q = query.lowercased()
        if c.title.lowercased().contains(q) { return true }
        if c.hostName.lowercased().contains(q) { return true }
        if c.primaryTopic?.lowercased().contains(q) == true { return true }
        if c.currentDiscussion?.lowercased().contains(q) == true { return true }
        if c.topicKeywords.contains(q) { return true }
        return false
    }
}

// MARK: - Category Topics Browser & Results
struct CategoryTopicsBrowserView: View {
    let category: TopicCategory
    let onTopicSelected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var page = 1
    private let pageSize = 10
    
    private var allTopics: [String] {
        // Reuse TopicSelectionView’s mock topics mapping (inline here to avoid import)
        switch category {
        case .movies: return ["Marvel Phase 5", "Dune Part Two", "Batman vs Superman", "Top Gun Maverick", "Avatar Way of Water", "Black Panther Legacy", "Spider-Man Multiverse", "The Batman Sequel", "Wonder Woman 3", "Fast X Racing", "John Wick 4"]
        case .sports: return ["NBA Playoffs", "Super Bowl", "World Cup", "March Madness", "Champions League", "UFC", "Formula 1", "Tennis Grand Slam"]
        case .politics: return ["Current Events", "Elections", "Policy Debates", "International Relations", "Local Government", "Tax Reform"]
        case .trending: return ["AI Developments", "Social Media Trends", "Streaming Wars", "Celebrity News", "Internet Memes", "Breaking News"]
        default: return ["General"]
        }
    }
    
    private var filtered: [String] {
        let base = searchText.isEmpty ? allTopics : allTopics.filter { $0.localizedCaseInsensitiveContains(searchText) }
        let end = min(page * pageSize, base.count)
        return Array(base.prefix(end))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search topics...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(12)
                .background(Color(.systemGray5))
                .cornerRadius(10)
                .padding()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { idx, t in
                            Button {
                                onTopicSelected(t)
                                dismiss()
                            } label: {
                                HStack {
                                    Text("#\(idx + 1)").foregroundColor(category.color).fontWeight(.bold)
                                    Text(t).fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if filtered.count < (searchText.isEmpty ? allTopics.count : filtered.count) {
                            Button {
                                page += 1
                            } label: {
                                HStack { Image(systemName: "arrow.down.circle"); Text("Load More") }
                                    .foregroundColor(category.color)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(category.color.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .navigationTitle("\(category.displayName) Topics")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() } } }
            }
        }
    }
}

// MARK: - Topic Chat Card
fileprivate struct TopicChatCard_Discussion: View {
    let topic: TopicChat
    let onJoin: () -> Void
    let onOpenProfile: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(topic.category.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: topic.category.icon).foregroundColor(topic.category.color).font(.system(size: 14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title).font(.headline).fontWeight(.semibold).lineLimit(1)
                    Button(action: { onOpenProfile(topic.hostId) }) {
                        HStack(spacing: 4) {
                            Text("by").foregroundColor(.secondary)
                            Text(topic.hostName)
                                .foregroundColor(.purple)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
                Button("Join", action: onJoin)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(topic.category.color))
            }
            Text(topic.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
            HStack {
                Image(systemName: "person.2.fill").font(.caption).foregroundColor(.secondary)
                Text(String(topic.participants.count)).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(topic.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(topic.category.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(topic.category.color.opacity(0.1)))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Topic Preview View
private struct TopicPreviewView_Discussion: View {
    let topic: TopicChat
    let onClose: () -> Void
    @State private var visibleParticipantCount: Int = 10
    
    private func openProfile(_ userId: String) {
        NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: userId)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(topic.category.color.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: topic.category.icon).foregroundColor(topic.category.color))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(2)
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill").foregroundColor(.purple)
                                Button(action: { openProfile(topic.hostId) }) {
                                    HStack(spacing: 4) {
                                        Text("Hosted by").foregroundColor(.purple)
                                        Text(topic.hostName).foregroundColor(.purple).fontWeight(.semibold)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                        Spacer()
                        Text(topic.category.displayName)
                            .font(.caption)
                            .foregroundColor(topic.category.color)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(topic.category.color.opacity(0.1)))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Now Discussing").font(.headline)
                        if let current = topic.currentDiscussion, !current.isEmpty {
                            Text(current).foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "text.bubble").foregroundColor(.secondary)
                                VStack(alignment: .leading) {
                                    Text("No active thread")
                                    Text("Topics will appear here").font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Participants").font(.headline)
                            Spacer()
                            Text("\(topic.participants.count) members").foregroundColor(.secondary).font(.subheadline)
                        }
                        ForEach(Array(topic.participants.prefix(visibleParticipantCount))) { p in
                            Button(action: { openProfile(p.id) }) {
                                HStack(spacing: 12) {
                                    Circle().fill(Color.purple.opacity(0.2)).frame(width: 36, height: 36)
                                        .overlay(Image(systemName: "person.fill").foregroundColor(.purple))
                                    VStack(alignment: .leading) {
                                        HStack(spacing: 8) {
                                            Text(p.name).foregroundColor(.primary).fontWeight(.medium)
                                            if p.isHost {
                                                Text("Host").font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.3)))
                                            }
                                        }
                                        Text("Joined just now").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if topic.participants.count > visibleParticipantCount {
                            Button(action: { visibleParticipantCount = min(visibleParticipantCount + 10, topic.participants.count) }) {
                                HStack { Text("See More"); Image(systemName: "chevron.down") }.frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Topic Stats").font(.headline)
                        HStack {
                            statTile(title: "Members", value: String(topic.participants.count))
                            statTile(title: "Speakers", value: String(topic.speakers.count))
                            statTile(title: "Voice Chat", value: topic.voiceChatActive ? "On" : "Off")
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { /* hook up when implementing joining */ }) {
                            HStack { Image(systemName: "person.2.fill"); Text("Join Discussion").fontWeight(.semibold) }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Text("You'll be able to chat with others and request to speak").font(.footnote).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
            }
            .navigationTitle("Discussion Preview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { onClose() }
                }
            }
        }
    }
    
    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }
}

// MARK: - Trending Game Preview Card

struct TrendingGamePreviewCard: View {
    let gameSession: GameSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: gameSession.gameType.iconName)
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gameSession.topicChat.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        Text("by \(gameSession.topicChat.hostName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("\(gameSession.activePlayerCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("\(gameSession.spectatorCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if gameSession.trendingScore > 10 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            
                            Text("Hot")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Text("Tap to watch")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(12)
            .frame(width: 160)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty Games Section View

struct EmptyGamesSectionView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}