import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

// MARK: - Data Models

struct TrendingItem: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String? // Artist name for songs/albums
    let artworkUrl: String?
    let logCount: Int // Number of logs in last 24 hours
    let averageRating: Double?
    let itemType: String // "song", "album", "artist"
    let itemId: String // Universal ID or identifier for grouping
    let appleMusicId: String? // Original Apple Music ID for fetching
    let totalRatings: Int?
    
    enum ItemType: String, CaseIterable {
        case song = "song"
        case album = "album"
        case artist = "artist"
    }
    
    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        artworkUrl: String? = nil,
        logCount: Int,
        averageRating: Double? = nil,
        itemType: String,
        itemId: String,
        appleMusicId: String? = nil,
        totalRatings: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.artworkUrl = artworkUrl
        self.logCount = logCount
        self.averageRating = averageRating
        self.itemType = itemType
        self.itemId = itemId
        self.appleMusicId = appleMusicId ?? itemId // Default to itemId if not provided
        self.totalRatings = totalRatings
    }
    
    func withAverageRating(_ rating: Double, totalRatings: Int) -> TrendingItem {
        let normalized = TrendingItem.normalizedAverage(from: rating)
        return TrendingItem(
            id: id,
            title: title,
            subtitle: subtitle,
            artworkUrl: artworkUrl,
            logCount: logCount,
            averageRating: normalized,
            itemType: itemType,
            itemId: itemId,
            appleMusicId: appleMusicId,
            totalRatings: totalRatings
        )
    }
}

extension TrendingItem {
    static func normalizedAverage(from rating: Double) -> Double {
        let clamped = max(0.0, min(5.0, rating))
        return (clamped * 10).rounded() / 10
    }
    
    static func normalizedAverage(optional rating: Double?) -> Double? {
        guard let rating else { return nil }
        return Self.normalizedAverage(from: rating)
    }
}

enum TrendingItemType: String, CaseIterable {
    case song = "song"
    case album = "album"
    case artist = "artist"
}

struct FriendActivity: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let userProfilePictureUrl: String?
    let songTitle: String
    let artistName: String
    let artworkUrl: String?
    let rating: Double?
    let loggedAt: Date
    let musicLog: MusicLog?
    
    init(id: String = UUID().uuidString, userId: String, username: String, userProfilePictureUrl: String? = nil, songTitle: String, artistName: String, artworkUrl: String? = nil, rating: Double? = nil, loggedAt: Date, musicLog: MusicLog? = nil) {
        self.id = id
        self.userId = userId
        self.username = username
        self.userProfilePictureUrl = userProfilePictureUrl
        self.songTitle = songTitle
        self.artistName = artistName
        self.artworkUrl = artworkUrl
        self.rating = rating
        self.loggedAt = loggedAt
        self.musicLog = musicLog
    }
}

struct CreatorSpotlight: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let displayName: String?
    let profilePictureUrl: String?
    let isVerified: Bool
    let roles: [String]?
    let recentLogs: [MusicLog]
    var latestLog: MusicLog? { recentLogs.first }
    let nowPlayingSong: String?
    let nowPlayingArtist: String?
    let nowPlayingAlbumArt: String?
    
    init(user: UserProfile, recentLogs: [MusicLog]) {
        self.id = user.uid
        self.userId = user.uid
        self.username = user.username
        self.displayName = user.displayName
        self.profilePictureUrl = user.profilePictureUrl
        self.isVerified = user.isVerified ?? false
        self.roles = user.roles
        self.recentLogs = recentLogs
        self.nowPlayingSong = user.nowPlayingSong
        self.nowPlayingArtist = user.nowPlayingArtist
        self.nowPlayingAlbumArt = user.nowPlayingAlbumArt
    }
}

// MARK: - Social Feed View Model

class SocialFeedViewModel: ObservableObject {
    @Published var trendingSongs: [TrendingItem] = []
    @Published var trendingArtists: [TrendingItem] = []
    @Published var trendingAlbums: [TrendingItem] = []
    @Published var todaysHot: [TrendingItem] = []
    private var todaysHotPageIndex: Int = 1
    private let todaysHotPageSize: Int = 20
    private func logDebug(_ message: String) {
        AppLogger.debug(message, category: .socialFeed)
    }
    
    private func logError(_ message: String) {
        AppLogger.error(message, category: .socialFeed)
    }
    @Published var friendsActivity: [FriendActivity] = []
    
    @Published var allTrendingSongs: [TrendingItem] = []
    @Published var allTrendingArtists: [TrendingItem] = []
    @Published var allTrendingAlbums: [TrendingItem] = []
    @Published var allFriendsActivity: [FriendActivity] = []
    // Friends popular (songs)
    @Published var friendsPopularSongs: [TrendingItem] = []
    @Published var allFriendsPopularSongs: [TrendingItem] = []
    // Friends popular (albums)
    @Published var friendsPopularAlbums: [TrendingItem] = []
    @Published var allFriendsPopularAlbums: [TrendingItem] = []
    private var friendsPopularCursorDate: Date?
    // Friends popular (combined: song/album/artist)
    @Published var friendsPopularCombined: [TrendingItem] = []
    @Published var allFriendsPopularCombined: [TrendingItem] = []
    
    @Published var isLoadingTrendingSongs = false
    @Published var isLoadingTrendingArtists = false
    @Published var isLoadingTrendingAlbums = false
    @Published var isLoadingFriendsActivity = false
    @Published var isLoadingCreators = false
    @Published var isLoadingWeeklyPopular = false
    
    @Published var showAllTrendingSongs = false
    @Published var showAllTrendingArtists = false
    @Published var showAllTrendingAlbums = false
    @Published var showAllFriendsActivity = false
    @Published var hasNewPosts = false
    @Published var showAllFriendsPopular = false
    @Published var showAllWeeklyPopular = false
    // Genres
    @Published var availableGenres: [String] = ["hip-hop", "pop", "indie", "r&b", "electronic", "rock", "country", "latin", "k-pop", "jazz", "metal", "classical"]
    @Published var selectedGenre: String = UserDefaults.standard.string(forKey: "selectedGenre") ?? "Hip-Hop"
    @Published var activeGenreFilter: String = UserDefaults.standard.string(forKey: "selectedGenre") ?? "Hip-Hop"
    @Published var genreTrending: [TrendingItem] = []
    @Published var allGenreTrending: [TrendingItem] = []
    @Published var isLoadingGenre = false
    @Published var showAllGenre = false
    @Published var genreTrendingArtists: [TrendingItem] = []
    @Published var allGenreTrendingArtists: [TrendingItem] = []
    @Published var isLoadingGenreArtists = false
    @Published var showAllGenreArtists = false
    @Published var genreTrendingAlbums: [TrendingItem] = []
    @Published var allGenreTrendingAlbums: [TrendingItem] = []
    @Published var isLoadingGenreAlbums = false
    @Published var showAllGenreAlbums = false
    // Genre: Popular with Friends (songs)
    @Published var genreFriendsPopularSongs: [TrendingItem] = []
    @Published var allGenreFriendsPopularSongs: [TrendingItem] = []
    @Published var showAllGenreFriendsPopular = false
    // Genre: Popular with Friends (combined)
    @Published var genreFriendsPopularCombined: [TrendingItem] = []
    @Published var allGenreFriendsPopularCombined: [TrendingItem] = []
    @Published var showAllGenreFriendsPopularCombined = false
    
