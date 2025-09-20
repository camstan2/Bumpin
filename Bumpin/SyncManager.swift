//
//  SyncManager.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import UIKit

class SyncManager: ObservableObject {
    @Published var isHost = false
    @Published var syncStatus: SyncStatus = .disconnected
    @Published var lastSyncTime: Date?
    @Published var participantsInSync: Int = 0
    
    private var syncTimer: Timer?
    private var lastPlaybackTime: TimeInterval = 0
    private var partyListener: ListenerRegistration?
    // Background task management removed
    var currentPartyId: String?
    weak var musicManager: MusicManager?
    private var syncStatusTimer: Timer?
    private var heartbeatTask: Task<Void, Never>? = nil
    private var syncStatusTask: Task<Void, Never>? = nil
    
    enum SyncStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case syncing
        case error(String)
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.connected, .connected),
                 (.syncing, .syncing):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    // Add this enum for sync status per participant
    enum ParticipantSyncStatus: String, Codable {
        case inSync = "in_sync"
        case lagging = "lagging"
        case disconnected = "disconnected"
    }

    // Track sync status for each participant (userId: status)
    @Published var participantSyncStatuses: [String: ParticipantSyncStatus] = [:]

    init() {
        setupBackgroundNotifications()
    }
    
    private func setupBackgroundNotifications() {
        // Background notifications removed to prevent app lifecycle conflicts
        print("[SyncManager] Background notifications disabled")
    }
    
    @objc private func handleAppDidEnterBackground() {
        print("[SyncManager] App entered background - sync will continue")
    }
    
    @objc private func handleAppWillEnterForeground() {
        print("[SyncManager] App will enter foreground - sync refreshed")
    }
    
    // App lifecycle handling removed to prevent state cycling
    
    // Background tasks removed - using native iOS background capabilities
    
    func startHosting() {
        isHost = true
        syncStatus = .connected
        lastSyncTime = Date()
        startHeartbeat()
    }
    
    func joinParty(partyCode: String) {
        isHost = false
        syncStatus = .connecting
        currentPartyId = partyCode
        setupPartyListener(partyId: partyCode)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.syncStatus = .connected
            self.lastSyncTime = Date()
        }
    }
    
    func setupPartyListener(partyId: String) {
        let db = Firestore.firestore()
        partyListener = db.collection("parties").document(partyId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.syncStatus = .error(error.localizedDescription)
                    }
                    return
                }
                guard let document = documentSnapshot else {
                    DispatchQueue.main.async {
                        self.syncStatus = .error("Party not found")
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.handlePartyUpdate(document: document)
                }
            }
    }

    func removePartyListener() {
        partyListener?.remove()
        partyListener = nil
    }
    
    private func handlePartyUpdate(document: DocumentSnapshot) {
        guard let data = document.data() else { return }
        syncStatus = .connected
        lastSyncTime = Date()
        
        // Handle current song updates
        if let songData = data["currentSong"] as? [String: Any], !songData.isEmpty {
            if let title = songData["title"] as? String,
               let artist = songData["artist"] as? String,
               let position = songData["position"] as? Double,
               let isPlaying = songData["isPlaying"] as? Bool,
               let updatedAt = songData["updatedAt"] as? Timestamp {
                let song = Song(
                    title: title,
                    artist: artist,
                    duration: songData["duration"] as? Double ?? 0,
                    appleMusicId: songData["appleMusicId"] as? String
                )
                if !isHost {
                    // Timestamp compensation
                    let serverTime = updatedAt.dateValue().timeIntervalSince1970
                    let now = Date().timeIntervalSince1970
                    let elapsed = now - serverTime
                    let compensatedPosition = position + elapsed
                    receivePlaybackUpdate(song: song, time: compensatedPosition, isPlaying: isPlaying)
                }
            }
        }
        
        // Handle queue updates
        if let queueData = data["musicQueue"] as? [[String: Any]] {
            receiveQueueUpdate(queueData: queueData)
        }
        
        // Handle shuffle state updates
        if let isShuffled = data["isShuffled"] as? Bool {
            receiveShuffleStateUpdate(isShuffled: isShuffled)
        }
        
        if let participants = data["participants"] as? [[String: Any]] {
            participantsInSync = participants.count
            var syncStatuses: [String: ParticipantSyncStatus] = [:]
            for participant in participants {
                if let id = participant["id"] as? String,
                   let statusRaw = participant["syncStatus"] as? String,
                   let status = ParticipantSyncStatus(rawValue: statusRaw) {
                    syncStatuses[id] = status
                }
            }
            participantSyncStatuses = syncStatuses
        }
    }
    
    func broadcastPlaybackUpdate(song: Song, time: TimeInterval, isPlaying: Bool) {
        guard isHost, let partyId = currentPartyId else { return }
        let db = Firestore.firestore()
        let songData: [String: Any] = [
            "title": song.title,
            "artist": song.artist,
            "position": time,
            "isPlaying": isPlaying,
            "duration": song.duration,
            "appleMusicId": song.appleMusicId ?? NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        db.collection("parties").document(partyId).updateData([
            "currentSong": songData
        ]) { error in
            if let error = error {
                print("Error broadcasting playback update: \(error.localizedDescription)")
            }
        }
    }
    
    func receivePlaybackUpdate(song: Song, time: TimeInterval, isPlaying: Bool) {
        guard !isHost else { return }
        // Only seek if out of sync by more than 0.3 seconds
        if let musicManager = musicManager {
            let localTime = musicManager.currentTime
            let diff = abs(localTime - time)
            if diff > 0.3 {
                print("[Sync] Seeking to compensated time: \(time) (diff: \(diff))")
                musicManager.playSong(song, at: time)
                if isPlaying {
                    musicManager.play()
                } else {
                    musicManager.pause()
                }
            } else {
                print("[Sync] Already in sync (diff: \(diff))")
            }
        } else {
            // Fallback: notify music manager to sync
            NotificationCenter.default.post(
                name: .syncPlayback,
                object: nil,
                userInfo: [
                    "song": song,
                    "time": time,
                    "isPlaying": isPlaying
                ]
            )
        }
    }
    
    // Call this method to update and broadcast the current user's sync status
    func updateMySyncStatus(_ status: ParticipantSyncStatus) {
        guard let partyId = currentPartyId, let userId = getCurrentUserId() else { return }
        let db = Firestore.firestore()
        // Update participant's sync status in Firestore
        db.collection("parties").document(partyId).getDocument { document, error in
            guard let document = document, document.exists, var data = document.data(),
                  var participants = data["participants"] as? [[String: Any]] else { return }
            for i in 0..<participants.count {
                if let id = participants[i]["id"] as? String, id == userId {
                    participants[i]["syncStatus"] = status.rawValue
                }
            }
            db.collection("parties").document(partyId).updateData(["participants": participants])
        }
        // Update local state
        participantSyncStatuses[userId] = status
    }

    // Call this periodically or after playback updates to check and update sync status
    func evaluateAndUpdateMySyncStatus(hostTime: TimeInterval?) {
        guard let myTime = musicManager?.currentTime, let hostTime = hostTime else { return }
        let diff = abs(myTime - hostTime)
        let status: ParticipantSyncStatus
        if diff < 1.5 {
            status = .inSync
        } else if diff < 5.0 {
            status = .lagging
        } else {
            status = .disconnected
        }
        updateMySyncStatus(status)
    }

    // Call this to resync playback to the host's position
    func resyncToHost(hostTime: TimeInterval?) {
        guard let hostTime = hostTime else { return }
        musicManager?.seekTo(hostTime)
        updateMySyncStatus(.inSync)
    }

    // Helper to get current user ID (should match PartyManager's logic)
    private func getCurrentUserId() -> String? {
        // Get current user ID from Firebase Auth
        return FirebaseAuth.Auth.auth().currentUser?.uid
    }
    
    private func startHeartbeat() {
        syncTimer?.invalidate()
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !(Task.isCancelled) {
                if let strong = self, strong.isHost, let musicManager = strong.musicManager, let song = musicManager.currentSong {
                    await MainActor.run {
                        strong.broadcastPlaybackUpdate(song: song, time: musicManager.currentTime, isPlaying: musicManager.isPlaying)
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
    
    func startSyncStatusTimer(getHostTime: @escaping () -> TimeInterval?) {
        syncStatusTimer?.invalidate()
        syncStatusTask?.cancel()
        syncStatusTask = Task { [weak self] in
            while !(Task.isCancelled) {
                if let strong = self, !strong.isHost, let hostTime = getHostTime(), let myTime = strong.musicManager?.currentTime {
                    let diff = abs(myTime - hostTime)
                    await MainActor.run {
                        if diff > 2.0 {
                            strong.updateMySyncStatus(.lagging)
                        } else if diff > 0.4 {
                            strong.musicManager?.seekTo(hostTime)
                            strong.updateMySyncStatus(.inSync)
                        } else {
                            strong.updateMySyncStatus(.inSync)
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stopSyncStatusTimer() {
        syncStatusTimer?.invalidate()
        syncStatusTimer = nil
        syncStatusTask?.cancel()
        syncStatusTask = nil
    }
    
    // MARK: - Queue Synchronization
    
    func receiveQueueUpdate(queueData: [[String: Any]]) {
        guard !isHost else { return } // Only non-hosts should receive queue updates
        
        let queue = queueData.compactMap { songData -> Song? in
            guard let id = songData["id"] as? String,
                  let title = songData["title"] as? String,
                  let artist = songData["artist"] as? String,
                  let duration = songData["duration"] as? TimeInterval else {
                return nil
            }
            
            let albumArt = songData["albumArt"] as? String
            let appleMusicId = songData["appleMusicId"] as? String
            let isCatalogSong = songData["isCatalogSong"] as? Bool ?? false
            
            return Song(
                title: title,
                artist: artist,
                albumArt: albumArt,
                duration: duration,
                appleMusicId: appleMusicId,
                isCatalogSong: isCatalogSong
            )
        }
        
        // Update music manager's queue
        musicManager?.setQueue(queue)
        
        // Notify UI about queue update
        NotificationCenter.default.post(
            name: .queueUpdated,
            object: nil,
            userInfo: ["queue": queue]
        )
    }
    
    func receiveShuffleStateUpdate(isShuffled: Bool) {
        guard !isHost else { return } // Only non-hosts should receive shuffle updates
        
        musicManager?.isShuffled = isShuffled
        
        // Notify UI about shuffle state update
        NotificationCenter.default.post(
            name: .shuffleStateUpdated,
            object: nil,
            userInfo: ["isShuffled": isShuffled]
        )
    }
    
    func disconnect() {
        partyListener?.remove()
        partyListener = nil
        syncTimer?.invalidate()
        syncTimer = nil
        syncStatusTimer?.invalidate()
        syncStatusTimer = nil
        syncStatus = .disconnected
        isHost = false
        participantsInSync = 0
        currentPartyId = nil
    }
    
    deinit {
        disconnect()
        NotificationCenter.default.removeObserver(self)
    }
}

// Notification for sync updates
extension Notification.Name {
    static let syncPlayback = Notification.Name("syncPlayback")
    static let queueUpdated = Notification.Name("queueUpdated")
    static let shuffleStateUpdated = Notification.Name("shuffleStateUpdated")
    static let songPlayed = Notification.Name("songPlayed")
} 