import SwiftUI

/// Reusable component for displaying users with their social scores in lists
struct UserCardWithSocialScore: View {
    let user: UserProfile
    let showSocialScore: Bool
    let displayStyle: DisplayStyle
    let onTap: (() -> Void)?
    
    enum DisplayStyle {
        case compact    // Small inline display
        case card       // Full card with details
        case list       // List row format
    }
    
    init(
        user: UserProfile,
        showSocialScore: Bool = true,
        displayStyle: DisplayStyle = .compact,
        onTap: (() -> Void)? = nil
    ) {
        self.user = user
        self.showSocialScore = showSocialScore
        self.displayStyle = displayStyle
        self.onTap = onTap
    }
    
    var body: some View {
        Group {
            switch displayStyle {
            case .compact:
                compactView
            case .card:
                cardView
            case .list:
                listView
            }
        }
        .onTapGesture {
            onTap?()
        }
    }
    
    // MARK: - Compact View (for small spaces)
    
    private var compactView: some View {
        HStack(spacing: 8) {
            // Profile Picture
            profilePicture
            
            // Name and Score
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if showSocialScore, let socialScore = user.socialScore, let totalRatings = user.totalSocialRatings, totalRatings > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        
                        Text(String(format: "%.1f", socialScore))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("(\(totalRatings))")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Card View (for participant grids)
    
    private var cardView: some View {
        VStack(spacing: 12) {
            // Profile Picture
            profilePicture
                .frame(width: 60, height: 60)
            
            // Name and Username
            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("@\(user.username)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Social Score (if available)
            if showSocialScore, let socialScore = user.socialScore, let totalRatings = user.totalSocialRatings, totalRatings > 0 {
                socialScoreBadge(socialScore: socialScore, totalRatings: totalRatings)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - List View (for participant lists)
    
    private var listView: some View {
        HStack(spacing: 12) {
            // Profile Picture
            profilePicture
                .frame(width: 40, height: 40)
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if showSocialScore, let socialScore = user.socialScore, let totalRatings = user.totalSocialRatings, totalRatings > 0 {
                        socialScorePill(socialScore: socialScore, totalRatings: totalRatings)
                    }
                }
                
                Text("@\(user.username)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Profile Picture
    
    private var profilePicture: some View {
        Circle()
            .fill(Color.purple.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
            )
    }
    
    // MARK: - Social Score Components
    
    private func socialScoreBadge(socialScore: Double, totalRatings: Int) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(scoreColor(socialScore))
                
                Text(String(format: "%.1f", socialScore))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(scoreColor(socialScore))
            }
            
            Text("\(totalRatings) rating\(totalRatings == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(scoreColor(socialScore).opacity(0.1))
        )
    }
    
    private func socialScorePill(socialScore: Double, totalRatings: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(scoreColor(socialScore))
            
            Text(String(format: "%.1f", socialScore))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(scoreColor(socialScore))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(scoreColor(socialScore).opacity(0.15))
        )
    }
    
    // MARK: - Helper Functions
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 8.5...10.0: return .orange
        case 7.0..<8.5: return .blue
        case 5.0..<7.0: return .yellow
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Compact View
        UserCardWithSocialScore(
            user: UserProfile(
                uid: "preview_user",
                email: "preview@example.com",
                username: "musicfan",
                displayName: "Alex Music Fan",
                createdAt: Date(),
                profilePictureUrl: nil,
                profileHeaderUrl: nil,
                bio: "Love discovering new music!",
                followers: [],
                following: [],
                isVerified: false,
                roles: [],
                reportCount: 0,
                violationCount: 0,
                locationSharingWith: [],
                showNowPlaying: true,
                nowPlayingSong: nil,
                nowPlayingArtist: nil,
                nowPlayingAlbumArt: nil,
                nowPlayingUpdatedAt: nil,
                pinnedSongs: [],
                pinnedArtists: [],
                pinnedAlbums: [],
                pinnedLists: [],
                pinnedSongsRanked: false,
                pinnedArtistsRanked: false,
                pinnedAlbumsRanked: false,
                pinnedListsRanked: false,
                matchmakingOptIn: false,
                matchmakingGender: nil,
                matchmakingPreferredGender: nil,
                matchmakingLastActive: nil,
                socialScore: 8.3,
                totalSocialRatings: 27,
                socialBadges: ["first_rating", "social_starter"],
                socialScoreLastUpdated: Date()
            ),
            displayStyle: .compact
        )
        
        // Card View
        UserCardWithSocialScore(
            user: UserProfile(
                uid: "preview_user2",
                email: "preview2@example.com",
                username: "djmaster",
                displayName: "DJ Master",
                createdAt: Date(),
                profilePictureUrl: nil,
                profileHeaderUrl: nil,
                bio: "Professional DJ and music producer",
                followers: [],
                following: [],
                isVerified: false,
                roles: [],
                reportCount: 0,
                violationCount: 0,
                locationSharingWith: [],
                showNowPlaying: true,
                nowPlayingSong: nil,
                nowPlayingArtist: nil,
                nowPlayingAlbumArt: nil,
                nowPlayingUpdatedAt: nil,
                pinnedSongs: [],
                pinnedArtists: [],
                pinnedAlbums: [],
                pinnedLists: [],
                pinnedSongsRanked: false,
                pinnedArtistsRanked: false,
                pinnedAlbumsRanked: false,
                pinnedListsRanked: false,
                matchmakingOptIn: false,
                matchmakingGender: nil,
                matchmakingPreferredGender: nil,
                matchmakingLastActive: nil,
                socialScore: 9.1,
                totalSocialRatings: 45,
                socialBadges: ["crowd_favorite", "social_butterfly"],
                socialScoreLastUpdated: Date()
            ),
            displayStyle: .card
        )
        
        // List View
        UserCardWithSocialScore(
            user: UserProfile(
                uid: "preview_user3",
                email: "preview3@example.com",
                username: "newuser",
                displayName: "New User",
                createdAt: Date(),
                profilePictureUrl: nil,
                profileHeaderUrl: nil,
                bio: "Just getting started!",
                followers: [],
                following: [],
                isVerified: false,
                roles: [],
                reportCount: 0,
                violationCount: 0,
                locationSharingWith: [],
                showNowPlaying: true,
                nowPlayingSong: nil,
                nowPlayingArtist: nil,
                nowPlayingAlbumArt: nil,
                nowPlayingUpdatedAt: nil,
                pinnedSongs: [],
                pinnedArtists: [],
                pinnedAlbums: [],
                pinnedLists: [],
                pinnedSongsRanked: false,
                pinnedArtistsRanked: false,
                pinnedAlbumsRanked: false,
                pinnedListsRanked: false,
                matchmakingOptIn: false,
                matchmakingGender: nil,
                matchmakingPreferredGender: nil,
                matchmakingLastActive: nil,
                socialScore: 7.2,
                totalSocialRatings: 8,
                socialBadges: ["first_rating"],
                socialScoreLastUpdated: Date()
            ),
            displayStyle: .list
        )
    }
    .padding()
}
