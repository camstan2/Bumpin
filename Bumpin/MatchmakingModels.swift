import Foundation
import FirebaseFirestore

// MARK: - Matchmaking Data Models

/// User's matchmaking preferences and history
struct MatchmakingProfile: Identifiable, Codable {
    let id: String // Same as userId
    let userId: String
    var optedIn: Bool
    var gender: MatchmakingGender?
    var preferredGender: MatchmakingGender?
    var lastActive: Date
    var totalMatches: Int
    var successfulConnections: Int
    var preferences: MatchmakingPreferences
    var history: [String] // Previous match user IDs
    
    init(userId: String) {
        self.id = userId
        self.userId = userId
        self.optedIn = false
        self.gender = nil
        self.preferredGender = .any
        self.lastActive = Date()
        self.totalMatches = 0
        self.successfulConnections = 0
        self.preferences = MatchmakingPreferences()
        self.history = []
    }
}

/// Gender options for matchmaking
enum MatchmakingGender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case nonBinary = "non_binary"
    case preferNotToSay = "prefer_not_to_say"
    case any = "any"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .nonBinary: return "Non-binary"
        case .preferNotToSay: return "Prefer not to say"
        case .any: return "Any"
        }
    }
}

/// User's detailed matchmaking preferences
struct MatchmakingPreferences: Codable {
    var genreWeighting: Double // How much to weight genre similarity (0.0-1.0)
    var artistWeighting: Double // How much to weight artist overlap (0.0-1.0)
    var ratingWeighting: Double // How much to weight rating correlation (0.0-1.0)
    var discoveryWeighting: Double // How much to weight discovery potential (0.0-1.0)
    var minimumSimilarityScore: Double // Minimum score to consider a match (0.0-1.0)
    var excludePreviousMatches: Bool // Whether to exclude previous matches
    var cooldownPeriodWeeks: Int // Weeks before re-matching with same person
    
    init() {
        self.genreWeighting = 0.3
        self.artistWeighting = 0.4
        self.ratingWeighting = 0.2
        self.discoveryWeighting = 0.1
        self.minimumSimilarityScore = 0.6
        self.excludePreviousMatches = true
        self.cooldownPeriodWeeks = 8
    }
}

/// A weekly match result
struct WeeklyMatch: Identifiable, Codable {
    let id: String
    let userId: String
    let matchedUserId: String
    let week: String
    let timestamp: Date
    let similarityScore: Double
    let sharedArtists: [String]
    let sharedGenres: [String]
    let botMessageSent: Bool
    var userResponded: Bool
    var matchSuccess: Bool?
    var responseTimestamp: Date?
    var connectionQuality: MatchConnectionQuality?
    
    init(userId: String, matchedUserId: String, week: String, similarityScore: Double, sharedArtists: [String], sharedGenres: [String]) {
        self.id = "\(userId)_\(matchedUserId)_\(week)"
        self.userId = userId
        self.matchedUserId = matchedUserId
        self.week = week
        self.timestamp = Date()
        self.similarityScore = similarityScore
        self.sharedArtists = sharedArtists
        self.sharedGenres = sharedGenres
        self.botMessageSent = false
        self.userResponded = false
        self.matchSuccess = nil
        self.responseTimestamp = nil
        self.connectionQuality = nil
    }
}

/// Quality of a match connection
enum MatchConnectionQuality: String, Codable {
    case noResponse = "no_response"
    case viewed = "viewed"
    case messaged = "messaged"
    case conversation = "conversation"
    case connection = "connection"
    
    var displayName: String {
        switch self {
        case .noResponse: return "No Response"
        case .viewed: return "Profile Viewed"
        case .messaged: return "Message Sent"
        case .conversation: return "Conversation Started"
        case .connection: return "Strong Connection"
        }
    }
}

/// Music taste similarity analysis
struct MusicTasteSimilarity: Codable {
    let user1Id: String
    let user2Id: String
    let overallScore: Double
    let artistSimilarity: Double
    let genreSimilarity: Double
    let ratingCorrelation: Double
    let discoveryPotential: Double
    let sharedArtists: [SharedArtist]
    let sharedGenres: [String]
    let analysisDate: Date
    
