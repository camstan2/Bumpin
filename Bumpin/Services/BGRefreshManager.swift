import Foundation
import BackgroundTasks
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class BGRefreshManager: ObservableObject {
    static let shared = BGRefreshManager()
    
    private let backgroundTaskIdentifier = "app.bumpin.refresh"
    private let db = Firestore.firestore()
    
    private init() {
        registerBackgroundTasks()
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform background refresh tasks here
        Task {
            // Add your background refresh logic
            await performBackgroundRefresh()
            task.setTaskCompleted(success: true)
        }
        
        // Schedule the next background refresh
        scheduleBackgroundRefresh()
    }
    
    private func performBackgroundRefresh() async {
        print("🔄 Performing background refresh")
        
        // Check and activate scheduled prompts
        await activateScheduledPrompts()
        
        // Check and deactivate expired prompts
        await deactivateExpiredPrompts()
    }
    
    // MARK: - Daily Prompt Automation
    
    /// Check for scheduled prompts that should be activated now
    private func activateScheduledPrompts() async {
        print("⏰ [BGRefresh] Checking for scheduled prompts to activate...")
        
        do {
            let now = Date()
            
            // Query for prompts that should be active now
            // - Not currently active
            // - Not archived
            // - Scheduled date is in the past
            // - Not yet expired
            let snapshot = try await db.collection("dailyPrompts")
                .whereField("isActive", isEqualTo: false)
                .whereField("isArchived", isEqualTo: false)
                .whereField("date", isLessThanOrEqualTo: Timestamp(date: now))
                .whereField("expiresAt", isGreaterThan: Timestamp(date: now))
                .getDocuments()
            
            print("   Found \(snapshot.documents.count) prompts ready to activate")
            
            guard !snapshot.documents.isEmpty else {
                print("   ℹ️ No scheduled prompts to activate")
                return
            }
            
            // Sort by date to get the most recent scheduled prompt
            let prompts = snapshot.documents.compactMap { doc -> (id: String, date: Date)? in
                guard let dateTimestamp = doc.data()["date"] as? Timestamp else { return nil }
                return (id: doc.documentID, date: dateTimestamp.dateValue())
            }.sorted { $0.date > $1.date }
            
            guard let latestPrompt = prompts.first else {
                print("   ⚠️ Could not parse prompt dates")
                return
            }
            
            print("   🎯 Activating prompt: \(latestPrompt.id)")
            
            // First, deactivate any currently active prompts
            let activeSnapshot = try await db.collection("dailyPrompts")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()
            
            print("   ⏸️ Deactivating \(activeSnapshot.documents.count) currently active prompts")
            
            let batch = db.batch()
            
            // Deactivate all currently active prompts
            for doc in activeSnapshot.documents {
                batch.updateData(["isActive": false], forDocument: doc.reference)
            }
            
            // Activate the scheduled prompt
            let promptRef = db.collection("dailyPrompts").document(latestPrompt.id)
            batch.updateData([
                "isActive": true,
                "date": FieldValue.serverTimestamp() // Update to actual activation time
            ], forDocument: promptRef)
            
            // Commit all changes
            try await batch.commit()
            
            print("   ✅ Successfully activated scheduled prompt: \(latestPrompt.id)")
            
            // Post notification for UI updates
            await MainActor.run {
                NotificationCenter.default.post(name: .dailyPromptActivated, object: latestPrompt.id)
            }
            
        } catch {
            print("   ❌ Error activating scheduled prompts: \(error)")
        }
    }
    
    /// Check for active prompts that have expired and deactivate them
    private func deactivateExpiredPrompts() async {
        print("⏰ [BGRefresh] Checking for expired prompts to deactivate...")
        
        do {
            let now = Date()
            
            // Query for prompts that are active but expired
            let snapshot = try await db.collection("dailyPrompts")
                .whereField("isActive", isEqualTo: true)
                .whereField("expiresAt", isLessThan: Timestamp(date: now))
                .getDocuments()
            
            print("   Found \(snapshot.documents.count) expired prompts to deactivate")
            
            guard !snapshot.documents.isEmpty else {
                print("   ℹ️ No expired prompts to deactivate")
                return
            }
            
            let batch = db.batch()
            
            // Deactivate all expired prompts
            for doc in snapshot.documents {
                batch.updateData(["isActive": false], forDocument: doc.reference)
                print("   ⏸️ Deactivating expired prompt: \(doc.documentID)")
            }
            
            // Commit all changes
            try await batch.commit()
            
            print("   ✅ Successfully deactivated \(snapshot.documents.count) expired prompts")
            
        } catch {
            print("   ❌ Error deactivating expired prompts: \(error)")
        }
    }
    
    // MARK: - Manual Triggers (for testing)
    
    /// Manually trigger prompt activation check (useful for testing)
    func manuallyCheckPrompts() async {
        print("🔧 [BGRefresh] Manually checking prompts...")
        
        await activateScheduledPrompts()
        await deactivateExpiredPrompts()
    }
    
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background refresh scheduled")
        } catch {
            print("❌ Failed to schedule background refresh: \(error)")
        }
    }
}
