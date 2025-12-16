import Foundation
import MediaPlayer
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Service that syncs the user's current Apple Music playback to Firestore
/// This allows friends to see what you're listening to in real-time
@MainActor
class NowPlayingSyncService: ObservableObject {
    static let shared = NowPlayingSyncService()
    
    @Published var isEnabled: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var currentTrackTitle: String?
    @Published var currentTrackArtist: String?
    
    private let db = Firestore.firestore()
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Sync interval - update Firestore every 30 seconds while playing
    private let syncInterval: TimeInterval = 30.0
    
    // Track the last synced track to avoid redundant updates
    private var lastSyncedTrackId: String?
    private var lastSyncedPlaybackState: MPMusicPlaybackState = .stopped
    
    private init() {
        setupNotifications()
        loadUserPreference()
    }
    
    // Note: deinit is called on the main actor since the class is @MainActor
    // No need to call stopSyncing here - timer will be invalidated automatically
    
    // MARK: - Setup
    
    private func setupNotifications() {
        // Listen for now playing item changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
        
        // Listen for playback state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
        
        musicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    private func loadUserPreference() {
        // Load user's showNowPlaying preference from UserDefaults
        isEnabled = UserDefaults.standard.bool(forKey: "showNowPlaying")
        
        // If enabled, request authorization and start syncing
        if isEnabled {
            Task {
                let authStatus = MPMediaLibrary.authorizationStatus()
                if authStatus == .notDetermined {
                    let newStatus = await MPMediaLibrary.requestAuthorization()
                    print("🎵 [NowPlayingSync] Requested Media Library auth on load: \(newStatus.rawValue)")
                } else if authStatus != .authorized {
                    print("⚠️ [NowPlayingSync] Media Library not authorized (status: \(authStatus.rawValue))")
                }
                startSyncing()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Enable now playing sync and start background updates
    func enableSync() {
        print("🎵 [NowPlayingSync] Enabling sync...")
        isEnabled = true
        UserDefaults.standard.set(true, forKey: "showNowPlaying")
        
        // Request Media Library authorization (required for systemMusicPlayer)
        Task {
            let authStatus = await MPMediaLibrary.requestAuthorization()
            print("🎵 [NowPlayingSync] Media Library authorization: \(authStatus.rawValue)")
            
            if authStatus == .authorized {
                await updateFirestorePreference(enabled: true)
                startSyncing()
            } else {
                print("❌ [NowPlayingSync] Media Library access denied. Cannot sync now playing.")
                // Still enable the preference, but warn user
                await updateFirestorePreference(enabled: true)
                startSyncing() // Try anyway, user might grant access later
            }
        }
    }
    
    /// Disable now playing sync and clear current data
    func disableSync() {
        print("🎵 [NowPlayingSync] Disabling sync...")
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "showNowPlaying")
        
        // Update Firestore user profile and clear now playing data
        Task {
            await updateFirestorePreference(enabled: false)
            await clearNowPlayingData()
        }
        
        stopSyncing()
    }
    
    /// Manually trigger a sync (useful for testing or immediate updates)
    func syncNow() {
        guard isEnabled else {
            print("🎵 [NowPlayingSync] Sync disabled, skipping manual sync")
            return
        }
        
        Task {
            await performSync()
        }
    }
    
    // MARK: - Syncing Logic
    
    private func startSyncing() {
        guard isEnabled else { return }
        
        print("🎵 [NowPlayingSync] Starting sync service...")
        
        // Perform initial sync
        Task {
            await performSync()
        }
        
        // Start timer for periodic syncs
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performSync()
            }
        }
    }
    
    private func stopSyncing() {
        print("🎵 [NowPlayingSync] Stopping sync service...")
        syncTimer?.invalidate()
        syncTimer = nil
        isSyncing = false
    }
    
    private func performSync() async {
        guard isEnabled else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ [NowPlayingSync] No authenticated user")
            return
        }
        
        // Check Media Library authorization
        let authStatus = MPMediaLibrary.authorizationStatus()
        if authStatus != .authorized {
            print("❌ [NowPlayingSync] Media Library not authorized (status: \(authStatus.rawValue)). Cannot read now playing.")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let playbackState = musicPlayer.playbackState
        let nowPlayingItem = musicPlayer.nowPlayingItem
        
        // Enhanced debugging
        print("🎵 [NowPlayingSync] Syncing...")
        print("   Playback State: \(playbackState.description) (\(playbackState.rawValue))")
        print("   Now Playing Item: \(nowPlayingItem?.title ?? "nil")")
        if let item = nowPlayingItem {
            print("   Artist: \(item.artist ?? "nil")")
            print("   Album: \(item.albumTitle ?? "nil")")
            print("   Persistent ID: \(item.persistentID)")
        }
        
        // If not playing or paused for a while, clear now playing data
        if playbackState != .playing || nowPlayingItem == nil {
            // Check if we need to clear (only if data exists)
            if lastSyncedPlaybackState == .playing {
                print("🎵 [NowPlayingSync] Music stopped/paused, clearing now playing data")
                await clearNowPlayingData()
                lastSyncedPlaybackState = playbackState
            }
            return
        }
        
        // Extract track info
        guard let track = nowPlayingItem else { return }
        
        let trackId = track.persistentID.description
        let title = track.title ?? "Unknown Track"
        let artist = track.artist ?? "Unknown Artist"
        let albumArt = track.artwork?.image(at: CGSize(width: 300, height: 300))
        
        // Check if we need to update (avoid redundant writes)
        if trackId == lastSyncedTrackId && playbackState == lastSyncedPlaybackState {
            // Same track still playing, but update timestamp every sync interval
            // This keeps the "last updated" time fresh
        } else {
            print("🎵 [NowPlayingSync] New track detected: \(title) by \(artist)")
        }
        
        // Update local state
        currentTrackTitle = title
        currentTrackArtist = artist
        lastSyncedTrackId = trackId
        lastSyncedPlaybackState = playbackState
        
        // Upload album art to Firebase Storage if available (optional)
        var albumArtUrl: String? = nil
        if let artImage = albumArt {
            albumArtUrl = await uploadAlbumArt(artImage, trackId: trackId)
        }
        
        // Update Firestore
        do {
            try await db.collection("users").document(userId).updateData([
                "nowPlayingSong": title,
                "nowPlayingArtist": artist,
                "nowPlayingAlbumArt": albumArtUrl as Any,
                "nowPlayingUpdatedAt": FieldValue.serverTimestamp(),
                "showNowPlaying": true
            ])
            
            lastSyncDate = Date()
            print("✅ [NowPlayingSync] Synced: \(title) by \(artist)")
            
        } catch {
            print("❌ [NowPlayingSync] Failed to sync: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Firestore Updates
    
    private func updateFirestorePreference(enabled: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "showNowPlaying": enabled
            ])
            print("✅ [NowPlayingSync] Updated preference: \(enabled)")
        } catch {
            print("❌ [NowPlayingSync] Failed to update preference: \(error.localizedDescription)")
        }
    }
    
    private func clearNowPlayingData() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId).updateData([
                "nowPlayingSong": FieldValue.delete(),
                "nowPlayingArtist": FieldValue.delete(),
                "nowPlayingAlbumArt": FieldValue.delete(),
                "nowPlayingUpdatedAt": FieldValue.delete()
            ])
            
            currentTrackTitle = nil
            currentTrackArtist = nil
            lastSyncedTrackId = nil
            
            print("✅ [NowPlayingSync] Cleared now playing data")
        } catch {
            print("❌ [NowPlayingSync] Failed to clear now playing data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Album Art Upload
    
    private func uploadAlbumArt(_ image: UIImage, trackId: String) async -> String? {
        // Optional: Upload album art to Firebase Storage
        // For now, return nil to keep it simple
        // You can implement this later if you want to cache album artwork
        return nil
    }
    
    // MARK: - Notification Handlers
    
    @objc private func nowPlayingItemChanged() {
        print("🎵 [NowPlayingSync] Now playing item changed")
        Task {
            await performSync()
        }
    }
    
    @objc private func playbackStateChanged() {
        print("🎵 [NowPlayingSync] Playback state changed")
        Task {
            await performSync()
        }
    }
}

// MARK: - Helper Extension

extension MPMusicPlaybackState {
    var description: String {
        switch self {
        case .stopped: return "Stopped"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .interrupted: return "Interrupted"
        case .seekingForward: return "Seeking Forward"
        case .seekingBackward: return "Seeking Backward"
        @unknown default: return "Unknown"
        }
    }
}

