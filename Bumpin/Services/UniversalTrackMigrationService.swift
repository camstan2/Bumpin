import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Universal Track Migration Service

@MainActor
class UniversalTrackMigrationService: ObservableObject {
    
    // MARK: - Migration Status
    
    @Published var isMigrating = false
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus = "Ready to migrate"
    @Published var migratedCount = 0
    @Published var totalCount = 0
    
    // MARK: - Singleton
    static let shared = UniversalTrackMigrationService()
    
    private init() {}
    
    // MARK: - Migration Methods
    
    /// Migrate all existing Apple Music logs to use universal tracks
    func migrateAllExistingLogs() async {
        guard !isMigrating else { return }
        
        isMigrating = true
        migrationProgress = 0.0
        migrationStatus = "Starting migration..."
        migratedCount = 0
        
        print("🔄 Starting universal track migration for existing logs...")
        
        let db = Firestore.firestore()
        
        do {
            // Get total count first
            let countSnapshot = try await db.collection("logs")
                .whereField("universalTrackId", isEqualTo: NSNull())
                .whereField("itemType", isEqualTo: "song")
                .count
                .getAggregation(source: .server)
            
            totalCount = Int(countSnapshot.count)
            migrationStatus = "Found \(totalCount) logs to migrate"
            
            // Process in batches to avoid overwhelming Firestore
            let batchSize = 20
            var processedCount = 0
            
            while processedCount < totalCount {
                let snapshot = try await db.collection("logs")
                    .whereField("universalTrackId", isEqualTo: NSNull())
                    .whereField("itemType", isEqualTo: "song")
                    .limit(to: batchSize)
                    .getDocuments()
                
                if snapshot.documents.isEmpty {
                    break // No more logs to process
                }
                
                migrationStatus = "Processing batch \(processedCount / batchSize + 1)..."
                
                // Process batch
                for document in snapshot.documents {
                    if let log = try? document.data(as: MusicLog.self) {
                        await migrateSingleLog(log, document: document)
                        migratedCount += 1
                        processedCount += 1
                        
                        // Update progress
                        migrationProgress = Double(processedCount) / Double(totalCount)
                    }
                }
                
                // Small delay between batches
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            migrationStatus = "Migration completed! \(migratedCount) logs migrated."
            print("✅ Migration completed: \(migratedCount) logs migrated to universal tracks")
            
        } catch {
            migrationStatus = "Migration failed: \(error.localizedDescription)"
            print("❌ Migration error: \(error.localizedDescription)")
        }
        
        isMigrating = false
    }
    
    /// Migrate a single log to use universal track
    private func migrateSingleLog(_ log: MusicLog, document: QueryDocumentSnapshot) async {
        do {
            // Create or find universal track
            let universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: log.title,
                artist: log.artistName,
                appleMusicId: log.itemId
            )
            
            // Update the log document
            try await document.reference.updateData([
                "universalTrackId": universalTrack.id,
                "musicPlatform": "apple_music",
                "platformMatchingConfidence": universalTrack.matchingConfidence
            ])
            
            print("✅ Migrated: \(log.title) → \(universalTrack.id)")
            
        } catch {
            print("❌ Failed to migrate log \(log.id): \(error.localizedDescription)")
        }
    }
    
    /// Check migration status
    func checkMigrationStatus() async -> (total: Int, migrated: Int) {
        let db = Firestore.firestore()
        
        do {
            async let totalSnapshot = db.collection("logs")
                .whereField("itemType", isEqualTo: "song")
                .count
                .getAggregation(source: .server)
            
            async let migratedSnapshot = db.collection("logs")
                .whereField("itemType", isEqualTo: "song")
                .whereField("universalTrackId", isNotEqualTo: NSNull())
                .count
                .getAggregation(source: .server)
            
            let (total, migrated) = try await (totalSnapshot, migratedSnapshot)
            return (total: Int(total.count), migrated: Int(migrated.count))
            
        } catch {
            print("❌ Error checking migration status: \(error.localizedDescription)")
            return (total: 0, migrated: 0)
        }
    }
    
    /// Quick migration for current user only (for testing)
    func migrateCurrentUserLogs() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isMigrating = true
        migrationStatus = "Migrating your logs..."
        
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("logs")
                .whereField("userId", isEqualTo: userId)
                .whereField("universalTrackId", isEqualTo: NSNull())
                .whereField("itemType", isEqualTo: "song")
                .limit(to: 50)
                .getDocuments()
            
            totalCount = snapshot.documents.count
            migratedCount = 0
            
            for document in snapshot.documents {
                if let log = try? document.data(as: MusicLog.self) {
                    await migrateSingleLog(log, document: document)
                    migratedCount += 1
                    migrationProgress = Double(migratedCount) / Double(totalCount)
                }
            }
            
            migrationStatus = "Your logs migrated successfully!"
            
        } catch {
            migrationStatus = "Migration failed: \(error.localizedDescription)"
        }
        
        isMigrating = false
    }
}
