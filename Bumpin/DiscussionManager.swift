//
//  DiscussionManager.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import AVFoundation

class DiscussionManager: ObservableObject {
    @Published var currentDiscussion: TopicChat?
    @Published var currentDiscussionType: DiscussionType?
    @Published var showDiscussionView = false
    
    // Discussion minimization state
    @Published var discussionConnectionState: DiscussionConnectionState = .disconnected
    @Published var isDiscussionMinimized: Bool = false
    
    // Voice chat
    @Published var voiceChatManager = VoiceChatManager()
    @Published var voiceChatStatus: String = "Disconnected"
    
    private let db = Firestore.firestore()
    
    // Real user data from Firebase Auth
    var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Discussion Management
    
    /// Joins a discussion (either random chat or topic chat)
    func joinDiscussion(_ discussion: TopicChat, type: DiscussionType) {
        print("🎙️ Joining discussion: \(discussion.title)")
        
        currentDiscussion = discussion
        currentDiscussionType = type
        discussionConnectionState = .active
        isDiscussionMinimized = false
        showDiscussionView = true
        
        // Start voice chat
        startVoiceChat(discussionId: discussion.id)
        
        // Persist state to Firestore
        persistDiscussionConnectionState()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("DiscussionJoined"), object: discussion)
    }
    
    /// Starts voice chat for the discussion
    private func startVoiceChat(discussionId: String) {
        Task {
            do {
                voiceChatManager.startVoiceChat(partyId: discussionId)
                await MainActor.run {
                    voiceChatStatus = "Connected to voice chat"
                }
                print("✅ Voice chat started for discussion: \(discussionId)")
            } catch {
                await MainActor.run {
                    voiceChatStatus = "Voice chat failed: \(error.localizedDescription)"
                }
                print("⚠️ Failed to start voice chat: \(error)")
            }
        }
    }
    
    // MARK: - Discussion Minimization Functions
    
    /// Minimizes the discussion - keeps connection but hides UI
    func minimizeDiscussion() {
        guard var discussion = currentDiscussion, discussionConnectionState == .active else { return }
        
        print("🔽 Minimizing discussion: \(discussion.title)")
        
        // Update discussion state
        discussionConnectionState = .minimized
        isDiscussionMinimized = true
        
        // Hide discussion view but keep everything running
        showDiscussionView = false
        
        // Ensure background audio continues
        ensureBackgroundAudioContinuation()
        
        // Keep voice chat active
        // Keep Firestore listeners active
        
        // Persist state to Firestore
        persistDiscussionConnectionState()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("DiscussionMinimized"), object: discussion)
    }
    
    /// Ensures background audio continues when discussion is minimized
    private func ensureBackgroundAudioContinuation() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            print("✅ Background audio session confirmed active for minimized discussion")
        } catch {
            print("⚠️ Failed to ensure background audio session: \(error.localizedDescription)")
        }
    }
    
    /// Restores the discussion from minimized state
    func restoreDiscussion() {
        guard let discussion = currentDiscussion, discussionConnectionState == .minimized else { return }
        
        print("🔼 Restoring discussion: \(discussion.title)")
        
        // Update discussion state
        discussionConnectionState = .active
        isDiscussionMinimized = false
        
        // Show discussion view
        showDiscussionView = true
        
        // Persist state to Firestore
        persistDiscussionConnectionState()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("DiscussionRestored"), object: discussion)
    }
    
    /// Completely leaves the discussion
    func leaveDiscussion() {
        guard let discussion = currentDiscussion else { return }
        
        print("🚪 Leaving discussion: \(discussion.title)")
        
        // Stop voice chat
        voiceChatManager.stopVoiceChat()
        
        // Update state
        discussionConnectionState = .disconnected
        isDiscussionMinimized = false
        currentDiscussion = nil
        currentDiscussionType = nil
        showDiscussionView = false
        voiceChatStatus = "Disconnected"
        
        // Update Firestore to remove user from discussion
        leaveDiscussionInFirestore(discussionId: discussion.id)
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("DiscussionLeft"), object: discussion)
    }
    
    /// Persists the discussion connection state to Firestore
    private func persistDiscussionConnectionState() {
        guard let discussion = currentDiscussion,
              let discussionType = currentDiscussionType else { return }
        
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        db.collection(collection).document(discussion.id).updateData([
            "connectionState": discussionConnectionState.rawValue,
            "lastActivity": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating discussion connection state: \(error.localizedDescription)")
            } else {
                print("✅ Discussion connection state updated: \(self.discussionConnectionState.rawValue)")
            }
        }
    }
    
    /// Removes user from discussion in Firestore
    private func leaveDiscussionInFirestore(discussionId: String) {
        guard let discussionType = currentDiscussionType else { return }
        
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        db.collection(collection).document(discussionId).updateData([
            "participants": FieldValue.arrayRemove([currentUserId]),
            "leftAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error leaving discussion: \(error.localizedDescription)")
            } else {
                print("✅ Left discussion in Firestore")
            }
        }
    }
    
    // MARK: - Voice Chat Controls
    
    /// Toggles microphone mute state
    func toggleMute() {
        voiceChatManager.toggleMute()
        print("🎤 Toggled mute: \(voiceChatManager.isMuted ? "muted" : "unmuted")")
    }
    
    /// Gets current speaking state
    var isSpeaking: Bool {
        return voiceChatManager.isSpeaking
    }
    
    /// Gets current mute state
    var isMuted: Bool {
        return voiceChatManager.isMuted
    }
    
    // MARK: - Speaking Permission Management
    
    /// Updates speaking permissions for a participant
    func updateSpeakingPermission(userId: String, canSpeak: Bool) {
        guard let discussion = currentDiscussion,
              let discussionType = currentDiscussionType else { return }
        
        var updatedDiscussion = discussion
        
        if canSpeak {
            // Add to speakers, remove from listeners
            if !updatedDiscussion.speakers.contains(userId) {
                updatedDiscussion.speakers.append(userId)
            }
            updatedDiscussion.listeners.removeAll { $0 == userId }
        } else {
            // Remove from speakers, add to listeners
            updatedDiscussion.speakers.removeAll { $0 == userId }
            if !updatedDiscussion.listeners.contains(userId) {
                updatedDiscussion.listeners.append(userId)
            }
        }
        
        // Update local state
        currentDiscussion = updatedDiscussion
        
        // Update Firestore
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        db.collection(collection).document(discussion.id).updateData([
            "speakers": updatedDiscussion.speakers,
            "listeners": updatedDiscussion.listeners,
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating speaking permissions: \(error.localizedDescription)")
            } else {
                print("✅ Speaking permissions updated for user \(userId): \(canSpeak ? "can speak" : "listener only")")
            }
        }
        
        // TODO: Update voice chat permissions when VoiceChatManager supports it
        // if canSpeak {
        //     voiceChatManager.grantSpeakingPermission(userId: userId)
        // } else {
        //     voiceChatManager.revokeSpeakingPermission(userId: userId)
        // }
    }
    
    /// Kicks a participant from the discussion
    func kickParticipant(userId: String) {
        guard let discussion = currentDiscussion,
              let discussionType = currentDiscussionType,
              discussion.hostId == currentUserId else {
            print("❌ Only host can kick participants")
            return
        }
        
        var updatedDiscussion = discussion
        
        // Remove from all arrays
        updatedDiscussion.participants.removeAll { participant in participant.id == userId }
        updatedDiscussion.speakers.removeAll { $0 == userId }
        updatedDiscussion.listeners.removeAll { $0 == userId }
        
        // Update local state
        currentDiscussion = updatedDiscussion
        
        // Update Firestore
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        let participantArray: [[String: Any]] = updatedDiscussion.participants.map { participant in
            [
                "id": participant.id,
                "name": participant.name,
                "profileImageUrl": participant.profileImageUrl ?? NSNull(),
                "isHost": participant.isHost
            ]
        }
        
        db.collection(collection).document(discussion.id).updateData([
            "participants": participantArray,
            "speakers": updatedDiscussion.speakers,
            "listeners": updatedDiscussion.listeners,
            "kickedUsers": FieldValue.arrayUnion([userId]),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error kicking participant: \(error.localizedDescription)")
            } else {
                print("✅ Kicked participant \(userId) from discussion")
            }
        }
        
        // TODO: Remove from voice chat when VoiceChatManager supports it
        // voiceChatManager.removeParticipant(userId: userId)
    }
    
    /// Mutes a participant for everyone (host only)
    func muteParticipantGlobally(userId: String) {
        guard let discussion = currentDiscussion,
              let discussionType = currentDiscussionType,
              discussion.hostId == currentUserId else {
            print("❌ Only host can mute participants globally")
            return
        }
        
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        db.collection(collection).document(discussion.id).updateData([
            "globallyMutedUsers": FieldValue.arrayUnion([userId]),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error muting participant globally: \(error.localizedDescription)")
            } else {
                print("✅ Muted participant \(userId) globally")
            }
        }
        
        // TODO: Mute in voice chat when VoiceChatManager supports it
        // voiceChatManager.muteParticipant(userId: userId, isMuted: true)
    }
}
