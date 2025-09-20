import SwiftUI
import FirebaseAuth

struct LikedItemsView: View {
    @State private var likedItems: [UserLike] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: UserLike.LikeType = .song
    
    var filteredItems: [UserLike] {
        likedItems.filter { $0.itemType == selectedFilter }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading liked items...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    VStack(spacing: 0) {
                        // Filter Picker
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(UserLike.LikeType.allCases, id: \.self) { type in
                                Text(type.displayName)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        
                        // Liked Items List
                        if filteredItems.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "heart.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("No liked \(selectedFilter.displayName.lowercased()) yet")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Start exploring and liking content to see it here!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(filteredItems) { item in
                                LikedItemRow(item: item)
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                }
            }
            .navigationTitle("Liked Items")
            .onAppear {
                fetchLikedItems()
            }
        }
    }
    
    private func fetchLikedItems() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to view liked items."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        UserLike.getUserLikes(userId: userId) { likes, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    self.likedItems = likes ?? []
                }
            }
        }
    }
}

struct LikedItemRow: View {
    let item: UserLike
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkUrl = item.itemArtworkUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else {
                Image(systemName: iconForType(item.itemType))
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.itemTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                if let artist = item.itemArtist {
                    Text(artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text("Liked \(item.createdAt, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Type indicator
            Text(item.itemType.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
    
    private func iconForType(_ type: UserLike.LikeType) -> String {
        switch type {
        case .song:
            return "music.note"
        case .album:
            return "opticaldisc"
        case .artist:
            return "person.circle"
        case .review:
            return "text.bubble"
        case .list:
            return "list.bullet"
        }
    }
}

// Extension to add display names for like types
extension UserLike.LikeType {
    var displayName: String {
        switch self {
        case .song:
            return "Songs"
        case .album:
            return "Albums"
        case .artist:
            return "Artists"
        case .review:
            return "Reviews"
        case .list:
            return "Lists"
        }
    }
}

struct LikedItemsView_Previews: PreviewProvider {
    static var previews: some View {
        LikedItemsView()
    }
} 