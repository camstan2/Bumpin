import Foundation

// MARK: - Engagement Scoring Service

/// Centralized service for calculating engagement scores across the app
/// Formula: (Comments × 3.0) + (Reposts × 3.0) + (Likes × 1.0) + (ThumbsDown × 1.0)
class EngagementScoringService {
    
    static let shared = EngagementScoringService()
    
    // Engagement weights
    struct Weights {
        static let comments: Double = 3.0
        static let reposts: Double = 3.0
        static let likes: Double = 1.0
        static let thumbsDown: Double = 1.0
    }
    
    private init() {}
    
    // MARK: - Score Calculation
    
    /// Calculate engagement score for a MusicLog
    func calculateScore(for log: MusicLog) -> Double {
        let comments = Double(log.commentCount ?? 0)
        let likes = Double(log.likeCount ?? 0)
        let thumbsDown = Double(log.thumbsDown == true ? 1 : 0)
        let reposts = Double(log.repostCount ?? 0)
        
        return (comments * Weights.comments) +
               (reposts * Weights.reposts) +
               (likes * Weights.likes) +
               (thumbsDown * Weights.thumbsDown)
    }
    
    /// Calculate engagement score with custom repost count
    func calculateScore(
        comments: Int,
        reposts: Int,
        likes: Int,
        thumbsDown: Int
    ) -> Double {
        return (Double(comments) * Weights.comments) +
               (Double(reposts) * Weights.reposts) +
               (Double(likes) * Weights.likes) +
               (Double(thumbsDown) * Weights.thumbsDown)
    }
    
    // MARK: - Sorting
    
    /// Sort logs by engagement score (highest to lowest)
    func sortByEngagement(_ logs: [MusicLog]) -> [MusicLog] {
        return logs.sorted { calculateScore(for: $0) > calculateScore(for: $1) }
    }
    
    // MARK: - Engagement Details
    
    /// Get formatted engagement breakdown for display
    func getEngagementBreakdown(for log: MusicLog) -> EngagementBreakdown {
        let comments = log.commentCount ?? 0
        let likes = log.likeCount ?? 0
        let thumbsDown = log.thumbsDown == true ? 1 : 0
        let reposts = log.repostCount ?? 0
        let totalScore = calculateScore(for: log)
        
        return EngagementBreakdown(
            comments: comments,
            reposts: reposts,
            likes: likes,
            thumbsDown: thumbsDown,
            totalScore: totalScore
        )
    }
}

// MARK: - Supporting Models

struct EngagementBreakdown {
    let comments: Int
    let reposts: Int
    let likes: Int
    let thumbsDown: Int
    let totalScore: Double
    
    var formattedScore: String {
        return String(format: "%.1f", totalScore)
    }
}

