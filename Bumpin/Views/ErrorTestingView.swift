import SwiftUI

struct ErrorTestingView: View {
    // MARK: - Properties
    @StateObject private var errorService = ErrorTestingService.shared
    @State private var selectedErrorType: TestError?
    @State private var showingErrorSelector = false
    
    // MARK: - Error Types
    private let availableErrors: [(String, TestError)] = [
        ("Network Error", .network("Failed to connect to server")),
        ("Authentication Error", .authentication("Token expired")),
        ("Database Error", .database("Failed to read data")),
        ("Validation Error", .validation("Invalid input format")),
        ("Unknown Error", .unknown("Unexpected system state"))
    ]
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Error Testing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        resetButton
                    }
                }
        }
    }
    
    // MARK: - Subviews
    private var mainContent: some View {
        VStack(spacing: 20) {
            errorStatusCard
            
            if errorService.isLoading {
                loadingView
            } else if let error = errorService.currentError {
                errorView(error)
            } else {
                triggerErrorButton
            }
            
            if !errorService.recoveryActions.isEmpty {
                recoveryActionsView
            }
            
            if let lastRecovery = errorService.lastSuccessfulRecovery {
                lastRecoveryView(lastRecovery)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingErrorSelector) {
            errorSelectorSheet
        }
    }
    
    private var errorStatusCard: some View {
        VStack(spacing: 8) {
            Label(
                "Recovery Attempts: \(errorService.recoveryAttempts)",
                systemImage: "arrow.clockwise.circle"
            )
            .font(.headline)
            
            if let error = errorService.currentError {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Processing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            
            Text(error.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
    
    private var triggerErrorButton: some View {
        Button(action: {
            showingErrorSelector = true
        }) {
            Label("Trigger Error", systemImage: "bolt.fill")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var recoveryActionsView: some View {
        VStack(spacing: 12) {
            Text("Recovery Actions")
                .font(.headline)
            
            ForEach(errorService.recoveryActions) { action in
                Button(action: {
                    Task {
                        await action.action()
                    }
                }) {
                    Text(action.title)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    private func lastRecoveryView(_ date: Date) -> some View {
        VStack(spacing: 4) {
            Text("Last Successful Recovery")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(date, style: .relative)
                .font(.caption2)
                .foregroundStyle(.green)
        }
    }
    
    private var resetButton: some View {
        Button(action: {
            errorService.reset()
        }) {
            Image(systemName: "arrow.counterclockwise")
        }
        .disabled(errorService.isLoading)
    }
    
    private var errorSelectorSheet: some View {
        NavigationStack {
            List(availableErrors, id: \.0) { name, error in
                Button(action: {
                    selectedErrorType = error
                    showingErrorSelector = false
                    Task {
                        await errorService.triggerError(error)
                    }
                }) {
                    Text(name)
                }
            }
            .navigationTitle("Select Error Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingErrorSelector = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
