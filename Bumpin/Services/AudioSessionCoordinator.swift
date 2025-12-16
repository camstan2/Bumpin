import Foundation
import AVFoundation
import FirebaseAuth
import UIKit

/// Coordinates audio session lifecycle to prevent blocking other apps
@MainActor
class AudioSessionCoordinator: ObservableObject {
    static let shared = AudioSessionCoordinator()
    
    private var isConfiguring = false
    private var lastConfigurationAttempt: Date?
    private let minTimeBetweenConfigurations: TimeInterval = 1.0 // Minimum 1 second between attempts
    
    private init() {
        setupBackgroundObserver()
    }
    
    private func setupBackgroundObserver() {
        // Listen for app backgrounding
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }
        
        // Listen for app foregrounding  
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillEnterForeground()
        }
    }
    
    private func handleAppDidEnterBackground() {
        print("📱 [AudioCoordinator] App entered background")
        
        // Prevent rapid repeated calls
        if isConfiguring {
            print("⚠️ [AudioCoordinator] Already configuring, skipping")
            return
        }
        
        if let lastAttempt = lastConfigurationAttempt,
           Date().timeIntervalSince(lastAttempt) < minTimeBetweenConfigurations {
            print("⚠️ [AudioCoordinator] Too soon since last attempt, skipping")
            return
        }
        
        isConfiguring = true
        lastConfigurationAttempt = Date()
        defer { isConfiguring = false }
        
        // Check if any audio features are active
        // Note: Most services are singletons accessed via .shared
        let voiceChatActive = false // VoiceChatManager doesn't have a shared singleton exposed
        let djStreamingActive = DJStreamService.shared.isStreaming
        let djSessionActive = DJStreamingManager.shared.isStreaming
        let musicPlaying = false // MusicManager doesn't have a shared singleton exposed
        let agoraJoined = false // AgoraVoiceService doesn't have a shared singleton exposed
        
        print("📱 [AudioCoordinator] DJ stream: \(djStreamingActive), DJ session: \(djSessionActive)")
        
        // Only deactivate if NO audio features are active
        // Note: Each service handles its own deactivation, this is just extra safety
        if !djStreamingActive && !djSessionActive {
            print("✅ [AudioCoordinator] No active DJ/streaming features - safe to deactivate if not playing music")
            
            // Extra safety: deactivate the shared audio session if truly idle
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                print("✅ [AudioCoordinator] Shared audio session deactivated")
            } catch {
                // This might fail if music is playing, which is fine
                print("ℹ️ [AudioCoordinator] Audio session deactivation not needed (possibly music playing): \(error)")
            }
        } else {
            print("ℹ️ [AudioCoordinator] Active audio features detected - keeping session active for background playback")
        }
    }
    
    private func handleAppWillEnterForeground() {
        print("📱 [AudioCoordinator] App will enter foreground")
        // Audio sessions will be reactivated on-demand by each service when needed
    }
}

