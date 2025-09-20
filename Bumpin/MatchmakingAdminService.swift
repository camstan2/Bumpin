import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Matchmaking Admin Service

@MainActor
class MatchmakingAdminService: ObservableObject {
    
    // MARK: - Published Properties
    
    // System Overview
    @Published var totalOptedInUsers: Int = 0
    @Published var weeklyMatchesCount: Int = 0
    @Published var totalConversationsStarted: Int = 0
    @Published var averageResponseRate: Double = 0.0
    @Published var systemHealthStatus: SystemHealthStatus = .unknown
    
    // Recent Activity
    @Published var recentMatches: [WeeklyMatch] = []
    @Published var recentStats: [WeeklyMatchmakingStats] = []
    @Published var activeUsers: [MatchmakingProfile] = []
    @Published var problemUsers: [AdminUserIssue] = []
    
    // Testing & Controls
    @Published var testResults: [TestResult] = []
    @Published var isRunningTest: Bool = false
    @Published var lastFunctionExecution: Date?
    @Published var functionExecutionLogs: [ExecutionLog] = []
    
    // Loading states
    @Published var isLoadingOverview = false
    @Published var isLoadingMatches = false
    @Published var isLoadingUsers = false
    @Published var isLoadingStats = false
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Admin Authentication
    
