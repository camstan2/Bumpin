import SwiftUI
import FirebaseAuth

/// Demo view for testing and showcasing the social scoring system
struct SocialScoringDemoView: View {
    @State private var selectedDemo: DemoType = .ratingPrompt
    @State private var showingRatingPrompt = false
    @State private var showingScoreDisplay = false
    @State private var showingMyRatings = false
    @State private var demoUserProfile: UserProfile?
    @State private var demoSocialScore: SocialScore?
    @State private var demoRatingPrompt: RatingPrompt?
    
    enum DemoType: String, CaseIterable {
        case ratingPrompt = "Rating Prompt"
        case scoreDisplay = "Score Display"
        case myRatings = "My Ratings View"
        case badgeSystem = "Badge System"
        case interactionFlow = "Interaction Flow"
        
        var icon: String {
            switch self {
            case .ratingPrompt: return "star.circle.fill"
            case .scoreDisplay: return "chart.bar.fill"
            case .myRatings: return "list.star"
            case .badgeSystem: return "award.fill"
            case .interactionFlow: return "arrow.triangle.2.circlepath"
            }
        }
        
        var description: String {
            switch self {
            case .ratingPrompt: return "See how users rate each other after interactions"
            case .scoreDisplay: return "View different social score display styles"
            case .myRatings: return "View all individual ratings received from others"
            case .badgeSystem: return "Explore the social badge achievement system"
            case .interactionFlow: return "Understand the complete interaction tracking flow"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ProfileDesignSystem.Spacing.xl) {
                    // Header
                    headerSection
                    
                    // Demo Type Selector
                    demoTypeSelector
                    
                    // Demo Content
                    demoContent
                    
                    // Action Buttons
                    actionButtons
                }
                .padding(.horizontal, ProfileDesignSystem.Spacing.lg)
                .padding(.bottom, ProfileDesignSystem.Spacing.xxxxl)
            }
            .navigationTitle("Social Scoring Demo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                setupDemoData()
            }
        }
        .sheet(isPresented: $showingRatingPrompt) {
            if let prompt = demoRatingPrompt, let profile = demoUserProfile {
                SocialRatingPromptView(ratingPrompt: prompt, targetUserProfile: profile)
            }
        }
        .sheet(isPresented: $showingScoreDisplay) {
            SocialScoreDisplayDemoView(socialScore: demoSocialScore)
        }
        .sheet(isPresented: $showingMyRatings) {
            MyRatingsView()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(ProfileDesignSystem.Colors.primary)
            
            Text("Social Scoring System")
                .font(ProfileDesignSystem.Typography.displayMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text("Interactive demo of the post-interaction rating system")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(ProfileDesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.large)
                .fill(ProfileDesignSystem.Colors.primary.opacity(0.1))
        )
    }
    
    // MARK: - Demo Type Selector
    
