import SwiftUI

struct FriendProfilePictures: View {
    let friends: [FriendProfile]
    let maxVisible: Int
    let size: CGFloat
    let overlap: CGFloat
    
    init(friends: [FriendProfile], maxVisible: Int = 5, size: CGFloat = 24, overlap: CGFloat = 8) {
        self.friends = friends
        self.maxVisible = maxVisible
        self.size = size
        self.overlap = overlap
    }
    
    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(friends.prefix(maxVisible).enumerated()), id: \.element.id) { index, friend in
                AsyncImage(url: URL(string: friend.profileImageUrl ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(friend.displayName.prefix(1).uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                )
                .zIndex(Double(maxVisible - index))
            }
            
            if friends.count > maxVisible {
                // Show count of additional friends
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: size, height: size)
                    
                    Text("+\(friends.count - maxVisible)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                )
                .zIndex(0)
            }
        }
    }
}

// FriendProfile is now defined in SharedModels.swift

#Preview {
    VStack(spacing: 20) {
        FriendProfilePictures(
            friends: [
                FriendProfile(id: "1", displayName: "Alice", profileImageUrl: nil, loggedAt: Date()),
                FriendProfile(id: "2", displayName: "Bob", profileImageUrl: nil, loggedAt: Date()),
                FriendProfile(id: "3", displayName: "Charlie", profileImageUrl: nil, loggedAt: Date()),
                FriendProfile(id: "4", displayName: "Diana", profileImageUrl: nil, loggedAt: Date()),
                FriendProfile(id: "5", displayName: "Eve", profileImageUrl: nil, loggedAt: Date()),
                FriendProfile(id: "6", displayName: "Frank", profileImageUrl: nil, loggedAt: Date())
            ],
            maxVisible: 5,
            size: 24,
            overlap: 8
        )
        
        FriendProfilePictures(
            friends: [
                FriendProfile(id: "1", displayName: "Alice", profileImageUrl: nil, loggedAt: Date()),
                FriendProfile(id: "2", displayName: "Bob", profileImageUrl: nil, loggedAt: Date())
            ],
            maxVisible: 5,
            size: 32,
            overlap: 10
        )
    }
    .padding()
}
