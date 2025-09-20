import Foundation
import SwiftUI

// MARK: - Mock Notification Service

@MainActor
class MockNotificationService: ObservableObject {
    
    static let shared = MockNotificationService()
    
    @Published var mockNotifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    
    private init() {
        generateMockNotifications()
    }
    
    // MARK: - Mock Data Generation
    
    private func generateMockNotifications() {
        let currentTime = Date()
        
        mockNotifications = [
            // Recent notifications (last hour)
            AppNotification(
                type: .newFollower,
                timestamp: currentTime.addingTimeInterval(-300), // 5 minutes ago
                isRead: false,
                fromUserId: "user1",
                fromUserName: "Sarah Chen",
                fromUserUsername: "sarahc_music",
                fromUserProfilePictureUrl: nil
            ),
            
            AppNotification(
                type: .musicLogLiked,
                timestamp: currentTime.addingTimeInterval(-900), // 15 minutes ago
                isRead: false,
                fromUserId: "user2",
                fromUserName: "Marcus Johnson",
                fromUserUsername: "marcusj",
                fromUserProfilePictureUrl: nil,
                contextId: "log1",
                contextTitle: "Blinding Lights",
                contextSubtitle: "The Weeknd"
            ),
            
            AppNotification(
                type: .partyInvite,
                timestamp: currentTime.addingTimeInterval(-1800), // 30 minutes ago
                isRead: false,
                fromUserId: "user3",
                fromUserName: "Alex Rivera",
                fromUserUsername: "alexr",
                fromUserProfilePictureUrl: nil,
                contextId: "party1",
                contextTitle: "Friday Night Vibes 🎵",
                contextSubtitle: "5 friends listening"
            ),
            
            AppNotification(
                type: .musicLogCommented,
                timestamp: currentTime.addingTimeInterval(-2700), // 45 minutes ago
                isRead: true,
                fromUserId: "user4",
                fromUserName: "Emma Wilson",
                fromUserUsername: "emmaw",
                fromUserProfilePictureUrl: nil,
                contextId: "log2",
                contextTitle: "Good 4 U",
                contextSubtitle: "Olivia Rodrigo",
                message: "This song hits different! 🔥"
            ),
            
            // Today's notifications
            AppNotification(
                type: .friendStartedParty,
                timestamp: currentTime.addingTimeInterval(-7200), // 2 hours ago
                isRead: true,
                fromUserId: "user5",
                fromUserName: "David Kim",
                fromUserUsername: "davidk",
                fromUserProfilePictureUrl: nil,
                contextId: "party2",
                contextTitle: "Study Session Beats",
                contextSubtitle: "Lo-fi Hip Hop"
            ),
            
            AppNotification(
                type: .musicLogReposted,
                timestamp: currentTime.addingTimeInterval(-10800), // 3 hours ago
                isRead: true,
                fromUserId: "user6",
                fromUserName: "Zoe Martinez",
                fromUserUsername: "zoem",
                fromUserProfilePictureUrl: nil,
                contextId: "log3",
                contextTitle: "As It Was",
                contextSubtitle: "Harry Styles"
            ),
            
            AppNotification(
                type: .djStreamStarted,
                timestamp: currentTime.addingTimeInterval(-14400), // 4 hours ago
                isRead: true,
                fromUserId: "user7",
                fromUserName: "DJ Phoenix",
                fromUserUsername: "djphoenix",
                fromUserProfilePictureUrl: nil,
                contextId: "stream1",
                contextTitle: "Late Night Electronic Mix",
                contextSubtitle: "Live DJ Set"
            ),
            
            AppNotification(
                type: .promptResponseLiked,
                timestamp: currentTime.addingTimeInterval(-18000), // 5 hours ago
                isRead: true,
                fromUserId: "user8",
                fromUserName: "Riley Thompson",
                fromUserUsername: "rileyt",
                fromUserProfilePictureUrl: nil,
                contextId: "prompt1",
                contextTitle: "Song that makes you nostalgic",
                contextSubtitle: "Daily Prompt Response"
            ),
            
            // Yesterday's notifications
            AppNotification(
                type: .partyJoined,
                timestamp: currentTime.addingTimeInterval(-86400), // 1 day ago
                isRead: true,
                fromUserId: "user9",
                fromUserName: "Jordan Lee",
                fromUserUsername: "jordanl",
                fromUserProfilePictureUrl: nil,
                contextId: "party3",
                contextTitle: "Throwback Thursday",
                contextSubtitle: "8 friends joined"
            ),
            
            AppNotification(
                type: .newDailyPrompt,
                timestamp: currentTime.addingTimeInterval(-90000), // ~1 day ago
                isRead: true,
                fromUserId: nil,
                fromUserName: nil,
                fromUserUsername: nil,
                fromUserProfilePictureUrl: nil,
                contextId: "prompt2",
                contextTitle: "What's your current obsession?",
                contextSubtitle: nil,
                message: "Share the song you can't stop playing!"
            ),
            
            AppNotification(
                type: .followBack,
                timestamp: currentTime.addingTimeInterval(-93600), // ~1 day ago
                isRead: true,
                fromUserId: "user10",
                fromUserName: "Taylor Swift",
                fromUserUsername: "taylorswift13",
                fromUserProfilePictureUrl: nil
            ),
            
            // Older notifications
            AppNotification(
                type: .streakMilestone,
                timestamp: currentTime.addingTimeInterval(-172800), // 2 days ago
                isRead: true,
                fromUserId: nil,
                fromUserName: nil,
                fromUserUsername: nil,
                fromUserProfilePictureUrl: nil,
                contextId: nil,
                contextTitle: "7-Day Streak!",
                contextSubtitle: nil,
                message: "You've logged music for 7 days straight! 🔥"
            ),
            
            AppNotification(
                type: .friendJoinedApp,
                timestamp: currentTime.addingTimeInterval(-259200), // 3 days ago
                isRead: true,
                fromUserId: "user11",
                fromUserName: "Chris Anderson",
                fromUserUsername: "chrisa",
                fromUserProfilePictureUrl: nil
            ),
            
            AppNotification(
                type: .partySongAdded,
                timestamp: currentTime.addingTimeInterval(-345600), // 4 days ago
                isRead: true,
                fromUserId: "user12",
                fromUserName: "Maya Patel",
                fromUserUsername: "mayap",
                fromUserProfilePictureUrl: nil,
                contextId: "party4",
                contextTitle: "Weekend Playlist Party",
                contextSubtitle: "Anti-Hero - Taylor Swift"
            ),
            
            AppNotification(
                type: .followersmilestone,
                timestamp: currentTime.addingTimeInterval(-432000), // 5 days ago
                isRead: true,
                fromUserId: nil,
                fromUserName: nil,
                fromUserUsername: nil,
                fromUserProfilePictureUrl: nil,
                contextId: nil,
                contextTitle: "50 Followers!",
                contextSubtitle: nil,
                message: "Your music taste is inspiring others! 🎵"
            ),
            
            AppNotification(
                type: .userMentioned,
                timestamp: currentTime.addingTimeInterval(-518400), // 6 days ago
                isRead: true,
                fromUserId: "user13",
                fromUserName: "Kai Johnson",
                fromUserUsername: "kaij",
                fromUserProfilePictureUrl: nil,
                contextId: "log4",
                contextTitle: "Flowers",
                contextSubtitle: "Miley Cyrus",
                message: "@you would love this track!"
            ),
            
            AppNotification(
                type: .firstMusicLog,
                timestamp: currentTime.addingTimeInterval(-604800), // 7 days ago
                isRead: true,
                fromUserId: nil,
                fromUserName: nil,
                fromUserUsername: nil,
                fromUserProfilePictureUrl: nil,
                contextId: "log5",
                contextTitle: "Welcome to Bumpin!",
                contextSubtitle: nil,
                message: "Great job on your first music log! 🌟"
            )
        ]
        
        updateUnreadCount()
    }
    
