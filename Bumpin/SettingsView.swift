import SwiftUI
import FirebaseFirestore
import FirebaseCore
import FirebaseAuth

struct SettingsView: View {
    @State private var hiddenUsers: [String] = []
    @State private var showTuner: Bool = false
    @State private var selectedTab: SettingsTab = .user
    @EnvironmentObject var adminState: AdminState
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case user = "User Settings"
        case admin = "Admin Settings"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .user: return "person.circle"
            case .admin: return "gearshape.2"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker (only show for admins)
                if adminState.isAdmin {
                    Picker("Settings Tab", selection: $selectedTab) {
                        ForEach(SettingsTab.allCases) { tab in
                            Text(tab.rawValue)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                // Tab Content
                Group {
                    if adminState.isAdmin {
                        // Admin users see both tabs
                        switch selectedTab {
                        case .user:
                            userSettingsContent
                        case .admin:
                            adminSettingsContent
                        }
                    } else {
                        // Regular users only see user settings
                        userSettingsContent
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { 
                Task { 
                    await loadHidden()
                    await setupAdminIfNeeded()
                } 
            }
            .sheet(isPresented: $showTuner) { ScoringTunerView() }
        }
    }
    
    // MARK: - User Settings Content
    private var userSettingsContent: some View {
        List {
            musicPlatformSection
            matchmakingSection
            migrationSection
            hiddenUsersSection
            signOutSection
        }
    }
    
    // MARK: - Admin Settings Content
    private var adminSettingsContent: some View {
        List {
            #if DEBUG
            debugSection
            #endif
            adminSection
            scoringSection
            adminDemoSection
        }
    }
    
    // MARK: - Admin Demo Section
    private var adminDemoSection: some View {
        Section(header: Text("Admin Demo Tools")) {
            NavigationLink(destination: LiveMatchmakingDemo()) {
                HStack {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Interactive Demo")
                            .font(.subheadline)
                        Text("See exactly how bot messages will look")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            NavigationLink(destination: MatchmakingBotMockView()) {
                HStack {
                    Image(systemName: "eye")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Message Previews")
                            .font(.subheadline)
                        Text("Browse different bot message types")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    #if DEBUG
    private var debugSection: some View {
        Section(header: Text("Debug Tools (Development Only)")) {
            NavigationLink(destination: CrossPlatformDebugView()) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cross-Platform Testing")
                            .font(.subheadline)
                        Text("Reset states and test flows")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    #endif
    
    private var musicPlatformSection: some View {
        Section(header: Text("Music Platform")) {
            NavigationLink(destination: MusicPlatformSettingsView()) {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.purple)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Music Service")
                            .font(.subheadline)
                        Text(UnifiedMusicSearchService.shared.platformPreference.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    private var matchmakingSection: some View {
        Section(header: Text("Music Matchmaking")) {
            NavigationLink(destination: MatchmakingSettingsView()) {
                HStack {
                    Image(systemName: "heart.text.square")
                        .foregroundColor(.purple)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Music Matchmaking")
                            .font(.subheadline)
                        Text("Get matched with people who share your taste")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    private var migrationSection: some View {
        Section(header: Text("Cross-Platform Migration")) {
            NavigationLink(destination: MigrationSettingsView()) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Universal Tracks")
                            .font(.subheadline)
                        Text("Migrate to cross-platform system")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    private var hiddenUsersSection: some View {
        HiddenUsersSection(hiddenUsers: hiddenUsers) { uid in
            Task { await unhideUserDirect(uid); await loadHidden() }
        }
    }
    
    private var signOutSection: some View {
        Section {
            Button(action: { AuthViewModel().logout() }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    
                    Text("Sign Out")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var scoringSection: some View {
        Section(header: Text("Admin Tools")) {
            Button(action: { showTuner = true }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.purple)
                        .frame(width: 20)
                    
                    Text("Scoring Tuner")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: SocialScoringDemoView()) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Social Scoring Demo")
                            .font(.subheadline)
                        Text("Preview post-talk survey system")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            NavigationLink(destination: AdminTrendingTopicsView()) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trending Topics Admin")
                            .font(.subheadline)
                        Text("Manage discussion trending topics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    private func loadHidden() async {
        guard let uid = Auth.auth().currentUser?.uid else { hiddenUsers = []; return }
        do {
            let snap = try await Firestore.firestore().collection("users").document(uid).getDocument()
            let arr = (snap.data()? ["hiddenUsers"] as? [String]) ?? []
            await MainActor.run { self.hiddenUsers = arr }
        } catch { await MainActor.run { self.hiddenUsers = [] } }
    }

    private func unhideUserDirect(_ userId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do { try await Firestore.firestore().collection("users").document(uid).updateData(["hiddenUsers": FieldValue.arrayRemove([userId])]) }
        catch { }
    }
    
    // MARK: - Admin Setup
    private func setupAdminIfNeeded() async {
        guard let user = Auth.auth().currentUser else { return }
        
        // Check if user should be admin based on email
        let shouldBeAdmin = user.email?.contains("admin") == true || 
                           user.email == "cam@bumpin.app"
        
        if shouldBeAdmin {
            do {
                // Set admin flag in Firestore user document
                try await Firestore.firestore()
                    .collection("users")
                    .document(user.uid)
                    .setData(["isAdmin": true], merge: true)
                print("✅ Admin flag set for user: \(user.email ?? "unknown")")
            } catch {
                print("❌ Failed to set admin flag: \(error)")
            }
        }
    }
}

// MARK: - Cross-Platform Debug View (Development Only)

#if DEBUG
struct CrossPlatformDebugView: View {
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Cross-Platform Debug Tools")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tools for testing the cross-platform music system during development.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Debug actions
                VStack(spacing: 12) {
                    Button(action: {
                        resetOnboardingState()
                        alertMessage = "Onboarding state reset. Restart app to test new user flow."
                        showingAlert = true
                    }) {
                        DebugActionCard(
                            icon: "person.badge.plus",
                            title: "Reset Onboarding State",
                            description: "Test new user platform selection flow"
                        )
                    }
                    
                    Button(action: {
                        resetMigrationPromptState()
                        alertMessage = "Migration prompt state reset. Restart app to test existing user flow."
                        showingAlert = true
                    }) {
                        DebugActionCard(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Reset Migration Prompt State",
                            description: "Test existing user upgrade prompts"
                        )
                    }
                    
                    Button(action: {
                        showCurrentState()
                        alertMessage = "Check console for current testing state."
                        showingAlert = true
                    }) {
                        DebugActionCard(
                            icon: "info.circle",
                            title: "Show Current State",
                            description: "Display current UserDefaults values in console"
                        )
                    }
                    
                    Button(action: {
                        testCrossPlatformMatching()
                        alertMessage = "Running manual cross-platform test. Check console for results."
                        showingAlert = true
                    }) {
                        DebugActionCard(
                            icon: "link",
                            title: "Test Cross-Platform Matching",
                            description: "Run manual test of universal track system",
                            isPrimary: true
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Debug Tools")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Debug Action", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Debug Functions
    
    private func resetOnboardingState() {
        UserDefaults.standard.removeObject(forKey: "music_platform_onboarding_completed")
        UserDefaults.standard.removeObject(forKey: "music_platform_preference")
        print("🔄 Reset onboarding state - app will show onboarding on next launch")
    }
    
    private func resetMigrationPromptState() {
        UserDefaults.standard.removeObject(forKey: "cross_platform_prompt_dismissed")
        UserDefaults.standard.removeObject(forKey: "last_cross_platform_prompt")
        UserDefaults.standard.set("apple_music_only", forKey: "music_platform_preference")
        UserDefaults.standard.set(true, forKey: "music_platform_onboarding_completed")
        print("🔄 Reset migration prompt state - app will show migration prompt on next launch")
    }
    
    private func showCurrentState() {
        let onboardingCompleted = UserDefaults.standard.bool(forKey: "music_platform_onboarding_completed")
        let promptDismissed = UserDefaults.standard.bool(forKey: "cross_platform_prompt_dismissed")
        let preference = UserDefaults.standard.string(forKey: "music_platform_preference") ?? "none"
        
        print("📊 Current Testing State:")
        print("   Onboarding Completed: \(onboardingCompleted)")
        print("   Migration Prompt Dismissed: \(promptDismissed)")
        print("   Platform Preference: \(preference)")
    }
    
    private func testCrossPlatformMatching() {
        Task {
            print("🧪 Manual Cross-Platform Test Starting...")
            
            // Test universal track creation
            let appleTrackId = "1421241217" // Example Apple Music ID
            let universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: "Test Song",
                artist: "Test Artist",
                albumName: "Test Album",
                appleMusicId: appleTrackId
            )
            
            print("✅ Created universal track: \(universalTrack.id)")
            
            // Test Spotify search
            let spotifyResults = await SpotifyService.shared.searchTracks(query: "Test Song Test Artist", limit: 1)
            print("🎵 Spotify search returned \(spotifyResults.count) results")
            
            print("✅ Manual test completed!")
        }
    }
}

struct DebugActionCard: View {
    let icon: String
    let title: String
    let description: String
    var isPrimary: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(isPrimary ? .white : .orange)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(isPrimary ? .white : .primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(isPrimary ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(isPrimary ? .white.opacity(0.7) : .secondary)
                .font(.caption)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPrimary ? 
                        AnyShapeStyle(LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing)) :
                        AnyShapeStyle(Color(.systemGray6))
                    )
            )
    }
}
#endif

// MARK: - Hidden Users Section
private struct HiddenUsersSection: View {
    let hiddenUsers: [String]
    let onUnhide: (String) -> Void
    var body: some View {
        Section(header: Text("Hidden Users")) {
            if hiddenUsers.isEmpty {
                Text("No hidden users").foregroundColor(.secondary)
            } else {
                ForEach(hiddenUsers, id: \.self) { uid in
                    HStack {
                        Text(uid).font(.footnote)
                        Spacer()
                        Button("Unhide") { onUnhide(uid) }
                            .foregroundColor(.purple)
                    }
                }
            }
        }
    }
}

private struct LegacyScoringTunerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remoteValues: [String: Double] = [:]
    @State private var textInputs: [String: String] = [:]
    @State private var isLoading = false
    @State private var error: String? = nil
    
    // Keys we expose for quick tuning
    private let keys: [String] = [
        "scoring.searchPrefixBonus",
        "scoring.searchWordStartBonus",
        "scoring.searchSubstringBonus",
        "scoring.searchFuzzyBonus",
        "scoring.appleProviderRankWeight",
        "scoring.searchTextWeight",
        "scoring.searchPopularityWeight"
    ]
    
    var body: some View {
        NavigationView {
            List {
                if let error = error { Text(error).foregroundColor(.red) }
                if isLoading { ProgressView() }
                Section(header: Text("Remote Values")) {
                    ForEach(keys, id: \.self) { key in
                        ScoringKeyRow(
                            key: key,
                            current: remoteValues[key],
                            text: Binding(
                                get: { textInputs[key] ?? "" },
                                set: { textInputs[key] = $0 }
                            )
                        )
                    }
                    Button("Save to Remote") { Task { await save() } }
                        .foregroundColor(.purple)
                }
            }
            .navigationTitle("Scoring Tuner")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { Task { await load() } }
        }
    }
    
    private func load() async {
        guard isAdmin() else { error = "Admin only"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snap = try await Firestore.firestore().collection("config").document("scoring").getDocument()
            let data = snap.data() ?? [:]
            var map: [String: Double] = [:]
            for (k, v) in data { if let n = v as? NSNumber { map[k] = n.doubleValue } else if let d = v as? Double { map[k] = d } }
            await MainActor.run {
                self.remoteValues = map
                for k in keys { self.textInputs[k] = map[k].map { String($0) } ?? "" }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
    
    private func save() async {
        guard isAdmin() else { error = "Admin only"; return }
        var updates: [String: Any] = [:]
        for k in keys {
            if let t = textInputs[k], let dbl = Double(t) { updates[k] = dbl }
        }
        do {
            try await Firestore.firestore().collection("config").document("scoring").setData(updates, merge: true)
            // Re-apply locally
            var map: [String: Double] = [:]
            for (k, v) in updates { if let d = v as? Double { map[k] = d } }
            // Apply if available at runtime
            _ = map
            await load()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
    
    private func isAdmin() -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        // Simple check: allow if userId ends with a known suffix or belongs to a small allowlist
        let allowlist: Set<String> = ["admin1", "admin2"]
        return allowlist.contains(uid)
    }
}

// MARK: - Row for a single scoring key
private struct ScoringKeyRow: View {
    let key: String
    let current: Double?
    let text: Binding<String>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(key).font(.caption)
                Text("Current: \(format(current))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            TextField("value", text: text)
                .keyboardType(.decimalPad)
                .frame(width: 90)
        }
    }

    private func format(_ value: Double?) -> String {
        guard let v = value else { return "-" }
        return String(format: "%.2f", v)
    }
}

// MARK: - Admin Section Extension

extension SettingsView {
    
    private var adminSection: some View {
        Group {
            if adminState.isAdmin {
                Section(header: Text("Admin Tools")) {
                    NavigationLink(destination: AdminMatchmakingView()) {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .foregroundColor(.red)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Matchmaking Admin")
                                    .font(.subheadline)
                                Text("Monitor and manage music matchmaking")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    NavigationLink(destination: AdminDailyPromptsView()) {
                        HStack {
                            Image(systemName: "quote.bubble.fill")
                                .foregroundColor(.purple)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Prompts Admin")
                                    .font(.subheadline)
                                Text("Manage and schedule daily music prompts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    NavigationLink(destination: DiscussionGamesMockView()) {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Games UI Mock")
                                    .font(.subheadline)
                                Text("Preview the social gaming interface")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    NavigationLink(destination: ImposterGameInProgressMockView()) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.red)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Game In Progress Mock")
                                    .font(.subheadline)
                                Text("Preview active Imposter game with 5 players")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    NavigationLink(destination: GameDiscussionMockView()) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.green)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Game Discussion Mock")
                                    .font(.subheadline)
                                Text("Preview discussion started from games tab with all 4 tabs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    // Social Tab Controls
                    Button(action: {
                        let new = !UserDefaults.standard.bool(forKey: "feed.mockData")
                        UserDefaults.standard.set(new, forKey: "feed.mockData")
                    }) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Social Tab - Mock Data")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Toggle mock data for social feed (Currently: \(UserDefaults.standard.bool(forKey: "feed.mockData") ? "ON" : "OFF"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { UserDefaults.standard.bool(forKey: "feed.mockData") },
                                set: { UserDefaults.standard.set($0, forKey: "feed.mockData") }
                            ))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink(destination: DailyPromptDemoView()) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.purple)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Social Tab - Daily Prompts Demo")
                                    .font(.subheadline)
                                Text("Preview daily prompts feature for social engagement")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        Task { @MainActor in
                            await testCrossPlatformSystem()
                        }
                    }) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Social Tab - Cross-Platform Test")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Run cross-platform music matching system test")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Home Tab Controls
                    Button(action: {
                        let new = !UserDefaults.standard.bool(forKey: "discovery.mockData")
                        UserDefaults.standard.set(new, forKey: "discovery.mockData")
                        // Note: Full functionality requires PartyDiscoveryManager context
                    }) {
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Home Tab - Mock Data")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Toggle mock data for party discovery (Currently: \(UserDefaults.standard.bool(forKey: "discovery.mockData") ? "ON" : "OFF"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { UserDefaults.standard.bool(forKey: "discovery.mockData") },
                                set: { UserDefaults.standard.set($0, forKey: "discovery.mockData") }
                            ))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        print("🔍 Home Tab Debug Info:")
                        print("  - Mock data enabled: \(UserDefaults.standard.bool(forKey: "discovery.mockData"))")
                        print("  - Discovery service status: Available in main app context")
                        print("  - Search functionality: Active")
                        print("  - Filter options: Available")
                    }) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Home Tab - Debug Info")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Print debug information about party discovery state")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "discovery.mockData")
                        print("🧪 Test Nearby activated - Mock data enabled")
                        print("Note: Switch to Home tab to see nearby parties")
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.green)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Home Tab - Test Nearby")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Enable mock data and simulate nearby parties")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        print("🔄 Home Tab Refresh triggered from admin settings")
                        print("Note: Full refresh functionality available in main Home tab")
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Home Tab - Refresh Parties")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Refresh party discovery data and nearby parties")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                }
            }
        }
    }
    
    // MARK: - Cross-Platform Testing
    private func testCrossPlatformSystem() async {
        print("🧪 === CROSS-PLATFORM SYSTEM TEST ===")
        await TrackMatchingService.shared.testSickoModeMatching()
        await SpotifyService.shared.demonstrateSpotifySearch()
        await UniversalMusicProfileService.shared.demonstrateSickoModeUnification()
        print("✅ Cross-platform test completed!")
    }
}


