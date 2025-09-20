import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Daily Prompt Models

struct DailyPrompt: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    var date: Date
    var isActive: Bool
    let createdBy: String // Admin user ID
    let createdAt: Date
    let expiresAt: Date
    let category: PromptCategory
    var totalResponses: Int
    var featuredSongs: [String] // Top song IDs for quick access
    var isArchived: Bool
    
    init(title: String, description: String? = nil, category: PromptCategory, createdBy: String, expiresAt: Date) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.date = Date()
        self.isActive = false // Will be activated by admin/scheduler
        self.createdBy = createdBy
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.category = category
        self.totalResponses = 0
        self.featuredSongs = []
        self.isArchived = false
    }
}

enum PromptCategory: String, Codable, CaseIterable, Identifiable {
    case mood = "mood"
    case activity = "activity" 
    case nostalgia = "nostalgia"
    case genre = "genre"
    case season = "season"
    case emotion = "emotion"
    case discovery = "discovery"
    case social = "social"
    case special = "special" // holidays, events
    case random = "random"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mood: return "Mood"
        case .activity: return "Activity"
        case .nostalgia: return "Nostalgia"
        case .genre: return "Genre"
        case .season: return "Season"
        case .emotion: return "Emotion"
        case .discovery: return "Discovery"
        case .social: return "Social"
        case .special: return "Special"
        case .random: return "Random"
        }
    }
    
    var icon: String {
        switch self {
        case .mood: return "face.smiling"
        case .activity: return "figure.run"
        case .nostalgia: return "clock.arrow.circlepath"
        case .genre: return "music.note.list"
        case .season: return "leaf"
        case .emotion: return "heart"
        case .discovery: return "magnifyingglass"
        case .social: return "person.2"
        case .special: return "star"
        case .random: return "shuffle"
        }
    }
    
    var color: Color {
        switch self {
        case .mood: return .yellow
        case .activity: return .green
        case .nostalgia: return .brown
        case .genre: return .purple
        case .season: return .orange
        case .emotion: return .pink
        case .discovery: return .blue
        case .social: return .teal
        case .special: return .red
        case .random: return .gray
        }
    }
}

struct PromptResponse: Identifiable, Codable {
    let id: String
    let promptId: String
    let userId: String
    let username: String // Cache for display
    let userProfilePictureUrl: String? // Cache for display
    
    // Song details
    let songId: String // Apple Music ID
    let songTitle: String
    let artistName: String
    let albumName: String?
    let artworkUrl: String?
    let appleMusicUrl: String? // Deep link to Apple Music
    
    // Response details
    let explanation: String? // Optional user explanation for their choice
    let submittedAt: Date
    var isPublic: Bool
    
    // Engagement
    var likeCount: Int
    var commentCount: Int
    
    // Moderation
    var isReported: Bool
    var isHidden: Bool
    
    init(promptId: String, userId: String, username: String, userProfilePictureUrl: String?, songId: String, songTitle: String, artistName: String, albumName: String? = nil, artworkUrl: String? = nil, appleMusicUrl: String? = nil, explanation: String? = nil, isPublic: Bool = true) {
        self.id = UUID().uuidString
        self.promptId = promptId
        self.userId = userId
        self.username = username
        self.userProfilePictureUrl = userProfilePictureUrl
        self.songId = songId
        self.songTitle = songTitle
        self.artistName = artistName
        self.albumName = albumName
        self.artworkUrl = artworkUrl
        self.appleMusicUrl = appleMusicUrl
        self.explanation = explanation
        self.submittedAt = Date()
        self.isPublic = isPublic
        self.likeCount = 0
        self.commentCount = 0
        self.isReported = false
        self.isHidden = false
    }
}

struct PromptLeaderboard: Codable {
    let promptId: String
    let songRankings: [SongRanking]
    let totalResponses: Int
    let lastUpdated: Date
    let topGenres: [String] // Most common genres in responses
    let averageResponseTime: TimeInterval? // Average time to respond after prompt goes live
    
    init(promptId: String, songRankings: [SongRanking] = [], totalResponses: Int = 0) {
        self.promptId = promptId
        self.songRankings = songRankings
        self.totalResponses = totalResponses
        self.lastUpdated = Date()
        self.topGenres = []
        self.averageResponseTime = nil
    }
}

struct SongRanking: Identifiable, Codable, Equatable {
    let id: String // songId
    let songTitle: String
    let artistName: String
    let albumName: String?
    let artworkUrl: String?
    let appleMusicUrl: String?
    var voteCount: Int
    var percentage: Double
    var rank: Int
    let sampleUsers: [ResponseUser] // Sample users who chose this song
    let firstSubmittedAt: Date // When this song was first submitted
    
    init(songId: String, songTitle: String, artistName: String, albumName: String? = nil, artworkUrl: String? = nil, appleMusicUrl: String? = nil, voteCount: Int = 1, sampleUsers: [ResponseUser] = []) {
        self.id = songId
        self.songTitle = songTitle
        self.artistName = artistName
        self.albumName = albumName
        self.artworkUrl = artworkUrl
        self.appleMusicUrl = appleMusicUrl
        self.voteCount = voteCount
        self.percentage = 0.0 // Will be calculated
        self.rank = 0 // Will be calculated
        self.sampleUsers = sampleUsers
        self.firstSubmittedAt = Date()
    }
    
