import SwiftUI

struct FriendLogChip: View {
    let log: MusicLog
    let username: String?
    let pfpUrl: String?
    var body: some View {
        VStack(spacing: 4) {
            if let url = pfpUrl, let u = URL(string: url) {
                AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: { Circle().fill(Color.gray.opacity(0.3)) }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 44, height: 44)
            }
            Text(username ?? "@???").font(.caption2).lineLimit(1)
            // stars
            if let rating = log.rating {
                StarRatingDisplayView(rating: rating, starSize: 8, spacing: 1, showNumber: false)
            }
        }
        .frame(width: 60)
    }
}
