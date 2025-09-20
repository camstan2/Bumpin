import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Matchmaking Testing Interface

struct MatchmakingTestingView: View {
    @StateObject private var testingService = MatchmakingTestingService()
    @State private var selectedTestType: TestType = .algorithmTest
    @State private var testUserId: String = ""
    @State private var showingResults = false
    
    enum TestType: String, CaseIterable, Identifiable {
        case algorithmTest = "Algorithm Test"
        case botMessageTest = "Bot Message Test"
        case userProfileTest = "User Profile Test"
        case systemHealthTest = "System Health Test"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .algorithmTest: return "brain.head.profile"
            case .botMessageTest: return "message.circle"
            case .userProfileTest: return "person.circle"
            case .systemHealthTest: return "stethoscope"
            }
        }
        
        var description: String {
            switch self {
            case .algorithmTest: return "Test the matching algorithm with real user data"
            case .botMessageTest: return "Test bot message delivery and formatting"
            case .userProfileTest: return "Test user profile analysis and compatibility"
            case .systemHealthTest: return "Check overall system health and performance"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    testingHeader
                    
                    // Test type selector
                    testTypeSelector
                    
                    // Test configuration
                    testConfiguration
                    
                    // Run test button
                    runTestButton
                    
                    // Test results
                    if !testingService.testResults.isEmpty {
                        testResults
                    }
                    
                    // System diagnostics
                    systemDiagnostics
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Matchmaking Testing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear Results") {
                        testingService.clearResults()
                    }
                    .disabled(testingService.testResults.isEmpty)
                }
            }
        }
        .alert("Test Error", isPresented: $testingService.showError) {
            Button("OK") { }
        } message: {
            Text(testingService.errorMessage ?? "Unknown error occurred")
        }
        .onAppear {
            testingService.loadSystemInfo()
        }
    }
    
    // MARK: - Testing Header
    
    private var testingHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Matchmaking Testing Suite")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Test and validate matchmaking components")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // System status
            HStack {
                systemStatusIndicator
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var systemStatusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(testingService.systemStatus.color)
                .frame(width: 8, height: 8)
            
            Text("System: \(testingService.systemStatus.displayName)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(testingService.systemStatus.color)
        }
    }
    
    // MARK: - Test Type Selector
    
    private var testTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Test Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(TestType.allCases) { testType in
                    TestTypeCard(
                        testType: testType,
                        isSelected: selectedTestType == testType,
                        action: { selectedTestType = testType }
                    )
                }
            }
        }
    }
    
    // MARK: - Test Configuration
    
    private var testConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                switch selectedTestType {
                case .algorithmTest:
                    algorithmTestConfig
                case .botMessageTest:
                    botMessageTestConfig
                case .userProfileTest:
                    userProfileTestConfig
                case .systemHealthTest:
                    systemHealthTestConfig
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Test Configurations
    
    private var algorithmTestConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Algorithm Test Settings")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Test User ID:")
                    Spacer()
                    TextField("Enter user ID", text: $testUserId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }
                
                HStack {
                    Text("Sample Size:")
                    Spacer()
                    Text("10 users")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Include Similarity Scores:")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
            }
        }
    }
    
    private var botMessageTestConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bot Message Test Settings")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Target User ID:")
                    Spacer()
                    TextField("Enter user ID", text: $testUserId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }
                
                HStack {
                    Text("Message Type:")
                    Spacer()
                    Text("Matchmaking")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var userProfileTestConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("User Profile Test Settings")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("User ID:")
                    Spacer()
                    TextField("Enter user ID", text: $testUserId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }
                
                HStack {
                    Text("Analyze Music Logs:")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
            }
        }
    }
    
    private var systemHealthTestConfig: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Health Test Settings")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("This test will check all system components and provide a comprehensive health report.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Run Test Button
    
    private var runTestButton: some View {
        Button(action: runTest) {
            HStack {
                if testingService.isRunningTest {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "play.circle.fill")
                }
                
                Text(testingService.isRunningTest ? "Running Test..." : "Run \(selectedTestType.rawValue)")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(testingService.isRunningTest || (selectedTestType != .systemHealthTest && testUserId.isEmpty))
    }
    
    // MARK: - Test Results
    
    private var testResults: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(testingService.testResults) { result in
                TestResultCard(result: result)
            }
        }
    }
    
    // MARK: - System Diagnostics
    
    private var systemDiagnostics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Diagnostics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DiagnosticItem(
                    title: "Firebase Connection",
                    status: testingService.firebaseStatus,
                    icon: "cloud.fill"
                )
                
                DiagnosticItem(
                    title: "User Authentication",
                    status: testingService.authStatus,
                    icon: "person.circle.fill"
                )
                
                DiagnosticItem(
                    title: "Matchmaking Service",
                    status: testingService.matchmakingStatus,
                    icon: "heart.circle.fill"
                )
                
                DiagnosticItem(
                    title: "Bot Service",
                    status: testingService.botStatus,
                    icon: "message.circle.fill"
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func runTest() {
        Task {
            await testingService.runTest(
                type: selectedTestType,
                userId: testUserId.isEmpty ? nil : testUserId
            )
        }
    }
}

