import Foundation
import FirebaseFirestore
import FirebaseAuth
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
    var rating: Double? // 1.0-5.0 stars with 0.1 precision, optional
    var review: String? // optional
    var notes: String? // optional
    var commentCount: Int? // Track number of comments
    var helpfulCount: Int? // Track helpful votes
    var unhelpfulCount: Int? // Track unhelpful votes
    var likeCount: Int? // Track number of likes (from UserLike collection)
    var repostCount: Int? // Track number of reposts
    var thumbsDownCount: Int? // Track number of thumbs down
    var reviewPhotos: [String]? // URLs for review photos
    var isLiked: Bool? // Track if user liked this item
    var thumbsUp: Bool? // Track thumbs up
    var thumbsDown: Bool? // Track thumbs down
    var isPublic: Bool? // Optional visibility; default true when nil
    var artistTokens: [String]? // Normalized artist identifiers for multi-artist attribution
    // Phase 2: Apple Music genre data
    var appleMusicGenres: [String]? // Genres from Apple Music
    var primaryGenre: String? // Primary genre classification
    var genres: [String]? // Normalized genres array for Firestore querying (contains primaryGenre or userCorrectedGenre)
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
    var likeCount: Int? // Track number of likes on this comment
    var replyCount: Int? // Track number of replies
    var parentCommentId: String? // If this is a reply, reference to parent comment
    
    init(logId: String, userId: String, username: String, userProfilePictureUrl: String?, text: String, parentCommentId: String? = nil) {
        self.id = UUID().uuidString
        self.logId = logId
        self.userId = userId
        self.username = username
        self.userProfilePictureUrl = userProfilePictureUrl
        self.text = text
        self.createdAt = Date()
        self.likeCount = 0
        self.replyCount = 0
        self.parentCommentId = parentCommentId
    }
    
    // Computed property for engagement score (used for sorting)
    var engagementScore: Int {
        return (likeCount ?? 0) + (replyCount ?? 0)
    }
}

// Model for tracking likes on comments
struct CommentLike: Identifiable, Codable {
    var id: String
    var commentId: String
    var userId: String
    var createdAt: Date
    
