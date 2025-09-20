import SwiftUI

enum AppTheme {
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24

    // Cards
    static let cardCornerRadius: CGFloat = 12
    static let cardShadowColor: Color = Color.black.opacity(0.05)
    static let cardShadowRadius: CGFloat = 4
    static let cardShadowOffset: CGFloat = 2

    // Typography
    static var sectionTitle: Font { .headline }
    static var sectionTitleWeight: Font.Weight { .semibold }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowOffset)
    }
}

extension View {
    func cardStyle() -> some View { self.modifier(CardStyle()) }
}

