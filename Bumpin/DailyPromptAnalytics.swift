import Foundation
import SwiftUI

// MARK: - Daily Prompt Analytics Tracker

class DailyPromptAnalytics {
    static let shared = DailyPromptAnalytics()
    private init() {}
    
    // MARK: - Core Events
    
    /// Track when user views the daily prompt tab
    func trackTabViewed() {
        AnalyticsService.shared.logEvent("daily_prompt_tab_viewed", parameters: [
            "timestamp": Date().timeIntervalSince1970,
            "user_authenticated": isUserAuthenticated()
        ])
    }
    
    /// Track when user views a specific prompt
    func trackPromptViewed(_ promptId: String, category: PromptCategory, hasUserResponded: Bool) {
        AnalyticsService.shared.logEvent("daily_prompt_viewed", parameters: [
            "prompt_id": promptId,
            "prompt_category": category.rawValue,
            "user_has_responded": hasUserResponded,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track when user starts response submission
    func trackResponseSubmissionStarted(_ promptId: String) {
        AnalyticsService.shared.logEvent("prompt_response_submission_started", parameters: [
            "prompt_id": promptId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track successful response submission
    func trackResponseSubmitted(_ promptId: String, songId: String, hasExplanation: Bool, isPublic: Bool, submissionTime: TimeInterval) {
        AnalyticsService.shared.logEvent("prompt_response_submitted", parameters: [
            "prompt_id": promptId,
            "song_id": songId,
            "has_explanation": hasExplanation,
            "is_public": isPublic,
            "submission_time_seconds": submissionTime,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track response submission failure
    func trackResponseSubmissionFailed(_ promptId: String, error: String) {
        AnalyticsService.shared.logEvent("prompt_response_submission_failed", parameters: [
            "prompt_id": promptId,
            "error": error,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Social Interaction Events
    
    /// Track when user likes a response
    func trackResponseLiked(_ responseId: String, promptId: String) {
        AnalyticsService.shared.logEvent("prompt_response_liked", parameters: [
            "response_id": responseId,
            "prompt_id": promptId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track when user unlikes a response
    func trackResponseUnliked(_ responseId: String, promptId: String) {
        AnalyticsService.shared.logEvent("prompt_response_unliked", parameters: [
            "response_id": responseId,
            "prompt_id": promptId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track when user adds a comment
    func trackCommentAdded(_ responseId: String, promptId: String, commentLength: Int, isReply: Bool) {
        AnalyticsService.shared.logEvent("prompt_response_commented", parameters: [
            "response_id": responseId,
            "prompt_id": promptId,
            "comment_length": commentLength,
            "is_reply": isReply,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track when user likes a comment
    func trackCommentLiked(_ commentId: String, responseId: String) {
        AnalyticsService.shared.logEvent("prompt_comment_liked", parameters: [
            "comment_id": commentId,
            "response_id": responseId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Discovery & Navigation Events
    
    /// Track when user views leaderboard
    func trackLeaderboardViewed(_ promptId: String, tab: String) {
        AnalyticsService.shared.logEvent("prompt_leaderboard_viewed", parameters: [
            "prompt_id": promptId,
            "leaderboard_tab": tab,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track when user views prompt history
    func trackHistoryViewed() {
        AnalyticsService.shared.logEvent("prompt_history_viewed", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track when user views a specific historical prompt
    func trackHistoricalPromptViewed(_ promptId: String, daysAgo: Int) {
        AnalyticsService.shared.logEvent("historical_prompt_viewed", parameters: [
            "prompt_id": promptId,
            "days_ago": daysAgo,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track when user plays a song from a response
    func trackSongPlayedFromResponse(_ songId: String, responseId: String, promptId: String) {
        AnalyticsService.shared.logEvent("song_played_from_response", parameters: [
            "song_id": songId,
            "response_id": responseId,
            "prompt_id": promptId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - User Engagement & Retention
    
    /// Track user's streak milestone
    func trackStreakMilestone(_ streak: Int, promptId: String) {
        AnalyticsService.shared.logEvent("prompt_streak_milestone", parameters: [
            "streak_count": streak,
            "prompt_id": promptId,
            "milestone_type": getStreakMilestoneType(streak),
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track first-time user experience
    func trackFirstResponse(_ promptId: String, songId: String) {
        AnalyticsService.shared.logEvent("first_prompt_response", parameters: [
            "prompt_id": promptId,
            "song_id": songId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track user returning after a break
    func trackUserReturn(_ daysSinceLastResponse: Int, promptId: String) {
        AnalyticsService.shared.logEvent("prompt_user_return", parameters: [
            "days_since_last_response": daysSinceLastResponse,
            "prompt_id": promptId,
            "return_type": getUserReturnType(daysSinceLastResponse),
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Content & Discovery
    
    /// Track music discovery through prompts
    func trackMusicDiscovered(_ songId: String, discoveryMethod: String, promptId: String) {
        AnalyticsService.shared.logEvent("music_discovered_via_prompt", parameters: [
            "song_id": songId,
            "discovery_method": discoveryMethod, // "leaderboard", "friend_response", "random_response"
            "prompt_id": promptId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track sharing behavior
    func trackContentShared(_ contentType: String, contentId: String, shareMethod: String) {
        AnalyticsService.shared.logEvent("prompt_content_shared", parameters: [
            "content_type": contentType, // "response", "leaderboard", "prompt"
            "content_id": contentId,
            "share_method": shareMethod,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track search and filtering behavior
    func trackPromptFiltered(_ category: PromptCategory) {
        AnalyticsService.shared.logEvent("prompt_category_filtered", parameters: [
            "category": category.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Performance & Technical
    
    /// Track loading performance
    func trackLoadingPerformance(_ screen: String, loadTime: TimeInterval) {
        AnalyticsService.shared.logEvent("prompt_loading_performance", parameters: [
            "screen": screen,
            "load_time_ms": loadTime * 1000,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track error occurrences
    func trackError(_ errorType: String, errorMessage: String, context: [String: Any] = [:]) {
        var parameters: [String: Any] = [
            "error_type": errorType,
            "error_message": errorMessage,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Merge context
        for (key, value) in context {
            parameters[key] = value
        }
        
        AnalyticsService.shared.logEvent("prompt_error_occurred", parameters: parameters)
    }
    
    // MARK: - Admin & Content Management
    
    /// Track admin actions
    func trackAdminAction(_ action: String, promptId: String? = nil, details: [String: Any] = [:]) {
        var parameters: [String: Any] = [
            "admin_action": action,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let promptId = promptId {
            parameters["prompt_id"] = promptId
        }
        
        // Merge details
        for (key, value) in details {
            parameters[key] = value
        }
        
        AnalyticsService.shared.logEvent("prompt_admin_action", parameters: parameters)
    }
    
    /// Track prompt performance metrics
    func trackPromptPerformance(_ promptId: String, metrics: PromptPerformanceMetrics) {
        AnalyticsService.shared.logEvent("prompt_performance_metrics", parameters: [
            "prompt_id": promptId,
            "total_responses": metrics.totalResponses,
            "unique_users": metrics.uniqueUsers,
            "avg_response_time": metrics.averageResponseTime,
            "engagement_rate": metrics.engagementRate,
            "completion_rate": metrics.completionRate,
            "social_interactions": metrics.socialInteractions,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    // MARK: - Helper Methods
    
    private func isUserAuthenticated() -> Bool {
        // Implementation would check Firebase Auth state
        return true // Placeholder
    }
    
    private func getStreakMilestoneType(_ streak: Int) -> String {
        switch streak {
        case 3: return "first_milestone"
        case 7: return "week_milestone"
        case 14: return "two_week_milestone"
        case 30: return "month_milestone"
        case 100: return "hundred_milestone"
        default: return "custom_milestone"
        }
    }
    
    private func getUserReturnType(_ days: Int) -> String {
        switch days {
        case 1: return "next_day_return"
        case 2...7: return "week_return"
        case 8...30: return "month_return"
        default: return "long_absence_return"
        }
    }
}

// MARK: - Performance Metrics Model

struct PromptPerformanceMetrics {
    let totalResponses: Int
    let uniqueUsers: Int
    let averageResponseTime: TimeInterval
    let engagementRate: Double // likes + comments / responses
    let completionRate: Double // responses / views
    let socialInteractions: Int // total likes + comments
}

// MARK: - Analytics Verification View

struct DailyPromptAnalyticsVerificationView: View {
    @State private var events: [AnalyticsEvent] = []
    @State private var isRecording = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Recording status
                HStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text(isRecording ? "Recording Events" : "Not Recording")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(isRecording ? "Stop" : "Start") {
                        isRecording.toggle()
                        if isRecording {
                            startRecording()
                        } else {
                            stopRecording()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                // Test buttons
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    testButton("Tab Viewed") {
                        DailyPromptAnalytics.shared.trackTabViewed()
                    }
                    
                    testButton("Prompt Viewed") {
                        DailyPromptAnalytics.shared.trackPromptViewed("test_prompt", category: .mood, hasUserResponded: false)
                    }
                    
                    testButton("Response Submitted") {
                        DailyPromptAnalytics.shared.trackResponseSubmitted("test_prompt", songId: "test_song", hasExplanation: true, isPublic: true, submissionTime: 45.0)
                    }
                    
                    testButton("Response Liked") {
                        DailyPromptAnalytics.shared.trackResponseLiked("test_response", promptId: "test_prompt")
                    }
                    
                    testButton("Leaderboard Viewed") {
                        DailyPromptAnalytics.shared.trackLeaderboardViewed("test_prompt", tab: "songs")
                    }
                    
                    testButton("Streak Milestone") {
                        DailyPromptAnalytics.shared.trackStreakMilestone(7, promptId: "test_prompt")
                    }
                }
                .padding(.horizontal)
                
                // Events list
                List(events, id: \.id) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text(timeFormatter.string(from: event.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !event.parameters.isEmpty {
                            Text(parametersString(event.parameters))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Analytics Verification")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        events.removeAll()
                    }
                }
            }
        }
    }
    
    private func testButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func startRecording() {
        // In a real implementation, this would hook into the analytics service
        // to capture events as they're sent
    }
    
    private func stopRecording() {
        // Stop capturing events
    }
    
    private func parametersString(_ parameters: [String: Any]) -> String {
        return parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Analytics Event Model

struct AnalyticsEvent {
    let id = UUID()
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
}

#Preview {
    DailyPromptAnalyticsVerificationView()
}
