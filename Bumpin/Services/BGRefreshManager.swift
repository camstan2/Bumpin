import Foundation
import BackgroundTasks
import SwiftUI

class BGRefreshManager: ObservableObject {
    static let shared = BGRefreshManager()
    
    private let backgroundTaskIdentifier = "com.bumpin.refresh"
    
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
        // Add background refresh logic here
        // For example: sync data, update notifications, etc.
        print("🔄 Performing background refresh")
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
