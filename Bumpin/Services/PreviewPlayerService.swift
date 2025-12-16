import Foundation
import AVFoundation
import Combine

/// Service for playing 30-second music previews
class PreviewPlayerService: ObservableObject {
    
    static let shared = PreviewPlayerService()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 30.0 // Default to 30 seconds
    @Published var isLoading = false
    @Published var currentPreviewUrl: String?
    
    // For minimized indicator
    @Published var currentSongTitle: String?
    @Published var currentArtistName: String?
    @Published var currentItemId: String?
    @Published var currentArtworkURL: URL?
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endTimeObserver: Any?
    private var audioSession: AVAudioSession?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            audioSession = AVAudioSession.sharedInstance()
            try audioSession?.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession?.setActive(true)
            print("✅ Preview audio session configured")
        } catch {
            print("❌ Failed to configure preview audio session: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Play a preview from a URL
    func playPreview(url: URL, songTitle: String? = nil, artistName: String? = nil, itemId: String? = nil, artworkURL: URL? = nil) {
        print("🎵 playPreview called with URL: \(url)")
        print("🎵 Current state - isPlaying: \(isPlaying), currentUrl: \(currentPreviewUrl ?? "nil")")
        
        // Store song info for minimized indicator
        self.currentSongTitle = songTitle
        self.currentArtistName = artistName
        self.currentItemId = itemId
        self.currentArtworkURL = artworkURL
        
        // If already playing the same URL, just resume
        if currentPreviewUrl == url.absoluteString, player != nil {
            print("🎵 Same URL already loaded, resuming...")
            resumePlayback()
            return
        }
        
        // Stop any existing playback
        print("🎵 Stopping any existing playback...")
        stopPlayback() // Use internal method that doesn't clear song info
        
        // Set URL first (synchronously on main thread to avoid race condition)
        print("🎵 Setting currentPreviewUrl to: \(url.absoluteString)")
        self.currentPreviewUrl = url.absoluteString
        self.isLoading = true
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Wait for player to be ready
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemReady),
            name: .AVPlayerItemNewAccessLogEntry,
            object: playerItem
        )
        
        // Observe when preview ends
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // Start playback - update state synchronously
        print("🎵 Setting isPlaying=true (currentPreviewUrl is already: \(self.currentPreviewUrl ?? "nil"))")
        self.isLoading = false
        self.isPlaying = true
        
        player?.play()
        startTimeObserver()
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resumePlayback()
        }
    }
    
    /// Pause playback
    func pause() {
        print("⏸️ PAUSE called - keeping current position")
        player?.pause()
        print("⏸️ Setting isPlaying = false (currentTime: \(currentTime))")
        self.isPlaying = false
    }
    
    /// Resume playback
    private func resumePlayback() {
        print("▶️ RESUME called - continuing from \(currentTime)")
        player?.play()
        print("▶️ Setting isPlaying = true")
        self.isPlaying = true
    }
    
    /// Stop playback and clean up
    func stop() {
        print("🛑 STOP called - cleaning up player")
        stopPlayback()
        
        // Clear song info
        self.currentSongTitle = nil
        self.currentArtistName = nil
        self.currentItemId = nil
        self.currentArtworkURL = nil
    }
    
    /// Internal stop that doesn't clear song info (for switching tracks)
    private func stopPlayback() {
        player?.pause()
        removeTimeObserver()
        
        print("🛑 Setting isPlaying = false, currentPreviewUrl = nil")
        self.isPlaying = false
        self.currentTime = 0
        self.currentPreviewUrl = nil
        self.isLoading = false
        
        NotificationCenter.default.removeObserver(self)
        player = nil
    }
    
    // MARK: - Time Observer
    
    private func startTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentSeconds = CMTimeGetSeconds(time)
            
            DispatchQueue.main.async {
                self.currentTime = currentSeconds
            }
            
            // Auto-stop at 30 seconds
            if currentSeconds >= 30.0 {
                self.stop()
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func playerItemReady() {
        if let duration = player?.currentItem?.asset.duration {
            let durationSeconds = CMTimeGetSeconds(duration)
            if durationSeconds.isFinite {
                DispatchQueue.main.async {
                    self.duration = min(durationSeconds, 30.0) // Cap at 30 seconds
                }
            }
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        print("🎵 Preview finished playing")
        stop()
    }
    
    deinit {
        stop()
    }
}

