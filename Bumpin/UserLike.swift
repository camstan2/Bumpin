import Foundation
import FirebaseFirestore

struct UserLike: Identifiable, Codable {
    var id: String
    var userId: String
    var itemId: String // Can be songId, albumId, artistId, logId, or listId
    var itemType: LikeType
    var itemTitle: String // For display purposes
    var itemArtist: String? // For songs/albums
    var itemArtworkUrl: String? // For display
    var createdAt: Date
    
    enum LikeType: String, Codable, CaseIterable {
        case song = "song"
        case album = "album"
        case artist = "artist"
        case review = "review" // For music log reviews
        case list = "list"
    }
    
    init(userId: String, itemId: String, itemType: LikeType, itemTitle: String, itemArtist: String? = nil, itemArtworkUrl: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.itemId = itemId
        self.itemType = itemType
        self.itemTitle = itemTitle
        self.itemArtist = itemArtist
        self.itemArtworkUrl = itemArtworkUrl
        self.createdAt = Date()
    }
}

// MARK: - Firestore Operations
extension UserLike {
    
    // Add a like
    static func addLike(_ like: UserLike, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        do {
            try db.collection("likes").document(like.id).setData(from: like) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    // Remove a like
    static func removeLike(userId: String, itemId: String, itemType: LikeType, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .whereField("itemId", isEqualTo: itemId)
            .whereField("itemType", isEqualTo: itemType.rawValue)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(error)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(nil) // No like found, consider it success
                    return
                }
                
                // Delete the like document
                documents.first?.reference.delete { error in
                    completion(error)
                }
            }
    }
    
    // Check if user has liked an item
    static func hasUserLiked(userId: String, itemId: String, itemType: LikeType, completion: @escaping (Bool, Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .whereField("itemId", isEqualTo: itemId)
            .whereField("itemType", isEqualTo: itemType.rawValue)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                let hasLiked = snapshot?.documents.isEmpty == false
                completion(hasLiked, nil)
            }
    }
    
    // Get all likes for a user
    static func getUserLikes(userId: String, completion: @escaping ([UserLike]?, Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let likes = snapshot?.documents.compactMap { try? $0.data(as: UserLike.self) }
                completion(likes, nil)
            }
    }
    
    // Get likes for a specific item (to show like count)
    static func getItemLikes(itemId: String, itemType: LikeType, completion: @escaping ([UserLike]?, Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("likes")
            .whereField("itemId", isEqualTo: itemId)
            .whereField("itemType", isEqualTo: itemType.rawValue)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let likes = snapshot?.documents.compactMap { try? $0.data(as: UserLike.self) }
                completion(likes, nil)
            }
    }
    
    // Get like count for an item
    static func getItemLikeCount(itemId: String, itemType: LikeType, completion: @escaping (Int, Error?) -> Void) {
        getItemLikes(itemId: itemId, itemType: itemType) { likes, error in
            if let error = error {
                completion(0, error)
                return
            }
            
            completion(likes?.count ?? 0, nil)
        }
    }
    
    // Get likes by type for a user
    static func getUserLikesByType(userId: String, type: LikeType, completion: @escaping ([UserLike]?, Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("likes")
            .whereField("userId", isEqualTo: userId)
            .whereField("itemType", isEqualTo: type.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let likes = snapshot?.documents.compactMap { try? $0.data(as: UserLike.self) }
                completion(likes, nil)
            }
    }
} 