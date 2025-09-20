import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Notification Service

@MainActor
class NotificationService: ObservableObject {
    
    static let shared = NotificationService()
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    @Published var unreadCount = 0
    @Published var recentNotifications: [AppNotification] = []
    
    private init() {}
    
    // MARK: - Create Notifications
    
    /// Create a new follower notification
    func createFollowerNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserId: String) {
        let notification = AppNotification(
            type: .newFollower,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl
        )
        
        saveNotification(notification, toUserId: toUserId)
        logAnalytics("new_follower", fromUserId: fromUserId, toUserId: toUserId)
    }
    
    /// Create a music log liked notification
    func createMusicLogLikedNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserId: String, songTitle: String, artistName: String, logId: String) {
        let notification = AppNotification(
            type: .musicLogLiked,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
            contextId: logId,
            contextTitle: songTitle,
            contextSubtitle: artistName
        )
        
        saveNotification(notification, toUserId: toUserId)
        logAnalytics("music_log_liked", fromUserId: fromUserId, toUserId: toUserId)
    }
    
    /// Create a music log commented notification
    func createMusicLogCommentedNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserId: String, songTitle: String, artistName: String, logId: String, commentText: String) {
        let notification = AppNotification(
            type: .musicLogCommented,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
            contextId: logId,
            contextTitle: songTitle,
            contextSubtitle: artistName,
            message: String(commentText.prefix(100)) // Preview of comment
        )
        
        saveNotification(notification, toUserId: toUserId)
        logAnalytics("music_log_commented", fromUserId: fromUserId, toUserId: toUserId)
    }
    
    /// Create a party invite notification
    func createPartyInviteNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserId: String, partyId: String, partyName: String) {
        let notification = AppNotification(
            type: .partyInvite,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
            contextId: partyId,
            contextTitle: partyName
        )
        
        saveNotification(notification, toUserId: toUserId)
        logAnalytics("party_invite", fromUserId: fromUserId, toUserId: toUserId)
    }
    
    /// Create a party joined notification
    func createPartyJoinedNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserId: String, partyId: String, partyName: String, memberCount: Int) {
        let notification = AppNotification(
            type: .partyJoined,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
            contextId: partyId,
            contextTitle: partyName,
            contextSubtitle: "\(memberCount) members"
        )
        
        saveNotification(notification, toUserId: toUserId)
        logAnalytics("party_joined", fromUserId: fromUserId, toUserId: toUserId)
    }
    
    /// Create a friend started party notification
    func createFriendStartedPartyNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserIds: [String], partyId: String, partyName: String) {
        let notification = AppNotification(
            type: .friendStartedParty,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
            contextId: partyId,
            contextTitle: partyName
        )
        
        for toUserId in toUserIds {
            saveNotification(notification, toUserId: toUserId)
        }
        logAnalytics("friend_started_party", fromUserId: fromUserId, toUserId: nil)
    }
    
    /// Create a new daily prompt notification
    func createNewDailyPromptNotification(promptId: String, promptTitle: String, toUserIds: [String]) {
        let notification = AppNotification(
            type: .newDailyPrompt,
            contextId: promptId,
            contextTitle: promptTitle
        )
        
        for toUserId in toUserIds {
            saveNotification(notification, toUserId: toUserId)
        }
        logAnalytics("new_daily_prompt", fromUserId: nil, toUserId: nil)
    }
    
    /// Create a prompt response liked notification
    func createPromptResponseLikedNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserId: String, promptId: String, responseId: String) {
        let notification = AppNotification(
            type: .promptResponseLiked,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
            contextId: responseId
        )
        
        saveNotification(notification, toUserId: toUserId)
        logAnalytics("prompt_response_liked", fromUserId: fromUserId, toUserId: toUserId)
    }
    
    /// Create a DJ stream started notification
    func createDJStreamStartedNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserIds: [String], streamId: String, streamTitle: String) {
        let notification = AppNotification(
            type: .djStreamStarted,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
            contextId: streamId,
            contextTitle: streamTitle
        )
        
        for toUserId in toUserIds {
            saveNotification(notification, toUserId: toUserId)
        }
        logAnalytics("dj_stream_started", fromUserId: fromUserId, toUserId: nil)
    }
    
    /// Create a new message notification
    func createNewMessageNotification(fromUserId: String, fromUserName: String, fromUserUsername: String, fromUserProfilePictureUrl: String?, toUserId: String, conversationId: String, messagePreview: String) {
        let notification = AppNotification(
            type: .newMessage,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserUsername: fromUserUsername,
            fromUserProfilePictureUrl: fromUserProfilePictureUrl,
            contextId: conversationId,
            message: messagePreview
        )
        
        saveNotification(notification, toUserId: toUserId)
        logAnalytics("new_message", fromUserId: fromUserId, toUserId: toUserId)
    }
    
    /// Create a system notification
    func createSystemNotification(type: NotificationType, title: String, message: String, toUserIds: [String]) {
        let notification = AppNotification(
            type: type,
            contextTitle: title,
            message: message
        )
        
        for toUserId in toUserIds {
            saveNotification(notification, toUserId: toUserId)
        }
        logAnalytics("system_notification", fromUserId: nil, toUserId: nil)
    }
    
    // MARK: - Private Helper Methods
    
    private func saveNotification(_ notification: AppNotification, toUserId: String) {
        do {
            let data = try Firestore.Encoder().encode(notification)
            db.collection("users").document(toUserId).collection("notifications")
                .document(notification.notificationId)
                .setData(data) { error in
                    if let error = error {
                        print("❌ Error saving notification: \(error.localizedDescription)")
                    } else {
                        print("✅ Notification saved successfully")
                    }
                }
        } catch {
            print("❌ Error encoding notification: \(error.localizedDescription)")
        }
    }
    
    private func logAnalytics(_ event: String, fromUserId: String?, toUserId: String?) {
        var parameters: [String: Any] = [:]
        if let fromUserId = fromUserId {
            parameters["from_user_id"] = fromUserId
        }
        if let toUserId = toUserId {
            parameters["to_user_id"] = toUserId
        }
        parameters["timestamp"] = Date().timeIntervalSince1970
        
        AnalyticsService.shared.logEvent("notification_\(event)", parameters: parameters)
    }
    
    // MARK: - Notification Management
    
    /// Start listening for notifications for the current user
    func startListening() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let listener = db.collection("users").document(currentUserId).collection("notifications")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to notifications: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.recentNotifications = documents.compactMap { doc in
                        let data = doc.data()
                        guard let typeString = data["type"] as? String,
                              let type = NotificationType(rawValue: typeString),
                              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                            return nil
                        }
                        
                        return AppNotification(
                            notificationId: doc.documentID,
                            type: type,
                            timestamp: timestamp,
                            isRead: data["isRead"] as? Bool ?? false,
                            fromUserId: data["fromUserId"] as? String,
                            fromUserName: data["fromUserName"] as? String,
                            fromUserUsername: data["fromUserUsername"] as? String,
                            fromUserProfilePictureUrl: data["fromUserProfilePictureUrl"] as? String,
                            contextId: data["contextId"] as? String,
                            contextTitle: data["contextTitle"] as? String,
                            contextSubtitle: data["contextSubtitle"] as? String,
                            contextImageUrl: data["contextImageUrl"] as? String,
                            message: data["message"] as? String
                        )
                    }
                    
                    self.unreadCount = self.recentNotifications.filter { !$0.isRead }.count
                }
            }
        
        listeners.append(listener)
    }
    
    /// Stop listening to notifications
    func stopListening() {
        for listener in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
    
    /// Mark a notification as read
    func markAsRead(_ notification: AppNotification) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(currentUserId).collection("notifications")
            .document(notification.notificationId)
            .updateData(["isRead": true]) { error in
                if let error = error {
                    print("❌ Error marking notification as read: \(error.localizedDescription)")
                }
            }
    }
    
    /// Mark all notifications as read
    func markAllAsRead() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        for notification in recentNotifications where !notification.isRead {
            let ref = db.collection("users").document(currentUserId).collection("notifications")
                .document(notification.notificationId)
            batch.updateData(["isRead": true], forDocument: ref)
        }
        
        batch.commit { error in
            if let error = error {
                print("❌ Error marking all notifications as read: \(error.localizedDescription)")
            }
        }
    }
    
    /// Delete a notification
    func deleteNotification(_ notification: AppNotification) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(currentUserId).collection("notifications")
            .document(notification.notificationId)
            .delete { error in
                if let error = error {
                    print("❌ Error deleting notification: \(error.localizedDescription)")
                }
            }
    }
    
    /// Clear all notifications
    func clearAllNotifications() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        for notification in recentNotifications {
            let ref = db.collection("users").document(currentUserId).collection("notifications")
                .document(notification.notificationId)
            batch.deleteDocument(ref)
        }
        
        batch.commit { error in
            if let error = error {
                print("❌ Error clearing all notifications: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Convenience Extensions

extension NotificationService {
    
    /// Quick method to notify all friends about a new party
    func notifyFriendsAboutNewParty(hostId: String, hostName: String, hostUsername: String, hostProfilePictureUrl: String?, partyId: String, partyName: String, friendIds: [String]) {
        createFriendStartedPartyNotification(
            fromUserId: hostId,
            fromUserName: hostName,
            fromUserUsername: hostUsername,
            fromUserProfilePictureUrl: hostProfilePictureUrl,
            toUserIds: friendIds,
            partyId: partyId,
            partyName: partyName
        )
    }
    
    /// Quick method to notify followers about a new DJ stream
    func notifyFollowersAboutDJStream(djId: String, djName: String, djUsername: String, djProfilePictureUrl: String?, streamId: String, streamTitle: String, followerIds: [String]) {
        createDJStreamStartedNotification(
            fromUserId: djId,
            fromUserName: djName,
            fromUserUsername: djUsername,
            fromUserProfilePictureUrl: djProfilePictureUrl,
            toUserIds: followerIds,
            streamId: streamId,
            streamTitle: streamTitle
        )
    }
    
    /// Quick method to send daily prompt notifications to all active users
    func notifyAllUsersAboutDailyPrompt(promptId: String, promptTitle: String) {
        // This would typically fetch all active user IDs from the database
        // For now, we'll leave this as a placeholder
        let allActiveUserIds: [String] = [] // TODO: Implement fetching active users
        
        createNewDailyPromptNotification(
            promptId: promptId,
            promptTitle: promptTitle,
            toUserIds: allActiveUserIds
        )
    }
}

