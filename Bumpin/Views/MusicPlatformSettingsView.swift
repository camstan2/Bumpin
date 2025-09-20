import SwiftUI

// MARK: - Music Platform Settings View

struct MusicPlatformSettingsView: View {
    @StateObject private var unifiedSearchService = UnifiedMusicSearchService.shared
    @StateObject private var spotifyService = SpotifyService.shared
    @State private var showingSpotifyAuth = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                    
                    Text("Music Platform Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose your preferred music service for search and discovery. Your ratings and reviews will be unified across platforms.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Platform selection
                VStack(spacing: 16) {
                    Text("Search Preference")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        ForEach(UnifiedMusicSearchService.MusicPlatformPreference.allCases, id: \.rawValue) { preference in
                            PlatformOptionCard(
                                preference: preference,
                                isSelected: unifiedSearchService.platformPreference == preference,
                                isSpotifyAuthenticated: spotifyService.isAuthenticated
                            ) {
                                unifiedSearchService.setPlatformPreference(preference)
                                
                                // Authenticate Spotify if needed
                                if preference != .appleMusicOnly && !spotifyService.isAuthenticated {
                                    showingSpotifyAuth = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Platform status
                platformStatusSection
                
                // Cross-platform benefits
                crossPlatformBenefitsSection
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Music Platform")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSpotifyAuth) {
            SpotifyAuthView()
        }
    }
    
    @ViewBuilder
    private var platformStatusSection: some View {
        VStack(spacing: 16) {
            Text("Platform Status")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Apple Music status
                PlatformStatusCard(
                    platform: "Apple Music",
                    icon: "music.note",
                    isConnected: true, // Always available through MusicKit
                    statusText: "Connected",
                    statusColor: .green
                )
                
                // Spotify status
                PlatformStatusCard(
                    platform: "Spotify Search",
                    icon: "magnifyingglass",
                    isConnected: spotifyService.isAuthenticated,
                    statusText: spotifyService.isAuthenticated ? "Connected" : "Not Connected",
                    statusColor: spotifyService.isAuthenticated ? .green : .orange
                ) {
                    if !spotifyService.isAuthenticated {
                        showingSpotifyAuth = true
                    }
                }
                
                // Spotify User Library status
                PlatformStatusCard(
                    platform: "Spotify Library",
                    icon: "music.note.list",
                    isConnected: spotifyService.isUserAuthenticated,
                    statusText: spotifyService.isUserAuthenticated ? "Connected" : "Not Connected",
                    statusColor: spotifyService.isUserAuthenticated ? .green : .orange
                ) {
                    if !spotifyService.isUserAuthenticated {
                        Task {
                            let success = await spotifyService.authenticateUser()
                            if success {
                                print("🎉 Spotify user authentication completed!")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var crossPlatformBenefitsSection: some View {
        VStack(spacing: 16) {
            Text("Cross-Platform Benefits")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                BenefitCard(
                    icon: "person.2.fill",
                    title: "Unified Profiles",
                    description: "See ratings and reviews from users on all platforms"
                )
                
                BenefitCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Better Trending",
                    description: "More accurate trending data from larger user base"
                )
                
                BenefitCard(
                    icon: "star.fill",
                    title: "More Reviews",
                    description: "Access to reviews from Apple Music and Spotify users"
                )
                
                BenefitCard(
                    icon: "link",
                    title: "Platform Freedom",
                    description: "Switch between platforms while keeping your social data"
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Platform Option Card

struct PlatformOptionCard: View {
    let preference: UnifiedMusicSearchService.MusicPlatformPreference
    let isSelected: Bool
    let isSpotifyAuthenticated: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: platformIcon)
                    .foregroundColor(platformColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preference.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(platformDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title2)
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.6)
    }
    
    private var platformIcon: String {
        switch preference {
        case .appleMusicOnly: return "music.note"
        case .spotifyOnly: return "music.note.list"
        case .both: return "link"
        case .appleMusicPrimary: return "music.note"
        case .spotifyPrimary: return "music.note.list"
        }
    }
    
    private var platformColor: Color {
        switch preference {
        case .appleMusicOnly: return .red
        case .spotifyOnly: return .green
        case .both: return .purple
        case .appleMusicPrimary: return .red
        case .spotifyPrimary: return .green
        }
    }
    
    private var platformDescription: String {
        switch preference {
        case .appleMusicOnly: return "Search only Apple Music catalog"
        case .spotifyOnly: return "Search only Spotify catalog"
        case .both: return "Search both platforms equally"
        case .appleMusicPrimary: return "Prefer Apple Music, include Spotify"
        case .spotifyPrimary: return "Prefer Spotify, include Apple Music"
        }
    }
    
    private var isAvailable: Bool {
        switch preference {
        case .appleMusicOnly, .appleMusicPrimary: return true
        case .spotifyOnly, .spotifyPrimary, .both: return isSpotifyAuthenticated
        }
    }
}

// MARK: - Platform Status Card

struct PlatformStatusCard: View {
    let platform: String
    let icon: String
    let isConnected: Bool
    let statusText: String
    let statusColor: Color
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(statusColor)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(platform)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            if let onTap = onTap, !isConnected {
                Button("Connect") {
                    onTap()
                }
                .font(.caption)
                .foregroundColor(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Benefit Card

struct BenefitCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Spotify Auth View

struct SpotifyAuthView: View {
    @StateObject private var spotifyService = SpotifyService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isAuthenticating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Connect to Spotify")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Connect your Spotify account to access cross-platform music profiles and search the Spotify catalog.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Benefits
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Search Spotify's 100M+ song catalog")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Unified ratings across all platforms")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Access to Spotify user reviews")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Auth button
                Button(action: {
                    authenticateSpotify()
                }) {
                    HStack {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Connecting...")
                        } else {
                            Image(systemName: "music.note.list")
                            Text("Connect to Spotify")
                        }
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Spotify Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func authenticateSpotify() {
        isAuthenticating = true
        
        Task {
            let success = await spotifyService.authenticateWithClientCredentials()
            
            await MainActor.run {
                isAuthenticating = false
                if success {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        MusicPlatformSettingsView()
    }
}
