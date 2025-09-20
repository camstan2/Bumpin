import Foundation
import FirebaseFirestore

struct TrendingStory: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let summary: String
    let genre: String
    let primaryArtist: String?
    let createdAt: Date
    let expiresAt: Date
}

final class TrendingStoriesService {
    static let shared = TrendingStoriesService()
    private let db = Firestore.firestore()
    private init() {}
    
    // Simple in-memory cache per genre with TTL
    private var cache: [String: (stories: [TrendingStory], expiresAt: Date)] = [:]
    
    func fetchStories(for genre: String, hoursBack: Int = 72) async throws -> [TrendingStory] {
        // Serve from cache if valid
        if let entry = cache[genre], entry.expiresAt > Date() {
            return entry.stories
        }
        let since = Calendar.current.date(byAdding: .hour, value: -hoursBack, to: Date()) ?? Date().addingTimeInterval(-72 * 3600)
        // Query recent logs for the genre
        let snap: QuerySnapshot
        do {
            snap = try await db.collection("logs")
                .whereField("genres", arrayContains: genre)
                .whereField("dateLogged", isGreaterThan: since)
                .order(by: "dateLogged", descending: true)
                .limit(to: 500)
                .getDocuments()
        } catch {
            // Fallback w/o composite index
            let temp = try await db.collection("logs")
                .whereField("genres", arrayContains: genre)
                .order(by: "dateLogged", descending: true)
                .limit(to: 500)
                .getDocuments()
            let all = temp.documents.compactMap { try? $0.data(as: MusicLog.self) }
            return try await buildStories(from: all.filter { $0.dateLogged >= since }, genre: genre)
        }
        let logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
        let stories = try await buildStories(from: logs, genre: genre)
        // Cache for 12 hours
        let ttl = Date().addingTimeInterval(12 * 3600)
        cache[genre] = (stories, ttl)
        return stories
    }
    
    private func buildStories(from logs: [MusicLog], genre: String) async throws -> [TrendingStory] {
        // Group by artist and count
        let groups = Dictionary(grouping: logs) { $0.artistName }
        let sorted = groups.sorted { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                // Tie-breaker by recency
                return (lhs.value.first?.dateLogged ?? .distantPast) > (rhs.value.first?.dateLogged ?? .distantPast)
            }
            return lhs.value.count > rhs.value.count
        }
        let top = Array(sorted.prefix(8))
        let now = Date()
        let expires = now.addingTimeInterval(12 * 3600)
        let stories: [TrendingStory] = top.enumerated().map { idx, entry in
            let artist = entry.key
            let count = entry.value.count
            // Lightweight generated blurb (can be replaced by LLM-backed text later)
            let title = "Trending: \(artist)"
            let summary = "\(artist) has been getting attention in \(genre.capitalized): \(count) new logs in the past few days."
            return TrendingStory(
                id: "\(genre)-\(artist)-\(idx)",
                title: title,
                summary: summary,
                genre: genre,
                primaryArtist: artist,
                createdAt: now,
                expiresAt: expires
            )
        }
        return stories
    }
}


