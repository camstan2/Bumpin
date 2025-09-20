import Foundation

struct DiscoverSnapshot: Codable {
    let parties: [Party]
    let savedAt: Date
}

final class DiscoverDiskCache {
    static let shared = DiscoverDiskCache()
    private init() {}

    private let fm = FileManager.default
    private let folder = "DiscoverCache"
    private var baseURL: URL {
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent(folder, isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private func fileURL(for key: String) -> URL {
        baseURL.appendingPathComponent("\(key).json")
    }

    func save(key: String, parties: [Party]) {
        let snap = DiscoverSnapshot(parties: parties, savedAt: Date())
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: fileURL(for: key))
        }
    }

    func load(key: String, maxAgeSeconds: TimeInterval) -> [Party]? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(DiscoverSnapshot.self, from: data) else { return nil }
        if Date().timeIntervalSince(snap.savedAt) <= maxAgeSeconds {
            return snap.parties
        }
        return nil
    }

    // Returns parties and age in seconds if within maxAge, else nil
    func loadWithMeta(key: String, maxAgeSeconds: TimeInterval) -> (parties: [Party], ageSeconds: TimeInterval)? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(DiscoverSnapshot.self, from: data) else { return nil }
        let age = Date().timeIntervalSince(snap.savedAt)
        if age <= maxAgeSeconds {
            return (snap.parties, age)
        }
        return nil
    }
}


