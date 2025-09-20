import SwiftUI

/// Reusable component for displaying social scores throughout the app
struct SocialScoreDisplayView: View {
    let socialScore: SocialScore?
    let displayStyle: DisplayStyle
    let showBadges: Bool
    
    enum DisplayStyle {
        case compact    // Small inline display
        case card      // Full card with details
        case badge     // Just the score as a badge
        case detailed  // Detailed view with breakdown
    }
    
    init(
        socialScore: SocialScore?,
        displayStyle: DisplayStyle = .compact,
        showBadges: Bool = true
    ) {
        self.socialScore = socialScore
        self.displayStyle = displayStyle
        self.showBadges = showBadges
    }
    
    var body: some View {
        Group {
            switch displayStyle {
            case .compact:
                compactView
            case .card:
                cardView
            case .badge:
                badgeView
            case .detailed:
                detailedView
            }
        }
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.xs) {
            if let score = socialScore {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(ProfileDesignSystem.Colors.ratingActive)
                
                Text(String(format: "%.1f", score.overallScore))
                    .font(ProfileDesignSystem.Typography.captionLarge)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                
                Text("(\(score.totalRatings))")
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                
                if showBadges && !score.badges.isEmpty {
                    Image(systemName: "award.fill")
                        .font(.caption2)
                        .foregroundColor(ProfileDesignSystem.Colors.warning)
                }
            } else {
                Text("No ratings yet")
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            }
        }
    }
    
    // MARK: - Badge View
    
    private var badgeView: some View {
        Group {
            if let score = socialScore {
                HStack(spacing: ProfileDesignSystem.Spacing.xs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    
                    Text(String(format: "%.1f", score.overallScore))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, ProfileDesignSystem.Spacing.sm)
                .padding(.vertical, ProfileDesignSystem.Spacing.xs)
                .background(
                    Capsule()
                        .fill(scoreColor(for: score.overallScore))
                )
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Card View
    
    private var cardView: some View {
        Group {
            if let score = socialScore {
                VStack(spacing: ProfileDesignSystem.Spacing.md) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.xs) {
                            Text("Social Score")
                                .font(ProfileDesignSystem.Typography.headlineSmall)
                                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                            
                            HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                                Text(String(format: "%.1f", score.overallScore))
                                    .font(ProfileDesignSystem.Typography.displaySmall)
                                    .fontWeight(.bold)
                                    .foregroundColor(scoreColor(for: score.overallScore))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 2) {
                                        ForEach(0..<5, id: \.self) { index in
                                            Image(systemName: index < Int(score.overallScore / 2) ? "star.fill" : "star")
                                                .font(.caption2)
                                                .foregroundColor(ProfileDesignSystem.Colors.ratingActive)
                                        }
                                    }
                                    
                                    Text("\(score.totalRatings) ratings")
                                        .font(ProfileDesignSystem.Typography.captionMedium)
                                        .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if showBadges && !score.badges.isEmpty {
                            badgePreview(badges: score.badges)
                        }
                    }
                    
                    // Recent trend
                    if score.recentScore != score.overallScore {
                        trendIndicator(overall: score.overallScore, recent: score.recentScore)
                    }
                }
                .padding(ProfileDesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                        .fill(ProfileDesignSystem.Colors.surfaceElevated)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            } else {
                noRatingsCard
            }
        }
    }
    
    // MARK: - Detailed View
    
    private var detailedView: some View {
        Group {
            if let score = socialScore {
                VStack(spacing: ProfileDesignSystem.Spacing.lg) {
                    // Main score display
                    cardView
                    
                    // Rating breakdown
                    ratingBreakdownView(breakdown: score.ratingsBreakdown, total: score.totalRatings)
                    
                    // Badges section
                    if showBadges && !score.badges.isEmpty {
                        badgeDetailView(badges: score.badges)
                    }
                }
            } else {
                noRatingsCard
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var noRatingsCard: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            Image(systemName: "star.circle")
                .font(.system(size: 40))
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            
            Text("No Social Ratings Yet")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            
            Text("Interact with others to start building your social score!")
                .font(ProfileDesignSystem.Typography.bodySmall)
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(ProfileDesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                .fill(ProfileDesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                        .stroke(ProfileDesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func badgePreview(badges: [SocialScore.SocialBadge]) -> some View {
        HStack(spacing: ProfileDesignSystem.Spacing.xs) {
            ForEach(badges.prefix(3), id: \.id) { badge in
                Image(systemName: badge.iconName)
                    .font(.caption)
                    .foregroundColor(ProfileDesignSystem.Colors.warning)
            }
            
            if badges.count > 3 {
                Text("+\(badges.count - 3)")
                    .font(ProfileDesignSystem.Typography.captionSmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            }
        }
        .padding(.horizontal, ProfileDesignSystem.Spacing.sm)
        .padding(.vertical, ProfileDesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                .fill(ProfileDesignSystem.Colors.warning.opacity(0.1))
        )
    }
    
    private func trendIndicator(overall: Double, recent: Double) -> some View {
        let isImproving = recent > overall
        let difference = abs(recent - overall)
        
        return HStack(spacing: ProfileDesignSystem.Spacing.xs) {
            Image(systemName: isImproving ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
                .foregroundColor(isImproving ? ProfileDesignSystem.Colors.success : ProfileDesignSystem.Colors.warning)
            
            Text("Recent: \(String(format: "%.1f", recent))")
                .font(ProfileDesignSystem.Typography.captionMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            
            Text(isImproving ? "↗" : "↘")
                .font(.caption2)
                .foregroundColor(isImproving ? ProfileDesignSystem.Colors.success : ProfileDesignSystem.Colors.warning)
        }
        .padding(.horizontal, ProfileDesignSystem.Spacing.sm)
        .padding(.vertical, ProfileDesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                .fill((isImproving ? ProfileDesignSystem.Colors.success : ProfileDesignSystem.Colors.warning).opacity(0.1))
        )
    }
    
    private func ratingBreakdownView(breakdown: [Int: Int], total: Int) -> some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
            Text("Rating Breakdown")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            VStack(spacing: ProfileDesignSystem.Spacing.xs) {
                ForEach((1...10).reversed(), id: \.self) { rating in
                    let count = breakdown[rating] ?? 0
                    let percentage = total > 0 ? Double(count) / Double(total) : 0.0
                    
                    if count > 0 {
                        HStack {
                            Text("\(rating)")
                                .font(ProfileDesignSystem.Typography.captionMedium)
                                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                                .frame(width: 20, alignment: .trailing)
                            
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(ProfileDesignSystem.Colors.ratingActive)
                            
                            GeometryReader { geometry in
                                HStack {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(scoreColor(for: Double(rating)))
                                        .frame(width: geometry.size.width * percentage)
                                    
                                    Spacer()
                                }
                            }
                            .frame(height: 4)
                            
                            Text("\(count)")
                                .font(ProfileDesignSystem.Typography.captionSmall)
                                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                                .frame(width: 20)
                        }
                    }
                }
            }
        }
        .padding(ProfileDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                .fill(ProfileDesignSystem.Colors.surface)
        )
    }
    
    private func badgeDetailView(badges: [SocialScore.SocialBadge]) -> some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
            Text("Social Badges")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ProfileDesignSystem.Spacing.sm) {
                ForEach(badges, id: \.id) { badge in
                    BadgeView(badge: badge)
                }
            }
        }
        .padding(ProfileDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                .fill(ProfileDesignSystem.Colors.surface)
        )
    }
    
    // MARK: - Helper Functions
    
    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 0..<4:
            return ProfileDesignSystem.Colors.error
        case 4..<6:
            return ProfileDesignSystem.Colors.warning
        case 6..<8:
            return ProfileDesignSystem.Colors.info
        case 8...10:
            return ProfileDesignSystem.Colors.success
        default:
            return ProfileDesignSystem.Colors.textTertiary
        }
    }
}

// MARK: - Badge View Component

struct BadgeView: View {
    let badge: SocialScore.SocialBadge
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.xs) {
            Image(systemName: badge.iconName)
                .font(.system(size: 20))
                .foregroundColor(ProfileDesignSystem.Colors.warning)
            
            Text(badge.name)
                .font(ProfileDesignSystem.Typography.captionMedium)
                .fontWeight(.medium)
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

// MARK: - Preview

#Preview {
    let sampleBadges = [
        SocialScore.SocialBadge(
            id: "social_starter",
            name: "Social Starter",
            description: "Received 10 social ratings",
            iconName: "person.2.fill",
            earnedAt: Date(),
            requirements: SocialScore.SocialBadge.BadgeRequirements(minScore: nil, minRatings: 10, specificAchievement: nil)
        ),
        SocialScore.SocialBadge(
            id: "crowd_favorite",
            name: "Crowd Favorite",
            description: "Maintain an 8+ rating with 25+ ratings",
            iconName: "heart.fill",
            earnedAt: Date(),
            requirements: SocialScore.SocialBadge.BadgeRequirements(minScore: 8.0, minRatings: 25, specificAchievement: nil)
        )
    ]
    
    let sampleScore = SocialScore(userId: "sample")
    var score = sampleScore
    score.overallScore = 8.5
    score.totalRatings = 42
    score.recentScore = 8.8
    score.ratingsBreakdown = [10: 5, 9: 8, 8: 12, 7: 10, 6: 4, 5: 2, 4: 1]
    score.badges = sampleBadges
    
    return VStack(spacing: 20) {
        SocialScoreDisplayView(socialScore: score, displayStyle: .compact)
        SocialScoreDisplayView(socialScore: score, displayStyle: .badge)
        SocialScoreDisplayView(socialScore: score, displayStyle: .card)
        SocialScoreDisplayView(socialScore: nil, displayStyle: .card)
    }
    .padding()
}
