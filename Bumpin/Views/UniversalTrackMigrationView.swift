import SwiftUI

/// Admin view for running the Universal Track migration
struct UniversalTrackMigrationView: View {
    @StateObject private var migrationService = UniversalTrackMigrationService.shared
    @State private var showConfirmation = false
    @State private var migrationStatus: MigrationStatus?
    @State private var isCheckingStatus = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Universal Track Migration")
                        .font(.title.bold())
                    
                    Text("This migration updates existing logs to support cross-platform music tracking. Apple Music and Spotify users will see the same ratings and comments for the same songs.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Status Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Migration Status")
                        .font(.headline)
                    
                    if isCheckingStatus {
                        HStack {
                            ProgressView()
                            Text("Checking status...")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if let status = migrationStatus {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: status.needsMigration ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .foregroundColor(status.needsMigration ? .orange : .green)
                                
                                Text(status.needsMigration ? "Migration Needed" : "Up to Date")
                                    .font(.subheadline.bold())
                            }
                            
                            if status.needsMigration {
                                Text("\(status.logsNeedingMigration) logs need to be migrated")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let lastRun = status.lastRunDate {
                                Text("Last run: \(lastRun.formatted())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    Button(action: checkStatus) {
                        Label("Check Status", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCheckingStatus || migrationService.isRunning)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                
                // Progress Section (shown when migration is running)
                if migrationService.isRunning {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Migration Progress")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("\(migrationService.processedLogs) / \(migrationService.totalLogs)")
                                    .font(.caption.monospacedDigit())
                                Spacer()
                                Text("\(Int(migrationService.progress * 100))%")
                                    .font(.caption.monospacedDigit())
                            }
                            
                            ProgressView(value: migrationService.progress)
                                .progressViewStyle(.linear)
                            
                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("✅ Success")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text("\(migrationService.successfulUpdates)")
                                        .font(.caption.bold().monospacedDigit())
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("❌ Failed")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                    Text("\(migrationService.failedUpdates)")
                                        .font(.caption.bold().monospacedDigit())
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("⏭️ Skipped")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("\(migrationService.skippedLogs)")
                                        .font(.caption.bold().monospacedDigit())
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
                
                // Error Messages
                if !migrationService.errorMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Errors")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(migrationService.errorMessages.prefix(10), id: \.self) { message in
                                    Text("• \(message)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                if migrationService.errorMessages.count > 10 {
                                    Text("... and \(migrationService.errorMessages.count - 10) more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
                
                // Run Migration Button
                VStack(spacing: 12) {
                    Button(action: { showConfirmation = true }) {
                        HStack {
                            if migrationService.isRunning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Migration Running...")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Run Migration")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(migrationService.isRunning ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(migrationService.isRunning)
                    
                    Text("⚠️ This process may take several minutes depending on the number of logs.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("Migration")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkStatus()
        }
        .alert("Run Migration?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Run Migration", role: .destructive) {
                Task {
                    await migrationService.runMigration()
                    await checkStatus()
                }
            }
        } message: {
            if let status = migrationStatus {
                Text("This will update \(status.logsNeedingMigration) logs to include universal track IDs. This operation cannot be undone.")
            } else {
                Text("This will update existing logs to include universal track IDs. This operation cannot be undone.")
            }
        }
    }
    
    private func checkStatus() {
        isCheckingStatus = true
        Task {
            let status = await migrationService.checkMigrationStatus()
            await MainActor.run {
                self.migrationStatus = status
                self.isCheckingStatus = false
            }
        }
    }
}

#Preview {
    NavigationView {
        UniversalTrackMigrationView()
    }
}