    static func == (lhs: SongRanking, rhs: SongRanking) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ResponseUser: Codable, Identifiable {
    let id: String // userId
    let username: String
    let profilePictureUrl: String?
    let explanation: String?
    let submittedAt: Date
    
    init(userId: String, username: String, profilePictureUrl: String? = nil, explanation: String? = nil) {
        self.id = userId
        self.username = username
        self.profilePictureUrl = profilePictureUrl
        self.explanation = explanation
        self.submittedAt = Date()
    }
}

// MARK: - Prompt Statistics & Analytics

struct PromptStats: Codable {
    let promptId: String
    let totalResponses: Int
    let uniqueArtists: Int
    let uniqueGenres: Int
    let averageRating: Double? // Average rating of selected songs
    let responseTimeStats: ResponseTimeStats
    let engagementStats: EngagementStats
    let demographicBreakdown: DemographicBreakdown?
    
    struct ResponseTimeStats: Codable {
        let averageTime: TimeInterval
        let fastestTime: TimeInterval
        let slowestTime: TimeInterval
        let medianTime: TimeInterval
    }
    
    struct EngagementStats: Codable {
        let totalLikes: Int
        let totalComments: Int
        let averageLikesPerResponse: Double
        let averageCommentsPerResponse: Double
        let shareCount: Int
    }
    
    struct DemographicBreakdown: Codable {
        let ageGroups: [String: Int] // If we have age data
        let topRegions: [String: Int] // If we have location data
        let newVsReturningUsers: [String: Int]
    }
}

// MARK: - Prompt Templates & Suggestions

struct PromptTemplate: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let category: PromptCategory
    let isActive: Bool
    let usageCount: Int
    let createdAt: Date
    let tags: [String]
    
    init(title: String, description: String? = nil, category: PromptCategory, tags: [String] = []) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.category = category
        self.isActive = true
        self.usageCount = 0
        self.createdAt = Date()
        self.tags = tags
    }
}

// MARK: - User Prompt History & Streaks

struct UserPromptStats: Codable {
    let userId: String
    var totalResponses: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastResponseDate: Date?
    var favoriteCategories: [PromptCategory: Int]
    var totalLikesReceived: Int
    var totalCommentsReceived: Int
    var averageResponseTime: TimeInterval?
    
    init(userId: String) {
        self.userId = userId
        self.totalResponses = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastResponseDate = nil
        self.favoriteCategories = [:]
        self.totalLikesReceived = 0
        self.totalCommentsReceived = 0
        self.averageResponseTime = nil
    }
}

// MARK: - Firestore Extensions

extension DailyPrompt {
    
    static func createPrompt(_ prompt: DailyPrompt, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("dailyPrompts").document(prompt.id).setData(from: prompt) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }
    
    static func fetchActivePrompt(completion: @escaping (DailyPrompt?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("dailyPrompts")
            .whereField("isActive", isEqualTo: true)
            .whereField("isArchived", isEqualTo: false)
            .order(by: "date", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let prompt = snapshot?.documents.first?.data()
                if let promptData = prompt {
                    do {
                        let dailyPrompt = try Firestore.Decoder().decode(DailyPrompt.self, from: promptData)
                        completion(dailyPrompt, nil)
                    } catch {
                        completion(nil, error)
                    }
                } else {
                    completion(nil, nil) // No active prompt
                }
            }
    }
    
    static func fetchPromptHistory(limit: Int = 30, completion: @escaping ([DailyPrompt]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("dailyPrompts")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let prompts = snapshot?.documents.compactMap { document in
                    try? document.data(as: DailyPrompt.self)
                }
                completion(prompts, nil)
            }
    }
}

extension PromptResponse {
    
    static func createResponse(_ response: PromptResponse, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("promptResponses").document(response.id).setData(from: response) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }
    
    static func fetchUserResponse(promptId: String, userId: String, completion: @escaping (PromptResponse?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("promptResponses")
            .whereField("promptId", isEqualTo: promptId)
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let response = snapshot?.documents.first?.data()
                if let responseData = response {
                    do {
                        let promptResponse = try Firestore.Decoder().decode(PromptResponse.self, from: responseData)
                        completion(promptResponse, nil)
                    } catch {
                        completion(nil, error)
                    }
                } else {
                    completion(nil, nil) // No response found
                }
            }
    }
    
    static func fetchResponsesForPrompt(promptId: String, limit: Int = 50, completion: @escaping ([PromptResponse]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("promptResponses")
            .whereField("promptId", isEqualTo: promptId)
            .whereField("isPublic", isEqualTo: true)
            .whereField("isHidden", isEqualTo: false)
            .order(by: "submittedAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let responses = snapshot?.documents.compactMap { document in
                    try? document.data(as: PromptResponse.self)
                }
                completion(responses, nil)
            }
    }
}

extension PromptLeaderboard {
    
    static func fetchLeaderboard(promptId: String, completion: @escaping (PromptLeaderboard?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("promptLeaderboards").document(promptId).getDocument { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(nil, nil)
                return
            }
            
            do {
                let leaderboard = try Firestore.Decoder().decode(PromptLeaderboard.self, from: data)
                completion(leaderboard, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    static func updateLeaderboard(_ leaderboard: PromptLeaderboard, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("promptLeaderboards").document(leaderboard.promptId).setData(from: leaderboard) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let dailyPromptActivated = Notification.Name("dailyPromptActivated")
    static let promptResponseSubmitted = Notification.Name("promptResponseSubmitted")
    static let promptLeaderboardUpdated = Notification.Name("promptLeaderboardUpdated")
}
