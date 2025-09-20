import Foundation
import FirebaseFirestore

struct ItemPopularity: Codable {
    let score: Double     // combined score
    let logsCount30d: Int
    let avgRating: Double
    let lastUpdated: Date
}

final class PopularityService {
    static let shared = PopularityService()
    private init() {}

    private let db = Firestore.firestore()
    private var cache: [String: ItemPopularity] = [:]
    private var lastFetchAt: [String: Date] = [:]
    private let ttl: TimeInterval = 60 * 10 // 10 minutes

    func getCachedScore(for itemId: String) -> Double? {
        if let pop = cache[itemId] { return pop.score }
        return nil
    }

    @discardableResult
    func preloadPopularity(for itemIds: [String]) async -> [String: ItemPopularity] {
        let now = Date()
        var toQuery: [String] = []
        for id in itemIds {
            if let last = lastFetchAt[id], now.timeIntervalSince(last) < ttl { continue }
            toQuery.append(id)
        }
        guard !toQuery.isEmpty else { return cache }
        // Firestore does not support 'in' with too many values; batch into 10s
        for batch in toQuery.chunked(into: 10) {
            do {
                // Compute popularity from logs within 30 days
                let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
                let snap = try await db.collection("logs")
                    .whereField("itemId", in: batch)
                    .whereField("dateLogged", isGreaterThan: monthAgo)
                    .getDocuments()
                var byItem: [String: [MusicLog]] = [:]
                for doc in snap.documents {
                    if let log = try? doc.data(as: MusicLog.self) {
                        byItem[log.itemId, default: []].append(log)
                    }
                }
                for id in batch {
                    let logs = byItem[id] ?? []
                    let count = logs.count
                    let ratings = logs.compactMap { $0.rating }
                    let avg = ratings.isEmpty ? 0.0 : Double(ratings.reduce(0, +)) / Double(ratings.count)
                    // Simple score: count + avg*10 with light decay for age
                    let score = Double(count) + avg * 10.0
                    let pop = ItemPopularity(score: score, logsCount30d: count, avgRating: avg, lastUpdated: now)
                    cache[id] = pop
                    lastFetchAt[id] = now
                }
            } catch {
                // Ignore failures; keep existing cache
                continue
            }
        }
        return cache
    }
}

// MARK: - Friends Popular scorer (pure, testable)
extension PopularityService {
    static func scoreFriendsPopular(logs: [MusicLog]) -> Double {
        guard !logs.isEmpty else { return 0 }
        let cfg = ScoringConfig.shared
        let now = Date()
        let countScore = Double(logs.count) * cfg.helpfulWeight
        let rated = logs.compactMap { $0.rating }
        let avg = rated.isEmpty ? 0.0 : Double(rated.reduce(0, +)) / Double(rated.count)
        let ratingScore = avg * cfg.ratingWeight
        let recencySum = logs.reduce(0.0) { acc, log in
            let hours = now.timeIntervalSince(log.dateLogged) / 3600.0
            return acc + exp(-hours / cfg.decayHours)
        }
        let recencyScore = recencySum * cfg.decayWeight
        return countScore + ratingScore + recencyScore
    }
}

// Uses global chunked(into:) defined elsewhere in the project


