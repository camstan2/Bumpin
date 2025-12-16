import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Enhanced Notifications View

// Wrapper to make String identifiable for navigation
private struct NavigableUserId: Identifiable {
    let id: String
}

@MainActor
struct NotificationsView: View {
    @State private var selectedTab = 0
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?
    @State private var showingDeleteAllAlert = false
    @EnvironmentObject var partyManager: PartyManager
    
    @StateObject private var notificationService = NotificationService.shared
    
    // DM Integration
    @State private var showMessages = false
    @StateObject private var dmUnreadService = DirectMessageUnreadService.shared
    @State private var showNewChatCreation = false
    
    // Navigation state
    @State private var selectedUserId: NavigableUserId?
    @State private var selectedLog: MusicLog?
    @State private var selectedGroupedNotification: GroupedNotification?
    
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
                Task {
                    await NotificationService.shared.markAllAsRead()
                }
            }
            .onDisappear {
                listener?.remove()
            }
            .refreshable {
                await refreshAllData()
            }
            .sheet(isPresented: $showNewChatCreation) {
                NewChatCreationView()
            }
            .fullScreenCover(item: $selectedUserId) { userId in
                UserProfileView(userId: userId.id, showFullProfile: false)
            }
            .fullScreenCover(item: $selectedLog) { log in
                UnifiedLogCommentsView(log: log)
            }
            .fullScreenCover(item: $selectedGroupedNotification) { grouped in
                NavigationStack {
                    GroupedNotificationsDetailView(groupedNotification: grouped)
                }
            }
            .alert("Clear All Notifications", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    Task {
                        await NotificationService.shared.deleteAllNotifications()
                        notifications = []
                    }
                }
            } message: {
                Text("Are you sure you want to delete all notifications? This action cannot be undone.")
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
                    if index == 0 {
                        Task {
                            await NotificationService.shared.markAllAsRead()
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Text(tab)
                                .font(.system(size: 16, weight: selectedTab == index ? .semibold : .medium))
                                .foregroundColor(selectedTab == index ? .primary : .secondary)
                            
                            // Unread badges
                            if index == 0 && notificationService.unreadCount > 0 {
                                Text("\(notificationService.unreadCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            } else if index == 1 && dmUnreadService.unreadConversationCount > 0 {
                                Text("\(dmUnreadService.unreadConversationCount)")
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
        .overlay(
            // Menu button for actions
            HStack {
                Spacer()
                if selectedTab == 0 && !notifications.isEmpty {
                    Menu {
                        if notificationService.unreadCount > 0 {
                            Button(action: {
                                Task {
                                    await NotificationService.shared.markAllAsRead()
                                }
                            }) {
                                Label("Mark All Read", systemImage: "envelope.open")
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            showingDeleteAllAlert = true
                        }) {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .padding(.trailing, 16)
                    }
                }
            }
        )
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
                // Show grouped notifications first
                let groupedNotifs = notificationService.groupNotifications(notifications)
                let ungroupedNotifs = notificationService.getUngroupedNotifications(notifications)
                
                ForEach(groupedNotifs) { grouped in
                    GroupedNotificationRow(
                        grouped: grouped,
                        onViewAll: {
                            print("🔵 [NotificationsView] View All tapped for grouped notification:")
                            print("   Type: \(grouped.type.rawValue)")
                            print("   Count: \(grouped.count)")
                            print("   ContextId: \(grouped.contextId)")
                            print("   ContextTitle: \(grouped.contextTitle ?? "nil")")
                            print("   ContextImageUrl: \(grouped.contextImageUrl ?? "nil")")
                            print("   Notifications in group: \(grouped.notifications.count)")
                            selectedGroupedNotification = grouped
                        },
                        onTap: { handleGroupedNotificationTap(grouped) },
                        onUsernameTap: { userId in
                            if let userId = userId {
                                navigateToUser(userId)
                            }
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 76)
                        .opacity(0.6)
                }
                
                // Then show individual notifications
                ForEach(ungroupedNotifs) { notification in
                    EnhancedNotificationRow(
                        notification: notification,
                        onTap: { handleNotificationTap(notification) },
                        onUsernameTap: { navigateToUser(notification.fromUserId) },
                        onDelete: { deleteNotification(notification) }
                    )
                    .onAppear {
                        if !notification.isRead {
                            Task {
                                await NotificationService.shared.markAsRead(notificationId: notification.notificationId)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.leading, 76)
                        .opacity(0.6)
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil
        
        // Set up real-time listener
        listener = Firestore.firestore()
            .collection("users")
            .document(currentUserId)
            .collection("notifications")
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [self] snapshot, error in
                isLoading = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    print("❌ Error loading notifications: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    notifications = []
                    return
                }
                
                notifications = documents.compactMap { doc -> AppNotification? in
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
                
                print("✅ Loaded \(notifications.count) notifications")
            }
    }
    private func refreshAllData() async {
        // Notifications are auto-refreshed via listener
        // DM badges update via DirectMessageUnreadService listeners
    }
    
    private func deleteNotification(_ notification: AppNotification) {
        Task {
            await NotificationService.shared.deleteNotification(notificationId: notification.notificationId)
            // Local state will update via listener
        }
    }
    
    // MARK: - Navigation Handlers
    
    private func navigateToUser(_ userId: String?) {
        guard let userId = userId else {
            print("❌ [NotificationsView] No userId provided")
            return
        }
        print("🔍 [NotificationsView] Navigating to user: \(userId)")
        selectedUserId = NavigableUserId(id: userId)
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        switch notification.type {
        case .newFollower, .followBack:
            // Navigate to user profile
            navigateToUser(notification.fromUserId)
            
        case .musicLogLiked, .musicLogReposted, .musicLogDisliked:
            // Navigate to log comments (shows the log with pinned comment section)
            if let logId = notification.contextId {
                fetchAndShowComments(logId: logId)
            }
            
        case .musicLogCommented, .userMentioned:
            // Navigate to comment section
            if let logId = notification.contextId {
                fetchAndShowComments(logId: logId)
            }
            
        case .partyInvite:
            if let partyId = notification.contextId {
                joinPartyFromNotification(partyId: partyId)
            }
            
        default:
            // For other types, just mark as read (already done on appear)
            break
        }
    }
    
    private func handleGroupedNotificationTap(_ grouped: GroupedNotification) {
        // When tapping on grouped notification (not "View All"), navigate to the log
        if let logId = grouped.contextId as String? {
            fetchAndShowComments(logId: logId)
        }
    }
    
    private func fetchAndShowComments(logId: String) {
        print("🔍 [NotificationsView] Fetching log: \(logId)")
        Task {
            let db = Firestore.firestore()
            do {
                let doc = try await db.collection("logs").document(logId).getDocument()
                if let log = try? doc.data(as: MusicLog.self) {
                    print("✅ [NotificationsView] Log fetched successfully: \(log.title)")
                    await MainActor.run {
                        self.selectedLog = log
                    }
                } else {
                    print("❌ [NotificationsView] Failed to decode log")
                }
            } catch {
                print("❌ [NotificationsView] Error fetching log: \(error)")
            }
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
        case .musicLogDisliked:
            return "\(notification.fromUserName ?? "Someone") disliked your review of \(notification.contextTitle ?? "a song")"
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

// MARK: - Enhanced Notification Row

struct EnhancedNotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void
    let onUsernameTap: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Left side: Icon or Artwork - larger and more prominent
                leftContent
                
                // Middle: Content
                VStack(alignment: .leading, spacing: 5) {
                    // Title with tappable purple username
                    notificationTitleView
                    
                    // Subtitle/Message (if any)
                    if let subtitle = notificationSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Time ago - more subtle
                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                // Right side: Unread indicator - slightly larger
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 9, height: 9)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(notification.isRead ? Color.clear : Color.blue.opacity(0.04))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Left Content (Icon or Artwork)
    
    @ViewBuilder
    private var leftContent: some View {
        if shouldShowArtwork, let artworkUrl = notification.contextImageUrl, let url = URL(string: artworkUrl) {
            // Show album/song artwork for log-related notifications - larger with shadow
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 56, height: 56)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        } else {
            // Show icon for other notifications - slightly larger
            Image(systemName: notification.type.icon)
                .font(.title2)
                .foregroundColor(notification.type.color)
                .frame(width: 56, height: 56)
                .background(notification.type.color.opacity(0.12))
                .clipShape(Circle())
        }
    }
    
    private var shouldShowArtwork: Bool {
        switch notification.type {
        case .musicLogLiked, .musicLogCommented, .musicLogReposted, .musicLogDisliked, .userMentioned:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Title with Tappable Username
    
    private var notificationTitleView: some View {
        let components = parseTitleText()
        
        return Text(buildAttributedTitle(components: components))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .onTapGesture {
                // Tap on username to view profile
                onUsernameTap()
            }
    }
    
    private func buildAttributedTitle(components: [TitleComponent]) -> AttributedString {
        var result = AttributedString()
        
        for component in components {
            switch component {
            case .text(let str):
                var attrStr = AttributedString(str)
                attrStr.font = .subheadline
                attrStr.foregroundColor = .primary
                if !notification.isRead {
                    attrStr.font = .subheadline.weight(.semibold)
                } else {
                    attrStr.font = .subheadline.weight(.medium)
                }
                result.append(attrStr)
            case .username(let username):
                var attrStr = AttributedString(username)
                attrStr.font = .subheadline.weight(.semibold)
                attrStr.foregroundColor = .purple
                result.append(attrStr)
            }
        }
        
        return result
    }
    
    private enum TitleComponent {
        case text(String)
        case username(String)
    }
    
    private func parseTitleText() -> [TitleComponent] {
        let titleText = notificationTitle
        
        guard let username = notification.fromUserName else {
            return [.text(titleText)]
        }
        
        // Split the title by the username to make it tappable
        let parts = titleText.components(separatedBy: username)
        
        if parts.count == 2 {
            var components: [TitleComponent] = []
            if !parts[0].isEmpty {
                components.append(.text(parts[0]))
            }
            components.append(.username(username))
            if !parts[1].isEmpty {
                components.append(.text(parts[1]))
            }
            return components
        } else {
            return [.text(titleText)]
        }
    }
    
    // MARK: - Notification Text
    
    private var notificationTitle: String {
        switch notification.type {
        case .newFollower:
            return "\(notification.fromUserName ?? "Someone") started following you"
        case .followBack:
            return "\(notification.fromUserName ?? "Someone") followed you back"
        case .musicLogLiked:
            return "\(notification.fromUserName ?? "Someone") liked your log for \(notification.contextTitle ?? "a song")"
        case .musicLogCommented:
            // NEW FORMAT: "User 2 commented on Die Lit" (shorter, cleaner)
            return "\(notification.fromUserName ?? "Someone") commented on \(notification.contextTitle ?? "a song")"
        case .musicLogReposted:
            return "\(notification.fromUserName ?? "Someone") reposted your log for \(notification.contextTitle ?? "a song")"
        case .musicLogDisliked:
            return "\(notification.fromUserName ?? "Someone") disliked your log for \(notification.contextTitle ?? "a song")"
        case .userMentioned:
            // NEW FORMAT: "User 2 mentioned you on Die Lit"
            return "\(notification.fromUserName ?? "Someone") mentioned you on \(notification.contextTitle ?? "a song")"
        case .commentReplied:
            return "\(notification.fromUserName ?? "Someone") replied to your comment"
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
        case .musicLogCommented, .userMentioned:
            // Show comment preview in quotes (NEW FORMAT)
            if let message = notification.message {
                return "\"\(message)\""
            }
            return nil
        case .musicLogLiked, .musicLogReposted, .musicLogDisliked:
            // Don't show subtitle for engagement notifications (cleaner look)
            return nil
        case .partyInvite, .partyJoined:
            return notification.contextSubtitle
        case .newMessage, .messageRequest:
            return notification.message
        default:
            return notification.contextSubtitle
        }
    }
    
    private var timeAgo: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notification.timestamp, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y ago"
        } else if let months = components.month, months > 0 {
            return "\(months)mo ago"
        } else if let days = components.day, days > 0 {
            if days == 1 {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: notification.timestamp)
            }
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "now"
        }
    }
}

// MARK: - Grouped Notification Row

struct GroupedNotificationRow: View {
    let grouped: GroupedNotification
    let onViewAll: () -> Void
    let onTap: () -> Void
    let onUsernameTap: (String?) -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Cover art - larger and more prominent
                if let imageUrl = grouped.contextImageUrl, let url = URL(string: imageUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title with count - more prominent
                    HStack(spacing: 5) {
                        Image(systemName: grouped.type.icon)
                            .foregroundColor(grouped.type.color)
                            .font(.system(size: 15, weight: .semibold))
                        
                        Text(groupedTitle)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    // Users who interacted
                    Text(usersText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Log info - slightly bolder
                    if let title = grouped.contextTitle {
                        Text(title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    // Time ago - slightly smaller and more subtle
                    Text(timeAgo(from: grouped.latestTimestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    // View All button - refined design
                    Button(action: { onViewAll() }) {
                        Text("View All")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.purple)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Unread indicator - slightly larger
                if grouped.hasUnread {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 9, height: 9)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(grouped.hasUnread ? Color.purple.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var groupedTitle: String {
        let count = grouped.count
        switch grouped.type {
        case .musicLogLiked:
            return "\(count) new \(count == 1 ? "like" : "likes")"
        case .musicLogReposted:
            return "\(count) new \(count == 1 ? "repost" : "reposts")"
        case .musicLogDisliked:
            return "\(count) new \(count == 1 ? "dislike" : "dislikes")"
        default:
            return "\(count) interactions"
        }
    }
    
    private var usersText: String {
        let users = grouped.notifications.prefix(3)
        let usernames = users.compactMap { $0.fromUserUsername }
        
        if usernames.isEmpty {
            return "from multiple users"
        } else if usernames.count == 1 {
            return "from @\(usernames[0])"
        } else if usernames.count == 2 {
            return "from @\(usernames[0]) and @\(usernames[1])"
        } else {
            let additionalCount = grouped.count - 2
            if additionalCount > 0 {
                return "from @\(usernames[0]), @\(usernames[1]), and \(additionalCount) \(additionalCount == 1 ? "other" : "others")"
            } else {
                return "from @\(usernames[0]), @\(usernames[1]), and @\(usernames[2])"
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            if day == 1 {
                return "Yesterday"
            } else if day < 7 {
                return "\(day)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
}

#Preview {
    NotificationsView()
        .environmentObject(PartyManager())
}