    private var demoTypeSelector: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
            Text("Choose Demo")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ProfileDesignSystem.Spacing.md) {
                ForEach(DemoType.allCases, id: \.rawValue) { demoType in
                    DemoTypeCard(
                        demoType: demoType,
                        isSelected: selectedDemo == demoType,
                        onTap: {
                            selectedDemo = demoType
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Demo Content
    
    private var demoContent: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.lg) {
            switch selectedDemo {
            case .ratingPrompt:
                ratingPromptDemo
            case .scoreDisplay:
                scoreDisplayDemo
            case .myRatings:
                myRatingsDemo
            case .badgeSystem:
                badgeSystemDemo
            case .interactionFlow:
                interactionFlowDemo
            }
        }
    }
    
    // MARK: - Rating Prompt Demo
    
    private var ratingPromptDemo: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
            Text("Post-Talk Survey")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text("After a meaningful interaction with someone new, users are prompted to rate their experience on a scale of 1-10.")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            
            // Preview Card
            VStack(spacing: ProfileDesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(ProfileDesignSystem.Colors.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rate Your Interaction")
                            .font(ProfileDesignSystem.Typography.headlineSmall)
                            .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                        
                        Text("Discussion about favorite albums")
                            .font(ProfileDesignSystem.Typography.bodySmall)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
                
                // Star Rating Preview
                HStack(spacing: ProfileDesignSystem.Spacing.xs) {
                    ForEach(1...10, id: \.self) { index in
                        Image(systemName: index <= 8 ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundColor(index <= 8 ? ProfileDesignSystem.Colors.ratingActive : ProfileDesignSystem.Colors.ratingInactive)
                    }
                }
                
                Text("Excellent - really great time!")
                    .font(ProfileDesignSystem.Typography.bodySmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            }
            .padding(ProfileDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                    .fill(ProfileDesignSystem.Colors.surfaceElevated)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            
            // Key Features
            VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
                Text("Key Features:")
                    .font(ProfileDesignSystem.Typography.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                FeatureRow(icon: "eye.fill", title: "Mutual Visibility", description: "Only see their rating if you rate them")
                FeatureRow(icon: "clock.fill", title: "Smart Timing", description: "Prompts appear after meaningful interactions (60+ seconds)")
                FeatureRow(icon: "person.2.slash.fill", title: "Strangers Only", description: "No rating prompts between existing friends")
                FeatureRow(icon: "message.fill", title: "Optional Comments", description: "Add context with optional feedback text")
            }
        }
    }
    
    // MARK: - Score Display Demo
    
    private var scoreDisplayDemo: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
            Text("Social Score Display")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text("Social scores are displayed throughout the app in various formats:")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            
            if let score = demoSocialScore {
                VStack(spacing: ProfileDesignSystem.Spacing.lg) {
                    // Compact Display
                    VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
                        Text("Compact (in profiles)")
                            .font(ProfileDesignSystem.Typography.bodyLarge)
                            .fontWeight(.semibold)
                        
                        SocialScoreDisplayView(socialScore: score, displayStyle: .compact)
                            .padding(ProfileDesignSystem.Spacing.sm)
                            .background(ProfileDesignSystem.Colors.surface)
                            .cornerRadius(ProfileDesignSystem.CornerRadius.small)
                    }
                    
                    // Badge Display
                    VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
                        Text("Badge (overlay)")
                            .font(ProfileDesignSystem.Typography.bodyLarge)
                            .fontWeight(.semibold)
                        
                        HStack {
                            SocialScoreDisplayView(socialScore: score, displayStyle: .badge)
                            Spacer()
                        }
                        .padding(ProfileDesignSystem.Spacing.sm)
                        .background(ProfileDesignSystem.Colors.surface)
                        .cornerRadius(ProfileDesignSystem.CornerRadius.small)
                    }
                    
                    // Card Display
                    VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
                        Text("Card (detailed view)")
                            .font(ProfileDesignSystem.Typography.bodyLarge)
                            .fontWeight(.semibold)
                        
                        SocialScoreDisplayView(socialScore: score, displayStyle: .card)
                    }
                }
            }
        }
    }
    
    // MARK: - My Ratings Demo
    
    private var myRatingsDemo: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
            Text("Individual Ratings View")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text("Users can view all individual ratings they've received, but only the ones they've unlocked by rating others back:")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            
            // Preview Cards showing different rating types
            VStack(spacing: ProfileDesignSystem.Spacing.md) {
                // High Rating Example
                RatingPreviewCard(
                    raterName: "Alex Music Fan",
                    raterUsername: "musicfan23",
                    rating: 9,
                    context: "Discussion about jazz fusion",
                    comment: "Great conversation! Really enjoyed discussing different jazz artists and learned about some new musicians to check out.",
                    timeAgo: "2 hours ago",
                    isVisible: true
                )
                
                // Medium Rating Example
                RatingPreviewCard(
                    raterName: "DJ Master",
                    raterUsername: "djmaster",
                    rating: 7,
                    context: "Party listening session",
                    comment: nil,
                    timeAgo: "1 day ago",
                    isVisible: true
                )
                
                // Locked Rating Example
                RatingPreviewCard(
                    raterName: "Music Lover",
                    raterUsername: "musiclover99",
                    rating: 8,
                    context: "Discussion about indie rock",
                    comment: "Had a great time chatting about music!",
                    timeAgo: "3 days ago",
                    isVisible: false
                )
            }
            
            // Key Features
            VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
                Text("Key Features:")
                    .font(ProfileDesignSystem.Typography.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                FeatureRow(icon: "lock.fill", title: "Mutual Visibility", description: "Only see ratings after you rate them back")
                FeatureRow(icon: "line.3.horizontal.decrease.circle.fill", title: "Smart Filtering", description: "Filter by rating score, date, or comments")
                FeatureRow(icon: "bubble.left.and.bubble.right.fill", title: "Interaction Context", description: "See what activity the rating came from")
                FeatureRow(icon: "chart.line.uptrend.xyaxis.circle.fill", title: "Trend Analysis", description: "Track your social score improvements over time")
            }
        }
    }
    
    // MARK: - Badge System Demo
    
    private var badgeSystemDemo: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
            Text("Achievement Badges")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text("Users earn badges based on their social interactions and ratings:")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ProfileDesignSystem.Spacing.md) {
                ForEach(SocialScore.SocialBadge.availableBadges, id: \.id) { badge in
                    BadgePreviewCard(badge: badge)
                }
            }
        }
    }
    
    // MARK: - Interaction Flow Demo
    
    private var interactionFlowDemo: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
            Text("How It Works")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text("The complete flow from meeting someone to rating them:")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            
            VStack(spacing: ProfileDesignSystem.Spacing.md) {
                FlowStepCard(
                    step: 1,
                    title: "Users Meet",
                    description: "Join a discussion, party, or random chat",
                    icon: "person.2.fill",
                    color: ProfileDesignSystem.Colors.info
                )
                
                FlowStepCard(
                    step: 2,
                    title: "Interaction Tracked",
                    description: "System automatically detects new connections",
                    icon: "eye.fill",
                    color: ProfileDesignSystem.Colors.warning
                )
                
                FlowStepCard(
                    step: 3,
                    title: "Meaningful Duration",
                    description: "Interaction lasts 60+ seconds to qualify",
                    icon: "clock.fill",
                    color: ProfileDesignSystem.Colors.primary
                )
                
                FlowStepCard(
                    step: 4,
                    title: "Users Part Ways",
                    description: "Someone leaves the discussion/party",
                    icon: "arrow.right.circle.fill",
                    color: ProfileDesignSystem.Colors.success
                )
                
                FlowStepCard(
                    step: 5,
                    title: "Rating Prompt",
                    description: "Both users get prompted to rate the interaction",
                    icon: "star.circle.fill",
                    color: ProfileDesignSystem.Colors.ratingActive
                )
                
                FlowStepCard(
                    step: 6,
                    title: "Mutual Visibility",
                    description: "See their rating only after you rate them",
                    icon: "eye.circle.fill",
                    color: ProfileDesignSystem.Colors.textSecondary
                )
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            Button(action: {
                switch selectedDemo {
                case .ratingPrompt:
                    showingRatingPrompt = true
                case .scoreDisplay:
                    showingScoreDisplay = true
                case .myRatings:
                    showingMyRatings = true
                case .badgeSystem, .interactionFlow:
                    // These are displayed inline, no action needed
                    break
                }
            }) {
                HStack {
                    Image(systemName: selectedDemo.icon)
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Try \(selectedDemo.rawValue)")
                        .font(ProfileDesignSystem.Typography.bodyLarge)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                        .fill(ProfileDesignSystem.Colors.primary)
                )
            }
            .buttonStyle(BumpinPrimaryButtonStyle())
            .disabled(selectedDemo == .badgeSystem || selectedDemo == .interactionFlow)
            
            if selectedDemo == .badgeSystem || selectedDemo == .interactionFlow {
                Text("This demo is displayed above")
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            }
        }
    }
    
    // MARK: - Setup Demo Data
    
    private func setupDemoData() {
        // Create demo user profile
        demoUserProfile = UserProfile(
            uid: "demo_user",
            email: "demo@example.com",
            username: "musicfan23",
            displayName: "Alex Music Fan",
            createdAt: Date(),
            profilePictureUrl: nil,
            profileHeaderUrl: nil,
            bio: "Love discovering new music and meeting fellow music enthusiasts!",
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
            socialBadges: ["first_rating", "social_starter", "crowd_favorite"],
            socialScoreLastUpdated: Date()
        )
        
        // Create demo social score
        var score = SocialScore(userId: "demo_user")
        score.overallScore = 8.3
        score.totalRatings = 27
        score.recentScore = 8.7
        score.ratingsBreakdown = [10: 3, 9: 8, 8: 9, 7: 5, 6: 2]
        score.badges = [
            SocialScore.SocialBadge.createAvailableBadge(id: "first_rating", name: "First Impression", description: "Received your first social rating", iconName: "star.fill", minRatings: 1),
            SocialScore.SocialBadge.createAvailableBadge(id: "social_starter", name: "Social Starter", description: "Received 10 social ratings", iconName: "person.2.fill", minRatings: 10),
            SocialScore.SocialBadge.createAvailableBadge(id: "crowd_favorite", name: "Crowd Favorite", description: "Maintain an 8+ rating with 25+ ratings", iconName: "heart.fill", minScore: 8.0, minRatings: 25)
        ]
        demoSocialScore = score
        
        // Create demo rating prompt
        demoRatingPrompt = RatingPrompt(
            interactionId: "demo_interaction",
            promptedUserId: Auth.auth().currentUser?.uid ?? "current_user",
            targetUserId: "demo_user",
            interactionType: .discussion,
            interactionContext: "Discussion about favorite albums and music discovery"
        )
    }
}

