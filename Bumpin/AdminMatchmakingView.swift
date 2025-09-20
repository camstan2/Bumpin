import SwiftUI
import FirebaseAuth

struct AdminMatchmakingView: View {
    @StateObject private var adminService = MatchmakingAdminService()
    @State private var selectedTab: AdminTab = .overview
    @State private var showManualTest = false
    @State private var showUserManagement = false
    @State private var showSystemLogs = false
    @State private var showAnalytics = false
    
    enum AdminTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case matches = "Matches"
        case users = "Users"
        case testing = "Testing"
        case logs = "Logs"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .matches: return "heart.fill"
            case .users: return "person.2.fill"
            case .testing: return "wrench.and.screwdriver.fill"
            case .logs: return "doc.text.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Admin header
                adminHeader
                
                // Tab selector
                tabSelector
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .matches:
                            matchesContent
                        case .users:
                            usersContent
                        case .testing:
                            testingContent
                        case .logs:
                            logsContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Matchmaking Admin")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showManualTest = true }) {
                            Label("Manual Test", systemImage: "play.circle")
                        }
                        
                        Button(action: { showUserManagement = true }) {
                            Label("User Management", systemImage: "person.crop.circle.badge.plus")
                        }
                        
                        Button(action: { showAnalytics = true }) {
                            Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            Task { await adminService.loadAllData() }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $showManualTest) {
            ManualTestingView(adminService: adminService)
        }
        .sheet(isPresented: $showUserManagement) {
            UserManagementView(adminService: adminService)
        }
        .sheet(isPresented: $showAnalytics) {
            MatchmakingAnalyticsView(adminService: adminService)
        }
        .alert("Error", isPresented: $adminService.showError) {
            Button("OK") { }
        } message: {
            Text(adminService.errorMessage ?? "Unknown error occurred")
        }
        .onAppear {
            if adminService.isAdmin {
                Task { await adminService.loadAllData() }
            }
        }
    }
    
    // MARK: - Admin Header
    
    private var adminHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Music Matchmaking System")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Administrative Dashboard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // System health indicator
                systemHealthIndicator
            }
            
            // Quick stats
            quickStatsRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    private var systemHealthIndicator: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(adminService.systemHealthStatus.color)
                .frame(width: 12, height: 12)
            
            Text(adminService.systemHealthStatus.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(adminService.systemHealthStatus.color)
        }
    }
    
    private var quickStatsRow: some View {
        HStack(spacing: 16) {
            QuickStatItem(
                title: "Active Users",
                value: "\(adminService.totalOptedInUsers)",
                icon: "person.2.fill",
                color: .blue
            )
            
            QuickStatItem(
                title: "Weekly Matches",
                value: "\(adminService.weeklyMatchesCount)",
                icon: "heart.fill",
                color: .purple
            )
            
            QuickStatItem(
                title: "Conversations",
                value: "\(adminService.totalConversationsStarted)",
                icon: "message.fill",
                color: .green
            )
            
            QuickStatItem(
                title: "Response Rate",
                value: String(format: "%.0f%%", adminService.averageResponseRate * 100),
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdminTab.allCases) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // System metrics
            SystemMetricsCard(adminService: adminService)
            
            // Recent activity
            RecentActivityCard(adminService: adminService)
            
            // Quick actions
            QuickActionsCard(adminService: adminService)
        }
    }
    
    @ViewBuilder
    private var matchesContent: some View {
        VStack(spacing: 16) {
            // Match statistics
            MatchStatisticsCard(adminService: adminService)
            
            // Recent matches list
            RecentMatchesList(adminService: adminService)
        }
    }
    
    @ViewBuilder
    private var usersContent: some View {
        VStack(spacing: 16) {
            // User statistics
            UserStatisticsCard(adminService: adminService)
            
            // Active users list
            ActiveUsersList(adminService: adminService)
        }
    }
    
    @ViewBuilder
    private var testingContent: some View {
        VStack(spacing: 16) {
            // Testing controls
            TestingControlsCard(adminService: adminService)
            
            // Test results
            TestResultsList(adminService: adminService)
        }
    }
    
    @ViewBuilder
    private var logsContent: some View {
        VStack(spacing: 16) {
            // System logs
            SystemLogsCard(adminService: adminService)
            
            // Execution history
            ExecutionHistoryList(adminService: adminService)
        }
    }
}

