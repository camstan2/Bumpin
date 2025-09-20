import SwiftUI

// MARK: - Migration Settings View

struct MigrationSettingsView: View {
    @StateObject private var migrationService = UniversalTrackMigrationService.shared
    @State private var showingMigrationConfirmation = false
    @State private var migrationStats: (total: Int, migrated: Int) = (0, 0)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Universal Track Migration")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Migrate your existing music logs to the new cross-platform system for unified profiles across Apple Music and Spotify.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Migration status
                migrationStatusSection
                
                // Benefits section
                benefitsSection
                
                // Migration actions
                migrationActionsSection
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Migration")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMigrationStats()
        }
        .alert("Start Migration?", isPresented: $showingMigrationConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Migrate", role: .destructive) {
                Task {
                    await migrationService.migrateCurrentUserLogs()
                    await loadMigrationStats()
                }
            }
        } message: {
            Text("This will update your music logs to use the new cross-platform system. This process is safe and reversible.")
        }
    }
    
    @ViewBuilder
    private var migrationStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Migration Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Progress indicator
                if migrationService.isMigrating {
                    VStack(spacing: 8) {
                        ProgressView(value: migrationService.migrationProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        
                        Text(migrationService.migrationStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(migrationService.migratedCount) of \(migrationService.totalCount) migrated")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Status cards
                HStack(spacing: 12) {
                    MigrationStatCard(
                        title: "Total Logs",
                        value: "\(migrationStats.total)",
                        color: .gray,
                        icon: "music.note.list"
                    )
                    
                    MigrationStatCard(
                        title: "Migrated",
                        value: "\(migrationStats.migrated)",
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                    
                    MigrationStatCard(
                        title: "Remaining",
                        value: "\(migrationStats.total - migrationStats.migrated)",
                        color: .orange,
                        icon: "clock.fill"
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    @ViewBuilder
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Migration Benefits")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                BenefitCard(
                    icon: "link.circle.fill",
                    title: "Cross-Platform Profiles",
                    description: "Your logs will contribute to unified music profiles"
                )
                
                BenefitCard(
                    icon: "person.2.fill",
                    title: "Larger Community",
                    description: "See ratings from both Apple Music and Spotify users"
                )
                
                BenefitCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Better Recommendations",
                    description: "More accurate trending based on all platforms"
                )
                
                BenefitCard(
                    icon: "shield.checkered",
                    title: "Future-Proof",
                    description: "Ready for additional music platforms"
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var migrationActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Migrate button
                Button(action: {
                    showingMigrationConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Migrate My Logs")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                }
                .disabled(migrationService.isMigrating || migrationStats.total == migrationStats.migrated)
                .padding(.horizontal, 20)
                
                // Test button
                Button("🧪 Test Cross-Platform System") {
                    Task {
                        await testCrossPlatformSystem()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.purple)
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func loadMigrationStats() {
        Task {
            let stats = await migrationService.checkMigrationStatus()
            await MainActor.run {
                migrationStats = stats
            }
        }
    }
    
    private func testCrossPlatformSystem() async {
        print("🧪 === CROSS-PLATFORM SYSTEM TEST ===")
        await TrackMatchingService.shared.testSickoModeMatching()
        await SpotifyService.shared.demonstrateSpotifySearch()
        print("✅ Cross-platform test completed!")
    }
}

// MARK: - Migration Stat Card

struct MigrationStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    NavigationView {
        MigrationSettingsView()
    }
}
