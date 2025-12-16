import Foundation
import FirebaseFirestore

struct MusicProfileSummary {
    let documentId: String
    let averageRating: Double?
    let totalRatings: Int
    let totalLogs: Int
}

/// Centralized cache for canonical music profile ratings.
/// Summaries are stored in the `musicProfiles` collection so every surface can share the same average.
final class MusicProfileSummaryService {
    static let shared = MusicProfileSummaryService()
    
    private let db = Firestore.firestore()
    private init() {}
    
    private var collection: CollectionReference {
        db.collection("musicProfiles")
    }
    
    // MARK: - Public API
    
    /// Returns the cached summary for a `TrendingItem`. If none exists it will compute it from logs and cache it.
    func summary(for item: TrendingItem, itemType: String) async -> MusicProfileSummary? {
        let identifiers = identifierTuples(primaryItemId: item.itemId, appleMusicId: item.appleMusicId)
        guard !identifiers.isEmpty else { return nil }
        
        if let cached = await fetchSummary(for: identifiers.map { $0.value }) {
            return cached
        }
        
        let metadata = SummaryMetadata(title: item.title,
                                       artistName: item.subtitle,
                                       artworkUrl: item.artworkUrl,
                                       itemType: itemType,
                                       appleMusicId: item.appleMusicId)
        
        guard let computed = await computeSummary(for: identifiers, itemType: itemType) else {
            return nil
        }
        
        await storeSummary(computed,
                           documentIds: identifiers.map { $0.value },
                           metadata: metadata)
        
        return MusicProfileSummary(documentId: identifiers.first?.value ?? "",
                                   averageRating: computed.averageRating,
                                   totalRatings: computed.totalRatings,
                                   totalLogs: computed.totalLogs)
    }
    
    /// Recomputes and caches the summary for the given log. Called whenever a log is created/updated/deleted.
    func updateSummary(for log: MusicLog) async {
        let identifiers = identifierTuples(for: log)
        guard !identifiers.isEmpty else { return }
        
        let metadata = SummaryMetadata(title: log.title,
                                       artistName: log.artistName,
                                       artworkUrl: log.artworkUrl,
                                       itemType: log.itemType,
                                       appleMusicId: cleanedIdentifier(from: log.itemId))
        
        if let computed = await computeSummary(for: identifiers, itemType: log.itemType) {
            await storeSummary(computed,
                               documentIds: identifiers.map { $0.value },
                               metadata: metadata)
        } else {
            await clearSummaries(documentIds: identifiers.map { $0.value })
        }
    }
    
    // MARK: - Fetch helpers
    
    private func fetchSummary(for documentIds: [String]) async -> MusicProfileSummary? {
        let uniqueIds = Array(Set(documentIds.filter { !$0.isEmpty }))
        guard !uniqueIds.isEmpty else { return nil }
        var summaries: [String: MusicProfileSummary] = [:]
        
        for batch in uniqueIds.chunked(into: 10) {
            do {
                let snapshot = try await collection
                    .whereField(FieldPath.documentID(), in: batch)
                    .getDocuments()
                for doc in snapshot.documents {
                    let data = doc.data()
                    let average = data["averageRating"] as? Double
                    let totalRatings = data["totalRatings"] as? Int ?? 0
                    let totalLogs = data["totalLogs"] as? Int ?? 0
                    summaries[doc.documentID] = MusicProfileSummary(documentId: doc.documentID,
                                                                    averageRating: average,
                                                                    totalRatings: totalRatings,
                                                                    totalLogs: totalLogs)
                }
            } catch {
                print("⚠️ MusicProfileSummaryService.fetchSummary error: \(error)")
            }
        }
        
        for id in documentIds {
            if let summary = summaries[id] {
                return summary
            }
        }
        return summaries.values.first
    }
    
    // MARK: - Computation
    
