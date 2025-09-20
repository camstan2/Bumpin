import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firebase Configuration Manager
class FirebaseManager {
    static let shared = FirebaseManager()
    
    func configure() {
        let config = AppConfig.shared
        
        // Load appropriate GoogleService-Info.plist
        guard let filePath = Bundle.main.path(forResource: config.firebase.googleServiceInfoPlist, ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            fatalError("Couldn't load Firebase configuration file")
        }
        
        // Initialize Firebase
        FirebaseApp.configure(options: options)
        
        // Configure additional Firebase services based on environment
        switch config.environment {
        case .development:
            setupDevelopmentConfig()
        case .staging:
            setupStagingConfig()
        case .production:
            setupProductionConfig()
        }
    }
    
    private func setupDevelopmentConfig() {
        // Development-specific Firebase configuration
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
    }
    
    private func setupStagingConfig() {
        // Staging-specific Firebase configuration
        // No additional configuration needed
    }
    
    private func setupProductionConfig() {
        // Production-specific Firebase configuration
        // No additional configuration needed
    }
}
