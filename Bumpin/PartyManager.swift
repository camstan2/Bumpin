//
//  PartyManager.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import AVFoundation
import MediaPlayer

// MARK: - Supporting Types

struct Friend: Identifiable, Equatable {
    let id: String
    let name: String
}

// Helper function for async operations with timeout
func withTimeout<T>(seconds: TimeInterval,
                    operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NSError(domain: "PartyManager", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Operation timed out"])
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

@MainActor
final class PartyManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentParty: Party?
    @Published var isCreatingParty: Bool = false
    @Published var showPartyCreation: Bool = false
    @Published var showPartyView: Bool = false
    @Published var showSongPicker: Bool = false
    @Published var showQueueSongPicker: Bool = false
    @Published var showJoinParty: Bool = false
    @Published var nearbyParties: [Party] = []
    @Published var isDiscoveringParties: Bool = false

    // Party minimization state
    @Published var partyConnectionState: PartyConnectionState = .disconnected
    @Published var isPartyMinimized: Bool = false

    // Chat and participants
    @Published var chatMessages: [PartyMessage] = []
    @Published var newMessageText: String = ""
    @Published var newMessageMentions: [String] = []
    @Published var participants: [PartyParticipant] = []
    @Published var messageReactions: [String: [ReactionSummary]] = [:]

    // Managers
    @Published var musicManager: MusicManager = MusicManager()
    let syncManager: SyncManager = SyncManager()
    let voiceChatManager: VoiceChatManager = VoiceChatManager()

    // Audio session coordination
    private var isAudioSessionActive = false

    // Queue write coalescing
    private var queueSyncWorkItem: DispatchWorkItem?
    private var lastWrittenQueueHash: Int?
    private var lastSourceSongsHash: Int?
    private var lastSourcePlaylistId: String?
    private let queueSyncDelay: TimeInterval = 0.3

    // Debounced party field updates
    private var pendingPartyUpdate: [String: Any] = [:]
    private var partyUpdateWorkItem: DispatchWorkItem?
    private let partyUpdateDebounce: TimeInterval = 0.25
    private var partyUpdateRetryCount: Int = 0

    // Real user data from Firebase Auth
    var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    private var currentUserName: String { Auth.auth().currentUser?.displayName ?? "You" }

    // Real friends - will be loaded from Firestore
    @Published var friends: [Friend] = []
    // Real live parties from friends - loaded from Firestore
    @Published var liveFriendParties: [Party] = []
    
    init() {
        syncManager.musicManager = musicManager
        setupSyncNotifications()
        setupBackgroundAudio()
        loadFriendsParties()
        setupMusicManagerNotifications()
    }
    
    private func setupMusicManagerNotifications() {
        // Listen for songs played through sync
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSongPlayed),
            name: .songPlayed,
            object: nil
        )
    }
    
    @objc private func handleSongPlayed(_ notification: Notification) {
        if let song = notification.userInfo?["song"] as? Song {
            print("📝 Received song played notification: \(song.title)")
            addSongToHistory(song)
        }
    }
    
    // Load real parties from friends
    private func loadFriendsParties() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        // First get user's following list
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let following = data["following"] as? [String],
                  !following.isEmpty else {
                return
            }
            
            // Get active parties from friends (chunk to avoid empty or large 'in' arrays)
            let chunks = following.filter { !$0.isEmpty }.chunked(into: 10)
            if chunks.isEmpty { return }
            var aggregated: [QueryDocumentSnapshot] = []
            let group = DispatchGroup()
            for batch in chunks {
                if batch.isEmpty { continue }
                group.enter()
                db.collection("parties")
                    .whereField("isActive", isEqualTo: true)
                    .whereField("hostId", in: batch)
                    .getDocuments { snapshot, _ in
                        if let docs = snapshot?.documents { aggregated.append(contentsOf: docs) }
                        group.leave()
                    }
            }
            group.notify(queue: .main) {
                self.liveFriendParties = aggregated.compactMap { try? $0.data(as: Party.self) }
            }
        }
    }
    
    private func setupBackgroundAudio() {
        // Audio session setup is handled by MusicManager to avoid conflicts
        print("[PartyManager] Audio session setup deferred to MusicManager")
    }
    
    private func setupSyncNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncPlayback),
            name: .syncPlayback,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQueueUpdate),
            name: .queueUpdated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShuffleStateUpdate),
            name: .shuffleStateUpdated,
            object: nil
        )
        
        // Listen for quick join requests from PartyDiscoveryView
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQuickJoinRequest),
            name: NSNotification.Name("JoinParty"),
            object: nil
        )
    }
    
    @objc private func handleSyncPlayback(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let song = userInfo["song"] as? Song,
              let time = userInfo["time"] as? TimeInterval,
              let isPlaying = userInfo["isPlaying"] as? Bool else {
            return
        }
        
        // Sync the music playback
        musicManager.syncPlayback(with: time)
        
        if isPlaying {
            musicManager.play()
        } else {
            musicManager.pause()
        }
        
        // Update party's current song
        if var party = currentParty {
            party.currentSong = song
            currentParty = party
        }
    }
    
    @objc private func handleQueueUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let queue = userInfo["queue"] as? [Song],
              var party = currentParty else {
            return
        }
        
        // Update party's queue (for non-hosts)
        party.musicQueue = queue
        currentParty = party
    }
    
    @objc private func handleShuffleStateUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isShuffled = userInfo["isShuffled"] as? Bool,
              var party = currentParty else {
            return
        }
        
        // Update party's shuffle state (for non-hosts)
        party.isShuffled = isShuffled
        currentParty = party
    }
    
    @objc private func handleQuickJoinRequest(_ notification: Notification) {
        guard let party = notification.object as? Party else { return }
        print("🎉 Quick joining party: \(party.name)")
        joinParty(party)
    }
    
    private func activateLocalParty(_ party: Party) {
        print("🎵 Activating local party...")
        
        // Activate party immediately on main thread
        var activeParty = party
        activeParty.connectionState = .active
        self.currentParty = activeParty
        self.partyConnectionState = .active
        self.isPartyMinimized = false
        self.showPartyView = true
        
        // Setup audio session after party is activated
        if !isAudioSessionActive {
            Task { @MainActor in
                do {
                    musicManager.setupAudioSession()
                    isAudioSessionActive = true
                    print("🎵 Audio session coordinated")
                } catch {
                    print("❌ Audio session setup failed: \(error)")
                    // Continue anyway - audio might still work
                }
                // Only dismiss creation sheet after everything is ready
                self.showPartyCreation = false
            }
        } else {
            // If audio is already active, dismiss the sheet
            self.showPartyCreation = false
        }
        
        // Setup sync manager
        self.syncManager.currentPartyId = party.id
        self.syncManager.setupPartyListener(partyId: party.id)
        self.syncManager.startHosting()
        
        print("🎵 Party activated successfully")
        
        // Create demo reactions for testing
        self.createDemoPartyReactions()
    }

    func createParty(
        name: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isPublic: Bool = false,
        maxDistance: Double = 1000,
        partyLocationEnabled: Bool = true,
        speakingEnabled: Bool = true,
        admissionMode: String = "open",
        speakingPermissionMode: String = "open",
        friendsAutoSpeaker: Bool = false,
        whoCanAddSongs: String = "all"
    ) {
        Task { @MainActor in
            // Set creating state
        isCreatingParty = true
        print("Creating party: \(name)")
        
        let db = Firestore.firestore()
        var newParty = Party(
            name: name,
            hostId: self.currentUserId,
            hostName: self.currentUserName,
            latitude: latitude,
            longitude: longitude,
            isPublic: isPublic,
            maxDistance: maxDistance,
            locationSharingEnabled: partyLocationEnabled
        )
        // Apply chosen settings locally so UI reflects them immediately
        newParty.voiceChatEnabled = speakingEnabled
        newParty.admissionMode = admissionMode
        newParty.speakingPermissionMode = speakingPermissionMode
        newParty.friendsAutoSpeaker = friendsAutoSpeaker
        newParty.whoCanAddSongs = whoCanAddSongs
        
        print("Party ID: \(newParty.id)")
        
        let participantArray: [[String: Any]] = newParty.participants.map { [
            "id": $0.id,
            "name": $0.name,
            "isHost": $0.isHost,
            // Use concrete timestamp; serverTimestamp is not allowed inside array elements
            "joinedAt": Timestamp(date: Date())
        ] }
        
        let partyData: [String: Any] = [
            "id": newParty.id,
            "name": newParty.name,
            "hostId": newParty.hostId,
            "hostName": newParty.hostName,
            "createdAt": FieldValue.serverTimestamp(),
            "participants": participantArray,
            "currentSong": NSNull(),
            "isActive": newParty.isActive,
            "latitude": latitude ?? NSNull(),
            "longitude": longitude ?? NSNull(),
            "isPublic": isPublic,
            "maxDistance": maxDistance,
            "admissionMode": admissionMode,
            "whoCanAddSongs": whoCanAddSongs,
            "voiceChatEnabled": speakingEnabled,
            "locationSharingEnabled": partyLocationEnabled,
            "speakingPermissionMode": speakingPermissionMode,
            "friendsAutoSpeaker": friendsAutoSpeaker,
            "accessCode": NSNull()
        ]
        
        print("Writing to Firestore...")
        
        do {
            // Create party in Firestore with timeout
            try await withTimeout(seconds: 10.0) {
                try await db.collection("parties").document(newParty.id).setData(partyData)
                print("Party created successfully!")
                
                // Only proceed with activation if still in creating state
                if self.isCreatingParty {
                    self.activateLocalParty(newParty)
                    AnalyticsService.shared.logAdmissionMode(mode: newParty.admissionMode)
                    AnalyticsService.shared.logQueuePermission(mode: newParty.whoCanAddSongs)
                }
            }
        } catch {
                    print("Error creating party: \(error.localizedDescription)")
            
            // Handle specific error cases
            if let nsError = error as NSError? {
                let code = nsError.code
                    // FirestoreErrorCode.permissionDenied = 7; unavailable = 14; deadlineExceeded = 4
                    if code == 7 || code == 14 || code == 4 {
                    // Create party locally if Firestore is unavailable
                    if self.isCreatingParty {
                        self.activateLocalParty(newParty)
                    }
                }
            }
        }
        
        // Always ensure creating state is reset
        self.isCreatingParty = false
    }
    }
    
    func discoverNearbyParties(userLocation: CLLocation) {
        isDiscoveringParties = true
        let db = Firestore.firestore()
        
        // Query for public parties within a reasonable radius (10km)
        let radiusInDegrees = 0.1 // Roughly 10km
        let lat = userLocation.coordinate.latitude
        let lon = userLocation.coordinate.longitude
        
        let minLat = lat - radiusInDegrees
        let maxLat = lat + radiusInDegrees
        let minLon = lon - radiusInDegrees
        let maxLon = lon + radiusInDegrees
        
        db.collection("parties")
            .whereField("isActive", isEqualTo: true)
            .whereField("isPublic", isEqualTo: true)
            .whereField("latitude", isGreaterThan: minLat)
            .whereField("latitude", isLessThan: maxLat)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isDiscoveringParties = false
                    
                    if let error = error {
                        print("Error discovering parties: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("No nearby parties found")
                        return
                    }
                    
                    var discoveredParties: [Party] = []
                    
                    for document in documents {
                        let data = document.data()
                        
                        // Additional longitude filter (Firestore doesn't support multiple range queries)
                        if let longitude = data["longitude"] as? Double,
                           longitude >= minLon && longitude <= maxLon {
                            
                            // Calculate actual distance
                            let partyLocation = CLLocation(latitude: data["latitude"] as? Double ?? 0, longitude: longitude)
                            let distance = userLocation.distance(from: partyLocation)
                            
                            // Check if within party's max distance
                            let maxDistance = data["maxDistance"] as? Double ?? 1000
                            if distance <= maxDistance {
                                var party = Party(
                                    name: data["name"] as? String ?? "",
                                    hostId: data["hostId"] as? String ?? "",
                                    hostName: data["hostName"] as? String ?? "",
                                    latitude: data["latitude"] as? Double,
                                    longitude: longitude,
                                    isPublic: data["isPublic"] as? Bool ?? false,
                                    maxDistance: maxDistance
                                )
                                party.id = document.documentID
                                discoveredParties.append(party)
                            }
                        }
                    }
                    
                    // Sort by distance
                    discoveredParties.sort { party1, party2 in
                        let distance1 = party1.distance(to: userLocation) ?? Double.infinity
                        let distance2 = party2.distance(to: userLocation) ?? Double.infinity
                        return distance1 < distance2
                    }
                    
                    self.nearbyParties = discoveredParties
                    print("Found \(discoveredParties.count) nearby parties")
                }
            }
    }
    
    // MARK: - Party Minimization Functions
    
    /// Minimizes the party - keeps connection but hides UI
    func minimizeParty() {
        guard var party = currentParty, party.connectionState == .active else { return }
        
        print("🔽 Minimizing party: \(party.name)")
        
        // Update party state
        party.connectionState = .minimized
        currentParty = party
        partyConnectionState = .minimized
        isPartyMinimized = true
        
        // Hide party view but keep everything running
        showPartyView = false
        
        // Ensure background audio continues
        ensureBackgroundAudioContinuation()
        
        // Keep music playing and sync active
        // Keep voice chat active if enabled
        // Keep Firestore listeners active
        
        // Persist state to Firestore
        persistPartyConnectionState()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("PartyMinimized"), object: party)
    }
    
    /// Ensures background audio continues when party is minimized
    private func ensureBackgroundAudioContinuation() {
        // The MusicManager already has proper background audio setup
        // Just ensure the audio session remains active
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            print("✅ Background audio session confirmed active for minimized party")
        } catch {
            print("⚠️ Failed to ensure background audio session: \(error.localizedDescription)")
        }
        
        // Update Now Playing info for Control Center
        updateNowPlayingInfo()
    }
    
    /// Updates Now Playing info for Control Center and Lock Screen
    private func updateNowPlayingInfo() {
        guard let party = currentParty, let song = party.currentSong else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = musicManager.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = musicManager.isPlaying ? 1.0 : 0.0
        
        // Add party context
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Bumpin Party: \(party.name)"
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("🎵 Updated Now Playing info for minimized party")
    }
    
    /// Restores the party from minimized state
    func restoreParty() {
        guard var party = currentParty, party.connectionState == .minimized else { return }
        
        print("🔼 Restoring party: \(party.name)")
        
        // Update party state
        party.connectionState = .active
        currentParty = party
        partyConnectionState = .active
        isPartyMinimized = false
        
        // Show party view
        showPartyView = true
        
        // Persist state to Firestore
        persistPartyConnectionState()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("PartyRestored"), object: party)
    }
    
    /// Completely leaves the party
    func leaveParty() {
        guard let party = currentParty else { return }
        
        print("🚪 Leaving party: \(party.name)")
        
        // Stop voice chat
        voiceChatManager.stopVoiceChat()
        
        // Update state
        partyConnectionState = .disconnected
        isPartyMinimized = false
        currentParty = nil
        showPartyView = false
        
        // Disconnect from sync
        syncManager.removePartyListener()
        syncManager.disconnect()
        syncManager.stopSyncStatusTimer()
        musicManager.pause()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("PartyLeft"), object: party)
    }
    
    /// Persists the party connection state to Firestore
    private func persistPartyConnectionState() {
        guard let party = currentParty else { return }
        
        let db = Firestore.firestore()
        db.collection("parties").document(party.id).updateData([
            "connectionState": party.connectionState.rawValue
        ]) { error in
            if let error = error {
                print("Error updating party connection state: \(error.localizedDescription)")
            } else {
                print("✅ Party connection state updated: \(party.connectionState.rawValue)")
            }
        }
    }
    
    func endParty() {
        guard var party = currentParty else { return }
        party.isActive = false
        currentParty = party
        showPartyView = false
        syncManager.removePartyListener()
        syncManager.disconnect()
        syncManager.stopSyncStatusTimer()
        musicManager.pause()
    }

    // MARK: - Roles
    func isHostOrCoHost(_ userId: String) -> Bool {
        guard let party = currentParty else { return false }
        return party.hostId == userId || party.coHostIds.contains(userId)
    }
    
    /// Pure helper to determine if a given user can add songs under current party settings
    func canUserAddSongs(_ userId: String, in party: Party) -> Bool {
        if party.whoCanAddSongs == "host" {
            return party.hostId == userId || party.coHostIds.contains(userId)
        }
        return true
    }
    
    /// Static pure helper mirror for unit testing without instance side effects
    // MARK: - PartyManager Helpers
    static func canUserAddSongs(userId: String, in party: Party) -> Bool {
        if party.whoCanAddSongs == "host" {
            return party.hostId == userId || party.coHostIds.contains(userId)
        }
        return true
    }
    
    func promoteToCoHost(_ userId: String) {
        guard var party = currentParty, party.hostId == currentUserId else { return }
        AnalyticsService.shared.logModeration(action: "promote_cohost", targetUserId: userId, partyId: party.id)
        if !party.coHostIds.contains(userId) { party.coHostIds.append(userId) }
        currentParty = party
        persistRoles()
        NotificationCenter.default.post(name: Notification.Name("ToastMessage"), object: "Promoted to co-host")
    }
    
    func demoteFromCoHost(_ userId: String) {
        guard var party = currentParty, party.hostId == currentUserId else { return }
        AnalyticsService.shared.logModeration(action: "demote_cohost", targetUserId: userId, partyId: party.id)
        party.coHostIds.removeAll { $0 == userId }
        currentParty = party
        persistRoles()
        NotificationCenter.default.post(name: Notification.Name("ToastMessage"), object: "Demoted from co-host")
    }
    
    // Removed duplicate implementation

    // MARK: - Moderation
    func kick(_ userId: String) {
        if let pid = currentParty?.id { AnalyticsService.shared.logModeration(action: "kick", targetUserId: userId, partyId: pid) }
        removeParticipant(participantId: userId)
        NotificationCenter.default.post(name: Notification.Name("ToastMessage"), object: "User kicked")
    }
    
    func ban(_ userId: String) {
        guard var party = currentParty, party.hostId == currentUserId || party.coHostIds.contains(currentUserId) else { return }
        AnalyticsService.shared.logModeration(action: "ban", targetUserId: userId, partyId: party.id)
        if !party.bannedUserIds.contains(userId) { party.bannedUserIds.append(userId) }
        currentParty = party
        schedulePartyUpdate(["bannedUserIds": party.bannedUserIds])
        removeParticipant(participantId: userId)
        NotificationCenter.default.post(name: Notification.Name("ToastMessage"), object: "User banned")
    }
    
    func toggleRoomMute(_ userId: String, mute: Bool) {
        guard var party = currentParty, party.hostId == currentUserId || party.coHostIds.contains(currentUserId) else { return }
        AnalyticsService.shared.logModeration(action: mute ? "mute" : "unmute", targetUserId: userId, partyId: party.id)
        if mute {
            if !party.mutedUserIds.contains(userId) { party.mutedUserIds.append(userId) }
        } else {
            party.mutedUserIds.removeAll { $0 == userId }
        }
        currentParty = party
        schedulePartyUpdate(["mutedUserIds": party.mutedUserIds])
        NotificationCenter.default.post(name: Notification.Name("ToastMessage"), object: mute ? "Muted in room" : "Unmuted in room")
    }

    func muteAllExceptHost() {
        guard var party = currentParty, party.hostId == currentUserId || party.coHostIds.contains(currentUserId) else { return }
        AnalyticsService.shared.logModeration(action: "mute_all_except_host", targetUserId: "-", partyId: party.id)
        let everyone = party.participants.map { $0.id }
        let toMute = everyone.filter { $0 != party.hostId }
        party.mutedUserIds = Array(Set(party.mutedUserIds + toMute))
        currentParty = party
        schedulePartyUpdate(["mutedUserIds": party.mutedUserIds])
    }

    func unmuteAll() {
        guard var party = currentParty, party.hostId == currentUserId || party.coHostIds.contains(currentUserId) else { return }
        AnalyticsService.shared.logModeration(action: "unmute_all", targetUserId: "-", partyId: party.id)
        party.mutedUserIds.removeAll()
        currentParty = party
        schedulePartyUpdate(["mutedUserIds": []])
    }
    
    // MARK: - Helper Methods
    
    private func persistRoles() {
        guard let party = currentParty else { return }
        let db = Firestore.firestore()
        
        db.collection("parties").document(party.id).updateData([
            "coHostIds": party.coHostIds
        ]) { error in
            if let error = error {
                print("❌ Error persisting roles: \(error.localizedDescription)")
            } else {
                print("✅ Roles persisted successfully")
            }
        }
    }
    
    private func schedulePartyUpdate(_ updates: [String: Any]) {
        guard let party = currentParty else { return }
        
        // Cancel any pending update
        partyUpdateWorkItem?.cancel()
        
        // Merge with pending updates
        for (key, value) in updates {
            pendingPartyUpdate[key] = value
        }
        
        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let party = self.currentParty else { return }
            let db = Firestore.firestore()
            
            let updateData = self.pendingPartyUpdate
            self.pendingPartyUpdate.removeAll()
            
            db.collection("parties").document(party.id).updateData(updateData) { error in
                if let error = error {
                    print("❌ Error updating party: \(error.localizedDescription)")
                    // Retry logic
                    if self.partyUpdateRetryCount < 3 {
                        self.partyUpdateRetryCount += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.schedulePartyUpdate(updateData)
                        }
                    } else {
                        self.partyUpdateRetryCount = 0
                    }
                } else {
                    print("✅ Party updated successfully")
                    self.partyUpdateRetryCount = 0
                }
            }
        }
        
        partyUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + partyUpdateDebounce, execute: workItem)
    }
    
    // MARK: - PartyManager Muting Helpers
    static func mutedIdsAfterMuteAllExceptHost(party: Party) -> [String] {
        let everyone = party.participants.map { $0.id }
        let toMute = everyone.filter { $0 != party.hostId }
        return Array(Set(party.mutedUserIds + toMute))
    }
    
    static func mutedIdsAfterUnmuteAll(party: Party) -> [String] { 
        return [] 
    }
    
    /// Filters participants by filter key (all|speaking|muted) and name query
    func filterParticipants(
        participants: [PartyParticipant],
        mutedIds: [String],
        voiceSpeakingIds: [String],
        filter: String,
        query: String
    ) -> [PartyParticipant] {
        let base: [PartyParticipant]
        switch filter {
        case "speaking":
            base = participants.filter { voiceSpeakingIds.contains($0.id) }
        case "muted":
            base = participants.filter { mutedIds.contains($0.id) }
        default:
            base = participants
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter { $0.name.lowercased().contains(trimmed.lowercased()) }
    }

    /// Static mirror removed to avoid redeclaration with instance method

    // MARK: - Debounced party updates
    // Removed duplicate implementation
    
    func getPartyCode() -> String {
        return currentParty?.id.prefix(8).uppercased() ?? ""
    }
    
    func selectSong() {
        showSongPicker = true
    }
    
    func playSong(_ song: Song) {
        musicManager.playSong(song)
        
        // Update party's current song
        if var party = currentParty {
            party.currentSong = song
            currentParty = party
            
            // Add to queue history
            addSongToHistory(song)
        }
        
        // Broadcast to participants
        syncManager.broadcastPlaybackUpdate(
            song: song,
            time: musicManager.currentTime,
            isPlaying: musicManager.isPlaying
        )
    }
    
    func togglePlayback() {
        print("🎵 PartyManager.togglePlayback() called, current isPlaying: \(musicManager.isPlaying)")
        if musicManager.isPlaying {
            print("⏸️ Calling pause()")
            musicManager.pause()
        } else {
            print("▶️ Calling play()")
            musicManager.play()
        }
        
        // Broadcast playback state
        if let song = musicManager.currentSong {
            syncManager.broadcastPlaybackUpdate(
                song: song,
                time: musicManager.currentTime,
                isPlaying: musicManager.isPlaying
            )
        }
    }
    
    func skipToNext() {
        // Check if there's a next song in the party queue
        if let party = currentParty, !party.musicQueue.isEmpty {
            playNextFromQueue()
        } else {
            // Fallback to regular skip
            musicManager.skipToNext()
            
            // Add to history if there's a current song
            if let song = musicManager.currentSong {
                addSongToHistory(song)
                
                // Broadcast
                syncManager.broadcastPlaybackUpdate(
                    song: song,
                    time: musicManager.currentTime,
                    isPlaying: musicManager.isPlaying
                )
            }
        }
    }
    
    func skipToPrevious() {
        musicManager.skipToPrevious()
        
        // Add to history if there's a current song
        if let song = musicManager.currentSong {
            addSongToHistory(song)
            
            // Broadcast
            syncManager.broadcastPlaybackUpdate(
                song: song,
                time: musicManager.currentTime,
                isPlaying: musicManager.isPlaying
            )
        }
    }
    
    // MARK: - Queue Management
    
    private func addSongToHistory(_ song: Song) {
        guard var party = currentParty else { return }
        party.addToHistory(
            song,
            playedBy: currentUserId,
            playedByName: currentUserName
        )
        currentParty = party
        
        // Update Firestore if connected
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("parties").document(party.id).updateData([
                    "queueHistory": party.getHistory().map { item in
                        [
                            "id": item.id,
                            "song": [
                                "id": item.song.id,
                                "title": item.song.title,
                                "artist": item.song.artist,
                                "albumArt": item.song.albumArt as Any,
                                "duration": item.song.duration,
                                "appleMusicId": item.song.appleMusicId as Any,
                                "isCatalogSong": item.song.isCatalogSong
                            ],
                            "playedAt": item.playedAt,
                            "playedBy": item.playedBy,
                            "playedByName": item.playedByName,
                            "playDuration": item.playDuration as Any,
                            "wasSkipped": item.wasSkipped
                        ]
                    }
                ])
            } catch {
                print("❌ Failed to update queue history: \(error)")
            }
        }
    }
    
        func addSongToQueue(_ song: Song, fromPlaylist playlistId: String? = nil, playlistSongs: [Song]? = nil) {
        guard var party = currentParty else { return }
        if party.whoCanAddSongs == "host" && party.hostId != currentUserId {
            NotificationCenter.default.post(name: NSNotification.Name("QueuePermissionDenied"), object: nil)
            return
        }
        
        // Update source playlist info if this is the first song or from a new playlist
        if party.musicQueue.isEmpty || (playlistId != nil && party.sourcePlaylistId != playlistId) {
            party.sourcePlaylistId = playlistId
            party.sourcePlaylistSongs = playlistSongs
        }
        
        party.addToQueue(song)
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)

        // Auto-play first song if nothing is currently playing
        if musicManager.currentSong == nil && !party.musicQueue.isEmpty {
            let firstSong = party.musicQueue.first!
            playSong(firstSong) // This will automatically add to history
            
            // Remove the first song from the queue after it starts playing
            // This prevents it from being played again when skipping
            party.musicQueue.removeFirst()
            currentParty = party
            
            // Update queue in MusicManager
            musicManager.setQueue(party.musicQueue)
        }

        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
        func addMultipleSongsToQueue(_ songs: [Song], fromPlaylist playlistId: String? = nil, playlistSongs: [Song]? = nil) {
        guard var party = currentParty else { return }
        if party.whoCanAddSongs == "host" && party.hostId != currentUserId {
            NotificationCenter.default.post(name: NSNotification.Name("QueuePermissionDenied"), object: nil)
            return
        }
        
        // Update source playlist info if this is the first batch or from a new playlist
        if party.musicQueue.isEmpty || (playlistId != nil && party.sourcePlaylistId != playlistId) {
            party.sourcePlaylistId = playlistId
            party.sourcePlaylistSongs = playlistSongs
        }
        
        for song in songs {
            party.addToQueue(song)
        }
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)

        // Auto-play first song if nothing is currently playing
        if musicManager.currentSong == nil && !party.musicQueue.isEmpty {
            let firstSong = party.musicQueue.first!
            playSong(firstSong) // This will automatically add to history
            
            // Remove the first song from the queue after it starts playing
            // This prevents it from being played again when skipping
            party.musicQueue.removeFirst()
            currentParty = party
            
            // Update queue in MusicManager
            musicManager.setQueue(party.musicQueue)
        }

        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
    // MARK: - Play Next Functions (Add to Top of Queue)
    
    func addSongToQueueTop(_ song: Song, fromPlaylist playlistId: String? = nil, playlistSongs: [Song]? = nil) {
        guard var party = currentParty else { return }
        if party.whoCanAddSongs == "host" && party.hostId != currentUserId {
            NotificationCenter.default.post(name: NSNotification.Name("QueuePermissionDenied"), object: nil)
            return
        }
        
        // Update source playlist info if this is the first song or from a new playlist
        if party.musicQueue.isEmpty || (playlistId != nil && party.sourcePlaylistId != playlistId) {
            party.sourcePlaylistId = playlistId
            party.sourcePlaylistSongs = playlistSongs
        }
        
        // Add song to the top of the queue (after current song if playing)
        party.addToQueueTop(song)
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)

        // Auto-play first song if nothing is currently playing
        if musicManager.currentSong == nil && !party.musicQueue.isEmpty {
            playSong(party.musicQueue.first!)
        }

        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
    func addMultipleSongsToQueueTop(_ songs: [Song], fromPlaylist playlistId: String? = nil, playlistSongs: [Song]? = nil) {
        guard var party = currentParty else { return }
        if party.whoCanAddSongs == "host" && party.hostId != currentUserId {
            NotificationCenter.default.post(name: NSNotification.Name("QueuePermissionDenied"), object: nil)
            return
        }
        
        // Update source playlist info if this is the first batch or from a new playlist
        if party.musicQueue.isEmpty || (playlistId != nil && party.sourcePlaylistId != playlistId) {
            party.sourcePlaylistId = playlistId
            party.sourcePlaylistSongs = playlistSongs
        }
        
        // Add songs to the top of the queue in reverse order to maintain selection order
        for song in songs.reversed() {
            party.addToQueueTop(song)
        }
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)

        // Auto-play first song if nothing is currently playing
        if musicManager.currentSong == nil && !party.musicQueue.isEmpty {
            playSong(party.musicQueue.first!)
        }

        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
    func removeSongFromQueue(at index: Int) {
        guard var party = currentParty else { return }
        
        party.removeFromQueue(at: index)
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)
        
        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
    func reorderQueue(from sourceIndex: Int, to destinationIndex: Int) {
        guard var party = currentParty else { return }
        
        // Ensure indices are valid
        guard sourceIndex < party.musicQueue.count && destinationIndex < party.musicQueue.count else { return }
        
        // Get the song to move
        let songToMove = party.musicQueue[sourceIndex]
        
        // Remove from source position
        party.musicQueue.remove(at: sourceIndex)
        
        // Insert at destination position
        party.musicQueue.insert(songToMove, at: destinationIndex)
        
        // Update original queue if not shuffled
        if !party.isShuffled {
            party.originalQueue = party.musicQueue
        }
        
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)
        
        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
    func clearQueue() {
        guard var party = currentParty else { return }
        
        // Clear the queue
        party.musicQueue.removeAll()
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue([])
        
        // Sync empty queue to Firestore
        syncQueueToFirestore()
        
        print("Queue cleared successfully")
    }
    
    func shuffleQueue() {
        guard var party = currentParty else { return }
        
        party.shuffleQueue()
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)
        musicManager.isShuffled = party.isShuffled
        musicManager.originalQueue = party.originalQueue
        
        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
    func unshuffleQueue() {
        guard var party = currentParty else { return }
        
        party.unshuffleQueue()
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)
        musicManager.isShuffled = party.isShuffled
        musicManager.originalQueue = party.originalQueue
        
        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
    func setQueueMode(_ mode: AutoQueueMode) {
        guard var party = currentParty else { return }
        
        // Use the new smart queue regeneration
        party.setQueueMode(mode)
        currentParty = party
        
        // Update queue in MusicManager
        musicManager.setQueue(party.musicQueue)
        musicManager.isShuffled = party.isShuffled
        musicManager.originalQueue = party.originalQueue
        
        // Sync queue to Firestore
        syncQueueToFirestore()
    }
    
    func playNextFromQueue() {
        guard var party = currentParty else { return }
        
        if let nextSong = party.playNext() {
            currentParty = party
            
            // Update queue in MusicManager
            musicManager.setQueue(party.musicQueue)
            
            // Play the next song
            playSong(nextSong)
            
            // Sync queue to Firestore
            syncQueueToFirestore()
        }
    }
    
    private func syncQueueToFirestore() {
        guard currentParty != nil else { return }

        // Cancel any pending sync to coalesce rapid edits
        queueSyncWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self = self, let party = self.currentParty else { return }
            let db = Firestore.firestore()

            // Prepare payloads
            let queueData = party.musicQueue.map { song in
                [
                    "id": song.id,
                    "title": song.title,
                    "artist": song.artist,
                    "albumArt": song.albumArt as Any,
                    "duration": song.duration,
                    "appleMusicId": song.appleMusicId as Any,
                    "isCatalogSong": song.isCatalogSong
                ] as [String: Any]
            }

            let originalQueueData = party.originalQueue.map { song in
                [
                    "id": song.id,
                    "title": song.title,
                    "artist": song.artist,
                    "albumArt": song.albumArt as Any,
                    "duration": song.duration,
                    "appleMusicId": song.appleMusicId as Any,
                    "isCatalogSong": song.isCatalogSong
                ] as [String: Any]
            }

            // Compute a lightweight hash of what we plan to write (excluding source songs)
            var hasher = Hasher()
            hasher.combine(party.isShuffled)
            hasher.combine(party.currentQueueMode.rawValue)
            hasher.combine(queueData.count)
            for item in queueData {
                hasher.combine(item["id"] as? String)
            }
            hasher.combine(originalQueueData.count)
            for item in originalQueueData {
                hasher.combine(item["id"] as? String)
            }
            let queueHash = hasher.finalize()
            if let last = self.lastWrittenQueueHash, last == queueHash { return }

            // Build update dict; include source playlist fields only if changed
            var update: [String: Any] = [
                "musicQueue": queueData,
                "isShuffled": party.isShuffled,
                "originalQueue": originalQueueData,
                "currentQueueMode": party.currentQueueMode.rawValue
            ]

            if party.sourcePlaylistId != self.lastSourcePlaylistId {
                update["sourcePlaylistId"] = party.sourcePlaylistId as Any
                self.lastSourcePlaylistId = party.sourcePlaylistId
            }

            if let songs = party.sourcePlaylistSongs {
                // Hash source songs to avoid large rewrites
                var sourceHasher = Hasher()
                sourceHasher.combine(songs.count)
                for s in songs { sourceHasher.combine(s.id) }
                let sourceHash = sourceHasher.finalize()
                if sourceHash != self.lastSourceSongsHash {
                    let sourceSongsData = songs.map { song in
                        [
                            "id": song.id,
                            "title": song.title,
                            "artist": song.artist,
                            "albumArt": song.albumArt as Any,
                            "duration": song.duration,
                            "appleMusicId": song.appleMusicId as Any,
                            "isCatalogSong": song.isCatalogSong
                        ] as [String: Any]
                    }
                    update["sourcePlaylistSongs"] = sourceSongsData
                    self.lastSourceSongsHash = sourceHash
                }
            }

            db.collection("parties").document(party.id).updateData(update) { error in
                if let error = error {
                    print("Error syncing queue to Firestore: \(error.localizedDescription)")
                } else {
                    self.lastWrittenQueueHash = queueHash
                    print("Queue synced to Firestore successfully")
                }
            }
        }

        queueSyncWorkItem = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + queueSyncDelay, execute: work)
    }
    
    private func updatePartyInFirestore(_ party: Party) {
        let db = Firestore.firestore()
        
        // Convert queue history to Firestore-compatible format
        let historyData = party.queueHistory.map { item in
            [
                "id": item.id,
                "song": [
                    "id": item.song.id,
                    "title": item.song.title,
                    "artist": item.song.artist,
                    "albumArt": item.song.albumArt as Any,
                    "duration": item.song.duration,
                    "appleMusicId": item.song.appleMusicId as Any,
                    "isCatalogSong": item.song.isCatalogSong
                ],
                "playedAt": item.playedAt,
                "playedBy": item.playedBy,
                "playedByName": item.playedByName,
                "playDuration": (item.playDuration.map { NSNumber(value: $0) } as NSObject?) as Any,
                "wasSkipped": item.wasSkipped
            ]
        }
        
        let partyData: [String: Any] = [
            "currentSong": party.currentSong != nil ? [
                "id": party.currentSong!.id,
                "title": party.currentSong!.title,
                "artist": party.currentSong!.artist,
                "albumArt": party.currentSong!.albumArt ?? NSNull(),
                "duration": party.currentSong!.duration,
                "appleMusicId": party.currentSong!.appleMusicId ?? NSNull(),
                "isCatalogSong": party.currentSong!.isCatalogSong
            ] : NSNull(),
            "queueHistory": historyData
        ]
        
        db.collection("parties").document(party.id).updateData(partyData) { error in
            if let error = error {
                print("Error updating party history: \(error.localizedDescription)")
            } else {
                print("✅ Party history updated successfully")
            }
        }
    }
    
    // MARK: - Join by Code (Deep Link)
    func joinByCode(_ rawCode: String) async {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return }
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("parties")
                .whereField("isActive", isEqualTo: true)
                .whereField("accessCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()
            guard let doc = snap.documents.first, let party = try? doc.data(as: Party.self) else {
                NotificationCenter.default.post(name: NSNotification.Name("JoinCodeNotFound"), object: code)
                return
            }
            // Enforce friends-only admission even for deep links
            if party.admissionMode == "friends" {
                let uid = Auth.auth().currentUser?.uid ?? ""
                if uid.isEmpty { 
                    NotificationCenter.default.post(name: NSNotification.Name("FriendsOnlyDenied"), object: party)
                    return
                }
                let userDoc = try await db.collection("users").document(uid).getDocument()
                let following = (userDoc.data()? ["following"] as? [String]) ?? []
                if !following.contains(party.hostId) {
                    NotificationCenter.default.post(name: NSNotification.Name("FriendsOnlyDenied"), object: party)
                    return
                }
            }
            await MainActor.run {
                self.joinParty(party)
            }
        } catch {
            NotificationCenter.default.post(name: NSNotification.Name("JoinCodeNotFound"), object: code)
        }
    }

    func joinParty(_ party: Party) {
        print("Joining party: \(party.name)")
        
        var joinedParty = party
        joinedParty.connectionState = .active
        
        // Add current user as participant if not already present
        if !joinedParty.participants.contains(where: { $0.id == currentUserId }) {
            joinedParty.participants.append(PartyParticipant(
                id: currentUserId,
                name: currentUserName,
                isHost: joinedParty.hostId == currentUserId
            ))
        }
        
        // Update local state
                        self.currentParty = joinedParty
        self.partyConnectionState = .active
        self.isPartyMinimized = false
        self.showPartyCreation = false
                        self.showPartyView = true
                        
        // Setup sync manager
                        self.syncManager.currentPartyId = party.id
                        self.syncManager.setupPartyListener(partyId: party.id)
        
        // Start music if host
        if joinedParty.hostId == currentUserId {
            self.syncManager.startHosting()
        }
                        
                        // Start voice chat manager
                        self.voiceChatManager.startVoiceChat(partyId: party.id)
                        
                        // Create demo reactions for testing
                        self.createDemoPartyReactions()
                        
                        // Start sync status timer for non-hosts
                        self.syncManager.startSyncStatusTimer(getHostTime: { [weak self] in
                            guard let self = self else { return nil }
                            // Host is always the first participant with isHost == true
                            if self.currentParty?.participants.first(where: { $0.isHost }) != nil,
                               self.currentParty?.currentSong != nil {
                                return self.musicManager.currentTime
                            }
                            return nil
                        })
        
        // Update Firestore
        Task {
            do {
                let db = Firestore.firestore()
                try await db.collection("parties").document(party.id).updateData([
                    "participants": joinedParty.participants.map { [
                        "id": $0.id,
                        "name": $0.name,
                        "isHost": $0.isHost,
                        "joinedAt": Timestamp(date: $0.joinedAt)
                    ] }
                ])
                        
                        // Notify listeners that a party has been joined
                        NotificationCenter.default.post(name: NSNotification.Name("PartyJoined"), object: joinedParty)
            } catch {
                print("❌ Failed to update participants: \(error)")
            }
        }
    }
    
    private func removeParticipant(participantId: String) {
        guard let party = currentParty, let partyId = party.id as String?, party.hostId == currentUserId else { return }
        let db = Firestore.firestore()
        // Remove from Firestore
        db.collection("parties").document(partyId).getDocument { document, error in
            guard let document = document, document.exists, var data = document.data(),
                  var participants = data["participants"] as? [[String: Any]] else { return }
            participants.removeAll { ($0["id"] as? String) == participantId }
            data["participants"] = participants
            db.collection("parties").document(partyId).updateData(["participants": participants])
        }
        // Remove from local state
        if var updatedParty = currentParty {
            updatedParty.participants.removeAll { $0.id == participantId }
            currentParty = updatedParty
        }
    }
    
    // MARK: - Chat Functions
    private var lastPartyChatSentAt: Date = .distantPast
    func sendMessage() {
        guard let partyId = currentParty?.id, !newMessageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Throttle chat sends to at most 5 per second
        let now = Date()
        if now.timeIntervalSince(lastPartyChatSentAt) < 0.2 { return }
        lastPartyChatSentAt = now
        
        let db = Firestore.firestore()
        let user = Auth.auth().currentUser
        let senderId = user?.uid ?? ""
        let senderName = user?.displayName ?? "Unknown"
        
        // Fetch profile picture from Firestore
        db.collection("users").document(senderId).getDocument { [weak self] snapshot, error in
            let profilePictureUrl = snapshot?.data()?["profilePictureUrl"] as? String ?? ""
            
            // Mentions: prefer explicit mentions selected in UI; fallback to naive parse
            var mentioned: [String] = self?.newMessageMentions ?? []
            if mentioned.isEmpty {
                let participantIds = self?.currentParty?.participants.map { $0.id } ?? []
                let lower = self?.newMessageText.lowercased() ?? ""
                for pid in participantIds {
                    if let name = self?.currentParty?.participants.first(where: { $0.id == pid })?.name.lowercased() {
                        if lower.contains("@" + name.replacingOccurrences(of: " ", with: "")) {
                            mentioned.append(pid)
                        }
                    }
                }
            }
            let messageData: [String: Any] = [
                "senderId": senderId,
                "senderName": senderName,
                "text": self?.newMessageText ?? "",
                "timestamp": FieldValue.serverTimestamp(),
                "profilePictureUrl": profilePictureUrl,
                "mentions": mentioned
            ]
            
            db.collection("parties").document(partyId).collection("messages").addDocument(data: messageData) { error in
                if let error = error {
                    print("Error sending message: \(error)")
                } else {
                    DispatchQueue.main.async {
                        self?.newMessageText = ""
                        self?.newMessageMentions = []
                    }
                }
            }
        }
    }
    
    // MARK: - Party Chat Reaction Functions
    
    func createDemoPartyReactions() {
        // Add demo reactions for party chat testing
        let demoReactions: [String: [String]] = [
            "party_msg_1": ["👍", "🎵", "🔥"],
            "party_msg_2": ["❤️", "🎶"],
            "party_msg_3": ["🎸", "🎧", "⭐️"]
        ]
        
        let currentUserId = Auth.auth().currentUser?.uid ?? "demo_current_user"
        
        for (messageId, emojis) in demoReactions {
            var reactions: [MessageReaction] = []
            
            for (index, emoji) in emojis.enumerated() {
                let reaction = MessageReaction(
                    messageId: messageId,
                    emoji: emoji,
                    userId: "party_demo_user_\(index)",
                    username: "Party User \(index + 1)"
                )
                reactions.append(reaction)
                
                // Add multiple reactions for some emojis
                if emoji == "🔥" {
                    let reaction2 = MessageReaction(
                        messageId: messageId,
                        emoji: emoji,
                        userId: "party_demo_user_extra",
                        username: "Party Extra"
                    )
                    reactions.append(reaction2)
                }
            }
            
            // Group reactions by emoji and create summaries
            let groupedReactions = Dictionary(grouping: reactions, by: { $0.emoji })
            let reactionSummaries = groupedReactions.map { emoji, reactions in
                ReactionSummary(emoji: emoji, reactions: reactions, currentUserId: currentUserId)
            }.sorted { $0.count > $1.count }
            
            messageReactions[messageId] = reactionSummaries
        }
        
        print("✅ Created demo party reactions")
    }
    
    func addReaction(to messageId: String, emoji: String) {
        guard let partyId = currentParty?.id else {
            print("❌ Cannot add reaction: No party")
            return
        }
        
        let user = Auth.auth().currentUser
        let userId = user?.uid ?? ""
        let username = user?.displayName ?? "Unknown User"
        
        let reaction = MessageReaction(
            messageId: messageId,
            emoji: emoji,
            userId: userId,
            username: username
        )
        
        let db = Firestore.firestore()
        
        // Add to Firestore
        Task { @MainActor in
            do {
                try await db.collection("parties")
                    .document(partyId)
                    .collection("messageReactions")
                    .document(reaction.id)
                    .setData(reaction.toFirestoreData())
                
                print("✅ Party reaction added successfully")
                await loadReactions(for: messageId)
            } catch {
                print("❌ Failed to add party reaction: \(error)")
            }
        }
    }
    
    func removeReaction(from messageId: String, emoji: String) {
        guard let partyId = currentParty?.id else {
            print("❌ Cannot remove reaction: No party")
            return
        }
        
        let userId = Auth.auth().currentUser?.uid ?? ""
        let db = Firestore.firestore()
        
        Task { @MainActor in
            do {
                // Find and delete the user's reaction for this emoji
                let snapshot = try await db.collection("parties")
                    .document(partyId)
                    .collection("messageReactions")
                    .whereField("messageId", isEqualTo: messageId)
                    .whereField("emoji", isEqualTo: emoji)
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                for document in snapshot.documents {
                    try await document.reference.delete()
                }
                
                print("✅ Party reaction removed successfully")
                await loadReactions(for: messageId)
            } catch {
                print("❌ Failed to remove party reaction: \(error)")
            }
        }
    }
    
    func toggleReaction(on messageId: String, emoji: String) {
        let currentReactions = messageReactions[messageId] ?? []
        let hasReaction = currentReactions.first { $0.emoji == emoji }?.hasCurrentUser ?? false
        
        if hasReaction {
            removeReaction(from: messageId, emoji: emoji)
        } else {
            addReaction(to: messageId, emoji: emoji)
        }
    }
    
    func loadReactions(for messageId: String) async {
        guard let partyId = currentParty?.id else { return }
        
        let userId = Auth.auth().currentUser?.uid ?? ""
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("parties")
                .document(partyId)
                .collection("messageReactions")
                .whereField("messageId", isEqualTo: messageId)
                .getDocuments()
            
            let reactions = snapshot.documents.compactMap { doc -> MessageReaction? in
                return MessageReaction(from: doc)
            }
            
            // Group reactions by emoji
            let groupedReactions = Dictionary(grouping: reactions, by: { $0.emoji })
            let reactionSummaries = groupedReactions.map { emoji, reactions in
                ReactionSummary(emoji: emoji, reactions: reactions, currentUserId: userId)
            }.sorted { $0.count > $1.count }
            
            await MainActor.run {
                self.messageReactions[messageId] = reactionSummaries
            }
        } catch {
            print("❌ Failed to load party reactions: \(error)")
        }
    }
    
    func loadAllReactions() {
        Task { @MainActor in
            for message in chatMessages {
                await loadReactions(for: message.messageId)
            }
        }
    }
    
    // Removed duplicate implementation
    
    // Removed duplicate implementation - using the one above
    
    // MARK: - Helper Functions
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}