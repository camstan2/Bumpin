import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Trending System Test Helper
// Helper to test the new user-statistics-based trending system

struct TrendingSystemTestHelper {
    static let shared = TrendingSystemTestHelper()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // MARK: - Test Data Creation
    
    /// Creates some test discussions to verify the trending system works
    func createTestDiscussions() async {
        print("🧪 Creating test discussions to verify trending system...")
        
        do {
            // Create a popular music topic
            let musicTopic = DiscussionTopic(
                name: "Taylor Swift's New Album",
                category: .music,
                createdBy: "test_user",
                description: "Discussing the latest Taylor Swift album release"
            )
            
            // Simulate it being popular (multiple discussions)
            var popularMusicTopic = musicTopic
            popularMusicTopic.totalDiscussions = 5
            popularMusicTopic.activeDiscussions = 2
            popularMusicTopic.lastActivity = Date() // Recent activity
            popularMusicTopic.trendingScore = 75.0
            popularMusicTopic.isTrending = true
            
            try await db.collection("topics").document(popularMusicTopic.id).setData(from: popularMusicTopic)
            print("✅ Created popular music topic: \(popularMusicTopic.name)")
            
            // Create a moderately popular sports topic
            let sportsTopic = DiscussionTopic(
                name: "NBA Trade Deadline",
                category: .sports,
                createdBy: "test_user",
                description: "Discussing potential NBA trades and rumors"
            )
            
            var moderateSportsTopic = sportsTopic
            moderateSportsTopic.totalDiscussions = 3
            moderateSportsTopic.activeDiscussions = 1
            moderateSportsTopic.lastActivity = Date().addingTimeInterval(-3600) // 1 hour ago
            moderateSportsTopic.trendingScore = 45.0
            moderateSportsTopic.isTrending = true
            
            try await db.collection("topics").document(moderateSportsTopic.id).setData(from: moderateSportsTopic)
            print("✅ Created moderate sports topic: \(moderateSportsTopic.name)")
            
            // Create a new topic with no discussions yet
            let newTopic = DiscussionTopic(
                name: "Best Gaming Setup 2025",
                category: .gaming,
                createdBy: "test_user",
                description: "Share your gaming setup and get recommendations"
            )
            
            try await db.collection("topics").document(newTopic.id).setData(from: newTopic)
            print("✅ Created new gaming topic: \(newTopic.name)")
            
            // Create an old topic with no recent activity
            let oldTopic = DiscussionTopic(
                name: "Old Movie Discussion",
                category: .movies,
                createdBy: "test_user",
                description: "An older movie discussion with no recent activity"
            )
            
            var oldMovieTopic = oldTopic
            oldMovieTopic.totalDiscussions = 2
            oldMovieTopic.activeDiscussions = 0
            oldMovieTopic.lastActivity = Date().addingTimeInterval(-86400 * 3) // 3 days ago
            oldMovieTopic.trendingScore = 10.0
            oldMovieTopic.isTrending = false
            
            try await db.collection("topics").document(oldMovieTopic.id).setData(from: oldMovieTopic)
            print("✅ Created old movie topic: \(oldMovieTopic.name)")
            
            print("🎉 Test discussions created successfully!")
            
        } catch {
            print("❌ Error creating test discussions: \(error)")
        }
    }
    
    /// Clears all test data
    func clearTestData() async {
        print("🧹 Clearing test discussion data...")
        
        do {
            let snapshot = try await db.collection("topics")
                .whereField("createdBy", isEqualTo: "test_user")
                .getDocuments()
            
            let batch = db.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            try await batch.commit()
            print("✅ Test data cleared successfully!")
            
        } catch {
            print("❌ Error clearing test data: \(error)")
        }
    }
    
    /// Simulates a discussion being created for a topic
    func simulateDiscussionCreated(topicId: String) async {
        do {
            try await TopicService.shared.updateTopicStats(topicId: topicId, incrementDiscussion: true)
            print("✅ Simulated discussion created for topic: \(topicId)")
        } catch {
            print("❌ Error simulating discussion: \(error)")
        }
    }
}
