import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Service Template
// Use this template when creating new services to maintain consistency

@MainActor
protocol BumpinService: ObservableObject {
    // Common properties that all services should have
    var isLoading: Bool { get set }
    var error: Error? { get set }
    
    // Common error handling
    func handle(_ error: Error)
    func clearError()
}

extension BumpinService {
    // Default error handling implementation
    func handle(_ error: Error) {
        Task { @MainActor in
            self.error = error
            print("❌ Service Error: \(error.localizedDescription)")
        }
    }
    
    func clearError() {
        Task { @MainActor in
            self.error = nil
        }
    }
}

// Example service implementation:
/*
@MainActor
class ExampleService: ObservableObject, BumpinService {
    // MARK: - Singleton
    static let shared = ExampleService()
    private init() { setupListeners() }
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    // MARK: - Lifecycle
    private func setupListeners() {
        // Setup any Firebase listeners or other initialization
    }
    
    deinit {
        listeners.values.forEach { $0.remove() }
    }
    
    // MARK: - Public Methods
    func somePublicMethod() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Implementation
        } catch {
            handle(error)
            throw error
        }
    }
}
*/
