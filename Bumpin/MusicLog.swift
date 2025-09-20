import Foundation
import FirebaseFirestore
import SwiftUI // Added for Color

struct MusicLog: Identifiable, Codable {
    var id: String
    var userId: String
    var itemId: String // Platform-specific ID (Apple Music/Spotify)
    var itemType: String // "song" or "album"
    var title: String
    var artistName: String
    var artworkUrl: String?
    var dateLogged: Date
    var rating: Int? // 1-5 stars, optional
    var review: String? // optional
    var notes: String? // optional
    var commentCount: Int? // Track number of comments
    var helpfulCount: Int? // Track helpful votes
    var unhelpfulCount: Int? // Track unhelpful votes
    var reviewPhotos: [String]? // URLs for review photos
    var isLiked: Bool? // Track if user liked this item
    var thumbsUp: Bool? // Track thumbs up
    var thumbsDown: Bool? // Track thumbs down
    var isPublic: Bool? // Optional visibility; default true when nil
    // Phase 2: Apple Music genre data
    var appleMusicGenres: [String]? // Genres from Apple Music
    var primaryGenre: String? // Primary genre classification
    // Phase 3: User corrections and learning
    var userCorrectedGenre: String? // User manually corrected genre
    var genreConfidenceScore: Double? // Confidence in genre classification (0.0-1.0)
    var classificationMethod: String? // How genre was determined ("apple_music", "artist_db", "keyword", "user_corrected")
    
    // Phase 4: Cross-platform unification
    var universalTrackId: String? // Universal track ID for cross-platform profiles
    var musicPlatform: String? // "apple_music", "spotify", etc.
    var platformMatchingConfidence: Double? // Confidence in platform matching (0.0-1.0)
    
    // Computed property for review length indicator
    var reviewLength: ReviewLength {
        guard let review = review, !review.isEmpty else { return .none }
        let wordCount = review.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        if wordCount < 25 { return .short }
        else if wordCount < 100 { return .medium }
        else { return .long }
    }
}

enum ReviewLength: String, CaseIterable {
    case none = "none"
    case short = "short"
    case medium = "medium"
    case long = "long"
    
    var displayText: String {
        switch self {
        case .none: return ""
        case .short: return "Quick Review"
        case .medium: return "Review"
        case .long: return "In-Depth Review"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .clear
        case .short: return .blue
        case .medium: return .orange
        case .long: return .purple
        }
    }
}

// Comment model for reviews
struct ReviewComment: Identifiable, Codable {
    var id: String
    var logId: String // Reference to the MusicLog
    var userId: String
    var username: String
    var userProfilePictureUrl: String?
    var text: String
    var createdAt: Date
    
    init(logId: String, userId: String, username: String, userProfilePictureUrl: String?, text: String) {
        self.id = UUID().uuidString
        self.logId = logId
        self.userId = userId
        self.username = username
        self.userProfilePictureUrl = userProfilePictureUrl
        self.text = text
        self.createdAt = Date()
    }
}

// Model for tracking helpful/unhelpful votes on reviews
struct ReviewHelpfulVote: Identifiable, Codable {
    var id: String
    var logId: String // Reference to the MusicLog
    var userId: String
    var isHelpful: Bool // true for helpful, false for unhelpful
    var createdAt: Date
    
    init(logId: String, userId: String, isHelpful: Bool) {
        self.id = UUID().uuidString
        self.logId = logId
        self.userId = userId
        self.isHelpful = isHelpful
        self.createdAt = Date()
    }
}

extension MusicLog {
    static func createLog(_ log: MusicLog, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("logs").document(log.id).setData(from: log) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }

    static func updateLog(_ log: MusicLog, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("logs").document(log.id).setData(from: log) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }

    static func deleteLog(logId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("logs").document(logId).delete { error in
            completion?(error)
        }
    }

