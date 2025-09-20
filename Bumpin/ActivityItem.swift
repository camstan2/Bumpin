import Foundation

enum ActivityType: String, Codable {
    case review, comment, pin
}

struct ActivityItem: Identifiable, Codable {
    var id: String
    var type: ActivityType
    var timestamp: Date
    var songId: String?
    var songTitle: String?
    var artistName: String?
    var artworkUrl: String?
    var reviewText: String?
    var rating: Int?
    var commentText: String?
    var pinType: String? // "song", "artist", "album"
    var targetId: String?
    var targetType: String?
} 