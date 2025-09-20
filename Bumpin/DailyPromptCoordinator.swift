import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Daily Prompt Coordinator

/// Central coordinator for the Daily Prompt feature
/// Manages all prompt-related services and provides a unified interface
@MainActor
class DailyPromptCoordinator: ObservableObject {
    
    // MARK: - Services
    @Published var promptService = DailyPromptService()
    @Published var interactionService = PromptInteractionService()
    @Published var adminService = PromptAdminService()
    
    // MARK: - UI State
    @Published var showPromptDetail = false
    @Published var showResponseSubmission = false
    @Published var showLeaderboard = false
    @Published var showPromptHistory = false
    @Published var selectedResponse: PromptResponse?
    @Published var selectedPrompt: DailyPrompt?
    
    // Navigation
    @Published var promptNavigationPath = NavigationPath()
    
    // Global loading state
    @Published var isInitializing = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        Task {
            await initialize()
        }
    }
    
    private func setupBindings() {
        // Listen for prompt changes to update interactions
        promptService.$currentPrompt
            .compactMap { $0 }
            .sink { [weak self] prompt in
                Task { @MainActor in
                    await self?.handlePromptChanged(prompt)
                }
            }
            .store(in: &cancellables)
        
        // Listen for response submissions to refresh leaderboard
        NotificationCenter.default.publisher(for: .promptResponseSubmitted)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleResponseSubmitted(notification)
                }
            }
            .store(in: &cancellables)
        
        // Listen for new prompts to show notifications
        NotificationCenter.default.publisher(for: .dailyPromptActivated)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleNewPromptActivated(notification)
                }
            }
            .store(in: &cancellables)
    }
    
    private func initialize() async {
        isInitializing = true
        defer { isInitializing = false }
        
        // Initialize prompt service first
        await promptService.loadInitialData()
        
        // Load interactions for current prompt if available
        if let prompt = promptService.currentPrompt {
            await handlePromptChanged(prompt)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handlePromptChanged(_ prompt: DailyPrompt) async {
        selectedPrompt = prompt
        
        // Load responses for interaction preloading
        let responses = await promptService.fetchResponsesForPrompt(prompt.id, limit: 20)
        await interactionService.preloadInteractionsForPrompt(prompt.id, responses: responses)
    }
    
    private func handleResponseSubmitted(_ notification: Notification) async {
        guard notification.userInfo?["response"] is PromptResponse else { return }
        
        // Refresh leaderboard
        await promptService.refreshData()
        
        // Show success feedback
        showResponseSubmissionSuccess()
        
        // Track achievement if it's user's first response
        if promptService.userTotalResponses == 1 {
            trackFirstResponseAchievement()
        }
        
        // Check for streak achievements
        checkStreakAchievements()
    }
    
    private func handleNewPromptActivated(_ notification: Notification) async {
        guard let prompt = notification.userInfo?["prompt"] as? DailyPrompt else { return }
        
        // Show new prompt notification
        showNewPromptNotification(prompt)
        
        // Schedule local notification for tomorrow's prompt reminder
        schedulePromptReminder()
    }
    
    // MARK: - Public Interface
    
    /// Refresh all prompt data
    func refreshAll() async {
        await promptService.refreshData()
        
        if let prompt = promptService.currentPrompt {
            let responses = await promptService.fetchResponsesForPrompt(prompt.id)
            await interactionService.preloadInteractionsForPrompt(prompt.id, responses: responses)
        }
    }
    
    /// Submit a response to the current prompt
    func submitResponse(
        songId: String,
        songTitle: String,
        artistName: String,
        albumName: String? = nil,
        artworkUrl: String? = nil,
        appleMusicUrl: String? = nil,
        explanation: String? = nil,
        isPublic: Bool = true
    ) async -> Bool {
        
        guard let prompt = promptService.currentPrompt else { return false }
        
        let success = await promptService.submitResponse(
            promptId: prompt.id,
            songId: songId,
            songTitle: songTitle,
            artistName: artistName,
            albumName: albumName,
            artworkUrl: artworkUrl,
            appleMusicUrl: appleMusicUrl,
            explanation: explanation,
            isPublic: isPublic
        )
        
        if success {
            showResponseSubmission = false
        }
        
        return success
    }
    
    /// Navigate to prompt detail view
    func showPromptDetail(_ prompt: DailyPrompt) {
        selectedPrompt = prompt
        showPromptDetail = true
    }
    
    /// Navigate to response detail view
    func showResponseDetail(_ response: PromptResponse) {
        selectedResponse = response
        
        // Load interactions for this response
        Task {
            await interactionService.loadLikesForResponse(response.id)
            await interactionService.loadCommentsForResponse(response.id)
        }
    }
    
    /// Show leaderboard for current or selected prompt
    func showLeaderboardView(_ prompt: DailyPrompt? = nil) {
        selectedPrompt = prompt ?? promptService.currentPrompt
        showLeaderboard = true
    }
    
    /// Toggle like on a response
    func toggleLikeResponse(_ response: PromptResponse) async -> Bool {
        guard let prompt = selectedPrompt ?? promptService.currentPrompt else { return false }
        
        return await interactionService.toggleLikeResponse(response.id, promptId: prompt.id)
    }
    
    /// Add comment to a response
    func addComment(
        to response: PromptResponse,
        text: String,
        replyTo comment: PromptResponseComment? = nil
    ) async -> Bool {
        
        guard let prompt = selectedPrompt ?? promptService.currentPrompt else { return false }
        
        return await interactionService.addComment(
            to: response.id,
            promptId: prompt.id,
            text: text,
            replyToCommentId: comment?.id,
            replyToUsername: comment?.username
        )
    }
    
    /// Get responses for current prompt with friends prioritized
    func getResponsesForCurrentPrompt(includeFriends: Bool = true) async -> [PromptResponse] {
        guard let prompt = promptService.currentPrompt else { return [] }
        
        if includeFriends {
            let friendsResponses = await promptService.fetchFriendsResponses(prompt.id)
            let allResponses = await promptService.fetchResponsesForPrompt(prompt.id)
            
            // Combine and deduplicate, with friends first
            var combined: [PromptResponse] = []
            let friendIds = Set(friendsResponses.map { $0.userId })
            
            // Add friends responses first
            combined.append(contentsOf: friendsResponses)
            
            // Add non-friend responses
            let nonFriendResponses = allResponses.filter { !friendIds.contains($0.userId) }
            combined.append(contentsOf: nonFriendResponses)
            
            return combined
        } else {
            return await promptService.fetchResponsesForPrompt(prompt.id)
        }
    }
    
    // MARK: - Admin Functions
    
    /// Create a new prompt (admin only)
    func createPrompt(
        title: String,
        description: String?,
        category: PromptCategory,
        scheduledDate: Date? = nil,
        activateImmediately: Bool = false
    ) async -> Bool {
        
        let success = await adminService.createPrompt(
            title: title,
            description: description,
            category: category,
            scheduledDate: scheduledDate,
            activateImmediately: activateImmediately
        )
        
        if success && activateImmediately {
            await promptService.refreshData()
        }
        
        return success
    }
    
    /// Activate a scheduled prompt (admin only)
    func activatePrompt(_ promptId: String) async -> Bool {
        let success = await adminService.activatePrompt(promptId)
        
        if success {
            await promptService.refreshData()
        }
        
        return success
    }
    
    // MARK: - Analytics & Insights
    
    /// Get user's prompt statistics
    func getUserStats() -> UserPromptStats? {
        return promptService.userPromptStats
    }
    
    /// Get leaderboard for current prompt
    func getCurrentLeaderboard() -> PromptLeaderboard? {
        return promptService.promptLeaderboard
    }
    
    /// Track user engagement with prompts
    func trackPromptEngagement(_ action: String, promptId: String? = nil) {
        let id = promptId ?? promptService.currentPrompt?.id ?? "unknown"
        
        AnalyticsService.shared.logEvent("daily_prompt_engagement", parameters: [
            "action": action,
            "prompt_id": id,
            "user_has_responded": promptService.hasUserResponded,
            "user_streak": promptService.userCurrentStreak
        ])
    }
    
    // MARK: - Notifications & Feedback
    
    private func showResponseSubmissionSuccess() {
        // Could show a toast or banner
        // For now, just track analytics
        AnalyticsService.shared.logEvent("prompt_response_success_feedback_shown")
    }
    
    private func showNewPromptNotification(_ prompt: DailyPrompt) {
        // Could show in-app notification or banner
        print("🎯 New prompt available: \(prompt.title)")
    }
    
    private func schedulePromptReminder() {
        // Could schedule local notification for tomorrow
        // Implementation depends on notification preferences
    }
    
    // MARK: - Achievements & Gamification
    
    private func trackFirstResponseAchievement() {
        AnalyticsService.shared.logEvent("achievement_first_prompt_response", parameters: [
            "prompt_id": promptService.currentPrompt?.id ?? "unknown"
        ])
    }
    
    private func checkStreakAchievements() {
        let streak = promptService.userCurrentStreak
        
        let milestones = [3, 7, 14, 30, 100]
        
        if milestones.contains(streak) {
            AnalyticsService.shared.logEvent("achievement_prompt_streak", parameters: [
                "streak_count": streak
            ])
        }
    }
    
    // MARK: - Computed Properties
    
    /// Current prompt is available and user can respond
    var canRespondToCurrentPrompt: Bool {
        return promptService.canUserRespond
    }
    
    /// User has already responded to current prompt
    var hasRespondedToCurrentPrompt: Bool {
        return promptService.hasUserResponded
    }
    
    /// Current prompt (if any)
    var currentPrompt: DailyPrompt? {
        return promptService.currentPrompt
    }
    
    /// User's response to current prompt (if any)
    var currentUserResponse: PromptResponse? {
        return promptService.userResponse
    }
    
    /// Time remaining to respond to current prompt
    var timeUntilCurrentPromptExpires: TimeInterval? {
        return promptService.timeUntilExpiration
    }
    
    /// User's current streak
    var userStreak: Int {
        return promptService.userCurrentStreak
    }
    
    /// Total number of prompts user has responded to
    var userTotalResponses: Int {
        return promptService.userTotalResponses
    }
    
    /// Is any service currently loading
    var isLoading: Bool {
        return isInitializing ||
               promptService.isLoadingPrompt ||
               promptService.isSubmittingResponse ||
               interactionService.isLoadingLikes ||
               interactionService.isLoadingComments
    }
    
    /// Any error from services
    var hasError: Bool {
        return promptService.showError ||
               interactionService.showError ||
               adminService.showError
    }
    
    /// Combined error message
    var errorMessage: String? {
        return promptService.errorMessage ??
               interactionService.errorMessage ??
               adminService.errorMessage
    }
}

// MARK: - Helper Extensions

extension DailyPromptCoordinator {
    
    /// Format time remaining until prompt expires
    func formatTimeRemaining() -> String? {
        guard let timeRemaining = timeUntilCurrentPromptExpires, timeRemaining > 0 else {
            return nil
        }
        
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes)m remaining"
        }
    }
    
    /// Get user's favorite prompt categories
    func getUserFavoriteCategories() -> [PromptCategory] {
        guard let stats = promptService.userPromptStats else { return [] }
        
        return stats.favoriteCategories
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    /// Check if user is on a streak
    var isUserOnStreak: Bool {
        return promptService.userCurrentStreak > 1
    }
    
    /// Get streak status message
    var streakStatusMessage: String {
        let streak = promptService.userCurrentStreak
        
        if streak == 0 {
            return "Start your streak today!"
        } else if streak == 1 {
            return "Great start! Keep it going tomorrow."
        } else {
            return "🔥 \(streak) day streak! Amazing!"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension DailyPromptCoordinator {
    
    /// Create mock coordinator for previews
    @MainActor
    static func mock() -> DailyPromptCoordinator {
        return DailyPromptMockData.createMockCoordinator(userHasResponded: false)
    }
    
    /// Create mock coordinator with user response
    @MainActor
    static func mockWithResponse() -> DailyPromptCoordinator {
        return DailyPromptMockData.createMockCoordinator(userHasResponded: true)
    }
}
#endif
