import SwiftUI

struct EnhancedTrendingCard: View {
    let item: TrendingItem
    let friends: [FriendProfile]
    let showFriendPictures: Bool
    let cardWidth: CGFloat
    let onTap: () -> Void
    let onTapArtist: (() -> Void)?
    
    init(item: TrendingItem, friends: [FriendProfile] = [], showFriendPictures: Bool = false, cardWidth: CGFloat = 140, onTap: @escaping () -> Void, onTapArtist: (() -> Void)? = nil) {
        self.item = item
        self.friends = friends
        self.showFriendPictures = showFriendPictures
        self.cardWidth = cardWidth
        self.onTap = onTap
        self.onTapArtist = onTapArtist
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Album artwork with friend profile pictures in top right
            ZStack(alignment: .topTrailing) {
                Button(action: onTap) {
                    AsyncImage(url: URL(string: item.artworkUrl ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: cardWidth, height: cardWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Friend profile pictures in top right
                if showFriendPictures && !friends.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            FriendProfilePictures(
                                friends: friends,
                                maxVisible: 3,
                                size: 16,
                                overlap: 4
                            )
                            .padding(.trailing, 6)
                            .padding(.top, 6)
                        }
                        Spacer()
                    }
                } else if showFriendPictures {
                    // Debug: Show a small indicator when showFriendPictures is true but no friends
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.red.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .padding(.trailing, 6)
                                .padding(.top, 6)
                        }
                        Spacer()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Button(action: onTap) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Artist
                if let artist = item.subtitle, !artist.isEmpty {
                    if let onTapArtist = onTapArtist {
                        Button(action: onTapArtist) {
                            Text(artist)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(width: cardWidth)
    }
}

// TrendingItem is now defined in SharedModels.swift

#Preview {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
            EnhancedTrendingCard(
                item: TrendingItem(
                    id: "1",
                    title: "Midnight Drive",
                    subtitle: "Astra",
                    artworkUrl: nil,
                    logCount: 8,
                    itemType: "album",
                    itemId: "1"
                ),
                friends: [
                    FriendProfile(id: "1", displayName: "Alice", profileImageUrl: nil, loggedAt: Date()),
                    FriendProfile(id: "2", displayName: "Bob", profileImageUrl: nil, loggedAt: Date()),
                    FriendProfile(id: "3", displayName: "Charlie", profileImageUrl: nil, loggedAt: Date()),
                    FriendProfile(id: "4", displayName: "Diana", profileImageUrl: nil, loggedAt: Date())
                ],
                showFriendPictures: true,
                cardWidth: 140,
                onTap: { print("Tapped Midnight Drive") },
                onTapArtist: { print("Tapped Astra") }
            )
        }
        .padding(.horizontal)
    }
    .padding(.vertical)
}
