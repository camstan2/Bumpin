import SwiftUI

// MARK: - Music Platform Onboarding Flow

struct MusicPlatformOnboardingView: View {
    @StateObject private var unifiedSearchService = UnifiedMusicSearchService.shared
    @StateObject private var spotifyService = SpotifyService.shared
    @State private var showingSpotifyAuth = false
    @State private var selectedPreference: UnifiedMusicSearchService.MusicPlatformPreference = .appleMusicOnly
    @Environment(\.presentationMode) var presentationMode
    
    let onComplete: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Choose Your Music Platform")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Select your preferred music service. Don't worry, you can change this later in Settings.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // Platform options
                    VStack(spacing: 12) {
                        ForEach(UnifiedMusicSearchService.MusicPlatformPreference.allCases, id: \.rawValue) { preference in
                            OnboardingPlatformCard(
                                preference: preference,
                                isSelected: selectedPreference == preference,
                                isSpotifyAuthenticated: spotifyService.isAuthenticated
                            ) {
                                selectedPreference = preference
                                
                                // Authenticate Spotify if needed
                                if preference != .appleMusicOnly && !spotifyService.isAuthenticated {
                                    showingSpotifyAuth = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Benefits section
                    VStack(spacing: 16) {
                        Text("Why Cross-Platform?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            OnboardingBenefit(
                                icon: "person.2.fill",
                                title: "More Social Data",
                                description: "See ratings from users on all platforms"
                            )
                            
                            OnboardingBenefit(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Better Trending",
                                description: "More accurate data from larger user base"
                            )
                            
                            OnboardingBenefit(
                                icon: "link",
                                title: "Platform Freedom",
                                description: "Switch services without losing your social data"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                    
                    // Continue button
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.purple.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(28)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Music Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        // Use Apple Music only as default
                        unifiedSearchService.setPlatformPreference(.appleMusicOnly)
                        onComplete()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingSpotifyAuth) {
            SpotifyAuthView()
        }
    }
    
    private func completeOnboarding() {
        unifiedSearchService.setPlatformPreference(selectedPreference)
        UserDefaults.standard.set(true, forKey: "music_platform_onboarding_completed")
        onComplete()
    }
}

// MARK: - Onboarding Platform Card

struct OnboardingPlatformCard: View {
    let preference: UnifiedMusicSearchService.MusicPlatformPreference
    let isSelected: Bool
    let isSpotifyAuthenticated: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Platform icon
                Image(systemName: platformIcon)
                    .foregroundColor(platformColor)
                    .font(.title)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(preference.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(platformDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                        .font(.title2)
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.purple.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.purple.opacity(0.5) : Color.clear, lineWidth: 2)
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
        case .appleMusicOnly: return "Use only Apple Music for search and discovery"
        case .spotifyOnly: return "Use only Spotify for search and discovery"
        case .both: return "Search both platforms with equal priority"
        case .appleMusicPrimary: return "Prefer Apple Music, but include Spotify results"
        case .spotifyPrimary: return "Prefer Spotify, but include Apple Music results"
        }
    }
    
    private var isAvailable: Bool {
        switch preference {
        case .appleMusicOnly, .appleMusicPrimary: return true
        case .spotifyOnly, .spotifyPrimary, .both: return isSpotifyAuthenticated
        }
    }
}

// MARK: - Onboarding Benefit

struct OnboardingBenefit: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Cross-Platform Migration Prompt

struct CrossPlatformMigrationPrompt: View {
    @Environment(\.presentationMode) var presentationMode
    let onMigrate: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Upgrade to Cross-Platform")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Connect your Spotify account to see unified music profiles across all platforms.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                // Benefits
                VStack(spacing: 16) {
                    Text("What You'll Get")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        OnboardingBenefit(
                            icon: "person.2.fill",
                            title: "Unified Profiles",
                            description: "See ratings from Apple Music and Spotify users together"
                        )
                        
                        OnboardingBenefit(
                            icon: "magnifyingglass",
                            title: "Expanded Search",
                            description: "Search both Apple Music and Spotify catalogs"
                        )
                        
                        OnboardingBenefit(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Better Recommendations",
                            description: "More accurate trending data from larger user base"
                        )
                        
                        OnboardingBenefit(
                            icon: "link",
                            title: "Keep Your Data",
                            description: "Your Apple Music ratings stay with you forever"
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onMigrate()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Enable Cross-Platform")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.purple.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(28)
                    }
                    
                    Button(action: {
                        onDismiss()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Cross-Platform Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onDismiss()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MusicPlatformOnboardingView {
        print("Onboarding completed")
    }
}
