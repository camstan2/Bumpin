import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private let db = Firestore.firestore()
    @Published var unreadCount: Int = 0
    
    private var unreadListener: ListenerRegistration?
    
    private init() {
        startUnreadListener()
    }
    
    deinit {
        unreadListener?.remove()
    }
    
    // MARK: - Unread Count Listener
    
    func startUnreadListener() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        unreadListener = db.collection("users")
            .document(currentUserId)
            .collection("notifications")
            .whereField("isRead", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to unread notifications: \(error)")
                    return
                }
                
                self.unreadCount = snapshot?.documents.count ?? 0
                print("🔔 Unread notifications: \(self.unreadCount)")
            }
    }
    
    // MARK: - Create Notifications
    
    /// Create a follow notification
    func createFollowNotification(followedUserId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != followedUserId else { return }
        
        do {
            // Get current user info
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            let username = userDoc.data()?["username"] as? String ?? "Someone"
            let displayName = userDoc.data()?["displayName"] as? String ?? username
            let profilePictureUrl = userDoc.data()?["profilePictureUrl"] as? String
            
        let notification = AppNotification(
            type: .newFollower,
                fromUserId: currentUserId,
                fromUserName: displayName,
                fromUserUsername: username,
                fromUserProfilePictureUrl: profilePictureUrl
            )
            
            try await saveNotification(notification, toUserId: followedUserId)
            print("✅ Follow notification created")
        } catch {
            print("❌ Error creating follow notification: \(error)")
        }
    }
    
    /// Create a like notification
    func createLikeNotification(logId: String, logOwnerId: String, log: MusicLog) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != logOwnerId else { return }
        
        do {
            // Get current user info
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            let username = userDoc.data()?["username"] as? String ?? "Someone"
            let displayName = userDoc.data()?["displayName"] as? String ?? username
            let profilePictureUrl = userDoc.data()?["profilePictureUrl"] as? String
            
            // For now, create individual notifications (grouping will be implemented later)
            
        let notification = AppNotification(
                type: .musicLogLiked,
                fromUserId: currentUserId,
                fromUserName: displayName,
                fromUserUsername: username,
                fromUserProfilePictureUrl: profilePictureUrl,
            contextId: logId,
                contextTitle: log.title,
                contextSubtitle: log.artistName,
                contextImageUrl: log.artworkUrl
            )
            
            try await saveNotification(notification, toUserId: logOwnerId, groupedUserIds: [currentUserId])
            print("✅ Like notification created")
        } catch {
            print("❌ Error creating like notification: \(error)")
        }
    }
    
    /// Create a comment notification
    func createCommentNotification(logId: String, logOwnerId: String, log: MusicLog, commentText: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != logOwnerId else { return }
        
        do {
            // Get current user info
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            let username = userDoc.data()?["username"] as? String ?? "Someone"
            let displayName = userDoc.data()?["displayName"] as? String ?? username
            let profilePictureUrl = userDoc.data()?["profilePictureUrl"] as? String
            
            // Truncate comment if too long
            let maxLength = 100
            let truncatedComment = commentText.count > maxLength ? 
                String(commentText.prefix(maxLength)) + "..." : commentText
            
        let notification = AppNotification(
                type: .musicLogCommented,
                fromUserId: currentUserId,
                fromUserName: displayName,
                fromUserUsername: username,
                fromUserProfilePictureUrl: profilePictureUrl,
                contextId: logId,
                contextTitle: log.title,
                contextSubtitle: log.artistName,
                contextImageUrl: log.artworkUrl,
                message: truncatedComment
            )
            
            try await saveNotification(notification, toUserId: logOwnerId)
            print("✅ Comment notification created")
        } catch {
            print("❌ Error creating comment notification: \(error)")
        }
    }
    
    /// Create a repost notification
    func createRepostNotification(logId: String, logOwnerId: String, log: MusicLog) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != logOwnerId else { return }
        
        do {
            // Get current user info
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            let username = userDoc.data()?["username"] as? String ?? "Someone"
            let displayName = userDoc.data()?["displayName"] as? String ?? username
            let profilePictureUrl = userDoc.data()?["profilePictureUrl"] as? String
            
            // For now, create individual notifications (grouping will be implemented later)
            
        let notification = AppNotification(
                type: .musicLogReposted,
                fromUserId: currentUserId,
                fromUserName: displayName,
                fromUserUsername: username,
                fromUserProfilePictureUrl: profilePictureUrl,
                contextId: logId,
                contextTitle: log.title,
                contextSubtitle: log.artistName,
                contextImageUrl: log.artworkUrl
            )
            
            try await saveNotification(notification, toUserId: logOwnerId, groupedUserIds: [currentUserId])
            print("✅ Repost notification created")
        } catch {
            print("❌ Error creating repost notification: \(error)")
        }
    }
    
    /// Create a dislike notification
    func createDislikeNotification(logId: String, logOwnerId: String, log: MusicLog) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != logOwnerId else { return }
        
        do {
            // Get current user info
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            let username = userDoc.data()?["username"] as? String ?? "Someone"
            let displayName = userDoc.data()?["displayName"] as? String ?? username
            let profilePictureUrl = userDoc.data()?["profilePictureUrl"] as? String
            
            // For now, create individual notifications (grouping will be implemented later)
            
        let notification = AppNotification(
                type: .musicLogDisliked,
                fromUserId: currentUserId,
                fromUserName: displayName,
                fromUserUsername: username,
                fromUserProfilePictureUrl: profilePictureUrl,
                contextId: logId,
                contextTitle: log.title,
                contextSubtitle: log.artistName,
                contextImageUrl: log.artworkUrl
            )
            
            try await saveNotification(notification, toUserId: logOwnerId, groupedUserIds: [currentUserId])
            print("✅ Dislike notification created")
        } catch {
            print("❌ Error creating dislike notification: \(error)")
        }
    }
    
    /// Create a mention notification (in comment, reply, or caption)
    func createMentionNotification(mentionedUserId: String, contentType: String, contentId: String, logId: String, log: MusicLog, mentionText: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != mentionedUserId else { return }
        
        do {
            // Get current user info
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            let username = userDoc.data()?["username"] as? String ?? "Someone"
            let displayName = userDoc.data()?["displayName"] as? String ?? username
            let profilePictureUrl = userDoc.data()?["profilePictureUrl"] as? String
            
            // Truncate mention text
            let maxLength = 100
            let truncatedText = mentionText.count > maxLength ? 
                String(mentionText.prefix(maxLength)) + "..." : mentionText
            
        let notification = AppNotification(
                type: .userMentioned,
                fromUserId: currentUserId,
                fromUserName: displayName,
                fromUserUsername: username,
                fromUserProfilePictureUrl: profilePictureUrl,
                contextId: contentId, // commentId or logId
                contextTitle: log.title,
                contextSubtitle: log.artistName,
                contextImageUrl: log.artworkUrl,
                message: truncatedText
            )
            
            try await saveNotification(notification, toUserId: mentionedUserId)
            print("✅ Mention notification created")
        } catch {
            print("❌ Error creating mention notification: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func createGroupedDisplayText(userIds: [String], action: String) async -> String {
        do {
            var usernames: [String] = []
            for userId in userIds.prefix(3) { // Only get first 3
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let username = userDoc.data()?["username"] as? String {
                    usernames.append(username)
                }
            }
            
            if userIds.count == 1 {
                return usernames.first ?? "Someone"
            } else if userIds.count == 2 {
                return "\(usernames[0]) and \(usernames[1])"
            } else if userIds.count == 3 {
                return "\(usernames[0]), \(usernames[1]), and \(usernames[2])"
            } else {
                let othersCount = userIds.count - 2
                return "\(usernames[0]), \(usernames[1]), and \(othersCount) \(othersCount == 1 ? "other" : "others")"
                }
        } catch {
            return "Multiple users"
        }
    }
    
    private func saveNotification(_ notification: AppNotification, toUserId: String, groupedUserIds: [String]? = nil) async throws {
        print("💾 [NotificationService] Saving notification...")
        print("   Type: \(notification.type.rawValue)")
        print("   To User: \(toUserId)")
        print("   From User: \(notification.fromUserId ?? "nil")")
        
        var data: [String: Any] = [
            "type": notification.type.rawValue,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false,
            "fromUserId": notification.fromUserId ?? "",
            "fromUserName": notification.fromUserName ?? "",
            "fromUserUsername": notification.fromUserUsername ?? "",
        ]
        
        if let profilePictureUrl = notification.fromUserProfilePictureUrl {
            data["fromUserProfilePictureUrl"] = profilePictureUrl
        }
        
        if let contextId = notification.contextId {
            data["contextId"] = contextId
        }
        
        if let contextTitle = notification.contextTitle {
            data["contextTitle"] = contextTitle
        }
        
        if let contextSubtitle = notification.contextSubtitle {
            data["contextSubtitle"] = contextSubtitle
        }
        
        if let contextImageUrl = notification.contextImageUrl {
            data["contextImageUrl"] = contextImageUrl
        }
        
        if let message = notification.message {
            data["message"] = message
        }
        
        if let groupedUserIds = groupedUserIds {
            data["groupedUserIds"] = groupedUserIds
        }
        
        let path = "users/\(toUserId)/notifications"
        print("   Writing to path: \(path)")
        
        do {
            try await db.collection("users")
                .document(toUserId)
                .collection("notifications")
                .addDocument(data: data)
            print("✅ [NotificationService] Successfully saved notification!")
        } catch {
            print("❌ [NotificationService] FAILED to save notification!")
            print("   Error: \(error)")
            print("   Error description: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Mark as Read/Delete
    
    func markAsRead(notificationId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users")
                .document(currentUserId)
                .collection("notifications")
                .document(notificationId)
                .updateData(["isRead": true])
        } catch {
            print("❌ Error marking notification as read: \(error)")
        }
    }
    
    func markAllAsRead() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("notifications")
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.updateData(["isRead": true])
            }
            
            unreadCount = 0
            print("✅ All notifications marked as read")
        } catch {
            print("❌ Error marking all notifications as read: \(error)")
        }
    }
    
    func deleteNotification(notificationId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users")
                .document(currentUserId)
                .collection("notifications")
                .document(notificationId)
                .delete()
            
            print("✅ Notification deleted")
        } catch {
            print("❌ Error deleting notification: \(error)")
        }
    }
    
    func deleteAllNotifications() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("notifications")
                .getDocuments()
            
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
            
            print("✅ All notifications deleted")
        } catch {
            print("❌ Error deleting all notifications: \(error)")
        }
    }
    
    // MARK: - Fetch & Group Notifications
    
    /// Fetch all notifications for the current user
    func fetchNotifications() async -> [AppNotification] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }
        
        do {
            let snapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("notifications")
                .order(by: "timestamp", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let notifications = snapshot.documents.compactMap { doc -> AppNotification? in
                try? doc.data(as: AppNotification.self)
            }
            
            return notifications
        } catch {
            print("❌ Error fetching notifications: \(error)")
            return []
        }
    }
    
    /// Group notifications by type and context (e.g., all likes on the same log)
    func groupNotifications(_ notifications: [AppNotification]) -> [GroupedNotification] {
        var grouped: [String: [AppNotification]] = [:]
        
        // Group notifications that can be grouped (likes, reposts, dislikes)
        let groupableTypes: [NotificationType] = [.musicLogLiked, .musicLogReposted, .musicLogDisliked]
        
        for notification in notifications {
            if groupableTypes.contains(notification.type), let contextId = notification.contextId {
                let groupKey = "\(notification.type.rawValue)_\(contextId)"
                grouped[groupKey, default: []].append(notification)
            }
        }
        
        // Create grouped notifications from groups with more than 1 notification
        return grouped.compactMap { key, notifs -> GroupedNotification? in
            guard notifs.count > 1,
                  let firstNotif = notifs.first else { return nil }
            
            return GroupedNotification(
                type: firstNotif.type,
                contextId: firstNotif.contextId ?? "",
                contextTitle: firstNotif.contextTitle,
                contextSubtitle: firstNotif.contextSubtitle,
                contextImageUrl: firstNotif.contextImageUrl,
                notifications: notifs
            )
        }.sorted { $0.latestTimestamp > $1.latestTimestamp }
    }
    
    /// Get ungrouped notifications (single notifications + comments/follows/mentions)
    func getUngroupedNotifications(_ notifications: [AppNotification]) -> [AppNotification] {
        let groupableTypes: [NotificationType] = [.musicLogLiked, .musicLogReposted, .musicLogDisliked]
        
        // Group by type and contextId
        var grouped: [String: [AppNotification]] = [:]
        for notification in notifications {
            if groupableTypes.contains(notification.type), let contextId = notification.contextId {
                let groupKey = "\(notification.type.rawValue)_\(contextId)"
                grouped[groupKey, default: []].append(notification)
            }
        }
        
        // Return only notifications that:
        // 1. Are not groupable types (comments, follows, mentions)
        // 2. Are groupable types but only have 1 notification in their group
        return notifications.filter { notification in
            if groupableTypes.contains(notification.type), let contextId = notification.contextId {
                let groupKey = "\(notification.type.rawValue)_\(contextId)"
                return grouped[groupKey]?.count == 1
            }
            return true // Not a groupable type, so include it
        }
    }
}