    // MARK: - Helper Methods
    
    private func updateUnreadCount() {
        unreadCount = mockNotifications.filter { !$0.isRead }.count
    }
    
    func markAsRead(_ notification: AppNotification) {
        if let index = mockNotifications.firstIndex(where: { $0.id == notification.id }) {
            mockNotifications[index] = AppNotification(
                notificationId: notification.notificationId,
                type: notification.type,
                timestamp: notification.timestamp,
                isRead: true,
                fromUserId: notification.fromUserId,
                fromUserName: notification.fromUserName,
                fromUserUsername: notification.fromUserUsername,
                fromUserProfilePictureUrl: notification.fromUserProfilePictureUrl,
                contextId: notification.contextId,
                contextTitle: notification.contextTitle,
                contextSubtitle: notification.contextSubtitle,
                contextImageUrl: notification.contextImageUrl,
                message: notification.message
            )
            updateUnreadCount()
        }
    }
    
    func markAllAsRead() {
        mockNotifications = mockNotifications.map { notification in
            AppNotification(
                notificationId: notification.notificationId,
                type: notification.type,
                timestamp: notification.timestamp,
                isRead: true,
                fromUserId: notification.fromUserId,
                fromUserName: notification.fromUserName,
                fromUserUsername: notification.fromUserUsername,
                fromUserProfilePictureUrl: notification.fromUserProfilePictureUrl,
                contextId: notification.contextId,
                contextTitle: notification.contextTitle,
                contextSubtitle: notification.contextSubtitle,
                contextImageUrl: notification.contextImageUrl,
                message: notification.message
            )
        }
        updateUnreadCount()
    }
    
    func deleteNotification(_ notification: AppNotification) {
        mockNotifications.removeAll { $0.id == notification.id }
        updateUnreadCount()
    }
    
    // MARK: - Add New Mock Notifications (for testing)
    
    func addMockNotification(_ type: NotificationType) {
        let newNotification = AppNotification(
            type: type,
            timestamp: Date(),
            isRead: false,
            fromUserId: "test_user",
            fromUserName: "Test User",
            fromUserUsername: "testuser",
            contextTitle: "Test Content"
        )
        
        mockNotifications.insert(newNotification, at: 0)
        updateUnreadCount()
    }
}
