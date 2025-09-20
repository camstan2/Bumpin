import SwiftUI
import FirebaseAuth

struct LikeButton: View {
    let itemId: String
    let itemType: UserLike.LikeType
    let itemTitle: String
    let itemArtist: String?
    let itemArtworkUrl: String?
    let showCount: Bool
    
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var isLoading = false
    
    init(itemId: String, itemType: UserLike.LikeType, itemTitle: String, itemArtist: String? = nil, itemArtworkUrl: String? = nil, showCount: Bool = true) {
        self.itemId = itemId
        self.itemType = itemType
        self.itemTitle = itemTitle
        self.itemArtist = itemArtist
        self.itemArtworkUrl = itemArtworkUrl
        self.showCount = showCount
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: toggleLike) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .gray)
                        .font(.system(size: 16))
                    
                    if showCount && likeCount > 0 {
                        Text("\(likeCount)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1.0)
        }
        .onAppear {
            loadLikeStatus()
        }
    }
    
    private func loadLikeStatus() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Check if user has liked this item
        UserLike.hasUserLiked(userId: userId, itemId: itemId, itemType: itemType) { hasLiked, error in
            DispatchQueue.main.async {
                if error == nil {
                    self.isLiked = hasLiked
                }
            }
        }
        
        // Get like count
        if showCount {
            UserLike.getItemLikeCount(itemId: itemId, itemType: itemType) { count, error in
                DispatchQueue.main.async {
                    if error == nil {
                        self.likeCount = count
                    }
                }
            }
        }
    }
    
    private func toggleLike() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        if isLiked {
            // Remove like
            UserLike.removeLike(userId: userId, itemId: itemId, itemType: itemType) { error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if error == nil {
                        self.isLiked = false
                        if self.showCount {
                            self.likeCount = max(0, self.likeCount - 1)
                        }
                    }
                }
            }
        } else {
            // If offline, enqueue and optimistically update UI
            if !OfflineActionQueue.shared.isOnline {
                OfflineActionQueue.shared.enqueueLike(userId: userId, itemId: itemId, itemTypeRaw: itemType.rawValue)
                self.isLoading = false
                self.isLiked = true
                if self.showCount { self.likeCount += 1 }
                return
            }
            // Add like
            let like = UserLike(
                userId: userId,
                itemId: itemId,
                itemType: itemType,
                itemTitle: itemTitle,
                itemArtist: itemArtist,
                itemArtworkUrl: itemArtworkUrl
            )
            
            UserLike.addLike(like) { error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if error == nil {
                        self.isLiked = true
                        if self.showCount {
                            self.likeCount += 1
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct LikeButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LikeButton(
                itemId: "sample-song-id",
                itemType: .song,
                itemTitle: "Sample Song",
                itemArtist: "Sample Artist",
                itemArtworkUrl: nil,
                showCount: true
            )
            
            LikeButton(
                itemId: "sample-review-id",
                itemType: .review,
                itemTitle: "Sample Review",
                itemArtist: nil,
                itemArtworkUrl: nil,
                showCount: false
            )
        }
        .padding()
    }
} 