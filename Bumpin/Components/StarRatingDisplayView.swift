import SwiftUI

/// A view that displays a star rating with partial star fill and optional numerical display
/// Shows both the number (e.g., "4.6") and visual stars with precise fill amounts
struct StarRatingDisplayView: View {
    let rating: Double
    let starSize: CGFloat
    let spacing: CGFloat
    let showNumber: Bool
    
    init(rating: Double, starSize: CGFloat = 12, spacing: CGFloat = 2, showNumber: Bool = true) {
        self.rating = max(0, min(5, rating)) // Clamp between 0 and 5
        self.starSize = starSize
        self.spacing = spacing
        self.showNumber = showNumber
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Numerical rating
            if showNumber {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: starSize, weight: .semibold))
                    .foregroundColor(ProfileDesignSystem.Colors.ratingGold)
                    .monospacedDigit()
            }
            
            // Star visualization
            HStack(spacing: spacing) {
                ForEach(1...5, id: \.self) { index in
                    starView(for: index)
                }
            }
        }
    }
    
    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let fillAmount = calculateFillAmount(for: index)
        
        ZStack {
            // Background (empty star)
            Image(systemName: "star.fill")
                .font(.system(size: starSize))
                .foregroundColor(ProfileDesignSystem.Colors.ratingInactive)
            
            // Foreground (filled portion with gradient)
            Image(systemName: "star.fill")
                .font(.system(size: starSize))
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
                            .frame(width: geometry.size.width * fillAmount)
                    }
                )
        }
        .frame(width: starSize, height: starSize)
    }
    
    private func calculateFillAmount(for index: Int) -> CGFloat {
        if rating >= Double(index) {
            return 1.0
        } else if rating > Double(index - 1) {
            return CGFloat(rating - Double(index - 1))
        } else {
            return 0.0
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Star Rating Display Examples")
            .font(.title2)
            .fontWeight(.bold)
        
        StarRatingDisplayView(rating: 4.6, starSize: 16)
        StarRatingDisplayView(rating: 3.2, starSize: 16)
        StarRatingDisplayView(rating: 5.0, starSize: 16)
        StarRatingDisplayView(rating: 2.7, starSize: 16)
        StarRatingDisplayView(rating: 1.6, starSize: 16)
        StarRatingDisplayView(rating: 1.0, starSize: 16)
        
        Divider()
        
        Text("Without Numbers")
            .font(.headline)
        
        StarRatingDisplayView(rating: 4.6, starSize: 16, showNumber: false)
        StarRatingDisplayView(rating: 3.2, starSize: 16, showNumber: false)
        StarRatingDisplayView(rating: 1.6, starSize: 16, showNumber: false)
    }
    .padding()
}

