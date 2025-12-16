import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for migrating existing MusicLog entries to include universalTrackId and musicPlatform
@MainActor
class UniversalTrackMigrationService: ObservableObject {
    static let shared = UniversalTrackMigrationService()
    
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var totalLogs = 0
    @Published var processedLogs = 0
    @Published var successfulUpdates = 0
    @Published var failedUpdates = 0
    @Published var skippedLogs = 0
    @Published var errorMessages: [String] = []
    @Published var lastRunDate: Date?
    
    private let db = Firestore.firestore()
    private let batchSize = 100 // Process 100 logs at a time
    
    private init() {
        loadLastRunDate()
    }
    
    // MARK: - Migration Control
    
    /// Run the migration for all logs without universalTrackId
    func runMigration() async {
        guard !isRunning else {
            print("⚠️ Migration already running")
            return
        }
        
        isRunning = true
        progress = 0.0
        processedLogs = 0
        successfulUpdates = 0
        failedUpdates = 0
        skippedLogs = 0
        errorMessages.removeAll()
        
        print("🚀 Starting Universal Track Migration...")
        
        do {
            // Get total count of logs without universalTrackId
            totalLogs = try await fetchTotalLogsToMigrate()
            print("📊 Found \(totalLogs) logs to migrate")
            
            if totalLogs == 0 {
                print("✅ No logs to migrate!")
                isRunning = false
                return
            }
            
            // Process in batches
            var lastDocument: DocumentSnapshot? = nil
            var hasMore = true
            
            while hasMore {
                let result = try await processBatch(after: lastDocument)
                lastDocument = result.lastDocument
                hasMore = result.hasMore
                
                // Update progress
                progress = Double(processedLogs) / Double(totalLogs)
                
                print("📈 Progress: \(processedLogs)/\(totalLogs) (\(Int(progress * 100))%)")
                
                // Add a small delay to avoid overwhelming Firestore
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            print("✅ Migration complete!")
            print("   Processed: \(processedLogs)")
            print("   Successful: \(successfulUpdates)")
            print("   Failed: \(failedUpdates)")
            print("   Skipped: \(skippedLogs)")
            
            // Save last run date
            lastRunDate = Date()
            saveLastRunDate()
            
        } catch {
            print("❌ Migration error: \(error.localizedDescription)")
            errorMessages.append("Migration failed: \(error.localizedDescription)")
        }
        
        isRunning = false
    }
    
    // MARK: - Batch Processing
    
    private func processBatch(after lastDoc: DocumentSnapshot?) async throws -> (lastDocument: DocumentSnapshot?, hasMore: Bool) {
        // Query logs without universalTrackId
        var query = db.collection("logs")
            .order(by: "dateLogged", descending: true)
            .limit(to: batchSize)
        
        if let lastDoc = lastDoc {
            query = query.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await query.getDocuments()
        
        guard !snapshot.documents.isEmpty else {
            return (nil, false)
        }
        
        // Filter logs that need migration (no universalTrackId or no musicPlatform)
        let logsToMigrate = snapshot.documents.compactMap { doc -> (doc: DocumentSnapshot, log: MusicLog)? in
            guard let log = try? doc.data(as: MusicLog.self) else { return nil }
            
            // Only migrate logs that are missing universalTrackId or musicPlatform
            if log.universalTrackId == nil || log.musicPlatform == nil {
                return (doc, log)
            }
            return nil
        }
        
        print("🔄 Processing batch: \(logsToMigrate.count) logs to migrate out of \(snapshot.documents.count)")
        
        // Process each log
        for (doc, log) in logsToMigrate {
            await migrateLog(doc: doc, log: log)
            processedLogs += 1
        }
        
        // Count skipped logs (already migrated)
        let skipped = snapshot.documents.count - logsToMigrate.count
        skippedLogs += skipped
        processedLogs += skipped
        
        return (snapshot.documents.last, snapshot.documents.count == batchSize)
    }
    
    private func migrateLog(doc: DocumentSnapshot, log: MusicLog) async {
        do {
            // Determine platform (default to apple_music for existing logs)
            let platform = log.musicPlatform ?? "apple_music"
            
            // Get or create universal track
            let universalTrack: UniversalTrack
            
            // For albums, use title as album name. For songs, use empty string since we don't have album info
            let albumName = log.itemType == "album" ? log.title : ""
            
            if platform == "apple_music" {
                universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                    title: log.title,
                    artist: log.artistName,
                    albumName: albumName,
                    appleMusicId: log.itemId
                )
            } else {
                universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                    title: log.title,
                    artist: log.artistName,
                    albumName: albumName,
                    spotifyId: log.itemId
                )
            }
            
            // Try multiple approaches to update the log
            do {
                // Approach 1: Try updateData first (most efficient)
                try await db.collection("logs").document(doc.documentID).updateData([
                    "universalTrackId": universalTrack.id,
                    "musicPlatform": platform,
                    "platformMatchingConfidence": 1.0
                ])
            } catch {
                // Approach 2: If updateData fails, try setData with merge
                print("⚠️ UpdateData failed, trying setData with merge for log \(doc.documentID)")
                guard var logData = doc.data() else {
                    throw NSError(domain: "MigrationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get document data"])
                }
                logData["universalTrackId"] = universalTrack.id
                logData["musicPlatform"] = platform
                logData["platformMatchingConfidence"] = 1.0
                
                try await db.collection("logs").document(doc.documentID).setData(logData, merge: true)
            }
            
            successfulUpdates += 1
            print("✅ Migrated log: \(log.title) by \(log.artistName) -> \(universalTrack.id)")
            
        } catch {
            failedUpdates += 1
            let errorMsg = "Failed to migrate log \(doc.documentID): \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            errorMessages.append(errorMsg)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchTotalLogsToMigrate() async throws -> Int {
        // Note: This is an approximation since we can't efficiently count logs without universalTrackId
        // We'll fetch a sample and extrapolate, or just count all logs for simplicity
        let snapshot = try await db.collection("logs").getDocuments()
        
        // Count logs that need migration
        let needsMigration = snapshot.documents.filter { doc in
            guard let log = try? doc.data(as: MusicLog.self) else { return false }
            return log.universalTrackId == nil || log.musicPlatform == nil
        }.count
        
        return needsMigration
    }
    
    // MARK: - Persistence
    
    private func loadLastRunDate() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastUniversalTrackMigrationDate") as? Date {
            lastRunDate = timestamp
        }
    }
    
    private func saveLastRunDate() {
        if let date = lastRunDate {
            UserDefaults.standard.set(date, forKey: "lastUniversalTrackMigrationDate")
        }
    }
    
    // MARK: - Status Check
    
    func checkMigrationStatus() async -> MigrationStatus {
        do {
            let needsMigration = try await fetchTotalLogsToMigrate()
            return MigrationStatus(
                needsMigration: needsMigration > 0,
                logsNeedingMigration: needsMigration,
                lastRunDate: lastRunDate
            )
        } catch {
            print("❌ Error checking migration status: \(error.localizedDescription)")
            return MigrationStatus(needsMigration: false, logsNeedingMigration: 0, lastRunDate: lastRunDate)
        }
    }
}

// MARK: - Supporting Types

struct MigrationStatus {
    let needsMigration: Bool
    let logsNeedingMigration: Int
    let lastRunDate: Date?
}
