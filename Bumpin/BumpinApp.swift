//
//  BumpinApp.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseCore
import FirebaseAuth
import CoreLocation
import MusicKit
import BackgroundTasks

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
        handle = Auth.auth().addStateDidChangeListener { _, user in
            self.isLoggedIn = (user != nil)
        }
    }
    
    func logout() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

@main
struct BumpinApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var nowPlayingManager = NowPlayingManager()
    @StateObject private var adminState = AdminState()
    @StateObject private var termsManager = TermsAcceptanceManager()
    private static var scoringListener: ListenerRegistration?
    @State private var joinBannerMessage: String? = nil
    @State private var showMusicPlatformOnboarding = false
    @State private var showCrossPlatformPrompt = false
    @State private var showTermsOfService = false
    
    init() {
        FirebaseApp.configure()
        // Register BG task handler once and schedule first request
        BGRefreshManager.shared.scheduleBackgroundRefresh()
        
        // Run the one-off migration only when a user is signed in to avoid
        // Firestore rules errors for unauthenticated reads at app launch.
        if Auth.auth().currentUser != nil {
            Task {
                await FirestoreMigrationManager.shared.runMigrationsIfNeeded()
            }
        } else {
            print("ℹ️ Skipping MusicList migration at launch (no signed-in user).")
        }
        
        // Initialize MusicKit
        Task {
            let status = MusicAuthorization.currentStatus
            print("🎵 MusicKit authorization status: \(status)")
            if status == .notDetermined {
                let requestedStatus = await MusicAuthorization.request()
                print("🎵 Requested MusicKit authorization: \(requestedStatus)")
                if requestedStatus == .authorized { 
                    // AppleMusicCache.shared.preload() 
                }
            } else if status == .authorized {
                // AppleMusicCache.shared.preload()
            }
        }

        // Fetch and subscribe to remote scoring overrides from Firestore
        Task {
            do {
                let snap = try await Firestore.firestore().collection("config").document("scoring").getDocument()
                if let data = snap.data() {
                    var map: [String: Double] = [:]
                    for (k, v) in data {
                        if let num = v as? NSNumber { map[k] = num.doubleValue }
                        if let d = v as? Double { map[k] = d }
                        if let i = v as? Int { map[k] = Double(i) }
                    }
                    if !map.isEmpty { 
                        // ScoringConfig.applyRemote(map) 
                    }
                }
            } catch {
                print("ℹ️ Remote scoring config not available: \(error)")
            }
            BumpinApp.scoringListener = Firestore.firestore().collection("config").document("scoring").addSnapshotListener { snapshot, _ in
                guard let data = snapshot?.data() else { return }
                var map: [String: Double] = [:]
                for (k, v) in data {
                    if let num = v as? NSNumber { map[k] = num.doubleValue }
                    if let d = v as? Double { map[k] = d }
                    if let i = v as? Int { map[k] = Double(i) }
                }
                // ScoringConfig.applyRemote(map)
            }
        }

        // Initialize Random Chat Matching Service
        _ = RandomChatMatchingService.shared
        
        // Initialize Social Interaction Tracker
        _ = SocialInteractionTracker.shared
        
        // Initialize Trending Topics Service and seed data if needed
        Task {
            await BumpinApp.initializeTrendingTopicsIfNeeded()
        }
        
        // Start dynamic links config listener (universal link domains)
        // AppConfig.shared.startLinksConfigListener()
        // Log configured domains for verification
        Task { @MainActor in
            // let domains = AppConfig.shared.universalLinkDomains
            // let primary = AppConfig.shared.universalLinkDomains.first ?? "(none)"
            // print("🔗 Universal Links domains: \(domains) | primary=\(primary)")
            // Optional: seed defaults if admin and config missing
            // if primary == "(none)" || domains.isEmpty {
            //     print("⚠️ No universal link domains configured")
            // }
            // Set global analytics context
            AnalyticsService.shared.globalContext = {
                var ctx: [String: Any] = [:]
                if let uid = Auth.auth().currentUser?.uid { ctx["userId"] = uid }
                ctx["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                ctx["build"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
                return ctx
            }
            CrashReporter.shared.setUserId(Auth.auth().currentUser?.uid)
        }
    }
    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoggedIn {
                if termsManager.requiresTermsAcceptance() {
                    TermsOfServiceView(isPresented: $showTermsOfService) {
                        Task {
                            await termsManager.acceptTerms()
                        }
                    }
                } else {
                    let partyManager = PartyManager()
                    let discussionManager = DiscussionManager()
                    let mockNotificationService = MockNotificationService.shared
                    MainTabScaffold(
                        authViewModel: authViewModel
                    )
                    .environmentObject(partyManager)
                    .environmentObject(discussionManager)
                    .environmentObject(locationManager)
                    .environmentObject(nowPlayingManager)
                    .environmentObject(adminState)
                    .environmentObject(mockNotificationService)
                    .environmentObject(termsManager)
                .onAppear {
                    // Start notification service listening
                    NotificationService.shared.startListening()
                }
                .onDisappear {
                    // Stop notification service listening
                    NotificationService.shared.stopListening()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Handle app entering background
                    SocialInteractionTracker.shared.handleAppDidEnterBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Handle app termination
                    SocialInteractionTracker.shared.handleAppWillTerminate()
                }
                .overlay {
                    // Minimized Party Indicator - Floating overlay
                    MinimizedPartyIndicator(partyManager: partyManager)
                    
                    // Minimized DJ Stream Indicator - Floating overlay
                    MinimizedDJStreamIndicator(djService: DJStreamService.shared)
                    
                    // Social Rating Prompt Container - Floating overlay
                    SocialRatingPromptContainer()
                }
                .fullScreenCover(isPresented: $showMusicPlatformOnboarding) {
                    MusicPlatformOnboardingView {
                        showMusicPlatformOnboarding = false
                    }
                }
                .sheet(isPresented: $showCrossPlatformPrompt) {
                    CrossPlatformMigrationPrompt(
                        onMigrate: {
                            // Navigate to platform settings
                            showCrossPlatformPrompt = false
                        },
                        onDismiss: {
                            UserDefaults.standard.set(true, forKey: "cross_platform_prompt_dismissed")
                            showCrossPlatformPrompt = false
                        }
                    )
                }
                .onAppear {
                    checkForOnboarding()
                }
                .overlay {
                    // Minimized Discussion Indicator - Floating overlay
                    MinimizedDiscussionIndicator(discussionManager: discussionManager)
                }
                .overlay(alignment: .top) {
                    if let msg = joinBannerMessage {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text(msg)
                                .font(.footnote)
                                .fontWeight(.semibold)
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 6)
                        .padding(.top, 12)
                    }
                }
                .onAppear { adminState.start() }
                .onOpenURL { url in
                    if let code = DeepLinkParser.parseJoinCode(from: url) {
                        joinBannerMessage = "Joining party…"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { joinBannerMessage = nil }
                        Task { await partyManager.joinByCode(code); AnalyticsService.shared.logPartyJoin(method: "deeplink", partyId: code) }
                    } else if let code = DeepLinkParser.parseUniversalJoinCode(from: url) {
                        joinBannerMessage = "Joining party…"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { joinBannerMessage = nil }
                        Task { await partyManager.joinByCode(code); AnalyticsService.shared.logPartyJoin(method: "universal", partyId: code) }
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL, let code = DeepLinkParser.parseUniversalJoinCode(from: url) {
                        joinBannerMessage = "Joining party…"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { joinBannerMessage = nil }
                        Task { await partyManager.joinByCode(code); AnalyticsService.shared.logPartyJoin(method: "universal", partyId: code) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PartyJoined"))) { _ in
                    joinBannerMessage = "Joined"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { joinBannerMessage = nil }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JoinCodeNotFound"))) { _ in
                    joinBannerMessage = "Failed to join"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { joinBannerMessage = nil }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FriendsOnlyDenied"))) { _ in
                    joinBannerMessage = "Failed to join"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { joinBannerMessage = nil }
                }
                }
            } else {
                LoginSignupView()
            }
        }
        // Removed .backgroundTask modifier to avoid duplicate registration; BGRefreshManager handles registration
    }
}