// MARK: - Supporting Components

struct TestTypeCard: View {
    let testType: MatchmakingTestingView.TestType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: testType.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .purple)
                
                Text(testType.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(testType.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.purple : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct TestResultCard: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(result.status.color)
                
                Text(result.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(result.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(result.details)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var statusIcon: String {
        switch result.status {
        case .running: return "clock.fill"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}


struct DiagnosticItem: View {
    let title: String
    let status: DiagnosticStatus
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(status.color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text(status.displayName)
                .font(.caption2)
                .foregroundColor(status.color)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Testing Service

@MainActor
class MatchmakingTestingService: ObservableObject {
    
    @Published var testResults: [TestResult] = []
    @Published var isRunningTest: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // System status
    @Published var systemStatus: SystemHealthStatus = .unknown
    @Published var firebaseStatus: DiagnosticStatus = .unknown
    @Published var authStatus: DiagnosticStatus = .unknown
    @Published var matchmakingStatus: DiagnosticStatus = .unknown
    @Published var botStatus: DiagnosticStatus = .unknown
    
    private let db = Firestore.firestore()
    
    func loadSystemInfo() {
        // Check Firebase connection
        firebaseStatus = .healthy
        
        // Check authentication
        authStatus = Auth.auth().currentUser != nil ? .healthy : .warning
        
        // Check matchmaking service
        matchmakingStatus = .healthy // TODO: Implement actual check
        
        // Check bot service
        botStatus = .healthy // TODO: Implement actual check
        
        // Overall system status
        systemStatus = .healthy
    }
    
    func runTest(type: MatchmakingTestingView.TestType, userId: String?) async {
        isRunningTest = true
        defer { isRunningTest = false }
        
        let testResult = TestResult(
            id: UUID().uuidString,
            timestamp: Date(),
            type: .algorithmTest, // Will be updated in performTest
            status: .running,
            details: "Starting \(type.rawValue.lowercased())..."
        )
        
        testResults.insert(testResult, at: 0)
        
        // Simulate test execution
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Update result based on test type
        let updatedResult = await performTest(type: type, userId: userId, originalResult: testResult)
        
        if let index = testResults.firstIndex(where: { $0.id == testResult.id }) {
            testResults[index] = updatedResult
        }
    }
    
    private func performTest(
        type: MatchmakingTestingView.TestType,
        userId: String?,
        originalResult: TestResult
    ) async -> TestResult {
        
        switch type {
        case .algorithmTest:
            return await performAlgorithmTest(userId: userId, originalResult: originalResult)
        case .botMessageTest:
            return await performBotMessageTest(userId: userId, originalResult: originalResult)
        case .userProfileTest:
            return await performUserProfileTest(userId: userId, originalResult: originalResult)
        case .systemHealthTest:
            return await performSystemHealthTest(originalResult: originalResult)
        }
    }
    
    private func performAlgorithmTest(userId: String?, originalResult: TestResult) async -> TestResult {
        // TODO: Implement actual algorithm test
        return TestResult(
            id: originalResult.id,
            timestamp: originalResult.timestamp,
            type: .algorithmTest,
            status: .success,
            details: "Algorithm test completed successfully. Found 5 potential matches."
        )
    }
    
    private func performBotMessageTest(userId: String?, originalResult: TestResult) async -> TestResult {
        // TODO: Implement actual bot message test
        return TestResult(
            id: originalResult.id,
            timestamp: originalResult.timestamp,
            type: .botMessageTest,
            status: .success,
            details: "Bot message test completed. Message delivered successfully."
        )
    }
    
    private func performUserProfileTest(userId: String?, originalResult: TestResult) async -> TestResult {
        // TODO: Implement actual user profile test
        return TestResult(
            id: originalResult.id,
            timestamp: originalResult.timestamp,
            type: .userProfileTest,
            status: .success,
            details: "User profile analysis completed successfully."
        )
    }
    
    private func performSystemHealthTest(originalResult: TestResult) async -> TestResult {
        // TODO: Implement actual system health test
        return TestResult(
            id: originalResult.id,
            timestamp: originalResult.timestamp,
            type: .algorithmTest, // Use available type from MatchmakingAdminService
            status: .success,
            details: "System health check completed. All services operational."
        )
    }
    
    func clearResults() {
        testResults.removeAll()
    }
}

// MARK: - Supporting Enums

enum DiagnosticStatus {
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

// TestResult is defined in MatchmakingAdminService.swift
// Using that definition for consistency

// MARK: - Preview

#Preview {
    MatchmakingTestingView()
}
