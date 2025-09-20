import Foundation
import SwiftUI
import Combine

// MARK: - Advanced Image Cache Manager

@MainActor
class ArtistImageCache: ObservableObject {
    static let shared = ArtistImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 3600 // 7 days
    
    // Performance monitoring
    @Published var cacheHitRate: Double = 0.0
    @Published var totalCacheSize: Int = 0
    
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    
    private init() {
        // Setup cache directory
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("ArtistImages")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure NSCache
        cache.countLimit = 200 // Max 200 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        
        // Setup periodic cleanup
        setupPeriodicCleanup()
        
        // Calculate initial cache size
        updateCacheSize()
    }
    
    // MARK: - Public Methods
    
    func loadImage(from url: String) async -> UIImage? {
        let cacheKey = NSString(string: url)
        
        // Check memory cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            cacheHits += 1
            updateCacheHitRate()
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = loadFromDisk(url: url) {
            cache.setObject(diskImage, forKey: cacheKey)
            cacheHits += 1
            updateCacheHitRate()
            return diskImage
        }
        
        // Download and cache
        cacheMisses += 1
        updateCacheHitRate()
        
        guard let imageURL = URL(string: url) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard let image = UIImage(data: data) else { return nil }
            
            // Optimize image for display
            let optimizedImage = optimizeImage(image)
            
            // Cache in memory and disk
            cache.setObject(optimizedImage, forKey: cacheKey)
            saveToDisk(image: optimizedImage, url: url)
            
            return optimizedImage
            
        } catch {
            print("❌ Failed to load image from \(url): \(error)")
            return nil
        }
    }
    
    func preloadImages(urls: [String]) {
        Task.detached(priority: .background) { [weak self] in
            for url in urls {
                await self?.loadImage(from: url)
                // Small delay to avoid overwhelming the network
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        cacheHits = 0
        cacheMisses = 0
        updateCacheHitRate()
        updateCacheSize()
    }
    
    func getCacheStats() -> CacheStats {
        return CacheStats(
            hitRate: cacheHitRate,
            totalSize: totalCacheSize,
            memoryCount: cache.countLimit,
            diskFiles: (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil))?.count ?? 0
        )
    }
    
    func optimizeForLowEndDevice() {
        // Reduce cache limits for low-end devices
        cache.countLimit = 50 // Reduced from 200
        cache.totalCostLimit = 20 * 1024 * 1024 // Reduced to 20MB from 50MB
        
        // Clear some existing cache to free memory
        cache.removeAllObjects()
        
        print("📱 Optimized image cache for low-end device")
    }
    
    // MARK: - Private Methods
    
    private func optimizeImage(_ image: UIImage) -> UIImage {
        // Resize large images to reasonable dimensions for display
        let maxDimension: CGFloat = 512
        let size = image.size
        
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func loadFromDisk(url: String) -> UIImage? {
        let filename = cacheFilename(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Check if file is too old
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > maxCacheAge {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return image
    }
    
    private func saveToDisk(image: UIImage, url: String) {
        // Capture values before async context
        let filename = cacheFilename(for: url)
        let cacheDir = cacheDirectory
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self,
                  let data = image.jpegData(compressionQuality: 0.8) else { return }
            
            let fileURL = cacheDir.appendingPathComponent(filename)
            
            try? data.write(to: fileURL)
            // Update cache size on main thread
            DispatchQueue.main.async {
                self.updateCacheSize()
            }
        }
    }
    
    private func cacheFilename(for url: String) -> String {
        return url.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") ?? UUID().uuidString
    }
    
    private func updateCacheHitRate() {
        let total = cacheHits + cacheMisses
        cacheHitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
    }
    
    private func updateCacheSize() {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            let size = await self.calculateDirectorySize(self.cacheDirectory)
            
            DispatchQueue.main.async {
                self.totalCacheSize = size
            }
        }
    }
    
    private func calculateDirectorySize(_ directory: URL) async -> Int {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else { continue }
            totalSize += fileSize
        }
        
        return totalSize
    }
    
    private func setupPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in // Every hour
            Task { [weak self] in
                await self?.performCleanup()
            }
        }
    }
    
    private func performCleanup() async {
        // Simplified cleanup - just clear old files
        let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        var removedCount = 0
        
        for fileURL in contents ?? [] {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let modificationDate = attributes[.modificationDate] as? Date,
               Date().timeIntervalSince(modificationDate) > maxCacheAge {
                try? fileManager.removeItem(at: fileURL)
                removedCount += 1
            }
        }
        
        DispatchQueue.main.async {
            self.updateCacheSize()
        }
        
        print("🧹 Image cache cleanup: Removed \(removedCount) old files")
    }
    
    private func evictOldestFiles(targetSize: Int) async {
        // Simplified eviction - remove oldest files until we reach target size
        let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        
        var filesToRemove: [(url: URL, date: Date)] = []
        
        for fileURL in contents ?? [] {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let modificationDate = attributes[.modificationDate] as? Date {
                filesToRemove.append((url: fileURL, date: modificationDate))
            }
        }
        
        // Sort by modification date (oldest first)
        filesToRemove.sort { $0.date < $1.date }
        
        // Remove oldest files until we reach roughly half the target
        let toRemove = filesToRemove.prefix(filesToRemove.count / 2)
        
        for file in toRemove {
            try? fileManager.removeItem(at: file.url)
        }
        
        print("🗑️ Evicted \(toRemove.count) oldest files")
    }
}

// MARK: - Cache Statistics

struct CacheStats {
    let hitRate: Double
    let totalSize: Int
    let memoryCount: Int
    let diskFiles: Int
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
    
    var hitRatePercentage: String {
        return String(format: "%.1f%%", hitRate * 100)
    }
}

// MARK: - Cached Async Image Component

struct CachedAsyncArtistImage: View {
    let url: String?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let placeholder: () -> AnyView
    
    @StateObject private var imageCache = ArtistImageCache.shared
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    init(url: String?, width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 12, @ViewBuilder placeholder: @escaping () -> AnyView) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if isLoading {
                placeholder()
                    .frame(width: width, height: height)
            } else {
                placeholder()
                    .frame(width: width, height: height)
            }
        }
        .task {
            await loadImageAsync()
        }
        .onChange(of: url) { _, newURL in
            Task {
                await loadImageAsync()
            }
        }
    }
    
    private func loadImageAsync() async {
        guard let url = url else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        if let image = await imageCache.loadImage(from: url) {
            withAnimation(.easeInOut(duration: 0.3)) {
                loadedImage = image
                isLoading = false
            }
        } else {
            isLoading = false
        }
    }
}
