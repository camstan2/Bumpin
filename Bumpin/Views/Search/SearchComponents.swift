import SwiftUI

// MARK: - Modern Search Bar
struct ModernSearchBar: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Search icon with animation
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 17, weight: .medium))
                .scaleEffect(isEditing ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isEditing)
            
            // Search TextField
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 17))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: text) { oldValue, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = !newValue.isEmpty
                    }
                }
            
            // Clear button with animation
            if !text.isEmpty {
                Button(action: {
                    withAnimation {
                        text = ""
                        isEditing = false
                    }
                    HapticManager.impact(style: .light)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - Modern Filter Pill
struct ModernFilterPill: View {
    let filter: SearchFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                action()
            }
            HapticManager.impact(style: .light)
        }) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(filter.rawValue)
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? filter.color : Color(.systemGray5))
                    .shadow(color: isSelected ? filter.color.opacity(0.3) : .clear, radius: 4, y: 2)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let result: any SearchResultItem
    let onTap: (() -> Void)?
    @State private var isPressed: Bool = false
    
    init(result: any SearchResultItem, onTap: (() -> Void)? = nil) {
        self.result = result
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Artwork with shimmer loading
            AsyncImage(url: result.artworkURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ShimmerView()
                }
            }
            .frame(width: 56, height: 56)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 17, weight: .medium))
                    .lineLimit(1)
                
                Text(result.subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Type indicator
            Text(result.type.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.2))
                )
                .foregroundColor(.purple)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color(.systemGray4).opacity(0.1), radius: 8, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .onTapGesture {
            HapticManager.impact(style: .light)
            
            withAnimation {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
            }
            
            // Call the navigation callback
            onTap?()
        }
    }
}

// MARK: - Shimmer Loading Effect
struct ShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemGray5),
                Color(.systemGray6),
                Color(.systemGray5)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .opacity(0.8)
        .offset(x: isAnimating ? 200 : -200)
        .animation(
            Animation
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Search Result Extensions
// Extensions removed - SearchResultItem is a typealias for SearchResult protocol
