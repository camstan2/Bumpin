import Foundation
import FirebaseFirestore
import Combine

class TopicTrendingService {
    static let shared = TopicTrendingService()
    private let db = Firestore.firestore()
    
    struct TrendingMetrics: Codable {
        let topicId: String
        var hourlyActivity: [String: Int] // Hour timestamp -> activity count
        var dailyActivity: [String: Int] // Day timestamp -> activity count
        var weeklyActivity: [String: Int] // Week timestamp -> activity count
        var participantGrowth: Double // Rate of new participant growth
        var engagementRate: Double // Average engagement per participant
        var retentionRate: Double // How many users return to the topic
        var lastUpdated: Date
        
        init(topicId: String) {
            self.topicId = topicId
            self.hourlyActivity = [:]
            self.dailyActivity = [:]
            self.weeklyActivity = [:]
            self.participantGrowth = 0.0
            self.engagementRate = 0.0
            self.retentionRate = 0.0
            self.lastUpdated = Date()
        }
    }
    
    // MARK: - Trending Calculation
    
    func calculateTrendingScore(for topic: DiscussionTopic) async throws -> Double {
        let metrics = try await getTrendingMetrics(topicId: topic.id)
        
        // Weighted scoring algorithm
        let recentActivityWeight = 0.4
        let growthWeight = 0.3
        let engagementWeight = 0.2
        let retentionWeight = 0.1
        
        let recentActivityScore = calculateRecentActivityScore(metrics)
        let growthScore = calculateGrowthScore(metrics)
        let engagementScore = calculateEngagementScore(metrics)
        let retentionScore = calculateRetentionScore(metrics)
        
        let trendingScore = (recentActivityScore * recentActivityWeight) +
                           (growthScore * growthWeight) +
                           (engagementScore * engagementWeight) +
                           (retentionScore * retentionWeight)
        
        return min(max(trendingScore, 0.0), 100.0) // Clamp between 0-100
    }
    
    func updateTrendingMetrics(for topicId: String, activityType: TopicActivityType) async throws {
        let now = Date()
        let hourKey = formatHourKey(now)
        let dayKey = formatDayKey(now)
        let weekKey = formatWeekKey(now)
        
        let metricsRef = db.collection("topicTrendingMetrics").document(topicId)
        
        try await db.runTransaction { transaction, errorPointer in
            let metricsDoc: DocumentSnapshot
            do {
                metricsDoc = try transaction.getDocument(metricsRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var metrics: TrendingMetrics
            if metricsDoc.exists {
                do {
                    metrics = try metricsDoc.data(as: TrendingMetrics.self) ?? TrendingMetrics(topicId: topicId)
                } catch let decodeError as NSError {
                    errorPointer?.pointee = decodeError
                    return nil
                }
            } else {
                metrics = TrendingMetrics(topicId: topicId)
            }
            
            // Update activity counts
            metrics.hourlyActivity[hourKey, default: 0] += 1
            metrics.dailyActivity[dayKey, default: 0] += 1
            metrics.weeklyActivity[weekKey, default: 0] += 1
            
            // Clean up old data (keep last 7 days for hourly, 30 days for daily, 12 weeks for weekly)
            metrics.hourlyActivity = self.cleanupOldData(metrics.hourlyActivity, maxAge: 7 * 24) // 7 days
            metrics.dailyActivity = self.cleanupOldData(metrics.dailyActivity, maxAge: 30) // 30 days
            metrics.weeklyActivity = self.cleanupOldData(metrics.weeklyActivity, maxAge: 12) // 12 weeks
            
            metrics.lastUpdated = now
            
            do {
                try transaction.setData(from: metrics, forDocument: metricsRef)
            } catch let setDataError as NSError {
                errorPointer?.pointee = setDataError
                return nil
            }
            return nil
        }
    }
    
    func getTrendingTopics(limit: Int = 20) async throws -> [DiscussionTopic] {
        let topicsRef = db.collection("topics")
            .whereField("isTrending", isEqualTo: true)
            .order(by: "trendingScore", descending: true)
            .limit(to: limit)
        
        let snapshot = try await topicsRef.getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: DiscussionTopic.self)
        }
    }
    
