import SwiftUI

// MARK: - Profile Header Component

struct ProfileHeaderComponent: View {
    let title: String
    let subtitle: String
    let itemType: String
    let artworkURL: String?
    let averageRating: Double
    let totalRatings: Int
    let totalLogs: Int // Total number of logs
    let onActionTapped: () -> Void
    let crossPlatformInfo: String? // Cross-platform popularity info
    let itemId: String // For deep links
    let platform: String? // "apple_music", "spotify", etc.
    let onSubtitleTapped: (() -> Void)?
    
    // Convenience initializer for backwards compatibility
    init(
        title: String,
        subtitle: String,
        itemType: String,
        artworkURL: String?,
        averageRating: Double,
        totalRatings: Int,
        totalLogs: Int = 0,
        onActionTapped: @escaping () -> Void,
        crossPlatformInfo: String? = nil,
        itemId: String = "",
        platform: String? = nil,
        onSubtitleTapped: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.itemType = itemType
        self.artworkURL = artworkURL
        self.averageRating = averageRating
        self.totalRatings = totalRatings
        self.totalLogs = totalLogs
        self.onActionTapped = onActionTapped
        self.crossPlatformInfo = crossPlatformInfo
        self.itemId = itemId
        self.platform = platform
        self.onSubtitleTapped = onSubtitleTapped
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
                VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
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
                        
                        // Artist name as clickable button (only for songs and albums)
                        if itemType.lowercased() == "song" || itemType.lowercased() == "album" {
                            if let onSubtitleTapped = onSubtitleTapped {
                                Button(action: onSubtitleTapped) {
                                    Text(subtitle)
                                        .font(ProfileDesignSystem.Typography.bodyLarge)
                                        .foregroundColor(.purple)
                                        .lineLimit(1)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Text(subtitle)
                                    .font(ProfileDesignSystem.Typography.bodyLarge)
                                    .foregroundColor(.purple)
                                    .lineLimit(1)
                            }
                        } else {
                        Text(subtitle)
                            .font(ProfileDesignSystem.Typography.bodyLarge)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
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
            .buttonStyle(ScaleButtonStyle())
            .disabled(isActionLoading)
            
            // Listen On Platform Buttons
            if !itemId.isEmpty {
                ListenOnPlatformButtons(
                    itemId: itemId,
                    itemType: itemType,
                    platform: platform,
                    artistName: itemType == "artist" ? title : subtitle,
                    songTitle: itemType != "artist" ? title : nil
                )
            }
            
            // Preview Player Button (only for songs)
            if itemType.lowercased() == "song" && !itemId.isEmpty {
                PreviewPlayerButton(
                    itemId: itemId,
                    itemType: itemType,
                    platform: platform,
                    songTitle: title,
                    artistName: subtitle,
                    artworkURL: artworkURL
                )
            }
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
    
    @State private var hasAppeared = false
    
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
                        .scaleEffect(hasAppeared ? 1.0 : 0.8)
                        .opacity(hasAppeared ? 1.0 : 0.0)
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
                .offset(x: hasAppeared ? 0 : -10)
                .opacity(hasAppeared ? 1.0 : 0.0)
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
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                hasAppeared = true
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
