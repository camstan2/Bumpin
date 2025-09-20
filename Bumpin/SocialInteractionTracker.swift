import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Service responsible for tracking social interactions and triggering rating prompts
@MainActor
class SocialInteractionTracker: ObservableObject {
    static let shared = SocialInteractionTracker()
    
    private let db = Firestore.firestore()
    private let socialScoringService = SocialScoringService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Active interactions tracking
    @Published private var activeInteractions: [String: SocialInteraction] = [:]
    
    // Minimum interaction duration to qualify for rating (in seconds)
    private let minimumInteractionDuration: TimeInterval = 60 // 1 minute
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Discussion events
        NotificationCenter.default.publisher(for: NSNotification.Name("DiscussionJoined"))
            .sink { [weak self] notification in
                if let discussion = notification.object as? TopicChat {
                    Task { @MainActor in
                        await self?.handleDiscussionJoined(discussion)
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("DiscussionLeft"))
            .sink { [weak self] notification in
                if let discussion = notification.object as? TopicChat {
                    Task { @MainActor in
                        await self?.handleDiscussionLeft(discussion)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Party events
        NotificationCenter.default.publisher(for: NSNotification.Name("PartyJoined"))
            .sink { [weak self] notification in
                if let party = notification.object as? Party {
                    Task { @MainActor in
                        await self?.handlePartyJoined(party)
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("PartyLeft"))
            .sink { [weak self] notification in
                if let party = notification.object as? Party {
                    Task { @MainActor in
                        await self?.handlePartyLeft(party)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Discussion Tracking
    
    private func handleDiscussionJoined(_ discussion: TopicChat) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("📊 SocialInteractionTracker: User joined discussion: \(discussion.title)")
        
        // Get all participant IDs
        let participantIds = discussion.participants.map { $0.id }
        
        // Only track if there are at least 2 participants
        guard participantIds.count >= 2 else { return }
        
        // Determine if this is a random meeting
        let isRandomMeeting = await determineIfRandomMeeting(
            participantIds: participantIds,
            currentUserId: currentUserId
        )
        
        // Create interaction context
        let context = SocialInteraction.InteractionContext(
            chatId: discussion.id,
            topic: discussion.title,
            groupSize: participantIds.count,
            wasRandom: isRandomMeeting
        )
        
        // Only track interactions that qualify for rating
        guard isRandomMeeting else {
            print("📊 SocialInteractionTracker: Skipping discussion - participants are friends")
            return
        }
        
        do {
            let interactionId = try await socialScoringService.startInteraction(
                participantIds: participantIds,
                interactionType: .discussion,
                context: context
            )
            
            // Store locally for tracking
            let interaction = SocialInteraction(
                participantIds: participantIds,
                interactionType: .discussion,
                context: context
            )
            
            activeInteractions[discussion.id] = interaction
            
            print("✅ SocialInteractionTracker: Started tracking discussion interaction: \(interactionId)")
            
        } catch {
            print("❌ SocialInteractionTracker: Failed to start discussion interaction: \(error)")
        }
    }
    
    private func handleDiscussionLeft(_ discussion: TopicChat) async {
        guard let interaction = activeInteractions[discussion.id] else {
            print("📊 SocialInteractionTracker: No active interaction found for discussion: \(discussion.id)")
            return
        }
        
        print("📊 SocialInteractionTracker: User left discussion: \(discussion.title)")
        
        // Calculate interaction duration
        let duration = Date().timeIntervalSince(interaction.startTime)
        
        // Only create rating prompts if interaction was long enough
        guard duration >= minimumInteractionDuration else {
            print("📊 SocialInteractionTracker: Discussion too short (\(duration)s) - skipping rating prompts")
            activeInteractions.removeValue(forKey: discussion.id)
            return
        }
        
        do {
            try await socialScoringService.endInteraction(
                interactionId: interaction.id,
                endTime: Date()
            )
            
            activeInteractions.removeValue(forKey: discussion.id)
            
            print("✅ SocialInteractionTracker: Ended discussion interaction and created rating prompts")
            
        } catch {
            print("❌ SocialInteractionTracker: Failed to end discussion interaction: \(error)")
        }
    }
    
    // MARK: - Party Tracking
    
    private func handlePartyJoined(_ party: Party) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        print("📊 SocialInteractionTracker: User joined party: \(party.name)")
        
        // Get all participant IDs
        let participantIds = party.participants.map { $0.id }
        
        // Only track if there are at least 2 participants
        guard participantIds.count >= 2 else { return }
        
        // Determine if this is a random meeting
        let isRandomMeeting = await determineIfRandomMeeting(
            participantIds: participantIds,
            currentUserId: currentUserId
        )
        
        // Create interaction context
        let context = SocialInteraction.InteractionContext(
            chatId: party.id,
            topic: party.name,
            groupSize: participantIds.count,
            wasRandom: isRandomMeeting
        )
        
        // Only track interactions that qualify for rating
        guard isRandomMeeting else {
            print("📊 SocialInteractionTracker: Skipping party - participants are friends")
            return
        }
        
        do {
            let interactionId = try await socialScoringService.startInteraction(
                participantIds: participantIds,
                interactionType: .party,
                context: context
            )
            
            // Store locally for tracking
            let interaction = SocialInteraction(
                participantIds: participantIds,
                interactionType: .party,
                context: context
            )
            
            activeInteractions[party.id] = interaction
            
            print("✅ SocialInteractionTracker: Started tracking party interaction: \(interactionId)")
            
        } catch {
            print("❌ SocialInteractionTracker: Failed to start party interaction: \(error)")
        }
    }
    
    private func handlePartyLeft(_ party: Party) async {
        guard let interaction = activeInteractions[party.id] else {
            print("📊 SocialInteractionTracker: No active interaction found for party: \(party.id)")
            return
        }
        
        print("📊 SocialInteractionTracker: User left party: \(party.name)")
        
        // Calculate interaction duration
        let duration = Date().timeIntervalSince(interaction.startTime)
        
        // Only create rating prompts if interaction was long enough
        guard duration >= minimumInteractionDuration else {
            print("📊 SocialInteractionTracker: Party too short (\(duration)s) - skipping rating prompts")
            activeInteractions.removeValue(forKey: party.id)
            return
        }
        
        do {
            try await socialScoringService.endInteraction(
                interactionId: interaction.id,
                endTime: Date()
            )
            
            activeInteractions.removeValue(forKey: party.id)
            
            print("✅ SocialInteractionTracker: Ended party interaction and created rating prompts")
            
        } catch {
            print("❌ SocialInteractionTracker: Failed to end party interaction: \(error)")
        }
    }
    
    // MARK: - Random Chat Tracking
    
    /// Manually track random chat interactions (called from RandomChatMatchingService)
    func trackRandomChatInteraction(
        chatId: String,
        participantIds: [String],
        topic: String = "Random Chat"
    ) async {
        guard participantIds.count >= 2 else { return }
        
        print("📊 SocialInteractionTracker: Tracking random chat interaction: \(chatId)")
        
        // Random chats are always with strangers
        let context = SocialInteraction.InteractionContext(
            chatId: chatId,
            topic: topic,
            groupSize: participantIds.count,
            wasRandom: true
        )
        
        do {
            let interactionId = try await socialScoringService.startInteraction(
                participantIds: participantIds,
                interactionType: .randomChat,
                context: context
            )
            
            // Store locally for tracking
            let interaction = SocialInteraction(
                participantIds: participantIds,
                interactionType: .randomChat,
                context: context
            )
            
            activeInteractions[chatId] = interaction
            
            print("✅ SocialInteractionTracker: Started tracking random chat interaction: \(interactionId)")
            
        } catch {
            print("❌ SocialInteractionTracker: Failed to start random chat interaction: \(error)")
        }
    }
    
    /// End random chat interaction
    func endRandomChatInteraction(chatId: String) async {
        guard let interaction = activeInteractions[chatId] else {
            print("📊 SocialInteractionTracker: No active interaction found for random chat: \(chatId)")
            return
        }
        
        print("📊 SocialInteractionTracker: Ending random chat interaction: \(chatId)")
        
        // Calculate interaction duration
        let duration = Date().timeIntervalSince(interaction.startTime)
        
        // Only create rating prompts if interaction was long enough
        guard duration >= minimumInteractionDuration else {
            print("📊 SocialInteractionTracker: Random chat too short (\(duration)s) - skipping rating prompts")
            activeInteractions.removeValue(forKey: chatId)
            return
        }
        
        do {
            try await socialScoringService.endInteraction(
                interactionId: interaction.id,
                endTime: Date()
            )
            
            activeInteractions.removeValue(forKey: chatId)
            
            print("✅ SocialInteractionTracker: Ended random chat interaction and created rating prompts")
            
        } catch {
            print("❌ SocialInteractionTracker: Failed to end random chat interaction: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determines if an interaction involves random users (not friends)
    private func determineIfRandomMeeting(participantIds: [String], currentUserId: String) async -> Bool {
        guard participantIds.count > 1 else { return false }
        
        // Get current user's following list
        do {
            let currentUserDoc = try await db.collection("users").document(currentUserId).getDocument()
            let following = currentUserDoc.data()?["following"] as? [String] ?? []
            
            // Check if any other participant is in the following list
            let otherParticipants = participantIds.filter { $0 != currentUserId }
            
            for participantId in otherParticipants {
                if following.contains(participantId) {
                    return false // Found a friend, so not a random meeting
                }
            }
            
            return true // No friends found, it's a random meeting
            
        } catch {
            print("❌ SocialInteractionTracker: Error checking friendships: \(error)")
            // Default to treating as random meeting if we can't check friendships
            return true
        }
    }
    
    /// Get active interaction for a chat/party ID
    func getActiveInteraction(for chatId: String) -> SocialInteraction? {
        return activeInteractions[chatId]
    }
    
    /// Get count of active interactions
    var activeInteractionCount: Int {
        return activeInteractions.count
    }
    
    /// Force end all active interactions (useful for app backgrounding/termination)
    func endAllActiveInteractions() async {
        print("📊 SocialInteractionTracker: Force ending all active interactions (\(activeInteractions.count))")
        
        for (chatId, interaction) in activeInteractions {
            let duration = Date().timeIntervalSince(interaction.startTime)
            
            // Only end interactions that meet minimum duration
            if duration >= minimumInteractionDuration {
                do {
                    try await socialScoringService.endInteraction(
                        interactionId: interaction.id,
                        endTime: Date()
                    )
                    print("✅ SocialInteractionTracker: Force ended interaction: \(chatId)")
                } catch {
                    print("❌ SocialInteractionTracker: Failed to force end interaction \(chatId): \(error)")
                }
            }
        }
        
        activeInteractions.removeAll()
    }
}

// MARK: - App Lifecycle Integration

extension SocialInteractionTracker {
    /// Call this when app enters background
    func handleAppDidEnterBackground() {
        Task {
            await endAllActiveInteractions()
        }
    }
    
    /// Call this when app will terminate
    func handleAppWillTerminate() {
        Task {
            await endAllActiveInteractions()
        }
    }
}

// MARK: - Integration Extensions

/// Extension to help integrate with existing party and discussion managers
extension SocialInteractionTracker {
    
    /// Convenience method to start tracking when joining a party
    func startTrackingParty(_ party: Party) async {
        await handlePartyJoined(party)
    }
    
    /// Convenience method to stop tracking when leaving a party
    func stopTrackingParty(_ party: Party) async {
        await handlePartyLeft(party)
    }
    
    /// Convenience method to start tracking when joining a discussion
    func startTrackingDiscussion(_ discussion: TopicChat) async {
        await handleDiscussionJoined(discussion)
    }
    
    /// Convenience method to stop tracking when leaving a discussion
    func stopTrackingDiscussion(_ discussion: TopicChat) async {
        await handleDiscussionLeft(discussion)
    }
}

// MARK: - Debug and Testing

extension SocialInteractionTracker {
    /// Debug method to print current active interactions
    func printActiveInteractions() {
        print("📊 Active Interactions (\(activeInteractions.count)):")
        for (chatId, interaction) in activeInteractions {
            let duration = Date().timeIntervalSince(interaction.startTime)
            print("  - \(chatId): \(interaction.interactionType.displayName) (\(Int(duration))s)")
        }
    }
    
    /// Test method to simulate an interaction
    func simulateInteraction(
        participantIds: [String],
        interactionType: SocialInteraction.InteractionType,
        topic: String,
        durationSeconds: TimeInterval = 120
    ) async {
        let chatId = "test_\(UUID().uuidString)"
        
        // Start interaction
        let context = SocialInteraction.InteractionContext(
            chatId: chatId,
            topic: topic,
            groupSize: participantIds.count,
            wasRandom: true
        )
        
        do {
            let interactionId = try await socialScoringService.startInteraction(
                participantIds: participantIds,
                interactionType: interactionType,
                context: context
            )
            
            print("🧪 Started test interaction: \(interactionId)")
            
            // Simulate passage of time
            try await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
            
            // End interaction
            try await socialScoringService.endInteraction(
                interactionId: interactionId,
                endTime: Date()
            )
            
            print("🧪 Ended test interaction: \(interactionId)")
            
        } catch {
            print("🧪 Test interaction failed: \(error)")
        }
    }
}
