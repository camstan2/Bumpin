import Foundation
import FirebaseFirestore

// MARK: - Social Scoring Data Models

/// Represents a social interaction between users that can be rated
struct SocialInteraction: Identifiable, Codable {
    let id: String
    let participantIds: [String] // All users involved in the interaction
    let interactionType: InteractionType
    let context: InteractionContext
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval? // Calculated duration in seconds
    let isRatingEligible: Bool // Whether this interaction qualifies for rating
    let createdAt: Date
    
    enum InteractionType: String, Codable, CaseIterable {
        case discussion = "discussion"
        case party = "party"
        case randomChat = "random_chat"
        
        var displayName: String {
            switch self {
            case .discussion: return "Discussion"
            case .party: return "Party"
            case .randomChat: return "Random Chat"
            }
        }
    }
    
    struct InteractionContext: Codable {
        let chatId: String? // Reference to the chat/party ID
        let topic: String? // Discussion topic if applicable
        let groupSize: Int // Number of participants
        let wasRandom: Bool // Whether users met randomly (not friends)
    }
    
    init(
        participantIds: [String],
        interactionType: InteractionType,
        context: InteractionContext,
        startTime: Date = Date()
    ) {
        self.id = UUID().uuidString
        self.participantIds = participantIds
        self.interactionType = interactionType
        self.context = context
        self.startTime = startTime
        self.endTime = nil
        self.duration = nil
        self.isRatingEligible = context.wasRandom && participantIds.count >= 2
        self.createdAt = Date()
    }
}

/// Individual rating given by one user to another after an interaction
struct SocialRating: Identifiable, Codable {
    let id: String
    let interactionId: String // Reference to the SocialInteraction
    let raterId: String // User giving the rating
    let ratedUserId: String // User being rated
    let rating: Int // 1-10 scale
    let comment: String? // Optional feedback comment
    let isAnonymous: Bool // Whether the rating is anonymous
    let interactionType: SocialInteraction.InteractionType // Type of interaction
    let interactionContext: String? // Context description
    let isVisible: Bool // Whether the rating is visible to the rated user
    let createdAt: Date
    let updatedAt: Date
    
