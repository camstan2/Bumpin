import Foundation
import MusicKit

struct CachedGenreEntry: Codable {
    let genres: [String]
    let updatedAt: Date
}

final class GenreClassifier {
    static let shared = GenreClassifier()
    private init() { loadCacheFromDisk() }

    private var cache: [String: CachedGenreEntry] = [:] // key: "type:id"
    private let fm = FileManager.default
    private var cacheURL: URL {
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("GenreCache.json")
    }

    // MARK: - Public API
    func computeGenreCounts(for logs: [MusicLog]) async -> [(String, Int)] {
        let uniqueKeys = Array(Set(logs.compactMap { keyForLog($0) }))
        var counts: [String: Int] = [:]
        for key in uniqueKeys {
            let comps = key.split(separator: ":", maxSplits: 1).map(String.init)
            guard comps.count == 2 else { continue }
            let type = comps[0]
            let id = comps[1]
            if let primary = await primaryGenre(type: type, id: id) {
                let g = normalizeGenre(primary)
                counts[g, default: 0] += logs.filter { keyForLog($0) == key }.count
            }
        }
        let sorted = counts.sorted { $0.value > $1.value }
        return sorted.map { ($0.key, $0.value) }
    }

    // MARK: - Enhanced Lookups with AI Classification
    private func primaryGenre(type: String, id: String) async -> String? {
        let key = "\(type):\(id)"
        
        // Check cache first
        if let cached = cache[key] {
            // If we have AI-classified data, use it
            if cached.genres.count >= 2 && AIGenreClassificationService.standardizedGenres.contains(cached.genres[1]) {
                return cached.genres[1] // AI-classified genre is stored as second element
            }
            return cached.genres.first // Fallback to Apple Music genre
        }
        
        // Fetch Apple Music genres
        let appleMusicGenres: [String]
        var title = ""
        var artist = ""
        
        do {
            if type == "song" {
                let req = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(id))
                let resp = try await req.response()
                if let song = resp.items.first {
                    appleMusicGenres = song.genreNames ?? []
                    title = song.title
                    artist = song.artistName
                } else {
                    appleMusicGenres = []
                }
            } else if type == "album" {
                let req = MusicCatalogResourceRequest<MusicKit.Album>(matching: \.id, equalTo: MusicItemID(id))
                let resp = try await req.response()
                if let album = resp.items.first {
                    appleMusicGenres = album.genreNames
                    title = album.title
                    artist = album.artistName
                } else {
                    appleMusicGenres = []
                }
            } else if type == "artist" {
                let req = MusicCatalogResourceRequest<MusicKit.Artist>(matching: \.id, equalTo: MusicItemID(id))
                let resp = try await req.response()
                if let artistItem = resp.items.first {
                    appleMusicGenres = artistItem.genreNames ?? []
                    title = artistItem.name
                    artist = artistItem.name
                } else {
                    appleMusicGenres = []
                }
            } else {
                appleMusicGenres = []
            }
        } catch {
            appleMusicGenres = []
        }
        
        // Use AI classification if we have Apple Music data
        if !appleMusicGenres.isEmpty && !title.isEmpty && !artist.isEmpty {
            let aiResult = await AIGenreClassificationService.shared.classifySong(
                title: title,
                artist: artist,
                appleMusicGenres: appleMusicGenres
            )
            
            // Cache both Apple Music genres and AI classification
            let cacheGenres = appleMusicGenres + [aiResult.primaryGenre]
            cache[key] = CachedGenreEntry(genres: cacheGenres, updatedAt: Date())
            saveCacheToDisk()
            
            print("🎯 AI classified '\(title)' by \(artist): \(aiResult.primaryGenre) (confidence: \(aiResult.confidence))")
            return aiResult.primaryGenre
        }
        
        // Fallback: cache Apple Music genres only
        if !appleMusicGenres.isEmpty {
            cache[key] = CachedGenreEntry(genres: appleMusicGenres, updatedAt: Date())
            saveCacheToDisk()
            return appleMusicGenres.first
        }
        
        return nil
    }

    private func keyForLog(_ log: MusicLog) -> String? {
        // itemType is expected to be "song", "album", or "artist"
        guard !log.itemId.isEmpty else { return nil }
        return "\(log.itemType):\(log.itemId)"
    }

    // MARK: - Normalization
    private func normalizeGenre(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("hip-hop") || lower.contains("rap") { return "hip-hop" }
        if lower.contains("r&b") || lower.contains("soul") { return "r&b" }
        if lower.contains("pop") { return "pop" }
        if lower.contains("electronic") || lower.contains("dance") { return "electronic" }
        if lower.contains("rock") { return "rock" }
        if lower.contains("country") { return "country" }
        if lower.contains("latin") { return "latin" }
        if lower.contains("k-pop") { return "k-pop" }
        if lower.contains("jazz") { return "jazz" }
        if lower.contains("metal") { return "metal" }
        if lower.contains("classical") { return "classical" }
        return raw.capitalized
    }

    // MARK: - Disk Cache
    private func loadCacheFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        if let decoded = try? JSONDecoder().decode([String: CachedGenreEntry].self, from: data) { cache = decoded }
    }
    private func saveCacheToDisk() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}


