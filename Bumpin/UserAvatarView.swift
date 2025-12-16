import SwiftUI

/// Reusable avatar that tries live fetch when no URL was stored on the comment.
struct UserAvatarView: View {
    let userId: String
    let existingUrl: String?
    var size: CGFloat = 36
    var initials: String
    
    @State private var resolvedUrl: String?
    
    init(userId: String, existingUrl: String?, initials: String, size: CGFloat = 36) {
        self.userId = userId
        self.existingUrl = existingUrl
        self.initials = initials
        self.size = size
    }
    
    var body: some View {
        Group {
            if let urlString = existingUrl ?? resolvedUrl, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholderCircle
                }
            } else {
                placeholderCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task {
            await fetchIfNeeded()
        }
    }
    
    private var placeholderCircle: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Text(String(initials.prefix(1)).uppercased())
                    .font(.caption2)
                    .foregroundColor(.white)
            )
    }
    
    private func fetchIfNeeded() async {
        guard existingUrl == nil && resolvedUrl == nil else { return }
        if let profile = await UserProfileCache.shared.getProfile(userId: userId),
           let url = profile.profilePictureUrl {
            await MainActor.run { resolvedUrl = url }
        }
    }
}
