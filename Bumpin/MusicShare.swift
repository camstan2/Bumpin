import Foundation
import FirebaseFirestore

// Represents a music share (like a "letter" in the letterbox)
struct MusicShare: Identifiable, Codable {
    var id: String
    let senderId: String
    let senderName: String
    var senderUsername: String
    var senderProfilePictureUrl: String?
    let recipientId: String
    let recipientName: String
    let recipientUsername: String
    let musicItemId: String // Apple Music ID
    let musicItemType: String // "song", "album", "playlist"
    let musicTitle: String
    let musicArtist: String
    let musicArtworkUrl: String?
    let message: String? // Optional personal message
    let createdAt: Date
    var isRead: Bool
    var isLiked: Bool
    var likeCount: Int
    var commentCount: Int
    
    init(senderId: String, senderName: String, senderUsername: String, senderProfilePictureUrl: String?,
         recipientId: String, recipientName: String, recipientUsername: String,
         musicItemId: String, musicItemType: String, musicTitle: String, musicArtist: String,
         musicArtworkUrl: String?, message: String?) {
        self.id = UUID().uuidString
        self.senderId = senderId
        self.senderName = senderName
        self.senderUsername = senderUsername
        self.senderProfilePictureUrl = senderProfilePictureUrl
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.recipientUsername = recipientUsername
        self.musicItemId = musicItemId
        self.musicItemType = musicItemType
        self.musicTitle = musicTitle
        self.musicArtist = musicArtist
        self.musicArtworkUrl = musicArtworkUrl
        self.message = message
        self.createdAt = Date()
        self.isRead = false
        self.isLiked = false
        self.likeCount = 0
        self.commentCount = 0
    }
}

// Comment on a music share
struct MusicShareComment: Identifiable, Codable {
    var id: String
    let shareId: String
    let commenterId: String
    let commenterName: String
    let commenterUsername: String
    let commenterProfilePictureUrl: String?
    let text: String
    let createdAt: Date
    var likeCount: Int
    
    init(shareId: String, commenterId: String, commenterName: String, commenterUsername: String,
         commenterProfilePictureUrl: String?, text: String) {
        self.id = UUID().uuidString
        self.shareId = shareId
        self.commenterId = commenterId
        self.commenterName = commenterName
        self.commenterUsername = commenterUsername
        self.commenterProfilePictureUrl = commenterProfilePictureUrl
        self.text = text
        self.createdAt = Date()
        self.likeCount = 0
    }
}

// Extension for Firestore operations
extension MusicShare {
    static func createShare(_ share: MusicShare, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("music_shares").document(share.id).setData(from: share) { error in
                completion?(error)
            }
        } catch {
            completion?(error)
        }
    }
    
    static func fetchInboxForUser(userId: String, completion: @escaping ([MusicShare]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("music_shares")
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                let shares = snapshot?.documents.compactMap { try? $0.data(as: MusicShare.self) }
                completion(shares, nil)
            }
    }
    
    static func fetchOutboxForUser(userId: String, completion: @escaping ([MusicShare]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("music_shares")
            .whereField("senderId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                let shares = snapshot?.documents.compactMap { try? $0.data(as: MusicShare.self) }
                completion(shares, nil)
            }
    }
    
    static func markAsRead(shareId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("music_shares").document(shareId).updateData([
            "isRead": true
        ]) { error in
            completion?(error)
        }
    }
    
    static func toggleLike(shareId: String, userId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("music_shares").document(shareId).getDocument { snapshot, error in
            guard let document = snapshot, document.exists else {
                completion?(error)
                return
            }
            
            var likes = document.data()?["likes"] as? [String] ?? []
            if likes.contains(userId) {
                likes.removeAll { $0 == userId }
            } else {
                likes.append(userId)
            }
            
            db.collection("music_shares").document(shareId).updateData([
                "likes": likes,
                "likeCount": likes.count
            ]) { error in
                completion?(error)
            }
        }
    }
    
    static func deleteShare(shareId: String, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("music_shares").document(shareId).delete { error in
            completion?(error)
        }
    }
}

extension MusicShareComment {
    static func addComment(_ comment: MusicShareComment, completion: ((Error?) -> Void)? = nil) {
        let db = Firestore.firestore()
        do {
            try db.collection("music_shares").document(comment.shareId)
                .collection("comments").document(comment.id).setData(from: comment) { error in
                    completion?(error)
                }
        } catch {
            completion?(error)
        }
    }
    
    static func fetchCommentsForShare(shareId: String, completion: @escaping ([MusicShareComment]?, Error?) -> Void) {
        let db = Firestore.firestore()
        db.collection("music_shares").document(shareId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                let comments = snapshot?.documents.compactMap { try? $0.data(as: MusicShareComment.self) }
                completion(comments, nil)
            }
    }
} 