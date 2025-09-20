import Foundation
import FirebaseFirestore

// MARK: - Music Taste Analyzer Service

@MainActor
class MusicTasteAnalyzer: ObservableObject {
    
    static let shared = MusicTasteAnalyzer()
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var userMusicProfilesCache: [String: UserMusicProfile] = [:]
    
    private init() {}
    
    // MARK: - User Music Profile
    
    struct UserMusicProfile {
        let userId: String
        let logs: [MusicLog]
        let artistFrequency: [String: Int]
        let genreFrequency: [String: Int]
        let averageRating: Double
        let ratingDistribution: [Int: Int] // rating -> count
        let totalLogs: Int
        let recentActivity: [MusicLog] // Last 30 days
        let topArtists: [String] // Most logged artists
        let topGenres: [String] // Most logged genres
        let musicDiversity: Double // 0.0-1.0, higher = more diverse taste
        
        init(userId: String, logs: [MusicLog]) {
            self.userId = userId
            self.logs = logs
            self.totalLogs = logs.count
            
            // Calculate artist frequency
            var artistFreq: [String: Int] = [:]
            for log in logs {
                artistFreq[log.artistName, default: 0] += 1
            }
            self.artistFrequency = artistFreq
            
            // Calculate genre frequency
            var genreFreq: [String: Int] = [:]
            for log in logs {
                if let primaryGenre = log.primaryGenre {
                    genreFreq[primaryGenre, default: 0] += 1
                }
                // Also count Apple Music genres
                if let genres = log.appleMusicGenres {
                    for genre in genres {
                        genreFreq[genre, default: 0] += 1
                    }
                }
            }
            self.genreFrequency = genreFreq
            
            // Calculate average rating
            let ratingsOnly = logs.compactMap { $0.rating }
            self.averageRating = ratingsOnly.isEmpty ? 0.0 : Double(ratingsOnly.reduce(0, +)) / Double(ratingsOnly.count)
            
            // Calculate rating distribution
            var ratingDist: [Int: Int] = [:]
            for rating in ratingsOnly {
                ratingDist[rating, default: 0] += 1
            }
            self.ratingDistribution = ratingDist
            
            // Get recent activity (last 30 days)
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            self.recentActivity = logs.filter { $0.dateLogged >= thirtyDaysAgo }
            
            // Get top artists (sorted by frequency)
            self.topArtists = artistFreq.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
            
            // Get top genres (sorted by frequency)
            self.topGenres = genreFreq.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
            
            // Calculate music diversity (Shannon diversity index)
            self.musicDiversity = Self.calculateDiversityIndex(artistFreq)
        }
        
        // Calculate Shannon diversity index for music taste diversity
        private static func calculateDiversityIndex(_ frequency: [String: Int]) -> Double {
            let total = frequency.values.reduce(0, +)
            guard total > 0 else { return 0.0 }
            
            var diversity = 0.0
            for count in frequency.values {
                let proportion = Double(count) / Double(total)
                if proportion > 0 {
                    diversity -= proportion * log2(proportion)
                }
            }
            
            // Normalize to 0.0-1.0 range
            let maxDiversity = log2(Double(frequency.count))
            return maxDiversity > 0 ? diversity / maxDiversity : 0.0
        }
    }
    
    // MARK: - Similarity Calculation
    