    init(
        interactionId: String,
        raterId: String,
        ratedUserId: String,
        rating: Int,
        comment: String? = nil,
        isAnonymous: Bool = true,
        interactionType: SocialInteraction.InteractionType = .discussion,
        interactionContext: String? = nil,
        isVisible: Bool = false
    ) {
        self.id = "\(interactionId)_\(raterId)_\(ratedUserId)"
        self.interactionId = interactionId
        self.raterId = raterId
        self.ratedUserId = ratedUserId
        self.rating = max(1, min(10, rating)) // Clamp to 1-10 range
        self.comment = comment
        self.isAnonymous = isAnonymous
        self.interactionType = interactionType
        self.interactionContext = interactionContext
        self.isVisible = isVisible
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// Aggregated social score data for a user
struct SocialScore: Identifiable, Codable {
    let id: String // Same as userId
    let userId: String
    var overallScore: Double // Weighted average of all ratings
    var totalRatings: Int // Total number of ratings received
    var ratingsBreakdown: [Int: Int] // Count of each rating (1-10)
    var recentScore: Double // Score from last 30 days
    var scoreHistory: [ScoreSnapshot] // Historical score data
    var badges: [SocialBadge] // Earned social badges
    var lastUpdated: Date
    var createdAt: Date
    
    struct ScoreSnapshot: Codable {
        let date: Date
        let score: Double
        let ratingCount: Int
    }
    
    struct SocialBadge: Codable, Equatable {
        let id: String
        let name: String
        let description: String
        let iconName: String
        var earnedAt: Date
        let requirements: BadgeRequirements
        
        struct BadgeRequirements: Codable, Equatable {
            let minScore: Double?
            let minRatings: Int?
            let specificAchievement: String?
        }
    }
    
    init(userId: String) {
        self.id = userId
        self.userId = userId
        self.overallScore = 0.0
        self.totalRatings = 0
        self.ratingsBreakdown = [:]
        self.recentScore = 0.0
        self.scoreHistory = []
        self.badges = []
        self.lastUpdated = Date()
        self.createdAt = Date()
    }
    
    /// Calculate weighted average score with time decay
    mutating func updateScore(with newRating: Int, ratingDate: Date = Date()) {
        // Update ratings breakdown
        ratingsBreakdown[newRating, default: 0] += 1
        totalRatings += 1
        
        // Calculate new weighted average
        let timeWeight = calculateTimeWeight(for: ratingDate)
        let weightedRating = Double(newRating) * timeWeight
        
        if overallScore == 0.0 {
            overallScore = Double(newRating)
        } else {
            // Weighted moving average
            let alpha = 0.1 // Smoothing factor
            overallScore = (1 - alpha) * overallScore + alpha * weightedRating
        }
        
        // Update recent score (last 30 days)
        updateRecentScore()
        
        // Add score snapshot
        addScoreSnapshot()
        
        // Check for new badges
        checkAndAwardBadges()
        
        lastUpdated = Date()
    }
    
    private func calculateTimeWeight(for date: Date) -> Double {
        let daysSince = Date().timeIntervalSince(date) / (24 * 3600)
        return max(0.5, 1.0 - (daysSince / 365.0)) // Decay over a year, minimum 0.5 weight
    }
    
    private mutating func updateRecentScore() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentSnapshots = scoreHistory.filter { $0.date >= thirtyDaysAgo }
        
        if !recentSnapshots.isEmpty {
            let totalScore = recentSnapshots.reduce(0.0) { $0 + ($1.score * Double($1.ratingCount)) }
            let totalCount = recentSnapshots.reduce(0) { $0 + $1.ratingCount }
            recentScore = totalCount > 0 ? totalScore / Double(totalCount) : overallScore
        } else {
            recentScore = overallScore
        }
    }
    
    private mutating func addScoreSnapshot() {
        let snapshot = ScoreSnapshot(
            date: Date(),
            score: overallScore,
            ratingCount: totalRatings
        )
        scoreHistory.append(snapshot)
        
        // Keep only last 365 days of history
        let oneYearAgo = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        scoreHistory = scoreHistory.filter { $0.date >= oneYearAgo }
    }
    
    private mutating func checkAndAwardBadges() {
        let availableBadges = SocialBadge.availableBadges
        let currentBadgeIds = Set(badges.map { $0.id })
        
        for badge in availableBadges {
            guard !currentBadgeIds.contains(badge.id) else { continue }
            
            if meetsRequirements(for: badge) {
                var newBadge = badge
                newBadge.earnedAt = Date()
                badges.append(newBadge)
            }
        }
    }
    
    private func meetsRequirements(for badge: SocialBadge) -> Bool {
        let req = badge.requirements
        
        if let minScore = req.minScore, overallScore < minScore {
            return false
        }
        
        if let minRatings = req.minRatings, totalRatings < minRatings {
            return false
        }
        
        // Add specific achievement checks here
        if let achievement = req.specificAchievement {
            switch achievement {
            case "perfect_week":
                return hasRecentPerfectRatings(days: 7)
            case "social_butterfly":
                return totalRatings >= 50 && overallScore >= 8.0
            default:
                return false
            }
        }
        
        return true
    }
    
    private func hasRecentPerfectRatings(days: Int) -> Bool {
        let targetDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentSnapshots = scoreHistory.filter { $0.date >= targetDate }
        return recentSnapshots.allSatisfy { $0.score >= 9.0 }
    }
}

// MARK: - Badge System Extensions

extension SocialScore.SocialBadge {
    static func createAvailableBadge(
        id: String,
        name: String,
        description: String,
        iconName: String,
        minScore: Double? = nil,
        minRatings: Int? = nil,
        specificAchievement: String? = nil
    ) -> SocialScore.SocialBadge {
        return SocialScore.SocialBadge(
            id: id,
            name: name,
            description: description,
            iconName: iconName,
            earnedAt: Date(), // This will be updated when the badge is actually earned
            requirements: BadgeRequirements(
                minScore: minScore,
                minRatings: minRatings,
                specificAchievement: specificAchievement
            )
        )
    }
    