// MARK: - Supporting Views

struct DemoTypeCard: View {
    let demoType: SocialScoringDemoView.DemoType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: ProfileDesignSystem.Spacing.sm) {
                Image(systemName: demoType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : ProfileDesignSystem.Colors.primary)
                
                Text(demoType.rawValue)
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : ProfileDesignSystem.Colors.textPrimary)
                
                Text(demoType.description)
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : ProfileDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(ProfileDesignSystem.Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                    .fill(isSelected ? ProfileDesignSystem.Colors.primary : ProfileDesignSystem.Colors.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                            .stroke(isSelected ? Color.clear : ProfileDesignSystem.Colors.primary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(BumpinButtonStyle())
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ProfileDesignSystem.Colors.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

struct BadgePreviewCard: View {
    let badge: SocialScore.SocialBadge
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.xs) {
            Image(systemName: badge.iconName)
                .font(.system(size: 24))
                .foregroundColor(ProfileDesignSystem.Colors.warning)
            
            Text(badge.name)
                .font(ProfileDesignSystem.Typography.captionLarge)
                .fontWeight(.semibold)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(badge.description)
                .font(ProfileDesignSystem.Typography.captionSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(ProfileDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                .fill(ProfileDesignSystem.Colors.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                        .stroke(ProfileDesignSystem.Colors.warning.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct FlowStepCard: View {
    let step: Int
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.md) {
            // Step number
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                
                Text("\(step)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(ProfileDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct SocialScoreDisplayDemoView: View {
    let socialScore: SocialScore?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ProfileDesignSystem.Spacing.xl) {
                    if let score = socialScore {
                        SocialScoreDisplayView(socialScore: score, displayStyle: .detailed)
                    }
                }
                .padding(ProfileDesignSystem.Spacing.lg)
            }
            .navigationTitle("Social Score Details")
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

struct RatingPreviewCard: View {
    let raterName: String
    let raterUsername: String
    let rating: Int
    let context: String
    let comment: String?
    let timeAgo: String
    let isVisible: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user info and rating
            HStack(spacing: 12) {
                // Profile picture
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Group {
                            if isVisible {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.purple)
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                
                // User details
                VStack(alignment: .leading, spacing: 2) {
                    Text(isVisible ? raterName : "Hidden User")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isVisible ? .primary : .secondary)
                    
                    Text(isVisible ? "@\(raterUsername)" : "@hidden")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Rating display
                if isVisible {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ratingColor(rating))
                            
                            Text("\(rating)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(ratingColor(rating))
                            
                            Text("/10")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(ratingQuality(rating))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(ratingColor(rating))
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text("?")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text("/10")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Locked")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Interaction context
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(context)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(timeAgo)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Comment (if provided and visible)
            if isVisible, let comment = comment, !comment.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        
                        Text("Comment:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                    
                    Text(comment)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.05))
                )
            } else if !isVisible {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text("Rate this user back to see their rating and comment")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.05))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isVisible ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
        .opacity(isVisible ? 1.0 : 0.7)
    }
    
    // MARK: - Helper Functions
    
    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 9...10: return .green
        case 7...8: return .blue
        case 5...6: return .orange
        default: return .red
        }
    }
    
    private func ratingQuality(_ rating: Int) -> String {
        switch rating {
        case 9...10: return "Excellent"
        case 7...8: return "Great"
        case 5...6: return "Good"
        case 3...4: return "Fair"
        default: return "Poor"
        }
    }
}

// MARK: - Preview

#Preview {
    SocialScoringDemoView()
}
