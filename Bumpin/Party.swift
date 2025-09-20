//
//  Party.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Party Connection State
enum PartyConnectionState: String, Codable, CaseIterable {
    case active = "active"           // Fully engaged in party
    case minimized = "minimized"     // Party running in background
    case disconnected = "disconnected" // Left party entirely
}

struct Party: Identifiable, Codable {
    var id: String
    var name: String
    let hostId: String
    let hostName: String
    var createdAt: Date
    var participants: [PartyParticipant]
    var currentSong: Song?
    var isActive: Bool
    // Location properties
    var latitude: Double?
    var longitude: Double?
    var isPublic: Bool
    var maxDistance: Double // Maximum distance in meters for discovery
    
    // Influencer/Celebrity party properties
    var isInfluencerParty: Bool
    var influencerId: String?
    var followerCount: Int?
    var isVerified: Bool
    
    // Friends party properties
    var isFriendsParty: Bool
    var friendsOnly: Bool
    var locationSharingEnabled: Bool
    
    // Queue and shuffle functionality
    var musicQueue: [Song]
    var isShuffled: Bool
    var originalQueue: [Song] // Store original order when shuffled
    
    // Queue history tracking
    var queueHistory: [QueueHistoryItem] // Songs that have been played
    var historyLimit: Int // Maximum number of history items to keep
    
    // Voice chat properties
    var voiceChatEnabled: Bool
    var voiceChatActive: Bool
    var speakers: [String]
    var listeners: [String]
    var maxSpeakers: Int
    // Voice permissions
    var speakingPermissionMode: String // "open" or "approval"
    var friendsAutoSpeaker: Bool
    // Party settings
    var descriptionText: String? = nil
    var admissionMode: String = "open" // "open", "invite", "friends", "followers"
    var whoCanAddSongs: String = "all" // "all", "host"
    var accessCode: String? = nil
    // Co-hosts
    var coHostIds: [String] = []
    // Moderation lists
    var mutedUserIds: [String] = []
    var bannedUserIds: [String] = []
    
    // Party connection state for minimization
    var connectionState: PartyConnectionState = .active
    
    // Trending and social proof properties
    var trendingScore: Double?
    var socialProof: SocialProof?
    var lastActivity: Date?
    
    // Playlist tracking for smart queue regeneration
    var sourcePlaylistId: String? // ID of the playlist the queue came from
    var sourcePlaylistSongs: [Song]? // All songs from the source playlist
    var currentQueueMode: AutoQueueMode // Track current queue mode
    
    init(name: String, hostId: String, hostName: String, latitude: Double? = nil, longitude: Double? = nil, isPublic: Bool = false, maxDistance: Double = 1000, isInfluencerParty: Bool = false, influencerId: String? = nil, followerCount: Int? = nil, isVerified: Bool = false, isFriendsParty: Bool = false, friendsOnly: Bool = false, locationSharingEnabled: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.hostId = hostId
        self.hostName = hostName
        self.createdAt = Date()
        self.participants = [PartyParticipant(id: hostId, name: hostName, isHost: true)]
        self.currentSong = nil
        self.isActive = true
        self.latitude = latitude
        self.longitude = longitude
        self.isPublic = isPublic
        self.maxDistance = maxDistance
        self.isInfluencerParty = isInfluencerParty
        self.influencerId = influencerId
        self.followerCount = followerCount
        self.isVerified = isVerified
        self.isFriendsParty = isFriendsParty
        self.friendsOnly = friendsOnly
        self.locationSharingEnabled = locationSharingEnabled
        
        // Initialize queue properties
        self.musicQueue = []
        self.isShuffled = false
        self.originalQueue = []
        self.queueHistory = []
        self.historyLimit = 100 // Default to 100 history items
        self.voiceChatEnabled = false
        self.voiceChatActive = false
        self.speakers = []
        self.listeners = []
        self.maxSpeakers = 10 // Default max speakers
        self.speakingPermissionMode = "open"
        self.friendsAutoSpeaker = false
        self.sourcePlaylistId = nil
        self.sourcePlaylistSongs = nil
        self.currentQueueMode = .ordered
        self.descriptionText = nil
        self.admissionMode = "open"
        self.whoCanAddSongs = "all"
        self.coHostIds = []
    }
    
    // Helper to get CLLocation
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    // Calculate distance to another location
    func distance(to location: CLLocation) -> CLLocationDistance? {
        guard let partyLocation = self.location else { return nil }
        return partyLocation.distance(from: location)
    }
    
    // Check if party is within discovery range
    func isWithinDiscoveryRange(of location: CLLocation, maxDistance: CLLocationDistance = 402.336) -> Bool {
        guard let distance = distance(to: location) else { return false }
        return distance <= maxDistance // Default 0.25 miles = 402.336 meters
    }
    
