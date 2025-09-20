import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Trending Topic Models

enum TrendingSource: String, Codable, CaseIterable {
    case manual = "manual"           // Admin curated
    case ai = "ai"                   // AI detected
    case userGenerated = "user"      // Popular user topics
    case external = "external"       // RSS/API feeds
    case community = "community"     // Community suggested
    
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .ai: return "AI Detected"
        case .userGenerated: return "User Generated"
        case .external: return "External Feed"
        case .community: return "Community"
        }
    }
    
    var color: Color {
        switch self {
        case .manual: return .purple
        case .ai: return .blue
        case .userGenerated: return .green
        case .external: return .orange
        case .community: return .cyan
        }
    }
}

struct TrendingTopic: Identifiable, Codable {
    let id: String
    var title: String
    var description: String?
    let category: TopicCategory
    var keywords: [String]
    let source: TrendingSource
    var popularity: Double // 0.0-1.0 calculated score
    var discussionCount: Int // Number of discussions using this topic
    var participantCount: Int // Total participants across all discussions
    var messageCount: Int // Total messages across all discussions
    let createdAt: Date
    var lastUpdated: Date
    var lastActivity: Date? // Last time someone joined/messaged
    var isActive: Bool
    var priority: Int // Manual override for ordering (0-10)
    var expiresAt: Date? // Optional expiration for time-sensitive topics
    
    // External source tracking
    var externalUrl: String? // Source URL for external topics
    var externalId: String? // External API ID
    
    // Quality metrics
    var qualityScore: Double // 0.0-1.0 based on engagement quality
    var reportCount: Int // Number of reports/flags
    var isVerified: Bool // Admin verified as high quality
    
    init(
        title: String,
        description: String? = nil,
        category: TopicCategory,
        keywords: [String] = [],
        source: TrendingSource,
        priority: Int = 5,
        expiresAt: Date? = nil
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.category = category
        self.keywords = keywords
        self.source = source
        self.popularity = 0.0
        self.discussionCount = 0
        self.participantCount = 0
        self.messageCount = 0
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.lastActivity = nil
        self.isActive = true
        self.priority = priority
        self.expiresAt = expiresAt
        self.externalUrl = nil
        self.externalId = nil
        self.qualityScore = 0.5
        self.reportCount = 0
        self.isVerified = source == .manual
    }
}

// MARK: - Topic Metrics for Analytics

struct TopicMetrics: Identifiable, Codable {
    let id: String // Same as TrendingTopic.id
    let topicId: String
    let category: TopicCategory
    
    // Discussion metrics
    var totalDiscussions: Int
    var activeDiscussions: Int
    var totalParticipants: Int
    var totalMessages: Int
    var averageDiscussionDuration: TimeInterval
    
    // Engagement metrics
    var dailyDiscussions: [Date: Int] // Last 30 days
    var hourlyActivity: [Int: Int] // 0-23 hours, activity count
    var topKeywords: [String: Int] // Keyword frequency
    var participantRetention: Double // % who return to topic discussions
    
    // Quality metrics
    var averageRating: Double // If users can rate topics
    var reportRate: Double // Reports per discussion
    var moderationActions: Int
    
    // Activity tracking
    var lastActivity: Date? // Last time someone joined/messaged
    
    let lastCalculated: Date
    
    init(topicId: String, category: TopicCategory) {
        self.id = topicId
        self.topicId = topicId
        self.category = category
        self.totalDiscussions = 0
        self.activeDiscussions = 0
        self.totalParticipants = 0
        self.totalMessages = 0
        self.averageDiscussionDuration = 0
        self.dailyDiscussions = [:]
        self.hourlyActivity = [:]
        self.topKeywords = [:]
        self.participantRetention = 0.0
        self.averageRating = 0.0
        self.reportRate = 0.0
        self.moderationActions = 0
        self.lastActivity = nil
        self.lastCalculated = Date()
    }
}

// MARK: - Trending Configuration

struct TrendingConfig: Codable {
    // Update frequencies (in seconds)
    var aiUpdateInterval: TimeInterval = 3600 // 1 hour
    var metricsUpdateInterval: TimeInterval = 1800 // 30 minutes
    var externalFeedInterval: TimeInterval = 7200 // 2 hours
    
    // Algorithm weights
    var discussionCountWeight: Double = 0.4
    var recentActivityWeight: Double = 0.3
    var engagementWeight: Double = 0.2
    var priorityWeight: Double = 0.1
    
    // Quality thresholds
    var minimumDiscussions: Int = 1
    var maximumReportRate: Double = 0.1
    var minimumQualityScore: Double = 0.3
    
    // Category-specific settings
    var categoryLimits: [String: Int] = [:] // Category -> max topics
    var categoryAIEnabled: [String: Bool] = [:] // Category -> AI enabled
    
    static let `default` = TrendingConfig()
}

// MARK: - Firestore Extensions

extension TrendingTopic {
    
    static func createTopic(_ topic: TrendingTopic, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("trendingTopics").document(topic.id).setData(from: topic) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }
    
    static func updateTopic(_ topic: TrendingTopic, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("trendingTopics").document(topic.id).setData(from: topic, merge: true) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }
    
    static func fetchTopicsForCategory(
        category: TopicCategory,
        limit: Int = 10,
        activeOnly: Bool = true,
        completion: @escaping ([TrendingTopic]?, Error?) -> Void
    ) {
        let db = Firestore.firestore()
        var query = db.collection("trendingTopics")
            .whereField("category", isEqualTo: category.rawValue)
        
        if activeOnly {
            query = query.whereField("isActive", isEqualTo: true)
        }
        
        query = query
            .order(by: "popularity", descending: true)
            .order(by: "priority", descending: true)
            .limit(to: limit)
        
        query.getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            let topics = snapshot?.documents.compactMap { document in
                try? document.data(as: TrendingTopic.self)
            }
            completion(topics, nil)
        }
    }
    
    static func deleteTopic(id: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("trendingTopics").document(id).delete { error in
            completion?(error)
        }
    }
}

extension TopicMetrics {
    
    static func updateMetrics(for topicId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        
        // Calculate metrics from topicChats collection
        db.collection("topicChats")
            .whereField("primaryTopic", isEqualTo: topicId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion?(error)
                    return
                }
                
                let discussions = snapshot?.documents.compactMap { document in
                    try? document.data(as: TopicChat.self)
                } ?? []
                
                // Calculate metrics
                let totalDiscussions = discussions.count
                let activeDiscussions = discussions.filter { $0.isActive }.count
                let totalParticipants = discussions.reduce(0) { $0 + $1.participants.count }
                let lastActivity = discussions.compactMap { $0.createdAt }.max()
                
                // Create/update metrics document
                let metrics = TopicMetrics(topicId: topicId, category: discussions.first?.category ?? .trending)
                var metricsData = metrics
                metricsData.totalDiscussions = totalDiscussions
                metricsData.activeDiscussions = activeDiscussions
                metricsData.totalParticipants = totalParticipants
                metricsData.lastActivity = lastActivity
                
                do {
                    try db.collection("topicMetrics").document(topicId).setData(from: metricsData) { error in
                        completion?(error)
                    }
                } catch {
                    completion?(error)
                }
            }
    }
}
