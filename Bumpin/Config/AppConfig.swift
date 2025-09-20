import Foundation

struct AppConfig {
    static let shared = AppConfig()
    
    // MARK: - App Information
    struct App {
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.bumpin.app"
    }
    
    // MARK: - Firebase Configuration
    struct Firebase {
        static let projectId = "bumpin-4349a"
        static let databaseURL = "https://bumpin-4349a-default-rtdb.firebaseio.com"
        static let storageBucket = "bumpin-4349a.appspot.com"
        static let googleServiceInfoPlist = "GoogleService-Info"
    }
    
    // MARK: - API Configuration
    struct API {
        static let baseURL = "https://api.music.apple.com/v1/"
        static let timeout: TimeInterval = 30.0
        static let maxRetries = 3
        static let claudeAPIBaseURL = URL(string: "https://api.anthropic.com/v1")!
        static let claudeAPIKey = "your-claude-api-key-here" // Replace with actual key
    }
    
    // MARK: - Content Limits
    struct ContentLimits {
        static let maxReviewLength = 1000
        static let maxCommentLength = 500
        static let maxChatMessageLength = 200
        static let maxPartyNameLength = 50
        static let maxUsernameLength = 30
        static let maxBioLength = 150
        static let maxTopicNameLength = 100
        static let maxTopicDescriptionLength = 300
    }
    
    // MARK: - Cache Configuration
    struct Cache {
        static let maxMemorySize = 50 * 1024 * 1024 // 50MB
        static let maxDiskSize = 100 * 1024 * 1024 // 100MB
        static let defaultExpiration: TimeInterval = 24 * 3600 // 24 hours
    }
    
    // MARK: - Social Features
    struct Social {
        static let maxFollowing = 5000
        static let maxFollowers = 50000
        static let maxPartyParticipants = 50
        static let maxChatMessagesPerMinute = 10
        static let maxReportsPerDay = 10
    }
    
    // MARK: - Safety Configuration
    struct Safety {
        static let maxViolationsBeforeWarning = 1
        static let maxViolationsBeforeMute = 3
        static let maxViolationsBeforeBan = 5
        static let maxReportsBeforeReview = 3
        static let moderationResponseTimeHours = 24
    }
    
    // MARK: - Environment
    enum Environment: String {
        case development = "development"
        case staging = "staging"
        case production = "production"
    }
    
    var environment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    var firebase: Firebase.Type {
        return Firebase.self
    }
    
    private init() {}
    
    // MARK: - Universal Links
    func isAllowedUniversalLinkHost(_ host: String) -> Bool {
        let allowedHosts = [
            "bumpin.app",
            "www.bumpin.app",
            "music.bumpin.app"
        ]
        return allowedHosts.contains(host.lowercased())
    }
    
    func inviteURL(forCode code: String) -> URL? {
        return URL(string: "https://bumpin.app/join/\(code)")
    }
}
