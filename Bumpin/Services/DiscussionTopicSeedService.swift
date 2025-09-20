import Foundation
import FirebaseFirestore

// MARK: - Discussion Topic Seed Service
// Seeds initial DiscussionTopic entries for the new user-statistics-based trending system

struct DiscussionTopicSeedService {
    static let shared = DiscussionTopicSeedService()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // MARK: - Main Seeding Method
    
    func seedInitialTopicsIfNeeded() async {
        let hasSeededKey = "discussion_topics_seeded_v2"
        let hasSeeded = UserDefaults.standard.bool(forKey: hasSeededKey)
        
        if !hasSeeded {
            print("🌱 Seeding initial DiscussionTopics for user-statistics-based trending...")
            await seedAllCategories()
            UserDefaults.standard.set(true, forKey: hasSeededKey)
            print("✅ DiscussionTopics seeded successfully!")
        }
    }
    
    private func seedAllCategories() async {
        for category in TopicCategory.allCases {
            await seedCategory(category)
        }
    }
    
    private func seedCategory(_ category: TopicCategory) async {
        let topics = getInitialTopicsForCategory(category)
        
        for topicData in topics {
            do {
                let topic = DiscussionTopic(
                    name: topicData.name,
                    category: category,
                    createdBy: "system",
                    description: topicData.description
                )
                
                // Save to Firestore
                try await db.collection("topics").document(topic.id).setData(from: topic)
                print("✅ Seeded topic: \(topic.name)")
                
            } catch {
                print("❌ Failed to seed topic \(topicData.name): \(error)")
            }
        }
    }
    
    // MARK: - Initial Topic Data
    
    private func getInitialTopicsForCategory(_ category: TopicCategory) -> [(name: String, description: String)] {
        switch category {
        case .trending:
            return [
                ("What's Viral Today", "Discuss the latest viral trends and moments"),
                ("Breaking News Discussion", "Real-time discussion about current events"),
                ("Hot Takes & Opinions", "Share your controversial takes on trending topics")
            ]
        case .music:
            return [
                ("New Album Reviews", "Discuss the latest album releases"),
                ("Concert Experiences", "Share your live music experiences"),
                ("Music Discovery", "Find and share new artists and songs")
            ]
        case .movies:
            return [
                ("Latest Movie Reviews", "Discuss new movie releases"),
                ("Marvel vs DC", "The eternal superhero debate"),
                ("Oscar Predictions", "Predict this year's Academy Award winners")
            ]
        case .tv:
            return [
                ("TV Show Discussions", "Talk about your favorite series"),
                ("Season Finales", "Discuss shocking season endings"),
                ("Netflix Recommendations", "Share your streaming finds")
            ]
        case .sports:
            return [
                ("Game Highlights", "Discuss the best moments from recent games"),
                ("Trade Rumors", "Speculate about player trades and moves"),
                ("Season Predictions", "Make your predictions for the season")
            ]
        case .gaming:
            return [
                ("New Game Reviews", "Discuss the latest game releases"),
                ("Gaming Tips & Tricks", "Share strategies and walkthroughs"),
                ("Esports Tournaments", "Follow competitive gaming events")
            ]
        case .politics:
            return [
                ("Current Events", "Discuss today's political news"),
                ("Policy Discussions", "Debate policies and their impacts"),
                ("Election Updates", "Follow election news and analysis")
            ]
        case .technology:
            return [
                ("Tech News", "Discuss the latest technology updates"),
                ("Software Reviews", "Share experiences with new apps and tools"),
                ("Innovation Discussions", "Talk about emerging technologies")
            ]
        case .business:
            return [
                ("Market Trends", "Discuss current market movements"),
                ("Startup News", "Share entrepreneurship stories"),
                ("Economic Updates", "Analyze economic developments")
            ]
        case .entertainment:
            return [
                ("Celebrity News", "Discuss entertainment industry updates"),
                ("Award Shows", "Talk about award ceremonies and winners"),
                ("Pop Culture", "Share thoughts on current pop culture trends")
            ]
        case .arts:
            return [
                ("Art Exhibitions", "Discuss current art shows and galleries"),
                ("Creative Projects", "Share and critique artistic works"),
                ("Artist Spotlights", "Highlight emerging and established artists")
            ]
        case .art:
            return [
                ("Digital Art Trends", "Discuss modern digital art movements"),
                ("Traditional Techniques", "Share classic art methods and styles"),
                ("Art History", "Explore famous artworks and periods")
            ]
        case .food:
            return [
                ("Recipe Sharing", "Exchange favorite recipes and cooking tips"),
                ("Restaurant Reviews", "Share dining experiences and recommendations"),
                ("Food Trends", "Discuss current culinary trends")
            ]
        case .lifestyle:
            return [
                ("Wellness Tips", "Share health and wellness advice"),
                ("Life Hacks", "Exchange productivity and life improvement tips"),
                ("Personal Growth", "Discuss self-improvement journeys")
            ]
        case .education:
            return [
                ("Study Tips", "Share effective learning strategies"),
                ("Online Courses", "Discuss educational platforms and courses"),
                ("Academic Discussions", "Talk about various academic subjects")
            ]
        case .science:
            return [
                ("Scientific Breakthroughs", "Discuss recent scientific discoveries"),
                ("Space Exploration", "Talk about astronomy and space missions"),
                ("Research Findings", "Share interesting research papers and studies")
            ]
        case .books:
            return [
                ("Book Recommendations", "Share your favorite reads"),
                ("Author Discussions", "Talk about favorite authors and their works"),
                ("Reading Challenges", "Discuss reading goals and achievements")
            ]
        case .travel:
            return [
                ("Travel Destinations", "Share amazing places to visit"),
                ("Trip Planning", "Get advice for upcoming travels"),
                ("Cultural Experiences", "Discuss cultural discoveries while traveling")
            ]
        case .fashion:
            return [
                ("Style Trends", "Discuss current fashion movements"),
                ("Outfit Inspiration", "Share and get styling advice"),
                ("Designer Spotlights", "Talk about fashion designers and brands")
            ]
        case .worldNews:
            return [
                ("Global Events", "Discuss international news and events"),
                ("Cultural Exchanges", "Share experiences from different cultures"),
                ("World Politics", "Analyze global political developments")
            ]
        case .health:
            return [
                ("Fitness Routines", "Share workout tips and experiences"),
                ("Mental Health", "Discuss wellness and mental health topics"),
                ("Nutrition Advice", "Exchange healthy eating tips")
            ]
        case .automotive:
            return [
                ("Car Reviews", "Discuss vehicle performance and features"),
                ("Electric Vehicles", "Talk about the future of transportation"),
                ("Racing Updates", "Follow motorsport events and news")
            ]
        case .other:
            return [
                ("General Discussion", "Open conversation about anything"),
                ("Random Topics", "Discuss whatever's on your mind"),
                ("Community Chat", "Connect with others in the community")
            ]
        }
    }
}
