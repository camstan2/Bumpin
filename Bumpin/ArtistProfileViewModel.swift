import Foundation
import SwiftUI
import MusicKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Data Models

struct ArtistCatalogItem: Identifiable, Codable {
    let id: String
    let title: String
    let artistName: String
    let albumName: String?
    let artworkURL: String?
    let itemType: String // "song" or "album"
    let releaseDate: Date?
    let duration: TimeInterval? // For songs
    let trackCount: Int? // For albums
    
    // Rating and popularity data
    var averageRating: Double = 0.0
    var totalRatings: Int = 0
    var totalLogs: Int = 0
    var popularityScore: Double = 0.0
    
    init(from musicResult: MusicSearchResult, releaseDate: Date? = nil, duration: TimeInterval? = nil, trackCount: Int? = nil) {
        self.id = musicResult.id
        self.title = musicResult.title
        self.artistName = musicResult.artistName
        self.albumName = musicResult.albumName
        self.artworkURL = musicResult.artworkURL
        self.itemType = musicResult.itemType
        self.releaseDate = releaseDate
        self.duration = duration
        self.trackCount = trackCount
    }
}

struct ArtistProfileData {
    let artistName: String
    let artworkURL: String?
    var allSongs: [ArtistCatalogItem] = []
    var allAlbums: [ArtistCatalogItem] = []
    var isFullyCached: Bool = false
    var lastUpdated: Date = Date()
    
    // Computed properties for sorted content
    var topSongs: [ArtistCatalogItem] {
        return allSongs.sorted { $0.popularityScore > $1.popularityScore }
    }
    
    var topAlbums: [ArtistCatalogItem] {
        return allAlbums.sorted { $0.popularityScore > $1.popularityScore }
    }
}

// MARK: - Loading States

enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
    case loadingMore
    
    static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded), (.loadingMore, .loadingMore):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Artist Profile View Model

