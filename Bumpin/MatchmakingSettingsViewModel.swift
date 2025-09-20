import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Matchmaking Settings ViewModel

@MainActor
class MatchmakingSettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isOptedIn: Bool = false
    @Published var userGender: MatchmakingGender = .preferNotToSay
    @Published var preferredGender: MatchmakingGender = .any
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Statistics
    @Published var totalMatches: Int = 0
    @Published var successfulConnections: Int = 0
    @Published var averageSimilarity: Double = 0.0
    @Published var responseRate: Double = 0.0
    
    // Recent matches
    @Published var recentMatches: [WeeklyMatch] = []
    
    // Demo controls
    @Published var showMockBot: Bool = false
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadUserPreferences()
        loadUserStatistics()
        loadRecentMatches()
    }
    
    // MARK: - User Preferences
    
    /// Load user's matchmaking preferences from Firestore
    func loadUserPreferences() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Failed to load preferences: \(error.localizedDescription)"
                    return
                }
                
                guard let data = snapshot?.data() else { return }
                
                // Load preferences
                self.isOptedIn = data["matchmakingOptIn"] as? Bool ?? false
                
                if let genderString = data["matchmakingGender"] as? String,
                   let gender = MatchmakingGender(rawValue: genderString) {
                    self.userGender = gender
                }
                
                if let preferredGenderString = data["matchmakingPreferredGender"] as? String,
                   let preferredGender = MatchmakingGender(rawValue: preferredGenderString) {
                    self.preferredGender = preferredGender
                }
                
                print("✅ Loaded matchmaking preferences: opted in = \(self.isOptedIn)")
            }
        }
    }
    
    /// Save user's matchmaking preferences to Firestore
    func savePreferences() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let updates: [String: Any] = [
            "matchmakingOptIn": isOptedIn,
            "matchmakingGender": userGender.rawValue,
            "matchmakingPreferredGender": preferredGender.rawValue,
            "matchmakingLastActive": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).updateData(updates) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Failed to save preferences: \(error.localizedDescription)"
                    print("❌ Error saving matchmaking preferences: \(error.localizedDescription)")
                } else {
                    print("✅ Saved matchmaking preferences successfully")
                    
                    // If user opted out, also create/update their matchmaking profile
                    if let self = self {
                        self.updateMatchmakingProfile()
                    }
                }
            }
        }
    }
    
    /// Update or create user's matchmaking profile
    private func updateMatchmakingProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let profileData: [String: Any] = [
            "userId": userId,
            "optedIn": isOptedIn,
            "gender": userGender.rawValue,
            "preferredGender": preferredGender.rawValue,
            "lastActive": FieldValue.serverTimestamp(),
            "preferences": [
                "genreWeighting": 0.3,
                "artistWeighting": 0.4,
                "ratingWeighting": 0.2,
                "discoveryWeighting": 0.1,
                "minimumSimilarityScore": 0.6,
                "excludePreviousMatches": true,
                "cooldownPeriodWeeks": 8
            ]
        ]
        
        db.collection("musicMatchmaking").document(userId).setData(profileData, merge: true) { error in
            if let error = error {
                print("❌ Error updating matchmaking profile: \(error.localizedDescription)")
            } else {
                print("✅ Updated matchmaking profile successfully")
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Load user's matchmaking statistics
    func loadUserStatistics() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Load match statistics
        db.collection("weeklyMatches")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ Error loading match statistics: \(error.localizedDescription)")
                        return
                    }
                    
                    let matches = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: WeeklyMatch.self)
                    } ?? []
                    
                    self.calculateStatistics(from: matches)
                }
            }
    }
    
    /// Calculate statistics from matches
    private func calculateStatistics(from matches: [WeeklyMatch]) {
        totalMatches = matches.count
        
        // Calculate successful connections (users who responded)
        successfulConnections = matches.filter { $0.userResponded }.count
        
        // Calculate average similarity score
        if !matches.isEmpty {
            averageSimilarity = matches.map { $0.similarityScore }.reduce(0, +) / Double(matches.count)
        }
        
        // Calculate response rate
        if totalMatches > 0 {
            responseRate = Double(successfulConnections) / Double(totalMatches)
        }
        
        print("📊 Loaded statistics: \(totalMatches) matches, \(successfulConnections) connections")
    }
    
    // MARK: - Recent Matches
    
    /// Load user's recent matches
    func loadRecentMatches() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("weeklyMatches")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ Error loading recent matches: \(error.localizedDescription)")
                        return
                    }
                    
                    self.recentMatches = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: WeeklyMatch.self)
                    } ?? []
                    
                    print("📝 Loaded \(self.recentMatches.count) recent matches")
                }
            }
    }
    
    // MARK: - Demo Controls
    
    /// Toggle mock bot conversation in Messages tab
    func toggleMockBot() {
        let newValue = !showMockBot
        showMockBot = newValue
        
        Task { @MainActor in
            if newValue {
                await MockBotConversationService.shared.createMockBotConversation()
                print("✅ Mock bot conversation added to Messages")
            } else {
                await MockBotConversationService.shared.removeMockBotConversation()
                print("🗑️ Mock bot conversation removed from Messages")
            }
        }
    }
    
    /// Check if mock bot conversation exists on load
    func checkMockBotStatus() {
        Task { @MainActor in
            let exists = await MockBotConversationService.shared.mockConversationExists()
            self.showMockBot = exists
        }
    }
    
    // MARK: - Manual Testing (Admin Only)
    
    /// Test matchmaking for current user (admin only)
    /// Note: This would require Firebase Functions SDK which is not available in iOS
    /// For testing, use the Firebase Console or deploy the function separately
    func testMatchmaking() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Check if user is admin
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data()
            
            guard userData?["isAdmin"] as? Bool == true else {
                errorMessage = "Admin access required for testing"
                return
            }
            
            errorMessage = "Manual testing requires Firebase Console or server-side deployment"
            print("ℹ️ Manual matchmaking testing should be done via Firebase Console")
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Test failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Extensions

extension MatchmakingSettingsViewModel {
    
    /// Get formatted statistics for display
    var formattedStats: [StatInfo] {
        [
            StatInfo(title: "Total Matches", value: "\(totalMatches)", icon: "heart.circle.fill", color: .pink),
            StatInfo(title: "Connections", value: "\(successfulConnections)", icon: "message.circle.fill", color: .green),
            StatInfo(title: "Avg Similarity", value: String(format: "%.0f%%", averageSimilarity * 100), icon: "waveform.circle.fill", color: .purple),
            StatInfo(title: "Response Rate", value: String(format: "%.0f%%", responseRate * 100), icon: "checkmark.circle.fill", color: .blue)
        ]
    }
}

// MARK: - Supporting Models

struct StatInfo {
    let title: String
    let value: String
    let icon: String
    let color: Color
}

// Note: Firebase Functions SDK is not available in iOS
// Manual testing should be done via Firebase Console
