import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

class UnifiedDiscussionViewModel: ObservableObject {
    @Published var yourTeam: [TopicParticipant] = []
    @Published var otherTeam: [TopicParticipant] = []
    @Published var showingUserProfile = false
    @Published var selectedUserId: String?
    @Published var showingPartyVoting = false
    @Published var partyVotingInProgress = false
    @Published var currentVotes = 0
    @Published var requiredVotes = 0
    @Published var votingTimeRemaining = 30
    @Published var voiceChatStatus: String?
    @Published var messageText = ""
    @Published var mutedUsers: Set<String> = [] // Users muted by current user
    @Published var messages: [DiscussionMessage] = [] // Chat messages
    @Published var messageReactions: [String: [ReactionSummary]] = [:]
    
    let iceBreakers = [
        "What's your favorite music genre?",
        "Been to any good concerts lately?",
        "What artists are you listening to?",
        "Any good music recommendations?",
        "What's your go-to karaoke song?",
        "Favorite album of all time?",
        "Best live performance you've seen?",
        "What song always gets you pumped up?",
        "Any hidden gem artists we should know?",
        "What's your music guilty pleasure?"
    ]
    
    private var chatBinding: Binding<TopicChat>?
    private var discussionType: DiscussionType?
    private var currentUserId: String?
    private var votingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    
    func setupDiscussion(chat: Binding<TopicChat>, type: DiscussionType) {
        self.chatBinding = chat
        self.discussionType = type
        self.currentUserId = Auth.auth().currentUser?.uid
        
        setupTeams()
        calculateVotingRequirements()
        
        // Listen for party voting updates
        listenForPartyVoting()
        
        // Create demo reactions for testing
        createDemoDiscussionReactions()
        
        // Listen for chat messages
        listenForMessages()
        
        voiceChatStatus = "Connected to voice chat"
    }
    
    private func setupTeams() {
        guard let chat = chatBinding?.wrappedValue,
              let currentUserId = currentUserId,
              discussionType == .randomChat else { return }
        
        // For random chat, split participants into teams
        // This is a simplified version - in reality, you'd have team data from the matching
        let allParticipants = chat.participants
        let currentUserIndex = allParticipants.firstIndex { $0.id == currentUserId } ?? 0
        
        // Split participants: current user's team vs other team
        // For now, we'll assume first half is your team, second half is other team
        let midpoint = allParticipants.count / 2
        
        if currentUserIndex < midpoint {
            yourTeam = Array(allParticipants.prefix(midpoint))
            otherTeam = Array(allParticipants.suffix(from: midpoint))
        } else {
            yourTeam = Array(allParticipants.suffix(from: midpoint))
            otherTeam = Array(allParticipants.prefix(midpoint))
        }
    }
    
    private func calculateVotingRequirements() {
        guard let chat = chatBinding?.wrappedValue else { return }
        
        let totalParticipants = chat.participants.count
        requiredVotes = Int(ceil(Double(totalParticipants) * 0.75)) // 3/4 majority
    }
    
    func showUserProfile(userId: String) {
        selectedUserId = userId
        showingUserProfile = true
    }
    
    func suggestTopic(_ topic: String) {
        guard let chat = chatBinding?.wrappedValue else { return }
        
        // Update the current discussion in Firestore
        db.collection("topicChats").document(chat.id).updateData([
            "currentDiscussion": topic
        ]) { error in
            if let error = error {
                print("Error updating discussion topic: \(error)")
            }
        }
        
        // Log analytics
        AnalyticsService.shared.logTap(category: "discussion_topic_suggested", id: chat.id)
    }
    
    func pinDiscussionTopic(_ topic: String) {
        guard let chatBinding = chatBinding else { return }
        
        // Update the local chat object immediately for UI responsiveness
        chatBinding.wrappedValue.currentDiscussion = topic
        print("✅ Updated local chat.currentDiscussion to: \(topic)")
        
        // Update the current discussion in Firestore to pin it
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        let chat = chatBinding.wrappedValue
        db.collection(collection).document(chat.id).updateData([
            "currentDiscussion": topic,
            "pinnedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error pinning discussion topic: \(error)")
                // For mock data, this is expected - just update locally
                print("✅ Topic pinned locally: \(topic)")
            } else {
                print("✅ Pinned topic in Firestore: \(topic)")
            }
        }
        
