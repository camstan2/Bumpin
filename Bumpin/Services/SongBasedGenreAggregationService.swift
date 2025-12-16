import Foundation
import FirebaseFirestore
import MusicKit

/// Service that determines album/artist genres by analyzing their songs' genres
/// Uses a "bottom-up" consensus approach based on logged songs in Firestore
@MainActor
class SongBasedGenreAggregationService: ObservableObject {
    
    static let shared = SongBasedGenreAggregationService()
    
    private let db = Firestore.firestore()
    
    // Cache to avoid repeated queries
    private var albumGenreCache: [String: CachedGenreResult] = [:]
    private var artistGenreCache: [String: CachedGenreResult] = [:]
    
    private struct CachedGenreResult {
        let result: AIGenreClassificationService.ClassificationResult
        let timestamp: Date
        let songCount: Int
        
        var isExpired: Bool {
            // Cache expires after 7 days or if based on too few songs
            let age = Date().timeIntervalSince(timestamp)
            let weekInSeconds: TimeInterval = 7 * 24 * 60 * 60
            return age > weekInSeconds || songCount < 5
        }
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Classify an album's genre based on its songs' genres from Firestore logs
    func classifyAlbumGenre(
        albumId: String,
        albumTitle: String,
        artistName: String
    ) async -> AIGenreClassificationService.ClassificationResult {
        
        // Check cache first
        if let cached = albumGenreCache[albumId], !cached.isExpired {
            print("📦 Using cached genre for album '\(albumTitle)': \(cached.result.primaryGenre)")
            return cached.result
        }
        
        print("🎵 Classifying album '\(albumTitle)' by \(artistName) using song consensus...")
        
        // 1. Fetch album tracks from MusicKit
        let tracks = await fetchAlbumTracks(albumId: albumId)
        
        guard !tracks.isEmpty else {
            print("⚠️ No tracks found for album '\(albumTitle)', using fallback")
            return fallbackClassification(
                title: albumTitle,
                artist: artistName,
                itemType: "album"
            )
        }
        
        print("📀 Found \(tracks.count) tracks in album '\(albumTitle)'")
        
        // 2. Get track IDs
        let trackIds = tracks.map { $0.id }
        
        // 3. Query Firestore for existing logs of these tracks
        let logs = await fetchLogsForTracks(trackIds: trackIds)
        
        print("📊 Found \(logs.count) existing logs for album tracks")
        
        // 4. If we have enough logged songs, use consensus
        if logs.count >= 3 {
            let result = calculateGenreConsensus(
                from: logs,
                itemTitle: albumTitle,
                itemType: "album"
            )
            
            // Cache the result
            albumGenreCache[albumId] = CachedGenreResult(
                result: result,
                timestamp: Date(),
                songCount: logs.count
            )
            
            return result
        }
        
        // 5. Not enough data - try fetching genres directly from the tracks
        print("ℹ️ Not enough logged songs (\(logs.count)/3), checking Apple Music track genres...")
        let trackGenres = tracks.compactMap { $0.genreNames }.flatMap { $0 }
        
        if !trackGenres.isEmpty {
            let result = await classifyFromAppleMusicGenres(
                genres: trackGenres,
                title: albumTitle,
                artist: artistName
            )
            
            // Cache with lower song count to indicate lower confidence
            albumGenreCache[albumId] = CachedGenreResult(
                result: result,
                timestamp: Date(),
                songCount: 0
            )
            
            return result
        }
        
        // 6. Complete fallback
        return fallbackClassification(
            title: albumTitle,
            artist: artistName,
            itemType: "album"
        )
    }
    