@MainActor
class ArtistProfileViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var artistData: ArtistProfileData
    @Published var loadingState: LoadingState = .idle
    @Published var songsLoadingState: LoadingState = .idle
    @Published var albumsLoadingState: LoadingState = .idle
    
    // Display control
    @Published var displayedSongsCount: Int = 8
    @Published var displayedAlbumsCount: Int = 8
    @Published var showAllSongs: Bool = false
    @Published var showAllAlbums: Bool = false
    
    // Filtering options
    @Published var songsTimeFilter: TimeFilter = .allTime
    @Published var albumsFilter: AlbumFilter = .studioAlbums
    
    // MARK: - Public Properties
    
    let artistName: String
    private let cacheManager = ArtistCacheManager.shared
    private let ratingsCalculator = PopularityCalculator()
    private let db = Firestore.firestore()
    
    // Pagination
    private var songsPageSize: Int = 16
    private var albumsPageSize: Int = 16
    private var hasMoreSongs: Bool = true
    private var hasMoreAlbums: Bool = true
    
    // MARK: - Initialization
    
    init(artistName: String) {
        self.artistName = artistName
        self.artistData = ArtistProfileData(artistName: artistName, artworkURL: nil)
        
        // Setup memory pressure monitoring
        setupMemoryPressureMonitoring()
    }
    
    deinit {
        // Clean up when view model is deallocated
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Performance Optimization Properties
    
    private var isBackgroundLoading = false
    private var lastVisibleSongIndex = 0
    private var lastVisibleAlbumIndex = 0
    private let visibilityThreshold = 3 // Load more when 3 items from the end
    
    // MARK: - Public Methods
    
    func loadArtistProfile() async {
        guard loadingState == .idle else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        loadingState = .loading
        
        do {
            // Try to load from cache first
            if let cachedData = await cacheManager.getCachedArtistData(for: artistName),
               !cachedData.isStale {
                artistData = cachedData
                loadingState = .loaded
                
                let loadTime = CFAbsoluteTimeGetCurrent() - startTime
                print("✅ Artist profile loaded from cache in \(String(format: "%.2f", loadTime))s")
                
                // Track cache hit
                AnalyticsService.shared.logPerformance(
                    event: "artist_profile_cache_hit",
                    duration: loadTime,
                    metadata: ["artist": artistName, "songs_count": artistData.allSongs.count, "albums_count": artistData.allAlbums.count]
                )
                return
            }
            
            // Load fresh data from Apple Music
            let catalogStartTime = CFAbsoluteTimeGetCurrent()
            try await loadFromAppleMusic()
            let catalogLoadTime = CFAbsoluteTimeGetCurrent() - catalogStartTime
            
            // Cache the loaded data
            await cacheManager.cacheArtistData(artistData)
            
            loadingState = .loaded
            
            let totalLoadTime = CFAbsoluteTimeGetCurrent() - startTime
            print("✅ Artist profile loaded fresh in \(String(format: "%.2f", totalLoadTime))s (catalog: \(String(format: "%.2f", catalogLoadTime))s)")
            
            // Track fresh load performance with optimization metrics
            AnalyticsService.shared.logPerformanceMetrics(
                event: "artist_profile_fresh_load",
                metadata: [
                    "artist": artistName,
                    "songs_count": artistData.allSongs.count,
                    "albums_count": artistData.allAlbums.count,
                    "catalog_load_time": catalogLoadTime,
                    "total_load_time": totalLoadTime
                ]
            )
            
        } catch {
            let errorTime = CFAbsoluteTimeGetCurrent() - startTime
            loadingState = .error("Failed to load artist profile: \(error.localizedDescription)")
            
            // Track error
            AnalyticsService.shared.logError(
                event: "artist_profile_load_error",
                error: error.localizedDescription,
                metadata: ["artist": artistName, "load_time": errorTime]
            )
        }
    }
    
    func loadMoreSongs() async {
        guard hasMoreSongs && songsLoadingState != .loadingMore else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let previousCount = displayedSongsCount
        
        songsLoadingState = .loadingMore
        
        let newCount = min(displayedSongsCount + songsPageSize, artistData.allSongs.count)
        
        // Simulate loading delay for better UX (gives time for animations)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        displayedSongsCount = newCount
        hasMoreSongs = newCount < artistData.allSongs.count
        
        songsLoadingState = .loaded
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Track load more action
        AnalyticsService.shared.logLoadMoreAction(
            section: "songs",
            fromCount: previousCount,
            toCount: newCount,
            artistName: artistName
        )
        
        print("📈 Songs loaded more: \(previousCount)→\(newCount) in \(String(format: "%.2f", loadTime))s")
    }
    
    func loadMoreAlbums() async {
        guard hasMoreAlbums && albumsLoadingState != .loadingMore else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let previousCount = displayedAlbumsCount
        
        albumsLoadingState = .loadingMore
        
        let newCount = min(displayedAlbumsCount + albumsPageSize, artistData.allAlbums.count)
        
        // Simulate loading delay for better UX (gives time for animations)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        displayedAlbumsCount = newCount
        hasMoreAlbums = newCount < artistData.allAlbums.count
        
        albumsLoadingState = .loaded
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Track load more action
        AnalyticsService.shared.logLoadMoreAction(
            section: "albums",
            fromCount: previousCount,
            toCount: newCount,
            artistName: artistName
        )
        
        print("📈 Albums loaded more: \(previousCount)→\(newCount) in \(String(format: "%.2f", loadTime))s")
    }
    
    func refreshData() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Clear cache and reload
        await cacheManager.clearCacheForArtist(artistName)
        
        // Reset display counts
        displayedSongsCount = 8
        displayedAlbumsCount = 8
        showAllSongs = false
        showAllAlbums = false
        hasMoreSongs = true
        hasMoreAlbums = true
        
        loadingState = .idle
        await loadArtistProfile()
        
        let refreshTime = CFAbsoluteTimeGetCurrent() - startTime
        print("🔄 Artist profile refreshed in \(String(format: "%.2f", refreshTime))s")
        
        // Track refresh action
        AnalyticsService.shared.logPerformance(
            event: "artist_profile_refresh",
            duration: refreshTime,
            metadata: ["artist": artistName, "cache_cleared": true]
        )
    }
    
    // MARK: - Progressive Loading States
    
    func getLoadingProgress() -> Double {
        switch loadingState {
        case .idle:
            return 0.0
        case .loading:
            return 0.3
        case .loaded:
            return 1.0
        case .error(_):
            return 0.0
        case .loadingMore:
            return 0.8
        }
    }
    
    func getSongsLoadingProgress() -> Double {
        guard totalSongsCount > 0 else { return 1.0 }
        return Double(displayedSongsCount) / Double(totalSongsCount)
    }
    
    func getAlbumsLoadingProgress() -> Double {
        guard totalAlbumsCount > 0 else { return 1.0 }
        return Double(displayedAlbumsCount) / Double(totalAlbumsCount)
    }
    
    // MARK: - Intelligent Preloading
    
    func handleSongVisibility(index: Int) {
        lastVisibleSongIndex = max(lastVisibleSongIndex, index)
        
        // If user is near the end of displayed songs, preload more
        if index >= displayedSongsCount - visibilityThreshold && canLoadMoreSongs && !isBackgroundLoading {
            Task {
                await preloadMoreSongs()
            }
        }
        
        // Preload images for upcoming songs with safe bounds checking
        guard index >= 0 && index < displayedSongs.count else { return }
        
        let endIndex = min(index + 5, displayedSongs.count)
        guard endIndex > index else { return }
        
        let upcomingRange = index..<endIndex
        let upcomingImages = Array(displayedSongs[upcomingRange]).compactMap { $0.artworkURL }
        ArtistImageCache.shared.preloadImages(urls: upcomingImages)
    }
    
    func handleAlbumVisibility(index: Int) {
        lastVisibleAlbumIndex = max(lastVisibleAlbumIndex, index)
        
        // If user is near the end of displayed albums, preload more
        if index >= displayedAlbumsCount - visibilityThreshold && canLoadMoreAlbums && !isBackgroundLoading {
            Task {
                await preloadMoreAlbums()
            }
        }
        
        // Preload images for upcoming albums with safe bounds checking
        guard index >= 0 && index < displayedAlbums.count else { return }
        
        let endIndex = min(index + 4, displayedAlbums.count)
        guard endIndex > index else { return }
        
        let upcomingRange = index..<endIndex
        let upcomingImages = Array(displayedAlbums[upcomingRange]).compactMap { $0.artworkURL }
        ArtistImageCache.shared.preloadImages(urls: upcomingImages)
    }
    
    private func preloadMoreSongs() async {
        guard !isBackgroundLoading else { return }
        isBackgroundLoading = true
        
        let currentCount = displayedSongsCount
        let newCount = min(currentCount + songsPageSize, artistData.allSongs.count)
        
        // Load ratings for the new songs in background
        guard currentCount < artistData.allSongs.count && newCount <= artistData.allSongs.count else { 
            isBackgroundLoading = false
            return 
        }
        
        let newSongIds = Array(artistData.allSongs[currentCount..<newCount]).map { $0.id }
        let ratingsData = await ratingsCalculator.calculateRatingsForItems(newSongIds, itemType: "song")
        
        await MainActor.run {
            applyRatingsToSongs(ratingsData)
            displayedSongsCount = newCount
            hasMoreSongs = newCount < artistData.allSongs.count
            isBackgroundLoading = false
        }
        
        print("🚀 Preloaded \(newCount - currentCount) more songs in background")
    }
    
    private func preloadMoreAlbums() async {
        guard !isBackgroundLoading else { return }
        isBackgroundLoading = true
        
        let currentCount = displayedAlbumsCount
        let newCount = min(currentCount + albumsPageSize, artistData.allAlbums.count)
        
        // Load ratings for the new albums in background
        let newAlbumIds = Array(artistData.allAlbums[currentCount..<newCount]).map { $0.id }
        let ratingsData = await ratingsCalculator.calculateRatingsForItems(newAlbumIds, itemType: "album")
        
        await MainActor.run {
            applyRatingsToAlbums(ratingsData)
            displayedAlbumsCount = newCount
            hasMoreAlbums = newCount < artistData.allAlbums.count
            isBackgroundLoading = false
        }
        
        print("🚀 Preloaded \(newCount - currentCount) more albums in background")
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryPressureMonitoring() {
        // Monitor memory pressure notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
        
        // Monitor app background/foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBackground()
        }
    }
    
    private func handleMemoryPressure() {
        print("⚠️ Memory pressure detected - optimizing artist profile cache")
        
        // Clear non-essential cached data
        Task.detached(priority: .background) {
            // Clear image cache partially
            await ArtistImageCache.shared.clearCache()
            
            // Clear artist cache for non-current artists
            await ArtistCacheManager.shared.performEmergencyCleanup()
        }
        
        // Track memory pressure event
        AnalyticsService.shared.logPerformanceMetrics(
            event: "memory_pressure_handled",
            metadata: ["artist": artistName, "action": "cache_cleanup"]
        )
    }
    
    private func handleAppBackground() {
        // Pause non-essential background loading when app goes to background
        isBackgroundLoading = false
        
        print("📱 App backgrounded - pausing artist profile background loading")
    }
    
    func optimizeForLowMemoryDevice() {
        // Reduce pagination sizes for low-memory devices
        songsPageSize = 8
        albumsPageSize = 8
        
        // Limit display counts
        displayedSongsCount = min(displayedSongsCount, 16)
        displayedAlbumsCount = min(displayedAlbumsCount, 16)
        
        print("🔧 Optimized for low-memory device - reduced pagination sizes")
    }
    
    // MARK: - Device Performance Optimization
    
    func optimizeForDeviceCapabilities() {
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        let memoryUsage = AnalyticsService.shared.getMemoryUsage()
        
        // Detect older devices or high memory usage
        if memoryUsage > 200 || isLowEndDevice() {
            optimizeForLowMemoryDevice()
        }
        
        // Adjust image loading strategy based on device
        if isLowEndDevice() {
            // Use smaller image sizes and reduce concurrent loading
            ArtistImageCache.shared.optimizeForLowEndDevice()
        }
        
        print("📱 Device optimization: \(deviceModel) iOS \(systemVersion) - Memory: \(String(format: "%.1f", memoryUsage))MB")
    }
    
    private func isLowEndDevice() -> Bool {
        // Detect older devices that might need optimization
        let deviceModel = UIDevice.current.model
        let memoryUsage = AnalyticsService.shared.getMemoryUsage()
        
        // Simple heuristic: if memory usage is consistently high, treat as low-end
        return memoryUsage > 150 || ProcessInfo.processInfo.physicalMemory < 3_000_000_000 // Less than 3GB RAM
    }
    
    // MARK: - Deep Linking Support
    

    
    func generateDeepLink(section: ArtistSection) -> URL? {
        let artistSlug = artistName.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        let urlString = "bumpin://artist/\(artistSlug)/\(section.rawValue)"
        return URL(string: urlString)
    }
    
    func generateShareableLink(section: ArtistSection) -> URL? {
        // Generate universal link for sharing
        let artistSlug = artistName.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        let urlString = "https://bumpin.app/artist/\(artistSlug)/\(section.rawValue)"
        return URL(string: urlString)
    }
    
    // MARK: - Filter Management
    
    func updateSongsTimeFilter(_ filter: TimeFilter) {
        songsTimeFilter = filter
        // Reset display count when filter changes
        displayedSongsCount = 8
        
        // Track filter usage
        AnalyticsService.shared.logFilterUsage(
            section: "songs",
            filter: filter.rawValue,
            artistName: artistName
        )
    }
    
    func updateAlbumsFilter(_ filter: AlbumFilter) {
        albumsFilter = filter
        // Reset display count when filter changes
        displayedAlbumsCount = 8
        
        // Track filter usage
        AnalyticsService.shared.logFilterUsage(
            section: "albums", 
            filter: filter.rawValue,
            artistName: artistName
        )
    }
    
    func toggleShowAllSongs() {
        showAllSongs.toggle()
        
        if showAllSongs {
            displayedSongsCount = filteredSongs.count
        } else {
            displayedSongsCount = 8
        }
        
        AnalyticsService.shared.logSectionExpansion(
            section: "songs",
            expanded: showAllSongs,
            artistName: artistName,
            totalItems: filteredSongs.count
        )
    }
    
    func toggleShowAllAlbums() {
        showAllAlbums.toggle()
        
        if showAllAlbums {
            displayedAlbumsCount = filteredAlbums.count
        } else {
            displayedAlbumsCount = 8
        }
        
        AnalyticsService.shared.logSectionExpansion(
            section: "albums",
            expanded: showAllAlbums,
            artistName: artistName,
            totalItems: filteredAlbums.count
        )
    }
    
    // MARK: - Cache Pre-warming
    
    static func preWarmCache(for popularArtists: [String]) {
        Task.detached(priority: .background) {
            for artistName in popularArtists {
                await MainActor.run {
                    let viewModel = ArtistProfileViewModel(artistName: artistName)
                    
                    Task {
                        // Check if already cached
                        if let _ = await viewModel.cacheManager.getCachedArtistData(for: artistName) {
                            return // Skip if already cached
                        }
                        
                        // Load and cache in background
                        await viewModel.loadArtistProfile()
                        print("🔥 Pre-warmed cache for: \(artistName)")
                    }
                }
                
                // Add delay to avoid overwhelming the API
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var displayedSongs: [ArtistCatalogItem] {
        let filtered = filteredSongs
        return Array(filtered.prefix(showAllSongs ? filtered.count : displayedSongsCount))
    }
    
    var displayedAlbums: [ArtistCatalogItem] {
        let filtered = filteredAlbums
        return Array(filtered.prefix(showAllAlbums ? filtered.count : displayedAlbumsCount))
    }
    
    var canLoadMoreSongs: Bool {
        return hasMoreSongs && displayedSongsCount < filteredSongs.count
    }
    
    var canLoadMoreAlbums: Bool {
        return hasMoreAlbums && displayedAlbumsCount < filteredAlbums.count
    }
    
    var totalSongsCount: Int {
        return filteredSongs.count
    }
    
    var totalAlbumsCount: Int {
        return filteredAlbums.count
    }
    
    // MARK: - Private Methods
    
    private var filteredSongs: [ArtistCatalogItem] {
        var songs = artistData.topSongs
        
        // Apply time filter
        if songsTimeFilter == .recent {
            let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            songs = songs.filter { song in
                song.releaseDate ?? Date.distantPast >= sixMonthsAgo
            }
        }
        
        return songs
    }
    
    private var filteredAlbums: [ArtistCatalogItem] {
        var albums = artistData.topAlbums
        
        // Apply album filter
        if albumsFilter == .studioAlbums {
            albums = albums.filter { album in
                let title = album.title.lowercased()
                return !title.contains("single") && 
                       !title.contains("ep") && 
                       !title.contains("remix") &&
                       !title.contains("live")
            }
        }
        
        return albums
    }
    
    private func loadFromAppleMusic() async throws {
        // Search for the artist first with enhanced search
        var artistRequest = MusicCatalogSearchRequest(term: artistName, types: [MusicKit.Artist.self])
        artistRequest.limit = 5 // Get multiple matches to find best one
        
        let artistResponse = try await artistRequest.response()
        
        // Find the best matching artist (exact name match preferred)
        guard let artist = findBestArtistMatch(from: artistResponse.artists) else {
            throw ArtistProfileError.artistNotFound
        }
        
        // Update artist artwork with high-resolution image
        artistData = ArtistProfileData(
            artistName: artistName,
            artworkURL: artist.artwork?.url(width: 512, height: 512)?.absoluteString
        )
        
        // Load comprehensive catalog data concurrently
        async let songsTask = loadComprehensiveSongsFromAppleMusic(for: artist)
        async let albumsTask = loadComprehensiveAlbumsFromAppleMusic(for: artist)
        
        let (songs, albums) = try await (songsTask, albumsTask)
        
        artistData.allSongs = songs
        artistData.allAlbums = albums
        
        // Load ratings with intelligent batching
        await loadRatingsWithBatching()
    }
    
    private func findBestArtistMatch(from artists: MusicItemCollection<MusicKit.Artist>) -> MusicKit.Artist? {
        let searchTermLower = artistName.lowercased()
        
        // First, look for exact matches
        for artist in artists {
            if artist.name.lowercased() == searchTermLower {
                return artist
            }
        }
        
        // Then, look for artists that start with the search term
        for artist in artists {
            if artist.name.lowercased().hasPrefix(searchTermLower) {
                return artist
            }
        }
        
        // Finally, return the first artist if no better match found
        return artists.first
    }
    
    private func loadComprehensiveSongsFromAppleMusic(for artist: MusicKit.Artist) async throws -> [ArtistCatalogItem] {
        var allSongs: [ArtistCatalogItem] = []
        
        // Strategy 1: Direct artist songs search
        do {
            var songsRequest = MusicCatalogSearchRequest(term: "\(artist.name) songs", types: [MusicKit.Song.self])
            songsRequest.limit = 50
            
            let songsResponse = try await songsRequest.response()
            let directSongs = songsResponse.songs.filter { song in
                isExactArtistMatch(song.artistName, targetArtist: artist.name)
            }
            
            allSongs.append(contentsOf: directSongs.map { song in
                createCatalogItem(from: song)
            })
        } catch {
            print("⚠️ Direct songs search failed: \(error)")
        }
        
        // Strategy 2: Search by popular song names + artist
        let popularSongQueries = [
            "\(artist.name) hits",
            "\(artist.name) popular",
            "\(artist.name) best",
            "\(artist.name) top"
        ]
        
        for query in popularSongQueries {
            do {
                var popularRequest = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
                popularRequest.limit = 25
                
                let popularResponse = try await popularRequest.response()
                let popularSongs = popularResponse.songs.filter { song in
                    isExactArtistMatch(song.artistName, targetArtist: artist.name)
                }
                
                for song in popularSongs {
                    let catalogItem = createCatalogItem(from: song)
                    // Avoid duplicates
                    if !allSongs.contains(where: { $0.id == catalogItem.id }) {
                        allSongs.append(catalogItem)
                    }
                }
            } catch {
                print("⚠️ Popular songs search failed for '\(query)': \(error)")
            }
        }
        
        // Remove duplicates and sort by release date (newest first as initial sort)
        let uniqueSongs = Array(Set(allSongs.map { $0.id })).compactMap { id in
            allSongs.first { $0.id == id }
        }
        
        return uniqueSongs.sorted { song1, song2 in
            let date1 = song1.releaseDate ?? Date.distantPast
            let date2 = song2.releaseDate ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private func createCatalogItem(from song: MusicKit.Song) -> ArtistCatalogItem {
        return ArtistCatalogItem(
            from: MusicSearchResult(
                id: song.id.rawValue,
                title: song.title,
                artistName: song.artistName,
                albumName: song.albumTitle ?? "",
                artworkURL: song.artwork?.url(width: 400, height: 400)?.absoluteString,
                itemType: "song",
                popularity: 0
            ),
            releaseDate: song.releaseDate,
            duration: song.duration
        )
    }
    
    private func isExactArtistMatch(_ songArtist: String, targetArtist: String) -> Bool {
        let songArtistLower = songArtist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let targetArtistLower = targetArtist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match
        if songArtistLower == targetArtistLower {
            return true
        }
        
        // Handle featuring cases (e.g., "Artist feat. Someone" should match "Artist")
        if songArtistLower.hasPrefix(targetArtistLower + " feat") ||
           songArtistLower.hasPrefix(targetArtistLower + " ft.") ||
           songArtistLower.hasPrefix(targetArtistLower + " featuring") {
            return true
        }
        
        return false
    }
    
    private func loadComprehensiveAlbumsFromAppleMusic(for artist: MusicKit.Artist) async throws -> [ArtistCatalogItem] {
        var allAlbums: [ArtistCatalogItem] = []
        
        // Strategy 1: Direct albums search
        do {
            var albumsRequest = MusicCatalogSearchRequest(term: "\(artist.name) albums", types: [MusicKit.Album.self])
            albumsRequest.limit = 50
            
            let albumsResponse = try await albumsRequest.response()
            let directAlbums = albumsResponse.albums.filter { album in
                isExactArtistMatch(album.artistName, targetArtist: artist.name)
            }
            
            allAlbums.append(contentsOf: directAlbums.map { album in
                createCatalogItem(from: album)
            })
        } catch {
            print("⚠️ Direct albums search failed: \(error)")
        }
        
        // Strategy 2: Search for discography and studio albums
        let albumQueries = [
            "\(artist.name) discography",
            "\(artist.name) studio albums",
            "\(artist.name) LP"
        ]
        
        for query in albumQueries {
            do {
                var albumRequest = MusicCatalogSearchRequest(term: query, types: [MusicKit.Album.self])
                albumRequest.limit = 25
                
                let albumResponse = try await albumRequest.response()
                let queryAlbums = albumResponse.albums.filter { album in
                    isExactArtistMatch(album.artistName, targetArtist: artist.name)
                }
                
                for album in queryAlbums {
                    let catalogItem = createCatalogItem(from: album)
                    // Avoid duplicates
                    if !allAlbums.contains(where: { $0.id == catalogItem.id }) {
                        allAlbums.append(catalogItem)
                    }
                }
            } catch {
                print("⚠️ Album query search failed for '\(query)': \(error)")
            }
        }
        
        // Remove duplicates and sort by release date (newest first)
        let uniqueAlbums = Array(Set(allAlbums.map { $0.id })).compactMap { id in
            allAlbums.first { $0.id == id }
        }
        
        return uniqueAlbums.sorted { album1, album2 in
            let date1 = album1.releaseDate ?? Date.distantPast
            let date2 = album2.releaseDate ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private func createCatalogItem(from album: MusicKit.Album) -> ArtistCatalogItem {
        return ArtistCatalogItem(
            from: MusicSearchResult(
                id: album.id.rawValue,
                title: album.title,
                artistName: album.artistName,
                albumName: album.title,
                artworkURL: album.artwork?.url(width: 400, height: 400)?.absoluteString,
                itemType: "album",
                popularity: 0
            ),
            releaseDate: album.releaseDate,
            trackCount: album.trackCount
        )
    }
    
    private func loadRatingsWithBatching() async {
        // Intelligent batching: Load ratings for display items first, then background load the rest
        let displaySongIds = Array(artistData.allSongs.prefix(displayedSongsCount)).map { $0.id }
        let displayAlbumIds = Array(artistData.allAlbums.prefix(displayedAlbumsCount)).map { $0.id }
        
        // Priority load: ratings for items that will be displayed immediately
        async let prioritySongsTask = loadRatingsForSpecificItems(displaySongIds, itemType: "song")
        async let priorityAlbumsTask = loadRatingsForSpecificItems(displayAlbumIds, itemType: "album")
        
        let (prioritySongsRatings, priorityAlbumsRatings) = await (prioritySongsTask, priorityAlbumsTask)
        
        // Apply priority ratings immediately
        applyRatingsToSongs(prioritySongsRatings)
        applyRatingsToAlbums(priorityAlbumsRatings)
        
        // Background load: ratings for remaining items
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            // Capture current state values
            let currentSongsCount = await self.displayedSongsCount
            let currentAlbumsCount = await self.displayedAlbumsCount
            let allSongs = await self.artistData.allSongs
            let allAlbums = await self.artistData.allAlbums
            
            let remainingSongIds = Array(allSongs.dropFirst(currentSongsCount)).map { $0.id }
            let remainingAlbumIds = Array(allAlbums.dropFirst(currentAlbumsCount)).map { $0.id }
            
            async let remainingSongsTask = self.loadRatingsForSpecificItems(remainingSongIds, itemType: "song")
            async let remainingAlbumsTask = self.loadRatingsForSpecificItems(remainingAlbumIds, itemType: "album")
            
            let (remainingSongsRatings, remainingAlbumsRatings) = await (remainingSongsTask, remainingAlbumsTask)
            
            await MainActor.run {
                self.applyRatingsToSongs(remainingSongsRatings)
                self.applyRatingsToAlbums(remainingAlbumsRatings)
            }
        }
    }
    
    private func loadRatingsForSpecificItems(_ itemIds: [String], itemType: String) async -> [String: PopularityCalculator.RatingData] {
        guard !itemIds.isEmpty else { return [:] }
        return await ratingsCalculator.calculateRatingsForItems(itemIds, itemType: itemType)
    }
    
    private func applyRatingsToSongs(_ ratingsData: [String: PopularityCalculator.RatingData]) {
        for i in 0..<artistData.allSongs.count {
            let songId = artistData.allSongs[i].id
            if let ratingData = ratingsData[songId] {
                artistData.allSongs[i].averageRating = ratingData.averageRating
                artistData.allSongs[i].totalRatings = ratingData.totalRatings
                artistData.allSongs[i].totalLogs = ratingData.totalLogs
                artistData.allSongs[i].popularityScore = ratingData.popularityScore
            }
        }
    }
    
    private func applyRatingsToAlbums(_ ratingsData: [String: PopularityCalculator.RatingData]) {
        for i in 0..<artistData.allAlbums.count {
            let albumId = artistData.allAlbums[i].id
            if let ratingData = ratingsData[albumId] {
                artistData.allAlbums[i].averageRating = ratingData.averageRating
                artistData.allAlbums[i].totalRatings = ratingData.totalRatings
                artistData.allAlbums[i].totalLogs = ratingData.totalLogs
                artistData.allAlbums[i].popularityScore = ratingData.popularityScore
            }
        }
    }
}

// MARK: - Filter Enums

enum TimeFilter: String, CaseIterable {
    case allTime = "All Time"
    case recent = "Recent"
    
    var icon: String {
        switch self {
        case .allTime: return "clock"
        case .recent: return "clock.badge"
        }
    }
}

enum AlbumFilter: String, CaseIterable {
    case all = "All Releases"
    case studioAlbums = "Studio Albums"
    
    var icon: String {
        switch self {
        case .all: return "rectangle.stack"
        case .studioAlbums: return "opticaldisc"
        }
    }
}

// MARK: - Error Types

enum ArtistProfileError: LocalizedError {
    case artistNotFound
    case networkError
    case ratingsLoadError
    
    var errorDescription: String? {
        switch self {
        case .artistNotFound:
            return "Artist not found in Apple Music catalog"
        case .networkError:
            return "Network connection error"
        case .ratingsLoadError:
            return "Failed to load ratings data"
        }
    }
}

// MARK: - Supporting Classes

class ArtistCacheManager {
    static let shared = ArtistCacheManager()
    private let cacheQueue = DispatchQueue(label: "artist.cache", qos: .background)
    private var cache: [String: ArtistProfileData] = [:]
    private var accessTimes: [String: Date] = [:]
    private let maxCacheSize = 50 // Maximum number of artists to cache
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    private init() {
        // Clean up cache periodically
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.performCacheCleanup()
            }
        }
    }
    
    func getCachedArtistData(for artistName: String) async -> ArtistProfileData? {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                let data = self.cache[artistName]
                
                // Update access time for LRU eviction
                if data != nil {
                    self.accessTimes[artistName] = Date()
                }
                
                continuation.resume(returning: data)
            }
        }
    }
    
    func cacheArtistData(_ data: ArtistProfileData) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                var updatedData = data
                updatedData.isFullyCached = true
                updatedData.lastUpdated = Date()
                
                // Check if we need to evict old entries
                if self.cache.count >= self.maxCacheSize {
                    self.evictLeastRecentlyUsed()
                }
                
                self.cache[data.artistName] = updatedData
                self.accessTimes[data.artistName] = Date()
                continuation.resume()
            }
        }
    }
    
    func clearCacheForArtist(_ artistName: String) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                self.cache.removeValue(forKey: artistName)
                self.accessTimes.removeValue(forKey: artistName)
                continuation.resume()
            }
        }
    }
    
    private func performCacheCleanup() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                let now = Date()
                var expiredKeys: [String] = []
                
                // Find expired entries
                for (artistName, data) in self.cache {
                    if now.timeIntervalSince(data.lastUpdated) > self.cacheExpiration {
                        expiredKeys.append(artistName)
                    }
                }
                
                // Remove expired entries
                for key in expiredKeys {
                    self.cache.removeValue(forKey: key)
                    self.accessTimes.removeValue(forKey: key)
                }
                
                print("🧹 Cache cleanup: Removed \(expiredKeys.count) expired entries")
                continuation.resume()
            }
        }
    }
    
    private func evictLeastRecentlyUsed() {
        guard !accessTimes.isEmpty else { return }
        
        // Find the least recently used entry
        let oldestEntry = accessTimes.min { $0.value < $1.value }
        
        if let oldestArtist = oldestEntry?.key {
            cache.removeValue(forKey: oldestArtist)
            accessTimes.removeValue(forKey: oldestArtist)
            print("🗑️ Evicted LRU cache entry: \(oldestArtist)")
        }
    }
    
    func getCacheStats() -> (count: Int, memoryUsage: String) {
        let count = cache.count
        let estimatedMemoryUsage = count * 100 // Rough estimate in KB
        let memoryString = estimatedMemoryUsage > 1024 ? 
            String(format: "%.1f MB", Double(estimatedMemoryUsage) / 1024.0) :
            "\(estimatedMemoryUsage) KB"
        
        return (count: count, memoryUsage: memoryString)
    }
    
    func performEmergencyCleanup() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                // Keep only the 5 most recently accessed artists
                let sortedByAccess = self.accessTimes.sorted { $0.value > $1.value }
                let toKeep = Array(sortedByAccess.prefix(5)).map { $0.key }
                
                var removedCount = 0
                for (artistName, _) in self.cache {
                    if !toKeep.contains(artistName) {
                        self.cache.removeValue(forKey: artistName)
                        self.accessTimes.removeValue(forKey: artistName)
                        removedCount += 1
                    }
                }
                
                print("🚨 Emergency cache cleanup: Removed \(removedCount) artists, kept \(toKeep.count)")
                continuation.resume()
            }
        }
    }
}

