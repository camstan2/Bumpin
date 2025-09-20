import Foundation
import FirebaseAuth
import Combine

/// View-model that fetches logs for a given item (song / album / artist).
/// If `friendsOnly` is true you must supply an array of friend UIDs (<=10 for now).
@MainActor
class ItemLogsViewModel: ObservableObject {
    @Published private(set) var logs: [MusicLog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private var cancellables = Set<AnyCancellable>()
    private let itemId: String
    private let friendIds: [String]?

    init(itemId: String, friendIds: [String]? = nil) {
        self.itemId = itemId
        self.friendIds = friendIds
        Task { await fetch() }
    }

    func fetch() async {
        isLoading = true
        error = nil

        // If no friendIds or <= 10, use the existing single call
        if friendIds == nil || (friendIds?.count ?? 0) <= 10 {
            MusicLog.fetchLogsForItem(itemId: itemId, friendIds: friendIds, limit: 20) { [weak self] logs, err in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let err = err {
                        self.error = err.localizedDescription
                    } else {
                        self.logs = (logs ?? []).sorted { $0.dateLogged > $1.dateLogged }
                    }
                }
            }
            return
        }

        // Batch into groups of 10 for Firestore 'in' query limits
        let batches: [[String]] = friendIds!.chunked(into: 10)
        var aggregated: [MusicLog] = []
        var firstError: Error?

        let group = DispatchGroup()
        for batch in batches {
            group.enter()
            MusicLog.fetchLogsForItem(itemId: itemId, friendIds: batch, limit: 20) { logs, err in
                if let err = err, firstError == nil { firstError = err }
                if let logs = logs { aggregated.append(contentsOf: logs) }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            if let err = firstError {
                self.error = err.localizedDescription
            }
            var seen = Set<String>()
            self.logs = aggregated.filter { log in
                if seen.contains(log.id) { return false }
                seen.insert(log.id)
                return true
            }.sorted { $0.dateLogged > $1.dateLogged }
        }
    }
}