    /// Classify an artist's genre based on their songs' genres from Firestore logs
    func classifyArtistGenre(
        artistId: String,
        artistName: String
    ) async -> AIGenreClassificationService.ClassificationResult {
        
        // Check cache first
        if let cached = artistGenreCache[artistId], !cached.isExpired {
            print("📦 Using cached genre for artist '\(artistName)': \(cached.result.primaryGenre)")
            return cached.result
        }
        
        print("🎤 Classifying artist '\(artistName)' using song consensus...")
        
        // 1. Fetch artist's top songs from MusicKit
        let topSongs = await fetchArtistTopSongs(artistName: artistName, limit: 20)
        
        guard !topSongs.isEmpty else {
            print("⚠️ No songs found for artist '\(artistName)', using fallback")
            return fallbackClassification(
                title: artistName,
                artist: artistName,
                itemType: "artist"
            )
        }
        
        print("🎸 Found \(topSongs.count) songs for artist '\(artistName)'")
        
        // 2. Get song IDs
        let songIds = topSongs.map { $0.id }
        
        // 3. Query Firestore for existing logs of these songs
        let logs = await fetchLogsForTracks(trackIds: songIds)
        
        print("📊 Found \(logs.count) existing logs for artist's songs")
        
        // 4. If we have enough logged songs, use consensus
        if logs.count >= 3 {
            let result = calculateGenreConsensus(
                from: logs,
                itemTitle: artistName,
                itemType: "artist"
            )
            
            // Cache the result
            artistGenreCache[artistId] = CachedGenreResult(
                result: result,
                timestamp: Date(),
                songCount: logs.count
            )
            
            return result
        }
        
        // 5. Not enough data - try fetching genres directly from the songs
        print("ℹ️ Not enough logged songs (\(logs.count)/3), checking Apple Music song genres...")
        let songGenres = topSongs.compactMap { $0.genreNames }.flatMap { $0 }
        
        if !songGenres.isEmpty {
            let result = await classifyFromAppleMusicGenres(
                genres: songGenres,
                title: artistName,
                artist: artistName
            )
            
            // Cache with lower song count to indicate lower confidence
            artistGenreCache[artistId] = CachedGenreResult(
                result: result,
                timestamp: Date(),
                songCount: 0
            )
            
            return result
        }
        
        // 6. Complete fallback
        return fallbackClassification(
            title: artistName,
            artist: artistName,
            itemType: "artist"
        )
    }
    
    // MARK: - MusicKit Fetching
    
    private func fetchAlbumTracks(albumId: String) async -> [(id: String, genreNames: [String])] {
        do {
            let albumRequest = MusicCatalogResourceRequest<Album>(
                matching: \.id,
                equalTo: MusicItemID(albumId)
            )
            let response = try await albumRequest.response()
            
            guard let album = response.items.first else {
                print("⚠️ Album not found: \(albumId)")
                return []
            }
            
            // Try to get tracks directly first
            if let directTracks = album.tracks, !directTracks.isEmpty {
                print("✅ Got \(directTracks.count) tracks directly from album")
                return directTracks.map { track in
                    (id: track.id.rawValue, genreNames: track.genreNames)
                }
            }
            
            // Fetch with tracks relationship
            let detailedAlbum = try await album.with(.tracks)
            if let tracks = detailedAlbum.tracks {
                print("✅ Got \(tracks.count) tracks via album.with(.tracks)")
                return tracks.map { track in
                    (id: track.id.rawValue, genreNames: track.genreNames)
                }
            }
            
            print("⚠️ No tracks available for album")
            return []
            
        } catch {
            print("❌ Error fetching album tracks: \(error)")
            return []
        }
    }
    
    private func fetchArtistTopSongs(artistName: String, limit: Int = 20) async -> [(id: String, genreNames: [String])] {
        do {
            var songsRequest = MusicCatalogSearchRequest(
                term: "\(artistName) songs",
                types: [MusicKit.Song.self]
            )
            songsRequest.limit = limit
            
            let response = try await songsRequest.response()
            
            // Filter to exact artist matches
            let artistSongs = response.songs.filter { song in
                song.artistName.lowercased() == artistName.lowercased()
            }
            
            print("✅ Found \(artistSongs.count) songs for artist '\(artistName)'")
            return artistSongs.map { song in
                (id: song.id.rawValue, genreNames: song.genreNames)
            }
            
        } catch {
            print("❌ Error fetching artist songs: \(error)")
            return []
        }
    }
    
    // MARK: - Firestore Queries
    
    private func fetchLogsForTracks(trackIds: [String]) async -> [MusicLog] {
        var allLogs: [MusicLog] = []
        
        // Firestore 'in' queries support max 10 items
        // Batch queries into chunks of 10
        let batchSize = 10
        var startIndex = 0
        
        while startIndex < trackIds.count {
            let endIndex = min(startIndex + batchSize, trackIds.count)
            let batch = Array(trackIds[startIndex..<endIndex])
            
            do {
                let snapshot = try await db.collection("logs")
                    .whereField("itemId", in: batch)
                    .whereField("itemType", isEqualTo: "song")
                    .getDocuments()
                
                let logs = snapshot.documents.compactMap { doc -> MusicLog? in
                    try? doc.data(as: MusicLog.self)
                }
                
                allLogs.append(contentsOf: logs)
                
            } catch {
                print("❌ Error fetching logs for batch: \(error)")
            }
            
            startIndex += batchSize
        }
        
        return allLogs
    }
    
    // MARK: - Genre Consensus Algorithm
    
