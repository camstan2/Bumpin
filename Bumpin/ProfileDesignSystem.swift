import SwiftUI

// MARK: - Profile Design System

struct ProfileDesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary brand colors
        static let primary = Color.purple
        static let primaryLight = Color.purple.opacity(0.8)
        static let primaryDark = Color.purple.opacity(1.2)
        
        // Rating colors
        static let ratingGold = Color.orange
        static let ratingActive = Color.orange
        static let ratingInactive = Color.gray.opacity(0.3)
        
        // Status colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // Surface colors
        static let surface = Color(.systemGray6)
        static let surfaceElevated = Color(.systemBackground)
        static let surfaceSecondary = Color(.secondarySystemBackground)
        
        // Text colors
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.secondary.opacity(0.7)
    }
    
    // MARK: - Typography
    struct Typography {
        // Display fonts for main headers
        static let displayLarge = Font.system(size: 32, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 24, weight: .semibold, design: .rounded)
        
        // Headline fonts for section headers
        static let headlineLarge = Font.system(size: 22, weight: .bold)
        static let headlineMedium = Font.system(size: 20, weight: .semibold)
        static let headlineSmall = Font.system(size: 18, weight: .semibold)
        
        // Body fonts for content
        static let bodyLarge = Font.system(size: 17, weight: .medium)
        static let bodyMedium = Font.system(size: 15, weight: .regular)
        static let bodySmall = Font.system(size: 13, weight: .regular)
        
        // Caption fonts for metadata
        static let captionLarge = Font.system(size: 12, weight: .medium)
        static let captionMedium = Font.system(size: 11, weight: .medium)
        static let captionSmall = Font.system(size: 10, weight: .regular)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let xxxxl: CGFloat = 40
        
        // Section-specific spacing
        static let sectionGap = xxxl
        static let cardPadding = lg
        static let contentPadding = lg
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
    }
    
    // MARK: - Shadows
    struct Shadows {
        struct ShadowStyle {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        static let small = ShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        static let medium = ShadowStyle(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        static let large = ShadowStyle(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
}

// MARK: - Design System View Modifiers

struct ProfileCardModifier: ViewModifier {
    let elevation: ProfileDesignSystem.Shadows.ShadowStyle
    
    init(elevation: ProfileDesignSystem.Shadows.ShadowStyle = ProfileDesignSystem.Shadows.medium) {
        self.elevation = elevation
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                    .fill(ProfileDesignSystem.Colors.surfaceElevated)
                    .shadow(
                        color: elevation.color,
                        radius: elevation.radius,
                        x: elevation.x,
                        y: elevation.y
                    )
            )
    }
}

struct ProfileSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, ProfileDesignSystem.Spacing.contentPadding)
    }
}

// MARK: - View Extensions

extension View {
    func profileCard(elevation: ProfileDesignSystem.Shadows.ShadowStyle = ProfileDesignSystem.Shadows.medium) -> some View {
        modifier(ProfileCardModifier(elevation: elevation))
    }
    
    func profileSection() -> some View {
        modifier(ProfileSectionModifier())
    }
}

// MARK: - Reusable Profile Components

struct ProfileArtworkView: View {
    let artworkURL: String?
    let size: CGFloat
    let cornerRadius: CGFloat
    
    init(artworkURL: String?, size: CGFloat = 120, cornerRadius: CGFloat = ProfileDesignSystem.CornerRadius.large) {
        self.artworkURL = artworkURL
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let artworkURL = artworkURL, let url = URL(string: artworkURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        placeholderView
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(
            color: ProfileDesignSystem.Shadows.medium.color,
            radius: ProfileDesignSystem.Shadows.medium.radius,
            x: ProfileDesignSystem.Shadows.medium.x,
            y: ProfileDesignSystem.Shadows.medium.y
        )
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(ProfileDesignSystem.Colors.surface)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            )
    }
}

struct ProfileItemTypeBadge: View {
    let itemType: String
    
    private var badgeColor: Color {
        switch itemType.lowercased() {
        case "song": return ProfileDesignSystem.Colors.info
        case "album": return ProfileDesignSystem.Colors.primary
        case "artist": return ProfileDesignSystem.Colors.success
        default: return ProfileDesignSystem.Colors.textSecondary
        }
    }
    
