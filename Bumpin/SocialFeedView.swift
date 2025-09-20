import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SocialFeedView: View {
    @StateObject private var viewModel = SocialFeedViewModel()
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    @State private var unreadCount: Int = 0
    @State private var selectedFilter: SocialFilter = .all
    @State private var showingExploreSheet: ExploreSheet?
    @State private var exploreScrollAnchorId: String? = UserDefaults.standard.string(forKey: "exploreScrollAnchorId")
    @State private var selectedExploreSection: ExploreSheet = {
        let savedValue = UserDefaults.standard.string(forKey: "exploreSelectedSection") ?? "songs"
        return ExploreSheet(rawValue: savedValue) ?? .songs
    }()
    
    // DEMO: Daily Prompts feature demo
    @State private var showDailyPromptsDemo = false
    
    private var weeklyPopularSectionHeader: some View {
        HStack {
            Text("Popular this week").font(.headline).fontWeight(.bold)
            Spacer()
            Button(action: { viewModel.showAllWeeklyPopular = true }) {
                HStack(spacing: 4) { Text("See All"); Image(systemName: "chevron.right") }
            }
            .font(.subheadline)
            .foregroundColor(.purple)
        }
    }
    
    
    @ViewBuilder
    private var newPostsBanner: some View {
        if viewModel.hasNewPosts {
            Button(action: {
                AnalyticsService.shared.logTap(category: "new_posts_banner", id: "refresh")
                Task { await viewModel.refreshAllData() }
                viewModel.acknowledgeNewPosts()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("New posts available – tap to refresh")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            .onAppear { AnalyticsService.shared.logImpression(category: "new_posts_banner", id: "visible") }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 24) {
            switch selectedFilter {
            case .genres:
                genresContent
            case .all:
                allTabContent
            case .explore:
                exploreContent
            case .followers:
                FollowersTabView()
            case .dailyPrompt:
                DailyPromptTabView()
                    .environmentObject(navigationCoordinator)
            }
        }
    }
    
    @ViewBuilder
    private var genresContent: some View {
        FavoriteGenresView()
    }
    
    @ViewBuilder
    private var genreWeeklyPopularSection: some View {
        if !viewModel.genreWeeklyPopularLogs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Popular this week").font(.headline).fontWeight(.bold)
                    Spacer()
                    Button(action: { viewModel.showAllGenreWeeklyPopular = true }) {
                        HStack(spacing: 4) { Text("See All"); Image(systemName: "chevron.right") }
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
                VStack(spacing: 10) {
                    ForEach(viewModel.genreWeeklyPopularLogs.prefix(viewModel.genreWeeklyVisibleCount)) { log in
                        PopularLogRow(log: log)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    HStack(spacing: 12) {
                        if viewModel.genreWeeklyPopularLogs.count > viewModel.genreWeeklyVisibleCount {
                            Button("See more") { viewModel.increaseGenreWeeklyVisible() }
                        }
                        if viewModel.genreWeeklyVisibleCount > 10 {
                            Button("See less") { viewModel.resetGenreWeeklyVisible() }
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
        }
    }
    
    @ViewBuilder
    private var allTabContent: some View {
        friendsNowPlayingSection
        
        EnhancedTrendingSectionView(
            title: "Trending Songs",
            items: Array(viewModel.trendingSongs.prefix(viewModel.trendingDisplayCountSongs)),
            itemType: .song,
            isLoading: viewModel.isLoadingTrendingSongs,
            showFriendPictures: true,
            friendsData: viewModel.friendsData,
            onSeeAll: { viewModel.showAllTrendingSongs = true },
            onNearEnd: { viewModel.increaseTrendingVisible(type: .song) }
        )
        
        EnhancedTrendingSectionView(
            title: "Trending Artists",
            items: Array(viewModel.trendingArtists.prefix(viewModel.trendingDisplayCountArtists)),
            itemType: .artist,
            isLoading: viewModel.isLoadingTrendingArtists,
            showFriendPictures: true,
            friendsData: viewModel.friendsData,
            onSeeAll: { viewModel.showAllTrendingArtists = true },
            onNearEnd: { viewModel.increaseTrendingVisible(type: .artist) }
        )
        
        EnhancedTrendingSectionView(
            title: "Trending Albums",
            items: Array(viewModel.trendingAlbums.prefix(viewModel.trendingDisplayCountAlbums)),
            itemType: .album,
            isLoading: viewModel.isLoadingTrendingAlbums,
            showFriendPictures: true,
            friendsData: viewModel.friendsData,
            onSeeAll: { viewModel.showAllTrendingAlbums = true },
            onNearEnd: { viewModel.increaseTrendingVisible(type: .album) }
        )

        EnhancedTrendingSectionView(
            title: "Popular with Friends",
            items: Array(viewModel.friendsPopularCombined.prefix(10)),
            itemType: .song,
            isLoading: false,
            showFriendPictures: true,
            friendsData: viewModel.friendsData,
            onSeeAll: { viewModel.showAllFriendsPopular = true }
        )

        weeklyPopularSection
    }
    
    @ViewBuilder
    private var friendsNowPlayingSection: some View {
        if !viewModel.nowPlayingFriends.isEmpty {
            HStack {
                Text("Friends listening now").font(.headline).fontWeight(.semibold)
                Spacer()
                Button("See All") { viewModel.showAllFriendsNowPlaying = true }
                    .font(.subheadline).foregroundColor(.purple)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.nowPlayingFriends, id: \.uid) { user in
                        NowPlayingFriendCard(user: user)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    @ViewBuilder
    private var weeklyPopularSection: some View {
        if !viewModel.weeklyPopularLogs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                weeklyPopularSectionHeader
                VStack(spacing: 10) {
                    ForEach(viewModel.weeklyPopularLogs.prefix(viewModel.weeklyVisibleCount)) { log in
                        PopularLogRow(log: log)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    HStack(spacing: 12) {
                        if viewModel.weeklyPopularLogs.count > viewModel.weeklyVisibleCount {
                            Button("See more") { viewModel.increaseWeeklyVisible() }
                        }
                        if viewModel.weeklyVisibleCount > 10 {
                            Button("See less") { viewModel.resetWeeklyVisible() }
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
        }
    }
    
    @ViewBuilder
    private var exploreContent: some View {
        creatorsNowPlayingSection
        
        ExploreCreatorLogsSection(
            title: "Creators' Songs",
            logs: viewModel.creatorSongLogs,
            isLoading: viewModel.isLoadingCreatorSongs,
            onLoadMore: { Task { await viewModel.loadCreatorLogs(type: "song", append: true) } },
            onSeeAll: { showingExploreSheet = .songs },
            visibleCount: viewModel.creatorSongsVisible,
            onSeeMore: {
                viewModel.increaseCreatorVisible(type: "song")
                if viewModel.creatorSongLogs.count < viewModel.creatorSongsVisible {
                    Task { await viewModel.loadCreatorLogs(type: "song", append: true) }
                }
            },
            onSeeLess: { viewModel.resetCreatorVisible(type: "song") },
            onVisible: { id in
                selectedExploreSection = .songs
                exploreScrollAnchorId = id
                UserDefaults.standard.set(id, forKey: "exploreScrollAnchorId")
                UserDefaults.standard.set(selectedExploreSection.rawValue, forKey: "exploreSelectedSection")
            }
        )
        .onAppear { Task { await viewModel.loadCreatorLogs(type: "song", append: false) } }

        ExploreCreatorLogsSection(
            title: "Creators' Artists",
            logs: viewModel.creatorArtistLogs,
            isLoading: viewModel.isLoadingCreatorArtists,
            onLoadMore: { Task { await viewModel.loadCreatorLogs(type: "artist", append: true) } },
            onSeeAll: { showingExploreSheet = .artists },
            visibleCount: viewModel.creatorArtistsVisible,
            onSeeMore: {
                viewModel.increaseCreatorVisible(type: "artist")
                if viewModel.creatorArtistLogs.count < viewModel.creatorArtistsVisible {
                    Task { await viewModel.loadCreatorLogs(type: "artist", append: true) }
                }
            },
            onSeeLess: { viewModel.resetCreatorVisible(type: "artist") },
            onVisible: { id in
                selectedExploreSection = .artists
                exploreScrollAnchorId = id
                UserDefaults.standard.set(id, forKey: "exploreScrollAnchorId")
                UserDefaults.standard.set(selectedExploreSection.rawValue, forKey: "exploreSelectedSection")
            }
        )
        .onAppear { Task { await viewModel.loadCreatorLogs(type: "artist", append: false) } }

        ExploreCreatorLogsSection(
            title: "Creators' Albums",
            logs: viewModel.creatorAlbumLogs,
            isLoading: viewModel.isLoadingCreatorAlbums,
            onLoadMore: { Task { await viewModel.loadCreatorLogs(type: "album", append: true) } },
            onSeeAll: { showingExploreSheet = .albums },
            visibleCount: viewModel.creatorAlbumsVisible,
            onSeeMore: {
                viewModel.increaseCreatorVisible(type: "album")
                if viewModel.creatorAlbumLogs.count < viewModel.creatorAlbumsVisible {
                    Task { await viewModel.loadCreatorLogs(type: "album", append: true) }
                }
            },
            onSeeLess: { viewModel.resetCreatorVisible(type: "album") },
            onVisible: { id in
                selectedExploreSection = .albums
                exploreScrollAnchorId = id
                UserDefaults.standard.set(id, forKey: "exploreScrollAnchorId")
                UserDefaults.standard.set(selectedExploreSection.rawValue, forKey: "exploreSelectedSection")
            }
        )
        .onAppear { Task { await viewModel.loadCreatorLogs(type: "album", append: false) } }
    }
    
    @ViewBuilder
    private var creatorsNowPlayingSection: some View {
        if !viewModel.nowPlayingCreators.isEmpty {
            HStack {
                Text("Creators listening now").font(.headline).fontWeight(.semibold)
                Spacer()
                Button("See All") { viewModel.showAllCreatorsNowPlaying = true }
                    .font(.subheadline).foregroundColor(.purple)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.nowPlayingCreators, id: \.uid) { user in
                        NowPlayingCreatorCard(user: user)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            EmptyView()
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Top filter chips (home style)
                        FilterChips(selected: $selectedFilter)
                            .padding(.bottom, 8)
                        
                        // Content area
                        VStack(spacing: 20) {
                            newPostsBanner
                            
                            mainContent
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
                .onDisappear { viewModel.stopLiveListeners() }
                .lifecyclePrefetch(with: viewModel)
                .navigationTitle("")
                .toolbar { 
                    navigationToolbar
                }
                .navigationBarTitleDisplayMode(.inline)
                .refreshable { await viewModel.refreshAllData() }
            }
        }
        .environmentObject(navigationCoordinator)
        .fullScreenCover(isPresented: $navigationCoordinator.showingMusicProfile) {
            if let musicItem = navigationCoordinator.selectedMusicItem {
                MusicProfileView(musicItem: musicItem, pinnedLog: nil)
            }
        }
        .fullScreenCover(isPresented: $navigationCoordinator.showingArtistProfile) {
            if let artistName = navigationCoordinator.selectedArtist {
                ArtistProfileView(artistName: artistName)
                    .environmentObject(navigationCoordinator)
            }
        }
        .onAppear {
            viewModel.loadAllData()
            viewModel.startNewPostsListener()
            if let saved = UserDefaults.standard.string(forKey: "exploreSelectedSection"), let kind = ExploreSheet(rawValue: saved) {
                selectedExploreSection = kind
            }
        }
        .fullScreenCover(isPresented: $viewModel.showAllFriendsNowPlaying) {
            FriendsNowPlayingListView(users: viewModel.nowPlayingFriends)
        }
        .fullScreenCover(isPresented: $showDailyPromptsDemo) {
            DailyPromptDemoView()
        }
        .fullScreenCover(isPresented: $viewModel.showAllCreatorsNowPlaying) {
            FriendsNowPlayingListView(users: viewModel.nowPlayingCreators)
        }
        .fullScreenCover(isPresented: $viewModel.showAllTrendingSongs) {
            TrendingDetailView(items: viewModel.allTrendingSongs, title: "Trending Songs", itemType: .song)
        }
        .fullScreenCover(isPresented: $viewModel.showAllTrendingArtists) {
            TrendingDetailView(items: viewModel.allTrendingArtists, title: "Trending Artists", itemType: .artist)
        }
        .fullScreenCover(isPresented: $viewModel.showAllTrendingAlbums) {
            TrendingDetailView(items: viewModel.allTrendingAlbums, title: "Trending Albums", itemType: .album)
        }
        .fullScreenCover(isPresented: $viewModel.showAllFriendsPopular) {
            CombinedTrendingDetailView(items: viewModel.allFriendsPopularCombined.isEmpty ? viewModel.friendsPopularCombined : viewModel.allFriendsPopularCombined, title: "Popular with Friends")
        }
        .fullScreenCover(isPresented: $viewModel.showAllWeeklyPopular) {
            WeeklyPopularListView(initialLogs: viewModel.weeklyPopularLogs)
        }
        .fullScreenCover(isPresented: $viewModel.showAllFriendsActivity) {
            FriendsPopularDetailView(initialItems: viewModel.allFriendsPopularSongs.isEmpty ? viewModel.friendsPopularSongs : viewModel.allFriendsPopularSongs)
        }
        .fullScreenCover(isPresented: $viewModel.showAllGenre) {
            GenreLogsListView(genre: viewModel.selectedGenre)
        }
        .fullScreenCover(isPresented: $viewModel.showAllGenreFriendsPopular) {
            FriendsPopularDetailView(initialItems: viewModel.allGenreFriendsPopularSongs.isEmpty ? viewModel.genreFriendsPopularSongs : viewModel.allGenreFriendsPopularSongs)
        }
        .fullScreenCover(isPresented: $viewModel.showAllGenreFriendsPopularCombined) {
            CombinedTrendingDetailView(items: viewModel.allGenreFriendsPopularCombined.isEmpty ? viewModel.genreFriendsPopularCombined : viewModel.allGenreFriendsPopularCombined, title: "Popular with Friends in \(viewModel.selectedGenre.capitalized)")
        }
        .fullScreenCover(isPresented: $viewModel.showAllGenreArtists) {
            TrendingDetailView(items: viewModel.allGenreTrendingArtists, title: "Trending Artists in \(viewModel.selectedGenre.capitalized)", itemType: .artist)
        }
        .fullScreenCover(isPresented: $viewModel.showAllGenreAlbums) {
            TrendingDetailView(items: viewModel.allGenreTrendingAlbums, title: "Trending Albums in \(viewModel.selectedGenre.capitalized)", itemType: .album)
        }
        .fullScreenCover(isPresented: $viewModel.showAllGenreWeeklyPopular) {
            WeeklyPopularListView(initialLogs: viewModel.genreWeeklyPopularLogs)
        }
        .fullScreenCover(isPresented: $viewModel.showAllCreators) {
            CreatorsListView(items: viewModel.allCreatorsSpotlight, loadMore: {
                Task { await viewModel.loadMoreCreatorsPage() }
            })
        }
        .fullScreenCover(item: $showingExploreSheet) { kind in
            switch kind {
            case .songs:
                ExploreCreatorLogsListView(title: "Creators' Songs", logs: viewModel.creatorSongLogs) {
                    Task { await viewModel.loadCreatorLogs(type: "song", append: true) }
                }
            case .artists:
                ExploreCreatorLogsListView(title: "Creators' Artists", logs: viewModel.creatorArtistLogs) {
                    Task { await viewModel.loadCreatorLogs(type: "artist", append: true) }
                }
            case .albums:
                ExploreCreatorLogsListView(title: "Creators' Albums", logs: viewModel.creatorAlbumLogs) {
                    Task { await viewModel.loadCreatorLogs(type: "album", append: true) }
                }
            }
        }
    }
    
    // MARK: - Cross-Platform Testing
    private func testCrossPlatformSystem() async {
        print("🧪 === CROSS-PLATFORM SYSTEM TEST ===")
        await TrackMatchingService.shared.testSickoModeMatching()
        await SpotifyService.shared.demonstrateSpotifySearch()
        await UniversalMusicProfileService.shared.demonstrateSickoModeUnification()
        print("✅ Cross-platform test completed!")
    }
}

// MARK: - Social Filter Enum
enum SocialFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case followers = "Feed"
    case dailyPrompt = "Prompt"
    case explore = "Explore"
    case genres = "Genres"
    
    var id: String { rawValue }
}

// MARK: - Explore Sheet Enum
enum ExploreSheet: String, CaseIterable, Identifiable {
    case songs = "songs"
    case artists = "artists"
    case albums = "albums"
    
    var id: String { rawValue }
}

// MARK: - Filter Chips View (Home Style)
struct FilterChips: View {
    @Binding var selected: SocialFilter
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(SocialFilter.allCases) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = filter
                    }
                }) {
                    Text(filter.rawValue)
                        .font(.caption)
                        .fontWeight(selected == filter ? .semibold : .regular)
                        .foregroundColor(selected == filter ? .purple : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Professional Genre Selector
struct GenreSelector: View {
    let genres: [String]
    @Binding var selectedGenre: String
    let onGenreSelected: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Genre picker with horizontal scroll for many options
            if genres.count <= 4 {
                // Use segmented control for 4 or fewer genres
                Picker("Genre", selection: $selectedGenre) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre.capitalized).tag(genre)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 4)
                .onChange(of: selectedGenre) { _, newGenre in
                    onGenreSelected(newGenre)
                }
            } else {
                // Use horizontal scroll for many genres
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genres, id: \.self) { genre in
                            GenreChipButton(
                                title: genre.capitalized,
                                isSelected: selectedGenre == genre
                            ) {
                                selectedGenre = genre
                                onGenreSelected(genre)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Genre Chip Button
struct GenreChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.purple : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Favorite Genres View with Scrollable Tabs
struct FavoriteGenresView: View {
    @StateObject private var genrePreferences = GenrePreferencesService.shared
    @StateObject private var viewModel = SocialFeedViewModel()
    @State private var selectedGenre: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with settings button
            HStack {
                Text("Your Genres")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    genrePreferences.showGenreSettings = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Customize")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)
            
            // Scrollable favorite genres tabs
            if genrePreferences.favoriteGenres.isEmpty {
                emptyGenresState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genrePreferences.favoriteGenresArray, id: \.self) { genre in
                            GenreTabButton(
                                title: genre,
                                isSelected: selectedGenre == genre
                            ) {
                                selectedGenre = genre
                                loadGenreContent(genre)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onAppear {
                    if selectedGenre.isEmpty && !genrePreferences.favoriteGenres.isEmpty {
                        selectedGenre = genrePreferences.favoriteGenresArray.first ?? ""
                        loadGenreContent(selectedGenre)
                    }
                }
            }
            
            // Genre content
            if !selectedGenre.isEmpty {
                VStack(spacing: 24) {
                    // Friends Listening Now (genre-filtered)
                    genreFriendsNowPlayingSection
                    
                    EnhancedTrendingSectionView(
                        title: "Trending Songs",
                        items: viewModel.genreTrending,
                        itemType: .song,
                        isLoading: viewModel.isLoadingGenre,
                        showFriendPictures: true,
                        friendsData: viewModel.friendsData,
                        onSeeAll: { viewModel.showAllGenre = true }
                    )

                    EnhancedTrendingSectionView(
                        title: "Trending Artists",
                        items: viewModel.genreTrendingArtists,
                        itemType: .artist,
                        isLoading: viewModel.isLoadingGenreArtists,
                        showFriendPictures: true,
                        friendsData: viewModel.friendsData,
                        onSeeAll: { viewModel.showAllGenreArtists = true }
                    )

                    EnhancedTrendingSectionView(
                        title: "Trending Albums",
                        items: viewModel.genreTrendingAlbums,
                        itemType: .album,
                        isLoading: viewModel.isLoadingGenreAlbums,
                        showFriendPictures: true,
                        friendsData: viewModel.friendsData,
                        onSeeAll: { viewModel.showAllGenreAlbums = true }
                    )

                    EnhancedTrendingSectionView(
                        title: "Popular with Friends",
                        items: viewModel.genreFriendsPopularCombined.isEmpty ? viewModel.genreFriendsPopularSongs : viewModel.genreFriendsPopularCombined,
                        itemType: .song,
                        isLoading: false,
                        showFriendPictures: true,
                        friendsData: viewModel.friendsData,
                        onSeeAll: {
                            if viewModel.genreFriendsPopularCombined.isEmpty {
                                viewModel.showAllGenreFriendsPopular = true
                            } else {
                                viewModel.showAllGenreFriendsPopularCombined = true
                            }
                        }
                    )
                    
                    // Popular This Week (genre-filtered)
                    genreWeeklyPopularSection
                }
            }
        }
        .sheet(isPresented: $genrePreferences.showGenreSettings) {
            GenreSettingsView()
        }
    }
    
    @ViewBuilder
    private var emptyGenresState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No favorite genres selected")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Customize your genres to see trending music in your favorite styles")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Select Favorite Genres") {
                genrePreferences.showGenreSettings = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var genreFriendsNowPlayingSection: some View {
        // Filter friends now playing by genre
        let genreFilteredFriends = viewModel.nowPlayingFriends.compactMap { friend -> UserProfile? in
            guard let songTitle = friend.nowPlayingSong, 
                  let artistName = friend.nowPlayingArtist else { return nil }
            let songGenre = classifyGenre(title: songTitle, artist: artistName)
            print("🎵 Genre filter: \(songTitle) by \(artistName) classified as \(songGenre), selected: \(selectedGenre)")
            return songGenre == selectedGenre ? friend : nil
        }
        
        // Always show the section header, even if empty (matching "all" section behavior)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends listening now").font(.headline).fontWeight(.semibold)
                Spacer()
                Button("See All") { viewModel.showAllFriendsNowPlaying = true }
                    .font(.subheadline).foregroundColor(.purple)
            }
            
            if !genreFilteredFriends.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(genreFilteredFriends, id: \.uid) { user in
                            NowPlayingFriendCard(user: user)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                // Empty state matching the "all" section
                Text("No friends listening to \(selectedGenre) right now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
    }
    
    @ViewBuilder
    private var genreWeeklyPopularSection: some View {
        // Always show the section header, even if empty (matching "all" section behavior)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Popular this week").font(.headline).fontWeight(.bold)
                Spacer()
                Button(action: { viewModel.showAllGenreWeeklyPopular = true }) {
                    HStack(spacing: 4) { Text("See All"); Image(systemName: "chevron.right") }
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            if !viewModel.genreWeeklyPopularLogs.isEmpty {
                VStack(spacing: 10) {
                    ForEach(viewModel.genreWeeklyPopularLogs.prefix(viewModel.genreWeeklyVisibleCount)) { log in
                        PopularLogRow(log: log)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    HStack(spacing: 12) {
                        if viewModel.genreWeeklyPopularLogs.count > viewModel.genreWeeklyVisibleCount {
                            Button("See more") { viewModel.increaseGenreWeeklyVisible() }
                        }
                        if viewModel.genreWeeklyVisibleCount > 10 {
                            Button("See less") { viewModel.resetGenreWeeklyVisible() }
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            } else {
                // Empty state matching the "all" section
                Text("No popular \(selectedGenre) logs this week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            }
        }
    }
    
    // Genre classification function (matching GenreDetailView implementation)
    private func classifyGenre(title: String, artist: String) -> String {
        let artistLower = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let titleLower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedText = "\(titleLower) \(artistLower)"
        
        // Artist-based classification (matching GenreDetailView)
        let artistGenreMap: [String: String] = [
            // Hip-Hop Artists
            "drake": "Hip-Hop", "kendrick lamar": "Hip-Hop", "travis scott": "Hip-Hop", "kanye west": "Hip-Hop",
            "tyler the creator": "Hip-Hop", "asap rocky": "Hip-Hop", "j cole": "Hip-Hop", "future": "Hip-Hop",
            "lil baby": "Hip-Hop", "lil wayne": "Hip-Hop", "eminem": "Hip-Hop", "jay-z": "Hip-Hop",
            "nas": "Hip-Hop", "biggie": "Hip-Hop", "tupac": "Hip-Hop", "snoop dogg": "Hip-Hop",
            "dr dre": "Hip-Hop", "50 cent": "Hip-Hop", "nicki minaj": "Hip-Hop", "cardi b": "Hip-Hop",
            "megan thee stallion": "Hip-Hop", "doja cat": "Hip-Hop", "ice spice": "Hip-Hop", "lil uzi vert": "Hip-Hop",
            "playboi carti": "Hip-Hop", "21 savage": "Hip-Hop", "metro boomin": "Hip-Hop", "gunna": "Hip-Hop",
            "young thug": "Hip-Hop", "roddy ricch": "Hip-Hop", "dababy": "Hip-Hop", "polo g": "Hip-Hop",
            "lil durk": "Hip-Hop", "pop smoke": "Hip-Hop", "juice wrld": "Hip-Hop", "xxxtentacion": "Hip-Hop",
            
            // Pop Artists
            "ariana grande": "Pop", "billie eilish": "Pop", "dua lipa": "Pop",
            "olivia rodrigo": "Pop", "harry styles": "Pop", "ed sheeran": "Pop", "justin bieber": "Pop",
            "selena gomez": "Pop", "miley cyrus": "Pop", "katy perry": "Pop", "lady gaga": "Pop",
            "bruno mars": "Pop", "post malone": "Pop", "charlie puth": "Pop",
            "shawn mendes": "Pop", "camila cabello": "Pop", "halsey": "Pop", "lorde": "Pop",
            
            // R&B Artists
            "sza": "R&B", "frank ocean": "R&B", "the weeknd": "R&B", "bryson tiller": "R&B",
            "partynextdoor": "R&B", "6lack": "R&B", "daniel caesar": "R&B", "kali uchis": "R&B",
            "summer walker": "R&B", "jhene aiko": "R&B", "kehlani": "R&B", "h.e.r.": "R&B",
            
            // Electronic Artists
            "calvin harris": "Electronic", "david guetta": "Electronic", "skrillex": "Electronic", "deadmau5": "Electronic",
            "diplo": "Electronic", "major lazer": "Electronic", "flume": "Electronic", "odesza": "Electronic",
            
            // Rock Artists
            "imagine dragons": "Rock", "onerepublic": "Rock", "maroon 5": "Rock", "coldplay": "Rock",
            "linkin park": "Rock", "foo fighters": "Rock", "red hot chili peppers": "Rock", "green day": "Rock",
            
            // Indie Artists
            "arctic monkeys": "Indie", "tame impala": "Indie", "vampire weekend": "Indie", "the strokes": "Indie",
            "foster the people": "Indie", "cage the elephant": "Indie", "glass animals": "Indie", "alt-j": "Indie",
            
            // Country Artists
            "kacey musgraves": "Country", "chris stapleton": "Country", "keith urban": "Country",
            "carrie underwood": "Country", "blake shelton": "Country", "luke bryan": "Country", "florida georgia line": "Country",
            
            // K-Pop Artists
            "bts": "K-Pop", "blackpink": "K-Pop", "twice": "K-Pop", "stray kids": "K-Pop",
            "itzy": "K-Pop", "red velvet": "K-Pop", "aespa": "K-Pop", "ive": "K-Pop",
            
            // Latin Artists
            "bad bunny": "Latin", "j balvin": "Latin", "ozuna": "Latin", "maluma": "Latin",
            "karol g": "Latin", "daddy yankee": "Latin", "shakira": "Latin", "manu chao": "Latin"
        ]
        
        // Check artist mapping first
        if let genre = artistGenreMap[artistLower] {
            return genre
        }
        
        // Keyword-based classification as fallback
        if combinedText.contains("hip hop") || combinedText.contains("rap") || combinedText.contains("trap") {
            return "Hip-Hop"
        } else if combinedText.contains("pop") && !combinedText.contains("k-pop") {
            return "Pop"
        } else if combinedText.contains("r&b") || combinedText.contains("rnb") || combinedText.contains("soul") {
            return "R&B"
        } else if combinedText.contains("electronic") || combinedText.contains("edm") || combinedText.contains("house") || combinedText.contains("techno") {
            return "Electronic"
        } else if combinedText.contains("rock") || combinedText.contains("metal") {
            return "Rock"
        } else if combinedText.contains("indie") || combinedText.contains("alternative") {
            return "Indie"
        } else if combinedText.contains("country") {
            return "Country"
        } else if combinedText.contains("k-pop") || combinedText.contains("kpop") {
            return "K-Pop"
        } else if combinedText.contains("latin") || combinedText.contains("reggaeton") {
            return "Latin"
        } else if combinedText.contains("jazz") {
            return "Jazz"
        } else if combinedText.contains("classical") {
            return "Classical"
        } else {
            return "Other"
        }
    }
    
    private func loadGenreContent(_ genre: String) {
        Task {
            // Load friends now playing data (needed for genre filtering)
            await viewModel.loadNowPlayingFriendsAsync()
            
            // Load genre-specific data
            await viewModel.loadGenreTrendingAsync(for: genre)
            await viewModel.loadGenreTrendingArtistsAsync(for: genre)
            await viewModel.loadGenreTrendingAlbumsAsync(for: genre)
            await viewModel.loadGenrePopularFriendsAsync(for: genre)
            await viewModel.loadGenrePopularFriendsCombinedAsync(for: genre)
            await viewModel.loadGenreWeeklyPopularAsync(for: genre, reset: true)
        }
        UserDefaults.standard.set(genre, forKey: "selectedGenre")
    }
}

// MARK: - Genre Tab Button
struct GenreTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
                .frame(width: 85) // Fixed width for even sizing
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.purple : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Genre Settings View
struct GenreSettingsView: View {
    @StateObject private var genrePreferences = GenrePreferencesService.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)
                        
                        Text("Customize Your Genres")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Select your favorite music genres to see trending content that matches your taste")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // Selection suggestion
                    if let suggestion = genrePreferences.selectionSuggestion {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Quick actions
                    HStack(spacing: 12) {
                        Button("Select Defaults") {
                            genrePreferences.resetToDefaults()
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                        
                        Button("Select All") {
                            genrePreferences.selectAllGenres()
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                        
                        Button("Clear All") {
                            genrePreferences.clearAllGenres()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal, 20)
                    
                    // Genre grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(genrePreferences.allGenres, id: \.self) { genre in
                            GenreToggleCard(
                                genre: genre,
                                isSelected: genrePreferences.isFavorite(genre)
                            ) {
                                genrePreferences.toggleGenre(genre)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Genre Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Genre Toggle Card
struct GenreToggleCard: View {
    let genre: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .purple : .gray)
                    .font(.title2)
                
                Text(genre)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Navigation Coordinator for handling profile navigation
class NavigationCoordinator: ObservableObject {
    @Published var selectedMusicItem: MusicSearchResult?
    @Published var selectedArtist: String?
    @Published var showingMusicProfile = false
    @Published var showingArtistProfile = false
    
    func navigateToMusicProfile(_ item: TrendingItem) {
        // Convert TrendingItem to MusicSearchResult
        let musicItem = MusicSearchResult(
            id: item.itemId,
            title: item.title,
            artistName: item.subtitle ?? "",
            albumName: "",
            artworkURL: item.artworkUrl,
            itemType: item.itemType,
            popularity: item.logCount
        )
        selectedMusicItem = musicItem
        showingMusicProfile = true
    }
    
    func navigateToArtistProfile(_ artistName: String) {
        print("🎯 NavigationCoordinator: Navigating to artist profile for: \(artistName)")
        selectedArtist = artistName
        showingArtistProfile = true
    }
}

#Preview {
    SocialFeedView()
} 
