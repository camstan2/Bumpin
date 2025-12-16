import UIKit

/// Centralized haptic feedback service for log engagement interactions
/// Provides consistent tactile feedback across all engagement buttons (like, comment, repost, etc.)
enum LogEngagementHaptics {
    
    // MARK: - Like Actions
    
    /// Haptic feedback when user likes a log (medium impact - satisfying positive action)
    static func like() {
        HapticManager.impact(style: .medium)
    }
    
    /// Haptic feedback when user unlikes a log (light impact - softer removal)
    static func unlike() {
        HapticManager.impact(style: .light)
    }
    
    // MARK: - Comment Actions
    
    /// Haptic feedback when user taps comment button (light impact - navigation action)
    static func comment() {
        HapticManager.impact(style: .light)
    }
    
    // MARK: - Dislike Actions
    
    /// Haptic feedback when user toggles thumbs down (medium impact - significant negative feedback)
    static func thumbsDown() {
        HapticManager.impact(style: .medium)
    }
    
    // MARK: - Repost Actions
    
    /// Haptic feedback when user reposts a log (medium impact - sharing action)
    static func repost() {
        HapticManager.impact(style: .medium)
    }
    
    /// Haptic feedback when user removes a repost (light impact - removal action)
    static func unrepost() {
        HapticManager.impact(style: .light)
    }
    
    // MARK: - Vote Actions
    
    /// Haptic feedback when user marks a review as helpful (light impact - positive vote)
    static func helpful() {
        HapticManager.impact(style: .light)
    }
    
    /// Haptic feedback when user marks a review as unhelpful (light impact - negative vote)
    static func unhelpful() {
        HapticManager.impact(style: .light)
    }
    
    // MARK: - Navigation Actions
    
    /// Haptic feedback when user opens activity view (light impact - navigation)
    static func viewActivity() {
        HapticManager.impact(style: .light)
    }
    
    // MARK: - Success Notifications
    
    /// Haptic feedback for successful engagement action (success notification)
    static func success() {
        HapticManager.notification(type: .success)
    }
    
    /// Haptic feedback for failed engagement action (error notification)
    static func error() {
        HapticManager.notification(type: .error)
    }
}

