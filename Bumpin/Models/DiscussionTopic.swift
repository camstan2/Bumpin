import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Discussion Topic Models

struct DiscussionTopic: Identifiable, Codable {
    let id: String
    let name: String
    let category: TopicCategory
    let createdBy: String
    let createdAt: Date
    
    // Stats
    var activeDiscussions: Int
    var totalDiscussions: Int
    var lastActivity: Date
    var isTrending: Bool
    
    // Metadata
    var description: String?
    var tags: [String]
    var isModerated: Bool
    var similarTopics: [String]? // IDs of similar topics
    
    // Ranking data
    var trendingScore: Double
    var weeklyDiscussionCount: Int
    var monthlyDiscussionCount: Int
    
    init(id: String = UUID().uuidString, 
         name: String, 
         category: TopicCategory, 
         createdBy: String, 
         description: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.createdBy = createdBy
        self.createdAt = Date()
        self.description = description
        
        // Initialize stats
        self.activeDiscussions = 0
        self.totalDiscussions = 0
        self.lastActivity = Date()
        self.isTrending = false
        self.tags = []
        self.isModerated = false
        self.similarTopics = nil
        self.trendingScore = 0.0
        self.weeklyDiscussionCount = 0
        self.monthlyDiscussionCount = 0
    }
}

enum TopicCategory: String, CaseIterable, Codable {
    case trending = "trending"
    case music = "music"
    case sports = "sports"
    case movies = "movies"
    case tv = "tv"
    case politics = "politics"
    case technology = "technology"
    case gaming = "gaming"
    case books = "books"
    case food = "food"
    case travel = "travel"
    case fashion = "fashion"
    case art = "art"
    case science = "science"
    case business = "business"
    case entertainment = "entertainment"
    case arts = "arts"
    case lifestyle = "lifestyle"
    case education = "education"
    case worldNews = "worldNews"
    case health = "health"
    case automotive = "automotive"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .trending: return "Trending"
        case .music: return "Music"
        case .sports: return "Sports"
        case .movies: return "Movies"
        case .tv: return "TV Shows"
        case .politics: return "Politics"
        case .technology: return "Technology"
        case .gaming: return "Gaming"
        case .books: return "Books"
        case .food: return "Food"
        case .travel: return "Travel"
        case .fashion: return "Fashion"
        case .art: return "Art"
        case .science: return "Science"
        case .business: return "Business"
        case .entertainment: return "Entertainment"
        case .arts: return "Arts"
        case .lifestyle: return "Lifestyle"
        case .education: return "Education"
        case .worldNews: return "World News"
        case .health: return "Health"
        case .automotive: return "Automotive"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .trending: return "flame"
        case .music: return "music.note"
        case .sports: return "sportscourt"
        case .movies: return "tv"
        case .tv: return "tv.circle"
        case .politics: return "building.2"
        case .technology: return "laptopcomputer"
        case .gaming: return "gamecontroller"
        case .books: return "book"
        case .food: return "fork.knife"
        case .travel: return "airplane"
        case .fashion: return "tshirt"
        case .art: return "paintbrush"
        case .science: return "atom"
        case .business: return "briefcase"
        case .entertainment: return "theatermasks"
        case .arts: return "paintpalette"
        case .lifestyle: return "heart"
        case .education: return "graduationcap"
        case .worldNews: return "globe"
        case .health: return "cross"
        case .automotive: return "car"
        case .other: return "ellipsis.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .trending: return .orange
        case .music: return .purple
        case .sports: return .orange
        case .movies: return .red
        case .tv: return .blue
        case .politics: return .gray
        case .technology: return .cyan
        case .gaming: return .green
        case .books: return .brown
        case .food: return .yellow
        case .travel: return .mint
        case .fashion: return .pink
        case .art: return .indigo
        case .science: return .teal
        case .business: return .black
        case .entertainment: return .red
        case .arts: return .indigo
        case .lifestyle: return .pink
        case .education: return .blue
        case .worldNews: return .gray
        case .health: return .green
        case .automotive: return .black
        case .other: return .secondary
        }
    }
    
    // Default categories for party discovery
    static let defaultCategories: [TopicCategory] = [
        .trending, .music, .sports, .movies, .gaming, .entertainment
    ]
}

// MARK: - Discussion Category Enum

enum DiscussionCategory: String, CaseIterable, Codable {
    case music = "music"
    case sports = "sports"
    case movies = "movies"
    case tv = "tv"
    case politics = "politics"
    case technology = "technology"
    case gaming = "gaming"
    case books = "books"
    case food = "food"
    case travel = "travel"
    case fashion = "fashion"
    case art = "art"
    case science = "science"
    case business = "business"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .music: return "Music"
        case .sports: return "Sports"
        case .movies: return "Movies"
        case .tv: return "TV Shows"
        case .politics: return "Politics"
        case .technology: return "Technology"
        case .gaming: return "Gaming"
        case .books: return "Books"
        case .food: return "Food"
        case .travel: return "Travel"
        case .fashion: return "Fashion"
        case .art: return "Art"
        case .science: return "Science"
        case .business: return "Business"
        case .other: return "Other"
        }
    }
}

struct TopicStats: Codable {
    let topicId: String
    var viewCount: Int
    var discussionCount: Int
    var participantCount: Int
    var lastViewed: Date
    var engagementScore: Double
    
    init(topicId: String) {
        self.topicId = topicId
        self.viewCount = 0
        self.discussionCount = 0
        self.participantCount = 0
        self.lastViewed = Date()
        self.engagementScore = 0.0
    }
}

// MARK: - Topic Creation Models

struct ProposedTopic {
    let name: String
    let category: TopicCategory
    let description: String?
    let tags: [String]
    let createdBy: String
}

enum TopicSortOption: String, CaseIterable {
    case trending = "trending"
    case newest = "newest"
    case mostActive = "most_active"
    case alphabetical = "alphabetical"
    
    var displayName: String {
        switch self {
        case .trending: return "Trending"
        case .newest: return "Newest"
        case .mostActive: return "Most Active"
        case .alphabetical: return "A-Z"
        }
    }
}

// MARK: - Topic Errors

enum TopicError: Error, LocalizedError {
    case notAuthenticated
    case topicNotFound
    case duplicateTopic
    case invalidTopicName
    case moderationRequired
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .topicNotFound:
            return "Topic not found"
        case .duplicateTopic:
            return "A similar topic already exists"
        case .invalidTopicName:
            return "Topic name is invalid or too short"
        case .moderationRequired:
            return "This topic requires moderation approval"
        case .networkError:
            return "Network error occurred"
        }
    }
}
