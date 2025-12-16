import Foundation
import FirebaseFirestore

/// Centralized Firestore access layer for music logs to reduce duplicated logic
actor MusicLogStore {
    static let shared = MusicLogStore()
    
    private let db = Firestore.firestore()
    private init() {}
    
    private var logsCollection: CollectionReference {
        db.collection("logs")
    }
    
    // MARK: - CRUD
    
    func createLog(_ log: MusicLog) async throws {
        let enriched = enrichWithArtistTokens(log)
        try await setData(enriched, in: logsCollection.document(enriched.id))
        Task {
            await MusicProfileSummaryService.shared.updateSummary(for: enriched)
        }
    }
    
    func updateLog(_ log: MusicLog) async throws {
        let enriched = enrichWithArtistTokens(log)
        try await setData(enriched, in: logsCollection.document(enriched.id))
        Task {
            await MusicProfileSummaryService.shared.updateSummary(for: enriched)
        }
    }
    
    func deleteLog(logId: String) async throws {
        let reference = logsCollection.document(logId)
        let snapshot = try? await getDocument(reference)
        let log = snapshot.flatMap { try? $0.data(as: MusicLog.self) }
        try await deleteDocument(reference)
        if let log {
            Task {
                await MusicProfileSummaryService.shared.updateSummary(for: log)
            }
        }
    }
    
    // MARK: - Fetching
    
    func fetchLogs(forUserId userId: String) async throws -> [MusicLog] {
        let query = logsCollection.whereField("userId", isEqualTo: userId)
        let snapshot = try await getDocuments(query)
        let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
        return logs.sorted { $0.dateLogged > $1.dateLogged }
    }
    
    func fetchAllLogs(limit: Int? = nil) async throws -> [MusicLog] {
        var query: Query = logsCollection.order(by: "dateLogged", descending: true)
        if let limit = limit {
            query = query.limit(to: limit)
        }
        let snapshot = try await getDocuments(query)
        return snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
    }
    
    func fetchLogsForItem(itemId: String, friendIds: [String]? = nil, limit: Int = 20) async throws -> [MusicLog] {
        var query: Query = logsCollection.whereField("itemId", isEqualTo: itemId)
        if let ids = friendIds, !ids.isEmpty, ids.count <= 10 {
            query = query.whereField("userId", in: ids)
        }
        query = query.limit(to: limit)
        let snapshot = try await getDocuments(query)
        return snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
    }
    
    func fetchEngagementMetrics(logId: String) async throws -> MusicLog? {
        let document = try await getDocument(logsCollection.document(logId))
        return try document.data(as: MusicLog.self)
    }
    
    // MARK: - Counters
    
    func updateCommentCount(logId: String, increment: Bool) async throws {
        let document = try await getDocument(logsCollection.document(logId))
        let currentCount = document.data()?["commentCount"] as? Int ?? 0
        let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
        try await updateData(["commentCount": newCount], in: document.reference)
    }
    
    func updateHelpfulCount(logId: String, isHelpful: Bool, increment: Bool) async throws {
        let document = try await getDocument(logsCollection.document(logId))
        let field = isHelpful ? "helpfulCount" : "unhelpfulCount"
        let current = document.data()?[field] as? Int ?? 0
        let newValue = increment ? current + 1 : max(0, current - 1)
        try await updateData([field: newValue], in: document.reference)
    }
    
    // MARK: - Helpers
    
    private func getDocuments(_ query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            query.getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: BumpinError.databaseError("No snapshot returned"))
                }
            }
        }
    }
    
    private func getDocument(_ reference: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            reference.getDocument { document, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let document = document {
                    continuation.resume(returning: document)
                } else {
                    continuation.resume(throwing: BumpinError.databaseError("Document not found"))
                }
            }
        }
    }
    
    private func setData<T: Encodable>(_ value: T, in reference: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try reference.setData(from: value) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func updateData(_ data: [String: Any], in reference: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.updateData(data) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func deleteDocument(_ reference: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.delete { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func enrichWithArtistTokens(_ log: MusicLog) -> MusicLog {
        var enriched = log
        let tokens = ArtistNameParser.tokens(from: log.artistName)
        enriched.artistTokens = tokens.isEmpty ? nil : tokens
        return enriched
    }
}

