import Foundation
import CryptoKit

struct CachedSearchResults: Codable {
    let users: [UserProfile]
    let songs: [MusicSearchResult]
    let artists: [MusicSearchResult]
    let albums: [MusicSearchResult]
    let lists: [MusicList]
    let savedAt: Date
}

final class SearchDiskCache {
    static let shared = SearchDiskCache()
    private init() { loadIndex() }

    private let fm = FileManager.default
    private let folderName = "SearchCache"
    private let indexFile = "index.json"
    private var index: [String: Date] = [:] // key -> lastUsed
    private let capacity = 30

    private var folderURL: URL {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private func fileURL(for key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        return folderURL.appendingPathComponent("\(hash).json")
    }

    private func loadIndex() {
        let url = folderURL.appendingPathComponent(indexFile)
        guard let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            index = decoded
        }
    }

    private func persistIndex() {
        let url = folderURL.appendingPathComponent(indexFile)
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: url)
        }
    }

    func load(key: String) -> CachedSearchResults? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let decoded = try? JSONDecoder().decode(CachedSearchResults.self, from: data) else { return nil }
        index[key] = Date()
        persistIndex()
        return decoded
    }

    func save(key: String, results: CachedSearchResults) {
        let url = fileURL(for: key)
        guard let data = try? JSONEncoder().encode(results) else { return }
        try? data.write(to: url)
        index[key] = Date()
        evictIfNeeded()
        persistIndex()
    }

    private func evictIfNeeded() {
        if index.count <= capacity { return }
        let sorted = index.sorted { $0.value < $1.value }
        let overflow = sorted.prefix(max(0, index.count - capacity))
        for (key, _) in overflow {
            let url = fileURL(for: key)
            try? fm.removeItem(at: url)
            index.removeValue(forKey: key)
        }
    }
}