extension ArtistProfileData {
    var isStale: Bool {
        return Date().timeIntervalSince(lastUpdated) > 3600 // 1 hour
    }
}

class PopularityCalculator {
    
    struct RatingData {
        let averageRating: Double
        let totalRatings: Int
        let totalLogs: Int
        let popularityScore: Double
    }
    
    func calculateRatingsForItems(_ itemIds: [String], itemType: String) async -> [String: RatingData] {
        let db = Firestore.firestore()
        var ratingsData: [String: RatingData] = [:]
        
        // Process in batches to avoid Firestore limits
        let batches = itemIds.chunkItems(into: 10)
        
        for batch in batches {
            do {
                let snapshot = try await db.collection("logs")
                    .whereField("itemId", in: batch)
                    .whereField("itemType", isEqualTo: itemType)
                    .getDocuments()
                
                var itemStats: [String: (totalRating: Double, ratingCount: Int, logCount: Int)] = [:]
                
                for document in snapshot.documents {
                    let data = document.data()
                    guard let itemId = data["itemId"] as? String else { continue }
                    
                    var stats = itemStats[itemId] ?? (0, 0, 0)
                    stats.logCount += 1
                    
                    if let rating = data["rating"] as? Int {
                        stats.totalRating += Double(rating)
                        stats.ratingCount += 1
                    }
                    
                    itemStats[itemId] = stats
                }
                
                // Calculate final ratings and popularity scores
                for (itemId, stats) in itemStats {
                    let averageRating = stats.ratingCount > 0 ? stats.totalRating / Double(stats.ratingCount) : 0.0
                    let popularityScore = calculatePopularityScore(
                        averageRating: averageRating,
                        totalRatings: stats.ratingCount,
                        totalLogs: stats.logCount
                    )
                    
                    ratingsData[itemId] = RatingData(
                        averageRating: averageRating,
                        totalRatings: stats.ratingCount,
                        totalLogs: stats.logCount,
                        popularityScore: popularityScore
                    )
                }
                
            } catch {
                print("Error loading ratings for batch: \(error)")
            }
        }
        
        return ratingsData
    }
    
