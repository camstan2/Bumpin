import SwiftUI

// MARK: - Star Rating View (Shared Component)
struct StarRatingView: View {
    let rating: Double
    let size: CGFloat
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                ZStack {
                    // Background (empty star)
                    Image(systemName: "star.fill")
                        .font(.system(size: size))
                        .foregroundColor(Color.gray.opacity(0.3))
                    
                    // Foreground (filled portion)
                    Image(systemName: "star.fill")
                        .font(.system(size: size))
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold color
                        .mask(
                            GeometryReader { geometry in
                                Rectangle()
                                    .frame(width: geometry.size.width * CGFloat(fillPercentage(for: index)))
                            }
                        )
                }
                .frame(width: size, height: size)
            }
        }
    }
    
    private func fillPercentage(for index: Int) -> Double {
        let starValue = Double(index + 1)
        
        if rating >= starValue {
            // Full star
            return 1.0
        } else if rating > Double(index) {
            // Partial star
            return rating - Double(index)
        } else {
            // Empty star
            return 0.0
        }
    }
}

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
                Group {
                    if item.itemType == "artist" {
                        Button(action: onTap) {
                            AsyncImage(url: URL(string: item.artworkUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.wave.2")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: cardWidth, height: cardWidth)
                            .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
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
                    }
                }
                
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
                
                // Rating Display
                if let averageRating = item.averageRating, averageRating > 0 {
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", averageRating))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        StarRatingView(rating: averageRating, size: 8)
                    }
                    .padding(.top, 2)
                } else {
                    Text("Not rated yet")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                Spacer(minLength: 0)
            }
            .frame(height: item.itemType == "artist" ? 60 : 80, alignment: .top)
        }
        .frame(width: cardWidth)
        .onAppear {
            // Debug logging
            print("🎨 [EnhancedTrendingCard] '\(item.title)' (itemId: \(item.itemId))")
            print("   showFriendPictures: \(showFriendPictures)")
            print("   friends count: \(friends.count)")
            if !friends.isEmpty {
                print("   friend names: \(friends.map { $0.displayName }.joined(separator: ", "))")
                print("   friend has image: \(friends.map { $0.profileImageUrl != nil })")
            } else {
                print("   ⚠️ NO FRIENDS - circle will NOT be shown")
            }
        }
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
