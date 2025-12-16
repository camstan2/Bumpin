import Foundation
import FirebaseFirestore
import FirebaseAuth

struct ArtistRatingSummary {
    let average: Double
    let count: Int
}

actor ArtistRatingsService {
    static let shared = ArtistRatingsService()
    
    private let db = Firestore.firestore()
    private var cache: [String: (summary: ArtistRatingSummary, timestamp: Date)] = [:]
    private let ttl: TimeInterval = 60 // seconds
    
    func fetchRatings(for artistNames: [String]) async -> [String: ArtistRatingSummary] {
        var result: [String: ArtistRatingSummary] = [:]
        let now = Date()
        var toCompute: [String] = []
        
        for name in artistNames {
            if let cached = cache[name], now.timeIntervalSince(cached.timestamp) < ttl {
                result[name] = cached.summary
            } else {
                toCompute.append(name)
            }
        }
        
        for name in toCompute {
            let summary = await computeSummary(for: name)
            cache[name] = (summary, now)
            result[name] = summary
        }
        
        return result
    }
    
    private func computeSummary(for artistName: String) async -> ArtistRatingSummary {
        let normalized = ArtistNameParser.normalizedKey(artistName)
        do {
            var snapshot = try await db.collection("logs")
                .whereField("artistTokens", arrayContains: normalized)
                .getDocuments()
            var logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            
            if logs.isEmpty {
                snapshot = try await db.collection("logs")
                    .whereField("artistName", isEqualTo: artistName)
                    .getDocuments()
                logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            }
            
            let ratedLogs = logs.filter { ($0.isPublic ?? true) && ($0.rating ?? 0) > 0 }
            let uniqueLogs = Dictionary(grouping: ratedLogs, by: { $0.id }).compactMap { $0.value.first }
            let count = uniqueLogs.count
            let total = uniqueLogs.compactMap { $0.rating }.reduce(0.0, +)
            let average = count > 0 ? total / Double(count) : 0.0
            return ArtistRatingSummary(average: average, count: count)
        } catch {
            print("⚠️ ArtistRatingsService error for \(artistName): \(error.localizedDescription)")
            return ArtistRatingSummary(average: 0.0, count: 0)
        }
    }
}