    private func calculatePopularityScore(averageRating: Double, totalRatings: Int, totalLogs: Int) -> Double {
        // Enhanced popularity algorithm with multiple factors
        let ratingQualityWeight = 0.4
        let ratingQuantityWeight = 0.25
        let totalEngagementWeight = 0.25
        let recencyWeight = 0.1
        
        // 1. Rating Quality Score (0-1): How good the ratings are
        let ratingQualityScore = averageRating / 5.0
        
        // 2. Rating Quantity Score (0-1): How many people rated it
        // Use sigmoid function to prevent outliers from dominating
        let ratingQuantityScore = sigmoid(Double(totalRatings), midpoint: 50, steepness: 0.1)
        
        // 3. Total Engagement Score (0-1): Overall user interaction
        // Includes all logs (ratings + non-rating logs)
        let engagementScore = sigmoid(Double(totalLogs), midpoint: 100, steepness: 0.05)
        
        // 4. Recency Bonus (0-1): Boost for recently active items
        // This would need release date or last activity data to implement fully
        let recencyScore = 0.5 // Placeholder - would calculate based on recent activity
        
        // Combine all factors
        let popularityScore = (ratingQualityScore * ratingQualityWeight) +
                            (ratingQuantityScore * ratingQuantityWeight) +
                            (engagementScore * totalEngagementWeight) +
                            (recencyScore * recencyWeight)
        
        return min(popularityScore, 1.0)
    }
    