    init(commentId: String, userId: String) {
        self.id = UUID().uuidString
        self.commentId = commentId
        self.userId = userId
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

// MARK: - Current User Helpers
extension ReviewComment {
    struct CurrentUserContext {
        let userId: String
        let username: String
        let profilePictureUrl: String?
    }
    
    static func currentUserContext() async -> CurrentUserContext? {
        guard let user = Auth.auth().currentUser else { return nil }
        
        if let profile = await UserProfileCache.shared.getProfile(userId: user.uid) {
            let username = !profile.username.isEmpty ? profile.username : (profile.displayName.isEmpty ? (user.displayName ?? user.email ?? "Unknown User") : profile.displayName)
            let pictureUrl = profile.profilePictureUrl ?? user.photoURL?.absoluteString
            return CurrentUserContext(userId: user.uid, username: username, profilePictureUrl: pictureUrl)
        }
        
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(user.uid).getDocument()
            let data = snapshot.data() ?? [:]
            let username = (data["username"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? user.displayName
                ?? user.email
                ?? "Unknown User"
            let pictureUrl = (data["profilePictureUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (data["profileImageUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? user.photoURL?.absoluteString
            return CurrentUserContext(userId: user.uid, username: username, profilePictureUrl: pictureUrl)
        } catch {
            let username = user.displayName ?? user.email ?? "Unknown User"
            return CurrentUserContext(userId: user.uid, username: username, profilePictureUrl: user.photoURL?.absoluteString)
        }
    }
}

extension MusicLog {
    static func createLog(_ log: MusicLog, completion: ((Error?) -> Void)? = nil) {
        Task {
            do {
                try await MusicLogStore.shared.createLog(log)
                await MainActor.run { completion?(nil) }
            } catch {
                await MainActor.run { completion?(error) }
            }
        }
    }

    static func updateLog(_ log: MusicLog, completion: ((Error?) -> Void)? = nil) {
        Task {
            do {
                try await MusicLogStore.shared.updateLog(log)
                await MainActor.run { completion?(nil) }
            } catch {
                await MainActor.run { completion?(error) }
            }
        }
    }

    static func deleteLog(logId: String, completion: ((Error?) -> Void)? = nil) {
        Task {
            do {
                try await MusicLogStore.shared.deleteLog(logId: logId)
                await MainActor.run { completion?(nil) }
            } catch {
                await MainActor.run { completion?(error) }
            }
        }
    }

    static func fetchLogsForUser(userId: String, completion: @escaping ([MusicLog]?, Error?) -> Void) {
        Task {
            do {
                let logs = try await MusicLogStore.shared.fetchLogs(forUserId: userId)
                await MainActor.run { completion(logs, nil) }
            } catch {
                await MainActor.run { completion(nil, error) }
            }
        }
    }

    static func fetchAllLogs(completion: @escaping ([MusicLog]?, Error?) -> Void) {
        Task {
            do {
                let logs = try await MusicLogStore.shared.fetchAllLogs()
                await MainActor.run { completion(logs, nil) }
            } catch {
                await MainActor.run { completion(nil, error) }
            }
        }
    }
    
    // Update comment count for a log
    static func updateCommentCount(logId: String, increment: Bool, completion: ((Error?) -> Void)? = nil) {
        Task {
            do {
                try await MusicLogStore.shared.updateCommentCount(logId: logId, increment: increment)
                await MainActor.run { completion?(nil) }
            } catch {
                await MainActor.run { completion?(error) }
            }
        }
    }
    
    // Fetch fresh engagement metrics (likeCount, commentCount, etc.) for a log
    static func fetchEngagementMetrics(logId: String, completion: @escaping (MusicLog?, Error?) -> Void) {
        Task {
            do {
                let log = try await MusicLogStore.shared.fetchEngagementMetrics(logId: logId)
                await MainActor.run { completion(log, nil) }
            } catch {
                await MainActor.run { completion(nil, error) }
            }
        }
    }
    
    // Update helpful/unhelpful count for a log
    static func fetchLogsForItem(itemId: String, friendIds: [String]? = nil, limit: Int = 20, completion: @escaping ([MusicLog]?, Error?) -> Void) {
        Task {
            do {
                let logs = try await MusicLogStore.shared.fetchLogsForItem(itemId: itemId, friendIds: friendIds, limit: limit)
                await MainActor.run { completion(logs, nil) }
            } catch {
                await MainActor.run { completion(nil, error) }
            }
        }
    }

    static func updateHelpfulCount(logId: String, isHelpful: Bool, increment: Bool, completion: ((Error?) -> Void)? = nil) {
        Task {
            do {
                try await MusicLogStore.shared.updateHelpfulCount(logId: logId, isHelpful: isHelpful, increment: increment)
                await MainActor.run { completion?(nil) }
            } catch {
                await MainActor.run { completion?(error) }
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
                        // If this is a reply, update parent comment's reply count
                        if let parentId = comment.parentCommentId {
                            ReviewComment.updateReplyCount(logId: comment.logId, commentId: parentId, increment: true)
                        } else {
                            // Only increment log comment count for top-level comments
                            MusicLog.updateCommentCount(logId: comment.logId, increment: true)
                        }
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
    
    // Fetch replies for a specific comment
    static func fetchRepliesForComment(logId: String, parentCommentId: String, limit: Int = 3, startAfter: String? = nil, completion: @escaping ([ReviewComment]?, Error?) -> Void) {
        let db = Firestore.firestore()
        var query: Query = db.collection("logs").document(logId)
            .collection("comments")
            .whereField("parentCommentId", isEqualTo: parentCommentId)
            .order(by: "likeCount", descending: true)
            .order(by: "replyCount", descending: true)
            .limit(to: limit)
        
        // Pagination support
        if let startAfterId = startAfter {
            db.collection("logs").document(logId)
                .collection("comments").document(startAfterId).getDocument { snapshot, _ in
                    if let snapshot = snapshot {
                        query = query.start(afterDocument: snapshot)
                    }
                    query.getDocuments { snapshot, error in
                        if let error = error {
                            completion(nil, error)
                            return
                        }
                        let replies = snapshot?.documents.compactMap { try? $0.data(as: ReviewComment.self) }
                        completion(replies, nil)
                    }
                }
        } else {
            query.getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                let replies = snapshot?.documents.compactMap { try? $0.data(as: ReviewComment.self) }
                completion(replies, nil)
            }
        }
    }
    
    // Update reply count for a comment
    static func updateReplyCount(logId: String, commentId: String, increment: Bool, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let commentRef = db.collection("logs").document(logId).collection("comments").document(commentId)
        
        commentRef.getDocument { document, error in
            if let error = error {
                completion?(error)
                return
            }
            
            let currentCount = document?.data()?["replyCount"] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            
            commentRef.updateData(["replyCount": newCount]) { error in
                completion?(error)
            }
        }
    }
    
    // Update like count for a comment
    static func updateLikeCount(logId: String, commentId: String, increment: Bool, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let commentRef = db.collection("logs").document(logId).collection("comments").document(commentId)
        
        commentRef.getDocument { document, error in
            if let error = error {
                completion?(error)
                return
            }
            
            let currentCount = document?.data()?["likeCount"] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            
            commentRef.updateData(["likeCount": newCount]) { error in
                completion?(error)
            }
        }
    }
} 

// MARK: - CommentLike Operations
extension CommentLike {
    // Add a like to a comment
    static func addLike(_ like: CommentLike, logId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("logs").document(logId)
                .collection("comments").document(like.commentId)
                .collection("likes").document(like.id).setData(from: like) { error in
                    if error == nil {
                        // Update comment like count
                        ReviewComment.updateLikeCount(logId: logId, commentId: like.commentId, increment: true)
                    }
                    completion?(error)
                }
        } catch {
            completion?(error)
        }
    }
    
    // Remove a like from a comment
    static func removeLike(logId: String, commentId: String, userId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        
        db.collection("logs").document(logId)
            .collection("comments").document(commentId)
            .collection("likes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion?(error)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion?(nil)
                    return
                }
                
                // Delete the like document
                documents.first?.reference.delete { error in
                    if error == nil {
                        // Update comment like count
                        ReviewComment.updateLikeCount(logId: logId, commentId: commentId, increment: false)
                    }
                    completion?(error)
                }
            }
    }
    
    // Check if user has liked a comment
    static func hasUserLiked(logId: String, commentId: String, userId: String, completion: @escaping (Bool, Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("logs").document(logId)
            .collection("comments").document(commentId)
            .collection("likes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                let hasLiked = snapshot?.documents.isEmpty == false
                completion(hasLiked, nil)
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