    // Get formatted distance string
    func formattedDistance(to location: CLLocation) -> String? {
        guard let distance = distance(to: location) else { return nil }
        
        if distance < 1000 {
            return "\(Int(distance))m away"
        } else {
            return String(format: "%.1f mi away", distance / 1609.34)
        }
    }
    
    // Queue management methods
    mutating func addToQueue(_ song: Song) {
        musicQueue.append(song)
        if !isShuffled {
            originalQueue = musicQueue
        }
    }
    
    mutating func addToQueueTop(_ song: Song) {
        // Add song to the top of the queue (next to play)
        // If queue is empty, just add the song
        if musicQueue.isEmpty {
            musicQueue.append(song)
        } else {
            // Insert at the beginning (index 0) to make it the next song to play
            musicQueue.insert(song, at: 0)
        }
        
        if !isShuffled {
            originalQueue = musicQueue
        }
    }
    
    mutating func removeFromQueue(at index: Int) {
        guard index < musicQueue.count else { return }
        let removedSong = musicQueue[index]
        musicQueue.remove(at: index)
        
        // Also remove from original queue if not shuffled
        if !isShuffled {
            originalQueue = musicQueue
        } else {
            // Remove from original queue as well
            if let originalIndex = originalQueue.firstIndex(where: { $0.id == removedSong.id }) {
                originalQueue.remove(at: originalIndex)
            }
        }
    }
    
    mutating func shuffleQueue() {
        guard !musicQueue.isEmpty else { return }
        
        if !isShuffled {
            // Store original order before shuffling
            originalQueue = musicQueue
        }
        
        // Shuffle the queue
        musicQueue.shuffle()
        isShuffled = true
    }
    
    mutating func unshuffleQueue() {
        guard isShuffled else { return }
        
        // Restore original order
        musicQueue = originalQueue
        isShuffled = false
    }
    
    // Smart queue regeneration methods
    mutating func setQueueMode(_ mode: AutoQueueMode, fromPlaylist playlistId: String? = nil, playlistSongs: [Song]? = nil) {
        currentQueueMode = mode
        
        // Update source playlist info if provided
        if let playlistId = playlistId {
            sourcePlaylistId = playlistId
        }
        if let playlistSongs = playlistSongs {
            sourcePlaylistSongs = playlistSongs
        }
        
        switch mode {
        case .ordered:
            regenerateOrderedQueue()
        case .random:
            regenerateRandomQueue()
        }
    }
    
    private mutating func regenerateOrderedQueue() {
        guard let sourceSongs = sourcePlaylistSongs, !sourceSongs.isEmpty else { return }
        
        // Get the currently playing song if any
        let currentSong = musicQueue.first
        
        // Create ordered queue from source playlist
        var newQueue = sourceSongs
        
        // If there's a current song, put it first and remove it from the rest
        if let currentSong = currentSong {
            newQueue = newQueue.filter { $0.id != currentSong.id }
            newQueue.insert(currentSong, at: 0)
        }
        
        musicQueue = newQueue
        originalQueue = newQueue
        isShuffled = false
    }
    
    private mutating func regenerateRandomQueue() {
        guard let sourceSongs = sourcePlaylistSongs, !sourceSongs.isEmpty else { return }
        
        // Get the currently playing song if any
        let currentSong = musicQueue.first
        
        // Create random queue from source playlist
        var availableSongs = sourceSongs
        
        // If there's a current song, remove it from available songs
        if let currentSong = currentSong {
            availableSongs = availableSongs.filter { $0.id != currentSong.id }
        }
        
        // Shuffle available songs
        availableSongs.shuffle()
        
        // If there's a current song, put it first
        if let currentSong = currentSong {
            availableSongs.insert(currentSong, at: 0)
        }
        
        musicQueue = availableSongs
        originalQueue = sourceSongs // Keep original order for reference
        isShuffled = true
    }
    
    func getNextSong() -> Song? {
        guard !musicQueue.isEmpty else { return nil }
        return musicQueue.first
    }
    
    mutating func playNext() -> Song? {
        guard !musicQueue.isEmpty else { return nil }
        let nextSong = musicQueue.removeFirst()
        
        // Also remove from original queue if shuffled
        if isShuffled, let originalIndex = originalQueue.firstIndex(where: { $0.id == nextSong.id }) {
            originalQueue.remove(at: originalIndex)
        } else if !isShuffled {
            originalQueue = musicQueue
        }
        
        return nextSong
    }
    
    // MARK: - Queue History Management
    
