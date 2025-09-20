import Foundation
import Combine
import SwiftUI

class RandomChatViewModel: ObservableObject {
    private let service = RandomChatService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // UI State
    @Published var isInQueue = false
    @Published var queueTimeString = "0:00"
    @Published var showingMatchAlert = false
    @Published var groupSize = 1
    @Published var genderPreference: GenderPreference = .any
    @Published var connectedGroupMembers: [String] = []
    @Published var error: Error?
    
    // Stats
    @Published var activeChats = 0
    @Published var queuedUsers = 0
    @Published var averageWaitTime = 0
    
    // Friends
    @Published var friends: [RandomChatFriend] = []
    @Published var matchedChat: TopicChat?
    
    // UI State
    @Published var showingGroupSizeSheet = false
    @Published var showingPreferencesSheet = false
    @Published var showingInviteFriendsSheet = false
    @Published var showTopicPicker = false
    @Published var selectedTopics: Set<String> = []
    
    var acceptedFriendsCount: Int {
        friends.filter { $0.hasAccepted }.count
    }
    
    var queueStatusText: String {
        if !isInQueue {
            return "Ready to Chat"
        }
        
        if let error = error {
            return error.localizedDescription
        }
        
        if showingMatchAlert {
            return "Match Found!"
        }
        
        if groupSize > 1 && connectedGroupMembers.count < groupSize {
            return "Waiting for group members..."
        }
        
        return "Finding your match..."
    }
    
    private var queueTimer: Timer?
    private var queueStartTime: Date?
    
    init() {
        setupSubscriptions()
        loadFriends()
    }
    
    private func setupSubscriptions() {
        // Subscribe to service updates
        service.$currentQueueRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in
                self?.isInQueue = request != nil
                self?.connectedGroupMembers = request?.groupMembers ?? []
                
                if request?.status == .matched {
                    self?.showingMatchAlert = true
                }
            }
            .store(in: &cancellables)
        
        service.$error
            .receive(on: DispatchQueue.main)
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
        
        service.$matchedChat
            .receive(on: DispatchQueue.main)
            .assign(to: \.matchedChat, on: self)
            .store(in: &cancellables)
        
        // Stats subscriptions
        service.$activeChatsCount
            .receive(on: DispatchQueue.main)
            .assign(to: \.activeChats, on: self)
            .store(in: &cancellables)
        
        service.$queuedUsersCount
            .receive(on: DispatchQueue.main)
            .assign(to: \.queuedUsers, on: self)
            .store(in: &cancellables)
        
