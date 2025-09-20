import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class EnhancedSocialFeedViewModel: ObservableObject {
    @Published var trendingSongs: [TrendingItem] = []
    @Published var trendingAlbums: [TrendingItem] = []
    @Published var trendingArtists: [TrendingItem] = []
    @Published var friendsPopularSongs: [TrendingItem] = []
    @Published var friendsPopularAlbums: [TrendingItem] = []
    @Published var friendsPopularArtists: [TrendingItem] = []
    
    // Friend data for popular items
    @Published var friendsData: [String: [FriendProfile]] = [:]
    
    // Loading states
    @Published var isLoadingTrendingSongs = false
    @Published var isLoadingTrendingAlbums = false
    @Published var isLoadingTrendingArtists = false
    @Published var isLoadingFriendsPopular = false
    
    // Pagination
    @Published var trendingDisplayCountSongs = 10
    @Published var trendingDisplayCountAlbums = 10
    @Published var trendingDisplayCountArtists = 10
    
    // Services
    private let friendsPopularService = FriendsPopularService()
    
    init() {
        loadInitialData()
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() {
        loadTrendingSongs()
        loadTrendingAlbums()
        loadTrendingArtists()
        loadFriendsPopularData()
    }
    
    func loadTrendingSongs() {
        isLoadingTrendingSongs = true
        
        // Simulate API call - replace with your actual trending songs API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.trendingSongs = [
                TrendingItem(id: "song1", title: "City Tapes", subtitle: "Kai Nova", artworkUrl: nil, logCount: 15, itemType: "song", itemId: "song1"),
                TrendingItem(id: "song2", title: "Dusk Sessions", subtitle: "Lumen", artworkUrl: nil, logCount: 12, itemType: "song", itemId: "song2"),
                TrendingItem(id: "song3", title: "Starlight", subtitle: "Cinder", artworkUrl: nil, logCount: 10, itemType: "song", itemId: "song3"),
                TrendingItem(id: "song4", title: "Bl", subtitle: "Artist", artworkUrl: nil, logCount: 8, itemType: "song", itemId: "song4")
            ]
            self.isLoadingTrendingSongs = false
        }
    }
    
    func loadTrendingAlbums() {
        isLoadingTrendingAlbums = true
        
        // Simulate API call - replace with your actual trending albums API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.trendingAlbums = [
                TrendingItem(id: "album1", title: "City Tapes", subtitle: "Kai Nova", artworkUrl: nil, logCount: 8, itemType: "album", itemId: "album1"),
                TrendingItem(id: "album2", title: "Dusk Sessions", subtitle: "Lumen", artworkUrl: nil, logCount: 6, itemType: "album", itemId: "album2"),
                TrendingItem(id: "album3", title: "Starlight", subtitle: "Cinder", artworkUrl: nil, logCount: 5, itemType: "album", itemId: "album3")
            ]
            self.isLoadingTrendingAlbums = false
        }
    }
    
    func loadTrendingArtists() {
        isLoadingTrendingArtists = true
        
        // Simulate API call - replace with your actual trending artists API
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.trendingArtists = [
                TrendingItem(id: "artist1", title: "Kai Nova", subtitle: "Electronic", artworkUrl: nil, logCount: 20, itemType: "artist", itemId: "artist1"),
                TrendingItem(id: "artist2", title: "Lumen", subtitle: "Ambient", artworkUrl: nil, logCount: 18, itemType: "artist", itemId: "artist2"),
                TrendingItem(id: "artist3", title: "Cinder", subtitle: "Indie", artworkUrl: nil, logCount: 15, itemType: "artist", itemId: "artist3")
            ]
            self.isLoadingTrendingArtists = false
        }
    }
    
    func loadFriendsPopularData() {
        isLoadingFriendsPopular = true
        
        // Simulate API call - replace with your actual friends popular API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.friendsPopularSongs = [
                TrendingItem(id: "friendsong1", title: "Midnight Drive", subtitle: "Astra", artworkUrl: nil, logCount: 12, itemType: "song", itemId: "friendsong1"),
                TrendingItem(id: "friendsong2", title: "Neon Lights", subtitle: "Echo Wave", artworkUrl: nil, logCount: 10, itemType: "song", itemId: "friendsong2"),
                TrendingItem(id: "friendsong3", title: "Golden Hour", subtitle: "Sundial", artworkUrl: nil, logCount: 8, itemType: "song", itemId: "friendsong3")
            ]
            
            self.friendsPopularAlbums = [
                TrendingItem(id: "friendalbum1", title: "Midnight Drive", subtitle: "Astra", artworkUrl: nil, logCount: 5, itemType: "album", itemId: "friendalbum1"),
                TrendingItem(id: "friendalbum2", title: "Neon Lights", subtitle: "Echo Wave", artworkUrl: nil, logCount: 4, itemType: "album", itemId: "friendalbum2"),
                TrendingItem(id: "friendalbum3", title: "Golden Hour", subtitle: "Sundial", artworkUrl: nil, logCount: 3, itemType: "album", itemId: "friendalbum3")
            ]
            
            self.friendsPopularArtists = [
                TrendingItem(id: "friendartist1", title: "Astra", subtitle: "Electronic", artworkUrl: nil, logCount: 15, itemType: "artist", itemId: "friendartist1"),
                TrendingItem(id: "friendartist2", title: "Echo Wave", subtitle: "Synthwave", artworkUrl: nil, logCount: 12, itemType: "artist", itemId: "friendartist2"),
                TrendingItem(id: "friendartist3", title: "Sundial", subtitle: "Indie", artworkUrl: nil, logCount: 10, itemType: "artist", itemId: "friendartist3")
            ]
            
            // Load friend data for these items
            self.loadFriendsDataForItems()
            
            self.isLoadingFriendsPopular = false
        }
    }
    
    // MARK: - Friends Data Management
    
    func loadFriendsDataForItems() {
        // Combine all friends popular items
        let allItems = friendsPopularSongs + friendsPopularAlbums + friendsPopularArtists
        
        // Create items array for the service
        let items = allItems.map { (id: $0.id, type: $0.itemType) }
        
        // Fetch friend data for all items
        friendsPopularService.fetchFriendsForItems(items: items) { [weak self] results in
            DispatchQueue.main.async {
                self?.friendsData = results
            }
        }
    }
    
    func loadFriendsDataForItem(_ item: TrendingItem) {
        friendsPopularService.fetchFriendsForItem(itemId: item.id, itemType: item.itemType) { [weak self] friends in
            DispatchQueue.main.async {
                if let friends = friends {
                    self?.friendsData[item.id] = friends
                }
            }
        }
    }
    
    // MARK: - Pagination
    
    func increaseTrendingVisible(type: TrendingItem.ItemType) {
        switch type {
        case .song:
            trendingDisplayCountSongs += 5
        case .album:
            trendingDisplayCountAlbums += 5
        case .artist:
            trendingDisplayCountArtists += 5
        }
    }
    
    // MARK: - Navigation
    
    func showAllTrendingSongs() {
        // Navigate to all trending songs view
        print("Show all trending songs")
    }
    
    func showAllTrendingAlbums() {
        // Navigate to all trending albums view
        print("Show all trending albums")
    }
    
    func showAllTrendingArtists() {
        // Navigate to all trending artists view
        print("Show all trending artists")
    }
    
    func showAllFriendsPopular() {
        // Navigate to all friends popular view
        print("Show all friends popular")
    }
    
    // MARK: - Refresh
    
    func refreshAllData() {
        loadInitialData()
    }
}

#Preview {
    VStack {
        Text("Enhanced Social Feed View Model")
            .font(.headline)
        Text("Manages trending data and friend profiles")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