    // Creators spotlight
    @Published var creatorsSpotlight: [CreatorSpotlight] = []
    @Published var allCreatorsSpotlight: [CreatorSpotlight] = []
    @Published var showAllCreators = false
    private var creatorsLastLoadedAt: Date? = nil
    private var creatorsLastDoc: DocumentSnapshot? = nil
    @Published var nowPlayingCreators: [UserProfile] = []
    @Published var showAllCreatorsNowPlaying: Bool = false
    @Published var nowPlayingFriends: [UserProfile] = []
    @Published var creatorSongLogs: [MusicLog] = []
    @Published var creatorArtistLogs: [MusicLog] = []
    @Published var creatorAlbumLogs: [MusicLog] = []
    @Published var isLoadingCreatorSongs = false
    @Published var isLoadingCreatorArtists = false
    @Published var isLoadingCreatorAlbums = false
    private var creatorLogsOldestDateSongs: Date? = nil
    private var creatorLogsOldestDateArtists: Date? = nil
    private var creatorLogsOldestDateAlbums: Date? = nil
    // Explore visible counts
    @Published var creatorSongsVisible: Int = 10
    @Published var creatorArtistsVisible: Int = 10
    @Published var creatorAlbumsVisible: Int = 10
    
    // Friends data for profile pictures
    @Published var friendsData: [String: [FriendProfile]] = [:]
    private let friendsPopularService = FriendsPopularService()
    // Weekly popular logs
    @Published var weeklyPopularLogs: [MusicLog] = []
    private var weeklyCursorDate: Date? = nil
    @Published var weeklyVisibleCount: Int = 10
    @Published var showAllFriendsNowPlaying: Bool = false
    // Weekly popular logs by genre
    @Published var genreWeeklyPopularLogs: [MusicLog] = []
    private var genreWeeklyCursorDate: Date? = nil
    @Published var showAllGenreWeeklyPopular = false
    @Published var genreWeeklyVisibleCount: Int = 10
    
    // Display counts for infinite scroll on main tab
    @Published var friendsDisplayCount: Int = 5
    @Published var trendingDisplayCountSongs: Int = 10
    @Published var trendingDisplayCountArtists: Int = 10
    @Published var trendingDisplayCountAlbums: Int = 10
    
    // Pagination cursors
    private var friendsCursorDate: Date?
    private var trendingCursorSongs: Date?
    private var trendingCursorArtists: Date?
    private var trendingCursorAlbums: Date?
    
    private let db = Firestore.firestore()
    private let calendar = Calendar.current
    private let feedService = SocialFeedService.shared
    private var topLogListener: ListenerRegistration?
    private var lastSeenTopDate: Date?
    private let storiesService = TrendingStoriesService.shared
    @Published var genreStories: [TrendingStory] = []
    
    // Genre loading coordination
    private var genreLoadToken: Int = 0

    // Popular module removed per redesign
    
    // MARK: - Public Methods
    