    static func fetchLogsForUser(userId: String, completion: @escaping ([MusicLog]?, Error?) -> Void) {
        let db = Firestore.firestore()
        // Temporary fix: Remove ordering to avoid index requirement - sort in app instead
        db.collection("logs").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching logs: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            let logs = snapshot?.documents.compactMap { try? $0.data(as: MusicLog.self) } ?? []
            // Sort in app to avoid needing Firestore composite index
            let sortedLogs = logs.sorted { $0.dateLogged > $1.dateLogged }
            print("✅ Fetched \(sortedLogs.count) logs for user")
            completion(sortedLogs, nil)
        }
    }

    static func fetchAllLogs(completion: @escaping ([MusicLog]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("logs").order(by: "dateLogged", descending: true).getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            let logs = snapshot?.documents.compactMap { try? $0.data(as: MusicLog.self) }
            completion(logs, nil)
        }
    }
    
    // Update comment count for a log
    static func updateCommentCount(logId: String, increment: Bool, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let logRef = db.collection("logs").document(logId)
        
        logRef.getDocument { document, error in
            if let error = error {
                completion?(error)
                return
            }
            
            let currentCount = document?.data()?["commentCount"] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            
            logRef.updateData(["commentCount": newCount]) { error in
                completion?(error)
            }
        }
    }
    
    // Update helpful/unhelpful count for a log
    static func fetchLogsForItem(itemId: String, friendIds: [String]? = nil, limit: Int = 20, completion: @escaping ([MusicLog]?, Error?) -> Void) {
        let db = Firestore.firestore()
        var baseQuery: Query = db.collection("logs").whereField("itemId", isEqualTo: itemId)
        // If friendIds provided and <= 10, use an `in` query. Otherwise caller should batch.
        if let ids = friendIds, !ids.isEmpty, ids.count <= 10 {
            baseQuery = baseQuery.whereField("userId", in: ids)
        }
        baseQuery = baseQuery.limit(to: limit)
        baseQuery.getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            let logs = snapshot?.documents.compactMap { try? $0.data(as: MusicLog.self) }
            completion(logs, nil)
        }
    }

    static func updateHelpfulCount(logId: String, isHelpful: Bool, increment: Bool, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let logRef = db.collection("logs").document(logId)
        
        logRef.getDocument { document, error in
            if let error = error {
                completion?(error)
                return
            }
            
            let fieldName = isHelpful ? "helpfulCount" : "unhelpfulCount"
            let currentCount = document?.data()?[fieldName] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            
            logRef.updateData([fieldName: newCount]) { error in
                completion?(error)
            }
        }
    }
}

// MARK: - ReviewComment Operations
extension ReviewComment {
    static func addComment(_ comment: ReviewComment, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("logs").document(comment.logId)
                .collection("comments").document(comment.id).setData(from: comment) { error in
                    if error == nil {
                        // Update comment count
                        MusicLog.updateCommentCount(logId: comment.logId, increment: true)
                    }
                    completion?(error)
                }
        } catch {
            completion?(error)
        }
    }
    
    static func fetchCommentsForLog(logId: String, limit: Int = 25, completion: @escaping ([ReviewComment]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("logs").document(logId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                let comments = snapshot?.documents.compactMap { try? $0.data(as: ReviewComment.self) }
                completion(comments, nil)
            }
    }
    
    static func deleteComment(logId: String, commentId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("logs").document(logId)
            .collection("comments").document(commentId).delete { error in
                if error == nil {
                    // Update comment count
                    MusicLog.updateCommentCount(logId: logId, increment: false)
                }
                completion?(error)
            }
    }
} 

