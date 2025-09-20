import SwiftUI

struct EnhancedArtworkView: View {
    let artworkUrl: String?
    let itemType: String // "song", "album", "artist"
    let size: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isLoading = true
    @State private var hasError = false
    
    init(artworkUrl: String?, itemType: String, size: CGFloat = 44, cornerRadius: CGFloat? = nil) {
        self.artworkUrl = artworkUrl
        self.itemType = itemType
        self.size = size
        self.cornerRadius = cornerRadius ?? (itemType == "artist" ? size / 2 : 6)
    }
    
    var body: some View {
        Group {
            if let url = artworkUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        loadingPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .onAppear {
                                isLoading = false
                                hasError = false
                            }
                    case .failure(_):
                        fallbackPlaceholder
                            .onAppear {
                                isLoading = false
                                hasError = true
                            }
                    @unknown default:
                        fallbackPlaceholder
                    }
                }
            } else {
                fallbackPlaceholder
            }
        }
        .frame(width: size, height: size)
        .modifier(ArtworkClipModifier(itemType: itemType, cornerRadius: cornerRadius))
    }
    
    private var loadingPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.purple.opacity(0.1))
            
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
        }
    }
    
    private var fallbackPlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.purple.opacity(0.2))
            .overlay(
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.purple)
            )
    }
    
    private var fallbackIcon: String {
        switch itemType {
        case "artist":
            return "person.fill"
        case "album":
            return "square.stack.3d.up"
        default:
            return "music.note"
        }
    }
}

struct ArtworkClipModifier: ViewModifier {
    let itemType: String
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if itemType == "artist" {
            content
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                )
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedArtworkView(artworkUrl: nil, itemType: "song", size: 60)
        EnhancedArtworkView(artworkUrl: nil, itemType: "artist", size: 60)
        EnhancedArtworkView(artworkUrl: nil, itemType: "album", size: 60)
    }
    .padding()
} 