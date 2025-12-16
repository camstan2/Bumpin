import SwiftUI

enum MainTab: Hashable {
    case social
    case search
    case party
    case discussion
    case notifications
    case profile
}

struct MainTabScaffold: View {
    let authViewModel: AuthViewModel
    @State private var selectedTab: MainTab = .social
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var dmUnreadService = DirectMessageUnreadService.shared
    
    // For navigating to song profiles from minimized preview indicator
    @State private var selectedMusicItem: MusicSearchResult?
    
    // STATE PRESERVATION: Keep tab views alive to prevent reloading
    @StateObject private var socialFeedViewModel = SocialFeedViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // STATE PRESERVATION: All views are kept in the hierarchy
                // Only the selected tab is visible and interactive
                
                SocialFeedView(viewModel: socialFeedViewModel)
                    .opacity(selectedTab == .social ? 1 : 0)
                    .allowsHitTesting(selectedTab == .social)
                
                ComprehensiveSearchView()
                    .opacity(selectedTab == .search ? 1 : 0)
                    .allowsHitTesting(selectedTab == .search)
                
                // FEATURE FLAG: Home tab (Parties)
                if FeatureFlags.showHomeTab {
                    ContentView(authViewModel: authViewModel)
                        .opacity(selectedTab == .party ? 1 : 0)
                        .allowsHitTesting(selectedTab == .party)
                }
                
                // FEATURE FLAG: Discussion tab
                if FeatureFlags.showDiscussionTab {
                    DiscussionView()
                        .opacity(selectedTab == .discussion ? 1 : 0)
                        .allowsHitTesting(selectedTab == .discussion)
                }
                
                NotificationsView()
                    .opacity(selectedTab == .notifications ? 1 : 0)
                    .allowsHitTesting(selectedTab == .notifications)
                
                UserProfileView(userId: nil)
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .opacity(0.5)

            CustomTabBar(selectedTab: $selectedTab,
                         notificationCount: notificationService.unreadCount,
                         dmCount: dmUnreadService.unreadConversationCount)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(item: $selectedMusicItem) { musicItem in
            MusicProfileView(musicItem: musicItem, pinnedLog: nil)
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .notifications {
                Task {
                    await notificationService.markAllAsRead()
                }
            }
        }
        .overlay(alignment: .top) {
            GlobalAlertBanner()
        }
        .onAppear {
            // Listen for navigation requests from minimized preview indicator
            NotificationCenter.default.addObserver(forName: NSNotification.Name("NavigateToSongProfile"), object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo,
                   let itemId = userInfo["itemId"] as? String {
                    print("📱 MainTabScaffold: Received navigation request for itemId: \(itemId)")
                    
                    // Get song info from preview service
                    let previewService = PreviewPlayerService.shared
                    let musicItem = MusicSearchResult(
                        id: itemId,
                        title: previewService.currentSongTitle ?? "Unknown",
                        artistName: previewService.currentArtistName ?? "Unknown",
                        albumName: "",
                        artworkURL: previewService.currentArtworkURL?.absoluteString,
                        itemType: "song",
                        popularity: 0
                    )
                    selectedMusicItem = musicItem
                }
            }
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    let notificationCount: Int
    let dmCount: Int
    
    var body: some View {
        HStack(spacing: 0) {
            MainTabButton(icon: "flame", isSelected: selectedTab == .social) { selectedTab = .social }
            MainTabButton(icon: "magnifyingglass", isSelected: selectedTab == .search) { selectedTab = .search }
            
            // FEATURE FLAG: Home tab button
            if FeatureFlags.showHomeTab {
                MainTabButton(icon: "house", isSelected: selectedTab == .party) { selectedTab = .party }
            }
            
            // FEATURE FLAG: Discussion tab button
            if FeatureFlags.showDiscussionTab {
                MainTabButton(icon: "text.bubble", isSelected: selectedTab == .discussion) { selectedTab = .discussion }
            }
            
            MainTabButton(icon: "bell",
                          isSelected: selectedTab == .notifications,
                          badgeCount: notificationCount,
                          secondaryDot: dmCount > 0) {
                selectedTab = .notifications
            }
            MainTabButton(icon: "person.crop.circle", isSelected: selectedTab == .profile) { selectedTab = .profile }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

private struct MainTabButton: View {
    let icon: String
    let isSelected: Bool
    var badgeCount: Int = 0
    var secondaryDot: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 22 : 20, weight: .semibold))
                    .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                
                // Badge
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, badgeCount > 9 ? 4 : 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: 6)
                }
                
                if secondaryDot {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 8, height: 8)
                        .offset(x: -12, y: 20)
                }
            }
        }
        .buttonStyle(.plain)
    }
}


