import SwiftUI

// MARK: - Type-erased Shape for conditional clipping
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        return _path(rect)
    }
}

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
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
            HapticManager.impact(style: .light)
        }) {
            // DESIGN ENHANCEMENT: Match Social Feed filter tab pattern
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(filter.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.purple.opacity(0.12) : Color(.systemGray6))
            )
            .overlay(
                // Bottom indicator line for selected state (matches Social Feed)
                VStack {
                    Spacer()
                    if isSelected {
                        Rectangle()
                            .fill(Color.purple)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                            .padding(.horizontal, 8)
                    }
                }
            )
            .foregroundColor(isSelected ? .purple : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Search Pill with Press State
struct RecentSearchPill: View {
    let query: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(query)
                .font(.subheadline)
                .foregroundColor(.purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        // DESIGN ENHANCEMENT: Press state micro-interaction
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
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
            // Artwork with shimmer loading (circular avatar for users)
            if result.type == .user {
                UserAvatarView(
                    userId: result.id,
                    existingUrl: result.artworkURL?.absoluteString,
                    initials: result.title,
                    size: 56
                )
            } else {
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
                .clipShape(AnyShape(RoundedRectangle(cornerRadius: 8)))
            }
            
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
                        .fill(typeColor.opacity(0.2))
                )
                .foregroundColor(typeColor)
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
    
    private var typeColor: Color {
        switch result.type {
        case .user: return .pink
        case .artist: return .green
        case .song: return .blue
        case .album: return .orange
        case .list: return .purple
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