    /// Calculate comprehensive music taste similarity between two users
    func calculateSimilarity(between user1Id: String, and user2Id: String) async -> MusicTasteSimilarity? {
        do {
            // Get music profiles for both users
            guard let profile1 = await getUserMusicProfile(userId: user1Id),
                  let profile2 = await getUserMusicProfile(userId: user2Id) else {
                print("❌ Could not load music profiles for similarity calculation")
                return nil
            }
            
            // Calculate different similarity components
            let artistSimilarity = calculateArtistSimilarity(profile1, profile2)
            let genreSimilarity = calculateGenreSimilarity(profile1, profile2)
            let ratingCorrelation = calculateRatingCorrelation(profile1, profile2)
            let discoveryPotential = calculateDiscoveryPotential(profile1, profile2)
            
            // Calculate weighted overall score
            let overallScore = (artistSimilarity * 0.4) + 
                             (genreSimilarity * 0.3) + 
                             (ratingCorrelation * 0.2) + 
                             (discoveryPotential * 0.1)
            
            // Find shared artists and genres
            let sharedArtists = findSharedArtists(profile1, profile2)
            let sharedGenres = findSharedGenres(profile1, profile2)
            
            return MusicTasteSimilarity(
                user1Id: user1Id,
                user2Id: user2Id,
                overallScore: overallScore,
                artistSimilarity: artistSimilarity,
                genreSimilarity: genreSimilarity,
                ratingCorrelation: ratingCorrelation,
                discoveryPotential: discoveryPotential,
                sharedArtists: sharedArtists,
                sharedGenres: sharedGenres,
                analysisDate: Date()
            )
            
        } catch {
            print("❌ Error calculating music similarity: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Similarity Components
    
    /// Calculate artist overlap similarity using Jaccard coefficient
    private func calculateArtistSimilarity(_ profile1: UserMusicProfile, _ profile2: UserMusicProfile) -> Double {
        let artists1 = Set(profile1.topArtists)
        let artists2 = Set(profile2.topArtists)
        
        let intersection = artists1.intersection(artists2)
        let union = artists1.union(artists2)
        
        guard !union.isEmpty else { return 0.0 }
        
        // Basic Jaccard coefficient
        let jaccard = Double(intersection.count) / Double(union.count)
        
        // Weight by frequency of shared artists
        var weightedScore = jaccard
        for artist in intersection {
            let freq1 = profile1.artistFrequency[artist] ?? 0
            let freq2 = profile2.artistFrequency[artist] ?? 0
            let avgFreq = Double(freq1 + freq2) / 2.0
            
            // Boost score for frequently shared artists
            weightedScore += (avgFreq / Double(max(profile1.totalLogs, profile2.totalLogs))) * 0.1
        }
        
        return min(weightedScore, 1.0)
    }
    
    /// Calculate genre compatibility
    private func calculateGenreSimilarity(_ profile1: UserMusicProfile, _ profile2: UserMusicProfile) -> Double {
        let genres1 = Set(profile1.topGenres)
        let genres2 = Set(profile2.topGenres)
        
        let intersection = genres1.intersection(genres2)
        let union = genres1.union(genres2)
        
        guard !union.isEmpty else { return 0.0 }
        
        // Genre similarity with frequency weighting
        let jaccard = Double(intersection.count) / Double(union.count)
        
        var weightedScore = jaccard
        for genre in intersection {
            let freq1 = profile1.genreFrequency[genre] ?? 0
            let freq2 = profile2.genreFrequency[genre] ?? 0
            let avgFreq = Double(freq1 + freq2) / 2.0
            
            // Boost score for frequently shared genres
            weightedScore += (avgFreq / Double(max(profile1.totalLogs, profile2.totalLogs))) * 0.15
        }
        
        return min(weightedScore, 1.0)
    }
    
    /// Calculate rating correlation using Pearson correlation coefficient
    private func calculateRatingCorrelation(_ profile1: UserMusicProfile, _ profile2: UserMusicProfile) -> Double {
        // Find songs both users have rated
        var commonRatings: [(Double, Double)] = []
        
        for log1 in profile1.logs {
            guard let rating1 = log1.rating else { continue }
            
            // Look for same song in user2's logs
            for log2 in profile2.logs {
                guard let rating2 = log2.rating else { continue }
                
                // Check if it's the same song (by itemId or universalTrackId)
                let isSameSong = log1.itemId == log2.itemId || 
                               (log1.universalTrackId != nil && log1.universalTrackId == log2.universalTrackId) ||
                               (log1.title.lowercased() == log2.title.lowercased() && 
                                log1.artistName.lowercased() == log2.artistName.lowercased())
                
                if isSameSong {
                    commonRatings.append((Double(rating1), Double(rating2)))
                    break
                }
            }
        }
        
        guard commonRatings.count >= 3 else {
            // Not enough common ratings, use rating distribution similarity instead
            return calculateRatingDistributionSimilarity(profile1, profile2)
        }
        
        // Calculate Pearson correlation
        let n = Double(commonRatings.count)
        let sumX = commonRatings.map { $0.0 }.reduce(0, +)
        let sumY = commonRatings.map { $0.1 }.reduce(0, +)
        let sumXY = commonRatings.map { $0.0 * $0.1 }.reduce(0, +)
        let sumX2 = commonRatings.map { $0.0 * $0.0 }.reduce(0, +)
        let sumY2 = commonRatings.map { $0.1 * $0.1 }.reduce(0, +)
        
        let numerator = (n * sumXY) - (sumX * sumY)
        let denominator = sqrt(((n * sumX2) - (sumX * sumX)) * ((n * sumY2) - (sumY * sumY)))
        
        guard denominator != 0 else { return 0.0 }
        
        let correlation = numerator / denominator
        
        // Convert from -1,1 range to 0,1 range
        return (correlation + 1.0) / 2.0
    }
    
    /// Fallback rating similarity when not enough common songs
    private func calculateRatingDistributionSimilarity(_ profile1: UserMusicProfile, _ profile2: UserMusicProfile) -> Double {
        let avgRating1 = profile1.averageRating
        let avgRating2 = profile2.averageRating
        
        // Similarity based on average rating difference
        let ratingDiff = abs(avgRating1 - avgRating2)
        let avgRatingSimilarity = max(0.0, 1.0 - (ratingDiff / 4.0)) // Max diff is 4 (5-1)
        
        return avgRatingSimilarity * 0.7 // Lower weight since it's less precise
    }
    
    /// Calculate discovery potential (how much new music they could introduce to each other)
    private func calculateDiscoveryPotential(_ profile1: UserMusicProfile, _ profile2: UserMusicProfile) -> Double {
        let artists1 = Set(profile1.topArtists)
        let artists2 = Set(profile2.topArtists)
        
        let uniqueToUser1 = artists1.subtracting(artists2)
        let uniqueToUser2 = artists2.subtracting(artists1)
        
        let totalUniqueArtists = uniqueToUser1.count + uniqueToUser2.count
        let totalArtists = artists1.count + artists2.count
        
        guard totalArtists > 0 else { return 0.0 }
        
        // Higher score for more unique artists (more discovery potential)
        let discoveryRatio = Double(totalUniqueArtists) / Double(totalArtists)
        
        // Balance discovery with similarity (some overlap is good)
        let overlapRatio = Double(artists1.intersection(artists2).count) / Double(max(artists1.count, artists2.count))
        
        // Optimal discovery score balances uniqueness with some similarity
        return (discoveryRatio * 0.7) + (overlapRatio * 0.3)
    }
    
    // MARK: - Shared Content Analysis
    
    private func findSharedArtists(_ profile1: UserMusicProfile, _ profile2: UserMusicProfile) -> [MusicTasteSimilarity.SharedArtist] {
        let commonArtists = Set(profile1.topArtists).intersection(Set(profile2.topArtists))
        
        return commonArtists.map { artist in
            let user1Rating = calculateAverageRatingForArtist(artist, in: profile1)
            let user2Rating = calculateAverageRatingForArtist(artist, in: profile2)
            let commonSongs = countCommonSongs(forArtist: artist, profile1: profile1, profile2: profile2)
            
            return MusicTasteSimilarity.SharedArtist(
                name: artist,
                user1Rating: user1Rating,
                user2Rating: user2Rating,
                commonSongs: commonSongs
            )
        }.sorted { $0.commonSongs > $1.commonSongs }
    }
    
    private func findSharedGenres(_ profile1: UserMusicProfile, _ profile2: UserMusicProfile) -> [String] {
        return Array(Set(profile1.topGenres).intersection(Set(profile2.topGenres)))
            .sorted { genre1, genre2 in
                let freq1 = (profile1.genreFrequency[genre1] ?? 0) + (profile2.genreFrequency[genre1] ?? 0)
                let freq2 = (profile1.genreFrequency[genre2] ?? 0) + (profile2.genreFrequency[genre2] ?? 0)
                return freq1 > freq2
            }
    }
    
    private func calculateAverageRatingForArtist(_ artist: String, in profile: UserMusicProfile) -> Double? {
        let artistLogs = profile.logs.filter { $0.artistName == artist }
        let ratings = artistLogs.compactMap { $0.rating }
        
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
    
    private func countCommonSongs(forArtist artist: String, profile1: UserMusicProfile, profile2: UserMusicProfile) -> Int {
        let artist1Songs = Set(profile1.logs.filter { $0.artistName == artist }.map { $0.title.lowercased() })
        let artist2Songs = Set(profile2.logs.filter { $0.artistName == artist }.map { $0.title.lowercased() })
        
        return artist1Songs.intersection(artist2Songs).count
    }
    
    // MARK: - Data Loading
    
    /// Get or create user music profile
    private func getUserMusicProfile(userId: String) async -> UserMusicProfile? {
        // Check cache first
        if let cachedProfile = userMusicProfilesCache[userId] {
            return cachedProfile
        }
        
        // Load from Firestore
        do {
            let snapshot = try await db.collection("logs")
                .whereField("userId", isEqualTo: userId)
                .whereField("isPublic", in: [true, NSNull()]) // Only public logs for matchmaking
                .order(by: "dateLogged", descending: true)
                .limit(to: 200) // Limit for performance
                .getDocuments()
            
            let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            
            guard !logs.isEmpty else {
                print("⚠️ No music logs found for user: \(userId)")
                return nil
            }
            
            let profile = UserMusicProfile(userId: userId, logs: logs)
            
            // Cache the profile
            userMusicProfilesCache[userId] = profile
            
            print("✅ Loaded music profile for \(userId): \(logs.count) logs, \(profile.topArtists.count) top artists")
            return profile
            
        } catch {
            print("❌ Error loading music profile for \(userId): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clear cache (useful for testing or memory management)
    func clearCache() {
        userMusicProfilesCache.removeAll()
    }
    
    /// Preload music profiles for a batch of users (optimization for batch matching)
    func preloadMusicProfiles(userIds: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for userId in userIds {
                group.addTask {
                    _ = await self.getUserMusicProfile(userId: userId)
                }
            }
        }
    }
}

// MARK: - Batch Similarity Analysis

extension MusicTasteAnalyzer {
    
    /// Calculate similarity scores for one user against multiple candidates
    func calculateSimilarityBatch(forUser userId: String, againstCandidates candidateIds: [String]) async -> [String: Double] {
        var similarities: [String: Double] = [:]
        
        // Preload all profiles
        let allUserIds = [userId] + candidateIds
        await preloadMusicProfiles(userIds: allUserIds)
        
        // Calculate similarities
        for candidateId in candidateIds {
            if let similarity = await calculateSimilarity(between: userId, and: candidateId) {
                similarities[candidateId] = similarity.overallScore
            }
        }
        
        return similarities
    }
    
    /// Find the best matches for a user from a pool of candidates
    func findBestMatches(forUser userId: String, fromCandidates candidates: [String], limit: Int = 5, minimumScore: Double = 0.6) async -> [(userId: String, score: Double)] {
        let similarities = await calculateSimilarityBatch(forUser: userId, againstCandidates: candidates)
        
        return similarities
            .filter { $0.value >= minimumScore }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (userId: $0.key, score: $0.value) }
    }
}
