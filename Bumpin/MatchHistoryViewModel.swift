import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Match History ViewModel

@MainActor
class MatchHistoryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var matches: [WeeklyMatch] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    /// Matches grouped by week for easier display
    var groupedMatches: [String: [WeeklyMatch]] {
        Dictionary(grouping: matches) { $0.week }
    }
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadMatches()
    }
    
    // MARK: - Data Loading
    
    /// Load all matches for the current user
    func loadMatches() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("weeklyMatches")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Failed to load matches: \(error.localizedDescription)"
                        print("❌ Error loading matches: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.matches = []
                        return
                    }
                    
                    self.matches = documents.compactMap { document in
                        do {
                            return try document.data(as: WeeklyMatch.self)
                        } catch {
                            print("❌ Error decoding match: \(error.localizedDescription)")
                            return nil
                        }
                    }
                    
                    print("✅ Loaded \(self.matches.count) matches")
                }
            }
    }
    
    /// Refresh matches with pull-to-refresh
    func refreshMatches() async {
        await withCheckedContinuation { continuation in
            loadMatches()
            
            // Wait for loading to complete
            $isLoading
                .filter { !$0 }
                .first()
                .sink { _ in
                    continuation.resume()
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Match Actions
    
    /// Mark a match as responded (when user messages the matched person)
    func markMatchAsResponded(_ match: WeeklyMatch) {
        guard let userId = Auth.auth().currentUser?.uid,
              match.userId == userId else { return }
        
        let updates: [String: Any] = [
            "userResponded": true,
            "responseTimestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("weeklyMatches").document(match.id).updateData(updates) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error updating match response: \(error.localizedDescription)")
                } else {
                    print("✅ Marked match as responded")
                    
                    // Update local data
                    if let index = self?.matches.firstIndex(where: { $0.id == match.id }) {
                        self?.matches[index].userResponded = true
                    }
                }
            }
        }
    }
    
    /// Mark a match as successful connection
    func markMatchAsSuccessful(_ match: WeeklyMatch) {
        guard let userId = Auth.auth().currentUser?.uid,
              match.userId == userId else { return }
        
        let updates: [String: Any] = [
            "matchSuccess": true,
            "connectionQuality": "connection"
        ]
        
        db.collection("weeklyMatches").document(match.id).updateData(updates) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error updating match success: \(error.localizedDescription)")
                } else {
                    print("✅ Marked match as successful")
                    
                    // Update local data
                    if let index = self?.matches.firstIndex(where: { $0.id == match.id }) {
                        self?.matches[index].matchSuccess = true
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Get match statistics for display
    var matchStatistics: MatchStatistics {
        let totalMatches = matches.count
        let respondedMatches = matches.filter { $0.userResponded }.count
        let successfulMatches = matches.filter { $0.matchSuccess == true }.count
        
        let averageSimilarity = matches.isEmpty ? 0.0 : 
            matches.map { $0.similarityScore }.reduce(0, +) / Double(matches.count)
        
        let responseRate = totalMatches > 0 ? Double(respondedMatches) / Double(totalMatches) : 0.0
        let successRate = totalMatches > 0 ? Double(successfulMatches) / Double(totalMatches) : 0.0
        
        // Get most common shared artists
        let allSharedArtists = matches.flatMap { $0.sharedArtists }
        let artistCounts = Dictionary(allSharedArtists.map { ($0, 1) }, uniquingKeysWith: +)
        let topSharedArtists = artistCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
        
        return MatchStatistics(
            totalMatches: totalMatches,
            respondedMatches: respondedMatches,
            successfulMatches: successfulMatches,
            averageSimilarity: averageSimilarity,
            responseRate: responseRate,
            successRate: successRate,
            topSharedArtists: Array(topSharedArtists)
        )
    }
    
    // MARK: - Helper Methods
    
    /// Get matches for a specific week
    func matches(for week: String) -> [WeeklyMatch] {
        matches.filter { $0.week == week }
    }
    
    /// Get the most recent match
    var mostRecentMatch: WeeklyMatch? {
        matches.first
    }
    
    /// Check if user has any matches
    var hasMatches: Bool {
        !matches.isEmpty
    }
}

// MARK: - Supporting Models

struct MatchStatistics {
    let totalMatches: Int
    let respondedMatches: Int
    let successfulMatches: Int
    let averageSimilarity: Double
    let responseRate: Double
    let successRate: Double
    let topSharedArtists: [String]
    
    var formattedAverageSimilarity: String {
        String(format: "%.0f%%", averageSimilarity * 100)
    }
    
    var formattedResponseRate: String {
        String(format: "%.0f%%", responseRate * 100)
    }
    
    var formattedSuccessRate: String {
        String(format: "%.0f%%", successRate * 100)
    }
}
