import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class TopicService: ObservableObject {
    private let db = Firestore.firestore()
    static let shared = TopicService()
    
    @Published var trendingTopics: [DiscussionTopic] = []
    @Published var categoryTopics: [TopicCategory: [DiscussionTopic]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupListeners()
    }
    
    // MARK: - Topic CRUD Operations
    
    func createTopic(name: String, category: TopicCategory, description: String? = nil) async throws -> DiscussionTopic {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw TopicError.notAuthenticated
        }
        
        // Check for similar topics
        let similarTopics = try await findSimilarTopics(name: name, category: category)
        if !similarTopics.isEmpty {
            throw TopicError.duplicateTopic
        }
        
        // Create new topic
        let topic = DiscussionTopic(
            name: name,
            category: category,
            createdBy: userId,
            description: description
        )
        
        // Save to Firestore
        try await db.collection("topics").document(topic.id).setData(from: topic)
        
        // Update local cache
        await updateLocalCache()
        
        return topic
    }
    
    func getTopics(for category: TopicCategory, sortBy: TopicSortOption = .trending) async throws -> [DiscussionTopic] {
        let query = db.collection("topics")
            .whereField("category", isEqualTo: category.rawValue)
        
        let snapshot = try await query.getDocuments()
        let topics = snapshot.documents.compactMap { doc in
            try? doc.data(as: DiscussionTopic.self)
        }
        
        return sortTopics(topics, by: sortBy)
    }
    
    func getTrendingTopics(limit: Int = 10) async throws -> [DiscussionTopic] {
        let query = db.collection("topics")
            .whereField("isTrending", isEqualTo: true)
            .order(by: "trendingScore", descending: true)
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: DiscussionTopic.self)
        }
    }
    
    func searchTopics(query: String, category: TopicCategory? = nil) async throws -> [DiscussionTopic] {
        var searchQuery: Query = db.collection("topics")
        
        if let category = category {
            searchQuery = searchQuery.whereField("category", isEqualTo: category.rawValue)
        }
        
        let snapshot = try await searchQuery.getDocuments()
        let allTopics = snapshot.documents.compactMap { doc in
            try? doc.data(as: DiscussionTopic.self)
        }
        
        // Filter by search query
        return allTopics.filter { topic in
            topic.name.localizedCaseInsensitiveContains(query) ||
            topic.description?.localizedCaseInsensitiveContains(query) == true ||
            topic.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    func findSimilarTopics(name: String, category: TopicCategory) async throws -> [DiscussionTopic] {
        let topics = try await getTopics(for: category)
        
        return topics.filter { topic in
            let similarity = calculateSimilarity(topic.name, name)
            return similarity > 0.7 // 70% similarity threshold
        }
    }
    
    func updateTopicStats(topicId: String, incrementDiscussion: Bool = false) async throws {
        let topicRef = db.collection("topics").document(topicId)
        
        try await db.runTransaction { transaction, errorPointer in
            let topicDoc: DocumentSnapshot
            do {
                topicDoc = try transaction.getDocument(topicRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var topic = try? topicDoc.data(as: DiscussionTopic.self) else {
                return nil
            }
            
            if incrementDiscussion {
                topic.totalDiscussions += 1
                topic.activeDiscussions += 1
            }
            
            topic.lastActivity = Date()
            
            // Calculate trending score based on activity
            topic.trendingScore = self.calculateTrendingScore(topic)
            
            // Mark as trending if it meets criteria
            topic.isTrending = self.shouldMarkAsTrending(topic)
            
            transaction.updateData([
                "totalDiscussions": topic.totalDiscussions,
                "activeDiscussions": topic.activeDiscussions,
                "lastActivity": topic.lastActivity,
                "trendingScore": topic.trendingScore,
                "isTrending": topic.isTrending
            ], forDocument: topicRef)
            
            return nil
        }
    }
    
    // MARK: - Trending Score Calculation
    
    private func calculateTrendingScore(_ topic: DiscussionTopic) -> Double {
        let now = Date()
        let hoursAgo = now.timeIntervalSince(topic.lastActivity) / 3600.0
        
        // Base score from discussion count (0-50 points)
        let discussionScore = min(50.0, Double(topic.totalDiscussions) * 2.0)
        
        // Recency bonus (0-30 points, decays over time)
        let recencyScore = max(0.0, 30.0 * exp(-hoursAgo / 24.0))
        
        // Activity score from active discussions (0-20 points)
        let activityScore = min(20.0, Double(topic.activeDiscussions) * 4.0)
        
        return discussionScore + recencyScore + activityScore
    }
    
    private func shouldMarkAsTrending(_ topic: DiscussionTopic) -> Bool {
        // Mark as trending if:
        // - Has at least 2 total discussions OR
        // - Has at least 1 active discussion AND recent activity (within 24 hours)
        let hasMinimumDiscussions = topic.totalDiscussions >= 2
        let hasRecentActivity = topic.lastActivity.timeIntervalSinceNow > -86400 // 24 hours
        let hasActiveDiscussion = topic.activeDiscussions >= 1
        
        return hasMinimumDiscussions || (hasActiveDiscussion && hasRecentActivity)
    }
    
    // MARK: - Private Methods
    
    private func setupListeners() {
        // Listen for trending topics updates
        db.collection("topics")
            .whereField("isTrending", isEqualTo: true)
            .order(by: "trendingScore", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = error
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.trendingTopics = documents.compactMap { doc in
                    try? doc.data(as: DiscussionTopic.self)
                }
            }
    }
    
    private func updateLocalCache() async {
        do {
            let trending = try await getTrendingTopics()
            await MainActor.run {
                self.trendingTopics = trending
            }
            
            // Update category topics
            for category in TopicCategory.allCases {
                let topics = try await getTopics(for: category)
                await MainActor.run {
                    self.categoryTopics[category] = topics
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    private func sortTopics(_ topics: [DiscussionTopic], by sortOption: TopicSortOption) -> [DiscussionTopic] {
        switch sortOption {
        case .trending:
            return topics.sorted { $0.trendingScore > $1.trendingScore }
        case .newest:
            return topics.sorted { $0.createdAt > $1.createdAt }
        case .mostActive:
            return topics.sorted { $0.activeDiscussions > $1.activeDiscussions }
        case .alphabetical:
            return topics.sorted { $0.name < $1.name }
        }
    }
    
    private func calculateSimilarity(_ string1: String, _ string2: String) -> Double {
        let s1 = string1.lowercased()
        let s2 = string2.lowercased()
        
        if s1 == s2 { return 1.0 }
        if s1.contains(s2) || s2.contains(s1) { return 0.8 }
        
        // Simple Levenshtein distance-based similarity
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        return maxLength == 0 ? 1.0 : 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        let m = a.count
        let n = b.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
}
