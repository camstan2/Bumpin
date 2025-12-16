import SwiftUI

/// A precise star rating component that supports:
/// - Tap for whole number ratings (1.0, 2.0, 3.0, 4.0, 5.0)
/// - Long-press and slide for decimal ratings (1.0-5.0 with 0.1 precision)
/// - Visual partial star fill
/// - Haptic feedback on transitions
struct PreciseStarRatingView: View {
    @Binding var rating: Double
    @State private var isDragging = false
    @State private var longPressActivated = false
    @State private var currentDragRating: Double = 0
    
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    private let hapticSelection = UISelectionFeedbackGenerator()
    private let starSize: CGFloat = 32
    private let starSpacing: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 16) {
            // Star rating display
            HStack(spacing: starSpacing) {
                ForEach(1...5, id: \.self) { index in
                    starView(for: index)
                        .frame(width: starSize, height: starSize)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChange(value)
                    }
                    .onEnded { _ in
                        handleDragEnd()
                    }
                    .simultaneously(with: LongPressGesture(minimumDuration: 0.4)
                        .onChanged { _ in
                            if !longPressActivated {
                                activateLongPress()
                            }
                        }
                    )
            )
            
            // Rating number display
            if isDragging {
                Text(String(format: "%.1f", currentDragRating))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .transition(.opacity.combined(with: .scale))
            } else if rating > 0 {
                Text(String(format: "%.1f", rating) + " star\(rating == 1.0 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            hapticImpact.prepare()
            hapticSelection.prepare()
        }
    }
    
    // MARK: - Star View
    
    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let fillAmount = calculateFillAmount(for: index)
        let displayRating = isDragging ? currentDragRating : rating
        
        ZStack {
            // Background (empty star)
            Image(systemName: "star")
                .font(.system(size: starSize))
                .foregroundColor(.gray.opacity(0.3))
            
            // Foreground (filled portion)
            Image(systemName: "star.fill")
                .font(.system(size: starSize))
                .foregroundColor(.yellow)
                .mask(
                    GeometryReader { geometry in
                        Rectangle()
                            .frame(width: geometry.size.width * fillAmount)
                    }
                )
        }
        .scaleEffect(isDragging && fillAmount > 0 ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: fillAmount)
        .animation(.easeInOut(duration: 0.1), value: isDragging)
    }
    
    // MARK: - Calculation Methods
    
    private func calculateFillAmount(for index: Int) -> CGFloat {
        let displayRating = isDragging ? currentDragRating : rating
        
        if displayRating >= Double(index) {
            return 1.0
        } else if displayRating > Double(index - 1) {
            return CGFloat(displayRating - Double(index - 1))
        } else {
            return 0.0
        }
    }
    
    private func calculateRatingFromPosition(_ position: CGPoint, geometry: GeometrySize) -> Double {
        // Total width including spacing
        let totalWidth = (starSize * 5) + (starSpacing * 4)
        let startOffset = (geometry.width - totalWidth) / 2
        
        // Calculate position relative to star area
        let relativeX = max(0, min(totalWidth, position.x - startOffset))
        
        // Calculate which star and position within star
        let starWidth = starSize + starSpacing
        let starIndex = Int(relativeX / starWidth)
        let positionInStar = (relativeX.truncatingRemainder(dividingBy: starWidth)) / starSize
        
        // Calculate rating (1.0 to 5.0)
        let calculatedRating = Double(starIndex) + Double(positionInStar)
        
        // Clamp between 1.0 and 5.0, round to nearest 0.1
        let clampedRating = max(1.0, min(5.0, calculatedRating))
        let roundedRating = (clampedRating * 10).rounded() / 10
        
        return roundedRating
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDragChange(_ value: DragGesture.Value) {
        if !isDragging && !longPressActivated {
            // Simple tap - select whole number
            handleSimpleTap(at: value.location)
        } else if longPressActivated {
            // Long press + drag - precise rating
            isDragging = true
            updateDragRating(at: value.location)
        }
    }
    
    private func handleDragEnd() {
        if isDragging && longPressActivated {
            // Commit the drag rating
            withAnimation(.easeOut(duration: 0.2)) {
                rating = currentDragRating
                isDragging = false
                longPressActivated = false
            }
            
            // End haptic
            hapticImpact.impactOccurred()
        }
        
        isDragging = false
        longPressActivated = false
    }
    
    private func handleSimpleTap(at location: CGPoint) {
        // Calculate which star was tapped (1-5)
        let totalWidth = (starSize * 5) + (starSpacing * 4)
        let starWidth = starSize + starSpacing
        let starIndex = Int(location.x / starWidth) + 1
        let tappedRating = Double(min(5, max(1, starIndex)))
        
        if tappedRating != rating {
            withAnimation(.easeOut(duration: 0.15)) {
                rating = tappedRating
            }
            
            // Haptic for whole number
            hapticSelection.selectionChanged()
        }
    }
    
    private func activateLongPress() {
        longPressActivated = true
        isDragging = true
        currentDragRating = rating > 0 ? rating : 1.0
        
        // Haptic for long press start
        hapticImpact.impactOccurred()
    }
    
    private func updateDragRating(at location: CGPoint) {
        // Use a fixed width assumption based on screen
        let screenWidth = UIScreen.main.bounds.width - 40 // padding
        let geometry = GeometrySize(width: screenWidth, height: starSize)
        
        let newRating = calculateRatingFromPosition(location, geometry: geometry)
        
        // Check for whole number transition for haptic
        if floor(newRating) != floor(currentDragRating) {
            hapticSelection.selectionChanged()
        }
        
        withAnimation(.easeOut(duration: 0.05)) {
            currentDragRating = newRating
        }
    }
}

// Helper struct for geometry calculations
private struct GeometrySize {
    let width: CGFloat
    let height: CGFloat
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        Text("Precise Star Rating Demo")
            .font(.title2)
            .fontWeight(.bold)
        
        Text("Tap for whole numbers\nLong-press and slide for decimals")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        
        PreciseStarRatingView(rating: .constant(0.0))
        
        PreciseStarRatingView(rating: .constant(3.7))
        
        PreciseStarRatingView(rating: .constant(5.0))
    }
    .padding()
}

