//
//  MusicManager.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import MediaPlayer
import StoreKit
import AVFoundation
import MusicKit
import UIKit



class MusicManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentSong: Song?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var showSongPicker = false
    
    // Queue management
    @Published var currentQueue: [Song] = []
    @Published var isShuffled = false
    @Published var originalQueue: [Song] = []
    
    private let musicPlayer = MPMusicPlayerController.applicationMusicPlayer
    private let appleMusicPlayer = ApplicationMusicPlayer.shared
    private var timer: Timer?
    private var audioSession: AVAudioSession?
    private var isAudioSessionSetup = false
    @Published var isUsingAppleMusic = false
    
    // Timer debugging
    private var timerCounter = 0
    
    // Performance optimizations
    private var songCache: [String: (Song, Bool)] = [:] // Song ID -> (Song, isCatalogSong)
    private var artworkCache: [String: UIImage] = [:]
    private var preloadedSongs: Set<String> = []
    
    init() {
        setupMusicPlayer()
        setupAudioSession() // Set up audio session immediately
    }
    
    func setupAudioSession() {
        guard !isAudioSessionSetup else { return }
        
        do {
            audioSession = AVAudioSession.sharedInstance()
            
            // Configure for background playback with proper options for iOS
            try audioSession?.setCategory(.playback, 
                                         mode: .default, 
                                         options: [.allowBluetooth, .allowAirPlay])
            
            // Activate the session with proper options for background playback
            try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Set up interruption handling
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            
            // Set up route change handling
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAudioRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )
            
            isAudioSessionSetup = true
            print("✅ Audio session configured for background playback")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Only handle important route changes to reduce noise
        switch reason {
        case .oldDeviceUnavailable:
            // Auto-pause when headphones are unplugged
            if isPlaying {
                pause()
            }
            print("🎤 Audio route: Device unavailable - paused playback")
        case .newDeviceAvailable:
            print("🎤 Audio route: New device available")
        default:
            // Don't log other route changes to reduce console spam
            break
        }
    }
    
    // Background task handling removed - using native iOS background audio
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("Audio session interruption began")
            // Optionally pause playback
            if isPlaying {
                pause()
            }
        case .ended:
            print("Audio session interruption ended")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                // Resume playback if it was playing before interruption
                if isPlaying {
                    play()
                }
            }
        @unknown default:
            break
        }
    }
    
    // Background tasks removed - using native iOS background audio
    
    private func setupMusicPlayer() {
        // Set up music player notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
        
        // App lifecycle handling removed - iOS handles background audio natively
        
        musicPlayer.beginGeneratingPlaybackNotifications()
        
        // Enable remote control events for lock screen
        UIApplication.shared.beginReceivingRemoteControlEvents()
        setupRemoteCommandCenter()
        
        // Timer will be started when play() is called
    }
    
    func selectSong() {
        showSongPicker = true
    }
    
    // MARK: - Queue Management
    
    func setQueue(_ songs: [Song]) {
        currentQueue = songs
        originalQueue = songs
        isShuffled = false
        
        // Preload songs for faster playback
        Task {
            await preloadSongs(songs)
        }
    }
    
    func addToQueue(_ song: Song) {
        currentQueue.append(song)
        if !isShuffled {
            originalQueue = currentQueue
        }
    }
    
    func removeFromQueue(at index: Int) {
        guard index < currentQueue.count else { return }
        let removedSong = currentQueue[index]
        currentQueue.remove(at: index)
        
        // Also remove from original queue if shuffled
        if isShuffled, let originalIndex = originalQueue.firstIndex(where: { $0.id == removedSong.id }) {
            originalQueue.remove(at: originalIndex)
        } else if !isShuffled {
            originalQueue = currentQueue
        }
    }
    
    func shuffleQueue() {
        guard !currentQueue.isEmpty else { return }
        
        if !isShuffled {
            // Store original order before shuffling
            originalQueue = currentQueue
        }
        
        // Shuffle the queue
        currentQueue.shuffle()
        isShuffled = true
    }
    
    func unshuffleQueue() {
        guard isShuffled else { return }
        
        // Restore original order
        currentQueue = originalQueue
        isShuffled = false
    }
    
    func getNextSong() -> Song? {
        guard !currentQueue.isEmpty else { return nil }
        return currentQueue.first
    }
    
    func playNextInQueue() -> Song? {
        guard !currentQueue.isEmpty else { return nil }
        let nextSong = currentQueue.removeFirst()
        
        // Also remove from original queue if shuffled
        if isShuffled, let originalIndex = originalQueue.firstIndex(where: { $0.id == nextSong.id }) {
            originalQueue.remove(at: originalIndex)
        } else if !isShuffled {
            originalQueue = currentQueue
        }
        
        return nextSong
    }
    
    func clearQueue() {
        currentQueue.removeAll()
        originalQueue.removeAll()
        isShuffled = false
    }
    
    func playSong(_ song: Song, at time: TimeInterval = 0) {
        isLoading = true
        
        Task {
            do {
                // Check cache first for faster playback
                let songId = "\(song.title)_\(song.artist)"
                if let (cachedSong, isCatalogSong) = songCache[songId] {
                    print("🚀 Using cached song: \(cachedSong.title)")
                    if isCatalogSong {
                        await playCachedCatalogSong(cachedSong, at: time)
                    } else {
                        await playCachedLibrarySong(cachedSong, at: time)
                    }
                    return
                }
                
                // Fallback to original method if not cached
                if song.isCatalogSong {
                    // This is a catalog song - use MusicKit directly
                    await playCatalogSong(song, at: time)
                } else {
                    // This is a library song - use MediaPlayer
                    await playLibrarySong(song, at: time)
                }
            } catch {
                print("Error playing song: \(error)")
                await self.playSongBySearch(song, at: time)
            }
        }
    }
    
    private func playCachedCatalogSong(_ song: Song, at time: TimeInterval) async {
        do {
            guard let appleMusicId = song.appleMusicId else {
                await playSongBySearch(song, at: time)
                return
            }
            
            let appleMusicPlayer = ApplicationMusicPlayer.shared
            
            // Create a MusicItemID from the string
            let songID = MusicItemID(appleMusicId)
            
            // Try to get the song from the catalog (should be fast since we cached it)
            let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: songID)
            let response = try await request.response()
            
            if let catalogSong = response.items.first {
                // Play the catalog song
                appleMusicPlayer.queue = [catalogSong]
                try await appleMusicPlayer.play()
                
                // Seek to the specified time if needed
                if time > 0 {
                    appleMusicPlayer.playbackTime = time
                }
                
                await MainActor.run {
                    self.isUsingAppleMusic = true
                    self.currentSong = song
                    self.duration = catalogSong.duration ?? 0
                    self.isLoading = false
                    self.isPlaying = true
                    self.startProgressTimer() // Start timer when song starts playing
                    
                    // Post notification for history tracking
                    NotificationCenter.default.post(
                        name: .songPlayed,
                        object: nil,
                        userInfo: ["song": song]
                    )
                }
            } else {
                // Fallback to search
                await playSongBySearch(song, at: time)
            }
        } catch {
            print("Error playing cached catalog song: \(error)")
            await playSongBySearch(song, at: time)
        }
    }
    
    private func playCachedLibrarySong(_ song: Song, at time: TimeInterval) async {
        guard let appleMusicId = song.appleMusicId,
              let persistentID = UInt64(appleMusicId) else {
            await playSongBySearch(song, at: time)
            return
        }
        
        let storeID = MPMediaPropertyPredicate(value: persistentID, forProperty: MPMediaItemPropertyPersistentID)
        let query = MPMediaQuery()
        query.addFilterPredicate(storeID)
        
        if let items = query.items, let firstItem = items.first {
            await MainActor.run {
                self.isUsingAppleMusic = false
                self.musicPlayer.setQueue(with: MPMediaItemCollection(items: [firstItem]))
                self.musicPlayer.currentPlaybackTime = time
                self.musicPlayer.play()
                self.currentSong = song
                self.duration = firstItem.playbackDuration
                self.isLoading = false
                self.isPlaying = true
                self.startProgressTimer() // Start timer when song starts playing
                
                // Post notification for history tracking
                NotificationCenter.default.post(
                    name: .songPlayed,
                    object: nil,
                    userInfo: ["song": song]
                )
            }
        } else {
            // Song not found in library, try search fallback
            await playSongBySearch(song, at: time)
        }
    }
    
    private func playCatalogSong(_ song: Song, at time: TimeInterval) async {
        do {
        guard let appleMusicId = song.appleMusicId else {
                await playSongBySearch(song, at: time)
                return
            }
            
            let appleMusicPlayer = ApplicationMusicPlayer.shared
            
            // Create a MusicItemID from the string
            let songID = MusicItemID(appleMusicId)
            
            // Try to get the song from the catalog
            let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: songID)
            let response = try await request.response()
            
                            if let catalogSong = response.items.first {
                    // Play the catalog song
                    appleMusicPlayer.queue = [catalogSong]
                    try await appleMusicPlayer.play()
                    
                    // Seek to the specified time if needed
                    if time > 0 {
                        // Note: MusicKit doesn't support direct seeking to arbitrary times
                        // This would require a different approach or waiting for the song to naturally progress
                        print("Seeking to \(time) seconds - MusicKit has limited seeking capabilities")
                    }
                    
                    await MainActor.run {
                        self.isUsingAppleMusic = true
                        self.currentSong = song
                        self.duration = catalogSong.duration ?? 0
                        self.isLoading = false
                        self.isPlaying = true
                        self.startProgressTimer() // Start timer when song starts playing
                    }
            } else {
                // Fallback to search
                await playSongBySearch(song, at: time)
            }
        } catch {
            print("Error playing catalog song: \(error)")
            await playSongBySearch(song, at: time)
        }
    }
    
    private func playLibrarySong(_ song: Song, at time: TimeInterval) async {
        guard let appleMusicId = song.appleMusicId,
              let persistentID = UInt64(appleMusicId) else {
            await playSongBySearch(song, at: time)
            return
        }
        
        let storeID = MPMediaPropertyPredicate(value: persistentID, forProperty: MPMediaItemPropertyPersistentID)
        let query = MPMediaQuery()
        query.addFilterPredicate(storeID)
        
        if let items = query.items, let firstItem = items.first {
            await MainActor.run {
                self.isUsingAppleMusic = false
                self.musicPlayer.setQueue(with: MPMediaItemCollection(items: [firstItem]))
                self.musicPlayer.currentPlaybackTime = time
                self.musicPlayer.play()
                self.currentSong = song
                self.duration = firstItem.playbackDuration
                self.isLoading = false
                self.isPlaying = true
                self.startProgressTimer() // Start timer when song starts playing
                
                // Post notification for history tracking
                NotificationCenter.default.post(
                    name: .songPlayed,
                    object: nil,
                    userInfo: ["song": song]
                )
            }
        } else {
            // Song not found in library, try search fallback
            await playSongBySearch(song, at: time)
        }
    }
    
    private func playSongBySearch(_ song: Song, at time: TimeInterval) async {
        do {
            // Try searching Apple Music catalog first
            let request = MusicCatalogSearchRequest(term: "\(song.title) \(song.artist)", types: [MusicKit.Song.self])
            let response = try await request.response()
            
            if let catalogSong = response.songs.first {
                let appleMusicPlayer = ApplicationMusicPlayer.shared
                appleMusicPlayer.queue = [catalogSong]
                try await appleMusicPlayer.play()
                
                await MainActor.run {
                    self.isUsingAppleMusic = true
                    self.currentSong = song
                    self.duration = catalogSong.duration ?? 0
                    self.isLoading = false
                    self.isPlaying = true
                    self.startProgressTimer() // Start timer when song starts playing
                    
                    // Post notification for history tracking
                    NotificationCenter.default.post(
                        name: .songPlayed,
                        object: nil,
                        userInfo: ["song": song]
                    )
                }
                return
            }
            
            // Last resort: search local library
        let titlePredicate = MPMediaPropertyPredicate(value: song.title, forProperty: MPMediaItemPropertyTitle, comparisonType: .contains)
        let artistPredicate = MPMediaPropertyPredicate(value: song.artist, forProperty: MPMediaItemPropertyArtist, comparisonType: .contains)
        
        let query = MPMediaQuery()
        query.addFilterPredicate(titlePredicate)
        query.addFilterPredicate(artistPredicate)
        
        if let items = query.items, let firstItem = items.first {
                await MainActor.run {
                    self.isUsingAppleMusic = false
                    self.musicPlayer.setQueue(with: MPMediaItemCollection(items: [firstItem]))
                    self.musicPlayer.currentPlaybackTime = time
                    self.musicPlayer.play()
                self.currentSong = song
                    self.duration = firstItem.playbackDuration
                self.isLoading = false
                self.isPlaying = true
                self.startProgressTimer() // Start timer when song starts playing
                
                // Post notification for history tracking
                NotificationCenter.default.post(
                    name: .songPlayed,
                    object: nil,
                    userInfo: ["song": song]
                )
            }
        } else {
                await MainActor.run {
                    self.isLoading = false
                    print("Could not find song: \(song.title) by \(song.artist)")
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                print("Search failed for song: \(song.title) by \(song.artist) - \(error)")
            }
        }
    }
    
    func play() {
        Task {
            print("🎵 MusicManager.play() called")
            
            // Ensure audio session is active
            do {
                try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("❌ Failed to reactivate audio session: \(error)")
            }
            
            if isUsingAppleMusic {
                // Use MusicKit player
                do {
                    try await appleMusicPlayer.play()
                    await MainActor.run {
                        print("🎵 MusicKit: Setting isPlaying to true")
                        self.isPlaying = true
                        self.startProgressTimer() // Start timer when playing
                        print("🎵 MusicKit: Timer should be started")
                    }
                } catch {
                    print("❌ Error playing with MusicKit: \(error)")
                }
            } else {
                // Use MediaPlayer
                musicPlayer.play()
                await MainActor.run {
                    print("🎵 MediaPlayer: Setting isPlaying to true")
                    self.isPlaying = true
                    self.startProgressTimer() // Start timer when playing
                    print("🎵 MediaPlayer: Timer should be started")
                }
            }
            
            // Update now playing info for background controls
            updateNowPlayingInfo()
        }
    }
    
    func pause() {
        Task {
            print("MusicManager.pause() called")
            if isUsingAppleMusic {
                // Use MusicKit player
                appleMusicPlayer.pause()
                await MainActor.run {
                    print("MusicKit: Setting isPlaying to false")
                    self.isPlaying = false
                    self.stopProgressTimer() // Stop timer when paused
                }
            } else {
                // Use MediaPlayer
                musicPlayer.pause()
                await MainActor.run {
                    print("MediaPlayer: Setting isPlaying to false")
                    self.isPlaying = false
                    self.stopProgressTimer() // Stop timer when paused
                }
            }
        }
    }
    
    func skipToNext() {
        // Check if there's a next song in the queue
        if let nextSong = playNextInQueue() {
            playSong(nextSong)
        } else {
            // Fallback to system skip if no queue
            if isUsingAppleMusic {
                Task {
                    do {
                        try await appleMusicPlayer.skipToNextEntry()
                    } catch {
                        print("Error skipping to next with MusicKit: \(error)")
                    }
                }
            } else {
        musicPlayer.skipToNextItem()
            }
        }
    }
    
    func skipToPrevious() {
        if isUsingAppleMusic {
            Task {
                do {
                    try await appleMusicPlayer.skipToPreviousEntry()
                } catch {
                    print("Error skipping to previous with MusicKit: \(error)")
                }
            }
        } else {
        musicPlayer.skipToPreviousItem()
        }
    }
    
    func seekTo(_ time: TimeInterval) {
        let targetTime = max(0, min(time, duration))
        print("🎯 Seeking to \(targetTime)s")
        
        if isUsingAppleMusic {
            // MusicKit seeking - optimized for speed
            Task {
                do {
                    // Direct seeking for MusicKit
                    appleMusicPlayer.playbackTime = targetTime
                    print("✅ MusicKit seek completed to \(targetTime)s")
                } catch {
                    print("❌ MusicKit seek failed: \(error.localizedDescription)")
                    // Quick fallback without pause/play cycle
                    print("🔄 Using quick fallback seek...")
                    await quickSeekFallback(to: targetTime)
                }
            }
        } else {
            // MediaPlayer seeking - very fast
            print("🎯 MediaPlayer seeking to \(targetTime)s")
            musicPlayer.currentPlaybackTime = targetTime
        }
    }
    
    private func quickSeekFallback(to time: TimeInterval) async {
        // Faster fallback that doesn't pause/play
        do {
            // Try to set playback time again with a small delay
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            appleMusicPlayer.playbackTime = time
            print("✅ Quick fallback seek completed")
        } catch {
            print("❌ Quick fallback also failed: \(error.localizedDescription)")
        }
    }
    
    func syncPlayback(with time: TimeInterval) {
        if isUsingAppleMusic {
            // MusicKit sync is more complex - may need to restart playback
            let difference = time - appleMusicPlayer.playbackTime
            if abs(difference) > 2.0 {
                print("Large sync difference detected: \(difference)s - MusicKit sync limited")
            }
        } else {
        let currentTime = musicPlayer.currentPlaybackTime
        let difference = time - currentTime
        
        // If difference is significant (> 1 second), sync
        if abs(difference) > 1.0 {
            musicPlayer.currentPlaybackTime = time
            }
        }
    }
    
    @objc private func handlePlaybackStateChanged() {
        DispatchQueue.main.async {
            let newPlayingState = self.musicPlayer.playbackState == .playing
            print("🎵 Playback state: \(self.musicPlayer.playbackState.rawValue), isPlaying: \(newPlayingState)")
            self.isPlaying = newPlayingState
            self.updateNowPlayingInfo()
        }
    }
    
    @objc private func handleNowPlayingItemChanged() {
        DispatchQueue.main.async {
            if let nowPlayingItem = self.musicPlayer.nowPlayingItem {
                let song = Song(
                    title: nowPlayingItem.title ?? "Unknown",
                    artist: nowPlayingItem.artist ?? "Unknown",
                    albumArt: nil,
                    duration: nowPlayingItem.playbackDuration,
                    appleMusicId: String(nowPlayingItem.persistentID)
                )
                self.currentSong = song
                self.duration = nowPlayingItem.playbackDuration
                self.updateNowPlayingInfo()
            } else {
                self.currentSong = nil
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Set basic info immediately for faster response
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Load artwork asynchronously (won't block playback)
        Task {
            await loadArtworkAsync(for: song, into: nowPlayingInfo)
        }
    }
    
    private func loadArtworkAsync(for song: Song, into nowPlayingInfo: [String: Any]) async {
        let songId = "\(song.title)_\(song.artist)"
        
        // Check cache first
        if let cachedArtwork = artworkCache[songId] {
            await MainActor.run {
                var updatedInfo = nowPlayingInfo
                let artwork = MPMediaItemArtwork(boundsSize: cachedArtwork.size) { _ in cachedArtwork }
                updatedInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
            }
            return
        }
        
        // Load artwork based on player type
        if isUsingAppleMusic {
            // For MusicKit songs, try to get artwork from URL
            if let albumArtUrl = song.albumArt, let url = URL(string: albumArtUrl) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        // Cache the artwork
                        await MainActor.run {
                            self.artworkCache[songId] = image
                        }
                        
                        await MainActor.run {
                            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                            var updatedInfo = nowPlayingInfo
                            updatedInfo[MPMediaItemPropertyArtwork] = artwork
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                        }
                    }
                } catch {
                    print("Failed to load artwork: \(error)")
                }
            }
        } else {
            // For MediaPlayer songs, use existing artwork
            if let artwork = musicPlayer.nowPlayingItem?.artwork {
                await MainActor.run {
                    var updatedInfo = nowPlayingInfo
                    updatedInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                }
            }
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play Command
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause Command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Next Track Command
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipToNext()
            return .success
        }
        
        // Previous Track Command
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipToPrevious()
            return .success
        }
        
        // Enable/disable commands based on availability
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
    }
    
    // App lifecycle handling removed - iOS handles background audio natively
    
    private func startProgressTimer() {
        print("⏰ Starting progress timer...")
        timer?.invalidate() // Stop any existing timer
        
        // Use a more reliable timer approach
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.timerCounter += 1
                
                // Get current time from the appropriate player
                let oldTime = self.currentTime
                
                if self.isUsingAppleMusic {
                    self.currentTime = self.appleMusicPlayer.playbackTime
                    print("⏰ Apple Music - oldTime: \(oldTime)s, newTime: \(self.currentTime)s, counter: \(self.timerCounter)")
                } else {
                    self.currentTime = self.musicPlayer.currentPlaybackTime
                    print("⏰ MediaPlayer - oldTime: \(oldTime)s, newTime: \(self.currentTime)s, counter: \(self.timerCounter)")
                }
                
                print("⏰ Timer update - currentTime: \(self.currentTime)s, isPlaying: \(self.isPlaying)")
                
                // Force UI update
                self.objectWillChange.send()
                
                // Preload next song when current song is near the end
                if self.isPlaying && self.duration > 0 {
                    let timeRemaining = self.duration - self.currentTime
                    if timeRemaining < 10.0 && timeRemaining > 0 { // 10 seconds before end
                        self.preloadNextSong()
                    }
                }
                
                // Update now playing info for lock screen controls
                if self.isPlaying {
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        // Ensure timer continues in background
        RunLoop.current.add(timer!, forMode: .common)
        print("⏰ Progress timer started successfully")
    }
    
    private func preloadNextSong() {
        guard let currentSong = currentSong,
              let currentIndex = currentQueue.firstIndex(where: { $0.id == currentSong.id }),
              currentIndex + 1 < currentQueue.count else {
            return
        }
        
        let nextSong = currentQueue[currentIndex + 1]
        Task {
            await preloadSong(nextSong)
        }
    }
    
    private func stopProgressTimer() {
        print("⏰ Stopping progress timer...")
        timer?.invalidate()
        timer = nil
        print("⏰ Progress timer stopped")
    }
    
    // MARK: - Performance Optimizations
    
    private func preloadSongs(_ songs: [Song]) async {
        print("🚀 Preloading \(songs.count) songs for faster playback...")
        
        for song in songs.prefix(5) { // Preload next 5 songs
            let songId = "\(song.title)_\(song.artist)"
            
            if !preloadedSongs.contains(songId) {
                await preloadSong(song)
                preloadedSongs.insert(songId)
            }
        }
    }
    
    private func preloadSong(_ song: Song) async {
        let songId = "\(song.title)_\(song.artist)"
        
        // Check if already cached
        if songCache[songId] != nil {
            return
        }
        
        // Try to preload catalog song first (fastest)
        if let appleMusicId = song.appleMusicId {
            do {
                let songID = MusicItemID(appleMusicId)
                let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: songID)
                let response = try await request.response()
                
                if let catalogSong = response.items.first {
                    songCache[songId] = (song, true)
                    print("🚀 Preloaded catalog song: \(song.title)")
                    return
                }
            } catch {
                print("🚀 Preload failed for catalog song: \(song.title)")
            }
        }
        
        // Try to preload library song
        if let appleMusicId = song.appleMusicId,
           let persistentID = UInt64(appleMusicId) {
            let storeID = MPMediaPropertyPredicate(value: persistentID, forProperty: MPMediaItemPropertyPersistentID)
            let query = MPMediaQuery()
            query.addFilterPredicate(storeID)
            
            if let items = query.items, !items.isEmpty {
                songCache[songId] = (song, false)
                print("🚀 Preloaded library song: \(song.title)")
                return
            }
        }
        
        // Cache as searchable (will be searched when played)
        songCache[songId] = (song, false)
        print("🚀 Cached searchable song: \(song.title)")
    }
    
    deinit {
        timer?.invalidate()
        musicPlayer.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }
} 