    struct SharedArtist: Codable {
        let name: String
        let user1Rating: Double?
        let user2Rating: Double?
        let commonSongs: Int
    }
}

/// Weekly matchmaking statistics
struct WeeklyMatchmakingStats: Identifiable, Codable {
    let id: String // Same as week
    let week: String
    let totalEligibleUsers: Int
    let totalMatches: Int
    let averageSimilarityScore: Double
    let responseRate: Double
    let successRate: Double
    let topSharedArtists: [String]
    let topSharedGenres: [String]
    let processingTime: TimeInterval
    let timestamp: Date
    
    init(week: String) {
        self.id = week
        self.week = week
        self.totalEligibleUsers = 0
        self.totalMatches = 0
        self.averageSimilarityScore = 0.0
        self.responseRate = 0.0
        self.successRate = 0.0
        self.topSharedArtists = []
        self.topSharedGenres = []
        self.processingTime = 0.0
        self.timestamp = Date()
    }
    
    init(week: String, totalEligibleUsers: Int, totalMatches: Int, averageSimilarityScore: Double, responseRate: Double, successRate: Double, topSharedArtists: [String], topSharedGenres: [String], processingTime: TimeInterval) {
        self.id = week
        self.week = week
        self.totalEligibleUsers = totalEligibleUsers
        self.totalMatches = totalMatches
        self.averageSimilarityScore = averageSimilarityScore
        self.responseRate = responseRate
        self.successRate = successRate
        self.topSharedArtists = topSharedArtists
        self.topSharedGenres = topSharedGenres
        self.processingTime = processingTime
        self.timestamp = Date()
    }
}

// MARK: - Firestore Extensions

extension MatchmakingProfile {
    static func create(_ profile: MatchmakingProfile, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        do {
            try db.collection("musicMatchmaking").document(profile.id).setData(from: profile) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    static func fetch(userId: String, completion: @escaping (MatchmakingProfile?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("musicMatchmaking").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                // Create default profile if none exists
                let defaultProfile = MatchmakingProfile(userId: userId)
                completion(defaultProfile, nil)
                return
            }
            
            do {
                let profile = try snapshot.data(as: MatchmakingProfile.self)
                completion(profile, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    static func update(_ profile: MatchmakingProfile, completion: @escaping (Error?) -> Void) {
        create(profile, completion: completion)
    }
}

extension WeeklyMatch {
    static func create(_ match: WeeklyMatch, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        do {
            try db.collection("weeklyMatches").document(match.id).setData(from: match) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    static func fetchForUser(userId: String, limit: Int = 50, completion: @escaping ([WeeklyMatch]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("weeklyMatches")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let matches = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: WeeklyMatch.self)
                } ?? []
                
                completion(matches, nil)
            }
    }
    
    static func fetchForWeek(_ week: String, completion: @escaping ([WeeklyMatch]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("weeklyMatches")
            .whereField("week", isEqualTo: week)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let matches = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: WeeklyMatch.self)
                } ?? []
                
                completion(matches, nil)
            }
    }
}

extension WeeklyMatchmakingStats {
    static func create(_ stats: WeeklyMatchmakingStats, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        do {
            try db.collection("matchmakingStats").document(stats.id).setData(from: stats) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
}

// MARK: - Utility Extensions

extension Date {
    /// Get week identifier in format YYYY-W##
    var weekId: String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: self)
        let week = calendar.component(.weekOfYear, from: self)
        return "\(year)-W\(String(format: "%02d", week))"
    }
    
    /// Check if date is within the last N weeks
    func isWithinWeeks(_ weeks: Int) -> Bool {
        let calendar = Calendar.current
        guard let weeksAgo = calendar.date(byAdding: .weekOfYear, value: -weeks, to: Date()) else {
            return false
        }
        return self >= weeksAgo
    }
}
