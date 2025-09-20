import Foundation
import SwiftUI
import MusicKit

// MARK: - Unified Music Search Service

@MainActor
class UnifiedMusicSearchService: ObservableObject {
    
    // MARK: - Search Results
    
    struct UnifiedSearchResults {
        var songs: [MusicSearchResult] = []
        var artists: [MusicSearchResult] = []
        var albums: [MusicSearchResult] = []
        
        var totalResults: Int {
            songs.count + artists.count + albums.count
        }
        
        var isEmpty: Bool {
            totalResults == 0
        }
    }
    
    // MARK: - User Preferences
    
    enum MusicPlatformPreference: String, CaseIterable {
        case appleMusicOnly = "apple_music_only"
        case spotifyOnly = "spotify_only"
        case both = "both_platforms"
        case appleMusicPrimary = "apple_music_primary"
        case spotifyPrimary = "spotify_primary"
        
        var displayName: String {
            switch self {
            case .appleMusicOnly: return "Apple Music Only"
            case .spotifyOnly: return "Spotify Only"
            case .both: return "Both Platforms"
            case .appleMusicPrimary: return "Apple Music Primary"
            case .spotifyPrimary: return "Spotify Primary"
            }
        }
    }
    
    @Published var platformPreference: MusicPlatformPreference = .appleMusicOnly
    @Published var isSearching = false
    @Published var searchError: String?
    
    // MARK: - Services
    private let spotifyService = SpotifyService.shared
    
    // MARK: - Singleton
    static let shared = UnifiedMusicSearchService()
    
    private init() {
        loadPlatformPreference()
    }
    
    // MARK: - Unified Search
    
    func search(query: String, limit: Int = 25) async -> UnifiedSearchResults {
        await MainActor.run {
            isSearching = true
            searchError = nil
        }
        
        defer {
            Task { @MainActor in
                isSearching = false
            }
        }
        
        var results = UnifiedSearchResults()
        
        switch platformPreference {
        case .appleMusicOnly:
            results = await searchAppleMusic(query: query, limit: limit)
            
        case .spotifyOnly:
            results = await searchSpotify(query: query, limit: limit)
            
        case .both, .appleMusicPrimary, .spotifyPrimary:
            // Search both platforms and merge results
            async let appleResults = searchAppleMusic(query: query, limit: limit / 2)
            async let spotifyResults = searchSpotify(query: query, limit: limit / 2)
            
            let (apple, spotify) = await (appleResults, spotifyResults)
            results = mergeSearchResults(apple: apple, spotify: spotify)
        }
        
        print("🔍 Unified search for '\(query)': \(results.totalResults) total results")
        return results
    }
    
    // MARK: - Platform-Specific Search
    
