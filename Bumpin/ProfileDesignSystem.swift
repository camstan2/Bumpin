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
    
    var body: some View {
        Text(itemType.capitalized)
            .font(ProfileDesignSystem.Typography.captionMedium)
            .fontWeight(.semibold)
            .foregroundColor(badgeColor)
            .padding(.horizontal, ProfileDesignSystem.Spacing.sm)
            .padding(.vertical, ProfileDesignSystem.Spacing.xs)
            .background(
                Capsule()
                    .fill(badgeColor.opacity(0.15))
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
    let userRating: Int
    let averageRating: Double
    let totalRatings: Int
    
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
                            Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
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
            
            // User rating display (read-only)
            VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
                Text("Your Rating")
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    if userRating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= userRating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(star <= userRating ? ProfileDesignSystem.Colors.ratingGold : ProfileDesignSystem.Colors.ratingInactive)
                            }
                        }
                        
                        Text("\(userRating) stars")
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                            .padding(.leading, ProfileDesignSystem.Spacing.sm)
                    } else {
                        Text("Not rated yet")
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
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
                            Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
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
        
        InteractiveRatingView(
            userRating: .constant(4),
            averageRating: 4.2,
            totalRatings: 156,
            onRatingChanged: { _ in }
        )
    }
    .padding()
}