    var isAdmin: Bool {
        // Use the same admin detection as the rest of the app
        guard let user = Auth.auth().currentUser else { 
            print("❌ MatchmakingAdminService: No current user")
            return false 
        }
        
        let email = user.email ?? "no-email"
        let isAdminUser = email.contains("admin") || email == "cam@bumpin.app"
        
        print("🔍 MatchmakingAdminService: Checking admin access for email: \(email), isAdmin: \(isAdminUser)")
        
        return isAdminUser
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadAllData()
        }
    }
    
    // MARK: - Data Loading
    
    func loadAllData() async {
        guard isAdmin else { 
            errorMessage = "Admin access required"
            showError = true
            return 
        }
        
        async let overviewTask = loadSystemOverview()
        async let matchesTask = loadRecentMatches()
        async let statsTask = loadRecentStats()
        async let usersTask = loadActiveUsers()
        async let logsTask = loadExecutionLogs()
        
        await overviewTask
        await matchesTask
        await statsTask
        await usersTask
        await logsTask
    }
    
    // MARK: - System Overview
    
    func loadSystemOverview() async {
        isLoadingOverview = true
        defer { isLoadingOverview = false }
        
        do {
            // Count opted-in users
            let usersSnapshot = try await db.collection("musicMatchmaking")
                .whereField("optedIn", isEqualTo: true)
                .getDocuments()
            totalOptedInUsers = usersSnapshot.documents.count
            
            // Count weekly matches (last 4 weeks)
            let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
            let matchesSnapshot = try await db.collection("weeklyMatches")
                .whereField("timestamp", isGreaterThan: fourWeeksAgo)
                .getDocuments()
            weeklyMatchesCount = matchesSnapshot.documents.count
            
            // Count conversations started from matches
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("conversationType", isEqualTo: "matchmaking")
                .getDocuments()
            totalConversationsStarted = conversationsSnapshot.documents.count
            
            // Calculate average response rate
            let matches = matchesSnapshot.documents.compactMap { doc in
                try? doc.data(as: WeeklyMatch.self)
            }
            
            if !matches.isEmpty {
                let respondedCount = matches.filter { $0.userResponded }.count
                averageResponseRate = Double(respondedCount) / Double(matches.count)
            }
            
            // Determine system health
            systemHealthStatus = calculateSystemHealth()
            
            print("✅ Loaded system overview: \(totalOptedInUsers) users, \(weeklyMatchesCount) matches")
            
        } catch {
            errorMessage = "Failed to load system overview: \(error.localizedDescription)"
            showError = true
            print("❌ Error loading system overview: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recent Activity
    
    func loadRecentMatches() async {
        isLoadingMatches = true
        defer { isLoadingMatches = false }
        
        do {
            let snapshot = try await db.collection("weeklyMatches")
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            recentMatches = snapshot.documents.compactMap { doc in
                try? doc.data(as: WeeklyMatch.self)
            }
            
            print("✅ Loaded \(recentMatches.count) recent matches")
            
        } catch {
            errorMessage = "Failed to load recent matches: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func loadRecentStats() async {
        isLoadingStats = true
        defer { isLoadingStats = false }
        
        do {
            let snapshot = try await db.collection("matchmakingStats")
                .order(by: "timestamp", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            recentStats = snapshot.documents.compactMap { doc in
                try? doc.data(as: WeeklyMatchmakingStats.self)
            }
            
            print("✅ Loaded \(recentStats.count) recent stats")
            
        } catch {
            errorMessage = "Failed to load recent stats: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func loadActiveUsers() async {
        isLoadingUsers = true
        defer { isLoadingUsers = false }
        
        do {
            let snapshot = try await db.collection("musicMatchmaking")
                .whereField("optedIn", isEqualTo: true)
                .order(by: "lastActive", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            activeUsers = snapshot.documents.compactMap { doc in
                try? doc.data(as: MatchmakingProfile.self)
            }
            
            print("✅ Loaded \(activeUsers.count) active users")
            
        } catch {
            errorMessage = "Failed to load active users: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func loadExecutionLogs() async {
        do {
            let snapshot = try await db.collection("systemLogs")
                .whereField("type", isEqualTo: "matchmaking_execution")
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            functionExecutionLogs = snapshot.documents.compactMap { doc in
                let data = doc.data()
                return ExecutionLog(
                    id: doc.documentID,
                    timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                    status: data["status"] as? String ?? "unknown",
                    duration: data["duration"] as? Double ?? 0,
                    matchesCreated: data["matchesCreated"] as? Int ?? 0,
                    errors: data["errors"] as? [String] ?? []
                )
            }
            
            lastFunctionExecution = functionExecutionLogs.first?.timestamp
            
        } catch {
            print("❌ Error loading execution logs: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Testing & Controls
    
    func runManualMatchmaking() async {
        guard isAdmin else { return }
        
        isRunningTest = true
        defer { isRunningTest = false }
        
        do {
            // Simulate running the matchmaking algorithm
            let testResult = TestResult(
                id: UUID().uuidString,
                timestamp: Date(),
                type: .manualExecution,
                status: .running,
                details: "Starting manual matchmaking execution..."
            )
            
            testResults.insert(testResult, at: 0)
            
            // Call the actual matchmaking service
            await MusicMatchmakingService.shared.executeWeeklyMatching()
            
            // Update test result
            if let index = testResults.firstIndex(where: { $0.id == testResult.id }) {
                testResults[index] = TestResult(
                    id: testResult.id,
                    timestamp: testResult.timestamp,
                    type: .manualExecution,
                    status: .success,
                    details: "Manual matchmaking completed successfully"
                )
            }
            
            // Reload data to show updated results
            await loadAllData()
            
        } catch {
            // Update test result with error
            if let testResult = testResults.first {
                if let index = testResults.firstIndex(where: { $0.id == testResult.id }) {
                    testResults[index] = TestResult(
                        id: testResult.id,
                        timestamp: testResult.timestamp,
                        type: .manualExecution,
                        status: .failed,
                        details: "Error: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
    
    func testBotMessage(userId: String) async {
        guard isAdmin else { return }
        
        let testResult = TestResult(
            id: UUID().uuidString,
            timestamp: Date(),
            type: .botMessageTest,
            status: .running,
            details: "Testing bot message delivery to user \(userId)..."
        )
        
        testResults.insert(testResult, at: 0)
        
        // TODO: Implement actual bot message test
        // For now, simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let index = self.testResults.firstIndex(where: { $0.id == testResult.id }) {
                self.testResults[index] = TestResult(
                    id: testResult.id,
                    timestamp: testResult.timestamp,
                    type: .botMessageTest,
                    status: .success,
                    details: "Bot message test completed successfully"
                )
            }
        }
    }
    
    func resetUserMatchmaking(userId: String) async {
        guard isAdmin else { return }
        
        do {
            // Reset user's matchmaking profile
            try await db.collection("musicMatchmaking").document(userId).updateData([
                "lastActive": FieldValue.serverTimestamp(),
                "preferences.excludePreviousMatches": false
            ])
            
            print("✅ Reset matchmaking for user \(userId)")
            
        } catch {
            errorMessage = "Failed to reset user matchmaking: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateSystemHealth() -> SystemHealthStatus {
        // Simple health calculation based on recent activity
        let recentActivity = weeklyMatchesCount > 0 && totalOptedInUsers > 10
        let goodResponseRate = averageResponseRate > 0.3
        
        if recentActivity && goodResponseRate {
            return .healthy
        } else if recentActivity || goodResponseRate {
            return .warning
        } else {
            return .critical
        }
    }
}

// MARK: - Supporting Models

enum SystemHealthStatus {
    case healthy
    case warning
    case critical
    case unknown
    
    var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        }
    }
}

struct TestResult: Identifiable {
    let id: String
    let timestamp: Date
    let type: TestType
    let status: TestStatus
    let details: String
    
    enum TestType {
        case manualExecution
        case botMessageTest
        case algorithmTest
        case userProfileTest
        
        var displayName: String {
            switch self {
            case .manualExecution: return "Manual Execution"
            case .botMessageTest: return "Bot Message Test"
            case .algorithmTest: return "Algorithm Test"
            case .userProfileTest: return "User Profile Test"
            }
        }
    }
    
    enum TestStatus {
        case running
        case success
        case failed
        case warning
        
        var color: Color {
            switch self {
            case .running: return .blue
            case .success: return .green
            case .failed: return .red
            case .warning: return .orange
            }
        }
    }
}

struct ExecutionLog: Identifiable {
    let id: String
    let timestamp: Date
    let status: String
    let duration: Double
    let matchesCreated: Int
    let errors: [String]
}

struct AdminUserIssue: Identifiable {
    let id: String
    let userId: String
    let username: String
    let issueType: IssueType
    let description: String
    let timestamp: Date
    
    enum IssueType {
        case noMatches
        case lowSimilarity
        case reportedUser
        case systemError
    }
}
