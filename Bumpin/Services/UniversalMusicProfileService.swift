import Foundation
import FirebaseFirestore

// MARK: - Universal Music Profile Service

@MainActor
class UniversalMusicProfileService: ObservableObject {
    
    // MARK: - Unified Music Profile
    
    struct UniversalMusicProfile {
        let universalTrackId: String
        let title: String
        let artist: String
        let albumName: String?
        
        // Aggregated social data from ALL platforms
        let totalRatings: Int
        let averageRating: Double
        let totalReviews: Int
        let totalLikes: Int
        let totalReposts: Int
        
        // Platform breakdown
        let appleMusicLogs: [MusicLog]
        let spotifyLogs: [MusicLog]
        let allLogs: [MusicLog]
        
        // Trending data
        let trendingScore: Double
        let popularityRank: Int?
        
        var platformDistribution: [String: Int] {
            var distribution: [String: Int] = [:]
            for log in allLogs {
                let platform = log.musicPlatform ?? "unknown"
                distribution[platform, default: 0] += 1
            }
            return distribution
        }
        
        var crossPlatformPopularity: String {
            let appleCount = appleMusicLogs.count
            let spotifyCount = spotifyLogs.count
            let total = allLogs.count
            
            if total == 0 { return "No activity" }
            if appleCount > 0 && spotifyCount > 0 {
                return "Popular across platforms (\(appleCount) Apple Music, \(spotifyCount) Spotify)"
            } else if appleCount > 0 {
                return "Popular on Apple Music (\(appleCount) logs)"
            } else if spotifyCount > 0 {
                return "Popular on Spotify (\(spotifyCount) logs)"
            }
            return "Cross-platform activity"
        }
    }
    
    // MARK: - Singleton
    static let shared = UniversalMusicProfileService()
    
    private init() {}
    
    // MARK: - Profile Loading
    
    /// Load unified music profile that aggregates data from all platforms
    func loadUniversalProfile(for universalTrackId: String) async -> UniversalMusicProfile? {
        
        // Get the universal track
        guard let universalTrack = await getUniversalTrack(universalTrackId) else {
            print("❌ Universal track not found: \(universalTrackId)")
            return nil
        }
        
        // Get all logs for this universal track
        let allLogs = await getAllLogsForUniversalTrack(universalTrackId)
        
        // Separate by platform
        let appleMusicLogs = allLogs.filter { $0.musicPlatform == "apple_music" }
        let spotifyLogs = allLogs.filter { $0.musicPlatform == "spotify" }
        
        // Calculate aggregated stats
        let totalRatings = allLogs.compactMap { $0.rating }.count
        let averageRating = totalRatings > 0 ? 
            Double(allLogs.compactMap { $0.rating }.reduce(0, +)) / Double(totalRatings) : 0.0
        
        let totalReviews = allLogs.compactMap { $0.review }.filter { !$0.isEmpty }.count
        let totalLikes = allLogs.compactMap { $0.isLiked }.filter { $0 }.count
        let totalReposts = allLogs.compactMap { $0.thumbsUp }.filter { $0 }.count
        
        let profile = UniversalMusicProfile(
            universalTrackId: universalTrackId,
            title: universalTrack.title,
            artist: universalTrack.artist,
            albumName: universalTrack.albumName,
            totalRatings: totalRatings,
            averageRating: averageRating,
            totalReviews: totalReviews,
            totalLikes: totalLikes,
            totalReposts: totalReposts,
            appleMusicLogs: appleMusicLogs,
            spotifyLogs: spotifyLogs,
            allLogs: allLogs,
            trendingScore: calculateTrendingScore(allLogs),
            popularityRank: nil // Could be calculated separately
        )
        
        print("✅ Loaded universal profile: \(profile.title) (\(profile.allLogs.count) total logs)")
        return profile
    }
    
