import Foundation
import FirebaseFirestore
import MusicKit

// MARK: - Track Matching Service

@MainActor
class TrackMatchingService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = TrackMatchingService()
    
    private init() {}
    
    // MARK: - Matching Thresholds
    private let exactMatchThreshold = 1.0
    private let fuzzyMatchThreshold = 0.85
    private let minimumMatchThreshold = 0.75
    
    // MARK: - Public Interface
    
    /// Find or create universal track for Apple Music item
    func getUniversalTrack(
        title: String,
        artist: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil,
        appleMusicId: String? = nil
    ) async -> UniversalTrack {
        
        // First, try to find existing universal track by Apple Music ID
        if let appleId = appleMusicId {
            if let existingTrack = await findByAppleMusicId(appleId) {
                print("✅ Found existing universal track by Apple Music ID: \(existingTrack.title)")
                return existingTrack
            }
        }
        
        // Try to find by fuzzy matching
        if let matchedTrack = await findBestMatch(title: title, artist: artist, duration: duration) {
            // Add Apple Music ID to existing track
            var updatedTrack = matchedTrack
            updatedTrack.appleMusicId = appleMusicId
            await updatePlatformId(universalId: updatedTrack.id, appleMusicId: appleMusicId)
            print("✅ Matched to existing universal track: \(updatedTrack.title)")
            return updatedTrack
        }
        
        // Create new universal track
        let newTrack = UniversalTrack(
            title: title,
            artist: artist,
            albumName: albumName,
            duration: duration,
            appleMusicId: appleMusicId,
            matchingMethod: "new_creation"
        )
        
        await createUniversalTrack(newTrack)
        print("🆕 Created new universal track: \(newTrack.title) by \(newTrack.artist)")
        return newTrack
    }
    
    /// Find or create universal track for Spotify item
    func getUniversalTrack(
        title: String,
        artist: String,
        albumName: String? = nil,
        duration: TimeInterval? = nil,
        spotifyId: String? = nil,
        isrcCode: String? = nil
    ) async -> UniversalTrack {
        
        // Try ISRC first (most accurate)
        if let isrc = isrcCode {
            if let existingTrack = await findByISRC(isrc) {
                print("✅ Found existing universal track by ISRC: \(existingTrack.title)")
                return existingTrack
            }
        }
        
        // Try to find existing universal track by Spotify ID
        if let spotifyId = spotifyId {
            if let existingTrack = await findBySpotifyId(spotifyId) {
                print("✅ Found existing universal track by Spotify ID: \(existingTrack.title)")
                return existingTrack
            }
        }
        
        // Try to find by fuzzy matching
        if let matchedTrack = await findBestMatch(title: title, artist: artist, duration: duration) {
            // Add Spotify ID to existing track
            var updatedTrack = matchedTrack
            updatedTrack.spotifyId = spotifyId
            await updatePlatformId(universalId: updatedTrack.id, spotifyId: spotifyId, isrcCode: isrcCode)
            print("✅ Matched to existing universal track: \(updatedTrack.title)")
            return updatedTrack
        }
        
        // Create new universal track
        let newTrack = UniversalTrack(
            title: title,
            artist: artist,
            albumName: albumName,
            duration: duration,
            spotifyId: spotifyId,
            isrcCode: isrcCode,
            matchingMethod: "new_creation"
        )
        
        await createUniversalTrack(newTrack)
        print("🆕 Created new universal track: \(newTrack.title) by \(newTrack.artist)")
        return newTrack
    }
    
    // MARK: - Private Matching Methods
    
    private func findByAppleMusicId(_ appleMusicId: String) async -> UniversalTrack? {
        return await withCheckedContinuation { continuation in
            UniversalTrack.findByPlatformId(appleMusicId: appleMusicId) { track in
                continuation.resume(returning: track)
            }
        }
    }
    
    private func findBySpotifyId(_ spotifyId: String) async -> UniversalTrack? {
        return await withCheckedContinuation { continuation in
            UniversalTrack.findByPlatformId(spotifyId: spotifyId) { track in
                continuation.resume(returning: track)
            }
        }
    }
    
    private func findByISRC(_ isrcCode: String) async -> UniversalTrack? {
        return await withCheckedContinuation { continuation in
            let db = Firestore.firestore()
            db.collection("universalTracks")
                .whereField("isrcCode", isEqualTo: isrcCode)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ Error finding by ISRC: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let track = snapshot?.documents.first.flatMap { try? $0.data(as: UniversalTrack.self) }
                    continuation.resume(returning: track)
                }
        }
    }
    
    private func findBestMatch(
        title: String,
        artist: String,
        duration: TimeInterval? = nil
    ) async -> UniversalTrack? {
        
        return await withCheckedContinuation { continuation in
            let db = Firestore.firestore()
            
            // Search for potential matches using normalized artist name
            let normalizedArtist = UniversalTrack.normalizeText(artist)
            
            db.collection("universalTracks")
                .whereField("artist", isEqualTo: normalizedArtist)
                .limit(to: 10) // Get top 10 potential matches
                .getDocuments { snapshot, error in
                    
                    if let error = error {
                        print("❌ Error searching for matches: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    var bestMatch: UniversalTrack?
                    var bestScore = 0.0
                    
                    for document in documents {
                        if let track = try? document.data(as: UniversalTrack.self) {
                            let score = UniversalTrack.calculateMatchingScore(
                                title1: title, artist1: artist, duration1: duration,
                                title2: track.title, artist2: track.artist, duration2: track.duration
                            )
                            
                            if score > bestScore && score >= self.fuzzyMatchThreshold {
                                bestScore = score
                                bestMatch = track
                            }
                        }
                    }
                    
                    if let match = bestMatch {
                        print("🎯 Found fuzzy match: \(match.title) (score: \(String(format: "%.2f", bestScore)))")
                    }
                    
                    continuation.resume(returning: bestMatch)
                }
        }
    }
    
    private func createUniversalTrack(_ track: UniversalTrack) async {
        await withCheckedContinuation { continuation in
            UniversalTrack.create(track) { result in
                switch result {
                case .success():
                    print("✅ Universal track created successfully")
                case .failure(let error):
                    print("❌ Failed to create universal track: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
    
    private func updatePlatformId(
        universalId: String,
        appleMusicId: String? = nil,
        spotifyId: String? = nil,
        isrcCode: String? = nil
    ) async {
        let db = Firestore.firestore()
        var updateData: [String: Any] = ["lastUpdated": FieldValue.serverTimestamp()]
        
        if let appleId = appleMusicId {
            updateData["appleMusicId"] = appleId
        }
        if let spotifyId = spotifyId {
            updateData["spotifyId"] = spotifyId
        }
        if let isrc = isrcCode {
            updateData["isrcCode"] = isrc
        }
        
        do {
            try await db.collection("universalTracks").document(universalId).updateData(updateData)
            print("✅ Updated platform IDs for universal track: \(universalId)")
        } catch {
            print("❌ Failed to update platform IDs: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Batch Processing
    
    /// Process multiple tracks efficiently
    func processMultipleTracks(_ tracks: [(title: String, artist: String, appleMusicId: String?)]) async -> [UniversalTrack] {
        var results: [UniversalTrack] = []
        
        // Process in batches to avoid overwhelming Firestore
        let batchSize = 5
        for batch in tracks.chunked(into: batchSize) {
            let batchResults = await withTaskGroup(of: UniversalTrack.self) { group in
                var groupResults: [UniversalTrack] = []
                
                for track in batch {
                    group.addTask {
                        await self.getUniversalTrack(
                            title: track.title,
                            artist: track.artist,
                            appleMusicId: track.appleMusicId
                        )
                    }
                }
                
                for await result in group {
                    groupResults.append(result)
                }
                
                return groupResults
            }
            
            results.append(contentsOf: batchResults)
            
            // Small delay between batches
            if tracks.count > batchSize {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
        }
        
        return results
    }
}

// MARK: - Demo/Testing Methods

extension TrackMatchingService {
    
    /// Test the matching system with "Sicko Mode" example
    func testSickoModeMatching() async {
        print("🧪 Testing cross-platform matching with 'Sicko Mode'...")
        
        // Simulate Apple Music user
        let appleTrack = await getUniversalTrack(
            title: "SICKO MODE",
            artist: "Travis Scott",
            duration: 312.0,
            appleMusicId: "1445900472"
        )
        
        // Simulate Spotify user with slight variation
        let spotifyTrack = await getUniversalTrack(
            title: "sicko mode",
            artist: "Travis Scott",
            albumName: "ASTROWORLD",
            duration: 312.817,
            spotifyId: "2xLMifQCjDGFmkHkpNLD9h"
        )
        
        print("🎯 Apple Music Universal ID: \(appleTrack.id)")
        print("🎯 Spotify Universal ID: \(spotifyTrack.id)")
        print("✅ Same profile: \(appleTrack.id == spotifyTrack.id)")
    }
}
