import Foundation
import FirebaseFirestore

// MARK: - Universal Track Model

struct UniversalTrack: Identifiable, Codable {
    let id: String // Universal ID (e.g., "UNIV_SICKO_MODE_001")
    let title: String // Normalized title
    let artist: String // Normalized artist name
    let albumName: String? // Normalized album name
    let duration: TimeInterval? // Duration for matching validation
    
    // Platform-specific IDs
    var appleMusicId: String?
    var spotifyId: String?
    var isrcCode: String? // International Standard Recording Code (most accurate)
    
    // Matching metadata
    let matchingConfidence: Double // 0.0-1.0 confidence in the match
    let createdAt: Date
    let lastUpdated: Date
    var matchingMethod: String // "exact", "fuzzy", "ai", "isrc"
    
    // Social aggregation data
    var totalRatings: Int
    var averageRating: Double
    var totalLogs: Int
    var lastActivity: Date?
    
    init(
        title: String,
        artist: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil,
        appleMusicId: String? = nil,
        spotifyId: String? = nil,
        isrcCode: String? = nil,
        matchingConfidence: Double = 1.0,
        matchingMethod: String = "exact"
    ) {
        self.id = UniversalTrack.generateUniversalId(title: title, artist: artist)
        self.title = UniversalTrack.normalizeText(title)
        self.artist = UniversalTrack.normalizeText(artist)
        self.albumName = albumName.map { UniversalTrack.normalizeText($0) }
        self.duration = duration
        self.appleMusicId = appleMusicId
        self.spotifyId = spotifyId
        self.isrcCode = isrcCode
        self.matchingConfidence = matchingConfidence
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.matchingMethod = matchingMethod
        self.totalRatings = 0
        self.averageRating = 0.0
        self.totalLogs = 0
        self.lastActivity = nil
    }
    
    // MARK: - Universal ID Generation
    
    static func generateUniversalId(title: String, artist: String) -> String {
        let normalizedTitle = normalizeText(title)
        let normalizedArtist = normalizeText(artist)
        
        // Create a hash-based ID that's deterministic
        let combined = "\(normalizedTitle)|\(normalizedArtist)"
        let hash = abs(combined.hashValue)
        
        // Create readable ID with hash for uniqueness
        let titlePrefix = String(normalizedTitle.prefix(10)).replacingOccurrences(of: " ", with: "_")
        let artistPrefix = String(normalizedArtist.prefix(8)).replacingOccurrences(of: " ", with: "_")
        
        return "UNIV_\(titlePrefix)_\(artistPrefix)_\(hash % 10000)"
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9_]", with: "", options: .regularExpression)
    }
    
    // MARK: - Text Normalization
    
    static func normalizeText(_ text: String) -> String {
        return text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "feat.", with: "featuring")
            .replacingOccurrences(of: "ft.", with: "featuring")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "  ", with: " ") // Double spaces to single
            .folding(options: .diacriticInsensitive, locale: .current) // Remove accents
    }
    
    // MARK: - Platform ID Management
    
    mutating func addPlatformId(appleMusicId: String? = nil, spotifyId: String? = nil) {
        if let appleId = appleMusicId {
            self.appleMusicId = appleId
        }
        if let spotifyId = spotifyId {
            self.spotifyId = spotifyId
        }
        // Update timestamp when platform IDs are added
        // Note: This would need to be done through Firestore update in real usage
    }
    
    // Check if track has platform support
    var hasAppleMusicId: Bool { appleMusicId != nil }
    var hasSpotifyId: Bool { spotifyId != nil }
    var supportedPlatforms: [String] {
        var platforms: [String] = []
        if hasAppleMusicId { platforms.append("Apple Music") }
        if hasSpotifyId { platforms.append("Spotify") }
        return platforms
    }
}

// MARK: - Firestore Operations

extension UniversalTrack {
    
    static func create(_ track: UniversalTrack, completion: @escaping (Result<Void, Error>) -> Void) {
        let db = Firestore.firestore()
        do {
            try db.collection("universalTracks").document(track.id).setData(from: track) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    print("✅ Universal track created: \(track.title) by \(track.artist)")
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    static func findById(_ universalId: String, completion: @escaping (UniversalTrack?) -> Void) {
        let db = Firestore.firestore()
        db.collection("universalTracks").document(universalId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching universal track: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            let track = try? snapshot?.data(as: UniversalTrack.self)
            completion(track)
        }
    }
    
    static func findByPlatformId(
        appleMusicId: String? = nil,
        spotifyId: String? = nil,
        completion: @escaping (UniversalTrack?) -> Void
    ) {
        let db = Firestore.firestore()
        var query: Query?
        
        if let appleId = appleMusicId {
            query = db.collection("universalTracks").whereField("appleMusicId", isEqualTo: appleId)
        } else if let spotifyId = spotifyId {
            query = db.collection("universalTracks").whereField("spotifyId", isEqualTo: spotifyId)
        }
        
        guard let finalQuery = query else {
            completion(nil)
            return
        }
        
        finalQuery.limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error finding universal track by platform ID: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            let track = snapshot?.documents.first.flatMap { try? $0.data(as: UniversalTrack.self) }
            completion(track)
        }
    }
    
    static func updateSocialStats(
        universalId: String,
        totalRatings: Int,
        averageRating: Double,
        totalLogs: Int,
        completion: @escaping (Error?) -> Void
    ) {
        let db = Firestore.firestore()
        db.collection("universalTracks").document(universalId).updateData([
            "totalRatings": totalRatings,
            "averageRating": averageRating,
            "totalLogs": totalLogs,
            "lastActivity": FieldValue.serverTimestamp()
        ]) { error in
            completion(error)
        }
    }
}

// MARK: - Matching Score Calculation

extension UniversalTrack {
    
    /// Calculate matching score between two tracks (0.0 - 1.0)
    static func calculateMatchingScore(
        title1: String, artist1: String, duration1: TimeInterval?,
        title2: String, artist2: String, duration2: TimeInterval?
    ) -> Double {
        
        let normalizedTitle1 = normalizeText(title1)
        let normalizedArtist1 = normalizeText(artist1)
        let normalizedTitle2 = normalizeText(title2)
        let normalizedArtist2 = normalizeText(artist2)
        
        // Exact match
        if normalizedTitle1 == normalizedTitle2 && normalizedArtist1 == normalizedArtist2 {
            return 1.0
        }
        
        // Calculate similarity scores
        let titleSimilarity = stringSimilarity(normalizedTitle1, normalizedTitle2)
        let artistSimilarity = stringSimilarity(normalizedArtist1, normalizedArtist2)
        
        // Duration validation (if both available)
        var durationScore = 1.0
        if let d1 = duration1, let d2 = duration2 {
            let durationDiff = abs(d1 - d2)
            durationScore = durationDiff < 5.0 ? 1.0 : max(0.0, 1.0 - (durationDiff / 30.0))
        }
        
        // Weighted average (title and artist are most important)
        let finalScore = (titleSimilarity * 0.5) + (artistSimilarity * 0.4) + (durationScore * 0.1)
        return finalScore
    }
    
    /// Calculate string similarity using Levenshtein distance
    private static func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Calculate Levenshtein distance between two strings
    private static func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let arr1 = Array(str1)
        let arr2 = Array(str2)
        let m = arr1.count
        let n = arr2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if arr1[i-1] == arr2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
}
