import SwiftUI

// MARK: - Profile Header Component

struct ProfileHeaderComponent: View {
    let title: String
    let subtitle: String
    let itemType: String
    let artworkURL: String?
    let averageRating: Double
    let totalRatings: Int
    let onActionTapped: () -> Void
    let crossPlatformInfo: String? // Cross-platform popularity info
    
    // Convenience initializer for backwards compatibility
    init(
        title: String,
        subtitle: String,
        itemType: String,
        artworkURL: String?,
        averageRating: Double,
        totalRatings: Int,
        onActionTapped: @escaping () -> Void,
        crossPlatformInfo: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.itemType = itemType
        self.artworkURL = artworkURL
        self.averageRating = averageRating
        self.totalRatings = totalRatings
        self.onActionTapped = onActionTapped
        self.crossPlatformInfo = crossPlatformInfo
    }
    
    @State private var isActionLoading = false
    @State private var actionSuccess = false
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.xl) {
            // Main content
            HStack(alignment: .top, spacing: ProfileDesignSystem.Spacing.xl) {
                // Artwork
                ProfileArtworkView(
                    artworkURL: artworkURL,
                    size: 120,
                    cornerRadius: ProfileDesignSystem.CornerRadius.large
                )
                
                // Content
                VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
                    // Item type badge
                    ProfileItemTypeBadge(itemType: itemType)
                    
                    // Title and subtitle
                    VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.xs) {
                        Text(title)
                            .font(ProfileDesignSystem.Typography.displayMedium)
                            .fontWeight(.bold)
                            .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(subtitle)
                            .font(ProfileDesignSystem.Typography.bodyLarge)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    // Quick stats
                    if totalRatings > 0 {
                        HStack(spacing: ProfileDesignSystem.Spacing.md) {
                            ProfileQuickStat(
                                icon: "star.fill",
                                value: String(format: "%.1f", averageRating),
                                label: "Rating",
                                color: ProfileDesignSystem.Colors.ratingGold
                            )
                            
                            ProfileQuickStat(
                                icon: "person.2",
                                value: "\(totalRatings)",
                                label: "Reviews",
                                color: ProfileDesignSystem.Colors.info
                            )
                        }
                    }
                }
                
                Spacer()
            }
            
            // Cross-platform info (if available)
            if let crossPlatformInfo = crossPlatformInfo {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(crossPlatformInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            
            // Action button
            Button(action: {
                if !isActionLoading {
                    isActionLoading = true
                    onActionTapped()
                    
                    // Simulate action completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isActionLoading = false
                        actionSuccess = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            actionSuccess = false
                        }
                    }
                }
            }) {
                HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    if isActionLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Adding...")
                    } else if actionSuccess {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Added to Listen Later")
                    } else {
                        Image(systemName: "plus.circle.fill")
                        Text("Listen Later")
                    }
                }
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(ProfileDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                        .fill(ProfileDesignSystem.Colors.primary.gradient)
                )
            }
            .disabled(isActionLoading)
            .scaleEffect(isActionLoading ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isActionLoading)
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard(elevation: ProfileDesignSystem.Shadows.large)
    }
}

// MARK: - Section Header Component

struct ProfileSectionHeader: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(title: String, subtitle: String? = nil, icon: String? = nil, action: (() -> Void)? = nil, actionTitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(ProfileDesignSystem.Typography.headlineSmall)
                        .foregroundColor(ProfileDesignSystem.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ProfileDesignSystem.Typography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                    }
                    .font(ProfileDesignSystem.Typography.captionLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(ProfileDesignSystem.Colors.primary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        ProfileHeaderComponent(
            title: "BANG!",
            subtitle: "Trippie Redd",
            itemType: "song",
            artworkURL: nil,
            averageRating: 4.2,
            totalRatings: 156,
            onActionTapped: {}
        )
        
        ProfileSectionHeader(
            title: "Rating Distribution",
            subtitle: "See how users rated this song",
            icon: "chart.bar.fill",
            action: {},
            actionTitle: "View All"
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