    static var availableBadges: [SocialScore.SocialBadge] {
        return [
            createAvailableBadge(
                id: "first_rating",
                name: "First Impression",
                description: "Received your first social rating",
                iconName: "star.fill",
                minRatings: 1
            ),
            createAvailableBadge(
                id: "social_starter",
                name: "Social Starter",
                description: "Received 10 social ratings",
                iconName: "person.2.fill",
                minRatings: 10
            ),
            createAvailableBadge(
                id: "crowd_favorite",
                name: "Crowd Favorite",
                description: "Maintain an 8+ rating with 25+ ratings",
                iconName: "heart.fill",
                minScore: 8.0,
                minRatings: 25
            ),
            createAvailableBadge(
                id: "social_butterfly",
                name: "Social Butterfly",
                description: "Excel in social interactions",
                iconName: "sparkles",
                minScore: 8.0,
                minRatings: 50,
                specificAchievement: "social_butterfly"
            ),
            createAvailableBadge(
                id: "perfect_week",
                name: "Perfect Week",
                description: "Maintain 9+ rating for a full week",
                iconName: "crown.fill",
                minScore: 9.0,
                minRatings: 5,
                specificAchievement: "perfect_week"
            )
        ]
    }
}

// MARK: - Rating Prompt Data

/// Data structure for managing rating prompts and mutual visibility
struct RatingPrompt: Identifiable, Codable {
    let id: String
    let interactionId: String
    let promptedUserId: String // User being asked to rate
    let targetUserId: String // User to be rated
    let interactionType: SocialInteraction.InteractionType
    let interactionContext: String // Brief description of the interaction
    let isShown: Bool
    let isCompleted: Bool
    let isSkipped: Bool
    let createdAt: Date
    let expiresAt: Date // Prompts expire after 24 hours
    
    init(
        interactionId: String,
        promptedUserId: String,
        targetUserId: String,
        interactionType: SocialInteraction.InteractionType,
        interactionContext: String
    ) {
        self.id = "\(interactionId)_\(promptedUserId)_\(targetUserId)"
        self.interactionId = interactionId
        self.promptedUserId = promptedUserId
        self.targetUserId = targetUserId
        self.interactionType = interactionType
        self.interactionContext = interactionContext
        self.isShown = false
        self.isCompleted = false
        self.isSkipped = false
        self.createdAt = Date()
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
}

// MARK: - Mutual Rating Visibility

/// Manages the mutual visibility logic for ratings
struct MutualRatingVisibility: Codable {
    let interactionId: String
    let userPairs: [UserPair] // All user pairs that can rate each other
    
    struct UserPair: Codable, Hashable {
        let userId1: String
        let userId2: String
        let user1Rated: Bool // Has user1 rated user2?
        let user2Rated: Bool // Has user2 rated user1?
        
        var bothRated: Bool {
            return user1Rated && user2Rated
        }
        
        func canSeeRating(requestingUserId: String) -> Bool {
            if requestingUserId == userId1 {
                return user1Rated // User1 can see user2's rating only if they rated user2
            } else if requestingUserId == userId2 {
                return user2Rated // User2 can see user1's rating only if they rated user1
            }
            return false
        }
    }
    
    init(interactionId: String, participantIds: [String]) {
        self.interactionId = interactionId
        
        // Create all possible pairs from participants
        var pairs: [UserPair] = []
        for i in 0..<participantIds.count {
            for j in (i+1)..<participantIds.count {
                pairs.append(UserPair(
                    userId1: participantIds[i],
                    userId2: participantIds[j],
                    user1Rated: false,
                    user2Rated: false
                ))
            }
        }
        self.userPairs = pairs
    }
}
