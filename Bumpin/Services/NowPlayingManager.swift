import Foundation
import MediaPlayer
import SwiftUI

@MainActor
class NowPlayingManager: ObservableObject {
    @Published var currentTrack: MPMediaItem?
    @Published var isPlaying: Bool = false
    @Published var playbackTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isEnabled: Bool = true
    
    private let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    
    init() {
        setupNotifications()
        updateNowPlayingInfo()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
        
        musicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    @objc private func nowPlayingItemChanged() {
        updateNowPlayingInfo()
    }
    
    @objc private func playbackStateChanged() {
        updatePlaybackState()
    }
    
    private func updateNowPlayingInfo() {
        currentTrack = musicPlayer.nowPlayingItem
        duration = currentTrack?.playbackDuration ?? 0
        updatePlaybackState()
    }
    
    private func updatePlaybackState() {
        isPlaying = musicPlayer.playbackState == .playing
        playbackTime = musicPlayer.currentPlaybackTime
    }
    
    func requestMusicAccess() async -> Bool {
        let status = await MPMediaLibrary.requestAuthorization()
        return status == .authorized
    }
}
