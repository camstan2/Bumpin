import Foundation
import FirebaseAuth

// MARK: - Notification Integration Examples

/// This file contains examples of how to integrate the notification system throughout the app

@MainActor
class NotificationExamples {
    
    private let notificationService = NotificationService.shared
    
    // MARK: - Social Interactions Examples
    
    /// Example: When someone follows a user
    func exampleFollowUser(targetUserId: String, targetUserName: String) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName else { return }
        
        // Create the follow relationship first...
        // Then send notification
        notificationService.createFollowerNotification(
            fromUserId: currentUser.uid,
            fromUserName: currentUserName,
            fromUserUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
            fromUserProfilePictureUrl: currentUser.photoURL?.absoluteString,
            toUserId: targetUserId
        )
    }
    
    /// Example: When someone likes a music log
    func exampleLikeMusicLog(logId: String, logOwnerId: String, songTitle: String, artistName: String) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName,
              currentUser.uid != logOwnerId else { return } // Don't notify yourself
        
        // Create the like first...
        // Then send notification
        notificationService.createMusicLogLikedNotification(
            fromUserId: currentUser.uid,
            fromUserName: currentUserName,
            fromUserUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
            fromUserProfilePictureUrl: currentUser.photoURL?.absoluteString,
            toUserId: logOwnerId,
            songTitle: songTitle,
            artistName: artistName,
            logId: logId
        )
    }
    
    /// Example: When someone comments on a music log
    func exampleCommentOnMusicLog(logId: String, logOwnerId: String, songTitle: String, artistName: String, commentText: String) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName,
              currentUser.uid != logOwnerId else { return } // Don't notify yourself
        
        // Create the comment first...
        // Then send notification
        notificationService.createMusicLogCommentedNotification(
            fromUserId: currentUser.uid,
            fromUserName: currentUserName,
            fromUserUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
            fromUserProfilePictureUrl: currentUser.photoURL?.absoluteString,
            toUserId: logOwnerId,
            songTitle: songTitle,
            artistName: artistName,
            logId: logId,
            commentText: commentText
        )
    }
    
    // MARK: - Party Examples
    
    /// Example: When creating a party and inviting friends
    func exampleCreatePartyAndInviteFriends(partyId: String, partyName: String, friendIds: [String]) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName else { return }
        
        // Create party first...
        // Then notify friends
        notificationService.notifyFriendsAboutNewParty(
            hostId: currentUser.uid,
            hostName: currentUserName,
            hostUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
            hostProfilePictureUrl: currentUser.photoURL?.absoluteString,
            partyId: partyId,
            partyName: partyName,
            friendIds: friendIds
        )
    }
    
    /// Example: When someone joins your party
    func exampleSomeoneJoinsParty(partyId: String, partyName: String, partyHostId: String, memberCount: Int) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName,
              currentUser.uid != partyHostId else { return } // Don't notify yourself
        
        // Join party first...
        // Then notify host
        notificationService.createPartyJoinedNotification(
            fromUserId: currentUser.uid,
            fromUserName: currentUserName,
            fromUserUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
            fromUserProfilePictureUrl: currentUser.photoURL?.absoluteString,
            toUserId: partyHostId,
            partyId: partyId,
            partyName: partyName,
            memberCount: memberCount
        )
    }
    
    // MARK: - Daily Prompt Examples
    
    /// Example: When a new daily prompt is created
    func exampleNewDailyPrompt(promptId: String, promptTitle: String) {
        // This would typically be called by an admin or scheduled function
        notificationService.notifyAllUsersAboutDailyPrompt(
            promptId: promptId,
            promptTitle: promptTitle
        )
    }
    
    /// Example: When someone likes your prompt response
    func exampleLikePromptResponse(responseId: String, responseOwnerId: String, promptId: String) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName,
              currentUser.uid != responseOwnerId else { return } // Don't notify yourself
        
        // Create the like first...
        // Then send notification
        notificationService.createPromptResponseLikedNotification(
            fromUserId: currentUser.uid,
            fromUserName: currentUserName,
            fromUserUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
            fromUserProfilePictureUrl: currentUser.photoURL?.absoluteString,
            toUserId: responseOwnerId,
            promptId: promptId,
            responseId: responseId
        )
    }
    
    // MARK: - DJ Stream Examples
    
    /// Example: When starting a DJ stream
    func exampleStartDJStream(streamId: String, streamTitle: String, followerIds: [String]) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName else { return }
        
        // Start stream first...
        // Then notify followers
        notificationService.notifyFollowersAboutDJStream(
            djId: currentUser.uid,
            djName: currentUserName,
            djUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
            djProfilePictureUrl: currentUser.photoURL?.absoluteString,
            streamId: streamId,
            streamTitle: streamTitle,
            followerIds: followerIds
        )
    }
    
    // MARK: - Direct Message Examples
    
    /// Example: When sending a direct message
    func exampleSendDirectMessage(conversationId: String, recipientId: String, messageText: String) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserName = currentUser.displayName,
              currentUser.uid != recipientId else { return } // Don't notify yourself
        
        // Send message first...
        // Then send notification
        let preview = String(messageText.prefix(50)) + (messageText.count > 50 ? "..." : "")
        
        notificationService.createNewMessageNotification(
            fromUserId: currentUser.uid,
            fromUserName: currentUserName,
            fromUserUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
            fromUserProfilePictureUrl: currentUser.photoURL?.absoluteString,
            toUserId: recipientId,
            conversationId: conversationId,
            messagePreview: preview
        )
    }
    
    // MARK: - System Notification Examples
    
    /// Example: App update notification
    func exampleAppUpdateNotification(version: String, features: [String], userIds: [String]) {
        let message = "New features: \(features.joined(separator: ", "))"
        
        notificationService.createSystemNotification(
            type: .appUpdate,
            title: "Update Available - v\(version)",
            message: message,
            toUserIds: userIds
        )
    }
    
    /// Example: Feature announcement
    func exampleFeatureAnnouncement(featureName: String, description: String, userIds: [String]) {
        notificationService.createSystemNotification(
            type: .featureAnnouncement,
            title: "New Feature: \(featureName)",
            message: description,
            toUserIds: userIds
        )
    }
    
    /// Example: Maintenance notification
    func exampleMaintenanceNotification(startTime: Date, duration: String, userIds: [String]) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let message = "Scheduled maintenance on \(formatter.string(from: startTime)). Duration: \(duration)"
        
        notificationService.createSystemNotification(
            type: .maintenance,
            title: "Scheduled Maintenance",
            message: message,
            toUserIds: userIds
        )
    }
}

