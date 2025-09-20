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
            HStack(spacing: 1) {
                ForEach(1...5, id: \.self) { idx in
                    Image(systemName: idx <= (log.rating ?? 0) ? "star.fill" : "star")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                }
            }
        }
        .frame(width: 60)
    }
}