    private func sigmoid(_ x: Double, midpoint: Double, steepness: Double) -> Double {
        return 1.0 / (1.0 + exp(-steepness * (x - midpoint)))
    }
}

// MARK: - Array Extension for Chunking
// Note: Only define if not already defined elsewhere in the project

private extension Array {
    func chunkItems(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Analytics Extensions

extension AnalyticsService {
    func logPerformance(event: String, duration: CFAbsoluteTime, metadata: [String: Any] = [:]) {
        var props = metadata
        props["duration_seconds"] = duration
        props["performance_category"] = "artist_profile"
        
        // Log performance event (you may want to implement this in your AnalyticsService)
        print("📊 Performance: \(event) - \(String(format: "%.3f", duration))s - \(metadata)")
    }
    
    func logError(event: String, error: String, metadata: [String: Any] = [:]) {
        var props = metadata
        props["error_message"] = error
        props["error_category"] = "artist_profile"
        
        // Log error event
        print("❌ Error: \(event) - \(error) - \(metadata)")
    }
    
    func logFilterUsage(section: String, filter: String, artistName: String) {
        print("🔍 Filter: \(section) - \(filter) - Artist: \(artistName)")
        // Implement actual analytics tracking here
    }
    
    func logSectionExpansion(section: String, expanded: Bool, artistName: String, totalItems: Int) {
        print("📂 Section \(expanded ? "Expanded" : "Collapsed"): \(section) - Artist: \(artistName) - Items: \(totalItems)")
        // Implement actual analytics tracking here
    }
    
    func logLoadMoreAction(section: String, fromCount: Int, toCount: Int, artistName: String) {
        print("📈 Load More: \(section) - \(fromCount)→\(toCount) - Artist: \(artistName)")
        // Implement actual analytics tracking here
    }
    
    func logSeeAllNavigation(section: String, totalItems: Int, artistName: String) {
        print("🔗 See All: \(section) - \(totalItems) items - Artist: \(artistName)")
        // Implement actual analytics tracking here
    }
    
    func logShare(contentType: String, contentId: String, method: String) {
        print("📤 Share: \(contentType) - \(contentId) - Method: \(method)")
        // Implement actual analytics tracking here
    }
    
    func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
    }
    
    func logPerformanceMetrics(event: String, metadata: [String: Any] = [:]) {
        var props = metadata
        props["performance_category"] = "artist_profile_optimization"
        
        // Add memory usage info
        let memoryUsage = AnalyticsService.shared.getMemoryUsage()
        props["memory_usage_mb"] = memoryUsage
        
        // Add cache stats (simplified to avoid MainActor issues)
        props["cache_optimization"] = "enabled"
        
        print("📊 Performance: \(event) - Memory: \(memoryUsage)MB - Cache: Optimized")
    }
}

// MARK: - Deep Linking Models

struct ArtistDeepLink {
    let artistName: String
    let section: ArtistSection
}

enum ArtistSection: String, CaseIterable {
    case profile = "profile"
    case songs = "songs"
    case albums = "albums"
    
