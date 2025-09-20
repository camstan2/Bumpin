import SwiftUI

final class InMemoryImageCache {
    static let shared = InMemoryImageCache()
    private init() { cache.countLimit = 512 }
    private let cache = NSCache<NSString, UIImage>()
    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, forKey key: String) { cache.setObject(image, forKey: key as NSString) }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    @State private var uiImage: UIImage?
    @State private var opacity: Double = 0

    init(url: URL,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.2)) { opacity = 1 }
                    }
            } else {
                placeholder()
                    .task { await load() }
            }
        }
    }

    private func load() async {
        let key = url.absoluteString
        if let cached = InMemoryImageCache.shared.image(forKey: key) {
            self.uiImage = cached
            return
        }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, _) = try await URLSession.shared.data(for: request)
            if let image = UIImage(data: data) {
                InMemoryImageCache.shared.set(image, forKey: key)
                await MainActor.run {
                    self.opacity = 0
                    self.uiImage = image
                    withAnimation(.easeInOut(duration: 0.2)) { self.opacity = 1 }
                }
            }
        } catch {
            // Leave placeholder
        }
    }
}


