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

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case .social:
                    SocialFeedView()
                        .transition(.opacity)
                case .search:
                    ComprehensiveSearchView()
                        .transition(.opacity)
                case .party:
                    ContentView(authViewModel: authViewModel)
                        .transition(.opacity)
                case .discussion:
                    DiscussionView()
                        .transition(.opacity)
                case .notifications:
                    NotificationsView()
                        .transition(.opacity)
                case .profile:
                    UserProfileView(userId: nil)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .opacity(0.5)

            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            MainTabButton(icon: "flame", isSelected: selectedTab == .social) { selectedTab = .social }
            MainTabButton(icon: "magnifyingglass", isSelected: selectedTab == .search) { selectedTab = .search }
            MainTabButton(icon: "house", isSelected: selectedTab == .party) { selectedTab = .party }
            MainTabButton(icon: "text.bubble", isSelected: selectedTab == .discussion) { selectedTab = .discussion }
            MainTabButton(icon: "bell", isSelected: selectedTab == .notifications) { selectedTab = .notifications }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isSelected ? 22 : 20, weight: .semibold))
            .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