    /// Load universal profile by platform-specific search
    func loadUniversalProfileBySearch(
        title: String,
        artist: String,
        platformId: String,
        platform: String // "apple_music" or "spotify"
    ) async -> UniversalMusicProfile? {
        
        // First, find or create the universal track
        let universalTrack: UniversalTrack
        
        if platform == "apple_music" {
            universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: title,
                artist: artist,
                appleMusicId: platformId
            )
        } else {
            universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: title,
                artist: artist,
                spotifyId: platformId
            )
        }
        
        // Load the unified profile
        return await loadUniversalProfile(for: universalTrack.id)
    }
    
    // MARK: - Private Methods
    
    private func getUniversalTrack(_ universalId: String) async -> UniversalTrack? {
        return await withCheckedContinuation { continuation in
            UniversalTrack.findById(universalId) { track in
                continuation.resume(returning: track)
            }
        }
    }
    
    private func getAllLogsForUniversalTrack(_ universalTrackId: String) async -> [MusicLog] {
        return await withCheckedContinuation { continuation in
            let db = Firestore.firestore()
            
            db.collection("logs")
                .whereField("universalTrackId", isEqualTo: universalTrackId)
                .whereField("itemType", isEqualTo: "song") // Only songs for now
                .getDocuments { snapshot, error in
                    
                    if let error = error {
                        print("❌ Error fetching logs for universal track: \(error.localizedDescription)")
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let logs = snapshot?.documents.compactMap { try? $0.data(as: MusicLog.self) } ?? []
                    print("📊 Found \(logs.count) logs for universal track: \(universalTrackId)")
                    continuation.resume(returning: logs)
                }
        }
    }
    
    private func calculateTrendingScore(_ logs: [MusicLog]) -> Double {
        // Simple trending calculation based on recent activity
        let now = Date()
        let recentLogs = logs.filter { now.timeIntervalSince($0.dateLogged) < 86400 * 7 } // Last 7 days
        
        let recencyWeight = Double(recentLogs.count)
        let ratingWeight = logs.compactMap { $0.rating }.reduce(0, +)
        let reviewWeight = logs.compactMap { $0.review }.filter { !$0.isEmpty }.count
        
        return (recencyWeight * 3.0) + (Double(ratingWeight) * 2.0) + (Double(reviewWeight) * 1.5)
    }
    
    // MARK: - Migration Helpers
    
    /// Migrate existing Apple Music logs to use universal tracks
    func migrateExistingLogs() async {
        let db = Firestore.firestore()
        
        do {
            // Get logs without universal track IDs
            let snapshot = try await db.collection("logs")
                .whereField("universalTrackId", isEqualTo: NSNull())
                .limit(to: 50) // Process in batches
                .getDocuments()
            
            print("🔄 Migrating \(snapshot.documents.count) logs to universal tracks...")
            
            for document in snapshot.documents {
                if let log = try? document.data(as: MusicLog.self) {
                    // Create universal track for this log
                    let universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                        title: log.title,
                        artist: log.artistName,
                        appleMusicId: log.itemId
                    )
                    
                    // Update the log with universal track ID
                    try await document.reference.updateData([
                        "universalTrackId": universalTrack.id,
                        "musicPlatform": "apple_music",
                        "platformMatchingConfidence": universalTrack.matchingConfidence
                    ])
                    
                    print("✅ Migrated log: \(log.title) → \(universalTrack.id)")
                }
            }
            
        } catch {
            print("❌ Migration error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Cross-Platform Music Profile Extensions

extension UniversalMusicProfileService {
    
    /// Demo function to show how "Sicko Mode" would work
    func demonstrateSickoModeUnification() async {
        print("🎵 === SICKO MODE CROSS-PLATFORM DEMO ===")
        
        // Simulate Apple Music user logging "SICKO MODE"
        print("👤 Apple Music user logs 'SICKO MODE'...")
        let appleUniversalTrack = await TrackMatchingService.shared.getUniversalTrack(
            title: "SICKO MODE",
            artist: "Travis Scott",
            appleMusicId: "1445900472"
        )
        
        // Simulate Spotify user logging "sicko mode" (different casing)
        print("👤 Spotify user logs 'sicko mode'...")
        let spotifyUniversalTrack = await TrackMatchingService.shared.getUniversalTrack(
            title: "sicko mode",
            artist: "Travis Scott",
            spotifyId: "2xLMifQCjDGFmkHkpNLD9h"
        )
        
        print("🎯 Apple Music Universal ID: \(appleUniversalTrack.id)")
        print("🎯 Spotify Universal ID: \(spotifyUniversalTrack.id)")
        print("✅ Same Profile: \(appleUniversalTrack.id == spotifyUniversalTrack.id ? "YES" : "NO")")
        
        if appleUniversalTrack.id == spotifyUniversalTrack.id {
            print("🎉 SUCCESS: Both users will see the same ratings, comments, and profile!")
        }
    }
}