// MARK: - BumpinApp Extensions

extension BumpinApp {
    // MARK: - Onboarding Logic
    
    private func checkForOnboarding() {
        // Check if user has completed music platform onboarding
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "music_platform_onboarding_completed")
        
        if !hasCompletedOnboarding {
            // New user - show onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showMusicPlatformOnboarding = true
            }
        } else {
            // Existing user - check if we should show cross-platform prompt
            checkForCrossPlatformPrompt()
        }
    }
    
    private func checkForCrossPlatformPrompt() {
        let hasBeenPrompted = UserDefaults.standard.bool(forKey: "cross_platform_prompt_dismissed")
        let currentPreference = UnifiedMusicSearchService.shared.platformPreference
        
        // Show prompt if user is only using Apple Music and hasn't been prompted
        if !hasBeenPrompted && currentPreference == .appleMusicOnly {
            // Show after a delay and only occasionally
            let lastPromptDate = UserDefaults.standard.object(forKey: "last_cross_platform_prompt") as? Date
            let shouldPrompt = lastPromptDate == nil || Date().timeIntervalSince(lastPromptDate!) > (7 * 24 * 60 * 60) // 7 days
            
            if shouldPrompt {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    showCrossPlatformPrompt = true
                    UserDefaults.standard.set(Date(), forKey: "last_cross_platform_prompt")
                }
            }
        }
    }
    
    // MARK: - Trending Topics Initialization
    
    static func initializeTrendingTopicsIfNeeded() async {
        // Initialize the new user-statistics-based trending system
        await DiscussionTopicSeedService.shared.seedInitialTopicsIfNeeded()
        
        // Initialize the topic system manager
        await TopicSystemManager.shared.initialize()
        
        // For testing: Create some test discussions to verify trending system
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "create_test_discussions") {
            await TrendingSystemTestHelper.shared.createTestDiscussions()
        }
        #endif
    }
}

struct SearchTabView: View {
    var body: some View {
        VStack {
            Text("Search Users")
                .font(.largeTitle)
                .padding()
            Text("User search coming soon!")
                .foregroundColor(.secondary)
        }
    }
}
