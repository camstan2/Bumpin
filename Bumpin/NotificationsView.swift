import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Enhanced Notifications View

@MainActor
struct NotificationsView: View {
    @State private var selectedTab = 0
    @State private var notifications: [AppNotification] = []
    @State private var unreadCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var partyManager: PartyManager
    
    // Mock service for development
    @StateObject private var mockService = MockNotificationService.shared
    
    // DM Integration
    @State private var showMessages = false
    @State private var dmUnreadCount: Int = 0
    @State private var showNewChatCreation = false
    
    private let tabs = ["Notifications", "Messages"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Tab Selector
                tabSelector
                
                // Content based on selected tab
                Group {
                    if selectedTab == 0 {
                        notificationsContent
                    } else {
                        messagesContent
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadNotifications()
                attachUnreadBadge()
            }
            .refreshable {
                await refreshAllData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == 0 && unreadCount > 0 {
                        Button("Mark All Read") {
                            markAllAsRead()
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showNewChatCreation) {
                NewChatCreationView()
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Text(tab)
                                .font(.system(size: 16, weight: selectedTab == index ? .semibold : .medium))
                                .foregroundColor(selectedTab == index ? .primary : .secondary)
                            
                            // Unread badges
                            if index == 0 && unreadCount > 0 {
                                Text("\(unreadCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            } else if index == 1 && dmUnreadCount > 0 {
                                Text("\(dmUnreadCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        // Active indicator
                        Rectangle()
                            .fill(selectedTab == index ? Color.purple : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Notifications Content
    
    private var notificationsContent: some View {
        Group {
            if isLoading {
                ProgressView("Loading notifications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notifications.isEmpty {
                emptyNotificationsView
            } else {
                notificationsList
            }
        }
    }
    
    private var emptyNotificationsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No notifications yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("You'll see notifications here when people interact with your content, invite you to parties, and more!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notifications) { notification in
                    NotificationRowView(notification: notification) {
                        handleNotificationTap(notification)
                    }
                    .onAppear {
                        if !notification.isRead {
                            markAsRead(notification)
                        }
                    }
                    
                    Divider()
                        .padding(.leading, 70)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Messages Content
    
    private var messagesContent: some View {
        ZStack {
            DMInboxView()
            
            // Floating Action Button for new chat
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    PlusFAB { 
                        showNewChatCreation = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .accessibilityLabel("Create new chat")
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadNotifications() {
        // Use mock service for development
        notifications = mockService.mockNotifications
        unreadCount = mockService.unreadCount
        
        // TODO: Replace with real Firebase implementation in production
        /*
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).collection("notifications")
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .getDocuments { snapshot, error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                
                if let docs = snapshot?.documents {
                    notifications = docs.compactMap { doc in
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
                    updateUnreadCount()
                } else {
                    notifications = []
                }
            }
        */
    }
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func attachUnreadBadge() {
        // Mock implementation for DM unread badge
        dmUnreadCount = 0 // This would be loaded from DirectMessageService
    }
    
    private func refreshAllData() async {
        loadNotifications()
        attachUnreadBadge()
    }
    
    private func markAsRead(_ notification: AppNotification) {
        // Use mock service for development
        mockService.markAsRead(notification)
        // Update local state from mock service
        notifications = mockService.mockNotifications
        unreadCount = mockService.unreadCount
        
        // TODO: Replace with real Firebase implementation in production
        /*
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).collection("notifications")
            .document(notification.notificationId)
            .updateData(["isRead": true]) { _ in
                // Update local state
                if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                    notifications[index] = AppNotification(
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
        */
    }
    
    private func markAllAsRead() {
        // Use mock service for development
        mockService.markAllAsRead()
        // Update local state from mock service
        notifications = mockService.mockNotifications
        unreadCount = mockService.unreadCount
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        // Handle different notification types
        switch notification.type {
        case .partyInvite:
            if let partyId = notification.contextId {
                joinPartyFromNotification(partyId: partyId)
            }
        case .newFollower:
            // Navigate to user profile
            break
        case .musicLogLiked, .musicLogCommented:
            // Navigate to music log
            break
        case .promptResponseLiked, .promptResponseCommented:
            // Navigate to prompt response
            break
        default:
            break
        }
    }
    
    private func joinPartyFromNotification(partyId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("parties").document(partyId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                if let name = data["name"] as? String,
                   let hostId = data["hostId"] as? String,
                   let hostName = data["hostName"] as? String {
                    var party = Party(name: name, hostId: hostId, hostName: hostName)
                    party.id = partyId
                    party.isActive = data["isActive"] as? Bool ?? true
                    NotificationCenter.default.post(name: NSNotification.Name("JoinParty"), object: party)
                }
            }
        }
    }
}

// MARK: - Notification Row View

struct NotificationRowView: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: notification.type.icon)
                    .font(.title2)
                    .foregroundColor(notification.type.color)
                    .frame(width: 40, height: 40)
                    .background(notification.type.color.opacity(0.1))
                    .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(notificationTitle)
                        .font(.subheadline)
                        .fontWeight(notification.isRead ? .medium : .semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = notificationSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(notification.isRead ? Color.clear : Color.blue.opacity(0.03))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var notificationTitle: String {
        switch notification.type {
        case .newFollower:
            return "\(notification.fromUserName ?? "Someone") started following you"
        case .followBack:
            return "\(notification.fromUserName ?? "Someone") followed you back"
        case .musicLogLiked:
            return "\(notification.fromUserName ?? "Someone") liked your review of \(notification.contextTitle ?? "a song")"
        case .musicLogCommented:
            return "\(notification.fromUserName ?? "Someone") commented on your review of \(notification.contextTitle ?? "a song")"
        case .musicLogReposted:
            return "\(notification.fromUserName ?? "Someone") reposted your review of \(notification.contextTitle ?? "a song")"
        case .commentReplied:
            return "\(notification.fromUserName ?? "Someone") replied to your comment"
        case .userMentioned:
            return "\(notification.fromUserName ?? "Someone") mentioned you in a comment"
        case .friendJoinedApp:
            return "\(notification.fromUserName ?? "Someone") joined Bumpin!"
        case .partyInvite:
            return "\(notification.fromUserName ?? "Someone") invited you to \(notification.contextTitle ?? "a party")"
        case .partyJoined:
            return "\(notification.fromUserName ?? "Someone") joined your party \(notification.contextTitle ?? "")"
        case .friendStartedParty:
            return "\(notification.fromUserName ?? "Someone") started a party: \(notification.contextTitle ?? "")"
        case .partyEnded:
            return "Party \(notification.contextTitle ?? "") has ended"
        case .partyHostChanged:
            return "\(notification.fromUserName ?? "Someone") is now hosting \(notification.contextTitle ?? "the party")"
        case .partySongAdded:
            return "\(notification.fromUserName ?? "Someone") added \(notification.contextSubtitle ?? "a song") to \(notification.contextTitle ?? "the party")"
        case .newDailyPrompt:
            return "New daily prompt: \(notification.contextTitle ?? "Check it out!")"
        case .promptResponseLiked:
            return "\(notification.fromUserName ?? "Someone") liked your response to today's prompt"
        case .promptResponseCommented:
            return "\(notification.fromUserName ?? "Someone") commented on your prompt response"
        case .promptLeaderboard:
            return "You're on today's prompt leaderboard! 🏆"
        case .friendCompletedPrompt:
            return "\(notification.fromUserName ?? "Someone") completed today's prompt"
        case .djStreamStarted:
            return "\(notification.fromUserName ?? "Someone") started a DJ stream: \(notification.contextTitle ?? "")"
        case .djStreamLive:
            return "\(notification.fromUserName ?? "Someone") is now live streaming!"
        case .djStreamEnded:
            return "\(notification.fromUserName ?? "Someone")'s stream has ended"
        case .newMessage:
            return "New message from \(notification.fromUserName ?? "someone")"
        case .messageRequest:
            return "Message request from \(notification.fromUserName ?? "someone")"
        case .firstMusicLog:
            return "Welcome to Bumpin! 🎵"
        case .streakMilestone:
            return "\(notification.contextTitle ?? "Streak milestone achieved!")"
        case .followersmilestone:
            return "\(notification.contextTitle ?? "Follower milestone reached!")"
        case .appUpdate:
            return "App update available"
        case .featureAnnouncement:
            return notification.contextTitle ?? "New feature announcement"
        case .maintenance:
            return "Scheduled maintenance notice"
        }
    }
    
    private var notificationSubtitle: String? {
        switch notification.type {
        case .musicLogLiked, .musicLogCommented:
            return notification.contextSubtitle // Artist name
        case .partyInvite, .partyJoined:
            return notification.contextSubtitle // Party description or member count
        case .newMessage, .messageRequest:
            return notification.message // Message preview
        default:
            return notification.contextSubtitle
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.timestamp, relativeTo: Date())
    }
}

#Preview {
    NotificationsView()
        .environmentObject(PartyManager())
}