        service.$averageWaitTime
            .receive(on: DispatchQueue.main)
            .assign(to: \.averageWaitTime, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Queue Management
    
    func joinQueue() {
        Task {
            do {
                // Provide immediate feedback
                HapticFeedback.queueJoined()
                await MainActor.run {
                    withAnimation(.spring()) {
                        isInQueue = true
                    }
                }
                
                // Join queue in Firebase
                try await service.joinQueue(groupSize: 1, genderPreference: genderPreference)
                
                await MainActor.run {
                    queueStartTime = Date()
                    startQueueTimer()
                }
                
                // Log analytics
                AnalyticsService.shared.logQueueAction(action: "join", groupSize: groupSize)
            } catch {
                await MainActor.run {
                    withAnimation {
                        isInQueue = false
                    }
                    self.error = error
                }
                HapticFeedback.error()
            }
        }
    }
    
    func leaveQueue() {
        Task {
            do {
                await MainActor.run {
                    // Stop the queue timer
                    queueTimer?.invalidate()
                    queueTimer = nil
                    
                    // Reset UI state
                    isInQueue = false
                    queueTimeString = "0:00"
                    showingMatchAlert = false
                }
                
                // Leave the queue in Firebase
                try await service.leaveQueue()
                
                await MainActor.run {
                    // Reset group state if needed
                    if groupSize > 1 {
                        connectedGroupMembers.removeAll()
                        friends = friends.map { friend in
                            var updated = friend
                            updated.isInvited = false
                            updated.hasAccepted = false
                            return updated
                        }
                    }
                }
                
                // Log analytics
                AnalyticsService.shared.logQueueAction(action: "leave", groupSize: groupSize)
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    // MARK: - Group Management
    
    func setGroupSize(_ size: Int) {
        groupSize = size
    }
    
    func showInviteFriends() {
        // This will be called by the view to show the invite sheet
    }
    
    var canStartGroupQueue: Bool {
        let acceptedFriends = friends.filter { $0.hasAccepted }.count
        return acceptedFriends == groupSize - 1
    }
    
    func inviteFriend(_ friend: RandomChatFriend) {
        Task {
            do {
                try await service.inviteFriend(friend.id)
                await MainActor.run {
                    if let index = friends.firstIndex(where: { $0.id == friend.id }) {
                        friends[index].isInvited = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    func startGroupQueue() {
        Task {
            do {
                try await service.joinQueue(groupSize: groupSize, genderPreference: genderPreference)
                await MainActor.run {
                    queueStartTime = Date()
                    startQueueTimer()
                }
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }
    
    func joinMatch() {
        // Will be implemented when we add the matching system
    }
    
    func cancelMatch() {
        Task {
            await MainActor.run {
                showingMatchAlert = false
            }
            leaveQueue()
        }
    }
    
    func endMatch() {
        Task {
            await MainActor.run {
                matchedChat = nil
                showingMatchAlert = false
            }
        }
    }
    
    func createMockMatch() {
        Task {
            await MainActor.run {
                // Create a mock TopicChat for testing
                var mockChat = TopicChat(
                    title: "Random Chat",
                    description: "A randomly matched conversation",
                    category: .trending,
                    hostId: "mock_host_123",
                    hostName: "Alex"
                )
                
                // Add mock participants (more to show grid layout)
                mockChat.participants = [
                    TopicParticipant(id: "mock_host_123", name: "Alex", isHost: true),
                    TopicParticipant(id: "current_user", name: "You", isHost: false),
                    TopicParticipant(id: "mock_user_2", name: "Sarah", isHost: false),
                    TopicParticipant(id: "mock_user_3", name: "Jordan", isHost: false),
                    TopicParticipant(id: "mock_user_4", name: "Taylor", isHost: false),
                    TopicParticipant(id: "mock_user_5", name: "Casey", isHost: false)
                ]
                
                // Set up voice chat
                mockChat.speakers = ["mock_host_123", "current_user", "mock_user_2"]
                mockChat.listeners = ["mock_user_3", "mock_user_4", "mock_user_5"]
                mockChat.voiceChatActive = true
                mockChat.currentDiscussion = "What's your favorite music genre?"
                
                // Set the matched chat to trigger navigation
                self.matchedChat = mockChat
                
                // Add haptic feedback
                HapticFeedback.matchFound()
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func startQueueTimer() {
        queueTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateQueueTime()
        }
    }
    
    private func updateQueueTime() {
        Task {
            await MainActor.run {
                guard let startTime = queueStartTime else { return }
                let interval = Int(-startTime.timeIntervalSinceNow)
                let minutes = interval / 60
                let seconds = interval % 60
                queueTimeString = String(format: "%d:%02d", minutes, seconds)
                
                // Check for timeout (5 minutes)
                if interval >= 300 {
                    Task {
                        await handleQueueTimeout()
                    }
                }
                
                // Update status message based on time
                if interval > 120 && queuedUsers < 2 {
                    error = NSError(
                        domain: "RandomChatError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Queue times are longer than usual. Try again later."]
                    )
                }
            }
        }
    }
    
    private func handleQueueTimeout() async {
        do {
            // Leave queue
            try await service.leaveQueue()
            
            await MainActor.run {
                // Reset state
                queueTimer?.invalidate()
                queueTimer = nil
                isInQueue = false
                queueTimeString = "0:00"
                
                // Show timeout error
                error = NSError(
                    domain: "RandomChatError",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Queue timed out. Please try again."]
                )
            }
            
            // Log analytics
            AnalyticsService.shared.logQueueAction(action: "timeout", groupSize: groupSize)
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    private func loadFriends() {
        // TODO: Replace with actual friend loading logic
        friends = [
            RandomChatFriend(id: "1", name: "Alex", status: "Online"),
            RandomChatFriend(id: "2", name: "Sarah", status: "Online"),
            RandomChatFriend(id: "3", name: "Mike", status: "Away"),
            RandomChatFriend(id: "4", name: "Emma", status: "Online"),
            RandomChatFriend(id: "5", name: "James", status: "Offline")
        ]
    }
}