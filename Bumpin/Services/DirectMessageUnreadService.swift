import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Tracks unread direct message conversations for the current user.
@MainActor
final class DirectMessageUnreadService: ObservableObject {
    static let shared = DirectMessageUnreadService()
    
    @Published private(set) var unreadConversationCount: Int = 0
    @Published private(set) var unreadRequestCount: Int = 0
    
    private var inboxListener: ListenerRegistration?
    private var requestListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        NotificationCenter.default.publisher(for: .AuthStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.resetAndAttach()
                }
            }
            .store(in: &cancellables)
        
        Task { @MainActor in
            resetAndAttach()
        }
    }
    
    deinit {
        inboxListener?.remove()
        requestListener?.remove()
    }
    
    func resetAndAttach() {
        detachListeners()
        guard let uid = Auth.auth().currentUser?.uid else {
            unreadConversationCount = 0
            unreadRequestCount = 0
            return
        }
        
        inboxListener = DirectMessageService.shared.observeInbox(for: uid) { [weak self] conversations in
            guard let self else { return }
            let unread = conversations.filter { Self.isConversationUnread($0, for: uid) }
            Task { @MainActor in
                self.unreadConversationCount = unread.count
            }
        }
        
        requestListener = DirectMessageService.shared.observeRequests(for: uid) { [weak self] conversations in
            guard let self else { return }
            let unread = conversations.filter { Self.isConversationUnread($0, for: uid) }
            Task { @MainActor in
                self.unreadRequestCount = unread.count
            }
        }
    }
    
    private func detachListeners() {
        inboxListener?.remove()
        inboxListener = nil
        requestListener?.remove()
        requestListener = nil
    }
    
    private static func isConversationUnread(_ conversation: Conversation, for userId: String) -> Bool {
        guard let lastTimestamp = conversation.lastTimestamp else { return false }
        let lastRead = conversation.lastReadAtByUser?[userId]
        return lastRead == nil || lastRead! < lastTimestamp
    }
}

