import Foundation

// MARK: - Advanced Music Similarity Scoring

struct MusicSimilarityScoring {
    
    // MARK: - Scoring Weights Configuration
    
    struct ScoringWeights {
        let artistOverlap: Double = 0.35        // Shared favorite artists
        let genreCompatibility: Double = 0.25   // Genre similarity
        let ratingCorrelation: Double = 0.20    // How similarly they rate music
        let discoveryPotential: Double = 0.10   // New music they could share
        let activityRecency: Double = 0.05      // Recent music activity
        let diversityBalance: Double = 0.05     // Balance of music taste diversity
        
        var total: Double {
            return artistOverlap + genreCompatibility + ratingCorrelation + 
                   discoveryPotential + activityRecency + diversityBalance
        }
        
        init() {
            assert(abs(total - 1.0) < 0.01, "Scoring weights must sum to 1.0")
        }
    }
    
    // MARK: - Advanced Similarity Metrics
    
    /// Calculate Cosine Similarity for artist preferences
    static func calculateCosineSimilarity(vector1: [String: Double], vector2: [String: Double]) -> Double {
        let allKeys = Set(vector1.keys).union(Set(vector2.keys))
        
        var dotProduct = 0.0
        var magnitude1 = 0.0
        var magnitude2 = 0.0
        
        for key in allKeys {
            let value1 = vector1[key] ?? 0.0
            let value2 = vector2[key] ?? 0.0
            
            dotProduct += value1 * value2
            magnitude1 += value1 * value1
            magnitude2 += value2 * value2
        }
        
        let denominator = sqrt(magnitude1) * sqrt(magnitude2)
        return denominator > 0 ? dotProduct / denominator : 0.0
    }
    
    /// Calculate TF-IDF weighted artist similarity
    static func calculateTFIDFArtistSimilarity(profile1: MusicTasteAnalyzer.UserMusicProfile, 
                                             profile2: MusicTasteAnalyzer.UserMusicProfile,
                                             globalArtistFrequency: [String: Int]) -> Double {
        
        let totalUsers = globalArtistFrequency.values.reduce(0, +)
        
        // Create TF-IDF vectors for both users
        var vector1: [String: Double] = [:]
        var vector2: [String: Double] = [:]
        
        // Calculate TF-IDF for user1
        for (artist, frequency) in profile1.artistFrequency {
            let tf = Double(frequency) / Double(profile1.totalLogs)
            let df = Double(globalArtistFrequency[artist] ?? 1)
            let idf = log(Double(totalUsers) / df)
            vector1[artist] = tf * idf
        }
        
        // Calculate TF-IDF for user2
        for (artist, frequency) in profile2.artistFrequency {
            let tf = Double(frequency) / Double(profile2.totalLogs)
            let df = Double(globalArtistFrequency[artist] ?? 1)
            let idf = log(Double(totalUsers) / df)
            vector2[artist] = tf * idf
        }
        
        return calculateCosineSimilarity(vector1: vector1, vector2: vector2)
    }
    
    /// Calculate temporal similarity (how recent activity aligns)
    static func calculateTemporalSimilarity(profile1: MusicTasteAnalyzer.UserMusicProfile,
                                          profile2: MusicTasteAnalyzer.UserMusicProfile) -> Double {
        
        let recent1 = profile1.recentActivity
        let recent2 = profile2.recentActivity
        
        guard !recent1.isEmpty && !recent2.isEmpty else { return 0.0 }
        
        // Group recent activity by week
        let calendar = Calendar.current
        
        let weeks1 = Dictionary(grouping: recent1) { log in
            calendar.component(.weekOfYear, from: log.dateLogged)
        }
        
        let weeks2 = Dictionary(grouping: recent2) { log in
            calendar.component(.weekOfYear, from: log.dateLogged)
        }
        
        // Calculate overlap in active weeks
        let activeWeeks1 = Set(weeks1.keys)
        let activeWeeks2 = Set(weeks2.keys)
        let commonWeeks = activeWeeks1.intersection(activeWeeks2)
        let totalWeeks = activeWeeks1.union(activeWeeks2)
        
        guard !totalWeeks.isEmpty else { return 0.0 }
        
        return Double(commonWeeks.count) / Double(totalWeeks.count)
    }
    