        // Log analytics
        AnalyticsService.shared.logTap(category: "discussion_topic_pinned", id: chat.id)
    }
    
    func sendMessage() {
        guard let chat = chatBinding?.wrappedValue,
              let currentUserId = currentUserId,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            return 
        }
        
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear the input immediately for better UX
        messageText = ""
        
        // Send message to Firestore
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        let messageData: [String: Any] = [
            "id": UUID().uuidString,
            "text": message,
            "userId": currentUserId,
            "userName": chat.participants.first { $0.id == currentUserId }?.name ?? "Anonymous",
            "timestamp": FieldValue.serverTimestamp(),
            "chatId": chat.id
        ]
        
        db.collection(collection).document(chat.id).collection("messages").addDocument(data: messageData) { error in
            if let error = error {
                print("Error sending message: \(error)")
            }
        }
        
        // Log analytics
        AnalyticsService.shared.logTap(category: "discussion_message_sent", id: chat.id)
    }
    
    func initiatePartyCreation() {
        guard let chat = chatBinding?.wrappedValue,
              let currentUserId = currentUserId else { return }
        
        // Create a party creation vote in Firestore
        let voteData: [String: Any] = [
            "chatId": chat.id,
            "initiatorId": currentUserId,
            "initiatorName": chat.participants.first { $0.id == currentUserId }?.name ?? "Unknown",
            "votes": [currentUserId], // Initiator automatically votes yes
            "requiredVotes": requiredVotes,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": FieldValue.serverTimestamp(), // Will be set to 30 seconds from now
            "status": "active"
        ]
        
        db.collection("partyCreationVotes").addDocument(data: voteData) { [weak self] error in
            if let error = error {
                print("Error creating party vote: \(error)")
            } else {
                DispatchQueue.main.async {
                    self?.partyVotingInProgress = true
                    self?.currentVotes = 1
                    self?.startVotingTimer()
                }
            }
        }
        
        // Log analytics
        AnalyticsService.shared.logTap(category: "party_creation_initiated", id: chat.id)
    }
    
    private func listenForPartyVoting() {
        guard let chat = chatBinding?.wrappedValue else { return }
        
        db.collection("partyCreationVotes")
            .whereField("chatId", isEqualTo: chat.id)
            .whereField("status", isEqualTo: "active")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error listening for party votes: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents,
                      let voteDoc = documents.first else {
                    DispatchQueue.main.async {
                        self?.partyVotingInProgress = false
                    }
                    return
                }
                
                let data = voteDoc.data()
                let votes = data["votes"] as? [String] ?? []
                let required = data["requiredVotes"] as? Int ?? 0
                
                DispatchQueue.main.async {
                    self?.currentVotes = votes.count
                    self?.requiredVotes = required
                    self?.partyVotingInProgress = true
                    
                    // Check if voting passed
                    if votes.count >= required {
                        self?.handleVotingPassed(voteDoc: voteDoc)
                    }
                }
            }
    }
    
    private func handleVotingPassed(voteDoc: DocumentSnapshot) {
        guard let chat = chatBinding?.wrappedValue else { return }
        
        // Create the party
        let party = Party(
            name: "\(chat.title) Party",
            hostId: chat.hostId,
            hostName: chat.hostName,
            isPublic: true
        )
        
        // Save party to Firestore and update vote status
        let batch = db.batch()
        
        let partyRef = db.collection("parties").document(party.id)
        
        // Convert party to Firestore data manually
        let participantArray: [[String: Any]] = party.participants.map { [
            "id": $0.id,
            "name": $0.name,
            "isHost": $0.isHost,
            "joinedAt": FieldValue.serverTimestamp()
        ] }
        
        let partyData: [String: Any] = [
            "id": party.id,
            "name": party.name,
            "hostId": party.hostId,
            "hostName": party.hostName,
            "createdAt": FieldValue.serverTimestamp(),
            "participants": participantArray,
            "currentSong": NSNull(),
            "isActive": party.isActive,
            "latitude": NSNull(),
            "longitude": NSNull(),
            "isPublic": party.isPublic,
            "maxDistance": party.maxDistance,
            "admissionMode": "open",
            "whoCanAddSongs": "all",
            "voiceChatEnabled": true,
            "locationSharingEnabled": false,
            "speakingPermissionMode": "open",
            "friendsAutoSpeaker": false,
            "accessCode": NSNull()
        ]
        
        batch.setData(partyData, forDocument: partyRef)
        
        let voteRef = voteDoc.reference
        batch.updateData(["status": "completed", "partyId": party.id], forDocument: voteRef)
        
        batch.commit { [weak self] error in
            if let error = error {
                print("Error creating party: \(error)")
            } else {
                DispatchQueue.main.async {
                    self?.handlePartyCreated(party)
                }
            }
        }
    }
    
    func handlePartyCreated(_ party: Party) {
        partyVotingInProgress = false
        votingTimer?.invalidate()
        
        // Navigate to party or show success message
        // This would typically trigger navigation in the parent view
        
        // Log analytics
        AnalyticsService.shared.logTap(category: "party_created_from_discussion", id: party.id)
    }
    
    private func startVotingTimer() {
        votingTimeRemaining = 30
        votingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.votingTimeRemaining -= 1
                
                if self?.votingTimeRemaining ?? 0 <= 0 {
                    self?.handleVotingTimeout()
                }
            }
        }
    }
    
    private func handleVotingTimeout() {
        votingTimer?.invalidate()
        partyVotingInProgress = false
        
        // Mark vote as expired in Firestore
        guard let chat = chatBinding?.wrappedValue else { return }
        
        db.collection("partyCreationVotes")
            .whereField("chatId", isEqualTo: chat.id)
            .whereField("status", isEqualTo: "active")
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                for doc in documents {
                    doc.reference.updateData(["status": "expired"])
                }
            }
    }
    
    // MARK: - Message Listening
    
    private func listenForMessages() {
        guard let chat = chatBinding?.wrappedValue,
              let discussionType = discussionType else { return }
        
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        db.collection(collection)
            .document(chat.id)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening for messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let newMessages = documents.compactMap { DiscussionMessage(document: $0) }
                
                DispatchQueue.main.async {
                    self.messages = newMessages
                    print("📱 Loaded \(newMessages.count) messages")
                }
            }
    }
    
    func cleanup() {
        votingTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Participant Actions
    
    func handleParticipantAction(_ action: ParticipantAction, chat: Binding<TopicChat>) {
        switch action {
        case .viewProfile(let userId):
            showUserProfile(userId: userId)
            
        case .muteForCurrentUser(let userId):
            toggleUserMute(userId: userId)
            
        case .muteForEveryone(let userId):
            muteParticipantForEveryone(userId: userId, chat: chat)
            
        case .giveSpeaking(let userId):
            updateSpeakingPermission(userId: userId, isSpeaker: true, chat: chat)
            
        case .removeSpeaking(let userId):
            updateSpeakingPermission(userId: userId, isSpeaker: false, chat: chat)
            
        case .kickParticipant(let userId):
            kickParticipant(userId: userId, chat: chat)
        }
    }
    
    // MARK: - Individual User Muting (Local)
    
    private func toggleUserMute(userId: String) {
        if mutedUsers.contains(userId) {
            mutedUsers.remove(userId)
            print("🔊 Unmuted user \(userId) for current user")
        } else {
            mutedUsers.insert(userId)
            print("🔇 Muted user \(userId) for current user")
        }
        
        // TODO: Integrate with VoiceChatManager to actually mute audio
        // voiceChatManager.muteUser(userId, isMuted: mutedUsers.contains(userId))
    }
    
    // MARK: - Speaking Permission Management
    
    private func updateSpeakingPermission(userId: String, isSpeaker: Bool, chat: Binding<TopicChat>) {
        guard let discussionType = discussionType else { return }
        
        var updatedChat = chat.wrappedValue
        
        if isSpeaker {
            // Add to speakers, remove from listeners
            if !updatedChat.speakers.contains(userId) {
                updatedChat.speakers.append(userId)
            }
            updatedChat.listeners.removeAll { $0 == userId }
            print("🎤 Gave speaking permission to user \(userId)")
        } else {
            // Remove from speakers, add to listeners
            updatedChat.speakers.removeAll { $0 == userId }
            if !updatedChat.listeners.contains(userId) {
                updatedChat.listeners.append(userId)
            }
            print("🔇 Removed speaking permission from user \(userId)")
        }
        
        // Update local state
        chat.wrappedValue = updatedChat
        
        // Update Firestore
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        db.collection(collection).document(updatedChat.id).updateData([
            "speakers": updatedChat.speakers,
            "listeners": updatedChat.listeners,
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error updating speaking permissions: \(error)")
            } else {
                print("✅ Speaking permissions updated in Firestore")
            }
        }
        
        // Log analytics
        AnalyticsService.shared.logTap(
            category: isSpeaker ? "speaking_permission_granted" : "speaking_permission_removed",
            id: updatedChat.id
        )
    }
    
    // MARK: - Global Muting (Host Only)
    
    private func muteParticipantForEveryone(userId: String, chat: Binding<TopicChat>) {
        guard let discussionType = discussionType,
              let currentUserId = currentUserId,
              chat.wrappedValue.hostId == currentUserId else {
            print("❌ Only host can mute participants for everyone")
            return
        }
        
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        db.collection(collection).document(chat.wrappedValue.id).updateData([
            "globallyMutedUsers": FieldValue.arrayUnion([userId]),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error muting participant globally: \(error)")
            } else {
                print("✅ Muted participant \(userId) for everyone")
            }
        }
        
        // Log analytics
        AnalyticsService.shared.logTap(category: "participant_muted_globally", id: chat.wrappedValue.id)
    }
    
    // MARK: - Kick Participant (Host Only)
    
    private func kickParticipant(userId: String, chat: Binding<TopicChat>) {
        guard let discussionType = discussionType,
              let currentUserId = currentUserId,
              chat.wrappedValue.hostId == currentUserId else {
            print("❌ Only host can kick participants")
            return
        }
        
        var updatedChat = chat.wrappedValue
        
        // Remove from all arrays
        updatedChat.participants.removeAll { participant in participant.id == userId }
        updatedChat.speakers.removeAll { $0 == userId }
        updatedChat.listeners.removeAll { $0 == userId }
        
        // Update local state
        chat.wrappedValue = updatedChat
        
        // Update Firestore
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        let participantArray: [[String: Any]] = updatedChat.participants.map { participant in
            [
                "id": participant.id,
                "name": participant.name,
                "profileImageUrl": participant.profileImageUrl ?? NSNull(),
                "isHost": participant.isHost
            ]
        }
        
        db.collection(collection).document(updatedChat.id).updateData([
            "participants": participantArray,
            "speakers": updatedChat.speakers,
            "listeners": updatedChat.listeners,
            "kickedUsers": FieldValue.arrayUnion([userId]),
            "lastUpdated": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error kicking participant: \(error)")
            } else {
                print("✅ Kicked participant \(userId) from discussion")
            }
        }
        
        // Log analytics
        AnalyticsService.shared.logTap(category: "participant_kicked", id: updatedChat.id)
    }
    
    // MARK: - Discussion Message Reaction Functions
    
    func addReaction(to messageId: String, emoji: String) {
        guard let chat = chatBinding?.wrappedValue,
              let discussionType = discussionType,
              let currentUserId = currentUserId else {
            print("❌ Cannot add reaction: Missing chat or user info")
            return
        }
        
        let username = Auth.auth().currentUser?.displayName ?? "Unknown User"
        
        let reaction = MessageReaction(
            messageId: messageId,
            emoji: emoji,
            userId: currentUserId,
            username: username
        )
        
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        // Add to Firestore
        Task { @MainActor in
            do {
                try await db.collection(collection)
                    .document(chat.id)
                    .collection("messageReactions")
                    .document(reaction.id)
                    .setData(reaction.toFirestoreData())
                
                print("✅ Discussion reaction added successfully")
                await loadReactions(for: messageId)
            } catch {
                print("❌ Failed to add discussion reaction: \(error)")
            }
        }
    }
    
    func removeReaction(from messageId: String, emoji: String) {
        guard let chat = chatBinding?.wrappedValue,
              let discussionType = discussionType,
              let currentUserId = currentUserId else {
            print("❌ Cannot remove reaction: Missing chat or user info")
            return
        }
        
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        Task { @MainActor in
            do {
                // Find and delete the user's reaction for this emoji
                let snapshot = try await db.collection(collection)
                    .document(chat.id)
                    .collection("messageReactions")
                    .whereField("messageId", isEqualTo: messageId)
                    .whereField("emoji", isEqualTo: emoji)
                    .whereField("userId", isEqualTo: currentUserId)
                    .getDocuments()
                
                for document in snapshot.documents {
                    try await document.reference.delete()
                }
                
                print("✅ Discussion reaction removed successfully")
                await loadReactions(for: messageId)
            } catch {
                print("❌ Failed to remove discussion reaction: \(error)")
            }
        }
    }
    
    func toggleReaction(on messageId: String, emoji: String) {
        let currentReactions = messageReactions[messageId] ?? []
        let hasReaction = currentReactions.first { $0.emoji == emoji }?.hasCurrentUser ?? false
        
        if hasReaction {
            removeReaction(from: messageId, emoji: emoji)
        } else {
            addReaction(to: messageId, emoji: emoji)
        }
    }
    
    func loadReactions(for messageId: String) async {
        guard let chat = chatBinding?.wrappedValue,
              let discussionType = discussionType,
              let currentUserId = currentUserId else { return }
        
        let collection = discussionType == .randomChat ? "randomChats" : "topicChats"
        
        do {
            let snapshot = try await db.collection(collection)
                .document(chat.id)
                .collection("messageReactions")
                .whereField("messageId", isEqualTo: messageId)
                .getDocuments()
            
            let reactions = snapshot.documents.compactMap { doc -> MessageReaction? in
                return MessageReaction(from: doc)
            }
            
            // Group reactions by emoji
            let groupedReactions = Dictionary(grouping: reactions, by: { $0.emoji })
            let reactionSummaries = groupedReactions.map { emoji, reactions in
                ReactionSummary(emoji: emoji, reactions: reactions, currentUserId: currentUserId)
            }.sorted { $0.count > $1.count }
            
            await MainActor.run {
                self.messageReactions[messageId] = reactionSummaries
            }
        } catch {
            print("❌ Failed to load discussion reactions: \(error)")
        }
    }
    
    func loadAllReactions() {
        Task { @MainActor in
            for message in messages {
                await loadReactions(for: message.id)
            }
        }
    }
    
    func createDemoDiscussionReactions() {
        // Add demo reactions for discussion chat testing
        let demoReactions: [String: [String]] = [
            "disc_msg_1": ["👍", "💭", "🤔"],
            "disc_msg_2": ["❤️", "🔥"],
            "disc_msg_3": ["😂", "👏", "💯"]
        ]
        
        let currentUserId = Auth.auth().currentUser?.uid ?? "demo_current_user"
        
        for (messageId, emojis) in demoReactions {
            var reactions: [MessageReaction] = []
            
            for (index, emoji) in emojis.enumerated() {
                let reaction = MessageReaction(
                    messageId: messageId,
                    emoji: emoji,
                    userId: "disc_demo_user_\(index)",
                    username: "Discussion User \(index + 1)"
                )
                reactions.append(reaction)
            }
            
            // Group reactions by emoji and create summaries
            let groupedReactions = Dictionary(grouping: reactions, by: { $0.emoji })
            let reactionSummaries = groupedReactions.map { emoji, reactions in
                ReactionSummary(emoji: emoji, reactions: reactions, currentUserId: currentUserId)
            }.sorted { $0.count > $1.count }
            
            messageReactions[messageId] = reactionSummaries
        }
        
        print("✅ Created demo discussion reactions")
    }
}

// MARK: - Extensions

extension UnifiedDiscussionViewModel {
    func voteForParty() {
        guard let chat = chatBinding?.wrappedValue,
              let currentUserId = currentUserId else { return }
        
        db.collection("partyCreationVotes")
            .whereField("chatId", isEqualTo: chat.id)
            .whereField("status", isEqualTo: "active")
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents,
                      let voteDoc = documents.first else { return }
                
                voteDoc.reference.updateData([
                    "votes": FieldValue.arrayUnion([currentUserId])
                ])
            }
    }
}
