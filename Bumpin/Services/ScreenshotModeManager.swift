import Foundation

/// Temporary screenshot mode manager for App Store screenshots
/// TO ENABLE: Set usePlaceholders to true
/// TO DISABLE: Set usePlaceholders to false
/// 
/// IMPORTANT: After taking screenshots, ALWAYS set this back to false!
final class ScreenshotModeManager {
    static let shared = ScreenshotModeManager()
    
    /// Set to true to show placeholder artwork for screenshots
    /// Set to false to show real artwork (normal operation)
    /// 
    /// CHANGE THIS VALUE IN CODE BELOW:
    private let usePlaceholders: Bool = false  // ✅ Normal mode - real artwork
    
    /// Public accessor - checks if screenshot mode is enabled
    var isScreenshotMode: Bool {
        return usePlaceholders
    }
    
    private init() {
        // Warn if screenshot mode is enabled
        if usePlaceholders {
            print("⚠️⚠️⚠️ SCREENSHOT MODE ENABLED - Placeholders will be shown instead of real artwork! ⚠️⚠️⚠️")
            print("⚠️ Remember to set usePlaceholders back to false after taking screenshots! ⚠️")
        }
    }
}

