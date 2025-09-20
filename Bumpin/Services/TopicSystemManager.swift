import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Topic System Manager
// Central coordinator for the new topic system

@MainActor
class TopicSystemManager: ObservableObject {
    static let shared = TopicSystemManager()
    
    @Published var isInitialized = false
    @Published var trendingTopics: [DiscussionTopic] = []
    @Published var categoryTopics: [TopicCategory: [DiscussionTopic]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let topicService = TopicService.shared
    private let aiManager = AITopicManager.shared
    private let trendingService = TopicTrendingService.shared
    private let trendingScheduler = TrendingUpdateScheduler.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupInitialization()
    }
    
    // MARK: - Initialization
    
    func initialize() async {
        guard !isInitialized else { return }
        
        isLoading = true
        
        do {
            // Load initial data
            async let trending = topicService.getTrendingTopics()
            async let categories = loadAllCategoryTopics()
            
            let (trendingResults, categoryResults) = try await (trending, categories)
            
            trendingTopics = trendingResults
            categoryTopics = categoryResults
            
            // Start trending updates
            trendingScheduler.startScheduledUpdates()
            
            isInitialized = true
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    // MARK: - Topic Management
    
    func createTopic(name: String, category: TopicCategory, description: String?) async throws -> DiscussionTopic {
        // Check for similar topics first
        let similarTopics = try await aiManager.findSimilarTopics(to: ProposedTopic(
            name: name,
            category: category,
            description: description,
            tags: [],
            createdBy: Auth.auth().currentUser?.uid ?? ""
        ))
        
        if !similarTopics.isEmpty {
            let similarTopic = similarTopics.first!
            if similarTopic.similarityScore > 0.8 {
                throw TopicError.duplicateTopic
            }
        }
        
        // Create the topic
        let topic = try await topicService.createTopic(
            name: name,
            category: category,
            description: description
        )
        
        // Update local cache
        await updateLocalCache()
        
        return topic
    }
    
    func searchTopics(query: String, category: TopicCategory? = nil) async throws -> [DiscussionTopic] {
        return try await topicService.searchTopics(query: query, category: category)
    }
    
    func getTopics(for category: TopicCategory, sortBy: TopicSortOption = .trending) async throws -> [DiscussionTopic] {
        return try await topicService.getTopics(for: category, sortBy: sortBy)
    }
    
    // MARK: - Discussion Integration
    
    func createDiscussionFromTopic(_ topic: DiscussionTopic, hostId: String, hostName: String) async throws -> TopicChat {
        let topicChat = try await topicService.createDiscussionFromTopic(topic, hostId: hostId, hostName: hostName)
        
        // Update trending metrics
        try await trendingService.updateTrendingMetrics(for: topic.id, activityType: .discussionCreated)
        
        return topicChat
    }
    
    func joinDiscussion(_ discussion: TopicChat) async throws {
        // Update trending metrics for the topic
        if let topicId = discussion.primaryTopic {
            try await trendingService.updateTrendingMetrics(for: topicId, activityType: .userJoined)
        }
    }
    
    func sendMessage(in discussion: TopicChat) async throws {
        // Update trending metrics for the topic
        if let topicId = discussion.primaryTopic {
            try await trendingService.updateTrendingMetrics(for: topicId, activityType: .messageSent)
        }
    }
    
    // MARK: - AI Features
    
    func suggestTopicName(_ description: String, category: DiscussionCategory) async throws -> [String] {
        return try await aiManager.suggestTopicName(description, category: category)
    }
    
    func findSimilarTopics(to proposedTopic: ProposedTopic) async throws -> [AITopicManager.SimilarityResult] {
        return try await aiManager.findSimilarTopics(to: proposedTopic)
    }
    
    func moderateTopic(_ name: String, _ description: String?) async throws -> TopicModerationResult {
        return try await aiManager.moderateTopic(name, description)
    }
    
    // MARK: - Private Methods
    
    private func setupInitialization() {
        // Auto-initialize when user is authenticated
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if user != nil {
                Task {
                    await self?.initialize()
                }
            }
        }
    }
    
    private func loadAllCategoryTopics() async throws -> [TopicCategory: [DiscussionTopic]] {
        var results: [TopicCategory: [DiscussionTopic]] = [:]
        
        for category in TopicCategory.allCases {
            let topics = try await topicService.getTopics(for: category)
            results[category] = topics
        }
        
        return results
    }
    
    private func updateLocalCache() async {
        do {
            let trending = try await topicService.getTrendingTopics()
            let categories = try await loadAllCategoryTopics()
            
            trendingTopics = trending
            categoryTopics = categories
        } catch {
            self.error = error
        }
    }
}

// MARK: - Topic System Events

extension TopicSystemManager {
    func handleTopicActivity(_ activity: TopicActivity) async {
        do {
            try await trendingService.updateTrendingMetrics(
                for: activity.topicId,
                activityType: activity.type
            )
        } catch {
            print("Error updating topic activity: \(error)")
        }
    }
}

struct TopicActivity {
    let topicId: String
    let type: TopicActivityType
    let userId: String
    let timestamp: Date
    
    init(topicId: String, type: TopicActivityType, userId: String? = nil) {
        self.topicId = topicId
        self.type = type
        self.userId = userId ?? Auth.auth().currentUser?.uid ?? ""
        self.timestamp = Date()
    }
}

// MARK: - Migration Helper

extension TopicSystemManager {
    /// Migrates existing discussions to use the new topic system
    func migrateExistingDiscussions() async throws {
        // This would migrate existing TopicChat instances to use DiscussionTopic references
        // Implementation depends on your existing data structure
        
        let discussionsSnapshot = try await Firestore.firestore()
            .collection("topicChats")
            .whereField("primaryTopic", isNotEqualTo: NSNull())
            .getDocuments()
        
        for document in discussionsSnapshot.documents {
            guard var discussion = try? document.data(as: TopicChat.self),
                  let primaryTopic = discussion.primaryTopic else { continue }
            
            // Create or find the corresponding DiscussionTopic
            let topic = try await findOrCreateTopicFromDiscussion(discussion)
            
            // Update the discussion with the topic reference
            discussion.updateWithDiscussionTopic(topic)
            
            // Save the updated discussion
            try await document.reference.setData(from: discussion)
        }
    }
    
    private func findOrCreateTopicFromDiscussion(_ discussion: TopicChat) async throws -> DiscussionTopic {
        // Try to find existing topic first
        let existingTopics = try await topicService.searchTopics(
            query: discussion.primaryTopic ?? discussion.title,
            category: discussion.category
        )
        
        if let existingTopic = existingTopics.first {
            return existingTopic
        }
        
        // Create new topic from discussion
        return try await topicService.createTopic(
            name: discussion.primaryTopic ?? discussion.title,
            category: discussion.category,
            description: discussion.description
        )
    }
}
