import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Matchmaking Settings View

struct MatchmakingSettingsView: View {
    @StateObject private var viewModel = MatchmakingSettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingInfoSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    headerSection
                    
                    // Opt-in toggle
                    optInSection
                    
                    // Gender preferences (only shown if opted in)
                    if viewModel.isOptedIn {
                        genderPreferencesSection
                        
                        // Match history section
                        matchHistorySection
                        
                        // Statistics section
                        statisticsSection
                        
                        // Demo section
                        demoSection
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Music Matchmaking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingInfoSheet = true }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .onAppear {
                viewModel.loadUserPreferences()
                viewModel.checkMockBotStatus()
            }
            .sheet(isPresented: $showingInfoSheet) {
                MatchmakingInfoSheet()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            
            Text("Music Matchmaking")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Get matched with people who share your music taste every Thursday at 1 PM")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Opt-in Section
    
    private var optInSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Music Matchmaking")
                        .font(.headline)
                    Text("Receive weekly matches based on your music taste")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isOptedIn)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .onChange(of: viewModel.isOptedIn) { _ in
                        viewModel.savePreferences()
                    }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            if !viewModel.isOptedIn {
                VStack(spacing: 8) {
                    Text("🎵 How it works:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text("•")
                            Text("We analyze your music logs to find compatible matches")
                        }
                        HStack(alignment: .top) {
                            Text("•")
                            Text("Every Thursday at 1 PM, you'll get a personalized match")
                        }
                        HStack(alignment: .top) {
                            Text("•")
                            Text("Start conversations with people who love the same music")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Gender Preferences Section
    
    private var genderPreferencesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Dating Preferences")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Your Gender
                VStack(alignment: .leading, spacing: 8) {
                    Text("I identify as:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MatchmakingGender.allCases, id: \.self) { gender in
                                GenderChip(
                                    gender: gender,
                                    isSelected: viewModel.userGender == gender,
                                    action: {
                                        viewModel.userGender = gender
                                        viewModel.savePreferences()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Preferred Gender
                VStack(alignment: .leading, spacing: 8) {
                    Text("I'm interested in:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MatchmakingGender.allCases, id: \.self) { gender in
                                GenderChip(
                                    gender: gender,
                                    isSelected: viewModel.preferredGender == gender,
                                    action: {
                                        viewModel.preferredGender = gender
                                        viewModel.savePreferences()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Match History Section
    
    private var matchHistorySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Matches")
                    .font(.headline)
                Spacer()
                if !viewModel.recentMatches.isEmpty {
                    NavigationLink(destination: MatchHistoryView()) {
                        Text("View All")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            if viewModel.recentMatches.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No matches yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Your first match will arrive next Thursday!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.recentMatches.prefix(3), id: \.id) { match in
                        MatchHistoryRow(match: match)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Stats")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MatchmakingStatCard(
                    title: "Total Matches",
                    value: "\(viewModel.totalMatches)",
                    icon: "heart.circle.fill",
                    color: .pink
                )
                
                MatchmakingStatCard(
                    title: "Connections",
                    value: "\(viewModel.successfulConnections)",
                    icon: "message.circle.fill",
                    color: .green
                )
                
                MatchmakingStatCard(
                    title: "Avg Similarity",
                    value: String(format: "%.0f%%", viewModel.averageSimilarity * 100),
                    icon: "waveform.circle.fill",
                    color: .purple
                )
                
                MatchmakingStatCard(
                    title: "Response Rate",
                    value: String(format: "%.0f%%", viewModel.responseRate * 100),
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Demo Section
    
    private var demoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Live Demo")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                DemoToggleCard(
                    title: "Show Bot in Messages",
                    description: "Add a mock bot conversation to your Messages tab to see exactly how it will look",
                    icon: "message.badge.fill",
                    color: .blue,
                    isOn: viewModel.showMockBot,
                    action: { 
                        viewModel.toggleMockBot()
                    }
                )
                
                Button(action: { showingInfoSheet = true }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.purple)
                        
                        Text("View Interactive Demo")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Demo Toggle Card

struct DemoToggleCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isOn: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(isOn))
                .toggleStyle(SwitchToggleStyle(tint: color))
                .onTapGesture {
                    action()
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Gender Chip Component

struct GenderChip: View {
    let gender: MatchmakingGender
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(gender.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Matchmaking Stat Card Component

struct MatchmakingStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Match History Row Component

struct MatchHistoryRow: View {
    let match: WeeklyMatch
    @State private var matchedUser: UserProfile?
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image placeholder
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(matchedUser?.displayName.prefix(1).uppercased() ?? "?")
                        .font(.headline)
                        .foregroundColor(.purple)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(matchedUser?.displayName ?? "Loading...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !match.sharedArtists.isEmpty {
                    Text("Shared: \(match.sharedArtists.prefix(2).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(match.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                Text("\(Int(match.similarityScore * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                Text("match")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadMatchedUser()
        }
    }
    
    private func loadMatchedUser() {
        let db = Firestore.firestore()
        db.collection("users").document(match.matchedUserId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.matchedUser = try? snapshot?.data(as: UserProfile.self)
            }
        }
    }
}

// MARK: - Info Sheet

struct MatchmakingInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How Music Matchmaking Works")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        InfoSection(
                            icon: "music.note.list",
                            title: "Music Analysis",
                            description: "We analyze your public music logs, ratings, and favorite artists to understand your taste."
                        )
                        
                        InfoSection(
                            icon: "heart.circle",
                            title: "Smart Matching",
                            description: "Our algorithm finds users with similar music preferences while ensuring you discover new artists."
                        )
                        
                        InfoSection(
                            icon: "calendar",
                            title: "Weekly Matches",
                            description: "Every Thursday at 1 PM, you'll receive a personalized match with someone who shares your music taste."
                        )
                        
                        InfoSection(
                            icon: "message.circle",
                            title: "Start Conversations",
                            description: "Use your shared music interests as conversation starters and make meaningful connections."
                        )
                        
                        InfoSection(
                            icon: "shield.checkered",
                            title: "Privacy & Safety",
                            description: "Only public music logs are used for matching. You control your participation and can opt out anytime."
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("About Matchmaking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoSection: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.purple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MatchmakingSettingsView()
}