    func loadAllData() {
        #if DEBUG
        // Explicitly set to false if this is the first time (to override any old cached true value)
        if UserDefaults.standard.object(forKey: "feed.mockData.initialized") == nil {
            UserDefaults.standard.set(false, forKey: "feed.mockData")
            UserDefaults.standard.set(true, forKey: "feed.mockData.initialized")
            logDebug("🔧 Initialized feed.mockData to FALSE (real data) on first launch")
        }
        
        // Check if mock data is explicitly enabled (default is now FALSE for real data)
        if UserDefaults.standard.bool(forKey: "feed.mockData") {
            logDebug("📊 Loading MOCK data (feed.mockData is enabled)")
            // Populate with mock data for design review
            let allSongs = MockSocialData.trendingItems(count: 36, type: "song")
            self.allTrendingSongs = allSongs
            self.trendingSongs = Array(allSongs.prefix(12))
            self.trendingArtists = MockSocialData.trendingItems(count: 10, type: "artist")
            self.trendingAlbums = MockSocialData.trendingItems(count: 10, type: "album")
            self.todaysHot = MockSocialData.trendingItems(count: 24, type: "song")
            self.friendsActivity = MockSocialData.friendsActivity(count: 12)
            // Genres mocks
            self.availableGenres = ["hip-hop", "pop", "indie", "r&b", "electronic"]
            self.genreTrending = MockSocialData.trendingItems(count: 8, type: "song")
            self.allGenreTrending = self.genreTrending
            self.genreStories = []
            // Genre artists/albums trending (approximation for mocks)
            self.genreTrendingArtists = MockSocialData.trendingItems(count: 8, type: "artist")
            self.allGenreTrendingArtists = self.genreTrendingArtists
            self.genreTrendingAlbums = MockSocialData.trendingItems(count: 8, type: "album")
            self.allGenreTrendingAlbums = self.genreTrendingAlbums
            self.genreFriendsPopularSongs = MockSocialData.genreFriendsPopular(genre: self.selectedGenre, count: 12)
            self.allGenreFriendsPopularSongs = self.genreFriendsPopularSongs
            // Explore mocks
            self.nowPlayingCreators = MockSocialData.nowPlayingCreators(count: 8)
            self.creatorSongLogs = MockSocialData.creatorLogs(type: "song", count: 12)
            self.creatorArtistLogs = MockSocialData.creatorLogs(type: "artist", count: 12)
            self.creatorAlbumLogs = MockSocialData.creatorLogs(type: "album", count: 12)
            // New: friends popular combined (approximation: merge rails)
            var combined: [TrendingItem] = []
            combined.append(contentsOf: self.trendingSongs.prefix(6))
            combined.append(contentsOf: self.trendingAlbums.prefix(4))
            combined.append(contentsOf: self.trendingArtists.prefix(4))
            self.friendsPopularCombined = Array(combined.prefix(10))
            self.allFriendsPopularCombined = combined
            // New: friends now playing (use creators as stand-in)
            self.nowPlayingFriends = MockSocialData.nowPlayingCreators(count: 8)
            // New: weekly popular logs (use creator logs as stand-in)
            self.weeklyPopularLogs = (self.creatorSongLogs + self.creatorAlbumLogs + self.creatorArtistLogs)
            // New: genre friends popular combined (approximation)
            var gCombined: [TrendingItem] = []
            gCombined.append(contentsOf: self.genreTrending.prefix(4))
            gCombined.append(contentsOf: self.genreTrendingAlbums.prefix(3))
            gCombined.append(contentsOf: self.genreTrendingArtists.prefix(3))
            self.genreFriendsPopularCombined = Array(gCombined.prefix(10))
            self.allGenreFriendsPopularCombined = gCombined
            // New: weekly popular by genre (use subset of creator logs)
            self.genreWeeklyPopularLogs = Array(self.creatorSongLogs.prefix(10))
            
            // Inject mock friends so PFPs are visible in rails
            self.friendsData.removeAll()
            self.addMockFriendData(for: self.friendsPopularCombined)
            self.addMockFriendData(for: self.genreFriendsPopularCombined)
            self.addMockFriendData(for: self.genreFriendsPopularSongs)
            // Also add for trending rails (All + Genre)
            self.addMockFriendData(for: self.trendingSongs)
            self.addMockFriendData(for: self.trendingArtists)
            self.addMockFriendData(for: self.trendingAlbums)
            self.addMockFriendData(for: self.genreTrending)
            self.addMockFriendData(for: self.genreTrendingArtists)
            self.addMockFriendData(for: self.genreTrendingAlbums)
            return
        }
        #endif
        // Short-lived caches for a snappy cold start (120s TTL)
        if let cached = SocialCache.shared.load(key: "trending_songs_all", maxAgeSeconds: 120) {
            self.allTrendingSongs = cached
            self.trendingSongs = Array(cached.prefix(10))
            AnalyticsService.shared.logDiscoveryCache(event: "load", source: "social_trending_songs", hit: true, ageMs: nil)
        } else {
            AnalyticsService.shared.logDiscoveryCache(event: "load", source: "social_trending_songs", hit: false, ageMs: nil)
        }
        if let cached = SocialCache.shared.load(key: "trending_artists_all", maxAgeSeconds: 120) {
            self.allTrendingArtists = cached
            self.trendingArtists = Array(cached.prefix(10))
        }
        if let cached = SocialCache.shared.load(key: "trending_albums_all", maxAgeSeconds: 120) {
            self.allTrendingAlbums = cached
            self.trendingAlbums = Array(cached.prefix(10))
        }
        // PERFORMANCE OPTIMIZATION: Load all data in parallel using TaskGroup
        let startTime = Date()
        logDebug("⏱️ [SocialFeed] Starting parallel data load...")
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                // Critical data: Load first (trending, friends activity)
                group.addTask { await self.loadTrendingSongsAsync() }
                group.addTask { await self.loadTrendingArtistsAsync() }
                group.addTask { await self.loadTrendingAlbumsAsync() }
                group.addTask { await self.loadFriendsActivityAsync() }
                
                // Friends popular data
                group.addTask { await self.loadFriendsPopularCombinedAsync(reset: true) }
                group.addTask { await self.loadNowPlayingFriendsAsync() }
                group.addTask { await self.loadWeeklyPopularAsync(reset: true) }
                
                // Genre-specific data
                group.addTask { await self.loadGenreTrendingAsync(for: self.selectedGenre) }
                group.addTask { await self.loadGenreStoriesAsync(for: self.selectedGenre) }
                group.addTask { await self.loadGenreTrendingArtistsAsync(for: self.selectedGenre) }
                group.addTask { await self.loadGenreTrendingAlbumsAsync(for: self.selectedGenre) }
                group.addTask { await self.loadGenrePopularFriendsAsync(for: self.selectedGenre) }
                group.addTask { await self.loadGenrePopularFriendsCombinedAsync(for: self.selectedGenre) }
                group.addTask { await self.loadGenreWeeklyPopularAsync(for: self.selectedGenre, reset: true) }
                
                // Creator/explore data
                group.addTask { await self.loadCreatorsSpotlightAsync() }
                group.addTask { await self.loadNowPlayingCreatorsAsync() }
            }
            
