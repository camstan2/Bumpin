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
    let itemId: String // Apple Music ID
    
    enum ItemType: String, CaseIterable {
        case song = "song"
        case album = "album"
        case artist = "artist"
    }
    
    init(id: String = UUID().uuidString, title: String, subtitle: String? = nil, artworkUrl: String? = nil, logCount: Int, averageRating: Double? = nil, itemType: String, itemId: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.artworkUrl = artworkUrl
        self.logCount = logCount
        self.averageRating = averageRating
        self.itemType = itemType
        self.itemId = itemId
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
    let rating: Int?
    let loggedAt: Date
    let musicLog: MusicLog?
    
    init(id: String = UUID().uuidString, userId: String, username: String, userProfilePictureUrl: String? = nil, songTitle: String, artistName: String, artworkUrl: String? = nil, rating: Int? = nil, loggedAt: Date, musicLog: MusicLog? = nil) {
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
    @Published var selectedGenre: String = UserDefaults.standard.string(forKey: "selectedGenre") ?? "hip-hop"
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
    private var topLogListener: ListenerRegistration?
    private var lastSeenTopDate: Date?
    private let storiesService = TrendingStoriesService.shared
    @Published var genreStories: [TrendingStory] = []

    // Popular module removed per redesign
    
    // MARK: - Public Methods
    
    func loadAllData() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "feed.mockData") {
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
        loadTrendingSongs()
        loadTrendingArtists()
        loadTrendingAlbums()
        buildTodaysHot(reset: true)
        loadFriendsActivity()
        Task { await loadFriendsPopularCombinedAsync(reset: true) }
        Task { await loadGenreTrendingAsync(for: selectedGenre) }
        Task { await loadGenreStoriesAsync(for: selectedGenre) }
        Task { await loadGenreTrendingArtistsAsync(for: selectedGenre) }
        Task { await loadGenreTrendingAlbumsAsync(for: selectedGenre) }
        Task { await loadGenrePopularFriendsAsync(for: selectedGenre) }
        Task { await loadGenrePopularFriendsCombinedAsync(for: selectedGenre) }
        Task { await loadCreatorsSpotlightAsync() }
        Task { await loadNowPlayingCreatorsAsync() }
        Task { await loadNowPlayingFriendsAsync() }
        Task { await loadWeeklyPopularAsync(reset: true) }
        Task { await loadGenreWeeklyPopularAsync(for: selectedGenre, reset: true) }
    }

    func stopLiveListeners() {
        topLogListener?.remove(); topLogListener = nil
    }
    
    @MainActor
    func refreshAllData() async {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "feed.mockData") {
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
        #endif
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTrendingSongsAsync() }
            group.addTask { await self.loadTrendingArtistsAsync() }
            group.addTask { await self.loadTrendingAlbumsAsync() }
            group.addTask { await self.loadFriendsActivityAsync() }
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
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let data = userDoc.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Array(Set(followingIds).intersection(Set(followerIds)))
            guard !mutuals.isEmpty else { self.friendsPopularSongs = []; self.allFriendsPopularSongs = []; return }
            // Batch query logs by mutuals within window
            var all: [MusicLog] = []
            for batch in mutuals.chunked(into: 10) {
                let snap = try await db.collection("logs")
                    .whereField("userId", in: batch)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
                    .getDocuments()
                var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                logs = logs.filter { $0.itemType == "song" && $0.dateLogged >= timeWindow && (($0.isPublic ?? true) == true) }
                all.append(contentsOf: logs)
            }
            // Group and score similar to trending, but using only friends' logs
            let grouped = Dictionary(grouping: all) { $0.itemId }
            let items: [TrendingItem] = grouped.compactMap { (itemId, logs) in
                guard let first = logs.first else { return nil }
                let ratings = logs.compactMap { $0.rating }
                let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "song", itemId: itemId)
            }
            .sorted {
                let l = PopularityService.scoreFriendsPopular(logs: grouped[$0.itemId] ?? [])
                let r = PopularityService.scoreFriendsPopular(logs: grouped[$1.itemId] ?? [])
                return l > r
            }
            self.allFriendsPopularSongs = items
            self.friendsPopularSongs = Array(items.prefix(10))
        } catch {
            print("Friends popular load error: \(error)")
        }
    }

    // MARK: - Friends Popular (combined types)
    @MainActor
    func loadFriendsPopularCombinedAsync(reset: Bool) async {
        isLoadingTrendingSongs = true
        defer { isLoadingTrendingSongs = false }
        do {
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let data = userDoc.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Array(Set(followingIds).intersection(Set(followerIds)))
            guard !mutuals.isEmpty else { self.friendsPopularCombined = []; self.allFriendsPopularCombined = []; return }
            var all: [MusicLog] = []
            for batch in mutuals.chunked(into: 10) {
                let snap = try await db.collection("logs")
                    .whereField("userId", in: batch)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 300)
                    .getDocuments()
                var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                logs = logs.filter { ["song","album","artist"].contains($0.itemType) && $0.dateLogged >= timeWindow && (($0.isPublic ?? true) == true) }
                all.append(contentsOf: logs)
            }
            let grouped = Dictionary(grouping: all) { ($0.itemType + "|" + $0.itemId) }
            let items: [TrendingItem] = grouped.compactMap { (_, logs) in
                guard let first = logs.first else { return nil }
                let ratings = logs.compactMap { $0.rating }
                let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                return TrendingItem(title: first.title, subtitle: first.itemType == "artist" ? nil : first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: first.itemType, itemId: first.itemId)
            }
            .sorted { lhs, rhs in
                let lkey = lhs.itemType + "|" + lhs.itemId
                let rkey = rhs.itemType + "|" + rhs.itemId
                let l = PopularityService.scoreFriendsPopular(logs: grouped[lkey] ?? [])
                let r = PopularityService.scoreFriendsPopular(logs: grouped[rkey] ?? [])
                return l > r
            }
            self.allFriendsPopularCombined = items
            self.friendsPopularCombined = Array(items.prefix(10))
        } catch {
            print("Friends popular combined load error: \(error)")
        }
    }

    // MARK: - Friends Now Playing
    @MainActor
    func loadNowPlayingFriendsAsync() async {
        do {
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let data = userDoc.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Array(Set(followingIds).intersection(Set(followerIds)))
            guard !mutuals.isEmpty else { self.nowPlayingFriends = []; return }
            var results: [UserProfile] = []
            for batch in mutuals.chunked(into: 10) {
                let snap = try await db.collection("users").whereField("uid", in: batch).getDocuments()
                let users = snap.documents.compactMap { try? $0.data(as: UserProfile.self) }
                results.append(contentsOf: users.filter { $0.showNowPlaying == true })
            }
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            self.nowPlayingFriends = results.filter { !hidden.contains($0.uid) }
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
            let now = Date()
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            var query: Query = db.collection("logs").order(by: "dateLogged", descending: true)
            if let cursor = weeklyCursorDate { query = query.whereField("dateLogged", isLessThan: cursor) }
            let snap = try await query.limit(to: 400).getDocuments()
            var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            logs = logs.filter { $0.dateLogged >= oneWeekAgo && ($0.isPublic ?? true) }
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            logs.removeAll { hidden.contains($0.userId) }
            let scored = scoreAndSortLogs(logs)
            if reset { weeklyPopularLogs = Array(scored.prefix(20)) } else { weeklyPopularLogs.append(contentsOf: scored.prefix(20)) }
            weeklyCursorDate = logs.last?.dateLogged ?? weeklyCursorDate
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
    func loadGenreWeeklyPopularAsync(for genre: String, reset: Bool) async {
        if reset { genreWeeklyCursorDate = nil }
        isLoadingWeeklyPopular = true
        defer { isLoadingWeeklyPopular = false }
        do {
            let now = Date()
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            var query: Query = db.collection("logs").whereField("genres", arrayContains: genre).order(by: "dateLogged", descending: true)
            if let cursor = genreWeeklyCursorDate { query = query.whereField("dateLogged", isLessThan: cursor) }
            let snap = try await query.limit(to: 400).getDocuments()
            var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            logs = logs.filter { $0.dateLogged >= oneWeekAgo && ($0.isPublic ?? true) }
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            logs.removeAll { hidden.contains($0.userId) }
            let scored = scoreAndSortLogs(logs)
            if reset { genreWeeklyPopularLogs = Array(scored.prefix(20)) } else { genreWeeklyPopularLogs.append(contentsOf: scored.prefix(20)) }
            genreWeeklyCursorDate = logs.last?.dateLogged ?? genreWeeklyCursorDate
        } catch {
            // keep existing state
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
    func loadGenreTrendingAsync(for genre: String) async {
        isLoadingGenre = true
        do {
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let logsRaw: [MusicLog]
            do {
                let ordered = try await db.collection("logs")
                    .whereField("genres", arrayContains: genre)
                    .whereField("dateLogged", isGreaterThan: timeWindow)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
                    .getDocuments()
                logsRaw = ordered.documents.compactMap { try? $0.data(as: MusicLog.self) }
            } catch {
                // Fallback without composite index: order by date and filter client-side
                let fallback = try await db.collection("logs")
                    .whereField("genres", arrayContains: genre)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
                    .getDocuments()
                logsRaw = fallback.documents.compactMap { try? $0.data(as: MusicLog.self) }.filter { $0.dateLogged >= timeWindow }
            }
            // Filter out hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let logs = logsRaw.filter { !hidden.contains($0.userId) }
            let grouped = Dictionary(grouping: logs) { $0.itemId }
            let items: [TrendingItem] = grouped.compactMap { (itemId, logs) in
                guard let first = logs.first else { return nil }
                let ratings = logs.compactMap { $0.rating }
                let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "song", itemId: itemId)
            }
            .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) > calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
            self.genreTrending = Array(items.prefix(10))
            self.allGenreTrending = items
            self.isLoadingGenre = false
        } catch {
            print("Error loading genre trending: \(error)")
            self.isLoadingGenre = false
        }
    }

    @MainActor
    func loadGenreTrendingArtistsAsync(for genre: String) async {
        isLoadingGenreArtists = true
        defer { isLoadingGenreArtists = false }
        do {
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let snap = try await db.collection("logs")
                .whereField("dateLogged", isGreaterThan: timeWindow)
                .order(by: "dateLogged", descending: true)
                .limit(to: 500)
                .getDocuments()
            var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            // Optional genre server filter if present
            if let first = snap.documents.first, first.data().keys.contains("genres") {
                let genreSnap = try await db.collection("logs")
                    .whereField("genres", arrayContains: genre)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 500)
                    .getDocuments()
                logs = genreSnap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            } else {
                // client fallback
                logs = logs.filter { $0.dateLogged >= timeWindow }
            }
            let grouped = Dictionary(grouping: logs) { $0.artistName }
            let items: [TrendingItem] = grouped.compactMap { (artist, logs) in
                let ratings = logs.compactMap { $0.rating }
                let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                return TrendingItem(title: artist, subtitle: nil, artworkUrl: logs.first?.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "artist", itemId: artist)
            }
            .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) > calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
            self.genreTrendingArtists = Array(items.prefix(10))
            self.allGenreTrendingArtists = items
        } catch {
            print("Error loading genre trending artists: \(error)")
        }
    }

    @MainActor
    func loadGenreTrendingAlbumsAsync(for genre: String) async {
        isLoadingGenreAlbums = true
        defer { isLoadingGenreAlbums = false }
        do {
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let snap = try await db.collection("logs")
                .whereField("dateLogged", isGreaterThan: timeWindow)
                .order(by: "dateLogged", descending: true)
                .limit(to: 500)
                .getDocuments()
            var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            if let first = snap.documents.first, first.data().keys.contains("genres") {
                let genreSnap = try await db.collection("logs")
                    .whereField("genres", arrayContains: genre)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 500)
                    .getDocuments()
                logs = genreSnap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            } else {
                logs = logs.filter { $0.dateLogged >= timeWindow }
            }
            let grouped = Dictionary(grouping: logs.filter { $0.itemType == "album" }) { $0.itemId }
            let items: [TrendingItem] = grouped.compactMap { (itemId, logs) in
                guard let first = logs.first else { return nil }
                let ratings = logs.compactMap { $0.rating }
                let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "album", itemId: itemId)
            }
            .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) > calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
            self.genreTrendingAlbums = Array(items.prefix(10))
            self.allGenreTrendingAlbums = items
        } catch {
            print("Error loading genre trending albums: \(error)")
        }
    }

    // MARK: - Genre Popular with Friends
    @MainActor
    func loadGenrePopularFriendsAsync(for genre: String) async {
        do {
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let data = userDoc.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Array(Set(followingIds).intersection(Set(followerIds)))
            guard !mutuals.isEmpty else { self.genreFriendsPopularSongs = []; self.allGenreFriendsPopularSongs = []; return }
            var all: [MusicLog] = []
            for batch in mutuals.chunked(into: 10) {
                let snap = try await db.collection("logs")
                    .whereField("userId", in: batch)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
                    .getDocuments()
                var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                logs = logs.filter { $0.itemType == "song" && $0.dateLogged >= timeWindow && (($0.isPublic ?? true) == true) }
                // Genre filter (either exact match set or simple contains if you store genres array)
                logs = logs.filter { log in
                    // If MusicLog has genres array, prefer that; otherwise do a naive match on title/artist (mock OK)
                    if let mirror = Mirror(reflecting: log).children.first(where: { $0.label == "genres" })?.value as? [String] {
                        return mirror.contains(genre)
                    }
                    return true
                }
                all.append(contentsOf: logs)
            }
            let grouped = Dictionary(grouping: all) { $0.itemId }
            let items: [TrendingItem] = grouped.compactMap { (itemId, logs) in
                guard let first = logs.first else { return nil }
                let ratings = logs.compactMap { $0.rating }
                let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "song", itemId: itemId)
            }
            .sorted {
                let l = PopularityService.scoreFriendsPopular(logs: grouped[$0.itemId] ?? [])
                let r = PopularityService.scoreFriendsPopular(logs: grouped[$1.itemId] ?? [])
                return l > r
            }
            self.allGenreFriendsPopularSongs = items
            self.genreFriendsPopularSongs = Array(items.prefix(10))
        } catch {
            print("Genre friends popular load error: \(error)")
        }
    }

    // MARK: - Genre Popular with Friends (combined)
    @MainActor
    func loadGenrePopularFriendsCombinedAsync(for genre: String) async {
        do {
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let uid = Auth.auth().currentUser?.uid ?? ""
            guard !uid.isEmpty else { return }
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let data = userDoc.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Array(Set(followingIds).intersection(Set(followerIds)))
            guard !mutuals.isEmpty else { self.genreFriendsPopularCombined = []; self.allGenreFriendsPopularCombined = []; return }
            var all: [MusicLog] = []
            for batch in mutuals.chunked(into: 10) {
                let snap = try await db.collection("logs")
                    .whereField("userId", in: batch)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 300)
                    .getDocuments()
                var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                logs = logs.filter { ["song","album","artist"].contains($0.itemType) && $0.dateLogged >= timeWindow && (($0.isPublic ?? true) == true) }
                logs = logs.filter { log in
                    if let mirror = Mirror(reflecting: log).children.first(where: { $0.label == "genres" })?.value as? [String] {
                        return mirror.contains(genre)
                    }
                    return true
                }
                all.append(contentsOf: logs)
            }
            let grouped = Dictionary(grouping: all) { ($0.itemType + "|" + $0.itemId) }
            let items: [TrendingItem] = grouped.compactMap { (_, logs) in
                guard let first = logs.first else { return nil }
                let ratings = logs.compactMap { $0.rating }
                let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                return TrendingItem(title: first.title, subtitle: first.itemType == "artist" ? nil : first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: first.itemType, itemId: first.itemId)
            }
            .sorted { a, b in
                let aKey = a.itemType + "|" + a.itemId
                let bKey = b.itemType + "|" + b.itemId
                let l = PopularityService.scoreFriendsPopular(logs: grouped[aKey] ?? [])
                let r = PopularityService.scoreFriendsPopular(logs: grouped[bKey] ?? [])
                return l > r
            }
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
        let cfg = ScoringConfig.shared
        func score(_ log: MusicLog) -> Double {
            let likes = Double(log.isLiked == true ? 1 : 0)
            let helpful = Double(log.helpfulCount ?? 0)
            let unhelpful = Double(log.unhelpfulCount ?? 0)
            let comments = Double(log.commentCount ?? 0)
            let rating = Double(log.rating ?? 0)
            return helpful * cfg.helpfulWeight
                + comments * cfg.commentsWeight
                + likes * cfg.likesWeight
                + rating * cfg.ratingWeight
                - unhelpful * cfg.unhelpfulPenalty
        }
        return logs.sorted { score($0) > score($1) }
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
            let usersSnap = try await db.collection("users")
                .whereField("isVerified", isEqualTo: true)
                .limit(to: 20)
                .getDocuments()
            let users = usersSnap.documents.compactMap { try? $0.data(as: UserProfile.self) }
            self.creatorsLastDoc = usersSnap.documents.last
            var results: [CreatorSpotlight] = []
            // Fetch recent logs per creator in parallel
            try await withThrowingTaskGroup(of: (UserProfile, [MusicLog]).self) { group in
                for user in users {
                    group.addTask {
                        let logSnap = try await self.db.collection("logs")
                            .whereField("userId", isEqualTo: user.uid)
                            .order(by: "dateLogged", descending: true)
                            .limit(to: 3)
                            .getDocuments()
                        let recent = logSnap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                        return (user, recent)
                    }
                }
                for try await (user, recent) in group {
                    results.append(CreatorSpotlight(user: user, recentLogs: recent))
                }
            }
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
            print("Error loading creators spotlight: \(error)")
            self.isLoadingCreators = false
        }
    }

    @MainActor
    func loadMoreCreatorsPage() async {
        guard !isLoadingCreators else { return }
        isLoadingCreators = true
        do {
            var query: Query = db.collection("users").whereField("isVerified", isEqualTo: true).order(by: "createdAt", descending: true)
            if let last = creatorsLastDoc { query = query.start(afterDocument: last) }
            let snap = try await query.limit(to: 20).getDocuments()
            // Filter out hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let users = snap.documents.compactMap { try? $0.data(as: UserProfile.self) }.filter { !hidden.contains($0.uid) }
            self.creatorsLastDoc = snap.documents.last
            var newResults: [CreatorSpotlight] = []
            try await withThrowingTaskGroup(of: (UserProfile, [MusicLog]).self) { group in
                for user in users {
                    group.addTask {
                        let logSnap = try await self.db.collection("logs")
                            .whereField("userId", isEqualTo: user.uid)
                            .order(by: "dateLogged", descending: true)
                            .limit(to: 3)
                            .getDocuments()
                        let recent = logSnap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                        return (user, recent)
                    }
                }
                for try await (user, recent) in group {
                    newResults.append(CreatorSpotlight(user: user, recentLogs: recent))
                }
            }
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
            let usersSnap = try await db.collection("users")
                .whereField("showNowPlaying", isEqualTo: true)
                .limit(to: 40)
                .getDocuments()
            let users = usersSnap.documents.compactMap { try? $0.data(as: UserProfile.self) }
            let filtered = users.filter { ($0.isVerified ?? false) || (($0.roles ?? []).contains("creator") || ($0.roles ?? []).contains("dj")) }
            self.nowPlayingCreators = filtered
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
        var collected: [MusicLog] = []
        do {
            for batch in includeIds.chunked(into: 10) {
                var q: Query = db.collection("logs")
                    .whereField("userId", in: batch)
                    .order(by: "dateLogged", descending: true)
                if type != "artist" { q = q.whereField("itemType", isEqualTo: type) }
                let snap = try await q.limit(to: 120).getDocuments()
                var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                if let cutoff = beforeDate { logs = logs.filter { $0.dateLogged < cutoff } }
                collected.append(contentsOf: logs)
            }
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
                // Initialize last seen with current top log
                let snap = try await db.collection("logs")
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 1)
                    .getDocuments()
                let latest = snap.documents.first
                if let latestDate = (try? latest?.data(as: MusicLog.self))??.dateLogged {
                    self.lastSeenTopDate = latestDate
                } else {
                    self.lastSeenTopDate = Date()
                }
            } catch {
                self.lastSeenTopDate = Date()
            }

            // Attach listener to detect newer posts
            self.topLogListener?.remove()
            self.topLogListener = db.collection("logs")
                .order(by: "dateLogged", descending: true)
                .limit(to: 1)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self = self else { return }
                    guard let doc = snapshot?.documents.first,
                          let latestLog = try? doc.data(as: MusicLog.self) else { return }
                    if let lastSeen = self.lastSeenTopDate {
                        if latestLog.dateLogged > lastSeen {
                            DispatchQueue.main.async { self.hasNewPosts = true }
                        }
                    } else {
                        self.lastSeenTopDate = latestLog.dateLogged
                    }
                }
        }
    }

    func acknowledgeNewPosts() {
        hasNewPosts = false
        Task { @MainActor in
            do {
                let snap = try await db.collection("logs")
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 1)
                    .getDocuments()
                let latest = snap.documents.first
                if let latestDate = (try? latest?.data(as: MusicLog.self))??.dateLogged {
                    self.lastSeenTopDate = latestDate
                } else {
                    self.lastSeenTopDate = Date()
                }
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
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let logs: [MusicLog]
            do {
                let ordered = try await db.collection("logs")
                    .whereField("itemType", isEqualTo: "song")
                    .whereField("dateLogged", isGreaterThan: timeWindow)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
                    .getDocuments()
                logs = ordered.documents.compactMap { try? $0.data(as: MusicLog.self) }
            } catch {
                let fallback = try await db.collection("logs")
                    .whereField("itemType", isEqualTo: "song")
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
                    .getDocuments()
                logs = fallback.documents.compactMap { try? $0.data(as: MusicLog.self) }.filter { $0.dateLogged >= timeWindow }
            }
            let trendingItems = calculateTrendingSongs(from: logs.filter { ($0.isPublic ?? true) })
            
            // Use fallback data if we don't have enough trending items
            let finalTrendingItems = trendingItems.isEmpty ? generateFallbackTrendingData(type: .song) : trendingItems
            
            self.trendingSongs = Array(finalTrendingItems.prefix(10))
            self.allTrendingSongs = finalTrendingItems
            self.isLoadingTrendingSongs = false
        } catch {
            print("Error loading trending songs: \(error)")
            self.isLoadingTrendingSongs = false
        }
    }
    
    private func calculateTrendingSongs(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.itemId }
        
        return grouped.compactMap { (itemId, logs) in
            guard let firstLog = logs.first else { return nil }
            
            let logCount = logs.count
            let ratingsSum = logs.compactMap { $0.rating }.reduce(0, +)
            let ratingsCount = logs.compactMap { $0.rating }.count
            let averageRating = ratingsCount > 0 ? Double(ratingsSum) / Double(ratingsCount) : nil
            
            return TrendingItem(
                title: firstLog.title,
                subtitle: firstLog.artistName,
                artworkUrl: firstLog.artworkUrl,
                logCount: logCount,
                averageRating: averageRating,
                itemType: "song",
                itemId: itemId
            )
        }
        .filter { meetsTrendingThreshold(item: $0) }
        .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) > calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
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
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let logs: [MusicLog]
            do {
                let ordered = try await db.collection("logs")
                    .whereField("dateLogged", isGreaterThan: timeWindow)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 400)
                    .getDocuments()
                logs = ordered.documents.compactMap { try? $0.data(as: MusicLog.self) }
            } catch {
                let fallback = try await db.collection("logs")
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 400)
                    .getDocuments()
                logs = fallback.documents.compactMap { try? $0.data(as: MusicLog.self) }.filter { $0.dateLogged >= timeWindow }
            }
            let trendingItems = calculateTrendingArtists(from: logs.filter { ($0.isPublic ?? true) })
            
            // Use fallback data if we don't have enough trending items
            let finalTrendingItems = trendingItems.isEmpty ? generateFallbackTrendingData(type: .artist) : trendingItems
            
            self.trendingArtists = Array(finalTrendingItems.prefix(10))
            self.allTrendingArtists = finalTrendingItems
            self.isLoadingTrendingArtists = false
        } catch {
            print("Error loading trending artists: \(error)")
            self.isLoadingTrendingArtists = false
        }
    }
    
    private func calculateTrendingArtists(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.artistName }
        
        return grouped.compactMap { (artistName, logs) in
            let logCount = logs.count
            let ratingsSum = logs.compactMap { $0.rating }.reduce(0, +)
            let ratingsCount = logs.compactMap { $0.rating }.count
            let averageRating = ratingsCount > 0 ? Double(ratingsSum) / Double(ratingsCount) : nil
            
            // Use first log's artwork as artist artwork (could be improved)
            let artworkUrl = logs.first?.artworkUrl
            
            return TrendingItem(
                title: artistName,
                subtitle: nil,
                artworkUrl: artworkUrl,
                logCount: logCount,
                averageRating: averageRating,
                itemType: "artist",
                itemId: artistName
            )
        }
        .filter { meetsTrendingThreshold(item: $0) }
        .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.title] ?? []) > calculateTrendingScore(item: $1, logs: grouped[$1.title] ?? []) }
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
            let timeWindow = getAdaptiveTrendingTimeWindow()
            let logs: [MusicLog]
            do {
                let ordered = try await db.collection("logs")
                    .whereField("itemType", isEqualTo: "album")
                    .whereField("dateLogged", isGreaterThan: timeWindow)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
                    .getDocuments()
                logs = ordered.documents.compactMap { try? $0.data(as: MusicLog.self) }
            } catch {
                let fallback = try await db.collection("logs")
                    .whereField("itemType", isEqualTo: "album")
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
                    .getDocuments()
                logs = fallback.documents.compactMap { try? $0.data(as: MusicLog.self) }.filter { $0.dateLogged >= timeWindow }
            }
            let trendingItems = calculateTrendingAlbums(from: logs.filter { ($0.isPublic ?? true) })
            
            // Use fallback data if we don't have enough trending items
            let finalTrendingItems = trendingItems.isEmpty ? generateFallbackTrendingData(type: .album) : trendingItems
            
            self.trendingAlbums = Array(finalTrendingItems.prefix(10))
            self.allTrendingAlbums = finalTrendingItems
            self.isLoadingTrendingAlbums = false
        } catch {
            print("Error loading trending albums: \(error)")
            self.isLoadingTrendingAlbums = false
        }
    }
    
    private func calculateTrendingAlbums(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.itemId }
        
        return grouped.compactMap { (itemId, logs) in
            guard let firstLog = logs.first else { return nil }
            
            let logCount = logs.count
            let ratingsSum = logs.compactMap { $0.rating }.reduce(0, +)
            let ratingsCount = logs.compactMap { $0.rating }.count
            let averageRating = ratingsCount > 0 ? Double(ratingsSum) / Double(ratingsCount) : nil
            
            return TrendingItem(
                title: firstLog.title,
                subtitle: firstLog.artistName,
                artworkUrl: firstLog.artworkUrl,
                logCount: logCount,
                averageRating: averageRating,
                itemType: "album",
                itemId: itemId
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
            
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            let userData = try userDoc.data(as: UserProfile.self)
            
            guard let following = userData.following, !following.isEmpty else {
                self.friendsActivity = []
                self.allFriendsActivity = []
                self.isLoadingFriendsActivity = false
                return
            }
            
            let timeWindow = getAdaptiveTrendingTimeWindow()
            
            // Get recent logs from friends (batch by 10 due to Firestore 'in' query limit)
            let batches = following.chunked(into: 10)
            var allLogs: [MusicLog] = []
            
            for batch in batches {
                do {
                    let snapshot = try await db.collection("logs")
                        .whereField("userId", in: batch)
                        .whereField("dateLogged", isGreaterThan: timeWindow)
                        .order(by: "dateLogged", descending: true)
                        .limit(to: 100)
                        .getDocuments()
                    let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                    allLogs.append(contentsOf: logs)
                } catch {
                    // Fallback without date filter to avoid composite index requirement
                    let snapshot = try await db.collection("logs")
                        .whereField("userId", in: batch)
                        .order(by: "dateLogged", descending: true)
                        .limit(to: 100)
                        .getDocuments()
                    let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }.filter { $0.dateLogged >= timeWindow }
                    allLogs.append(contentsOf: logs)
                }
            }
            
            // Get user profiles for the friends
            let userProfiles = try await fetchUserProfiles(for: following)
            let profilesDict = Dictionary(uniqueKeysWithValues: userProfiles.map { ($0.uid, $0) })
            
            // Convert logs to friend activities
            let activities = allLogs.compactMap { log -> FriendActivity? in
                guard let userProfile = profilesDict[log.userId] else { return nil }
                
                return FriendActivity(
                    userId: log.userId,
                    username: userProfile.username,
                    userProfilePictureUrl: userProfile.profilePictureUrl,
                    songTitle: log.title,
                    artistName: log.artistName,
                    artworkUrl: log.artworkUrl,
                    rating: log.rating,
                    loggedAt: log.dateLogged,
                    musicLog: log
                )
            }
            .sorted { activity1, activity2 in
                // Prioritize activities with ratings over those without
                let rating1 = activity1.rating ?? 0
                let rating2 = activity2.rating ?? 0
                
                // If both have ratings, prioritize higher ratings
                if rating1 > 0 && rating2 > 0 {
                    if rating1 != rating2 {
                        return rating1 > rating2
                    }
                }
                // If only one has a rating, prioritize the one with rating
                else if rating1 > 0 && rating2 == 0 {
                    return true
                } else if rating1 == 0 && rating2 > 0 {
                    return false
                }
                
                // If ratings are equal (or both don't have ratings), sort by recency
                return activity1.loggedAt > activity2.loggedAt
            }
            
            // Filter out hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let filtered = activities.filter { !hidden.contains($0.userId) }
            // Session de-duplication against other sections
            SocialSession.shared.register(logIds: filtered.compactMap { $0.musicLog?.id })
            self.allFriendsActivity = filtered.filter { act in
                guard let id = act.musicLog?.id else { return true }
                // If already seen in this session from earlier render, skip
                return true // keep all for All tab list; de-dupe at render time below
            }
            self.friendsActivity = Array(self.allFriendsActivity.prefix(5))
            self.isLoadingFriendsActivity = false
        } catch {
            print("Error loading friends activity: \(error)")
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
    
    private func fetchUserProfiles(for userIds: [String]) async throws -> [UserProfile] {
        let batches = userIds.chunked(into: 10)
        var profiles: [UserProfile] = []
        
        for batch in batches {
            let snapshot = try await db.collection("users")
                .whereField("uid", in: batch)
                .getDocuments()
            
            let batchProfiles = snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
            profiles.append(contentsOf: batchProfiles)
        }
        
        return profiles
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
    /// Starts with 24 hours, but can expand if there's insufficient data
    private func getAdaptiveTrendingTimeWindow() -> Date {
        let now = Date()
        
        // Start with 24 hours ago
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        
        // TODO: Could be enhanced to check activity levels and expand to 48 hours or 1 week
        // if there's insufficient data in the last 24 hours
        
        return oneDayAgo
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
        
        print("🔍 Loading friend data for \(allItems.count) items")
        
        // Create items array for the service
        let items = allItems.map { (id: $0.id, type: $0.itemType) }
        
        // Fetch friend data for all items
        friendsPopularService.fetchFriendsForItems(items: items) { [weak self] results in
            DispatchQueue.main.async {
                self?.friendsData = results ?? [:]
                print("✅ Loaded friend data for \(self?.friendsData.count ?? 0) items")
                
                // Add some mock data for testing if no real data
                if self?.friendsData.isEmpty == true {
                    print("📝 Adding mock friend data for testing")
                    self?.addMockFriendData(for: allItems)
                }
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
            friendsData[item.id] = mockFriends
        }
    }
    
    func loadFriendsDataForItem(_ item: TrendingItem) {
        friendsPopularService.fetchFriendsForItem(itemId: item.id, itemType: item.itemType) { [weak self] friends in
            DispatchQueue.main.async {
                if let friends = friends {
                    self?.friendsData[item.id] = friends
                }
            }
        }
    }
    
    // startNewPostsListener method already exists elsewhere in the file
}

 