    /// Calculate genre diversity compatibility
    static func calculateGenreDiversityCompatibility(profile1: MusicTasteAnalyzer.UserMusicProfile,
                                                   profile2: MusicTasteAnalyzer.UserMusicProfile) -> Double {
        
        let diversity1 = profile1.musicDiversity
        let diversity2 = profile2.musicDiversity
        
        // Users with similar diversity levels are more compatible
        let diversityDiff = abs(diversity1 - diversity2)
        let diversitySimilarity = max(0.0, 1.0 - diversityDiff)
        
        // Bonus for both users having high diversity (discovery potential)
        let averageDiversity = (diversity1 + diversity2) / 2.0
        let diversityBonus = averageDiversity > 0.7 ? 0.1 : 0.0
        
        return min(1.0, diversitySimilarity + diversityBonus)
    }
    
    /// Calculate listening intensity compatibility
    static func calculateListeningIntensityCompatibility(profile1: MusicTasteAnalyzer.UserMusicProfile,
                                                        profile2: MusicTasteAnalyzer.UserMusicProfile) -> Double {
        
        let intensity1 = Double(profile1.totalLogs) / max(1.0, Date().timeIntervalSince(profile1.logs.first?.dateLogged ?? Date()) / 86400)
        let intensity2 = Double(profile2.totalLogs) / max(1.0, Date().timeIntervalSince(profile2.logs.first?.dateLogged ?? Date()) / 86400)
        
        // Users with similar logging intensity are more compatible
        let maxIntensity = max(intensity1, intensity2)
        let minIntensity = min(intensity1, intensity2)
        
        guard maxIntensity > 0 else { return 0.0 }
        
        return minIntensity / maxIntensity
    }
    
    /// Calculate rating pattern similarity
    static func calculateRatingPatternSimilarity(profile1: MusicTasteAnalyzer.UserMusicProfile,
                                                profile2: MusicTasteAnalyzer.UserMusicProfile) -> Double {
        
        // Compare rating distributions
        let ratings1 = profile1.ratingDistribution
        let ratings2 = profile2.ratingDistribution
        
        var similarity = 0.0
        let allRatings = Set(ratings1.keys).union(Set(ratings2.keys))
        
        for rating in allRatings {
            let freq1 = Double(ratings1[rating] ?? 0)
            let freq2 = Double(ratings2[rating] ?? 0)
            let total1 = Double(ratings1.values.reduce(0, +))
            let total2 = Double(ratings2.values.reduce(0, +))
            
            if total1 > 0 && total2 > 0 {
                let prop1 = freq1 / total1
                let prop2 = freq2 / total2
                similarity += 1.0 - abs(prop1 - prop2)
            }
        }
        
        return similarity / Double(allRatings.count)
    }
    
    // MARK: - Composite Scoring
    
    /// Calculate comprehensive similarity score using all factors
    static func calculateComprehensiveSimilarity(profile1: MusicTasteAnalyzer.UserMusicProfile,
                                               profile2: MusicTasteAnalyzer.UserMusicProfile,
                                               globalArtistFrequency: [String: Int] = [:],
                                               weights: ScoringWeights = ScoringWeights()) -> Double {
        
        // Basic similarities
        let artistSimilarity = calculateBasicArtistSimilarity(profile1, profile2)
        let genreSimilarity = calculateBasicGenreSimilarity(profile1, profile2)
        let ratingCorrelation = calculateRatingPatternSimilarity(profile1: profile1, profile2: profile2)
        
        // Advanced similarities
        let discoveryPotential = calculateDiscoveryPotential(profile1, profile2)
        let temporalSimilarity = calculateTemporalSimilarity(profile1: profile1, profile2: profile2)
        let diversityCompatibility = calculateGenreDiversityCompatibility(profile1: profile1, profile2: profile2)
        
        // Weighted combination
        let score = (artistSimilarity * weights.artistOverlap) +
                   (genreSimilarity * weights.genreCompatibility) +
                   (ratingCorrelation * weights.ratingCorrelation) +
                   (discoveryPotential * weights.discoveryPotential) +
                   (temporalSimilarity * weights.activityRecency) +
                   (diversityCompatibility * weights.diversityBalance)
        
        return min(1.0, max(0.0, score))
    }
    
    // MARK: - Helper Methods
    