            await MainActor.run {
                self.buildTodaysHot(reset: true)
                
                // Load friend data for profile pictures
                self.loadFriendsDataForItems()
                
                let elapsed = Date().timeIntervalSince(startTime)
                logDebug("⏱️ [SocialFeed] Parallel data load completed in \(Int(elapsed * 1000))ms")
            }
        }
    }

    func stopLiveListeners() {
        topLogListener?.remove(); topLogListener = nil
    }
    
    @MainActor
    func prepareGenreLoad(for genre: String) -> Int {
        selectedGenre = genre
        activeGenreFilter = genre
        genreLoadToken &+= 1
        let token = genreLoadToken
        
        // reset data to avoid showing stale content
        genreTrending = []
        allGenreTrending = []
        genreTrendingArtists = []
        allGenreTrendingArtists = []
        genreTrendingAlbums = []
        allGenreTrendingAlbums = []
        genreFriendsPopularSongs = []
        allGenreFriendsPopularSongs = []
        genreFriendsPopularCombined = []
        allGenreFriendsPopularCombined = []
        genreWeeklyPopularLogs = []
        
        isLoadingGenre = true
        isLoadingGenreArtists = true
        isLoadingGenreAlbums = true
        isLoadingWeeklyPopular = true
        
        return token
    }
    
    @MainActor
    func refreshAllData() async {
        #if DEBUG
        // Check if mock data is explicitly enabled (default is now FALSE for real data)
        if UserDefaults.standard.bool(forKey: "feed.mockData") {
            logDebug("📊 Refreshing MOCK data (feed.mockData is enabled)")
            await MainActor.run {
                self.trendingSongs = MockSocialData.trendingItems(count: 12, type: "song")
                self.allTrendingSongs = MockSocialData.trendingItems(count: 36, type: "song")
                self.trendingArtists = MockSocialData.trendingItems(count: 10, type: "artist")
                self.trendingAlbums = MockSocialData.trendingItems(count: 10, type: "album")
                self.todaysHot = MockSocialData.trendingItems(count: 24, type: "song")
                self.friendsActivity = MockSocialData.friendsActivity(count: 12)
                // Genres mocks
                self.genreTrending = MockSocialData.trendingItems(count: 8, type: "song")
                self.allGenreTrending = self.genreTrending
                self.genreStories = MockSocialData.stories(for: self.selectedGenre)
                self.genreFriendsPopularSongs = MockSocialData.genreFriendsPopular(genre: self.selectedGenre, count: 12)
                self.allGenreFriendsPopularSongs = self.genreFriendsPopularSongs
                // Explore mocks
                self.nowPlayingCreators = MockSocialData.nowPlayingCreators(count: 8)
                self.creatorSongLogs = MockSocialData.creatorLogs(type: "song", count: 12)
                self.creatorArtistLogs = MockSocialData.creatorLogs(type: "artist", count: 12)
                self.creatorAlbumLogs = MockSocialData.creatorLogs(type: "album", count: 12)
                self.resetVisibleCounts()
            }
            return
        }
        #else
        // In release builds, never use mock data
        #endif
        logDebug("✅ Refreshing REAL data from Firestore")
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTrendingSongsAsync() }
            group.addTask { await self.loadTrendingArtistsAsync() }
            group.addTask { await self.loadTrendingAlbumsAsync() }
            group.addTask { await self.loadFriendsActivityAsync() }
            group.addTask { await self.loadNowPlayingFriendsAsync() }
        }
        await MainActor.run {
            self.resetVisibleCounts()
            self.buildTodaysHot(reset: true)
            
            // Load friend data for profile pictures
            self.loadFriendsDataForItems()
        }
    }

    // MARK: - Friends Popular (songs)
    @MainActor
    func loadFriendsPopularSongsAsync(reset: Bool) async {
        isLoadingTrendingSongs = true
        defer { isLoadingTrendingSongs = false }
        do {
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let items = try await feedService.fetchFriendsPopularSongs(for: uid)
            self.allFriendsPopularSongs = items
            self.friendsPopularSongs = Array(items.prefix(10))
        } catch {
            logError("Friends popular load error: \(error)")
        }
    }

    // MARK: - Friends Popular (combined types)
    @MainActor
    func loadFriendsPopularCombinedAsync(reset: Bool) async {
        isLoadingTrendingSongs = true
        defer { isLoadingTrendingSongs = false }
        do {
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let items = try await feedService.fetchFriendsPopularCombined(for: uid)
            self.allFriendsPopularCombined = items
            self.friendsPopularCombined = Array(items.prefix(10))
        } catch {
            logError("Friends popular combined load error: \(error)")
        }
    }

    // MARK: - Friends Now Playing
    @MainActor
    func loadNowPlayingFriendsAsync() async {
        do {
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let results = try await feedService.fetchNowPlayingFriends(for: uid)
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            self.nowPlayingFriends = results.filter { !hidden.contains($0.uid) }
            
            logDebug("🎵 [NowPlaying] Loaded \(self.nowPlayingFriends.count) friends currently listening (filtered stale data)")
        } catch {
            self.nowPlayingFriends = []
        }
    }

    // MARK: - Weekly Popular Logs
    @MainActor
    func loadWeeklyPopularAsync(reset: Bool) async {
        if reset { weeklyCursorDate = nil }
        isLoadingWeeklyPopular = true
        defer { isLoadingWeeklyPopular = false }
        do {
            let fetched = try await feedService.fetchWeeklyPopularLogs(before: weeklyCursorDate)
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let visible = fetched.filter { !hidden.contains($0.userId) }
            let scored = scoreAndSortLogs(visible)
            if reset { weeklyPopularLogs = Array(scored.prefix(20)) } else { weeklyPopularLogs.append(contentsOf: scored.prefix(20)) }
            weeklyCursorDate = fetched.last?.dateLogged ?? weeklyCursorDate
        } catch {
            // keep existing state
        }
    }

    @MainActor
    func increaseWeeklyVisible(step: Int = 10) {
        weeklyVisibleCount = min(weeklyVisibleCount + step, max(weeklyVisibleCount + step, weeklyPopularLogs.count))
    }

    @MainActor
    func resetWeeklyVisible() {
        weeklyVisibleCount = 10
    }

    // MARK: - Weekly Popular Logs by Genre
    @MainActor
    func loadGenreWeeklyPopularAsync(for genre: String, reset: Bool, context: Int? = nil) async {
        if reset { genreWeeklyCursorDate = nil }
        let shouldGuard = context != nil
        if !shouldGuard {
        isLoadingWeeklyPopular = true
        }
        do {
            let fetched = try await feedService.fetchGenreWeeklyPopularLogs(for: genre, before: genreWeeklyCursorDate)
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let visible = fetched.filter { !hidden.contains($0.userId) }
            let scored = scoreAndSortLogs(visible)
            if shouldGuard && context != genreLoadToken { return }
            if reset { genreWeeklyPopularLogs = Array(scored.prefix(20)) } else { genreWeeklyPopularLogs.append(contentsOf: scored.prefix(20)) }
            genreWeeklyCursorDate = fetched.last?.dateLogged ?? genreWeeklyCursorDate
        } catch {
            // keep existing state
        }
        if !shouldGuard || context == genreLoadToken {
            isLoadingWeeklyPopular = false
        }
    }

    @MainActor
    func increaseGenreWeeklyVisible(step: Int = 10) {
        genreWeeklyVisibleCount = min(genreWeeklyVisibleCount + step, max(genreWeeklyVisibleCount + step, genreWeeklyPopularLogs.count))
    }

    @MainActor
    func resetGenreWeeklyVisible() {
        genreWeeklyVisibleCount = 10
    }

    // MARK: - Genre Trending
    @MainActor
    func loadGenreTrendingAsync(for genre: String, context: Int? = nil) async {
        let shouldGuard = context != nil
        if !shouldGuard {
        isLoadingGenre = true
        }
        do {
            let logsRaw = try await feedService.fetchGenreLogs(for: genre, limit: 200)
            // Filter out hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let logs = logsRaw.filter { !hidden.contains($0.userId) }
            
            // Ensure the "Trending Songs" row only contains song logs
            let songLogs = logs.filter { $0.itemType == "song" }
            
            guard !songLogs.isEmpty else {
                self.genreTrending = []
                self.allGenreTrending = []
                self.isLoadingGenre = false
                return
            }
            
            // 🎯 Phase 3: Group by universalTrackId for cross-platform aggregation
            let grouped = Dictionary(grouping: songLogs) { log in
                log.universalTrackId ?? log.itemId // Fallback to itemId for old logs
            }
            
            var items: [TrendingItem] = grouped.compactMap { (trackId, logs) in
                guard let first = logs.first else { return nil }
                
                logDebug("🎵 Genre Trending: \(first.title) - \(logs.count) logs (universalTrackId: \(trackId))")
                
                return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: nil, itemType: "song", itemId: trackId)
            }
            .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) > calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
            
            // Enrich with overall ratings from all logs (not just 72-hour window)
            items = await feedService.enrichWithOverallRatings(items, itemType: "song")
            
            if shouldGuard && context != genreLoadToken { return }
            self.genreTrending = Array(items.prefix(10))
            self.allGenreTrending = items
            self.isLoadingGenre = false
        } catch {
            logError("Error loading genre trending: \(error)")
            if shouldGuard && context != genreLoadToken { return }
            self.isLoadingGenre = false
        }
    }

    @MainActor
    func loadGenreTrendingArtistsAsync(for genre: String, context: Int? = nil) async {
        let shouldGuard = context != nil
        if !shouldGuard {
        isLoadingGenreArtists = true
        }
        do {
            let logsRaw = try await feedService.fetchGenreLogs(for: genre, limit: 500)
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let logs = logsRaw.filter { !hidden.contains($0.userId) }
            
            var artistLogs: [String: (displayName: String, logs: [MusicLog])] = [:]
            for log in logs {
                let artists = ArtistNameParser.splitArtists(from: log.artistName)
                let targets = artists.isEmpty ? [log.artistName] : artists
                for artist in targets {
                    let key = ArtistNameParser.normalizedKey(artist)
                    guard !key.isEmpty else { continue }
                    if artistLogs[key] == nil {
                        artistLogs[key] = (artist, [log])
                    } else {
                        artistLogs[key]?.logs.append(log)
                    }
                }
            }
            
            var items: [TrendingItem] = artistLogs.compactMap { (key, payload) in
                TrendingItem(
                    title: payload.displayName,
                    subtitle: nil,
                    artworkUrl: nil,
                    logCount: payload.logs.count,
                    averageRating: nil,
                    itemType: "artist",
                    itemId: key
                )
            }
            .sorted { calculateTrendingScore(item: $0, logs: artistLogs[$0.itemId]?.logs ?? []) >
                      calculateTrendingScore(item: $1, logs: artistLogs[$1.itemId]?.logs ?? []) }
            
            items = await feedService.enrichArtistsWithArtwork(items)
            
            if !items.isEmpty {
                let summaries = await ArtistRatingsService.shared.fetchRatings(for: items.map { $0.title })
                items = items.map { item in
                    if let summary = summaries[item.title], summary.count > 0 {
                        let rounded = (summary.average * 10).rounded() / 10
                        return item.withAverageRating(rounded, totalRatings: summary.count)
                    }
                    return item
                }
            }
            
            if shouldGuard && context != genreLoadToken { return }
            self.genreTrendingArtists = Array(items.prefix(10))
            self.allGenreTrendingArtists = items
        } catch {
            logError("Error loading genre trending artists: \(error)")
            if shouldGuard && context != genreLoadToken { return }
        }
        if !shouldGuard || context == genreLoadToken {
            isLoadingGenreArtists = false
        }
    }

    @MainActor
    func loadGenreTrendingAlbumsAsync(for genre: String, context: Int? = nil) async {
        let shouldGuard = context != nil
        if !shouldGuard {
        isLoadingGenreAlbums = true
        }
        do {
            let logsRaw = try await feedService.fetchGenreLogs(for: genre, limit: 500)
            // Filter out hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let logs = logsRaw.filter { !hidden.contains($0.userId) }
            let grouped = Dictionary(grouping: logs.filter { $0.itemType == "album" }) { $0.itemId }
            var items: [TrendingItem] = grouped.compactMap { (itemId, logs) in
                guard let first = logs.first else { return nil }
                return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: nil, itemType: "album", itemId: itemId)
            }
            .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) > calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
            
            // Enrich with overall ratings from all logs (not just genre window)
            items = await feedService.enrichWithOverallRatings(items, itemType: "album")
            
            if shouldGuard && context != genreLoadToken { return }
            self.genreTrendingAlbums = Array(items.prefix(10))
            self.allGenreTrendingAlbums = items
        } catch {
            logError("Error loading genre trending albums: \(error)")
            if shouldGuard && context != genreLoadToken { return }
        }
        if !shouldGuard || context == genreLoadToken {
            isLoadingGenreAlbums = false
        }
    }

    // MARK: - Genre Popular with Friends
    @MainActor
    func loadGenrePopularFriendsAsync(for genre: String, context: Int? = nil) async {
        do {
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let items = try await feedService.fetchGenreFriendsPopularSongs(for: uid, genre: genre)
            if context != nil && context != genreLoadToken { return }
            self.allGenreFriendsPopularSongs = items
            self.genreFriendsPopularSongs = Array(items.prefix(10))
        } catch {
            logError("Genre friends popular load error: \(error)")
        }
    }

    // MARK: - Genre Popular with Friends (combined)
    @MainActor
    func loadGenrePopularFriendsCombinedAsync(for genre: String, context: Int? = nil) async {
        do {
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let items = try await feedService.fetchGenreFriendsPopularCombined(for: uid, genre: genre)
            if context != nil && context != genreLoadToken { return }
            self.allGenreFriendsPopularCombined = items
            self.genreFriendsPopularCombined = Array(items.prefix(10))
        } catch {
            // ignore
        }
    }

    // MARK: - Genre Stories
    @MainActor
    func loadGenreStoriesAsync(for genre: String) async {
        do {
            let stories = try await storiesService.fetchStories(for: genre)
            self.genreStories = stories
        } catch {
            self.genreStories = []
        }
    }

    private func scoreAndSortLogs(_ logs: [MusicLog]) -> [MusicLog] {
        // Use new engagement scoring service
        return EngagementScoringService.shared.sortByEngagement(logs)
    }

    // Popular helpers removed per redesign

    // MARK: - Creators Spotlight
    @MainActor
    func loadCreatorsSpotlightAsync() async {
        isLoadingCreators = true
        do {
            if let last = creatorsLastLoadedAt, Date().timeIntervalSince(last) < 300, !allCreatorsSpotlight.isEmpty {
                // Use cache if loaded within 5 minutes
                self.isLoadingCreators = false
                return
            }
            // Fetch verified creators
            let page = try await feedService.fetchCreatorSpotlightEntries(limit: 20, after: nil)
            self.creatorsLastDoc = page.lastDocument
            var results = page.entries.map { CreatorSpotlight(user: $0.user, recentLogs: $0.recentLogs) }
            // Prefer creators that have a latest log
            results.sort { (a, b) in
                let aDate = a.latestLog?.dateLogged ?? .distantPast
                let bDate = b.latestLog?.dateLogged ?? .distantPast
                return aDate > bDate
            }
            self.creatorsSpotlight = Array(results.prefix(10))
            self.allCreatorsSpotlight = results
            self.isLoadingCreators = false
            self.creatorsLastLoadedAt = Date()
        } catch {
            logError("Error loading creators spotlight: \(error)")
            self.isLoadingCreators = false
        }
    }

    @MainActor
    func loadMoreCreatorsPage() async {
        guard !isLoadingCreators else { return }
        isLoadingCreators = true
        do {
            let page = try await feedService.fetchCreatorSpotlightEntries(limit: 20, after: creatorsLastDoc)
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let filteredEntries = page.entries.filter { !hidden.contains($0.user.uid) }
            self.creatorsLastDoc = page.lastDocument
            let newResults = filteredEntries.map { CreatorSpotlight(user: $0.user, recentLogs: $0.recentLogs) }
            // Append and keep sorted by latest activity
            self.allCreatorsSpotlight.append(contentsOf: newResults)
            self.allCreatorsSpotlight.sort { ($0.latestLog?.dateLogged ?? .distantPast) > ($1.latestLog?.dateLogged ?? .distantPast) }
            self.creatorsSpotlight = Array(self.allCreatorsSpotlight.prefix(10))
            self.isLoadingCreators = false
        } catch {
            self.isLoadingCreators = false
        }
    }

    // MARK: - Explore: Now Playing
    @MainActor
    func loadNowPlayingCreatorsAsync() async {
        do {
            let users = try await feedService.fetchNowPlayingCreators(limit: 40)
            self.nowPlayingCreators = users
        } catch {
            self.nowPlayingCreators = []
        }
    }

    // MARK: - Explore: Creator Logs (Songs/Artists/Albums)
    private func getCreatorIds() async -> [String] {
        if !allCreatorsSpotlight.isEmpty { return allCreatorsSpotlight.map { $0.userId } }
        await loadCreatorsSpotlightAsync()
        return allCreatorsSpotlight.map { $0.userId }
    }

    @MainActor
    func loadCreatorLogs(type: String, append: Bool = false) async {
        let ids = await getCreatorIds()
        if ids.isEmpty { return }
        await UserPreferencesService.shared.loadHiddenUsers()
        let hidden = UserPreferencesService.shared.hiddenUserIds
        
        // Filter out blocked users
        let blockedUsers = BlockingService.shared.blockedUsers
        let includeIds = ids.filter { !hidden.contains($0) && !blockedUsers.contains($0) }
        if includeIds.isEmpty { return }

        let beforeDate: Date? = {
            switch type {
            case "song": return creatorLogsOldestDateSongs
            case "artist": return creatorLogsOldestDateArtists
            case "album": return creatorLogsOldestDateAlbums
            default: return nil
            }
        }()

        func setLoading(_ value: Bool) {
            switch type {
            case "song": isLoadingCreatorSongs = value
            case "artist": isLoadingCreatorArtists = value
            case "album": isLoadingCreatorAlbums = value
            default: break
            }
        }

        setLoading(true)
        do {
            let collected = try await feedService.fetchCreatorLogs(for: includeIds, type: type, before: beforeDate)
            // De-duplicate, filter blocked users, and sort
            var map: [String: MusicLog] = [:]
            for l in collected { map[l.id] = l }
            let unfiltered = Array(map.values)
            let merged = BlockingService.shared.filterMusicLogs(unfiltered).sorted { $0.dateLogged > $1.dateLogged }
            switch type {
            case "song":
                if append { creatorSongLogs.append(contentsOf: merged) } else { creatorSongLogs = merged }
                creatorLogsOldestDateSongs = (creatorSongLogs.last?.dateLogged) ?? creatorLogsOldestDateSongs
            case "artist":
                if append { creatorArtistLogs.append(contentsOf: merged) } else { creatorArtistLogs = merged }
                creatorLogsOldestDateArtists = (creatorArtistLogs.last?.dateLogged) ?? creatorLogsOldestDateArtists
            case "album":
                if append { creatorAlbumLogs.append(contentsOf: merged) } else { creatorAlbumLogs = merged }
                creatorLogsOldestDateAlbums = (creatorAlbumLogs.last?.dateLogged) ?? creatorLogsOldestDateAlbums
            default: break
            }
            // De-duplicate across sections with priority: song > album > artist
            deduplicateExploreLists()
            setLoading(false)
        } catch {
            setLoading(false)
        }
    }

    private func deduplicateExploreLists() {
        var seen: Set<String> = []
        // Songs first
        creatorSongLogs = creatorSongLogs.filter { log in
            if seen.contains(log.id) { return false }
            seen.insert(log.id); return true
        }
        // Albums next
        creatorAlbumLogs = creatorAlbumLogs.filter { log in
            if seen.contains(log.id) { return false }
            seen.insert(log.id); return true
        }
        // Artists last
        creatorArtistLogs = creatorArtistLogs.filter { log in
            if seen.contains(log.id) { return false }
            seen.insert(log.id); return true
        }
    }

    // MARK: - Explore visible controls
    @MainActor
    func increaseCreatorVisible(type: String, step: Int = 5) {
        switch type {
        case "song": creatorSongsVisible = min(creatorSongsVisible + step, max(creatorSongsVisible + step, creatorSongLogs.count))
        case "artist": creatorArtistsVisible = min(creatorArtistsVisible + step, max(creatorArtistsVisible + step, creatorArtistLogs.count))
        case "album": creatorAlbumsVisible = min(creatorAlbumsVisible + step, max(creatorAlbumsVisible + step, creatorAlbumLogs.count))
        default: break
        }
    }

    @MainActor
    func resetCreatorVisible(type: String) {
        switch type {
        case "song": creatorSongsVisible = 10
        case "artist": creatorArtistsVisible = 10
        case "album": creatorAlbumsVisible = 10
        default: break
        }
    }

    // MARK: - New Posts Listener
    func startNewPostsListener() {
        Task { @MainActor in
            do {
                let latest = try await feedService.fetchLatestLog()
                self.lastSeenTopDate = latest?.dateLogged ?? Date()
            } catch {
                self.lastSeenTopDate = Date()
            }

            // Attach listener to detect newer posts
            self.topLogListener?.remove()
            self.topLogListener = feedService.attachTopLogListener { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let latestLog):
                    guard let latestLog = latestLog else { return }
                    if let lastSeen = self.lastSeenTopDate {
                        if latestLog.dateLogged > lastSeen {
                            DispatchQueue.main.async { self.hasNewPosts = true }
                        }
                    } else {
                        self.lastSeenTopDate = latestLog.dateLogged
                    }
                case .failure:
                    break
                }
            }
        }
    }

    func acknowledgeNewPosts() {
        hasNewPosts = false
        Task { @MainActor in
            do {
                let latest = try await feedService.fetchLatestLog()
                self.lastSeenTopDate = latest?.dateLogged ?? Date()
            } catch {
                self.lastSeenTopDate = Date()
            }
        }
    }

    // MARK: - Prefetch helpers
    /// Lightweight prefetch for trending rails; safe to call from outside
    func prefetchTrendingRails() {
        // Use the existing internal loaders; they are lightweight and idempotent
        loadTrendingSongs()
        loadTrendingArtists()
        loadTrendingAlbums()
    }
    
    // MARK: - Trending Songs
    
    private func loadTrendingSongs() {
        isLoadingTrendingSongs = true
        
        Task {
            await loadTrendingSongsAsync()
        }
    }
    
    @MainActor
    private func loadTrendingSongsAsync() async {
        do {
            var items = try await feedService.fetchTrendingSongs()
            if items.isEmpty { items = generateFallbackTrendingData(type: .song) }
            self.trendingSongs = Array(items.prefix(10))
            self.allTrendingSongs = items
            self.isLoadingTrendingSongs = false
        } catch {
            logError("Error loading trending songs: \(error)")
            self.isLoadingTrendingSongs = false
        }
    }
    
    // MARK: - Trending Artists
    
    private func loadTrendingArtists() {
        isLoadingTrendingArtists = true
        
        Task {
            await loadTrendingArtistsAsync()
        }
    }
    
    @MainActor
    private func loadTrendingArtistsAsync() async {
        do {
            var items = try await feedService.fetchTrendingArtists()
            if !items.isEmpty {
                let artistNames = items.map { $0.title }
                let summaries = await ArtistRatingsService.shared.fetchRatings(for: artistNames)
                items = items.map { item in
                    if let summary = summaries[item.title], summary.count > 0 {
                        let rounded = (summary.average * 10).rounded() / 10
                        return item.withAverageRating(rounded, totalRatings: summary.count)
                    } else {
                        return item
                    }
                }
            }
            if items.isEmpty { items = generateFallbackTrendingData(type: .artist) }
            self.trendingArtists = Array(items.prefix(10))
            self.allTrendingArtists = items
            self.isLoadingTrendingArtists = false
        } catch {
            logError("Error loading trending artists: \(error)")
            self.isLoadingTrendingArtists = false
        }
    }
    
    
    // MARK: - Trending Albums
    
    private func loadTrendingAlbums() {
        isLoadingTrendingAlbums = true
        
        Task {
            await loadTrendingAlbumsAsync()
        }
    }
    
    @MainActor
    private func loadTrendingAlbumsAsync() async {
        do {
            var items = try await feedService.fetchTrendingAlbums()
            if items.isEmpty { items = generateFallbackTrendingData(type: .album) }
            self.trendingAlbums = Array(items.prefix(10))
            self.allTrendingAlbums = items
            self.isLoadingTrendingAlbums = false
        } catch {
            logError("Error loading trending albums: \(error)")
            self.isLoadingTrendingAlbums = false
        }
    }
    
    private func calculateTrendingAlbums(from logs: [MusicLog]) -> [TrendingItem] {
        // 🎯 Phase 3: Group by universalTrackId for cross-platform aggregation
        let grouped = Dictionary(grouping: logs) { log in
            log.universalTrackId ?? log.itemId // Fallback to itemId for old logs
        }
        
        return grouped.compactMap { (trackId, logs) in
            guard let firstLog = logs.first else { return nil }
            
            let logCount = logs.count
            
            // Find the original Apple Music ID from logs (prefer Apple Music platform)
            let appleMusicLog = logs.first { $0.musicPlatform?.lowercased().contains("apple") == true }
            let appleMusicId = appleMusicLog?.itemId ?? firstLog.itemId
            
            logDebug("💿 Trending Album: \(firstLog.title) - \(logCount) logs (universalId: \(trackId), appleMusicId: \(appleMusicId))")
            
            return TrendingItem(
                title: firstLog.title,
                subtitle: firstLog.artistName,
                artworkUrl: firstLog.artworkUrl,
                logCount: logCount,
                averageRating: nil, // Will be set by enrichWithOverallRatings
                itemType: "album",
                itemId: trackId,
                appleMusicId: appleMusicId
            )
        }
        .filter { meetsTrendingThreshold(item: $0) }
        .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) > calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
    }

    // MARK: - Composite: Today's Hot
    private func buildTodaysHot(reset: Bool) {
        if reset { todaysHotPageIndex = 1; todaysHot.removeAll() }
        let combined = combinedHotItemsSorted()
        let end = min(combined.count, todaysHotPageIndex * todaysHotPageSize)
        self.todaysHot = Array(combined.prefix(end))
    }

    func expandTodaysHot() {
        todaysHotPageIndex += 1
        buildTodaysHot(reset: false)
    }

    private func combinedHotItemsSorted() -> [TrendingItem] {
        // Deduplicate by (itemType,itemId)
        var map: [String: TrendingItem] = [:]
        for it in (allTrendingSongs + allTrendingAlbums + allTrendingArtists) {
            let key = "\(it.itemType)|\(it.itemId)"
            if map[key] == nil { map[key] = it }
        }
        let items = Array(map.values)
        return items.sorted { scoreForHot($0) > scoreForHot($1) }
    }

    private func scoreForHot(_ item: TrendingItem) -> Double {
        // Simple score blending recency proxy (logCount) and quality (averageRating)
        let count = Double(item.logCount)
        let rating = item.averageRating ?? 3.0
        // Weights: favor activity, then rating
        return count * 1.0 + rating * 2.0
    }
    
    // MARK: - Friends Activity
    
    private func loadFriendsActivity() {
        isLoadingFriendsActivity = true
        
        Task {
            await loadFriendsActivityAsync()
        }
    }
    
    @MainActor
    private func loadFriendsActivityAsync() async {
        do {
            // Get current user's following list
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                self.isLoadingFriendsActivity = false
                return
            }
            
            let activities = try await feedService.fetchFriendsActivity(for: currentUserId)
            
            // Filter out hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let filtered = activities.filter { !hidden.contains($0.userId) }
            // Session de-duplication against other sections
            SocialSession.shared.register(logIds: filtered.compactMap { $0.musicLog?.id })
            self.allFriendsActivity = filtered
            self.friendsActivity = Array(self.allFriendsActivity.prefix(5))
            self.isLoadingFriendsActivity = false
        } catch {
            logError("Error loading friends activity: \(error)")
            self.isLoadingFriendsActivity = false
        }
    }

    // MARK: - Visible count controls and auto-increment for infinite feel
    @MainActor
    func maybeIncreaseVisibleCounts() {
        // Increase visible counts as data is present
        if friendsDisplayCount < allFriendsActivity.count { friendsDisplayCount = min(friendsDisplayCount + 5, allFriendsActivity.count) }
        if trendingDisplayCountSongs < allTrendingSongs.count { trendingDisplayCountSongs = min(trendingDisplayCountSongs + 5, allTrendingSongs.count) }
        if trendingDisplayCountArtists < allTrendingArtists.count { trendingDisplayCountArtists = min(trendingDisplayCountArtists + 5, allTrendingArtists.count) }
        if trendingDisplayCountAlbums < allTrendingAlbums.count { trendingDisplayCountAlbums = min(trendingDisplayCountAlbums + 5, allTrendingAlbums.count) }
    }

    @MainActor
    func resetVisibleCounts() {
        friendsDisplayCount = 5
        trendingDisplayCountSongs = 10
        trendingDisplayCountArtists = 10
        trendingDisplayCountAlbums = 10
    }

    // Increment helpers for onAppear near-end triggers
    @MainActor
    func increaseFriendsVisible(step: Int = 5) {
        if friendsDisplayCount < allFriendsActivity.count {
            friendsDisplayCount = min(friendsDisplayCount + step, allFriendsActivity.count)
        }
    }

    @MainActor
    func increaseTrendingVisible(type: TrendingItemType, step: Int = 3) {
        switch type {
        case .song:
            if trendingDisplayCountSongs < allTrendingSongs.count {
                trendingDisplayCountSongs = min(trendingDisplayCountSongs + step, allTrendingSongs.count)
            }
        case .artist:
            if trendingDisplayCountArtists < allTrendingArtists.count {
                trendingDisplayCountArtists = min(trendingDisplayCountArtists + step, allTrendingArtists.count)
            }
        case .album:
            if trendingDisplayCountAlbums < allTrendingAlbums.count {
                trendingDisplayCountAlbums = min(trendingDisplayCountAlbums + step, allTrendingAlbums.count)
            }
        }
    }
    
    // MARK: - Trending Score Calculation
    
    /// Determines if an item meets the minimum threshold to be considered "trending"
    private func meetsTrendingThreshold(item: TrendingItem) -> Bool {
        // Minimum 2 logs to be considered trending
        guard item.logCount >= 2 else { return false }
        
        // If it has ratings, average should be at least 2.0 (not terrible)
        if let averageRating = item.averageRating {
            return averageRating >= 2.0
        }
        
        // If no ratings, allow it through (user might have just logged without rating)
        return true
    }
    
    /// Calculates a trending score based on multiple factors:
    /// - Log count (frequency)
    /// - Average rating (quality)
    /// - Recency (more recent = higher score)
    /// - User diversity (more unique users = more trending)
    private func calculateTrendingScore(item: TrendingItem, logs: [MusicLog]) -> Double {
        let logCount = Double(item.logCount)
        let averageRating = item.averageRating ?? 3.0 // Default to neutral if no ratings
        
        // Calculate recency factor (more recent logs get higher scores)
        let now = Date()
        let recencyScore = logs.map { log in
            let hoursAgo = now.timeIntervalSince(log.dateLogged) / 3600.0
            return max(0, 24.0 - hoursAgo) / 24.0 // Score from 0-1 based on how recent
        }.reduce(0, +) / Double(logs.count)
        
        // Calculate user diversity (unique users who logged this item)
        let uniqueUsers = Set(logs.map { $0.userId }).count
        let diversityScore = min(Double(uniqueUsers), 10.0) / 10.0 // Cap at 10 users, normalize to 0-1
        
        // Weighted scoring formula
        let logCountWeight = 3.0      // Most important factor
        let ratingWeight = 2.0        // Quality matters
        let recencyWeight = 1.5       // Recent activity is important
        let diversityWeight = 1.0     // User diversity adds credibility
        
        let totalScore = (logCount * logCountWeight) +
                        (averageRating * ratingWeight) +
                        (recencyScore * recencyWeight) +
                        (diversityScore * diversityWeight)
        
        return totalScore
    }
    
    // MARK: - Fallback Data
    
    /// Gets an adaptive time window for trending calculations
    /// Uses 72 hours (3 days) for trending songs, albums, and artists
    private func getAdaptiveTrendingTimeWindow() -> Date {
        let now = Date()
        
        // Use 72 hours (3 days) ago for trending calculations
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        
        return threeDaysAgo
    }
    
    /// Generates fallback trending data when there's insufficient real activity
    private func generateFallbackTrendingData(type: TrendingItemType, count: Int = 5) -> [TrendingItem] {
        // This could be enhanced to pull from a curated list or recent popular items
        // For now, return empty array to show "Check again later" message
        return []
    }
    
    // MARK: - Friends Data Management
    
    func loadFriendsDataForItems() {
        // Combine all friends popular items plus trending rails so PFPs appear everywhere
        let allItems = friendsPopularSongs + friendsPopularAlbums + friendsPopularCombined + trendingSongs + trendingAlbums + trendingArtists + genreTrending + genreTrendingAlbums + genreTrendingArtists
        
        logDebug("🔍 Loading friend data for \(allItems.count) items")
        logDebug("🔍 Sample items (first 3):")
        for (index, item) in allItems.prefix(3).enumerated() {
            logDebug("   \(index + 1). title: \(item.title), itemId: \(item.itemId), itemType: \(item.itemType)")
        }
        
        // Create items array for the service - USE itemId (Apple Music ID), not id (generated ID)
        let items = allItems.map { (id: $0.itemId, type: $0.itemType) }
        
        // Fetch friend data for all items
        friendsPopularService.fetchFriendsForItems(items: items) { [weak self] results in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Store using itemId so we can look up by itemId later
                self.friendsData = results ?? [:]
                let totalItems = self.friendsData.count
                self.logDebug("✅ Loaded friend data for \(totalItems) items")
                self.logDebug("🔍 Friend data keys (first 5): \(Array(self.friendsData.keys).prefix(5))")
                self.logDebug("🔍 Friend data details:")
                for (key, friends) in self.friendsData.prefix(3) {
                    let friendNames = friends.map { $0.displayName }.joined(separator: ", ")
                    self.logDebug("   itemId: \(key) -> \(friends.count) friends: \(friendNames)")
                    if friends.isEmpty {
                        self.logDebug("      ⚠️ EMPTY ARRAY - no friends will be shown for this item")
                    }
                }
                
                #if DEBUG
                // Add some mock data for testing if no real data
                if self.friendsData.isEmpty {
                    self.logDebug("📝 No real friend data found, adding mock data for testing (DEBUG only)")
                    self.addMockFriendData(for: allItems)
                }
                #else
                // In production, just log that no friend data was found
                if self.friendsData.isEmpty {
                    self.logDebug("ℹ️ No friend data found for any items (no friends have logged these items)")
                }
                #endif
            }
        }
    }
    
    private func addMockFriendData(for items: [TrendingItem]) {
        let mockFriends = [
            FriendProfile(id: "1", displayName: "Alice", profileImageUrl: nil, loggedAt: Date()),
            FriendProfile(id: "2", displayName: "Bob", profileImageUrl: nil, loggedAt: Date()),
            FriendProfile(id: "3", displayName: "Charlie", profileImageUrl: nil, loggedAt: Date()),
            FriendProfile(id: "4", displayName: "Diana", profileImageUrl: nil, loggedAt: Date())
        ]
        
        for item in items {
            friendsData[item.itemId] = mockFriends // Use itemId, not id
        }
    }
    
    func loadFriendsDataForItem(_ item: TrendingItem) {
        friendsPopularService.fetchFriendsForItem(itemId: item.itemId, itemType: item.itemType) { [weak self] friends in
            DispatchQueue.main.async {
                if let friends = friends {
                    self?.friendsData[item.itemId] = friends // Store by itemId
                }
            }
        }
    }
    
}

// MARK: - Array Extension for Unique Elements
extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}