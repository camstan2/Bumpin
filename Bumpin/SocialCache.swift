import Foundation

struct TrendingSnapshot: Codable {
    let items: [TrendingItem]
    let savedAt: Date
}

final class SocialCache {
    static let shared = SocialCache()
    private init() {}
    private let fm = FileManager.default
    private let folder = "SocialCache"
    private var baseURL: URL {
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent(folder, isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    private func fileURL(for key: String) -> URL { baseURL.appendingPathComponent("\(key).json") }

    func save(key: String, items: [TrendingItem]) {
        let snap = TrendingSnapshot(items: items, savedAt: Date())
        if let data = try? JSONEncoder().encode(snap) { try? data.write(to: fileURL(for: key)) }
    }
    func load(key: String, maxAgeSeconds: TimeInterval) -> [TrendingItem]? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url), let snap = try? JSONDecoder().decode(TrendingSnapshot.self, from: data) else { return nil }
        if Date().timeIntervalSince(snap.savedAt) <= maxAgeSeconds { return snap.items }
        return nil
    }
}