    mutating func addToHistory(_ song: Song, playedBy: String, playedByName: String, playDuration: TimeInterval? = nil, wasSkipped: Bool = false) {
        let historyItem = QueueHistoryItem(
            song: song,
            playedBy: playedBy,
            playedByName: playedByName,
            playDuration: playDuration,
            wasSkipped: wasSkipped
        )
        
        queueHistory.append(historyItem)
        
        // Keep history within limit
        if queueHistory.count > historyLimit {
            queueHistory.removeFirst()
        }
    }
    
    func getHistory() -> [QueueHistoryItem] {
        return queueHistory.reversed() // Most recent first
    }
    
    func getHistoryByUser(_ userId: String) -> [QueueHistoryItem] {
        return queueHistory.filter { $0.playedBy == userId }.reversed()
    }
    
    func getMostPlayedSongs(limit: Int = 10) -> [(Song, Int)] {
        var songCounts: [String: (Song, Int)] = [:]
        
        for item in queueHistory {
            let songId = item.song.id
            if let existing = songCounts[songId] {
                songCounts[songId] = (existing.0, existing.1 + 1)
            } else {
                songCounts[songId] = (item.song, 1)
            }
        }
        
        return songCounts.values
            .sorted { $0.1 > $1.1 } // Sort by count descending
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }
    
    func getMostActiveUsers(limit: Int = 5) -> [(String, Int)] {
        var userCounts: [String: Int] = [:]
        
        for item in queueHistory {
            userCounts[item.playedBy, default: 0] += 1
        }
        
        return userCounts
            .sorted { $0.value > $1.value } // Sort by count descending
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
    
    mutating func clearHistory() {
        queueHistory.removeAll()
    }
}

struct PartyParticipant: Identifiable, Codable {
    let id: String
    let name: String
    var isHost: Bool
    var joinedAt: Date
    
    init(id: String, name: String, isHost: Bool = false) {
        self.id = id
        self.name = name
        self.isHost = isHost
        self.joinedAt = Date()
    }
}

struct Song: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let albumArt: String?
    let duration: TimeInterval
    let appleMusicId: String?
    let isCatalogSong: Bool // true = Apple Music catalog, false = user's library
    
    init(title: String, artist: String, albumArt: String? = nil, duration: TimeInterval, appleMusicId: String? = nil, isCatalogSong: Bool = false) {
        self.id = UUID().uuidString
        self.title = title
        self.artist = artist
        self.albumArt = albumArt
        self.duration = duration
        self.appleMusicId = appleMusicId
        self.isCatalogSong = isCatalogSong
    }
}

struct QueueHistoryItem: Identifiable, Codable {
    let id: String
    let song: Song
    let playedAt: Date
    let playedBy: String // User ID who added the song
    let playedByName: String // Display name of who added the song
    let playDuration: TimeInterval? // How long the song actually played (if skipped early)
    let wasSkipped: Bool // Whether the song was skipped before finishing
    
    init(song: Song, playedBy: String, playedByName: String, playDuration: TimeInterval? = nil, wasSkipped: Bool = false) {
        self.id = UUID().uuidString
        self.song = song
        self.playedAt = Date()
        self.playedBy = playedBy
        self.playedByName = playedByName
        self.playDuration = playDuration
        self.wasSkipped = wasSkipped
    }
}

// MARK: - Voice Chat Models

struct VoiceSpeaker: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let isHost: Bool
    var isSpeaking: Bool
    let joinedAt: Date
    let avatarUrl: String?
    
    init(userId: String, name: String, isHost: Bool = false, avatarUrl: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.name = name
        self.isHost = isHost
        self.isSpeaking = false
        self.joinedAt = Date()
        self.avatarUrl = avatarUrl
    }
}

struct VoiceListener: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let joinedAt: Date
    let avatarUrl: String?
    
    init(userId: String, name: String, avatarUrl: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.name = name
        self.joinedAt = Date()
        self.avatarUrl = avatarUrl
    }
}

// Represents a pending request from a listener to become a speaker in voice chat
struct SpeakerRequest: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let timestamp: Date
    var status: String // "pending", "approved", "declined"
    
    init(id: String = UUID().uuidString, userId: String, userName: String, timestamp: Date = Date(), status: String = "pending") {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.timestamp = timestamp
        self.status = status
    }
}

// MARK: - Social Proof Structure
struct SocialProof: Codable {
    var memberCountProof: String?
    var voiceChatProof: String?
    var influencerProof: String?
    var recentActivityProof: String?
    
    var allProofs: [String] {
        var proofs: [String] = []
        if let memberCountProof = memberCountProof { proofs.append(memberCountProof) }
        if let voiceChatProof = voiceChatProof { proofs.append(voiceChatProof) }
        if let influencerProof = influencerProof { proofs.append(influencerProof) }
        if let recentActivityProof = recentActivityProof { proofs.append(recentActivityProof) }
        return proofs
    }
} 