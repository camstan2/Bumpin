import SwiftUI

struct EnhancedTrendingSectionView: View {
    let title: String
    let items: [TrendingItem]
    let itemType: TrendingItem.ItemType
    let isLoading: Bool
    let showFriendPictures: Bool
    let friendsData: [String: [FriendProfile]]
    let onSeeAll: () -> Void
    let onNearEnd: (() -> Void)?
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    init(
        title: String,
        items: [TrendingItem],
        itemType: TrendingItem.ItemType,
        isLoading: Bool = false,
        showFriendPictures: Bool = false,
        friendsData: [String: [FriendProfile]] = [:],
        onSeeAll: @escaping () -> Void,
        onNearEnd: (() -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.itemType = itemType
        self.isLoading = isLoading
        self.showFriendPictures = showFriendPictures
        self.friendsData = friendsData
        self.onSeeAll = onSeeAll
        self.onNearEnd = onNearEnd
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: onSeeAll) {
                    HStack(spacing: 4) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
            
            // Content
            if isLoading {
                // Loading state
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<5, id: \.self) { _ in
                            TrendingCardSkeleton()
                        }
                    }
                    .padding(.horizontal)
                }
            } else if items.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("No \(title.lowercased()) yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Items
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            EnhancedTrendingCard(
                                item: item,
                                friends: friendsData[item.id] ?? [],
                                showFriendPictures: showFriendPictures,
                                cardWidth: 140,
                                onTap: { handleItemTap(item) },
                                onTapArtist: { handleArtistTap(item) }
                            )
                            .onAppear {
                                // Trigger near end callback for pagination
                                if let onNearEnd = onNearEnd,
                                   index >= items.count - 3 {
                                    onNearEnd()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func handleItemTap(_ item: TrendingItem) {
        // Navigate to music profile (song or album)
        navigationCoordinator.navigateToMusicProfile(item)
    }
    
    private func handleArtistTap(_ item: TrendingItem) {
        // Navigate to artist profile
        let artistName = item.subtitle ?? item.title
        navigationCoordinator.navigateToArtistProfile(artistName)
    }
}

// Loading skeleton for trending cards
struct TrendingCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 140, height: 140)
                .shimmer()
            
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 16)
                .shimmer()
            
            // Artist skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 12)
                .shimmer()
        }
        .frame(width: 140)
    }
}

// Shimmer extension defined in Shimmer.swift

#Preview {
    VStack(spacing: 20) {
        EnhancedTrendingSectionView(
            title: "Popular with Friends",
            items: [
                TrendingItem(id: "1", title: "Midnight Drive", subtitle: "Astra", artworkUrl: nil, logCount: 8, itemType: "album", itemId: "1"),
                TrendingItem(id: "2", title: "Neon Lights", subtitle: "Echo Wave", artworkUrl: nil, logCount: 6, itemType: "album", itemId: "2"),
                TrendingItem(id: "3", title: "Golden Hour", subtitle: "Sundial", artworkUrl: nil, logCount: 5, itemType: "album", itemId: "3")
            ],
            itemType: TrendingItem.ItemType.album,
            showFriendPictures: true,
            friendsData: [
                "1": [
                    FriendProfile(id: "1", displayName: "Alice", profileImageUrl: nil, loggedAt: Date()),
                    FriendProfile(id: "2", displayName: "Bob", profileImageUrl: nil, loggedAt: Date()),
                    FriendProfile(id: "3", displayName: "Charlie", profileImageUrl: nil, loggedAt: Date())
                ],
                "2": [
                    FriendProfile(id: "4", displayName: "Diana", profileImageUrl: nil, loggedAt: Date()),
                    FriendProfile(id: "5", displayName: "Eve", profileImageUrl: nil, loggedAt: Date())
                ]
            ],
            onSeeAll: { print("See All tapped") }
        )
        .environmentObject(NavigationCoordinator())
    }
    .padding()
}
