import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Music Matchmaking Service

@MainActor
class MusicMatchmakingService: ObservableObject {
    
    static let shared = MusicMatchmakingService()
    
    // MARK: - Published Properties
    
    @Published var isProcessingMatches = false
    @Published var lastProcessingTime: Date?
    @Published var processingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var weeklyStats: WeeklyMatchmakingStats?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private let tasteAnalyzer = MusicTasteAnalyzer.shared
    private let botService = MatchmakingBotService.shared
    
    private init() {}
    
    // MARK: - Main Matching Process
    
    /// Execute the weekly matchmaking process for all eligible users
    func executeWeeklyMatching() async {
        print("🎵 Starting weekly music matchmaking process...")
        
        isProcessingMatches = true
        processingProgress = 0.0
        errorMessage = nil
        
        let startTime = Date()
        let currentWeek = Date().weekId
        
        do {
            // Step 1: Get eligible users (10%)
            processingProgress = 0.1
            let eligibleUsers = try await getEligibleUsers()
            print("📊 Found \(eligibleUsers.count) eligible users for matchmaking")
            
            guard eligibleUsers.count >= 2 else {
                throw MatchmakingError.insufficientUsers
            }
            
            // Step 2: Filter by gender preferences (20%)
            processingProgress = 0.2
            let genderFilteredPairs = filterByGenderPreferences(eligibleUsers)
            print("💑 Created \(genderFilteredPairs.count) potential gender-compatible pairs")
            
            // Step 3: Calculate music similarities (60%)
            processingProgress = 0.3
            let similarityResults = await calculateSimilaritiesForPairs(genderFilteredPairs)
            print("🎼 Calculated \(similarityResults.count) similarity scores")
            
            // Step 4: Apply matching algorithm (80%)
            processingProgress = 0.8
            let matches = await applyMatchingAlgorithm(similarityResults, week: currentWeek)
            print("✨ Generated \(matches.count) final matches")
            
            // Step 5: Send bot messages (90%)
            processingProgress = 0.9
            await sendMatchingMessages(matches)
            
            // Step 6: Generate statistics (100%)
            processingProgress = 1.0
            let stats = generateWeeklyStats(matches: matches, eligibleUsers: eligibleUsers, processingTime: Date().timeIntervalSince(startTime))
            await saveWeeklyStats(stats)
            
            lastProcessingTime = Date()
            weeklyStats = stats
            
            print("✅ Weekly matchmaking complete! Generated \(matches.count) matches in \(String(format: "%.1f", stats.processingTime))s")
            
        } catch {
            print("❌ Weekly matchmaking failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isProcessingMatches = false
    }
    
    // MARK: - User Eligibility
    
    /// Get users who are eligible for matchmaking
    private func getEligibleUsers() async throws -> [UserProfile] {
        let query = db.collection("users")
            .whereField("matchmakingOptIn", isEqualTo: true)
        
        let snapshot = try await query.getDocuments()
        let users = snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
        
        // Filter for users with recent activity and sufficient music logs
        var eligibleUsers: [UserProfile] = []
        
        for user in users {
            // Check if user has sufficient music activity
            let hasRecentActivity = await checkUserHasRecentMusicActivity(userId: user.uid)
            let hasEnoughLogs = await checkUserHasMinimumLogs(userId: user.uid, minimum: 10)
            
            if hasRecentActivity && hasEnoughLogs {
                eligibleUsers.append(user)
            }
        }
        
        return eligibleUsers
    }
    
    private func checkUserHasRecentMusicActivity(userId: String) async -> Bool {
        do {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            let query = db.collection("logs")
                .whereField("userId", isEqualTo: userId)
                .whereField("dateLogged", isGreaterThan: thirtyDaysAgo)
                .limit(to: 1)
            
            let snapshot = try await query.getDocuments()
            return !snapshot.documents.isEmpty
            
        } catch {
            print("❌ Error checking recent activity for \(userId): \(error.localizedDescription)")
            return false
        }
    }
    
    private func checkUserHasMinimumLogs(userId: String, minimum: Int) async -> Bool {
        do {
            let query = db.collection("logs")
                .whereField("userId", isEqualTo: userId)
                .limit(to: minimum)
            
            let snapshot = try await query.getDocuments()
            return snapshot.documents.count >= minimum
            
        } catch {
            print("❌ Error checking log count for \(userId): \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Match Tracking
    
    /// Check if users have been matched recently (within cooldown period)
    private func hasRecentMatch(user1: String, user2: String) async -> Bool {
        let cooldownWeeks = 8 // Don't match same users within 8 weeks
        let cooldownDate = Calendar.current.date(byAdding: .weekOfYear, value: -cooldownWeeks, to: Date()) ?? Date()
        
        do {
            // Check both directions (user1->user2 and user2->user1)
            let snapshot1 = try await db.collection("weeklyMatches")
                .whereField("userId", isEqualTo: user1)
                .whereField("matchedUserId", isEqualTo: user2)
                .whereField("timestamp", isGreaterThan: cooldownDate)
                .limit(to: 1)
                .getDocuments()
            
            let snapshot2 = try await db.collection("weeklyMatches")
                .whereField("userId", isEqualTo: user2)
                .whereField("matchedUserId", isEqualTo: user1)
                .whereField("timestamp", isGreaterThan: cooldownDate)
                .limit(to: 1)
                .getDocuments()
            
            return !snapshot1.documents.isEmpty || !snapshot2.documents.isEmpty
        } catch {
            print("❌ Error checking recent matches: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Track a new match to prevent future duplicates
    private func trackNewMatch(user1: String, user2: String, similarity: MusicTasteSimilarity) async {
        let week = getCurrentWeekId()
        
        // Create match records for both users
        let match1 = WeeklyMatch(
            userId: user1,
            matchedUserId: user2,
            week: week,
            similarityScore: similarity.overallScore,
            sharedArtists: similarity.sharedArtists.map { $0.name },
            sharedGenres: similarity.sharedGenres
        )
        
        let match2 = WeeklyMatch(
            userId: user2,
            matchedUserId: user1,
            week: week,
            similarityScore: similarity.overallScore,
            sharedArtists: similarity.sharedArtists.map { $0.name },
            sharedGenres: similarity.sharedGenres
        )
        
        do {
            // Save both match records
            try await db.collection("weeklyMatches").document(match1.id).setData(from: match1)
            try await db.collection("weeklyMatches").document(match2.id).setData(from: match2)
            
            print("✅ Tracked new match: \(user1) ↔ \(user2)")
        } catch {
            print("❌ Error tracking new match: \(error.localizedDescription)")
        }
    }
    
    /// Get current week identifier in format "YYYY-WXX"
    private func getCurrentWeekId() -> String {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.yearForWeekOfYear, from: now)
        let week = calendar.component(.weekOfYear, from: now)
        return String(format: "%d-W%02d", year, week)
    }
    
    // MARK: - Gender Filtering
    
    /// Filter users into compatible pairs based on gender preferences
    private func filterByGenderPreferences(_ users: [UserProfile]) -> [(UserProfile, UserProfile)] {
        var compatiblePairs: [(UserProfile, UserProfile)] = []
        
        for i in 0..<users.count {
            for j in (i+1)..<users.count {
                let user1 = users[i]
                let user2 = users[j]
                
                if areGenderCompatible(user1, user2) {
                    compatiblePairs.append((user1, user2))
                }
            }
        }
        
        return compatiblePairs
    }
    
    private func areGenderCompatible(_ user1: UserProfile, _ user2: UserProfile) -> Bool {
        let user1Gender = user1.matchmakingGender ?? "any"
        let user2Gender = user2.matchmakingGender ?? "any"
        let user1Preference = user1.matchmakingPreferredGender ?? "any"
        let user2Preference = user2.matchmakingPreferredGender ?? "any"
        
        // Check if user1's preference matches user2's gender
        let user1Compatible = user1Preference == "any" || user1Preference == user2Gender
        
        // Check if user2's preference matches user1's gender
        let user2Compatible = user2Preference == "any" || user2Preference == user1Gender
        
        return user1Compatible && user2Compatible
    }
    
    // MARK: - Similarity Calculation
    
    private func calculateSimilaritiesForPairs(_ pairs: [(UserProfile, UserProfile)]) async -> [(pair: (UserProfile, UserProfile), similarity: MusicTasteSimilarity)] {
        var results: [(pair: (UserProfile, UserProfile), similarity: MusicTasteSimilarity)] = []
        let totalPairs = pairs.count
        
        for (index, pair) in pairs.enumerated() {
            // Update progress
            let pairProgress = Double(index) / Double(totalPairs)
            processingProgress = 0.3 + (pairProgress * 0.5) // 30% to 80%
            
            if let similarity = await tasteAnalyzer.calculateSimilarity(between: pair.0.uid, and: pair.1.uid) {
                results.append((pair: pair, similarity: similarity))
            }
            
            // Small delay to prevent overwhelming the system
            if index % 10 == 0 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        return results
    }
    
    // MARK: - Matching Algorithm
    
    /// Apply the matching algorithm to select final matches
    private func applyMatchingAlgorithm(_ similarityResults: [(pair: (UserProfile, UserProfile), similarity: MusicTasteSimilarity)], week: String) async -> [WeeklyMatch] {
        
        // Filter by minimum similarity threshold
        let qualifyingPairs = similarityResults.filter { $0.similarity.overallScore >= 0.6 }
        
        // Sort by similarity score (highest first)
        let sortedPairs = qualifyingPairs.sorted { $0.similarity.overallScore > $1.similarity.overallScore }
        
        // Apply match selection algorithm to avoid conflicts
        var finalMatches: [WeeklyMatch] = []
        var matchedUserIds: Set<String> = []
        
        // Get previous matches to avoid duplicates
        let previousMatches = await getPreviousMatches(weeks: 8) // 8-week cooldown
        let previousMatchPairs = Set(previousMatches.map { "\($0.userId)_\($0.matchedUserId)" })
        
        for result in sortedPairs {
            let user1 = result.pair.0
            let user2 = result.pair.1
            let similarity = result.similarity
            
            // Skip if either user is already matched this week
            if matchedUserIds.contains(user1.uid) || matchedUserIds.contains(user2.uid) {
                continue
            }
            
            // Skip if they've been matched recently
            let pairKey1 = "\(user1.uid)_\(user2.uid)"
            let pairKey2 = "\(user2.uid)_\(user1.uid)"
            if previousMatchPairs.contains(pairKey1) || previousMatchPairs.contains(pairKey2) {
                continue
            }
            
            // Create matches for both users
            let match1 = WeeklyMatch(
                userId: user1.uid,
                matchedUserId: user2.uid,
                week: week,
                similarityScore: similarity.overallScore,
                sharedArtists: similarity.sharedArtists.map { $0.name },
                sharedGenres: similarity.sharedGenres
            )
            
            let match2 = WeeklyMatch(
                userId: user2.uid,
                matchedUserId: user1.uid,
                week: week,
                similarityScore: similarity.overallScore,
                sharedArtists: similarity.sharedArtists.map { $0.name },
                sharedGenres: similarity.sharedGenres
            )
            
            finalMatches.append(match1)
            finalMatches.append(match2)
            
            matchedUserIds.insert(user1.uid)
            matchedUserIds.insert(user2.uid)
        }
        
        // Save matches to database
        for match in finalMatches {
            do {
                try await db.collection("weeklyMatches").document(match.id).setData(from: match)
            } catch {
                print("❌ Error saving match \(match.id): \(error.localizedDescription)")
            }
        }
        
        return finalMatches
    }
    
    private func getPreviousMatches(weeks: Int) async -> [WeeklyMatch] {
        do {
            let weeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()
            
            let query = db.collection("weeklyMatches")
                .whereField("timestamp", isGreaterThan: weeksAgo)
            
            let snapshot = try await query.getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: WeeklyMatch.self) }
            
        } catch {
            print("❌ Error fetching previous matches: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Bot Messaging
    
    private func sendMatchingMessages(_ matches: [WeeklyMatch]) async {
        let uniqueMatches = Dictionary(grouping: matches) { $0.userId }.mapValues { $0.first! }
        
        for (_, match) in uniqueMatches {
            do {
                // Get matched user profile
                let matchedUserDoc = try await db.collection("users").document(match.matchedUserId).getDocument()
                guard let matchedUser = try? matchedUserDoc.data(as: UserProfile.self) else {
                    print("❌ Could not load matched user profile: \(match.matchedUserId)")
                    continue
                }
                
                // Send bot message
                await botService.sendMatchmakingMessage(
                    to: match.userId,
                    matchedUser: matchedUser,
                    sharedInterests: match.sharedArtists
                ) { error in
                    if let error = error {
                        print("❌ Error sending match message to \(match.userId): \(error.localizedDescription)")
                    } else {
                        print("✅ Sent match message to \(match.userId)")
                    }
                }
                
                // Mark message as sent
                try await db.collection("weeklyMatches").document(match.id).updateData([
                    "botMessageSent": true
                ])
                
            } catch {
                print("❌ Error processing match message for \(match.userId): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Statistics
    
    private func generateWeeklyStats(matches: [WeeklyMatch], eligibleUsers: [UserProfile], processingTime: TimeInterval) -> WeeklyMatchmakingStats {
        let week = Date().weekId
        let uniqueMatches = matches.count / 2 // Each match is stored twice
        
        let averageSimilarity = matches.isEmpty ? 0.0 : matches.map { $0.similarityScore }.reduce(0, +) / Double(matches.count)
        
        // Get top shared artists and genres
        let allSharedArtists = matches.flatMap { $0.sharedArtists }
        let allSharedGenres = matches.flatMap { $0.sharedGenres }
        
        let topArtists = Dictionary(grouping: allSharedArtists) { $0 }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        let topGenres = Dictionary(grouping: allSharedGenres) { $0 }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        
        let stats = WeeklyMatchmakingStats(
            week: week,
            totalEligibleUsers: eligibleUsers.count,
            totalMatches: uniqueMatches,
            averageSimilarityScore: averageSimilarity,
            responseRate: 0.0, // Will be calculated later based on user responses
            successRate: 0.0, // Will be calculated later based on connections
            topSharedArtists: Array(topArtists),
            topSharedGenres: Array(topGenres),
            processingTime: processingTime
        )
        
        return stats
    }
    
    private func saveWeeklyStats(_ stats: WeeklyMatchmakingStats) async {
        do {
            try await db.collection("matchmakingStats").document(stats.id).setData(from: stats)
            print("✅ Saved weekly matchmaking statistics")
        } catch {
            print("❌ Error saving weekly stats: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Manual Testing
    
    /// Test the matching algorithm with a specific user
    func testMatchingForUser(_ userId: String, candidateLimit: Int = 10) async -> [(userId: String, score: Double)] {
        do {
            let eligibleUsers = try await getEligibleUsers()
            let candidates = eligibleUsers.filter { $0.uid != userId }.map { $0.uid }
            
            return await tasteAnalyzer.findBestMatches(
                forUser: userId,
                fromCandidates: Array(candidates.prefix(candidateLimit)),
                limit: 5,
                minimumScore: 0.5
            )
        } catch {
            print("❌ Error testing matches for user: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Error Types

enum MatchmakingError: LocalizedError {
    case insufficientUsers
    case noEligibleMatches
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .insufficientUsers:
            return "Not enough users for matchmaking (minimum 2 required)"
        case .noEligibleMatches:
            return "No eligible matches found with sufficient similarity scores"
        case .processingFailed(let message):
            return "Matchmaking processing failed: \(message)"
        }
    }
}
