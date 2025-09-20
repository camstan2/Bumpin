import SwiftUI

struct ActivityCardView: View {
    let activity: ActivityItem
    
    var iconName: String {
        switch activity.type {
        case .review: return "star.fill"
        case .comment: return "text.bubble.fill"
        case .pin:
            switch activity.pinType {
            case "artist": return "person.fill"
            case "album": return "square.stack.3d.up"
            default: return "music.note"
            }
        }
    }
    
    var iconColor: Color {
        switch activity.type {
        case .review: return .yellow
        case .comment: return .blue
        case .pin: return .purple
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            EnhancedArtworkView(
                artworkUrl: activity.artworkUrl,
                itemType: activity.pinType ?? (activity.type == .review ? "song" : "song"),
                size: 48
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .foregroundColor(iconColor)
                        .font(.system(size: 16, weight: .bold))
                    Text(activityLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(activity.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let title = activity.songTitle {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                if let artist = activity.artistName, !artist.isEmpty {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                if let review = activity.reviewText, activity.type == .review {
                    Text(review)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if let rating = activity.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                        }
                    }
                }
                if let comment = activity.commentText, activity.type == .comment {
                    Text(comment)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                if activity.type == .pin, let pinType = activity.pinType {
                    Text("Pinned \(pinType.capitalized)")
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.purple.opacity(0.1))
                        )
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
    
    private var activityLabel: String {
        switch activity.type {
        case .review: return "Review"
        case .comment: return "Comment"
        case .pin: return "Pin"
        }
    }
} 