    var displayName: String {
        switch self {
        case .profile: return "Profile"
        case .songs: return "Songs"
        case .albums: return "Albums"
        }
    }
    
    var icon: String {
        switch self {
        case .profile: return "person.circle"
        case .songs: return "music.note"
        case .albums: return "opticaldisc"
        }
    }
}

// MARK: - Deep Link Handler Extension

extension DeepLinkParser {
    /// Parse artist profile deep links: bumpin://artist/travis-scott/songs
    static func parseArtistLink(from url: URL) -> ArtistDeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return nil }
        
        // Support URLs like: bumpin://artist/travis-scott/songs or bumpin://artist/taylor-swift/albums
        let pathComponents = components.path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        if host == "artist" && pathComponents.count >= 1 {
            let artistName = pathComponents[0].replacingOccurrences(of: "-", with: " ")
            let section = pathComponents.count > 1 ? pathComponents[1] : "profile"
            
            return ArtistDeepLink(
                artistName: artistName,
                section: ArtistSection(rawValue: section) ?? .profile
            )
        }
        
        return nil
    }
    
    /// Parse universal artist links: https://bumpin.app/artist/travis-scott/albums
    @MainActor
    static func parseUniversalArtistLink(from url: URL) -> ArtistDeepLink? {
        guard let host = url.host, AppConfig.shared.isAllowedUniversalLinkHost(host) else { return nil }
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        if pathComponents.count >= 2 && pathComponents[0].lowercased() == "artist" {
            let artistName = pathComponents[1].replacingOccurrences(of: "-", with: " ")
            let section = pathComponents.count > 2 ? pathComponents[2] : "profile"
            
            return ArtistDeepLink(
                artistName: artistName,
                section: ArtistSection(rawValue: section) ?? .profile
            )
        }
        
        return nil
    }
}