// MARK: - Integration Points

/// This extension shows where to integrate notifications throughout the app
extension NotificationExamples {
    
    /// Integration points for the existing codebase:
    func integrationPoints() {
        /*
         
         1. SocialFeedViewModel.swift
            - In functions that handle likes/comments on music logs
            - When users follow each other
         
         2. PartyManager.swift
            - When creating parties (notify friends)
            - When someone joins a party (notify host)
            - When parties end
         
         3. DailyPromptCoordinator.swift
            - When new prompts are created
            - When responses are liked/commented
         
         4. DJStreamingManager.swift
            - When DJ streams start
            - When streams go live
         
         5. DirectMessageService.swift
            - When new messages are sent
            - When message requests are received
         
         6. Admin functions
            - App updates
            - Feature announcements
            - Maintenance notifications
         
         */
    }
}

// MARK: - Usage in Existing Code

/// Example of how to integrate into PartyManager.swift
extension PartyManager {
    
    /// Add this to your createParty function
    func notifyFriendsAboutNewParty() {
        // After party creation succeeds...
        guard let party = currentParty,
              let currentUser = Auth.auth().currentUser else { return }
        
        // Get friend IDs (this would come from your friends system)
        let friendIds: [String] = [] // TODO: Load from friends list
        
        Task { @MainActor in
            NotificationService.shared.notifyFriendsAboutNewParty(
                hostId: currentUserId,
                hostName: currentUser.displayName ?? "Unknown Host",
                hostUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
                hostProfilePictureUrl: currentUser.photoURL?.absoluteString,
                partyId: party.id,
                partyName: party.name,
                friendIds: friendIds
            )
        }
    }
}

/// Example of how to integrate into SocialFeedViewModel.swift
extension SocialFeedViewModel {
    
    /// Add this to your like music log function
    func notifyAboutMusicLogLike(log: MusicLog) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        Task { @MainActor in
            NotificationService.shared.createMusicLogLikedNotification(
                fromUserId: currentUser.uid,
                fromUserName: currentUser.displayName ?? "Someone",
                fromUserUsername: currentUser.email?.components(separatedBy: "@").first ?? "user",
                fromUserProfilePictureUrl: currentUser.photoURL?.absoluteString,
                toUserId: log.userId,
                songTitle: log.title,
                artistName: log.artistName,
                logId: log.id
            )
        }
    }
}