    private var badgeIcon: String {
        switch itemType.lowercased() {
        case "song": return "music.note"
        case "album": return "square.stack.fill"
        case "artist": return "person.fill"
        default: return "music.note"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(badgeColor)
            
            Text(itemType.capitalized)
                .font(ProfileDesignSystem.Typography.captionMedium)
                .fontWeight(.semibold)
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, ProfileDesignSystem.Spacing.sm)
        .padding(.vertical, ProfileDesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(badgeColor.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

struct ProfileQuickStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.xs) {
            HStack(spacing: ProfileDesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(color)
                Text(value)
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            }
            
            Text(label)
                .font(ProfileDesignSystem.Typography.captionSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
        }
        .padding(ProfileDesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Display Only Rating Component

struct DisplayOnlyRatingView: View {
    let userRating: Double // Changed from Int to Double to support half stars
    let averageRating: Double
    let totalRatings: Int
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.xl) {
            // User rating in top-left (subtle) - IMPROVED SPACING - Now with half-star support
            if userRating > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Rating")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        // Use StarRatingDisplayView for half-star support
                        StarRatingDisplayView(
                            rating: userRating,
                            starSize: 16, // Slightly smaller for the compact "Your Rating" section
                            spacing: 3,
                            showNumber: false
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                    Spacer()
                }
            }
            
            // Overall rating - HERO section (center of attention) - ENHANCED CARD
            VStack(spacing: ProfileDesignSystem.Spacing.lg) {
                // Large rating number
                Text(String(format: "%.1f", averageRating))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(ProfileDesignSystem.Colors.ratingGold)
                    .shadow(color: ProfileDesignSystem.Colors.ratingGold.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Star visualization with partial fill support
                StarRatingDisplayView(
                    rating: averageRating,
                    starSize: 28,
                    spacing: 6,
                    showNumber: false
                )
                
                // Total ratings count
                Text("\(totalRatings) total ratings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ProfileDesignSystem.Spacing.xl)
            .padding(.horizontal, ProfileDesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.large)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard(elevation: ProfileDesignSystem.Shadows.medium)
    }
    
}

// MARK: - Interactive Rating Component

struct InteractiveRatingView: View {
    @Binding var userRating: Int
    let averageRating: Double
    let totalRatings: Int
    let onRatingChanged: (Int) -> Void
    
    @State private var tempRating: Int = 0
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            // Community rating display
            VStack(spacing: ProfileDesignSystem.Spacing.xs) {
                HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    Text(String(format: "%.1f", averageRating))
                        .font(ProfileDesignSystem.Typography.headlineLarge)
                        .fontWeight(.bold)
                        .foregroundColor(ProfileDesignSystem.Colors.ratingGold)
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: starIconForAverage(position: star, rating: averageRating))
                                .font(ProfileDesignSystem.Typography.bodyMedium)
                                .foregroundColor(ProfileDesignSystem.Colors.ratingGold)
                        }
                    }
                    
                    Spacer()
                }
                
                Text("\(totalRatings) ratings")
                    .font(ProfileDesignSystem.Typography.captionLarge)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // User rating interface
            VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
                Text("Your Rating")
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: {
                            let newRating = userRating == star ? 0 : star
                            userRating = newRating
                            onRatingChanged(newRating)
                        }) {
                            Image(systemName: star <= userRating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(star <= userRating ? ProfileDesignSystem.Colors.ratingGold : ProfileDesignSystem.Colors.ratingInactive)
                                .scaleEffect(tempRating == star ? 1.2 : 1.0)
                        }
                        .onLongPressGesture(minimumDuration: 0) {
                            tempRating = star
                        } onPressingChanged: { pressing in
                            if !pressing {
                                tempRating = 0
                            }
                        }
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: tempRating)
                    }
                    
                    if userRating > 0 {
                        Button("Clear") {
                            userRating = 0
                            onRatingChanged(0)
                        }
                        .font(ProfileDesignSystem.Typography.captionLarge)
                        .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                        .padding(.leading, ProfileDesignSystem.Spacing.sm)
                    }
                }
            }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
    }
    
    // MARK: - Helper for Half-Star Rendering
    private func starIconForAverage(position: Int, rating: Double) -> String {
        let starThreshold = Double(position)
        let halfStarThreshold = Double(position) - 0.5
        
        if rating >= starThreshold {
            return "star.fill"
        } else if rating >= halfStarThreshold {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Partial Star Rating Component

struct PartialStarRatingView: View {
    let rating: Double
    let starSize: CGFloat
    let spacing: CGFloat
    let showNumericRating: Bool
    let numericRatingFont: Font
    
    init(
        rating: Double,
        starSize: CGFloat = 14,
        spacing: CGFloat = 2,
        showNumericRating: Bool = true,
        numericRatingFont: Font = .caption
    ) {
        self.rating = max(0, min(5, rating)) // Clamp between 0 and 5
        self.starSize = starSize
        self.spacing = spacing
        self.showNumericRating = showNumericRating
        self.numericRatingFont = numericRatingFont
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Numeric rating
            if showNumericRating {
                Text(String(format: "%.1f", rating))
                    .font(numericRatingFont)
                    .fontWeight(.semibold)
                    .foregroundColor(ProfileDesignSystem.Colors.ratingGold)
                    .monospacedDigit()
            }
            
            // Star visualization
            HStack(spacing: spacing) {
                ForEach(1...5, id: \.self) { position in
                    PartialStarView(
                        position: position,
                        rating: rating,
                        size: starSize
                    )
                }
            }
        }
    }
}

// MARK: - Individual Partial Star

private struct PartialStarView: View {
    let position: Int
    let rating: Double
    let size: CGFloat
    
    private var fillPercentage: Double {
        let starStart = Double(position - 1)
        let starEnd = Double(position)
        
        if rating >= starEnd {
            return 1.0 // Fully filled
        } else if rating > starStart {
            return rating - starStart // Partially filled
        } else {
            return 0.0 // Empty
        }
    }
    
    var body: some View {
        ZStack {
            // Background (empty star)
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundColor(ProfileDesignSystem.Colors.ratingInactive)
            
            // Foreground (filled portion with gradient mask)
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ProfileDesignSystem.Colors.ratingGold,
                            ProfileDesignSystem.Colors.ratingGold.opacity(0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    GeometryReader { geometry in
                        Rectangle()
                            .frame(width: geometry.size.width * fillPercentage)
                    }
                )
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileArtworkView(
            artworkURL: "https://example.com/artwork.jpg",
            size: 120
        )
        
        ProfileItemTypeBadge(itemType: "song")
        
        ProfileQuickStat(
            icon: "star.fill",
            value: "4.2",
            label: "Average",
            color: .orange
        )
        
        // Showcase partial star ratings
        VStack(alignment: .leading, spacing: 12) {
            PartialStarRatingView(rating: 1.6, starSize: 16)
            PartialStarRatingView(rating: 3.4, starSize: 16)
            PartialStarRatingView(rating: 4.5, starSize: 16)
            PartialStarRatingView(rating: 2.7, starSize: 16)
        }
        
        InteractiveRatingView(
            userRating: .constant(4),
            averageRating: 4.2,
            totalRatings: 156,
            onRatingChanged: { _ in }
        )
    }
    .padding()
}
