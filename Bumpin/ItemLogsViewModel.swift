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
        
        do {
            let fetchedLogs: [MusicLog]
            if let friendIds, friendIds.count > 10 {
                fetchedLogs = try await fetchLogsInBatches(friendIds: friendIds)
            } else {
                fetchedLogs = try await MusicLogStore.shared.fetchLogsForItem(itemId: itemId,
                                                                             friendIds: friendIds,
                                                                             limit: 20)
            }
            self.logs = deduplicatedAndSorted(fetchedLogs)
            self.isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func fetchLogsInBatches(friendIds: [String]) async throws -> [MusicLog] {
        let targetItemId = itemId
        let batches = friendIds.chunked(into: 10)
        var aggregated: [MusicLog] = []
        
        try await withThrowingTaskGroup(of: [MusicLog].self) { group in
            for batch in batches {
                group.addTask {
                    try await MusicLogStore.shared.fetchLogsForItem(itemId: targetItemId,
                                                                   friendIds: batch,
                                                                   limit: 20)
                }
            }
            
            for try await result in group {
                aggregated.append(contentsOf: result)
            }
        }
        return aggregated
    }
    
    private func deduplicatedAndSorted(_ logs: [MusicLog]) -> [MusicLog] {
        var seen = Set<String>()
        return logs
            .sorted { $0.dateLogged > $1.dateLogged }
            .filter { log in
                guard !seen.contains(log.id) else { return false }
                seen.insert(log.id)
                return true
            }
    }
}
