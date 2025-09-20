import Foundation

final class SocialSession {
    static let shared = SocialSession()
    private init() {}
    private(set) var seenLogIds: Set<String> = []
    private let lock = NSLock()

    func register(logId: String) {
        lock.lock(); defer { lock.unlock() }
        seenLogIds.insert(logId)
    }

    func register(logIds: [String]) {
        lock.lock(); defer { lock.unlock() }
        for id in logIds { seenLogIds.insert(id) }
    }
}