    private func calculateGenreConsensus(
        from logs: [MusicLog],
        itemTitle: String,
        itemType: String
    ) -> AIGenreClassificationService.ClassificationResult {
        
        // Extract all primary genres from logs
        let genres = logs.compactMap { $0.primaryGenre }
        
        guard !genres.isEmpty else {
            return AIGenreClassificationService.ClassificationResult(
                primaryGenre: "Other",
                confidence: 0.1,
                reasoning: "No genre data available from logged songs",
                appleMusicGenres: [],
                classificationMethod: "song_consensus_fallback"
            )
        }
        
        // Calculate frequency distribution
        let frequency = calculateGenreFrequency(genres)
        
        // Get most common genre with threshold
        let primaryGenre = getMostCommonGenre(frequency, minThreshold: 0.25)
        
        // Calculate confidence score
        let confidence = calculateConfidence(frequency, totalLogs: logs.count)
        
        // Build reasoning
        let mostCommonCount = frequency[primaryGenre] ?? 0
        let reasoning = "Based on \(logs.count) logged songs: \(mostCommonCount) are \(primaryGenre)"
        
        print("✅ Genre consensus for '\(itemTitle)': \(primaryGenre) (confidence: \(String(format: "%.2f", confidence)))")
        
        return AIGenreClassificationService.ClassificationResult(
            primaryGenre: primaryGenre,
            confidence: confidence,
            reasoning: reasoning,
            appleMusicGenres: [],
            classificationMethod: "song_consensus"
        )
    }
    
    private func calculateGenreFrequency(_ genres: [String]) -> [String: Int] {
        var frequency: [String: Int] = [:]
        for genre in genres {
            frequency[genre, default: 0] += 1
        }
        return frequency
    }
    
    private func getMostCommonGenre(
        _ frequency: [String: Int],
        minThreshold: Double = 0.25
    ) -> String {
        guard !frequency.isEmpty else { return "Other" }
        
        let total = frequency.values.reduce(0, +)
        guard total > 0 else { return "Other" }
        
        let sorted = frequency.sorted { $0.value > $1.value }
        guard let mostCommon = sorted.first else { return "Other" }
        
        let percentage = Double(mostCommon.value) / Double(total)
        
        // If most common genre is < threshold, it's too diverse
        if percentage < minThreshold {
            print("⚠️ Genre too diverse (\(String(format: "%.1f%%", percentage * 100)) for \(mostCommon.key)), using 'Other'")
            return "Other"
        }
        
        return mostCommon.key
    }
    
    private func calculateConfidence(
        _ frequency: [String: Int],
        totalLogs: Int
    ) -> Double {
        guard !frequency.isEmpty else { return 0.0 }
        
        let total = frequency.values.reduce(0, +)
        guard total > 0 else { return 0.0 }
        
        let sorted = frequency.sorted { $0.value > $1.value }
        guard let mostCommon = sorted.first else { return 0.0 }
        
        // Consistency: How dominant is the most common genre?
        let consistency = Double(mostCommon.value) / Double(total)
        
        // Data amount: More logs = more confidence (capped at 20 logs = 1.0)
        let dataAmount = min(Double(totalLogs) / 20.0, 1.0)
        
        // Weighted combination (70% consistency, 30% data amount)
        let confidence = consistency * 0.7 + dataAmount * 0.3
        
        return confidence
    }
    
    // MARK: - Fallback Methods
    
    private func classifyFromAppleMusicGenres(
        genres: [String],
        title: String,
        artist: String
    ) async -> AIGenreClassificationService.ClassificationResult {
        
        // Use the existing AI classification service
        return await AIGenreClassificationService.shared.classifySong(
            title: title,
            artist: artist,
            appleMusicGenres: genres
        )
    }
    
    private func fallbackClassification(
        title: String,
        artist: String,
        itemType: String
    ) -> AIGenreClassificationService.ClassificationResult {
        
        print("⚠️ Using fallback classification for \(itemType) '\(title)'")
        
        return AIGenreClassificationService.ClassificationResult(
            primaryGenre: "Other",
            confidence: 0.2,
            reasoning: "Insufficient data for genre classification",
            appleMusicGenres: [],
            classificationMethod: "fallback"
        )
    }
    
    // MARK: - Cache Management
    
    /// Clear expired cache entries
    func cleanupCache() {
        albumGenreCache = albumGenreCache.filter { !$0.value.isExpired }
        artistGenreCache = artistGenreCache.filter { !$0.value.isExpired }
        print("🧹 Cleaned up genre cache")
    }
    
    /// Invalidate cache for a specific album (call when new songs are logged)
    func invalidateAlbumCache(albumId: String) {
        albumGenreCache.removeValue(forKey: albumId)
        print("🔄 Invalidated cache for album: \(albumId)")
    }
    
    /// Invalidate cache for a specific artist (call when new songs are logged)
    func invalidateArtistCache(artistId: String) {
        artistGenreCache.removeValue(forKey: artistId)
        print("🔄 Invalidated cache for artist: \(artistId)")
    }
}