    private static func calculateBasicArtistSimilarity(_ profile1: MusicTasteAnalyzer.UserMusicProfile,
                                                      _ profile2: MusicTasteAnalyzer.UserMusicProfile) -> Double {
        let artists1 = Set(profile1.topArtists)
        let artists2 = Set(profile2.topArtists)
        
        let intersection = artists1.intersection(artists2)
        let union = artists1.union(artists2)
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    private static func calculateBasicGenreSimilarity(_ profile1: MusicTasteAnalyzer.UserMusicProfile,
                                                     _ profile2: MusicTasteAnalyzer.UserMusicProfile) -> Double {
        let genres1 = Set(profile1.topGenres)
        let genres2 = Set(profile2.topGenres)
        
        let intersection = genres1.intersection(genres2)
        let union = genres1.union(genres2)
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    private static func calculateDiscoveryPotential(_ profile1: MusicTasteAnalyzer.UserMusicProfile,
                                                   _ profile2: MusicTasteAnalyzer.UserMusicProfile) -> Double {
        let artists1 = Set(profile1.topArtists)
        let artists2 = Set(profile2.topArtists)
        
        let uniqueToUser1 = artists1.subtracting(artists2)
        let uniqueToUser2 = artists2.subtracting(artists1)
        let sharedArtists = artists1.intersection(artists2)
        
        // Good discovery potential = some shared taste + unique content
        let sharedRatio = Double(sharedArtists.count) / Double(max(artists1.count, artists2.count))
        let uniqueRatio = Double(uniqueToUser1.count + uniqueToUser2.count) / Double(artists1.count + artists2.count)
        
        // Optimal balance: 30-70% shared, 30-70% unique
        let sharedScore = sharedRatio >= 0.3 && sharedRatio <= 0.7 ? 1.0 : max(0.0, 1.0 - abs(0.5 - sharedRatio) * 2.0)
        let uniqueScore = uniqueRatio >= 0.3 && uniqueRatio <= 0.7 ? 1.0 : max(0.0, 1.0 - abs(0.5 - uniqueRatio) * 2.0)
        
        return (sharedScore + uniqueScore) / 2.0
    }
}

// MARK: - Similarity Caching

class SimilarityCache {
    private var cache: [String: (similarity: Double, timestamp: Date)] = [:]
    private let cacheExpirationTime: TimeInterval = 86400 * 7 // 1 week
    
    func getCachedSimilarity(user1: String, user2: String) -> Double? {
        let key = makeCacheKey(user1: user1, user2: user2)
        
        if let cached = cache[key] {
            // Check if cache is still valid
            if Date().timeIntervalSince(cached.timestamp) < cacheExpirationTime {
                return cached.similarity
            } else {
                // Remove expired cache entry
                cache.removeValue(forKey: key)
            }
        }
        
        return nil
    }
    
    func cacheSimilarity(user1: String, user2: String, similarity: Double) {
        let key = makeCacheKey(user1: user1, user2: user2)
        cache[key] = (similarity: similarity, timestamp: Date())
    }
    
    private func makeCacheKey(user1: String, user2: String) -> String {
        // Ensure consistent key regardless of parameter order
        let sortedUsers = [user1, user2].sorted()
        return "\(sortedUsers[0])_\(sortedUsers[1])"
    }
    
    func clearCache() {
        cache.removeAll()
    }
    
    func clearExpiredEntries() {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < cacheExpirationTime }
    }
}

// MARK: - Batch Processing Optimizations

extension MusicSimilarityScoring {
    
    /// Optimize similarity calculations for batch processing
    static func calculateBatchSimilarities(profiles: [MusicTasteAnalyzer.UserMusicProfile],
                                         cache: SimilarityCache = SimilarityCache()) -> [[Double]] {
        let count = profiles.count
        var similarityMatrix = Array(repeating: Array(repeating: 0.0, count: count), count: count)
        
        // Calculate global artist frequency for TF-IDF
        var globalArtistFreq: [String: Int] = [:]
        for profile in profiles {
            for (artist, _) in profile.artistFrequency {
                globalArtistFreq[artist, default: 0] += 1
            }
        }
        
        // Calculate similarities
        for i in 0..<count {
            for j in (i+1)..<count {
                let profile1 = profiles[i]
                let profile2 = profiles[j]
                
                // Check cache first
                if let cachedSimilarity = cache.getCachedSimilarity(user1: profile1.userId, user2: profile2.userId) {
                    similarityMatrix[i][j] = cachedSimilarity
                    similarityMatrix[j][i] = cachedSimilarity
                } else {
                    // Calculate new similarity
                    let similarity = calculateComprehensiveSimilarity(
                        profile1: profile1,
                        profile2: profile2,
                        globalArtistFrequency: globalArtistFreq
                    )
                    
                    similarityMatrix[i][j] = similarity
                    similarityMatrix[j][i] = similarity
                    
                    // Cache the result
                    cache.cacheSimilarity(user1: profile1.userId, user2: profile2.userId, similarity: similarity)
                }
            }
        }
        
        return similarityMatrix
    }
}