// MARK: - ReviewHelpfulVote Operations
extension ReviewHelpfulVote {
    static func addVote(_ vote: ReviewHelpfulVote, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("logs").document(vote.logId)
                .collection("helpful_votes").document(vote.id).setData(from: vote) { error in
                    if error == nil {
                        // Update helpful count
                        MusicLog.updateHelpfulCount(logId: vote.logId, isHelpful: vote.isHelpful, increment: true)
                    }
                    completion?(error)
                }
        } catch {
            completion?(error)
        }
    }
    
    static func removeVote(logId: String, userId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        
        // First find the existing vote
        db.collection("logs").document(logId)
            .collection("helpful_votes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion?(error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion?(nil) // No vote found
                    return
                }
                
                if let vote = try? document.data(as: ReviewHelpfulVote.self) {
                    // Remove the vote
                    document.reference.delete { error in
                        if error == nil {
                            // Update helpful count
                            MusicLog.updateHelpfulCount(logId: logId, isHelpful: vote.isHelpful, increment: false)
                        }
                        completion?(error)
                    }
                }
            }
    }
    
    static func updateVote(logId: String, userId: String, isHelpful: Bool, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        
        // First find the existing vote
        db.collection("logs").document(logId)
            .collection("helpful_votes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion?(error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    // No existing vote, create new one
                    let newVote = ReviewHelpfulVote(logId: logId, userId: userId, isHelpful: isHelpful)
                    addVote(newVote, completion: completion)
                    return
                }
                
                if let existingVote = try? document.data(as: ReviewHelpfulVote.self) {
                    if existingVote.isHelpful == isHelpful {
                        // Same vote, remove it
                        removeVote(logId: logId, userId: userId, completion: completion)
                    } else {
                        // Different vote, update it
                        let updatedVote = ReviewHelpfulVote(logId: logId, userId: userId, isHelpful: isHelpful)
                        
                        // Remove old count, add new count
                        MusicLog.updateHelpfulCount(logId: logId, isHelpful: existingVote.isHelpful, increment: false)
                        MusicLog.updateHelpfulCount(logId: logId, isHelpful: isHelpful, increment: true)
                        
                        // Update the document
                        do {
                            try document.reference.setData(from: updatedVote) { error in
                                completion?(error)
                            }
                        } catch {
                            completion?(error)
                        }
                    }
                }
            }
    }
    
    static func getUserVote(logId: String, userId: String, completion: @escaping (ReviewHelpfulVote?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("logs").document(logId)
            .collection("helpful_votes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let vote = snapshot?.documents.first.flatMap { try? $0.data(as: ReviewHelpfulVote.self) }
                completion(vote, nil)
        }
    }
} 

// MARK: - Repost model and operations
struct Repost: Identifiable, Codable {
    var id: String
    var logId: String? // If reposting a user log
    var itemId: String? // If reposting an item (song/album/artist)
    var itemType: String? // "song", "album", "artist"
    var userId: String // who reposted
    var createdAt: Date
    
    init(logId: String, userId: String) {
        self.id = UUID().uuidString
        self.logId = logId
        self.itemId = nil
        self.itemType = nil
        self.userId = userId
        self.createdAt = Date()
    }
    
    init(itemId: String, itemType: String, userId: String) {
        self.id = UUID().uuidString
        self.logId = nil
        self.itemId = itemId
        self.itemType = itemType
        self.userId = userId
        self.createdAt = Date()
    }
}

extension Repost {
    // Add a repost
    static func add(_ repost: Repost, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            let collection: CollectionReference
            if let logId = repost.logId { collection = db.collection("logs").document(logId).collection("reposts") }
            else { collection = db.collection("items").document(repost.itemId ?? "").collection("reposts") }
            try collection.document(repost.id).setData(from: repost) { error in completion?(error) }
        } catch { completion?(error) }
    }
    
    // Remove a repost by this user
    static func remove(forUser userId: String, logId: String? = nil, itemId: String? = nil, itemType: String? = nil, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let collection: CollectionReference
        if let logId = logId { collection = db.collection("logs").document(logId).collection("reposts") }
        else { collection = db.collection("items").document(itemId ?? "").collection("reposts") }
        collection.whereField("userId", isEqualTo: userId).getDocuments { snap, err in
            if let err = err { completion?(err); return }
            let batch = db.batch()
            snap?.documents.forEach { batch.deleteDocument($0.reference) }
            batch.commit { completion?($0) }
        }
    }
    
    // Check whether the user has reposted
    static func hasReposted(userId: String, logId: String? = nil, itemId: String? = nil, itemType: String? = nil, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let collection: CollectionReference
        if let logId = logId { collection = db.collection("logs").document(logId).collection("reposts") }
        else { collection = db.collection("items").document(itemId ?? "").collection("reposts") }
        collection.whereField("userId", isEqualTo: userId).limit(to: 1).getDocuments { snap, _ in
            completion(!(snap?.documents.isEmpty ?? true))
        }
    }
    
    // Fetch list of users who reposted (for attribution)
    static func fetchReposters(logId: String? = nil, itemId: String? = nil, completion: @escaping ([String]) -> Void) {
        let db = Firestore.firestore()
        let collection: CollectionReference
        if let logId = logId { collection = db.collection("logs").document(logId).collection("reposts") }
        else { collection = db.collection("items").document(itemId ?? "").collection("reposts") }
        collection.limit(to: 10).getDocuments { snap, _ in
            let ids = (snap?.documents.compactMap { try? $0.data(as: Repost.self) } ?? []).map { $0.userId }
            completion(ids)
        }
    }
} 