    func updateTopicTrendingStatus(_ topicId: String, isTrending: Bool, trendingScore: Double) async throws {
        let topicRef = db.collection("topics").document(topicId)
        
        try await topicRef.updateData([
            "isTrending": isTrending,
            "trendingScore": trendingScore,
            "lastTrendingUpdate": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Private Methods
    
    private func getTrendingMetrics(topicId: String) async throws -> TrendingMetrics {
        let metricsRef = db.collection("topicTrendingMetrics").document(topicId)
        let snapshot = try await metricsRef.getDocument()
        
        if snapshot.exists {
            return try snapshot.data(as: TrendingMetrics.self)
        } else {
            return TrendingMetrics(topicId: topicId)
        }
    }
    
    private func calculateRecentActivityScore(_ metrics: TrendingMetrics) -> Double {
        let now = Date()
        let last24Hours = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
        
        let recentActivity = metrics.hourlyActivity.compactMap { (key, value) in
            guard let hourDate = parseHourKey(key), hourDate >= last24Hours else { return nil }
            return value
        }.reduce(0, +)
        
        // Normalize to 0-100 scale (assuming max 100 activities per hour is "hot")
        return min(Double(recentActivity) / 100.0 * 100.0, 100.0)
    }
    
    private func calculateGrowthScore(_ metrics: TrendingMetrics) -> Double {
        // Calculate growth rate over last 7 days vs previous 7 days
        let now = Date()
        let last7Days = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let previous7Days = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        
        let recentActivity = metrics.dailyActivity.compactMap { (key, value) in
            guard let dayDate = parseDayKey(key), dayDate >= last7Days else { return nil }
            return value
        }.reduce(0, +)
        
        let previousActivity = metrics.dailyActivity.compactMap { (key, value) in
            guard let dayDate = parseDayKey(key), dayDate >= previous7Days && dayDate < last7Days else { return nil }
            return value
        }.reduce(0, +)
        
        if previousActivity == 0 {
            return recentActivity > 0 ? 100.0 : 0.0
        }
        
        let growthRate = Double(recentActivity - previousActivity) / Double(previousActivity)
        return min(max(growthRate * 100.0, 0.0), 100.0)
    }
    
    private func calculateEngagementScore(_ metrics: TrendingMetrics) -> Double {
        // This would be calculated based on message frequency, reaction rates, etc.
        // For now, using a simplified calculation
        return min(metrics.engagementRate * 100.0, 100.0)
    }
    
    private func calculateRetentionScore(_ metrics: TrendingMetrics) -> Double {
        // This would be calculated based on how many users return to the topic
        // For now, using a simplified calculation
        return min(metrics.retentionRate * 100.0, 100.0)
    }
    
    private func formatHourKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.string(from: date)
    }
    
    private func formatDayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func formatWeekKey(_ date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return "\(year)-W\(week)"
    }
    
    private func parseHourKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return formatter.date(from: key)
    }
    
    private func parseDayKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }
    
    private func parseWeekKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-'W'ww"
        return formatter.date(from: key)
    }
    
    private func cleanupOldData(_ data: [String: Int], maxAge: Int) -> [String: Int] {
        let now = Date()
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -maxAge, to: now) ?? now
        
        return data.filter { (key, _) in
            if let date = parseHourKey(key) {
                return date >= cutoffDate
            } else if let date = parseDayKey(key) {
                return date >= cutoffDate
            } else if let date = parseWeekKey(key) {
                return date >= cutoffDate
            }
            return false
        }
    }
}

// MARK: - Topic Activity Types

enum TopicActivityType: String, Codable {
    case discussionCreated = "discussion_created"
    case messageSent = "message_sent"
    case userJoined = "user_joined"
    case userLeft = "user_left"
    case reactionAdded = "reaction_added"
    case topicViewed = "topic_viewed"
}

// MARK: - Trending Update Scheduler

class TrendingUpdateScheduler {
    static let shared = TrendingUpdateScheduler()
    private let trendingService = TopicTrendingService.shared
    private var updateTimer: Timer?
    
    func startScheduledUpdates() {
        // Update trending scores every hour
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.updateAllTrendingScores()
            }
        }
    }
    
    func stopScheduledUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateAllTrendingScores() async {
        do {
            // Get all topics
            let topicsSnapshot = try await Firestore.firestore().collection("topics").getDocuments()
            let topics = topicsSnapshot.documents.compactMap { doc in
                try? doc.data(as: DiscussionTopic.self)
            }
            
            // Calculate trending scores
            for topic in topics {
                let trendingScore = try await trendingService.calculateTrendingScore(for: topic)
                let isTrending = trendingScore > 50.0 // Threshold for trending
                
                try await trendingService.updateTopicTrendingStatus(
                    topic.id,
                    isTrending: isTrending,
                    trendingScore: trendingScore
                )
            }
        } catch {
            print("Error updating trending scores: \(error)")
        }
    }
}
