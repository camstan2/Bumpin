import Foundation
import MusicKit
import MediaPlayer
import SwiftUI

// MARK: - Apple Music Library Service
@MainActor
class AppleMusicLibraryService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authorizationStatus: MusicAuthorization.Status = .notDetermined
    
    // Library content
    @Published var recentlyAdded: [LibraryItem] = []
    @Published var recentlyAddedSongs: [LibraryItem] = []
    @Published var allPlaylists: [LibraryPlaylist] = []  // All playlists (for management)
    @Published var userPlaylists: [LibraryPlaylist] = [] // Legacy support
    @Published var enabledPlaylists: [LibraryPlaylist] = [] // Primary filtered playlists
    @Published var librarySongs: [LibraryItem] = []
    @Published var libraryArtists: [LibraryItem] = []
    @Published var libraryAlbums: [LibraryItem] = []
    
    // Search results
    @Published var searchResults: [LibraryItem] = []
    @Published var isSearching = false
    
    // Playlist toggle system
    @Published var selectedPlaylistIds: Set<String> = []
    
    // Cache for performance
    private var libraryCache: [String: [LibraryItem]] = [:]
    private var lastCacheUpdate: Date?
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Singleton
    static let shared = AppleMusicLibraryService()
    
    private init() {
        checkAuthorizationStatus()
        loadPlaylistSelection()
        loadPlaylistPlayHistory()
    }
    
    // MARK: - Authorization
    func checkAuthorizationStatus() {
        authorizationStatus = MusicAuthorization.currentStatus
    }
    
    func requestAuthorization() async -> MusicAuthorization.Status {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            self.authorizationStatus = status
        }
        return status
    }
    
    // MARK: - Library Loading
    func loadAllLibraryContent() async {
        guard authorizationStatus == .authorized else {
            await MainActor.run {
                self.errorMessage = "Apple Music authorization required"
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        async let recentlyAddedTask = loadRecentlyAdded()
        async let playlistsTask = loadUserPlaylists()
        async let songsTask = loadLibrarySongs()
        async let artistsTask = loadLibraryArtists()
        async let albumsTask = loadLibraryAlbums()
        
        // Load all sections concurrently
        await recentlyAddedTask
        await playlistsTask
        await songsTask
        await artistsTask
        await albumsTask
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Recently Added
    func loadRecentlyAdded() async {
        print("🎵 Starting to load recently added content...")
        
        do {
            // MediaPlayer provides better date sorting than MusicKit for recently added
            // Load songs, albums, and artists
            let songs = await loadRecentlyAddedSongsWithMediaPlayer()
            let albums = await loadRecentlyAddedAlbumsWithMediaPlayer()
            let artists = await loadRecentlyAddedArtistsWithMediaPlayer()
            
            // Combine and sort all items by date added
            let allItems = (songs + albums + artists).sorted { item1, item2 in
                guard let date1 = item1.dateAdded, let date2 = item2.dateAdded else {
                    return false
                }
                return date1 > date2
            }
            
            // Take the most recent 20 items
            let recentItems = Array(allItems.prefix(20))
            
            await MainActor.run {
                self.recentlyAdded = recentItems
                // Also populate songs-only array for the main library view
                self.recentlyAddedSongs = songs.sorted { item1, item2 in
                    guard let date1 = item1.dateAdded, let date2 = item2.dateAdded else {
                        return false
                    }
                    return date1 > date2
                }
                print("✅ Successfully loaded \(recentItems.count) recently added items (songs: \(songs.count), albums: \(albums.count), artists: \(artists.count))")
                print("🎵 Recently added songs: \(self.recentlyAddedSongs.count)")
            }
            
        } catch {
            print("❌ Failed to load recently added: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load recently added: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadRecentlyAddedSongsWithMediaPlayer() async -> [LibraryItem] {
        print("🎵 Loading recently added songs with MediaPlayer...")
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query = MPMediaQuery.songs()
                
                guard let items = query.items else {
                    print("❌ No songs found in MediaPlayer library")
                    continuation.resume(returning: [])
                    return
                }
                
                print("✅ Found \(items.count) total songs in MediaPlayer library")
                
                // Sort by date added (most recent first)
                let sortedItems = items.sorted { item1, item2 in
                    let date1 = item1.dateAdded
                    let date2 = item2.dateAdded
                    return date1 > date2
                }
                
                let recentItems = sortedItems.prefix(50).compactMap { item -> LibraryItem? in
                    guard let title = item.title,
                          let artist = item.artist,
                          !title.isEmpty else { return nil }
                    
                    return LibraryItem(
                        id: String(item.persistentID),
                        title: title,
                        artistName: artist,
                        albumName: item.albumTitle,
                        artworkURL: self.extractArtworkURL(from: item),
                        itemType: .song,
                        dateAdded: item.dateAdded
                    )
                }
                
                print("🎵 Created \(recentItems.count) recently added songs")
                continuation.resume(returning: Array(recentItems))
            }
        }
    }
    
    private func loadRecentlyAddedAlbumsWithMediaPlayer() async -> [LibraryItem] {
        print("🎵 Loading recently added albums with MediaPlayer...")
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query = MPMediaQuery.albums()
                
                guard let collections = query.collections else {
                    print("❌ No albums found in MediaPlayer library")
                    continuation.resume(returning: [])
                    return
                }
                
                // Get unique albums with their date added (use most recent song's date)
                var albumDict: [String: (collection: MPMediaItemCollection, dateAdded: Date)] = [:]
                
                for collection in collections {
                    guard let representativeItem = collection.representativeItem,
                          let albumTitle = representativeItem.albumTitle,
                          let artistName = representativeItem.albumArtist ?? representativeItem.artist,
                          !albumTitle.isEmpty else { continue }
                    
                    let albumKey = "\(albumTitle.lowercased())|\(artistName.lowercased())"
                    
                    // Use the most recent song's date as the album's date
                    let mostRecentDate = collection.items.compactMap { $0.dateAdded }.max() ?? representativeItem.dateAdded
                    
                    if let existingEntry = albumDict[albumKey] {
                        // Keep the one with the more recent date
                        if mostRecentDate > existingEntry.dateAdded {
                            albumDict[albumKey] = (collection, mostRecentDate)
                        }
                    } else {
                        albumDict[albumKey] = (collection, mostRecentDate)
                    }
                }
                
                // Sort by date and take recent albums
                let sortedAlbums = albumDict.values.sorted { $0.dateAdded > $1.dateAdded }
                
                let recentAlbums = sortedAlbums.prefix(5).compactMap { entry -> LibraryItem? in
                    guard let representativeItem = entry.collection.representativeItem,
                          let albumTitle = representativeItem.albumTitle,
                          let artistName = representativeItem.albumArtist ?? representativeItem.artist else { return nil }
                    
                    return LibraryItem(
                        id: String(representativeItem.albumPersistentID),
                        title: albumTitle,
                        artistName: artistName,
                        albumName: albumTitle,
                        artworkURL: self.extractArtworkURL(from: representativeItem),
                        itemType: .album,
                        dateAdded: entry.dateAdded
                    )
                }
                
                print("🎵 Created \(recentAlbums.count) recently added albums")
                continuation.resume(returning: Array(recentAlbums))
            }
        }
    }
    
    private func loadRecentlyAddedArtistsWithMediaPlayer() async -> [LibraryItem] {
        print("🎵 Loading recently added artists with MediaPlayer...")
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query = MPMediaQuery.artists()
                
                guard let collections = query.collections else {
                    print("❌ No artists found in MediaPlayer library")
                    continuation.resume(returning: [])
                    return
                }
                
                // Get unique artists with their most recent addition date
                var artistDict: [String: (collection: MPMediaItemCollection, dateAdded: Date)] = [:]
                
                for collection in collections {
                    guard let representativeItem = collection.representativeItem,
                          let artistName = representativeItem.artist,
                          !artistName.isEmpty else { continue }
                    
                    let artistKey = artistName.lowercased()
                    
                    // Use the most recent song's date as the artist's date
                    let mostRecentDate = collection.items.compactMap { $0.dateAdded }.max() ?? representativeItem.dateAdded
                    
                    if let existingEntry = artistDict[artistKey] {
                        // Keep the one with the more recent date
                        if mostRecentDate > existingEntry.dateAdded {
                            artistDict[artistKey] = (collection, mostRecentDate)
                        }
                    } else {
                        artistDict[artistKey] = (collection, mostRecentDate)
                    }
                }
                
                // Sort by date and take recent artists
                let sortedArtists = artistDict.values.sorted { $0.dateAdded > $1.dateAdded }
                
                let recentArtists = sortedArtists.prefix(5).compactMap { entry -> LibraryItem? in
                    guard let representativeItem = entry.collection.representativeItem,
                          let artistName = representativeItem.artist else { return nil }
                    
                    return LibraryItem(
                        id: String(representativeItem.artistPersistentID),
                        title: artistName,
                        artistName: artistName,
                        albumName: nil,
                        artworkURL: self.extractArtworkURL(from: representativeItem),
                        itemType: .artist,
                        dateAdded: entry.dateAdded
                    )
                }
                
                print("🎵 Created \(recentArtists.count) recently added artists")
                continuation.resume(returning: Array(recentArtists))
            }
        }
    }
    
    // MARK: - User Playlists
    func loadUserPlaylists() async {
        do {
            // Try MusicKit first - include tracks relationship to get song counts
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 100
            let response = try await request.response()
            
            // Load playlists with tracks relationship to get accurate song counts
            var playlistsWithTracks: [Playlist] = []
            for playlist in response.items {
                do {
                    let playlistWithTracks = try await playlist.with(.tracks)
                    playlistsWithTracks.append(playlistWithTracks)
                } catch {
                    // If loading tracks fails, use the original playlist with 0 count
                    print("⚠️ Failed to load tracks for playlist \(playlist.name): \(error)")
                    playlistsWithTracks.append(playlist)
                }
            }
            
            let playlists = playlistsWithTracks.map { playlist in
                // Get song count from tracks if available
                let songCount = playlist.tracks?.count ?? 0
                print("🎵 Playlist '\(playlist.name)' has \(songCount) tracks")
                
                // Filter out problematic descriptions that contain playlist object info
                let cleanDescription: String? = {
                    let desc = playlist.description
                    // If description contains "Playlist(id:" it's the object string, not real description
                    if desc.contains("Playlist(id:") || desc.contains("playlist.") {
                        return nil
                    }
                    return desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : desc
                }()
                
                return LibraryPlaylist(
                    id: playlist.id.rawValue,
                    name: playlist.name,
                    description: cleanDescription,
                    artworkURL: playlist.artwork?.url(width: 300, height: 300)?.absoluteString,
                    songCount: songCount,
                    curatorName: playlist.curatorName,
                    isUserCreated: true
                )
            }
            
            await MainActor.run {
                self.allPlaylists = playlists
                self.userPlaylists = playlists // Legacy support
                
                // Smart initialization for first-time users
                if self.selectedPlaylistIds.isEmpty {
                    self.selectedPlaylistIds = self.getSmartDefaultSelection(for: playlists)
                    self.savePlaylistSelection()
                }
                self.updateEnabledPlaylists()
                
                // Seed test play history for demonstration (only if no history exists)
                self.seedTestPlayHistory()
            }
            
        } catch {
            // Fallback to MediaPlayer
            let playlists = await loadPlaylistsWithMediaPlayer()
            await MainActor.run {
                self.allPlaylists = playlists
                self.userPlaylists = playlists // Legacy support
                
                // Smart initialization for first-time users
                if self.selectedPlaylistIds.isEmpty {
                    self.selectedPlaylistIds = self.getSmartDefaultSelection(for: playlists)
                    self.savePlaylistSelection()
                }
                self.updateEnabledPlaylists()
                
                // Seed test play history for demonstration (only if no history exists)
                self.seedTestPlayHistory()
            }
        }
    }
    
    // MARK: - Playlist Toggle Management
    func togglePlaylistSelection(_ playlistId: String) {
        if selectedPlaylistIds.contains(playlistId) {
            selectedPlaylistIds.remove(playlistId)
        } else {
            selectedPlaylistIds.insert(playlistId)
        }
        updateEnabledPlaylists()
        savePlaylistSelection()
    }
    
    func isPlaylistSelected(_ playlistId: String) -> Bool {
        return selectedPlaylistIds.contains(playlistId)
    }
    
    private func updateEnabledPlaylists() {
        enabledPlaylists = allPlaylists.filter { selectedPlaylistIds.contains($0.id) }
        // Keep userPlaylists in sync for legacy support
        userPlaylists = enabledPlaylists
    }
    
    private func savePlaylistSelection() {
        UserDefaults.standard.set(Array(selectedPlaylistIds), forKey: "selected_playlist_ids")
    }
    
    private func loadPlaylistSelection() {
        if let savedIds = UserDefaults.standard.array(forKey: "selected_playlist_ids") as? [String] {
            selectedPlaylistIds = Set(savedIds)
        }
    }
    
    // MARK: - Smart Default Selection
    private func getSmartDefaultSelection(for playlists: [LibraryPlaylist]) -> Set<String> {
        // Smart algorithm for first-time playlist selection
        var selectedIds = Set<String>()
        
        for playlist in playlists {
            let shouldEnable = shouldEnablePlaylistByDefault(playlist)
            if shouldEnable {
                selectedIds.insert(playlist.id)
            }
        }
        
        // Ensure at least some playlists are selected (fallback to all if smart selection is too restrictive)
        if selectedIds.count < max(3, playlists.count / 3) {
            selectedIds = Set(playlists.map { $0.id }) // Enable all as fallback
        }
        
        print("🧠 Smart selection: Enabled \(selectedIds.count) of \(playlists.count) playlists")
        return selectedIds
    }
    
    private func shouldEnablePlaylistByDefault(_ playlist: LibraryPlaylist) -> Bool {
        // Smart criteria for auto-enabling playlists
        
        // Always enable if it has a reasonable number of songs (5-500)
        let hasReasonableSongCount = playlist.songCount >= 5 && playlist.songCount <= 500
        
        // Enable if it's recently created (within last 6 months)
        let isRecent = {
            guard let dateAdded = playlist.dateAdded else { return false }
            let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            return dateAdded > sixMonthsAgo
        }()
        
        // Enable if it's user-created (not Apple Music playlists)
        let isUserCreated = playlist.isUserCreated
        
        // Disable very large playlists for performance
        let isTooLarge = playlist.songCount > 500
        
        // Disable empty playlists
        let isEmpty = playlist.songCount == 0
        
        // Final decision
        if isEmpty || isTooLarge {
            return false
        }
        
        return hasReasonableSongCount || isRecent || isUserCreated
    }
    
    // MARK: - Performance Analytics
    func getPerformanceMetrics() -> (totalSongs: Int, enabledSongs: Int, disabledSongs: Int, memorySavingsMB: Int) {
        let enabledSongs = enabledPlaylists.reduce(0) { $0 + $1.songCount }
        let disabledPlaylists = allPlaylists.filter { !selectedPlaylistIds.contains($0.id) }
        let disabledSongs = disabledPlaylists.reduce(0) { $0 + $1.songCount }
        let totalSongs = enabledSongs + disabledSongs
        
        // Rough estimate: ~1KB per song for metadata
        let memorySavingsMB = disabledSongs / 1000
        
        return (totalSongs: totalSongs, enabledSongs: enabledSongs, disabledSongs: disabledSongs, memorySavingsMB: memorySavingsMB)
    }
    
    // MARK: - Recently Played Tracking
    func markPlaylistAsPlayed(_ playlistId: String) {
        // Update the playlist's last played date
        if let index = allPlaylists.firstIndex(where: { $0.id == playlistId }) {
            let playlistName = allPlaylists[index].name
            allPlaylists[index].lastPlayedDate = Date()
            
            // Update enabled playlists to maintain sync
            updateEnabledPlaylists()
            
            // Save to persistent storage
            savePlaylistPlayHistory()
            
            print("🎵 Marked playlist '\(playlistName)' as played at \(Date())")
            print("🔍 Debug: Playlist now has lastPlayedDate: \(allPlaylists[index].lastPlayedDate?.description ?? "nil")")
        } else {
            print("❌ Could not find playlist with ID: \(playlistId)")
        }
    }
    
    private func savePlaylistPlayHistory() {
        // Save playlist play history to UserDefaults
        let playHistory = allPlaylists.compactMap { playlist -> [String: Any]? in
            guard let lastPlayed = playlist.lastPlayedDate else { return nil }
            return [
                "id": playlist.id,
                "lastPlayedDate": lastPlayed.timeIntervalSince1970
            ]
        }
        UserDefaults.standard.set(playHistory, forKey: "playlist_play_history")
    }
    
    private func loadPlaylistPlayHistory() {
        guard let historyData = UserDefaults.standard.array(forKey: "playlist_play_history") as? [[String: Any]] else {
            return
        }
        
        // Create a dictionary for quick lookup
        var playHistoryDict: [String: Date] = [:]
        for entry in historyData {
            if let id = entry["id"] as? String,
               let timestamp = entry["lastPlayedDate"] as? TimeInterval {
                playHistoryDict[id] = Date(timeIntervalSince1970: timestamp)
            }
        }
        
        // Update playlists with play history
        for i in 0..<allPlaylists.count {
            if let lastPlayed = playHistoryDict[allPlaylists[i].id] {
                allPlaylists[i].lastPlayedDate = lastPlayed
            }
        }
        
        // Update enabled playlists as well
        updateEnabledPlaylists()
        
        print("📊 Loaded \(playHistoryDict.count) playlist play history entries")
    }
    
    // MARK: - Debug Helper (for testing recently played functionality)
    func seedTestPlayHistory() {
        // Only seed if we don't have any play history yet
        let hasPlayHistory = allPlaylists.contains { $0.lastPlayedDate != nil }
        
        if !hasPlayHistory && allPlaylists.count >= 3 {
            print("🧪 Seeding test play history for demonstration...")
            
            // Mark a few playlists as played at different times
            if allPlaylists.count > 0 {
                // Most recent (5 minutes ago)
                allPlaylists[0].lastPlayedDate = Date().addingTimeInterval(-300)
                print("🎵 Seeded: '\(allPlaylists[0].name)' played 5 minutes ago")
            }
            
            if allPlaylists.count > 2 {
                // 1 hour ago
                allPlaylists[2].lastPlayedDate = Date().addingTimeInterval(-3600)
                print("🎵 Seeded: '\(allPlaylists[2].name)' played 1 hour ago")
            }
            
            if allPlaylists.count > 1 {
                // 1 day ago
                allPlaylists[1].lastPlayedDate = Date().addingTimeInterval(-86400)
                print("🎵 Seeded: '\(allPlaylists[1].name)' played 1 day ago")
            }
            
            // Update enabled playlists and save
            updateEnabledPlaylists()
            savePlaylistPlayHistory()
            
            print("✅ Test play history seeded successfully")
        }
    }
    
    func getOptimizationSuggestions() -> [PlaylistOptimizationSuggestion] {
        var suggestions: [PlaylistOptimizationSuggestion] = []
        
        for playlist in allPlaylists {
            let isEnabled = selectedPlaylistIds.contains(playlist.id)
            
            // Suggest disabling large playlists
            if isEnabled && playlist.songCount > 500 {
                suggestions.append(PlaylistOptimizationSuggestion(
                    playlist: playlist,
                    type: .disableLarge,
                    reason: "Large playlist (\(playlist.songCount) songs) may slow down search"
                ))
            }
            
            // Suggest disabling empty playlists
            if isEnabled && playlist.songCount == 0 {
                suggestions.append(PlaylistOptimizationSuggestion(
                    playlist: playlist,
                    type: .disableEmpty,
                    reason: "Empty playlist provides no content"
                ))
            }
            
            // Suggest enabling recently created playlists
            if !isEnabled && playlist.songCount > 0 {
                if let dateAdded = playlist.dateAdded {
                    let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                    if dateAdded > oneMonthAgo {
                        suggestions.append(PlaylistOptimizationSuggestion(
                            playlist: playlist,
                            type: .enableRecent,
                            reason: "Recently created playlist with \(playlist.songCount) songs"
                        ))
                    }
                }
            }
        }
        
        return suggestions
    }
    
    private func loadPlaylistsWithMediaPlayer() async -> [LibraryPlaylist] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query = MPMediaQuery.playlists()
                
                guard let collections = query.collections else {
                    continuation.resume(returning: [])
                    return
                }
                
                let playlists = collections.compactMap { collection -> LibraryPlaylist? in
                    guard let playlist = collection as? MPMediaPlaylist,
                          let name = playlist.name,
                          !name.isEmpty,
                          playlist.persistentID != MPMediaEntityPersistentID() else {
                        return nil
                    }
                    
                    let songCount = playlist.items.count
                    print("🎵 MediaPlayer Playlist '\(name)' has \(songCount) tracks")
                    
                    return LibraryPlaylist(
                        id: String(playlist.persistentID),
                        name: name,
                        description: nil,
                        artworkURL: self.extractPlaylistArtworkURL(from: playlist),
                        songCount: songCount,
                        curatorName: nil,
                        isUserCreated: true
                    )
                }
                
                continuation.resume(returning: playlists)
            }
        }
    }
    
    // MARK: - Library Songs
    func loadLibrarySongs(limit: Int = 500) async {
        do {
            var request = MusicLibraryRequest<MusicKit.Song>()
            request.limit = limit
            let response = try await request.response()
            
            let songs = response.items.compactMap { song -> LibraryItem? in
                // Skip songs with problematic IDs
                let idString = song.id.rawValue
                if idString.hasPrefix("-") && idString.count > 15 {
                    return nil
                }
                
                return LibraryItem(
                    id: song.id.rawValue,
                    title: song.title,
                    artistName: song.artistName,
                    albumName: song.albumTitle,
                    artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: .song
                )
            }
            
            await MainActor.run {
                self.librarySongs = songs
                self.libraryCache["songs"] = songs
                self.lastCacheUpdate = Date()
            }
            
        } catch {
            // Fallback to MediaPlayer
            let songs = await loadSongsWithMediaPlayer(limit: limit)
            await MainActor.run {
                self.librarySongs = songs
            }
        }
    }
    
    private func loadSongsWithMediaPlayer(limit: Int) async -> [LibraryItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query = MPMediaQuery.songs()
                query.addFilterPredicate(MPMediaPropertyPredicate(value: false, forProperty: MPMediaItemPropertyIsCloudItem))
                
                guard let items = query.items else {
                    continuation.resume(returning: [])
                    return
                }
                
                let songs = items.prefix(limit).compactMap { item -> LibraryItem? in
                    guard let title = item.title,
                          let artist = item.artist,
                          !title.isEmpty else { return nil }
                    
                    return LibraryItem(
                        id: String(item.persistentID),
                        title: title,
                        artistName: artist,
                        albumName: item.albumTitle,
                        artworkURL: self.extractArtworkURL(from: item),
                        itemType: .song
                    )
                }
                
                continuation.resume(returning: Array(songs))
            }
        }
    }
    
    // MARK: - Library Artists
    func loadLibraryArtists(limit: Int = 200) async {
        do {
            var request = MusicLibraryRequest<Artist>()
            request.limit = limit
            let response = try await request.response()
            
            let artists = response.items.map { artist in
                LibraryItem(
                    id: artist.id.rawValue,
                    title: artist.name,
                    artistName: artist.name,
                    albumName: nil,
                    artworkURL: artist.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: .artist
                )
            }
            
            await MainActor.run {
                self.libraryArtists = artists
                self.libraryCache["artists"] = artists
            }
            
        } catch {
            // Fallback to MediaPlayer
            let artists = await loadArtistsWithMediaPlayer(limit: limit)
            await MainActor.run {
                self.libraryArtists = artists
            }
        }
    }
    
    private func loadArtistsWithMediaPlayer(limit: Int) async -> [LibraryItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query = MPMediaQuery.artists()
                
                guard let collections = query.collections else {
                    continuation.resume(returning: [])
                    return
                }
                
                let artists = collections.prefix(limit).compactMap { collection -> LibraryItem? in
                    guard let artist = collection.representativeItem?.artist,
                          !artist.isEmpty else { return nil }
                    
                    return LibraryItem(
                        id: String(collection.persistentID),
                        title: artist,
                        artistName: artist,
                        albumName: nil,
                        artworkURL: self.extractArtworkURL(from: collection.representativeItem),
                        itemType: .artist
                    )
                }
                
                continuation.resume(returning: Array(artists))
            }
        }
    }
    
    // MARK: - Library Albums
    func loadLibraryAlbums(limit: Int = 300) async {
        do {
            var request = MusicLibraryRequest<Album>()
            request.limit = limit
            let response = try await request.response()
            
            let albums = response.items.compactMap { album -> LibraryItem? in
                // Skip albums with problematic IDs
                let idString = album.id.rawValue
                if idString.hasPrefix("-") && idString.count > 15 {
                    return nil
                }
                
                return LibraryItem(
                    id: album.id.rawValue,
                    title: album.title,
                    artistName: album.artistName,
                    albumName: album.title,
                    artworkURL: album.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: .album
                )
            }
            
            await MainActor.run {
                self.libraryAlbums = albums
                self.libraryCache["albums"] = albums
            }
            
        } catch {
            // Fallback to MediaPlayer
            let albums = await loadAlbumsWithMediaPlayer(limit: limit)
            await MainActor.run {
                self.libraryAlbums = albums
            }
        }
    }
    
    private func loadAlbumsWithMediaPlayer(limit: Int) async -> [LibraryItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query = MPMediaQuery.albums()
                
                guard let collections = query.collections else {
                    continuation.resume(returning: [])
                    return
                }
                
                let albums = collections.prefix(limit).compactMap { collection -> LibraryItem? in
                    guard let album = collection.representativeItem?.albumTitle,
                          let artist = collection.representativeItem?.artist,
                          !album.isEmpty else { return nil }
                    
                    return LibraryItem(
                        id: String(collection.persistentID),
                        title: album,
                        artistName: artist,
                        albumName: album,
                        artworkURL: self.extractArtworkURL(from: collection.representativeItem),
                        itemType: .album
                    )
                }
                
                continuation.resume(returning: Array(albums))
            }
        }
    }
    
    // MARK: - Library Search
    func searchLibrary(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
            return
        }
        
        await MainActor.run {
            self.isSearching = true
        }
        
        // Use a combination of MusicKit search and cached library search for better results
        var allResults: [LibraryItem] = []
        
        do {
            // First try MusicKit search for comprehensive results
            var request = MusicLibrarySearchRequest(term: query, types: [MusicKit.Song.self, MusicKit.Artist.self, MusicKit.Album.self])
            request.limit = 30
            
            let response = try await request.response()
            
            // Add songs from MusicKit search
            allResults.append(contentsOf: response.songs.compactMap { song in
                LibraryItem(
                    id: song.id.rawValue,
                    title: song.title,
                    artistName: song.artistName,
                    albumName: song.albumTitle,
                    artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: .song
                )
            })
            
            // Add artists from MusicKit search
            allResults.append(contentsOf: response.artists.map { artist in
                LibraryItem(
                    id: artist.id.rawValue,
                    title: artist.name,
                    artistName: artist.name,
                    albumName: nil,
                    artworkURL: artist.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: .artist
                )
            })
            
            // Add albums from MusicKit search
            allResults.append(contentsOf: response.albums.compactMap { album in
                LibraryItem(
                    id: album.id.rawValue,
                    title: album.title,
                    artistName: album.artistName,
                    albumName: album.title,
                    artworkURL: album.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: .album
                )
            })
            
        } catch {
            print("MusicKit library search failed, using cached search: \(error)")
        }
        
        // Also search cached library content for additional matches
        let cachedResults = await searchCachedLibraryInternal(query: query)
        
        // Combine and deduplicate results
        let combinedResults = combineAndDeduplicateResults(musicKitResults: allResults, cachedResults: cachedResults)
        
        await MainActor.run {
            self.searchResults = combinedResults
            self.isSearching = false
        }
    }
    
    // Enhanced cached library search
    private func searchCachedLibraryInternal(query: String) async -> [LibraryItem] {
        let lowercaseQuery = query.lowercased()
        var results: [LibraryItem] = []
        
        // Search through all cached library content with scoring (only enabled playlists for performance)
        let allItems = librarySongs + libraryArtists + libraryAlbums + enabledPlaylists.map { $0.toLibraryItem() }
        
        for item in allItems {
            let titleMatch = item.title.lowercased().contains(lowercaseQuery)
            let artistMatch = item.artistName.lowercased().contains(lowercaseQuery)
            let albumMatch = item.albumName?.lowercased().contains(lowercaseQuery) ?? false
            
            // Prioritize exact matches and prefix matches
            let titleExact = item.title.lowercased() == lowercaseQuery
            let titlePrefix = item.title.lowercased().hasPrefix(lowercaseQuery)
            let artistExact = item.artistName.lowercased() == lowercaseQuery
            let artistPrefix = item.artistName.lowercased().hasPrefix(lowercaseQuery)
            
            if titleExact || artistExact || titlePrefix || artistPrefix || titleMatch || artistMatch || albumMatch {
                results.append(item)
            }
        }
        
        // Sort by relevance (exact matches first, then prefix matches, then contains)
        return results.sorted { item1, item2 in
            let score1 = calculateSearchRelevanceScore(for: item1, query: lowercaseQuery)
            let score2 = calculateSearchRelevanceScore(for: item2, query: lowercaseQuery)
            return score1 > score2
        }
    }
    
    private func calculateSearchRelevanceScore(for item: LibraryItem, query: String) -> Int {
        var score = 0
        let title = item.title.lowercased()
        let artist = item.artistName.lowercased()
        let album = item.albumName?.lowercased() ?? ""
        
        // Exact matches get highest score
        if title == query { score += 100 }
        if artist == query { score += 90 }
        if album == query { score += 80 }
        
        // Prefix matches get high score
        if title.hasPrefix(query) { score += 50 }
        if artist.hasPrefix(query) { score += 40 }
        if album.hasPrefix(query) { score += 30 }
        
        // Contains matches get lower score
        if title.contains(query) { score += 20 }
        if artist.contains(query) { score += 15 }
        if album.contains(query) { score += 10 }
        
        return score
    }
    
    private func combineAndDeduplicateResults(musicKitResults: [LibraryItem], cachedResults: [LibraryItem]) -> [LibraryItem] {
        var seenIds = Set<String>()
        var combinedResults: [LibraryItem] = []
        
        // Add MusicKit results first (they're usually more accurate)
        for item in musicKitResults {
            if !seenIds.contains(item.id) {
                seenIds.insert(item.id)
                combinedResults.append(item)
            }
        }
        
        // Add cached results that weren't already included
        for item in cachedResults {
            if !seenIds.contains(item.id) {
                seenIds.insert(item.id)
                combinedResults.append(item)
            }
        }
        
        // Limit to 50 results for performance
        return Array(combinedResults.prefix(50))
    }
    
    
    // MARK: - Playlist Songs
    func loadPlaylistSongs(for playlist: LibraryPlaylist) async -> [LibraryItem] {
        // Check cache first
        let cacheKey = "playlist_\(playlist.id)"
        if let cached = libraryCache[cacheKey] {
            return cached
        }
        
        do {
            // Try MusicKit first - get playlist from library request
            var request = MusicLibraryRequest<MusicKit.Playlist>()
            request.limit = 1000 // Get all playlists to find the specific one
            let response = try await request.response()
            
            // Find the specific playlist by ID
            if let musicKitPlaylist = response.items.first(where: { $0.id.rawValue == playlist.id }) {
                print("🎵 Found playlist in MusicKit library: \(musicKitPlaylist.name)")
                // Load tracks from the playlist
                let songs = try await loadSongsFromMusicKitPlaylist(musicKitPlaylist)
                libraryCache[cacheKey] = songs
                return songs
            } else {
                print("⚠️ Playlist not found in MusicKit library")
            }
        } catch {
            print("MusicKit playlist loading failed: \(error)")
        }
        
        // Fallback to MediaPlayer
        return await loadPlaylistSongsWithMediaPlayer(playlistId: playlist.id)
    }
    
    private func loadSongsFromMusicKitPlaylist(_ playlist: MusicKit.Playlist) async throws -> [LibraryItem] {
        print("🎵 Loading tracks for playlist: \(playlist.name)")
        
        do {
            // Method 1: Try to get tracks directly from the playlist
            if let directTracks = playlist.tracks, !directTracks.isEmpty {
                print("✅ Found \(directTracks.count) tracks directly from playlist.tracks")
                let songs = directTracks.compactMap { track -> LibraryItem? in
                    return LibraryItem(
                        id: track.id.rawValue,
                        title: track.title,
                        artistName: track.artistName,
                        albumName: track.albumTitle ?? "",
                        artworkURL: track.artwork?.url(width: 300, height: 300)?.absoluteString,
                        itemType: .song
                    )
                }
                print("🎵 Returning \(songs.count) tracks from playlist.tracks")
                return songs
            }
            
            // Method 2: Attempt to fetch missing relationship via .with(.tracks)
            print("🔄 Attempting to fetch tracks relationship for playlist")
            let detailedPlaylist = try await playlist.with(.tracks)
            
            if let tracks = detailedPlaylist.tracks, !tracks.isEmpty {
                print("✅ Found \(tracks.count) tracks from detailed playlist")
                let songs = tracks.compactMap { track -> LibraryItem? in
                    return LibraryItem(
                        id: track.id.rawValue,
                        title: track.title,
                        artistName: track.artistName,
                        albumName: track.albumTitle ?? "",
                        artworkURL: track.artwork?.url(width: 300, height: 300)?.absoluteString,
                        itemType: .song
                    )
                }
                print("🎵 Returning \(songs.count) tracks from detailed playlist")
                return songs
            }
            
            print("⚠️ No tracks found in MusicKit playlist")
            return []
            
        } catch {
            print("❌ Error loading tracks from MusicKit playlist: \(error)")
            throw error
        }
    }
    
    private func loadPlaylistSongsWithMediaPlayer(playlistId: String) async -> [LibraryItem] {
        print("🎵 Falling back to MediaPlayer for playlist")
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let persistentId = UInt64(playlistId) else {
                    print("❌ Invalid playlist ID for MediaPlayer")
                    continuation.resume(returning: [])
                    return
                }
                
                let query = MPMediaQuery.playlists()
                guard let playlist = (query.collections as? [MPMediaPlaylist])?.first(where: { $0.persistentID == persistentId }) else {
                    print("❌ Playlist not found in MediaPlayer")
                    continuation.resume(returning: [])
                    return
                }
                
                print("✅ Found playlist in MediaPlayer: \(playlist.name ?? "Unknown") with \(playlist.items.count) items")
                
                let songs = playlist.items.compactMap { item -> LibraryItem? in
                    guard let title = item.title,
                          let artist = item.artist else { return nil }
                    
                    return LibraryItem(
                        id: String(item.persistentID),
                        title: title,
                        artistName: artist,
                        albumName: item.albumTitle,
                        artworkURL: self.extractArtworkURL(from: item),
                        itemType: .song
                    )
                }
                
                // Cache the results
                Task { @MainActor in
                    self.libraryCache["playlist_\(playlistId)"] = songs
                }
                
                continuation.resume(returning: songs)
            }
        }
    }
    
    // MARK: - Helper Methods
    nonisolated private func extractArtworkURL(from item: MPMediaItem?) -> String? {
        guard let item = item,
              let artwork = item.artwork else { return nil }
        
        let size = CGSize(width: 300, height: 300)
        guard let image = artwork.image(at: size),
              let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let base64String = imageData.base64EncodedString()
        return "data:image/jpeg;base64,\(base64String)"
    }
    
    nonisolated private func extractPlaylistArtworkURL(from playlist: MPMediaPlaylist) -> String? {
        // Get artwork from first song in playlist
        guard let firstSong = playlist.items.first else { return nil }
        return extractArtworkURL(from: firstSong)
    }
    
    // MARK: - Cache Management
    func clearCache() {
        libraryCache.removeAll()
        lastCacheUpdate = nil
    }
    
    private func isCacheValid() -> Bool {
        guard let lastUpdate = lastCacheUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheExpiration
    }
    
    // MARK: - Utility
    func refreshLibrary() async {
        clearCache()
        await loadAllLibraryContent()
    }
}
