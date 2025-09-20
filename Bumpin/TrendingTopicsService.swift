import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Trending Topics Service

@MainActor
class TrendingTopicsService: ObservableObject {
    
    static let shared = TrendingTopicsService()
    
    // MARK: - Published Properties
    
    @Published var trendingTopicsByCategory: [TopicCategory: [TrendingTopic]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private var config = TrendingConfig.default
    
    // Cache with TTL
    private var cache: [String: (topics: [TrendingTopic], expiresAt: Date)] = [:]
    private let cacheTTL: TimeInterval = 1800 // 30 minutes
    
    private init() {
        loadConfig()
    }
    
    deinit {
        // Schedule cleanup on the main actor to respect actor isolation
        Task { @MainActor in
            self.removeAllListeners()
        }
    }
    
    // MARK: - Public Methods
    
    /// Get trending topics for a specific category
    func getTrendingTopics(for category: TopicCategory, limit: Int = 10) async -> [TrendingTopic] {
        let cacheKey = "\(category.rawValue)_\(limit)"
        
        // Check cache first
        if let cached = cache[cacheKey], cached.expiresAt > Date() {
            return Array(cached.topics.prefix(limit))
        }
        
        // Fetch from Firebase
        do {
            let topics = try await fetchTopicsFromFirebase(category: category, limit: limit)
            
            // Update cache
            let expiresAt = Date().addingTimeInterval(cacheTTL)
            cache[cacheKey] = (topics: topics, expiresAt: expiresAt)
            
            return topics
        } catch {
            print("❌ Error fetching trending topics for \(category.rawValue): \(error)")
            return []
        }
    }
    
    /// Refresh all trending topics
    func refreshAllTopics() async {
        isLoading = true
        cache.removeAll()
        
        for category in TopicCategory.allCases {
            let topics = await getTrendingTopics(for: category)
            await MainActor.run {
                trendingTopicsByCategory[category] = topics
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Manual Curation Methods
    
    /// Add a manually curated topic
    func addManualTopic(
        category: TopicCategory,
        title: String,
        description: String? = nil,
        keywords: [String] = [],
        priority: Int = 5,
        expiresAt: Date? = nil
    ) async -> Bool {
        guard isAdmin() else {
            await MainActor.run {
                errorMessage = "Admin access required"
            }
            return false
        }
        
        let topic = TrendingTopic(
            title: title,
            description: description,
            category: category,
            keywords: keywords,
            source: .manual,
            priority: priority,
            expiresAt: expiresAt
        )
        
        do {
            try await db.collection("trendingTopics").document(topic.id).setData(from: topic)
            
            // Invalidate cache for this category
            invalidateCache(for: category)
            
            // Update metrics
            await updateTopicMetrics(topicId: topic.id)
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to add topic: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Update topic priority (admin only)
    func updateTopicPriority(topicId: String, priority: Int) async -> Bool {
        guard isAdmin() else {
            await MainActor.run {
                errorMessage = "Admin access required"
            }
            return false
        }
        
        do {
            try await db.collection("trendingTopics").document(topicId).updateData([
                "priority": priority,
                "lastUpdated": FieldValue.serverTimestamp()
            ])
            
            // Invalidate all caches since priority affects ordering
            cache.removeAll()
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update priority: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Toggle topic active status
    func toggleTopicActive(topicId: String, isActive: Bool) async -> Bool {
        guard isAdmin() else {
            await MainActor.run {
                errorMessage = "Admin access required"
            }
            return false
        }
        
        do {
            try await db.collection("trendingTopics").document(topicId).updateData([
                "isActive": isActive,
                "lastUpdated": FieldValue.serverTimestamp()
            ])
            
            // Invalidate all caches
            cache.removeAll()
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to toggle topic: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Delete topic (admin only)
    func deleteTopic(topicId: String) async -> Bool {
        guard isAdmin() else {
            await MainActor.run {
                errorMessage = "Admin access required"
            }
            return false
        }
        
        do {
            // Delete topic
            try await db.collection("trendingTopics").document(topicId).delete()
            
            // Delete associated metrics
            try await db.collection("topicMetrics").document(topicId).delete()
            
            // Invalidate all caches
            cache.removeAll()
            
            return true
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete topic: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Ranking Algorithm
    
    /// Calculate trending score for a topic based on discussion activity
    func calculateTrendingScore(topic: TrendingTopic, metrics: TopicMetrics?) -> Double {
        let weights = config
        
        // Discussion activity score (0.0-1.0)
        let maxDiscussions = 50.0 // Normalize against this
        let discussionScore = min(1.0, Double(topic.discussionCount) / maxDiscussions)
        
        // Recent activity score (0.0-1.0)
        let recentScore = calculateRecencyScore(lastActivity: topic.lastActivity)
        
        // Engagement score (0.0-1.0)
        let engagementScore = calculateEngagementScore(topic: topic, metrics: metrics)
        
        // Priority score (0.0-1.0)
        let priorityScore = Double(topic.priority) / 10.0
        
        // Weighted final score
        return (discussionScore * weights.discussionCountWeight) +
               (recentScore * weights.recentActivityWeight) +
               (engagementScore * weights.engagementWeight) +
               (priorityScore * weights.priorityWeight)
    }
    
    /// Update all topic metrics and rankings
    func updateAllTopicMetrics() async {
        print("🔄 Updating all topic metrics...")
        
        for category in TopicCategory.allCases {
            await updateCategoryMetrics(category: category)
        }
        
        print("✅ Topic metrics update completed")
    }
    
    // MARK: - AI Integration Methods (Placeholder)
    
    /// Run AI trend detection for a category
    func runAITrendDetection(for category: TopicCategory) async -> [TrendingTopic] {
        // TODO: Implement AI trend detection
        // This would integrate with external APIs like:
        // - Reddit API for trending posts
        // - News APIs for current events
        // - Social media trend APIs
        // - Google Trends API
        
        print("🤖 Running AI trend detection for \(category.displayName)...")
        
        // Placeholder: Generate some AI-detected topics
        let aiTopics = await generatePlaceholderAITopics(for: category)
        
        // Save AI-detected topics to Firebase
        for topic in aiTopics {
            do {
                try await db.collection("trendingTopics").document(topic.id).setData(from: topic)
            } catch {
                print("❌ Failed to save AI topic: \(error)")
            }
        }
        
        return aiTopics
    }
    
    /// Analyze external trends from RSS/API feeds
    func analyzeExternalTrends(for category: TopicCategory) async -> [TrendingTopic] {
        // TODO: Implement external trend analysis
        print("📡 Analyzing external trends for \(category.displayName)...")
        return []
    }
    
    // MARK: - Real-time Updates
    
    /// Start listening to real-time updates for a category
    func startListening(to category: TopicCategory) {
        let listenerKey = category.rawValue
        
        // Remove existing listener
        listeners[listenerKey]?.remove()
        
        // Create new listener
        let listener = db.collection("trendingTopics")
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("isActive", isEqualTo: true)
            .order(by: "popularity", descending: true)
            .order(by: "priority", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Failed to listen to topics: \(error.localizedDescription)"
                    }
                    return
                }
                
                let topics = snapshot?.documents.compactMap { document in
                    try? document.data(as: TrendingTopic.self)
                } ?? []
                
                Task { @MainActor in
                    self.trendingTopicsByCategory[category] = topics
                }
            }
        
        listeners[listenerKey] = listener
    }
    
    /// Stop listening to updates for a category
    func stopListening(to category: TopicCategory) {
        let listenerKey = category.rawValue
        listeners[listenerKey]?.remove()
        listeners.removeValue(forKey: listenerKey)
    }
    
    /// Remove all listeners
    func removeAllListeners() {
        for listener in listeners.values {
            listener.remove()
        }
        listeners.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func fetchTopicsFromFirebase(category: TopicCategory, limit: Int) async throws -> [TrendingTopic] {
        let snapshot = try await db.collection("trendingTopics")
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("isActive", isEqualTo: true)
            .order(by: "popularity", descending: true)
            .order(by: "priority", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            try? document.data(as: TrendingTopic.self)
        }
    }
    
    private func calculateRecencyScore(lastActivity: Date?) -> Double {
        guard let lastActivity = lastActivity else { return 0.0 }
        
        let hoursAgo = Date().timeIntervalSince(lastActivity) / 3600.0
        
        // Exponential decay: score decreases over time
        // Full score for activity within last hour, 50% at 24 hours, near 0% at 7 days
        return max(0.0, exp(-hoursAgo / 24.0))
    }
    
    private func calculateEngagementScore(topic: TrendingTopic, metrics: TopicMetrics?) -> Double {
        guard let metrics = metrics else { return 0.0 }
        
        // Engagement factors
        let participantEngagement = metrics.totalParticipants > 0 ? 
            Double(metrics.totalMessages) / Double(metrics.totalParticipants) : 0.0
        
        let discussionQuality = metrics.averageDiscussionDuration / 3600.0 // Hours
        
        let retentionScore = metrics.participantRetention
        
        // Normalize and combine
        let normalizedParticipant = min(1.0, participantEngagement / 10.0) // 10 messages per participant = max score
        let normalizedQuality = min(1.0, discussionQuality / 2.0) // 2 hours = max score
        
        return (normalizedParticipant * 0.4) + (normalizedQuality * 0.3) + (retentionScore * 0.3)
    }
    
    private func updateCategoryMetrics(category: TopicCategory) async {
        do {
            let topics = try await fetchTopicsFromFirebase(category: category, limit: 100)
            
            for topic in topics {
                await updateTopicMetrics(topicId: topic.id)
            }
            
            // Update topic popularity scores based on new metrics
            await updateTopicPopularityScores(for: category)
            
        } catch {
            print("❌ Failed to update metrics for \(category.displayName): \(error)")
        }
    }
    
    private func updateTopicMetrics(topicId: String) async {
        // This calls the TopicMetrics.updateMetrics method
        await withCheckedContinuation { continuation in
            TopicMetrics.updateMetrics(for: topicId) { error in
                if let error = error {
                    print("❌ Failed to update metrics for topic \(topicId): \(error)")
                }
                continuation.resume()
            }
        }
    }
    
    private func updateTopicPopularityScores(for category: TopicCategory) async {
        do {
            // Fetch topics and their metrics
            let topics = try await fetchTopicsFromFirebase(category: category, limit: 100)
            let metricsSnapshot = try await db.collection("topicMetrics")
                .whereField("category", isEqualTo: category.rawValue)
                .getDocuments()
            
            let metricsDict: [String: TopicMetrics] = metricsSnapshot.documents.reduce(into: [:]) { partialResult, doc in
                if let metrics = try? doc.data(as: TopicMetrics.self) {
                    partialResult[metrics.topicId] = metrics
                }
            }
            
            // Calculate new popularity scores
            let batch = db.batch()
            
            for topic in topics {
                let metrics = metricsDict[topic.id]
                let newScore = calculateTrendingScore(topic: topic, metrics: metrics)
                
                let topicRef = db.collection("trendingTopics").document(topic.id)
                batch.updateData([
                    "popularity": newScore,
                    "lastUpdated": FieldValue.serverTimestamp()
                ], forDocument: topicRef)
            }
            
            try await batch.commit()
            
            // Invalidate cache for this category
            invalidateCache(for: category)
            
        } catch {
            print("❌ Failed to update popularity scores for \(category.displayName): \(error)")
        }
    }
    
    private func invalidateCache(for category: TopicCategory) {
        let keysToRemove = cache.keys.filter { $0.hasPrefix(category.rawValue) }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    private func loadConfig() {
        Task {
            do {
                let snapshot = try await db.collection("config").document("trending").getDocument()
                if let data = snapshot.data() {
                    let configData = try JSONSerialization.data(withJSONObject: data)
                    config = try JSONDecoder().decode(TrendingConfig.self, from: configData)
                }
            } catch {
                print("ℹ️ Using default trending config: \(error)")
                config = TrendingConfig.default
            }
        }
    }
    
    private func isAdmin() -> Bool {
        // Check if current user is admin
        // This should match your existing admin check logic
        return Auth.auth().currentUser?.uid != nil // Placeholder - implement proper admin check
    }
    
    // MARK: - Placeholder AI Methods
    
    private func generatePlaceholderAITopics(for category: TopicCategory) async -> [TrendingTopic] {
        // Generate some realistic placeholder topics based on category
        let placeholderTopics: [String] = {
            switch category {
            case .trending:
                return ["What's trending today", "Viral moments", "Breaking news discussion", "Hot takes"]
            case .movies:
                return ["Latest movie releases", "Oscar predictions", "Marvel vs DC", "Netflix recommendations"]
            case .tv:
                return ["TV show discussions", "Season finales", "Streaming recommendations", "Binge-worthy series"]
            case .sports:
                return ["Game highlights", "Trade rumors", "Player performances", "Season predictions"]
            case .gaming:
                return ["New game releases", "Gaming tips and tricks", "Esports tournaments", "Gaming hardware"]
            case .music:
                return ["New album drops", "Concert experiences", "Music discovery", "Artist collaborations"]
            case .entertainment:
                return ["Celebrity news", "Award shows", "TV show finales", "Entertainment gossip"]
            case .politics:
                return ["Current events", "Policy discussions", "Election updates", "Political analysis"]
            case .business:
                return ["Market trends", "Startup news", "Tech earnings", "Economic updates"]
            case .arts:
                return ["Art exhibitions", "Creative projects", "Artist spotlights", "Cultural events"]
            case .art:
                return ["Art exhibitions", "Creative projects", "Artist spotlights", "Cultural events"]
            case .food:
                return ["Recipe sharing", "Restaurant reviews", "Food trends", "Cooking tips"]
            case .lifestyle:
                return ["Wellness tips", "Life hacks", "Personal growth", "Productivity"]
            case .education:
                return ["Learning resources", "Study tips", "Academic discussions", "Online courses"]
            case .books:
                return ["Book recommendations", "Author discussions", "Reading challenges", "Literary analysis"]
            case .travel:
                return ["Travel destinations", "Trip planning", "Travel tips", "Cultural experiences"]
            case .fashion:
                return ["Style trends", "Fashion shows", "Outfit inspiration", "Designer spotlights"]
            case .science:
                return ["Scientific breakthroughs", "Tech innovations", "Research findings", "Future tech"]
            case .technology:
                return ["Tech news", "Software updates", "Hardware reviews", "Innovation discussions"]
            case .worldNews:
                return ["Global events", "International news", "World politics", "Cultural exchanges"]
            case .health:
                return ["Fitness routines", "Mental health", "Nutrition advice", "Wellness trends"]
            case .automotive:
                return ["Car reviews", "Auto shows", "Electric vehicles", "Racing updates"]
            case .other:
                return ["General discussions", "Random topics", "Miscellaneous", "Open conversations"]
            }
        }()
        
        return placeholderTopics.enumerated().map { index, title in
            TrendingTopic(
                title: title,
                description: "AI-generated trending topic for \(category.displayName)",
                category: category,
                keywords: [title.lowercased()],
                source: .ai,
                priority: 5 - (index / 2) // Vary priority
            )
        }
    }
}

// MARK: - Background Update Methods

extension TrendingTopicsService {
    
    /// Run periodic updates (call from background task)
    func runPeriodicUpdate() async {
        print("⏰ Running periodic trending topics update...")
        
        // Update metrics for all topics
        await updateAllTopicMetrics()
        
        // Run AI detection for enabled categories
        for category in TopicCategory.allCases {
            if config.categoryAIEnabled[category.rawValue] == true {
                _ = await runAITrendDetection(for: category)
            }
        }
        
        // Clean up expired topics
        await cleanupExpiredTopics()
        
        print("✅ Periodic update completed")
    }
    
    private func cleanupExpiredTopics() async {
        do {
            let now = Date()
            let expiredSnapshot = try await db.collection("trendingTopics")
                .whereField("expiresAt", isLessThan: now)
                .getDocuments()
            
            let batch = db.batch()
            
            for document in expiredSnapshot.documents {
                batch.updateData(["isActive": false], forDocument: document.reference)
            }
            
            try await batch.commit()
            
            print("🧹 Cleaned up \(expiredSnapshot.documents.count) expired topics")
            
        } catch {
            print("❌ Failed to cleanup expired topics: \(error)")
        }
    }
}
