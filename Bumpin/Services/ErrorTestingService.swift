import Foundation
import SwiftUI
import Combine

// MARK: - Error Types
enum TestError: Error, LocalizedError {
    case network(String)
    case authentication(String)
    case database(String)
    case validation(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .network(let message): return "Network Error: \(message)"
        case .authentication(let message): return "Auth Error: \(message)"
        case .database(let message): return "Database Error: \(message)"
        case .validation(let message): return "Validation Error: \(message)"
        case .unknown(let message): return "Unknown Error: \(message)"
        }
    }
}

// MARK: - Recovery Action
struct ErrorRecoveryAction: Identifiable {
    let id = UUID()
    let title: String
    let action: () async -> Void
    let analyticsName: String
}

// MARK: - Error Testing Service Protocol
protocol ErrorTestingServiceProtocol {
    var currentError: Error? { get }
    var isLoading: Bool { get }
    var recoveryActions: [ErrorRecoveryAction] { get }
    var recoveryAttempts: Int { get }
    var lastSuccessfulRecovery: Date? { get }
    
    func triggerError(_ type: TestError) async
    func attemptRecovery() async
    func reset()
}

// MARK: - Error Testing Service
@MainActor
final class ErrorTestingService: NSObject, ObservableObject, ErrorTestingServiceProtocol {
    // MARK: - Singleton
    static let shared = ErrorTestingService()
    
    // MARK: - Published Properties
    @Published private(set) var currentError: Error?
    @Published private(set) var isLoading = false
    @Published private(set) var recoveryActions: [ErrorRecoveryAction] = []
    @Published private(set) var recoveryAttempts = 0
    @Published private(set) var lastSuccessfulRecovery: Date?
    
    // MARK: - Private Properties
    private var retryLimit = 3
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupErrorHandling()
    }
    
    // MARK: - Required Protocol Methods
    func initialize() async throws {
        // No initialization needed
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Simulates different types of errors
    func triggerError(_ type: TestError) async {
        isLoading = true
        defer { isLoading = false }
        
        // Log attempt
        logEvent("error_test_triggered", parameters: [
            "error_type": String(describing: type),
            "recovery_attempts": recoveryAttempts
        ])
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Set error and generate recovery actions
        currentError = type
        generateRecoveryActions(for: type)
        
        // Log error
        logError(type, category: "error_testing", userInfo: ["recovery_attempts": recoveryAttempts])
    }
    
    /// Attempts to recover from the current error
    func attemptRecovery() async {
        guard currentError != nil else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        recoveryAttempts += 1
        
        // Log recovery attempt
        logEvent("error_recovery_attempted", parameters: [
            "attempt_number": recoveryAttempts,
            "error_type": String(describing: currentError)
        ])
        
        // Simulate recovery process
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // 70% success rate after delay
        if Double.random(in: 0...1) < 0.7 {
            await handleSuccessfulRecovery()
        } else {
            await handleFailedRecovery()
        }
    }
    
    /// Resets the error testing service
    func reset() {
        currentError = nil
        recoveryAttempts = 0
        recoveryActions = []
        lastSuccessfulRecovery = nil
        
        logEvent("error_testing_reset")
    }
    
    // MARK: - Private Methods
    
    private func setupErrorHandling() {
        // Monitor recovery attempts
        $recoveryAttempts
            .sink { [weak self] attempts in
                if attempts >= self?.retryLimit ?? 3 {
                    self?.handleTooManyAttempts()
                }
            }
            .store(in: &cancellables)
    }
    
    private func generateRecoveryActions(for error: TestError) {
        switch error {
        case .network:
            recoveryActions = [
                ErrorRecoveryAction(
                    title: "Check Connection",
                    action: { [weak self] in
                        await self?.simulateNetworkCheck()
                    },
                    analyticsName: "check_connection"
                ),
                ErrorRecoveryAction(
                    title: "Retry",
                    action: { [weak self] in
                        await self?.attemptRecovery()
                    },
                    analyticsName: "retry_connection"
                )
            ]
            
        case .authentication:
            recoveryActions = [
                ErrorRecoveryAction(
                    title: "Refresh Token",
                    action: { [weak self] in
                        await self?.simulateTokenRefresh()
                    },
                    analyticsName: "refresh_token"
                ),
                ErrorRecoveryAction(
                    title: "Reauthorize",
                    action: { [weak self] in
                        await self?.simulateReauthorization()
                    },
                    analyticsName: "reauthorize"
                )
            ]
            
        case .database:
            recoveryActions = [
                ErrorRecoveryAction(
                    title: "Verify Data",
                    action: { [weak self] in
                        await self?.simulateDataVerification()
                    },
                    analyticsName: "verify_data"
                ),
                ErrorRecoveryAction(
                    title: "Repair",
                    action: { [weak self] in
                        await self?.simulateDataRepair()
                    },
                    analyticsName: "repair_data"
                )
            ]
            
        case .validation:
            recoveryActions = [
                ErrorRecoveryAction(
                    title: "Validate Input",
                    action: { [weak self] in
                        await self?.simulateInputValidation()
                    },
                    analyticsName: "validate_input"
                )
            ]
            
        case .unknown:
            recoveryActions = [
                ErrorRecoveryAction(
                    title: "Reset",
                    action: { [weak self] in
                        self?.reset()
                    },
                    analyticsName: "reset_system"
                )
            ]
        }
    }
    
    private func handleSuccessfulRecovery() async {
        lastSuccessfulRecovery = Date()
        currentError = nil
        recoveryActions = []
        
        logEvent("error_recovery_successful", parameters: [
            "attempts_needed": recoveryAttempts
        ])
    }
    
    private func handleFailedRecovery() async {
        let newError = TestError.unknown("Recovery attempt \(recoveryAttempts) failed")
        currentError = newError
        
        logError(newError, category: "error_recovery", userInfo: ["attempts": recoveryAttempts])
    }
    
    private func handleTooManyAttempts() {
        let error = TestError.unknown("Too many recovery attempts")
        currentError = error
        recoveryActions = [
            ErrorRecoveryAction(
                title: "Reset System",
                action: { [weak self] in
                    self?.reset()
                },
                analyticsName: "reset_after_max_attempts"
            )
        ]
        
        logError(error, category: "error_recovery", userInfo: ["max_attempts": retryLimit])
    }
    
    // MARK: - Analytics Helpers
    
    private func logEvent(_ name: String, parameters: [String: Any] = [:]) {
        Task {
            await MainActor.run {
                // Using print for now until AnalyticsService is available
                print("📊 Analytics Event: \(name), Parameters: \(parameters)")
            }
        }
    }
    
    private func logError(_ error: Error, category: String, userInfo: [String: Any] = [:]) {
        Task {
            await MainActor.run {
                // Using print for now until ErrorLogger is available
                print("❌ Error Log: \(error.localizedDescription), Category: \(category), Info: \(userInfo)")
            }
        }
    }
    
    // MARK: - Simulation Methods
    
    private func simulateNetworkCheck() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await attemptRecovery()
    }
    
    private func simulateTokenRefresh() async {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await attemptRecovery()
    }
    
    private func simulateReauthorization() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await attemptRecovery()
    }
    
    private func simulateDataVerification() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await attemptRecovery()
    }
    
    private func simulateDataRepair() async {
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        await attemptRecovery()
    }
    
    private func simulateInputValidation() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        await attemptRecovery()
    }
}