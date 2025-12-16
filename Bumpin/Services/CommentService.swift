import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Centralized service for managing comments and replies on music logs
class CommentService {
    static let shared = CommentService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Fetch Comments
    
    /// Fetch all top-level comments for a log, sorted by engagement
    func fetchComments(logId: String, completion: @escaping ([ReviewComment]?, Error?) -> Void) {
        db.collection("logs")
            .document(logId)
            .collection("comments")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                // Filter for top-level comments (those without parentCommentId)
                var comments = snapshot?.documents.compactMap { doc -> ReviewComment? in
                    guard let comment = try? doc.data(as: ReviewComment.self) else { return nil }
                    // Only include comments without a parent (top-level comments)
                    return comment.parentCommentId == nil ? comment : nil
                } ?? []
                
                // Sort by engagement score (likes + replies)
                comments.sort { $0.engagementScore > $1.engagementScore }
                
                completion(comments, nil)
            }
    }
    
    /// Fetch replies for a specific comment
    func fetchReplies(logId: String, commentId: String, completion: @escaping ([ReviewComment]?, Error?) -> Void) {
        db.collection("logs")
            .document(logId)
            .collection("comments")
            .whereField("parentCommentId", isEqualTo: commentId)
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let replies = snapshot?.documents.compactMap { try? $0.data(as: ReviewComment.self) } ?? []
                completion(replies, nil)
            }
    }
    
    // MARK: - Add Comment/Reply
    
    /// Add a new comment or reply
    func addComment(logId: String, text: String, parentCommentId: String? = nil, completion: ((Error?) -> Void)? = nil) {
        guard let currentUser = Auth.auth().currentUser else {
            completion?(NSError(domain: "CommentService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        Task {
            guard let context = await ReviewComment.currentUserContext() else {
                completion?(NSError(domain: "CommentService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to load user context"]))
                return
            }
            
            let comment = ReviewComment(
                logId: logId,
                userId: context.userId,
                username: context.username,
                userProfilePictureUrl: context.profilePictureUrl,
                text: text,
                parentCommentId: parentCommentId
            )
            
            do {
                try self.db.collection("logs")
                    .document(logId)
                    .collection("comments")
                    .document(comment.id)
                    .setData(from: comment)
                
                            self.updateLogCommentCount(logId: logId, increment: true)
                            if let parentId = parentCommentId {
                                self.updateCommentReplyCount(logId: logId, commentId: parentId, increment: true)
                            }
                
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Delete Comment
    
    /// Delete a comment (user's own only)
    func deleteComment(logId: String, commentId: String, completion: ((Error?) -> Void)? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "CommentService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        let commentRef = db.collection("logs")
            .document(logId)
            .collection("comments")
            .document(commentId)
        
        // First, verify user owns this comment
        commentRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                completion?(error)
                return
            }
            
            guard let comment = try? snapshot?.data(as: ReviewComment.self),
                  comment.userId == currentUserId else {
                completion?(NSError(domain: "CommentService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this comment"]))
                return
            }
            
            // Delete the comment
            commentRef.delete { error in
                if error == nil {
                    // Update log comment count
                    self.updateLogCommentCount(logId: logId, increment: false)
                    
                    // If this was a reply, update parent's reply count
                    if let parentId = comment.parentCommentId {
                        self.updateCommentReplyCount(logId: logId, commentId: parentId, increment: false)
                    }
                    
                    // TODO: Also delete all replies to this comment if it was a parent
                }
                completion?(error)
            }
        }
    }
    
    // MARK: - Like/Unlike Comment
    
    /// Toggle like on a comment
    func toggleCommentLike(logId: String, commentId: String, completion: ((Bool, Error?) -> Void)? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion?(false, NSError(domain: "CommentService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        // Check if user has already liked
        hasUserLikedComment(logId: logId, commentId: commentId, userId: currentUserId) { [weak self] hasLiked, error in
            guard let self = self else { return }
            
            if let error = error {
                completion?(false, error)
                return
            }
            
            if hasLiked {
                // Unlike
                self.removeLike(logId: logId, commentId: commentId, userId: currentUserId) { error in
                    completion?(false, error)
                }
            } else {
                // Like
                self.addLike(logId: logId, commentId: commentId, userId: currentUserId) { error in
                    completion?(true, error)
                }
            }
        }
    }
    
    /// Check if user has liked a comment
    func hasUserLikedComment(logId: String, commentId: String, userId: String, completion: @escaping (Bool, Error?) -> Void) {
        // Check directly using userId as document ID (more efficient)
        db.collection("logs")
            .document(logId)
            .collection("comments")
            .document(commentId)
            .collection("likes")
            .document(userId)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                let hasLiked = snapshot?.exists == true
                completion(hasLiked, nil)
            }
    }
    
    // MARK: - Private Helper Methods
    
    private func addLike(logId: String, commentId: String, userId: String, completion: ((Error?) -> Void)?) {
        let like = CommentLike(commentId: commentId, userId: userId)
        
        do {
            // Use userId as document ID to match Firestore rules and prevent duplicate likes
            try db.collection("logs")
                .document(logId)
                .collection("comments")
                .document(commentId)
                .collection("likes")
                .document(userId)
                .setData(from: like) { [weak self] error in
                    if error == nil {
                        // Update comment like count
                        self?.updateCommentLikeCount(logId: logId, commentId: commentId, increment: true)
                    } else {
                        print("❌ Error liking comment: \(error!)")
                    }
                    completion?(error)
                }
        } catch {
            print("❌ Error encoding like: \(error)")
            completion?(error)
        }
    }
    
    private func removeLike(logId: String, commentId: String, userId: String, completion: ((Error?) -> Void)?) {
        // Use userId as document ID to match Firestore rules
        db.collection("logs")
            .document(logId)
            .collection("comments")
            .document(commentId)
            .collection("likes")
            .document(userId)
            .delete { [weak self] error in
                    if error == nil {
                        // Update comment like count
                        self?.updateCommentLikeCount(logId: logId, commentId: commentId, increment: false)
                } else {
                    print("❌ Error removing like: \(error!)")
                }
                completion?(error)
            }
    }
    
    private func updateCommentLikeCount(logId: String, commentId: String, increment: Bool) {
        let commentRef = db.collection("logs")
            .document(logId)
            .collection("comments")
            .document(commentId)
        
        commentRef.getDocument { document, error in
            guard let document = document, document.exists else { return }
            
            let currentCount = document.data()?["likeCount"] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            
            commentRef.updateData(["likeCount": newCount]) { error in
                if let error = error {
                    print("❌ Error updating comment like count: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateCommentReplyCount(logId: String, commentId: String, increment: Bool) {
        let commentRef = db.collection("logs")
            .document(logId)
            .collection("comments")
            .document(commentId)
        
        commentRef.getDocument { document, error in
            guard let document = document, document.exists else { return }
            
            let currentCount = document.data()?["replyCount"] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            
            commentRef.updateData(["replyCount": newCount]) { error in
                if let error = error {
                    print("❌ Error updating comment reply count: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateLogCommentCount(logId: String, increment: Bool) {
        let logRef = db.collection("logs").document(logId)
        
        logRef.getDocument { document, error in
            guard let document = document, document.exists else { return }
            
            let currentCount = document.data()?["commentCount"] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            
            logRef.updateData(["commentCount": newCount]) { error in
                if let error = error {
                    print("❌ Error updating log comment count: \(error.localizedDescription)")
                }
            }
        }
    }
}

