import Foundation
import FirebaseFirestore

class FirestoreMigrationManager {
    static let shared = FirestoreMigrationManager()
    
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    func runMigrationsIfNeeded() async {
        let currentVersion = getCurrentMigrationVersion()
        let latestVersion = getLatestMigrationVersion()
        
        if currentVersion < latestVersion {
            print("🔄 Running Firestore migrations from version \(currentVersion) to \(latestVersion)")
            
            for version in (currentVersion + 1)...latestVersion {
                await runMigration(version: version)
            }
            
            setCurrentMigrationVersion(latestVersion)
            print("✅ Firestore migrations completed")
        }
    }
    
    private func getCurrentMigrationVersion() -> Int {
        return userDefaults.integer(forKey: "firestore_migration_version")
    }
    
    private func setCurrentMigrationVersion(_ version: Int) {
        userDefaults.set(version, forKey: "firestore_migration_version")
    }
    
    private func getLatestMigrationVersion() -> Int {
        return 1 // Update this as you add more migrations
    }
    
    private func runMigration(version: Int) async {
        switch version {
        case 1:
            await migration_v1_addUserSafetyFields()
        default:
            print("⚠️ Unknown migration version: \(version)")
        }
    }
    
    // MARK: - Migration v1: Add user safety fields
    private func migration_v1_addUserSafetyFields() async {
        print("🔄 Running migration v1: Adding user safety fields")
        
        do {
            let usersSnapshot = try await db.collection("users").getDocuments()
            
            for document in usersSnapshot.documents {
                let data = document.data()
                
                // Add safety fields if they don't exist
                var updates: [String: Any] = [:]
                
                if data["blockedUsers"] == nil {
                    updates["blockedUsers"] = []
                }
                
                if data["blockedBy"] == nil {
                    updates["blockedBy"] = []
                }
                
                if data["reportCount"] == nil {
                    updates["reportCount"] = 0
                }
                
                if data["violationCount"] == nil {
                    updates["violationCount"] = 0
                }
                
                if data["termsAcceptedAt"] == nil {
                    updates["termsAcceptedAt"] = FieldValue.serverTimestamp()
                    updates["termsVersion"] = "1.0"
                }
                
                if !updates.isEmpty {
                    try await document.reference.updateData(updates)
                }
            }
            
            print("✅ Migration v1 completed")
        } catch {
            print("❌ Migration v1 failed: \(error)")
        }
    }
}