    private func searchAppleMusic(query: String, limit: Int) async -> UnifiedSearchResults {
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self, MusicKit.Artist.self, MusicKit.Album.self])
            request.limit = limit
            
            let response = try await request.response()
            
            var results = UnifiedSearchResults()
            
            // Convert Apple Music results
            results.songs = response.songs.map { song in
                MusicSearchResult(
                    id: song.id.rawValue,
                    title: song.title,
                    artistName: song.artistName,
                    albumName: song.albumTitle ?? "",
                    artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: "song",
                    popularity: 0,
                    // Prefer song-level genre names; fallback to first artist's genres
                    genreNames: (song.genreNames.isEmpty ? song.artists?.first?.genreNames : song.genreNames),
                    primaryGenre: (song.genreNames.isEmpty ? song.artists?.first?.genreNames?.first : song.genreNames.first)
                )
            }
            
            results.artists = response.artists.map { artist in
                MusicSearchResult(
                    id: artist.id.rawValue,
                    title: artist.name,
                    artistName: artist.name,
                    albumName: "",
                    artworkURL: artist.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: "artist",
                    popularity: 0,
                    genreNames: artist.genreNames,
                    primaryGenre: artist.genreNames?.first
                )
            }
            
            results.albums = response.albums.map { album in
                MusicSearchResult(
                    id: album.id.rawValue,
                    title: album.title,
                    artistName: album.artistName,
                    albumName: album.title,
                    artworkURL: album.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: "album",
                    popularity: 0,
                    genreNames: album.genreNames,
                    primaryGenre: album.genreNames.first
                )
            }
            
            // Deduplicate within Apple results themselves (Apple can return duplicate rows)
            let originalSongCount = results.songs.count
            let originalArtistCount = results.artists.count
            let originalAlbumCount = results.albums.count
            
            results.songs = removeDuplicates(results.songs)
            results.artists = removeDuplicates(results.artists)
            results.albums = removeDuplicates(results.albums)
            
            // Log deduplication results for debugging
            if originalSongCount != results.songs.count || originalArtistCount != results.artists.count || originalAlbumCount != results.albums.count {
                print("🍎 Deduplication for '\(query)': Songs \(originalSongCount)→\(results.songs.count), Artists \(originalArtistCount)→\(results.artists.count), Albums \(originalAlbumCount)→\(results.albums.count)")
            }
            
            return results
            
        } catch {
            print("❌ Apple Music search error: \(error.localizedDescription)")
            await MainActor.run {
                searchError = "Apple Music search failed"
            }
            return UnifiedSearchResults()
        }
    }
    
    private func searchSpotify(query: String, limit: Int) async -> UnifiedSearchResults {
        let tracks = await spotifyService.searchTracks(query: query, limit: limit)
        let artists = await spotifyService.searchArtists(query: query, limit: limit)
        let albums = await spotifyService.searchAlbums(query: query, limit: limit)
        
        var results = UnifiedSearchResults()
        results.songs = tracks.map { spotifyService.convertToMusicSearchResult($0) }
        results.artists = artists.map { spotifyService.convertToMusicSearchResult($0) }
        results.albums = albums.map { spotifyService.convertToMusicSearchResult($0) }
        
        return results
    }
    
    // MARK: - Result Merging
    
    private func mergeSearchResults(apple: UnifiedSearchResults, spotify: UnifiedSearchResults) -> UnifiedSearchResults {
        var merged = UnifiedSearchResults()
        
        // Combine results based on preference
        switch platformPreference {
        case .appleMusicPrimary:
            merged.songs = apple.songs + spotify.songs
            merged.artists = apple.artists + spotify.artists
            merged.albums = apple.albums + spotify.albums
            
        case .spotifyPrimary:
            merged.songs = spotify.songs + apple.songs
            merged.artists = spotify.artists + apple.artists
            merged.albums = spotify.albums + apple.albums
            
        case .both:
            // Interleave results for balanced representation
            merged.songs = interleaveResults(apple.songs, spotify.songs)
            merged.artists = interleaveResults(apple.artists, spotify.artists)
            merged.albums = interleaveResults(apple.albums, spotify.albums)
            
        default:
            merged = apple
        }
        
        // Remove duplicates based on title + artist
        merged.songs = removeDuplicates(merged.songs)
        merged.artists = removeDuplicates(merged.artists)
        merged.albums = removeDuplicates(merged.albums)
        
        return merged
    }
    
    private func interleaveResults<T>(_ first: [T], _ second: [T]) -> [T] {
        var result: [T] = []
        let maxCount = max(first.count, second.count)
        
        for i in 0..<maxCount {
            if i < first.count {
                result.append(first[i])
            }
            if i < second.count {
                result.append(second[i])
            }
        }
        
        return result
    }
    
    private func removeDuplicates(_ results: [MusicSearchResult]) -> [MusicSearchResult] {
        var deduplicated: [MusicSearchResult] = []
        
        func normalize(_ text: String) -> String {
            let lowered = text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.replacingOccurrences(of: "[\u{2018}\u{2019}'`]+", with: "", options: .regularExpression)
        }
        
        func normalizeAlbumTitle(_ title: String) -> String {
            var t = normalize(title)
            // Remove edition qualifiers in parentheses - more comprehensive patterns
            t = t.replacingOccurrences(of: "\\s*\\((deluxe|clean|explicit|remaster(ed)?|expanded|edition|version|single|ep|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)[^)]*\\)", with: "", options: .regularExpression)
            // Remove dash qualifiers
            t = t.replacingOccurrences(of: "\\s*-\\s*(single|ep|deluxe|clean|explicit|expanded|edition|version|remaster(ed)?|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)\\s*$", with: "", options: .regularExpression)
            // Remove bracket qualifiers
            t = t.replacingOccurrences(of: "\\s*\\[(deluxe|clean|explicit|remaster(ed)?|expanded|edition|version|single|ep|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)[^\\]]*\\]", with: "", options: .regularExpression)
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Enhanced grouping logic with multiple fallback keys
        var titleArtistGroups: [String: [MusicSearchResult]] = [:]
        
        for result in results {
            let artistKey = normalize(result.artistName)
            let baseTitle: String = (result.itemType == "album") ? normalizeAlbumTitle(result.title) : normalize(result.title)
            
            // Create multiple possible keys for more robust matching
            let primaryKey = "\(result.itemType)|\(baseTitle)|\(artistKey)"
            
            // For albums, also try matching with just the first word of artist (for "Various Artists" cases)
            let artistFirstWord = artistKey.components(separatedBy: " ").first ?? artistKey
            let secondaryKey = result.itemType == "album" ? "\(result.itemType)|\(baseTitle)|\(artistFirstWord)" : primaryKey
            
            // Check if we already have this item under any key
            let existingGroup = titleArtistGroups[primaryKey] ?? titleArtistGroups[secondaryKey]
            
            if let existing = existingGroup {
                // Add to existing group
                titleArtistGroups[primaryKey] = existing + [result]
                // Remove from secondary key if it was there
                if titleArtistGroups[secondaryKey] != nil && secondaryKey != primaryKey {
                    titleArtistGroups[secondaryKey] = nil
                }
            } else {
                // Create new group
                titleArtistGroups[primaryKey] = [result]
            }
        }
        
        // Second pass: From each group, pick the best representative
        for (_, group) in titleArtistGroups {
            if let bestResult = selectBestFromGroup(group) {
                deduplicated.append(bestResult)
            }
        }
        
        // Final safety pass: remove any remaining exact duplicates by ID
        var seenIds: Set<String> = []
        deduplicated = deduplicated.filter { result in
            if !result.id.isEmpty && seenIds.contains(result.id) {
                return false
            }
            if !result.id.isEmpty {
                seenIds.insert(result.id)
            }
            return true
        }
        
        return deduplicated
    }
    
    private func selectBestFromGroup(_ group: [MusicSearchResult]) -> MusicSearchResult? {
        guard !group.isEmpty else { return nil }
        
        // If only one item, return it
        if group.count == 1 {
            return group.first
        }
        
        // Log duplicate detection for debugging
        if group.count > 1 {
            let titles = group.map { $0.title }.joined(separator: ", ")
            print("🔍 Found \(group.count) duplicates for \(group.first?.itemType ?? "unknown"): \(titles)")
        }
        
        // Prefer results with more complete metadata
        let scored = group.map { result -> (MusicSearchResult, Int) in
            var score = 0
            
            // Prefer results with valid IDs (essential for playback)
            if !result.id.isEmpty && result.id != "unknown" {
                score += 20
            }
            
            // Prefer results with album artwork
            if let artworkURL = result.artworkURL, !artworkURL.isEmpty {
                score += 10
            }
            
            // Prefer results with more complete titles (less likely to be truncated)
            if result.title.count > 10 {
                score += 5
            }
            
            // Prefer results with genre information
            if let genres = result.genreNames, !genres.isEmpty {
                score += 3
            }
            
            // Strongly prefer results without edition qualifiers in the original title (main release)
            let titleLower = result.title.lowercased()
            let hasEditionQualifier = titleLower.contains("deluxe") ||
                                    titleLower.contains("explicit") ||
                                    titleLower.contains("clean") ||
                                    titleLower.contains("single") ||
                                    titleLower.contains("remaster") ||
                                    titleLower.contains("anniversary") ||
                                    titleLower.contains("special") ||
                                    titleLower.contains("limited") ||
                                    titleLower.contains("extended") ||
                                    titleLower.contains("complete")
            if !hasEditionQualifier {
                score += 15
            }
            
            // For albums, prefer shorter titles (usually the main release)
            if result.itemType == "album" {
                let titleLength = result.title.count
                if titleLength < 30 {
                    score += 8
                } else if titleLength > 50 {
                    score -= 5
                }
            }
            
            // Prefer results with higher popularity scores
            score += min(result.popularity / 10, 5) // Cap at 5 points
            
            return (result, score)
        }
        
        // Return the highest scoring result
        let bestResult = scored.max(by: { $0.1 < $1.1 })?.0
        
        if group.count > 1, let best = bestResult {
            print("✅ Selected best result: '\(best.title)' (score: \(scored.first(where: { $0.0.id == best.id })?.1 ?? 0))")
        }
        
        return bestResult
    }
    
    // MARK: - Platform Preference Management
    
    func setPlatformPreference(_ preference: MusicPlatformPreference) {
        platformPreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: "music_platform_preference")
        print("🎛️ Music platform preference set to: \(preference.displayName)")
    }
    
    private func loadPlatformPreference() {
        if let saved = UserDefaults.standard.string(forKey: "music_platform_preference"),
           let preference = MusicPlatformPreference(rawValue: saved) {
            platformPreference = preference
        }
    }
    
    // MARK: - Universal Track Integration
    
    /// Create universal track when user logs music from search
    func createUniversalTrackForLog(searchResult: MusicSearchResult, platform: String) async -> String {
        let universalTrack: UniversalTrack
        
        if platform == "apple_music" {
            universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: searchResult.title,
                artist: searchResult.artistName,
                albumName: searchResult.albumName,
                appleMusicId: searchResult.id
            )
        } else {
            // For Spotify, we'd extract ISRC if available
            universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: searchResult.title,
                artist: searchResult.artistName,
                albumName: searchResult.albumName,
                spotifyId: searchResult.id
            )
        }
        
        return universalTrack.id
    }
}
