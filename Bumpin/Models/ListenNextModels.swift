import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Listen Later Item Model
struct ListenLaterItem: Identifiable, Codable, Equatable {
    var id: String
    var userId: String
    var itemId: String // Apple Music ID
    var itemType: ListenLaterItemType
    var title: String
    var artistName: String
    var albumName: String? // For songs
    var artworkUrl: String?
    var addedAt: Date
    var averageRating: Double? // Calculated from all user logs
    var totalRatings: Int // Number of users who rated this
    
    init(id: String = UUID().uuidString, userId: String, itemId: String, itemType: ListenLaterItemType, title: String, artistName: String, albumName: String? = nil, artworkUrl: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.itemId = itemId
        self.itemType = itemType
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkUrl = artworkUrl
        self.addedAt = addedAt
        self.averageRating = nil
        self.totalRatings = 0
    }
}

// MARK: - Listen Later Item Type
enum ListenLaterItemType: String, Codable, CaseIterable {
    case song = "song"
    case album = "album"
    case artist = "artist"
    
    var displayName: String {
        switch self {
        case .song: return "Songs"
        case .album: return "Albums"
        case .artist: return "Artists"
        }
    }
    
    var icon: String {
        switch self {
        case .song: return "music.note"
        case .album: return "opticaldisc"
        case .artist: return "person.wave.2"
        }
    }
    
    var color: Color {
        switch self {
        case .song: return .blue
        case .album: return .green
        case .artist: return .orange
        }
    }
}

// MARK: - Listen Later Section Data
struct ListenLaterSection {
    let type: ListenLaterItemType
    var items: [ListenLaterItem]
    var isLoading: Bool = false
    
    var displayTitle: String {
        return type.displayName
    }
    
    var count: Int {
        return items.count
    }
}

// MARK: - Listen Later Search Result (for adding new items)
struct ListenLaterSearchResult: Identifiable {
    let id: String
    let title: String
    let artistName: String
    let albumName: String?
    let artworkUrl: String?
    let itemType: ListenLaterItemType
    let averageRating: Double?
    let totalRatings: Int
    
    // Convert to ListenLaterItem
    func toListenLaterItem(userId: String) -> ListenLaterItem {
        return ListenLaterItem(
            userId: userId,
            itemId: id,
            itemType: itemType,
            title: title,
            artistName: artistName,
            albumName: albumName,
            artworkUrl: artworkUrl
        )
    }
}

// MARK: - Firestore Extensions
extension ListenLaterItem {
    
    // MARK: - Create Listen Later Item
    static func create(_ item: ListenLaterItem) async throws {
        let db = Firestore.firestore()
        print("💾 ListenLaterItem.create called")
        print("   Document ID: \(item.id)")
        print("   Collection: listenLater")
        print("   Data: \(item)")
        
        try await db.collection("listenLater").document(item.id).setData(from: item)
        print("✅ Successfully saved to Firestore collection 'listenLater'")
    }
    
    // MARK: - Fetch Listen Later Items for User
    static func fetchItemsForUser(userId: String, type: ListenLaterItemType? = nil) async throws -> [ListenLaterItem] {
        let db = Firestore.firestore()
        
        var query: Query = db.collection("listenLater")
            .whereField("userId", isEqualTo: userId)
        
        if let type = type {
            query = query.whereField("itemType", isEqualTo: type.rawValue)
        }
        
        query = query.order(by: "addedAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ListenLaterItem.self) }
    }
    
    // MARK: - Remove Listen Later Item
    static func removeItem(id: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("listenLater").document(id).delete()
    }
    
    // MARK: - Check if item exists in Listen Later
    static func itemExists(userId: String, itemId: String, type: ListenLaterItemType) async throws -> Bool {
        let db = Firestore.firestore()
        
        let snapshot = try await db.collection("listenLater")
            .whereField("userId", isEqualTo: userId)
            .whereField("itemId", isEqualTo: itemId)
            .whereField("itemType", isEqualTo: type.rawValue)
            .limit(to: 1)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    // MARK: - Update Average Rating
    static func updateAverageRating(itemId: String, itemType: ListenLaterItemType) async {
        // Calculate average rating from all user logs for this item
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("logs")
                .whereField("itemId", isEqualTo: itemId)
                .whereField("itemType", isEqualTo: itemType.rawValue)
                .getDocuments()
            
            let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            let ratings = logs.compactMap { $0.rating }
            
            guard !ratings.isEmpty else { return }
            
            let averageRating = Double(ratings.reduce(0, +)) / Double(ratings.count)
            let totalRatings = ratings.count
            
            // Update all Listen Later items with this itemId
            let listenLaterSnapshot = try await db.collection("listenLater")
                .whereField("itemId", isEqualTo: itemId)
                .whereField("itemType", isEqualTo: itemType.rawValue)
                .getDocuments()
            
            let batch = db.batch()
            for doc in listenLaterSnapshot.documents {
                batch.updateData([
                    "averageRating": averageRating,
                    "totalRatings": totalRatings
                ], forDocument: doc.reference)
            }
            
            try await batch.commit()
            print("✅ Updated average rating for \(itemType.rawValue): \(averageRating)")
            
        } catch {
            print("❌ Failed to update average rating: \(error)")
        }
    }
}