    private func computeSummary(for identifiers: [(field: String, value: String)],
                                itemType: String) async -> ComputedSummary? {
        for (field, value) in identifiers {
            do {
                let snapshot = try await db.collection("logs")
                    .whereField(field, isEqualTo: value)
                    .whereField("itemType", isEqualTo: itemType)
                    .getDocuments()
                
                guard !snapshot.documents.isEmpty else {
                    continue
                }
                
                let ratings = snapshot.documents.compactMap { doc -> Double? in
                    if let rating = doc.data()["rating"] as? Double {
                        return rating
                    }
                    if let ratingInt = doc.data()["rating"] as? Int {
                        return Double(ratingInt)
                    }
                    return nil
                }.filter { $0 > 0 }
                
                if ratings.isEmpty {
                    return ComputedSummary(averageRating: nil,
                                           totalRatings: 0,
                                           totalLogs: snapshot.count)
                }
                
                let average = ratings.reduce(0, +) / Double(ratings.count)
                return ComputedSummary(averageRating: average,
                                       totalRatings: ratings.count,
                                       totalLogs: snapshot.count)
            } catch {
                print("⚠️ MusicProfileSummaryService.computeSummary error for \(field)=\(value): \(error)")
            }
        }
        return nil
    }
    
    // MARK: - Persistence
    
    private func storeSummary(_ summary: ComputedSummary,
                              documentIds: [String],
                              metadata: SummaryMetadata) async {
        let uniqueIds = Array(Set(documentIds.filter { !$0.isEmpty }))
        guard !uniqueIds.isEmpty else { return }
        
        let timestamp = Timestamp(date: Date())
        let batch = db.batch()
        
        for id in uniqueIds {
            var payload: [String: Any] = [
                "totalRatings": summary.totalRatings,
                "totalLogs": summary.totalLogs,
                "itemType": metadata.itemType,
                "title": metadata.title,
                "artistName": metadata.artistName ?? "",
                "aliases": uniqueIds,
                "updatedAt": timestamp
            ]
            if let average = summary.averageRating {
                payload["averageRating"] = average
            } else {
                payload["averageRating"] = FieldValue.delete()
            }
            if let artwork = metadata.artworkUrl {
                payload["artworkUrl"] = artwork
            }
            if let appleId = metadata.appleMusicId {
                payload["appleMusicId"] = appleId
            }
            batch.setData(payload, forDocument: collection.document(id), merge: true)
        }
        
        do {
            try await batch.commit()
        } catch {
            print("⚠️ MusicProfileSummaryService.storeSummary error: \(error)")
        }
    }
    
    private func clearSummaries(documentIds: [String]) async {
        let uniqueIds = Array(Set(documentIds.filter { !$0.isEmpty }))
        guard !uniqueIds.isEmpty else { return }
        let batch = db.batch()
        for id in uniqueIds {
            batch.deleteDocument(collection.document(id))
        }
        do {
            try await batch.commit()
        } catch {
            print("⚠️ MusicProfileSummaryService.clearSummaries error: \(error)")
        }
    }
    
    // MARK: - Identifier helpers
    
    private func identifierTuples(for log: MusicLog) -> [(field: String, value: String)] {
        var tuples: [(String, String)] = []
        if let universal = log.universalTrackId, !universal.isEmpty {
            tuples.append(("universalTrackId", universal))
        }
        let cleanedItemId = cleanedIdentifier(from: log.itemId)
        if !cleanedItemId.isEmpty {
            tuples.append(("itemId", cleanedItemId))
        }
        return uniqueTuples(tuples)
    }
    
    private func identifierTuples(primaryItemId: String, appleMusicId: String?) -> [(field: String, value: String)] {
        var tuples: [(String, String)] = []
        let cleaned = cleanedIdentifier(from: primaryItemId)
        if !cleaned.isEmpty {
            tuples.append(("universalTrackId", cleaned))
            tuples.append(("itemId", cleaned))
        }
        if let apple = appleMusicId, !apple.isEmpty {
            tuples.append(("itemId", apple))
        }
        return uniqueTuples(tuples)
    }
    
    private func uniqueTuples(_ tuples: [(String, String)]) -> [(String, String)] {
        var seen: Set<String> = []
        return tuples.filter { pair in
            let key = "\(pair.0)|\(pair.1)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
    
    private func cleanedIdentifier(from raw: String) -> String {
        guard !raw.isEmpty else { return raw }
        if raw.contains("|"), let last = raw.split(separator: "|").last {
            return String(last)
        }
        return raw
    }
    
    // MARK: - Nested types
    
    private struct ComputedSummary {
        let averageRating: Double?
        let totalRatings: Int
        let totalLogs: Int
    }
    
    private struct SummaryMetadata {
        let title: String
        let artistName: String?
        let artworkUrl: String?
        let itemType: String
        let appleMusicId: String?
    }
}


