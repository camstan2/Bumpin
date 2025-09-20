import Foundation

// MARK: - App Secrets Configuration
// This file should be added to .gitignore to keep API keys secure

struct AppSecrets {
    
    // MARK: - Development Environment
    struct Development {
        static let claudeAPIKey = "REDACTED"
        static let firebaseConfigPath = "GoogleService-Info-Dev"
    }
    
    // MARK: - Staging Environment
    struct Staging {
        static let claudeAPIKey = "YOUR_STAGING_CLAUDE_API_KEY_HERE"
        static let firebaseConfigPath = "GoogleService-Info-Staging"
    }
    
    // MARK: - Production Environment
    struct Production {
        static let claudeAPIKey = "YOUR_PRODUCTION_CLAUDE_API_KEY_HERE"
        static let firebaseConfigPath = "GoogleService-Info"
    }
}

// MARK: - Environment Detection

extension AppSecrets {
    static var current: (claudeAPIKey: String, firebaseConfigPath: String) {
        #if DEBUG
        return (Development.claudeAPIKey, Development.firebaseConfigPath)
        #else
        // In production, you might want to use different logic
        // For now, defaulting to production
        return (Production.claudeAPIKey, Production.firebaseConfigPath)
        #endif
    }
}
