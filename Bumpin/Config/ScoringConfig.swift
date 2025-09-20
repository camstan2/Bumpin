import Foundation

struct ScoringConfig {
    static let shared = ScoringConfig()
    
    // MARK: - Social Scoring Weights
    struct SocialScoring {
        static let likeWeight: Double = 1.0
        static let commentWeight: Double = 2.0
        static let shareWeight: Double = 3.0
        static let reviewWeight: Double = 5.0
        static let helpfulVoteWeight: Double = 1.5
        static let followWeight: Double = 2.5
        
        // Time decay factors
        static let dailyDecayFactor: Double = 0.95
        static let weeklyDecayFactor: Double = 0.8
        static let monthlyDecayFactor: Double = 0.6
    }
    
    // MARK: - Music Discovery Scoring
    struct MusicScoring {
        static let playCountWeight: Double = 1.0
        static let ratingWeight: Double = 3.0
        static let recencyBoost: Double = 1.2
        static let diversityBonus: Double = 0.5
        static let friendInfluence: Double = 2.0
    }
    
    // MARK: - Content Moderation Scoring
    struct ModerationScoring {
        static let reportWeight: Double = -5.0
        static let violationWeight: Double = -10.0
        static let bannedUserPenalty: Double = -100.0
        static let verifiedUserBonus: Double = 2.0
    }
    
    // MARK: - Trending Calculations
    struct TrendingScoring {
        static let viewWeight: Double = 1.0
        static let engagementWeight: Double = 3.0
        static let velocityMultiplier: Double = 2.0
        static let timeWindow: TimeInterval = 24 * 3600 // 24 hours
    }
    
    private init() {}
    
    // MARK: - Popularity Service Properties
    var helpfulWeight: Double = 1.0
    var ratingWeight: Double = 3.0
    var decayHours: Double = 24.0
    var decayWeight: Double = 0.5
    var commentsWeight: Double = 1.5
    var likesWeight: Double = 2.0
    var unhelpfulPenalty: Double = -0.5
    var repostWeight: Double = 2.5
    var recencyWeightMultiplier: Double = 1.2
    var mutualBoost: Double = 1.5
    var followingBoost: Double = 1.2
}
