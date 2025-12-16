import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Manages user privacy settings
@MainActor
class PrivacySettingsService: ObservableObject {
    static let shared = PrivacySettingsService()
    
    @Published var profileVisibility: ProfileVisibility = .public
    @Published var logsVisibility: LogsVisibility = .everyone
    @Published var whoCanMessage: MessagingPrivacy = .everyone
    @Published var showActivityStatus: Bool = true
    
    @Published var isLoading: Bool = false
    
    private let db = Firestore.firestore()
    
    private init() {
        Task {
            await loadPrivacySettings()
        }
    }
    
    // MARK: - Load Settings
    
    func loadPrivacySettings() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data(),
                  let settings = data["privacySettings"] as? [String: String] else {
                // Use defaults if no settings stored
                return
            }
            
            await MainActor.run {
                if let visibility = settings["profileVisibility"],
                   let mode = ProfileVisibility(rawValue: visibility) {
                    self.profileVisibility = mode
                }
                
                if let logsVis = settings["logsVisibility"],
                   let mode = LogsVisibility(rawValue: logsVis) {
                    self.logsVisibility = mode
                }
                
                if let messaging = settings["whoCanMessage"],
                   let mode = MessagingPrivacy(rawValue: messaging) {
                    self.whoCanMessage = mode
                }
                
                if let activityStatus = data["showActivityStatus"] as? Bool {
                    self.showActivityStatus = activityStatus
                }
            }
            
            print("✅ Loaded privacy settings")
        } catch {
            print("❌ Error loading privacy settings: \(error)")
        }
    }
    
    // MARK: - Save Settings
    
    func savePrivacySettings() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let settings: [String: String] = [
            "profileVisibility": profileVisibility.rawValue,
            "logsVisibility": logsVisibility.rawValue,
            "whoCanMessage": whoCanMessage.rawValue
        ]
        
        do {
            try await db.collection("users").document(uid).updateData([
                "privacySettings": settings,
                "showActivityStatus": showActivityStatus
            ])
            print("✅ Saved privacy settings")
        } catch {
            print("❌ Error saving privacy settings: \(error)")
        }
    }
}

// MARK: - Privacy Enums

enum ProfileVisibility: String, CaseIterable, Identifiable {
    case `public` = "public"
    case friends = "friends"
    case `private` = "private"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        case .private: return "Private"
        }
    }
    
    var description: String {
        switch self {
        case .public: return "Anyone can view your profile"
        case .friends: return "Only friends can view your profile"
        case .private: return "Only you can view your profile"
        }
    }
    
    var icon: String {
        switch self {
        case .public: return "globe"
        case .friends: return "person.2.fill"
        case .private: return "lock.fill"
        }
    }
}

enum LogsVisibility: String, CaseIterable, Identifiable {
    case everyone = "everyone"
    case friends = "friends"
    case nobody = "nobody"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .friends: return "Friends Only"
        case .nobody: return "Only Me"
        }
    }
    
    var description: String {
        switch self {
        case .everyone: return "Anyone can see your music logs"
        case .friends: return "Only friends can see your logs"
        case .nobody: return "Only you can see your logs"
        }
    }
}

enum MessagingPrivacy: String, CaseIterable, Identifiable {
    case everyone = "everyone"
    case friends = "friends"
    case nobody = "nobody"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .friends: return "Friends Only"
        case .nobody: return "No One"
        }
    }
    
    var description: String {
        switch self {
        case .everyone: return "Anyone can message you"
        case .friends: return "Only friends can message you"
        case .nobody: return "No one can message you"
        }
    }
}

