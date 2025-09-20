import Foundation
import FirebaseFirestore
import FirebaseAuth
import MusicKit

// MARK: - Listen Later Service
class ListenLaterService: ObservableObject {
    static let shared = ListenLaterService()
    
    @Published var songItems: [ListenLaterItem] = []
    @Published var albumItems: [ListenLaterItem] = []
    @Published var artistItems: [ListenLaterItem] = []
    
    @Published var isLoadingSongs = false
    @Published var isLoadingAlbums = false
    @Published var isLoadingArtists = false
    
    private var songListener: ListenerRegistration?
    private var albumListener: ListenerRegistration?
    private var artistListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Load All Sections
    func loadAllSections() {
        guard let userId = Auth.auth().currentUser?.uid else { 
            print("❌ No authenticated user for Listen Later")
            return 
        }
        
        print("🎯 Loading Listen Later sections for user: \(userId)")
        setupRealtimeListeners(for: userId)
    }
    
    // MARK: - Manual Refresh
    func refreshAllSections() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("🔄 Manually refreshing Listen Later sections")
        
        // Only restart listeners if they're not already active
        if songListener == nil || albumListener == nil || artistListener == nil {
            print("🔄 Restarting listeners...")
            stopListeners()
            setupRealtimeListeners(for: userId)
        } else {
            print("🔄 Listeners already active, keeping them running")
        }
    }
    
    // MARK: - Force Reload (for debugging)
    func forceReload() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("🔧 Force reloading Listen Later sections")
        
        // Stop existing listeners
        stopListeners()
        
        // Clear current data
        DispatchQueue.main.async {
            self.songItems = []
            self.albumItems = []
            self.artistItems = []
        }
        
        // Restart listeners after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.setupRealtimeListeners(for: userId)
        }
    }
    
    // MARK: - Setup Real-time Listeners
    private func setupRealtimeListeners(for userId: String) {
        let db = Firestore.firestore()
        
        // Stop existing listeners first to avoid duplicates
        stopListeners()
        
        print("🔗 Setting up Listen Later real-time listeners for user: \(userId)")
        
        // Set loading states
        DispatchQueue.main.async {
            self.isLoadingSongs = true
            self.isLoadingAlbums = true
            self.isLoadingArtists = true
        }
        
        // Songs listener - simplified query to avoid index requirement
        songListener = db.collection("listenLater")
            .whereField("userId", isEqualTo: userId)
            .whereField("itemType", isEqualTo: ListenLaterItemType.song.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Listen Later songs listener error: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingSongs = false
                    }
                    return
                }
                
                let items = snapshot?.documents.compactMap { try? $0.data(as: ListenLaterItem.self) } ?? []
                // Sort manually by addedAt since we can't use orderBy without index
                let sortedItems = items.sorted { $0.addedAt > $1.addedAt }
                print("🎵 Listen Later songs updated: \(sortedItems.count) items")
                DispatchQueue.main.async {
                    self.songItems = sortedItems
                    self.isLoadingSongs = false
                }
            }
        
        // Albums listener - simplified query to avoid index requirement
        albumListener = db.collection("listenLater")
            .whereField("userId", isEqualTo: userId)
            .whereField("itemType", isEqualTo: ListenLaterItemType.album.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Listen Later albums listener error: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingAlbums = false
                    }
                    return
                }
                
                let items = snapshot?.documents.compactMap { try? $0.data(as: ListenLaterItem.self) } ?? []
                // Sort manually by addedAt since we can't use orderBy without index
                let sortedItems = items.sorted { $0.addedAt > $1.addedAt }
                print("🎵 Listen Later albums updated: \(sortedItems.count) items")
                DispatchQueue.main.async {
                    self.albumItems = sortedItems
                    self.isLoadingAlbums = false
                }
            }
        
        // Artists listener - simplified query to avoid index requirement  
        artistListener = db.collection("listenLater")
            .whereField("userId", isEqualTo: userId)
            .whereField("itemType", isEqualTo: ListenLaterItemType.artist.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Listen Later artists listener error: \(error)")
                    DispatchQueue.main.async {
                        self.isLoadingArtists = false
                    }
                    return
                }
                
                let items = snapshot?.documents.compactMap { try? $0.data(as: ListenLaterItem.self) } ?? []
                // Sort manually by addedAt since we can't use orderBy without index
                let sortedItems = items.sorted { $0.addedAt > $1.addedAt }
                print("🎵 Listen Later artists updated: \(sortedItems.count) items")
                DispatchQueue.main.async {
                    self.artistItems = sortedItems
                    self.isLoadingArtists = false
                }
            }
    }
    
    // MARK: - Add Item to Listen Later
    func addItem(_ searchResult: MusicSearchResult, type: ListenLaterItemType) async -> Bool {
        print("🎯 ListenLaterService.addItem called")
        print("   Title: \(searchResult.title)")
        print("   Type: \(type.rawValue)")
        print("   ID: \(searchResult.id)")
        
        guard let userId = Auth.auth().currentUser?.uid else { 
            print("❌ No authenticated user")
            return false 
        }
        
        print("👤 User ID: \(userId)")
        
        do {
            // Check if item already exists
            print("🔍 Checking if item already exists...")
            let exists = try await ListenLaterItem.itemExists(
                userId: userId,
                itemId: searchResult.id,
                type: type
            )
            
            if exists {
                print("ℹ️ Item already in Listen Later: \(searchResult.title)")
                return false
            }
            
            print("✅ Item doesn't exist, creating new Listen Later item...")
            
            // Create new Listen Later item
            let item = ListenLaterItem(
                userId: userId,
                itemId: searchResult.id,
                itemType: type,
                title: searchResult.title,
                artistName: searchResult.artistName,
                albumName: type == .album ? searchResult.albumName : (type == .song ? searchResult.albumName : nil),
                artworkUrl: searchResult.artworkURL
            )
            
            print("📝 Created ListenLaterItem:")
            print("   ID: \(item.id)")
            print("   UserID: \(item.userId)")
            print("   ItemID: \(item.itemId)")
            print("   Title: \(item.title)")
            print("   Artist: \(item.artistName)")
            print("   Album: \(item.albumName ?? "nil")")
            print("   Artwork: \(item.artworkUrl ?? "nil")")
            
            // Save to Firestore
            print("💾 Saving to Firestore...")
            try await ListenLaterItem.create(item)
            print("✅ Successfully saved to Firestore!")
            
            // Update average rating asynchronously
            Task {
                await ListenLaterItem.updateAverageRating(itemId: searchResult.id, itemType: type)
            }
            
            print("✅ Added to Listen Later: \(searchResult.title)")
            AnalyticsService.shared.logTap(category: "listen_later_add", id: "\(type.rawValue)_\(searchResult.id)")
            
            // Post notification for immediate UI update
            NotificationCenter.default.post(name: NSNotification.Name("ListenLaterItemAdded"), object: type)
            print("📢 Posted notification for UI update")
            
            return true
            
        } catch {
            print("❌ Failed to add Listen Later item: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Remove Item from Listen Later
    func removeItem(_ item: ListenLaterItem) async -> Bool {
        do {
            try await ListenLaterItem.removeItem(id: item.id)
            print("✅ Removed from Listen Later: \(item.title)")
            AnalyticsService.shared.logTap(category: "listen_later_remove", id: "\(item.itemType.rawValue)_\(item.itemId)")
            return true
        } catch {
            print("❌ Failed to remove Listen Later item: \(error)")
            return false
        }
    }
    
    // MARK: - Clear Section
    func clearSection(_ type: ListenLaterItemType) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        do {
            let items = try await ListenLaterItem.fetchItemsForUser(userId: userId, type: type)
            
            let db = Firestore.firestore()
            let batch = db.batch()
            
            for item in items {
                let docRef = db.collection("listenLater").document(item.id)
                batch.deleteDocument(docRef)
            }
            
            try await batch.commit()
            print("✅ Cleared \(type.displayName) section")
            AnalyticsService.shared.logTap(category: "listen_later_clear", id: type.rawValue)
            return true
            
        } catch {
            print("❌ Failed to clear section: \(error)")
            return false
        }
    }
    
    // MARK: - Get Section Items
    func getItems(for type: ListenLaterItemType) -> [ListenLaterItem] {
        switch type {
        case .song: return songItems
        case .album: return albumItems
        case .artist: return artistItems
        }
    }
    
    // MARK: - Get Section Loading State
    func isLoading(for type: ListenLaterItemType) -> Bool {
        switch type {
        case .song: return isLoadingSongs
        case .album: return isLoadingAlbums
        case .artist: return isLoadingArtists
        }
    }
    
    // MARK: - Cleanup
    func stopListeners() {
        songListener?.remove()
        albumListener?.remove()
        artistListener?.remove()
        songListener = nil
        albumListener = nil
        artistListener = nil
    }
    
    deinit {
        stopListeners()
    }
}

// MARK: - Listen Later Helper Extensions
extension MusicSearchResult {
    // Convert to ListenLaterSearchResult with rating data
    func toListenLaterSearchResult() -> ListenLaterSearchResult {
        let itemType: ListenLaterItemType
        switch self.itemType.lowercased() {
        case "album": itemType = .album
        case "artist": itemType = .artist
        default: itemType = .song
        }
        
        return ListenLaterSearchResult(
            id: self.id,
            title: self.title,
            artistName: self.artistName,
            albumName: self.albumName.isEmpty ? nil : self.albumName,
            artworkUrl: self.artworkURL,
            itemType: itemType,
            averageRating: nil, // Will be calculated
            totalRatings: 0
        )
    }
}
