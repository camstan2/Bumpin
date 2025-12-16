import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

/// Manages user notification preferences
@MainActor
class NotificationPreferencesService: ObservableObject {
    static let shared = NotificationPreferencesService()
    
    @Published var pushNotificationsEnabled: Bool = false
    @Published var likesEnabled: Bool = true
    @Published var commentsEnabled: Bool = true
    @Published var followersEnabled: Bool = true
    @Published var messagesEnabled: Bool = true
    @Published var matchmakingEnabled: Bool = true
    @Published var socialFeedEnabled: Bool = true
    
    @Published var isLoading: Bool = false
    
    private let db = Firestore.firestore()
    
    private init() {
        Task {
            await loadPreferences()
            await checkSystemNotificationStatus()
        }
    }
    
    // MARK: - Load Preferences
    
    func loadPreferences() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data(),
                  let prefs = data["notificationPreferences"] as? [String: Bool] else {
                // Use defaults if no preferences stored
                return
            }
            
            await MainActor.run {
                self.likesEnabled = prefs["likes"] ?? true
                self.commentsEnabled = prefs["comments"] ?? true
                self.followersEnabled = prefs["followers"] ?? true
                self.messagesEnabled = prefs["messages"] ?? true
                self.matchmakingEnabled = prefs["matchmaking"] ?? true
                self.socialFeedEnabled = prefs["socialFeed"] ?? true
            }
            
            print("✅ Loaded notification preferences")
        } catch {
            print("❌ Error loading notification preferences: \(error)")
        }
    }
    
    // MARK: - Save Preferences
    
    func savePreferences() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let preferences: [String: Bool] = [
            "likes": likesEnabled,
            "comments": commentsEnabled,
            "followers": followersEnabled,
            "messages": messagesEnabled,
            "matchmaking": matchmakingEnabled,
            "socialFeed": socialFeedEnabled
        ]
        
        do {
            try await db.collection("users").document(uid).updateData([
                "notificationPreferences": preferences
            ])
            print("✅ Saved notification preferences")
        } catch {
            print("❌ Error saving notification preferences: \(error)")
        }
    }
    
    // MARK: - System Notification Status
    
    func checkSystemNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        await MainActor.run {
            self.pushNotificationsEnabled = settings.authorizationStatus == .authorized
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.pushNotificationsEnabled = granted
            }
            
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
            
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

