import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Daily Prompt Service

@MainActor
class DailyPromptService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentPrompt: DailyPrompt?
    @Published var userResponse: PromptResponse?
    @Published var promptLeaderboard: PromptLeaderboard?
    @Published var promptHistory: [DailyPrompt] = []
    @Published var userPromptStats: UserPromptStats?
    
    // Loading states
    @Published var isLoadingPrompt = false
    @Published var isLoadingResponse = false
    @Published var isLoadingLeaderboard = false
    @Published var isSubmittingResponse = false
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Real-time listeners
    private var promptListener: ListenerRegistration?
    private var leaderboardListener: ListenerRegistration?
    private var userStatsListener: ListenerRegistration?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    // Current user ID from Firebase Auth
    var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Initialization
    
    init() {
        setupAuthListener()
    }
    
    deinit {
        print("🗑️ DailyPromptService: deinit called")
        // Remove listeners directly without calling @MainActor method
        promptListener?.remove()
        leaderboardListener?.remove()
        userStatsListener?.remove()
        cancellables.removeAll()
    }
    
    private func setupAuthListener() {
        // Listen for auth changes and reload data accordingly
        NotificationCenter.default.publisher(for: .AuthStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadInitialData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    func loadInitialData() async {
        guard Auth.auth().currentUser != nil else { return }
        
        await loadActivePrompt()
        await loadUserPromptStats()
        await loadPromptHistory()
    }
    
    func refreshData() async {
        await loadActivePrompt()
        if let promptId = currentPrompt?.id {
            await loadUserResponse(promptId: promptId)
            await loadPromptLeaderboard(promptId: promptId)
        }
    }
    
    // MARK: - Active Prompt Management
    
    func loadActivePrompt() async {
        isLoadingPrompt = true
        defer { isLoadingPrompt = false }
        
        do {
            // Stop existing listener
            promptListener?.remove()
            
            // Set up real-time listener for active prompt
            promptListener = db.collection("dailyPrompts")
                .whereField("isActive", isEqualTo: true)
                .whereField("isArchived", isEqualTo: false)
                .order(by: "date", descending: true)
                .limit(to: 1)
                .addSnapshotListener { [weak self] snapshot, error in
                    Task { @MainActor in
                        if let error = error {
                            self?.handleError(error)
                            return
                        }
                        
                        if let document = snapshot?.documents.first {
                            do {
                                let prompt = try document.data(as: DailyPrompt.self)
                                await self?.handleNewActivePrompt(prompt)
                            } catch {
                                self?.handleError(error)
                            }
                        } else {
                            self?.currentPrompt = nil
                            self?.userResponse = nil
                            self?.promptLeaderboard = nil
                        }
                    }
                }
        }
    }
    
    private func handleNewActivePrompt(_ prompt: DailyPrompt) async {
        let previousPromptId = currentPrompt?.id
        currentPrompt = prompt
        
        // If this is a new prompt, load associated data
        if previousPromptId != prompt.id {
            await loadUserResponse(promptId: prompt.id)
            await loadPromptLeaderboard(promptId: prompt.id)
            
            // Post notification for new prompt
            NotificationCenter.default.post(
                name: .dailyPromptActivated,
                object: nil,
                userInfo: ["prompt": prompt]
            )
            
            // Track analytics
            AnalyticsService.shared.logEvent("daily_prompt_viewed", parameters: [
                "prompt_id": prompt.id,
                "prompt_category": prompt.category.rawValue,
                "prompt_title": prompt.title
            ])
        }
    }
    
    // MARK: - User Response Management
    
    func loadUserResponse(promptId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingResponse = true
        defer { isLoadingResponse = false }
        
        do {
            let snapshot = try await db.collection("promptResponses")
                .whereField("promptId", isEqualTo: promptId)
                .whereField("userId", isEqualTo: userId)
                .limit(to: 1)
                .getDocuments()
            
            if let document = snapshot.documents.first {
                userResponse = try document.data(as: PromptResponse.self)
            } else {
                userResponse = nil
            }
        } catch {
            handleError(error)
        }
    }
    
    func submitResponse(
        promptId: String,
        songId: String,
        songTitle: String,
        artistName: String,
        albumName: String? = nil,
        artworkUrl: String? = nil,
        appleMusicUrl: String? = nil,
        explanation: String? = nil,
        isPublic: Bool = true
    ) async -> Bool {
        
        guard let user = Auth.auth().currentUser else {
            handleError(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return false
        }
        
        // Check if user already responded
        if userResponse != nil {
            handleError(NSError(domain: "ResponseError", code: 409, userInfo: [NSLocalizedDescriptionKey: "You have already responded to this prompt"]))
            return false
        }
        
        isSubmittingResponse = true
        defer { isSubmittingResponse = false }
        
        do {
            // Get user profile for cached data
            let userProfile = try await fetchUserProfile(userId: user.uid)
            
            // Create response
            let response = PromptResponse(
                promptId: promptId,
                userId: user.uid,
                username: userProfile?.username ?? "Anonymous",
                userProfilePictureUrl: userProfile?.profilePictureUrl,
                songId: songId,
                songTitle: songTitle,
                artistName: artistName,
                albumName: albumName,
                artworkUrl: artworkUrl,
                appleMusicUrl: appleMusicUrl,
                explanation: explanation,
                isPublic: isPublic
            )
            
            // Submit to Firestore using batch operation
            let batch = db.batch()
            
            // Add the response
            let responseRef = db.collection("promptResponses").document(response.id)
            try batch.setData(from: response, forDocument: responseRef)
            
            // Update prompt response count
            let promptRef = db.collection("dailyPrompts").document(promptId)
            batch.updateData([
                "totalResponses": FieldValue.increment(Int64(1)),
                "featuredSongs": FieldValue.arrayUnion([songId])
            ], forDocument: promptRef)
            
            // Update user stats
            if let stats = userPromptStats {
                let updatedStats = updateUserStats(stats, newResponse: response)
                let statsRef = db.collection("userPromptStats").document(user.uid)
                try batch.setData(from: updatedStats, forDocument: statsRef)
            }
            
            // Commit batch
            try await batch.commit()
            
            // Update local state
            userResponse = response
            await updateLocalPromptCount(increment: 1)
            
            // Post notification
            NotificationCenter.default.post(
                name: .promptResponseSubmitted,
                object: nil,
                userInfo: ["response": response]
            )
            
            // Track analytics
            AnalyticsService.shared.logEvent("daily_prompt_response_submitted", parameters: [
                "prompt_id": promptId,
                "song_id": songId,
                "has_explanation": explanation != nil,
                "is_public": isPublic
            ])
            
            // Trigger leaderboard update
            await refreshLeaderboard(promptId: promptId)
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func updateResponse(
        responseId: String,
        explanation: String?,
        isPublic: Bool
    ) async -> Bool {
        
        guard let user = Auth.auth().currentUser,
              let response = userResponse,
              response.userId == user.uid else {
            handleError(NSError(domain: "AuthError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot update this response"]))
            return false
        }
        
        do {
            try await db.collection("promptResponses").document(responseId).updateData([
                "explanation": explanation as Any,
                "isPublic": isPublic
            ])
            
            // Update local state
            var updatedResponse = response
            updatedResponse.isPublic = isPublic
            userResponse = updatedResponse
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    // MARK: - Leaderboard Management
    
    func loadPromptLeaderboard(promptId: String) async {
        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }
        
        // Stop existing listener
        leaderboardListener?.remove()
        
        // Set up real-time listener for leaderboard
        leaderboardListener = db.collection("promptLeaderboards")
            .document(promptId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.handleError(error)
                        return
                    }
                    
                    if let document = snapshot, document.exists {
                        do {
                            self?.promptLeaderboard = try document.data(as: PromptLeaderboard.self)
                        } catch {
                            self?.handleError(error)
                        }
                    } else {
                        // Generate initial leaderboard
                        await self?.generateLeaderboard(promptId: promptId)
                    }
                }
            }
    }
    
    private func generateLeaderboard(promptId: String) async {
        do {
            // Fetch all responses for this prompt
            let snapshot = try await db.collection("promptResponses")
                .whereField("promptId", isEqualTo: promptId)
                .whereField("isPublic", isEqualTo: true)
                .whereField("isHidden", isEqualTo: false)
                .getDocuments()
            
            let responses = snapshot.documents.compactMap { doc in
                try? doc.data(as: PromptResponse.self)
            }
            
            // Calculate leaderboard
            let leaderboard = calculateLeaderboard(from: responses, promptId: promptId)
            
            // Save to Firestore
            try await db.collection("promptLeaderboards")
                .document(promptId)
                .setData(from: leaderboard)
            
            promptLeaderboard = leaderboard
            
        } catch {
            handleError(error)
        }
    }
    
    private func refreshLeaderboard(promptId: String) async {
        // Trigger a leaderboard recalculation
        await generateLeaderboard(promptId: promptId)
    }
    
    func fetchLeaderboard(for promptId: String) async -> PromptLeaderboard? {
        do {
            let document = try await db.collection("promptLeaderboards").document(promptId).getDocument()
            
            if document.exists {
                return try document.data(as: PromptLeaderboard.self)
            } else {
                // Generate leaderboard if it doesn't exist
                await generateLeaderboard(promptId: promptId)
                return promptLeaderboard
            }
        } catch {
            handleError(error)
            return nil
        }
    }
    
    private func calculateLeaderboard(from responses: [PromptResponse], promptId: String) -> PromptLeaderboard {
        // Group responses by song
        let groupedBySong = Dictionary(grouping: responses) { $0.songId }
        
        // Create song rankings
        var songRankings: [SongRanking] = []
        
        for (songId, songResponses) in groupedBySong {
            guard let firstResponse = songResponses.first else { continue }
            
            let voteCount = songResponses.count
            let sampleUsers = songResponses.prefix(5).map { response in
                ResponseUser(
                    userId: response.userId,
                    username: response.username,
                    profilePictureUrl: response.userProfilePictureUrl,
                    explanation: response.explanation
                )
            }
            
            let ranking = SongRanking(
                songId: songId,
                songTitle: firstResponse.songTitle,
                artistName: firstResponse.artistName,
                albumName: firstResponse.albumName,
                artworkUrl: firstResponse.artworkUrl,
                appleMusicUrl: firstResponse.appleMusicUrl,
                voteCount: voteCount,
                sampleUsers: Array(sampleUsers)
            )
            
            songRankings.append(ranking)
        }
        
        // Sort by vote count and calculate percentages and ranks
        songRankings.sort { $0.voteCount > $1.voteCount }
        
        let totalResponses = responses.count
        for (index, var ranking) in songRankings.enumerated() {
            ranking.rank = index + 1
            ranking.percentage = totalResponses > 0 ? Double(ranking.voteCount) / Double(totalResponses) * 100 : 0
            songRankings[index] = ranking
        }
        
        // Calculate top genres (simplified - would need genre classification)
        let topGenres: [String] = [] // TODO: Implement genre classification
        
        return PromptLeaderboard(
            promptId: promptId,
            songRankings: songRankings,
            totalResponses: totalResponses
        )
    }
    
    // MARK: - User Statistics
    
    func loadUserPromptStats() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Set up real-time listener for user stats
        userStatsListener = db.collection("userPromptStats")
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.handleError(error)
                        return
                    }
                    
                    if let document = snapshot, document.exists {
                        do {
                            self?.userPromptStats = try document.data(as: UserPromptStats.self)
                        } catch {
                            self?.handleError(error)
                        }
                    } else {
                        // Create initial stats
                        let initialStats = UserPromptStats(userId: userId)
                        self?.userPromptStats = initialStats
                        
                        // Save to Firestore
                        do {
                            try await self?.db.collection("userPromptStats")
                                .document(userId)
                                .setData(from: initialStats)
                        } catch {
                            self?.handleError(error)
                        }
                    }
                }
            }
    }
    
    private func updateUserStats(_ stats: UserPromptStats, newResponse: PromptResponse) -> UserPromptStats {
        var updatedStats = stats
        
        // Update basic counts
        updatedStats.totalResponses += 1
        
        // Update streak
        let calendar = Calendar.current
        let today = Date()
        
        if let lastResponseDate = stats.lastResponseDate {
            let daysBetween = calendar.dateComponents([.day], from: lastResponseDate, to: today).day ?? 0
            
            if daysBetween == 1 {
                // Consecutive day - continue streak
                updatedStats.currentStreak += 1
                updatedStats.longestStreak = max(updatedStats.longestStreak, updatedStats.currentStreak)
            } else if daysBetween == 0 {
                // Same day - no streak change
            } else {
                // Streak broken
                updatedStats.currentStreak = 1
            }
        } else {
            // First response
            updatedStats.currentStreak = 1
            updatedStats.longestStreak = 1
        }
        
        updatedStats.lastResponseDate = today
        
        // Update favorite categories
        let category = currentPrompt?.category ?? .random
        updatedStats.favoriteCategories[category] = (updatedStats.favoriteCategories[category] ?? 0) + 1
        
        // Calculate average response time (simplified)
        if let promptCreatedAt = currentPrompt?.createdAt {
            let responseTime = newResponse.submittedAt.timeIntervalSince(promptCreatedAt)
            if let currentAverage = updatedStats.averageResponseTime {
                updatedStats.averageResponseTime = (currentAverage + responseTime) / 2
            } else {
                updatedStats.averageResponseTime = responseTime
            }
        }
        
        return updatedStats
    }
    
    // MARK: - Prompt History
    
    func loadPromptHistory(limit: Int = 30) async {
        do {
            // Only load prompts that are in the past or currently active (not future scheduled prompts)
            let snapshot = try await db.collection("dailyPrompts")
                .whereField("date", isLessThanOrEqualTo: Timestamp(date: Date()))
                .order(by: "date", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            promptHistory = snapshot.documents.compactMap { doc in
                try? doc.data(as: DailyPrompt.self)
            }
            
        } catch {
            handleError(error)
        }
    }
    
    func loadMorePromptHistory() async {
        guard !promptHistory.isEmpty else { return }
        
        let lastPrompt = promptHistory.last!
        
        do {
            // Only load more prompts that are in the past or currently active
            let snapshot = try await db.collection("dailyPrompts")
                .whereField("date", isLessThanOrEqualTo: Timestamp(date: Date()))
                .order(by: "date", descending: true)
                .start(afterDocument: try await db.collection("dailyPrompts").document(lastPrompt.id).getDocument())
                .limit(to: 20)
                .getDocuments()
            
            let newPrompts = snapshot.documents.compactMap { doc in
                try? doc.data(as: DailyPrompt.self)
            }
            
            promptHistory.append(contentsOf: newPrompts)
            
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Response Interactions
    
    func fetchResponsesForPrompt(_ promptId: String, limit: Int = 50) async -> [PromptResponse] {
        do {
            let snapshot = try await db.collection("promptResponses")
                .whereField("promptId", isEqualTo: promptId)
                .whereField("isPublic", isEqualTo: true)
                .whereField("isHidden", isEqualTo: false)
                .order(by: "submittedAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc in
                try? doc.data(as: PromptResponse.self)
            }
            
        } catch {
            handleError(error)
            return []
        }
    }
    
    func fetchFriendsResponses(_ promptId: String) async -> [PromptResponse] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        
        do {
            // Get user's following list
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let userData = userDoc.data() ?? [:]
            let followingIds = userData["following"] as? [String] ?? []
            
            guard !followingIds.isEmpty else { return [] }
            
            // Batch fetch friends' responses (Firestore 'in' query limited to 10)
            var allResponses: [PromptResponse] = []
            
            for batch in followingIds.chunked(into: 10) {
                let snapshot = try await db.collection("promptResponses")
                    .whereField("promptId", isEqualTo: promptId)
                    .whereField("userId", in: batch)
                    .whereField("isPublic", isEqualTo: true)
                    .whereField("isHidden", isEqualTo: false)
                    .getDocuments()
                
                let batchResponses = snapshot.documents.compactMap { doc in
                    try? doc.data(as: PromptResponse.self)
                }
                
                allResponses.append(contentsOf: batchResponses)
            }
            
            return allResponses.sorted { $0.submittedAt > $1.submittedAt }
            
        } catch {
            handleError(error)
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateLocalPromptCount(increment: Int) async {
        guard var prompt = currentPrompt else { return }
        prompt.totalResponses += increment
        currentPrompt = prompt
    }
    
    private func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return try? snapshot.data(as: UserProfile.self)
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        
        // Log error for debugging
        print("❌ DailyPromptService Error: \(error)")
        
        // Track error in analytics
        AnalyticsService.shared.logError(error: error, context: "daily_prompt_service_error")
    }
    
    private func stopAllListeners() {
        promptListener?.remove()
        leaderboardListener?.remove()
        userStatsListener?.remove()
    }
    
    // MARK: - Public Computed Properties
    
    var hasUserResponded: Bool {
        return userResponse != nil
    }
    
    var canUserRespond: Bool {
        guard let prompt = currentPrompt else { return false }
        return prompt.isActive && !hasUserResponded && Date() < prompt.expiresAt
    }
    
    var timeUntilExpiration: TimeInterval? {
        guard let prompt = currentPrompt else { return nil }
        return prompt.expiresAt.timeIntervalSince(Date())
    }
    
    var userCurrentStreak: Int {
        return userPromptStats?.currentStreak ?? 0
    }
    
    var userLongestStreak: Int {
        return userPromptStats?.longestStreak ?? 0
    }
    
    var userTotalResponses: Int {
        return userPromptStats?.totalResponses ?? 0
    }
}

// Note: chunked(into:) extension already exists in UserProfileViewModel

// MARK: - Notification Extensions

extension Notification.Name {
    static let AuthStateDidChange = Notification.Name("AuthStateDidChange")
}