// MARK: - Supporting Components

struct QuickStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TabButton: View {
    let tab: AdminMatchmakingView.AdminTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)
                
                Text(tab.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.purple : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Content Cards

struct SystemMetricsCard: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("System Metrics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricItem(
                    title: "Total Users",
                    value: "\(adminService.totalOptedInUsers)",
                    subtitle: "Opted into matchmaking",
                    color: .blue
                )
                
                MetricItem(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", adminService.averageResponseRate * 100),
                    subtitle: "Users who respond",
                    color: .green
                )
                
                MetricItem(
                    title: "Weekly Matches",
                    value: "\(adminService.weeklyMatchesCount)",
                    subtitle: "Last 4 weeks",
                    color: .purple
                )
                
                MetricItem(
                    title: "Conversations",
                    value: "\(adminService.totalConversationsStarted)",
                    subtitle: "From matches",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MetricItem: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct RecentActivityCard: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if adminService.recentMatches.isEmpty {
                Text("No recent matches")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(adminService.recentMatches.prefix(5), id: \.id) { match in
                    RecentMatchRow(match: match)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecentMatchRow: View {
    let match: WeeklyMatch
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(match.userResponded ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Match created")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(Int(match.similarityScore * 100))% similarity")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(match.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct QuickActionsCard: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 8) {
                Button(action: {
                    Task { await adminService.runManualMatchmaking() }
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Run Manual Matchmaking")
                        Spacer()
                        if adminService.isRunningTest {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(adminService.isRunningTest)
                
                Button(action: {
                    Task { await adminService.loadAllData() }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh All Data")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Views for Additional Sheets

struct ManualTestingView: View {
    @ObservedObject var adminService: MatchmakingAdminService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Manual Testing Interface")
                    .font(.title2)
                
                // TODO: Implement manual testing controls
                
                Spacer()
            }
            .padding()
            .navigationTitle("Manual Testing")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct UserManagementView: View {
    @ObservedObject var adminService: MatchmakingAdminService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("User Management Interface")
                    .font(.title2)
                
                // TODO: Implement user management tools
                
                Spacer()
            }
            .padding()
            .navigationTitle("User Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MatchmakingAnalyticsView: View {
    @ObservedObject var adminService: MatchmakingAdminService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Analytics Dashboard")
                    .font(.title2)
                
                // TODO: Implement analytics charts and insights
                
                Spacer()
            }
            .padding()
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Additional Content Views (Stubs)

struct MatchStatisticsCard: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack {
            Text("Match Statistics")
                .font(.headline)
            // TODO: Implement match statistics
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecentMatchesList: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack {
            Text("Recent Matches")
                .font(.headline)
            // TODO: Implement recent matches list
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct UserStatisticsCard: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack {
            Text("User Statistics")
                .font(.headline)
            // TODO: Implement user statistics
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ActiveUsersList: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack {
            Text("Active Users")
                .font(.headline)
            // TODO: Implement active users list
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TestingControlsCard: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack {
            Text("Testing Controls")
                .font(.headline)
            // TODO: Implement testing controls
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TestResultsList: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack {
            Text("Test Results")
                .font(.headline)
            // TODO: Implement test results list
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SystemLogsCard: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack {
            Text("System Logs")
                .font(.headline)
            // TODO: Implement system logs
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ExecutionHistoryList: View {
    @ObservedObject var adminService: MatchmakingAdminService
    
    var body: some View {
        VStack {
            Text("Execution History")
                .font(.headline)
            // TODO: Implement execution history
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    AdminMatchmakingView()
}
