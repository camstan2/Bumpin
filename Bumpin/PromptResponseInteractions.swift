import Foundation
import FirebaseFirestore

// MARK: - Prompt Response Interactions

struct PromptResponseLike: Identifiable, Codable {
    let id: String
    let responseId: String
    let promptId: String // For easier querying
    let userId: String
    let username: String // Cache for display
    let createdAt: Date
    
    init(responseId: String, promptId: String, userId: String, username: String) {
        self.id = UUID().uuidString
        self.responseId = responseId
        self.promptId = promptId
        self.userId = userId
        self.username = username
        self.createdAt = Date()
    }
}

struct PromptResponseComment: Identifiable, Codable {
    let id: String
    let responseId: String
    let promptId: String // For easier querying
    let userId: String
    let username: String
    let userProfilePictureUrl: String?
    let text: String
    let createdAt: Date
    var likeCount: Int
    var isReported: Bool
    var isHidden: Bool
    
    // Optional reply functionality
    let replyToCommentId: String? // If this is a reply to another comment
    let replyToUsername: String? // Username being replied to
    
    init(responseId: String, promptId: String, userId: String, username: String, userProfilePictureUrl: String?, text: String, replyToCommentId: String? = nil, replyToUsername: String? = nil) {
        self.id = UUID().uuidString
        self.responseId = responseId
        self.promptId = promptId
        self.userId = userId
        self.username = username
        self.userProfilePictureUrl = userProfilePictureUrl
        self.text = text
        self.createdAt = Date()
        self.likeCount = 0
        self.isReported = false
        self.isHidden = false
        self.replyToCommentId = replyToCommentId
        self.replyToUsername = replyToUsername
    }
}

struct PromptResponseCommentLike: Identifiable, Codable {
    let id: String
    let commentId: String
    let responseId: String
    let userId: String
    let createdAt: Date
    
    init(commentId: String, responseId: String, userId: String) {
        self.id = UUID().uuidString
        self.commentId = commentId
        self.responseId = responseId
        self.userId = userId
        self.createdAt = Date()
    }
}

// MARK: - Firestore Extensions

extension PromptResponseLike {
    
    static func createLike(_ like: PromptResponseLike, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Add the like
        let likeRef = db.collection("promptResponseLikes").document(like.id)
        do {
            try batch.setData(from: like, forDocument: likeRef)
        } catch {
            completion?(error)
            return
        }
        
        // Increment like count on the response
        let responseRef = db.collection("promptResponses").document(like.responseId)
        batch.updateData(["likeCount": FieldValue.increment(Int64(1))], forDocument: responseRef)
        
        batch.commit { error in
            completion?(error)
        }
    }
    
    static func deleteLike(responseId: String, userId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        
        // First find the like
        db.collection("promptResponseLikes")
            .whereField("responseId", isEqualTo: responseId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion?(error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion?(nil) // Like doesn't exist
                    return
                }
                
                let batch = db.batch()
                
                // Delete the like
                batch.deleteDocument(document.reference)
                
                // Decrement like count on the response
                let responseRef = db.collection("promptResponses").document(responseId)
                batch.updateData(["likeCount": FieldValue.increment(Int64(-1))], forDocument: responseRef)
                
                batch.commit { error in
                    completion?(error)
                }
            }
    }
    
    static func checkUserLiked(responseId: String, userId: String, completion: @escaping (Bool, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("promptResponseLikes")
            .whereField("responseId", isEqualTo: responseId)
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                completion(!(snapshot?.documents.isEmpty ?? true), nil)
            }
    }
    
    static func fetchLikesForResponse(responseId: String, limit: Int = 20, completion: @escaping ([PromptResponseLike]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("promptResponseLikes")
            .whereField("responseId", isEqualTo: responseId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let likes = snapshot?.documents.compactMap { document in
                    try? document.data(as: PromptResponseLike.self)
                }
                completion(likes, nil)
            }
    }
}

extension PromptResponseComment {
    
    static func createComment(_ comment: PromptResponseComment, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Add the comment
        let commentRef = db.collection("promptResponseComments").document(comment.id)
        do {
            try batch.setData(from: comment, forDocument: commentRef)
        } catch {
            completion?(error)
            return
        }
        
        // Increment comment count on the response
        let responseRef = db.collection("promptResponses").document(comment.responseId)
        batch.updateData(["commentCount": FieldValue.increment(Int64(1))], forDocument: responseRef)
        
        batch.commit { error in
            completion?(error)
        }
    }
    
    static func fetchCommentsForResponse(responseId: String, limit: Int = 50, completion: @escaping ([PromptResponseComment]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("promptResponseComments")
            .whereField("responseId", isEqualTo: responseId)
            .whereField("isHidden", isEqualTo: false)
            .order(by: "createdAt", descending: false) // Chronological order for comments
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let comments = snapshot?.documents.compactMap { document in
                    try? document.data(as: PromptResponseComment.self)
                }
                completion(comments, nil)
            }
    }
    
    static func deleteComment(commentId: String, responseId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Delete the comment
        let commentRef = db.collection("promptResponseComments").document(commentId)
        batch.deleteDocument(commentRef)
        
        // Decrement comment count on the response
        let responseRef = db.collection("promptResponses").document(responseId)
        batch.updateData(["commentCount": FieldValue.increment(Int64(-1))], forDocument: responseRef)
        
        batch.commit { error in
            completion?(error)
        }
    }
}

extension PromptResponseCommentLike {
    
    static func createCommentLike(_ like: PromptResponseCommentLike, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Add the like
        let likeRef = db.collection("promptResponseCommentLikes").document(like.id)
        do {
            try batch.setData(from: like, forDocument: likeRef)
        } catch {
            completion?(error)
            return
        }
        
        // Increment like count on the comment
        let commentRef = db.collection("promptResponseComments").document(like.commentId)
        batch.updateData(["likeCount": FieldValue.increment(Int64(1))], forDocument: commentRef)
        
        batch.commit { error in
            completion?(error)
        }
    }
    
    static func deleteCommentLike(commentId: String, userId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        
        // First find the like
        db.collection("promptResponseCommentLikes")
            .whereField("commentId", isEqualTo: commentId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion?(error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion?(nil) // Like doesn't exist
                    return
                }
                
                let batch = db.batch()
                
                // Delete the like
                batch.deleteDocument(document.reference)
                
                // Decrement like count on the comment
                let commentRef = db.collection("promptResponseComments").document(commentId)
                batch.updateData(["likeCount": FieldValue.increment(Int64(-1))], forDocument: commentRef)
                
                batch.commit { error in
                    completion?(error)
                }
            }
    }
}

// MARK: - Additional Notification Extensions

extension Notification.Name {
    static let promptResponseLiked = Notification.Name("promptResponseLiked")
    static let promptResponseCommented = Notification.Name("promptResponseCommented")
    static let promptResponseCommentLiked = Notification.Name("promptResponseCommentLiked")
}
