import Foundation
import Network
import FirebaseFirestore

enum OfflineActionType: String, Codable {
    case joinParty
    case like
    case follow
}

struct OfflineAction: Codable {
    let id: String
    let type: OfflineActionType
    let payload: Data
    let createdAt: Date
}

final class OfflineActionQueue {
    static let shared = OfflineActionQueue()
    private init() {
        startMonitoring()
        loadQueue()
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "offline-action-queue")
    private var isOnlineInternal: Bool = true
    var isOnline: Bool { isOnlineInternal }

    private var actions: [OfflineAction] = []
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("offline_actions.json")
    }()

    private func persistQueue() {
        if let data = try? JSONEncoder().encode(actions) {
            try? data.write(to: fileURL)
        }
    }

    private func loadQueue() {
        if let data = try? Data(contentsOf: fileURL), let arr = try? JSONDecoder().decode([OfflineAction].self, from: data) {
            actions = arr
        }
    }

    static let reachabilityChanged = Notification.Name("OfflineActionQueueReachabilityChanged")

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.isOnlineInternal = path.status == .satisfied
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.reachabilityChanged, object: self.isOnlineInternal)
            }
            if self.isOnlineInternal {
                self.processQueue()
            }
        }
        monitor.start(queue: queue)
    }

    func enqueueJoinParty(party: Party) {
        let payload = try? JSONEncoder().encode(party)
        let action = OfflineAction(id: UUID().uuidString, type: .joinParty, payload: payload ?? Data(), createdAt: Date())
        actions.append(action)
        persistQueue()
    }
    
    func enqueueLike(userId: String, itemId: String, itemTypeRaw: String) {
        let dict: [String: String] = ["userId": userId, "itemId": itemId, "itemType": itemTypeRaw]
        let payload = try? JSONSerialization.data(withJSONObject: dict)
        let action = OfflineAction(id: UUID().uuidString, type: .like, payload: payload ?? Data(), createdAt: Date())
        actions.append(action)
        persistQueue()
    }
    
    func enqueueFollow(currentUserId: String, targetUserId: String) {
        let dict: [String: String] = ["currentUserId": currentUserId, "targetUserId": targetUserId]
        let payload = try? JSONSerialization.data(withJSONObject: dict)
        let action = OfflineAction(id: UUID().uuidString, type: .follow, payload: payload ?? Data(), createdAt: Date())
        actions.append(action)
        persistQueue()
    }

    // TODO: implement like/follow enqueue helpers as those flows are built out

    private func processQueue() {
        guard isOnlineInternal else { return }
        // Simple FIFO processing
        var remaining: [OfflineAction] = []
        for action in actions {
            switch action.type {
            case .joinParty:
                if let party = try? JSONDecoder().decode(Party.self, from: action.payload) {
                    // Repost the same local notification used by the UI to perform a join
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("JoinParty"), object: party)
                    }
                } else {
                    // Malformed payload; drop
                }
            case .like:
                if let dict = try? JSONSerialization.jsonObject(with: action.payload) as? [String: String],
                   let userId = dict["userId"], let itemId = dict["itemId"], let itemType = dict["itemType"],
                   let likeType = UserLike.LikeType(rawValue: itemType) {
                    // Attempt to add like
                    let like = UserLike(userId: userId, itemId: itemId, itemType: likeType, itemTitle: "", itemArtist: nil, itemArtworkUrl: nil)
                    let semaphore = DispatchSemaphore(value: 0)
                    UserLike.addLike(like) { _ in semaphore.signal() }
                    _ = semaphore.wait(timeout: .now() + 5)
                } else {
                    remaining.append(action)
                }
            case .follow:
                if let dict = try? JSONSerialization.jsonObject(with: action.payload) as? [String: String],
                   let currentUserId = dict["currentUserId"], let targetUserId = dict["targetUserId"] {
                    let semaphore = DispatchSemaphore(value: 0)
                    Firestore.firestore().collection("users").document(currentUserId).updateData(["following": FieldValue.arrayUnion([targetUserId])]) { _ in semaphore.signal() }
                    _ = semaphore.wait(timeout: .now() + 5)
                } else {
                    remaining.append(action)
                }
            }
        }
        actions = remaining
        persistQueue()
        AnalyticsService.shared.logOfflineQueue(length: remaining.count)
    }
}


