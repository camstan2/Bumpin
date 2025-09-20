import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Game Service
// Central service for managing game sessions, matchmaking, and game state

@MainActor
class GameService: ObservableObject {
    static let shared = GameService()
    
    // MARK: - Published Properties
    
    @Published var currentGameSession: GameSession?
    @Published var availableGames: [GameSession] = []
    @Published var friendsGames: [GameSession] = []
    @Published var trendingGames: [GameSession] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // Queue management
    @Published var currentQueue: GameQueue?
    @Published var queuePosition: Int = 0
    @Published var estimatedWaitTime: TimeInterval?
    
    // Friend group management
    @Published var currentPlayerGroup: PlayerGroup?
    @Published var availableGroups: [PlayerGroup] = []
    @Published var groupInvites: [GroupInvite] = []
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupListeners()
    }
    
    deinit {
        Task { @MainActor in
            self.removeAllListeners()
        }
    }
    
    // MARK: - Game Session Management
    
    /// Creates a new game session
    func createGameSession(title: String, gameType: GameType, config: GameConfig? = nil) async throws -> GameSession {
        guard let currentUser = Auth.auth().currentUser else {
            throw GameServiceError.notAuthenticated
        }
        
        let gameSession = GameSession.createNew(
            title: title,
            gameType: gameType,
            hostId: currentUser.uid,
            hostName: currentUser.displayName ?? "Unknown",
            config: config
        )
        
        // Save to Firestore
        try await db.collection("gameSessions").document(gameSession.id).setData(from: gameSession)
        
        // Set as current session
        currentGameSession = gameSession
        
        return gameSession
    }
    
    /// Joins an existing game session as a player
    func joinGameSession(_ session: GameSession) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GameServiceError.notAuthenticated
        }
        
        var updatedSession = session
        
        let participant = GameParticipant(
            userId: currentUser.uid,
            userName: currentUser.displayName ?? "Unknown"
        )
        
        guard updatedSession.addPlayer(participant) else {
            throw GameServiceError.gameFull
        }
        
        // Update in Firestore
        try await db.collection("gameSessions").document(session.id).setData(from: updatedSession)
        
        currentGameSession = updatedSession
    }
    
    /// Joins an existing game session as a spectator
    func spectateGameSession(_ session: GameSession) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GameServiceError.notAuthenticated
        }
        
        var updatedSession = session
        
        let spectator = GameParticipant(
            userId: currentUser.uid,
            userName: currentUser.displayName ?? "Unknown"
        )
        
        guard updatedSession.addSpectator(spectator) else {
            throw GameServiceError.spectatorsFull
        }
        
        // Update in Firestore
        try await db.collection("gameSessions").document(session.id).setData(from: updatedSession)
        
        currentGameSession = updatedSession
    }
    
    /// Leaves the current game session
    func leaveGameSession() async throws {
        guard let session = currentGameSession,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        var updatedSession = session
        updatedSession.removePlayer(userId: currentUser.uid)
        updatedSession.removeSpectator(userId: currentUser.uid)
        
        // Update in Firestore
        try await db.collection("gameSessions").document(session.id).setData(from: updatedSession)
        
        currentGameSession = nil
    }
    
    /// Starts a game session (host only)
    func startGameSession(_ session: GameSession) async throws {
        guard let currentUser = Auth.auth().currentUser,
              session.topicChat.hostId == currentUser.uid else {
            throw GameServiceError.notAuthorized
        }
        
        var updatedSession = session
        guard updatedSession.canStartGame else {
            throw GameServiceError.notEnoughPlayers
        }
        
        updatedSession.startGame()
        
        // Update in Firestore
        try await db.collection("gameSessions").document(session.id).setData(from: updatedSession)
        
        currentGameSession = updatedSession
    }
    
    // MARK: - Game Discovery
    
    /// Fetches available games for the current user
    func fetchAvailableGames() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("gameSessions")
                .whereField("gameStatus", isEqualTo: GameStatus.waiting.rawValue)
                .order(by: "lastActivity", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            let games = snapshot.documents.compactMap { doc in
                GameSession.fromFirestore(doc)
            }
            
            availableGames = games
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Fetches games from friends
    func fetchFriendsGames() async {
        // TODO: Implement friend system integration
        // For now, return empty array
        friendsGames = []
    }
    
    /// Fetches trending games (most spectators)
    func fetchTrendingGames() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("gameSessions")
                .whereField("gameStatus", isEqualTo: GameStatus.inProgress.rawValue)
                .order(by: "spectatorCount", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            let games = snapshot.documents.compactMap { doc in
                GameSession.fromFirestore(doc)
            }
            
            trendingGames = games
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: - Matchmaking
    
    /// Joins the matchmaking queue for a specific game type
    func joinQueue(gameType: GameType, group: PlayerGroup? = nil) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GameServiceError.notAuthenticated
        }
        
        // Leave current queue if in one
        if currentQueue != nil {
            try await leaveQueue()
        }
        
        // Find or create queue for this game type
        let queueId = "queue_\(gameType.rawValue)"
        let queueRef = db.collection("gameQueues").document(queueId)
        
        let participant = QueueParticipant(
            userId: currentUser.uid,
            userName: currentUser.displayName ?? "Unknown",
            groupId: group?.id
        )
        
        try await db.runTransaction { transaction, errorPointer in
            let queueDoc: DocumentSnapshot
            do {
                queueDoc = try transaction.getDocument(queueRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return
            }
            
            var queue: GameQueue
            if queueDoc.exists {
                queue = try! queueDoc.data(as: GameQueue.self)
            } else {
                queue = GameQueue(gameType: gameType)
            }
            
            // Add participant to queue
            queue.participants.append(participant)
            
            // Add group if provided
            if let group = group, !queue.groups.contains(group.id) {
                queue.groups.append(group.id)
            }
            
            // Try to create a match if enough players
            if queue.canStartGame && queue.gameType.maxPlayers <= queue.totalParticipants {
                // Trigger matchmaking process
                Task {
                    await self.processMatchmaking(for: queue)
                }
            }
            
            do {
                try transaction.setData(from: queue, forDocument: queueRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
            }
            return
        }
        
        // Start listening to queue updates
        startListeningToQueue(queueId: queueId)
    }
    
    /// Leaves the current matchmaking queue
    func leaveQueue() async throws {
        guard let queue = currentQueue,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let queueRef = db.collection("gameQueues").document(queue.id)
        
        try await db.runTransaction { transaction, errorPointer in
            let queueDoc: DocumentSnapshot
            do {
                queueDoc = try transaction.getDocument(queueRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return
            }
            
            guard var updatedQueue = try? queueDoc.data(as: GameQueue.self) else {
                return
            }
            
            // Remove participant from queue
            updatedQueue.participants.removeAll { $0.userId == currentUser.uid }
            
            do {
                try transaction.setData(from: updatedQueue, forDocument: queueRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
            }
            return
        }
        
        currentQueue = nil
        stopListeningToQueue()
    }
    
    // MARK: - Friend Group Management
    
    /// Creates a new player group for matchmaking
    func createPlayerGroup(gameType: GameType) async throws -> PlayerGroup {
        guard let currentUser = Auth.auth().currentUser else {
            throw GameServiceError.notAuthenticated
        }
        
        let group = PlayerGroup(leaderId: currentUser.uid, gameType: gameType)
        
        // Save to Firestore
        try await db.collection("playerGroups").document(group.id).setData(from: group)
        
        currentPlayerGroup = group
        return group
    }
    
    /// Invites a friend to join the current player group
    func inviteFriendToGroup(_ friendId: String, friendName: String) async throws {
        guard let group = currentPlayerGroup,
              let currentUser = Auth.auth().currentUser else {
            throw GameServiceError.invalidGameState
        }
        
        // Check if user is the group leader
        guard group.leaderId == currentUser.uid else {
            throw GameServiceError.notAuthorized
        }
        
        let invite = GroupInvite(
            groupId: group.id,
            fromUserId: currentUser.uid,
            fromUserName: currentUser.displayName ?? "Unknown",
            toUserId: friendId,
            toUserName: friendName,
            gameType: group.gameType
        )
        
        // Save invite to Firestore
        try await db.collection("groupInvites").document(invite.id).setData(from: invite)
        
        print("✅ GameService: Sent group invite to \(friendName)")
    }
    
    /// Accepts a group invite
    func acceptGroupInvite(_ invite: GroupInvite) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw GameServiceError.notAuthenticated
        }
        
        let groupRef = db.collection("playerGroups").document(invite.groupId)
        let inviteRef = db.collection("groupInvites").document(invite.id)
        
        try await db.runTransaction { transaction, errorPointer in
            let groupDoc: DocumentSnapshot
            do {
                groupDoc = try transaction.getDocument(groupRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return
            }
            
            guard var group = try? groupDoc.data(as: PlayerGroup.self) else {
                return
            }
            
            // Add user to group
            if !group.memberIds.contains(currentUser.uid) {
                group.memberIds.append(currentUser.uid)
            }
            
            do {
                try transaction.setData(from: group, forDocument: groupRef)
                // Delete the invite
                transaction.deleteDocument(inviteRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
            }
            return nil
        }
        
        // Update local state
        currentPlayerGroup = try await getPlayerGroup(invite.groupId)
        
        print("✅ GameService: Joined group \(invite.groupId)")
    }
    
    /// Declines a group invite
    func declineGroupInvite(_ invite: GroupInvite) async throws {
        try await db.collection("groupInvites").document(invite.id).delete()
        
        // Remove from local state
        groupInvites.removeAll { $0.id == invite.id }
    }
    
    /// Leaves the current player group
    func leavePlayerGroup() async throws {
        guard let group = currentPlayerGroup,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        let groupRef = db.collection("playerGroups").document(group.id)
        
        try await db.runTransaction { transaction, errorPointer in
            let groupDoc: DocumentSnapshot
            do {
                groupDoc = try transaction.getDocument(groupRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return
            }
            
            guard var updatedGroup = try? groupDoc.data(as: PlayerGroup.self) else {
                return
            }
            
            // Remove user from group
            updatedGroup.memberIds.removeAll { $0 == currentUser.uid }
            
            // If group is empty, delete it
            if updatedGroup.memberIds.isEmpty {
                transaction.deleteDocument(groupRef)
            } else {
                // If leader left, assign new leader
                if updatedGroup.leaderId == currentUser.uid && !updatedGroup.memberIds.isEmpty {
                    updatedGroup.leaderId = updatedGroup.memberIds.first!
                }
                
                do {
                    try transaction.setData(from: updatedGroup, forDocument: groupRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                }
            }
            return nil
        }
        
        currentPlayerGroup = nil
        print("✅ GameService: Left player group")
    }
    
    /// Fetches group invites for the current user
    func fetchGroupInvites() async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        do {
            let snapshot = try await db.collection("groupInvites")
                .whereField("toUserId", isEqualTo: currentUser.uid)
                .whereField("status", isEqualTo: GroupInviteStatus.pending.rawValue)
                .getDocuments()
            
            groupInvites = snapshot.documents.compactMap { doc in
                try? doc.data(as: GroupInvite.self)
            }
            
        } catch {
            print("❌ GameService: Error fetching group invites: \(error)")
        }
    }
    
    /// Gets a player group by ID
    private func getPlayerGroup(_ groupId: String) async throws -> PlayerGroup {
        let doc = try await db.collection("playerGroups").document(groupId).getDocument()
        guard let group = try? doc.data(as: PlayerGroup.self) else {
            throw GameServiceError.gameNotFound
        }
        return group
    }
    
    // MARK: - Matchmaking Logic
    
    /// Processes matchmaking for a specific queue
    private func processMatchmaking(for queue: GameQueue) async {
        do {
            let gameType = queue.gameType
            let requiredPlayers = gameType.maxPlayers
            
            // Get groups for this queue
            let groups = await getGroupsForQueue(queue)
            
            // Create matches using smart matching algorithm
            let matches = createMatches(
                participants: queue.participants,
                groups: groups,
                gameType: gameType,
                requiredPlayers: requiredPlayers
            )
            
            // Create game sessions for each match
            for match in matches {
                await createGameSessionFromMatch(match, queueId: queue.id)
            }
            
        } catch {
            print("❌ GameService: Error processing matchmaking: \(error)")
        }
    }
    
    /// Creates optimal matches from participants and groups
    private func createMatches(
        participants: [QueueParticipant],
        groups: [PlayerGroup],
        gameType: GameType,
        requiredPlayers: Int
    ) -> [GameMatch] {
        var matches: [GameMatch] = []
        var usedParticipants = Set<String>()
        var usedGroups = Set<String>()
        
        // Priority 1: Complete groups that can fill a game
        for group in groups {
            if group.memberIds.count == requiredPlayers && !usedGroups.contains(group.id) {
                let groupParticipants = group.memberIds.compactMap { id in
                    participants.first { $0.userId == id }
                }
                
                if groupParticipants.count == requiredPlayers {
                    let match = GameMatch(
                        gameType: gameType,
                        participants: groupParticipants,
                        groups: [group],
                        matchType: .completeGroup
                    )
                    matches.append(match)
                    usedGroups.insert(group.id)
                    group.memberIds.forEach { usedParticipants.insert($0) }
                }
            }
        }
        
        // Priority 2: Groups + individual players
        for group in groups {
            if !usedGroups.contains(group.id) {
                let groupSize = group.memberIds.count
                let neededPlayers = requiredPlayers - groupSize
                
                if neededPlayers > 0 {
                    let groupParticipants = group.memberIds.compactMap { id in
                        participants.first { $0.userId == id }
                    }
                    
                    let availableIndividuals = participants.filter { participant in
                        !usedParticipants.contains(participant.userId) &&
                        participant.groupId == nil
                    }
                    
                    if availableIndividuals.count >= neededPlayers && groupParticipants.count == groupSize {
                        let selectedIndividuals = Array(availableIndividuals.prefix(neededPlayers))
                        let match = GameMatch(
                            gameType: gameType,
                            participants: groupParticipants + selectedIndividuals,
                            groups: [group],
                            matchType: .groupPlusIndividuals
                        )
                        matches.append(match)
                        usedGroups.insert(group.id)
                        group.memberIds.forEach { usedParticipants.insert($0) }
                        selectedIndividuals.forEach { usedParticipants.insert($0.userId) }
                    }
                }
            }
        }
        
        // Priority 3: Individual players only
        let remainingIndividuals = participants.filter { participant in
            !usedParticipants.contains(participant.userId) &&
            participant.groupId == nil
        }
        
        var individualsArray = Array(remainingIndividuals)
        while individualsArray.count >= requiredPlayers {
            let selectedPlayers = Array(individualsArray.prefix(requiredPlayers))
            let match = GameMatch(
                gameType: gameType,
                participants: selectedPlayers,
                groups: [],
                matchType: .individualsOnly
            )
            matches.append(match)
            selectedPlayers.forEach { usedParticipants.insert($0.userId) }
            individualsArray.removeFirst(requiredPlayers)
        }
        
        return matches
    }
    
    /// Creates a game session from a successful match
    private func createGameSessionFromMatch(_ match: GameMatch, queueId: String) async {
        do {
            // Create game session
            let gameSession = GameSession.createNew(
                title: generateGameTitle(for: match),
                gameType: match.gameType,
                hostId: match.participants.first!.userId,
                hostName: match.participants.first!.userName,
                config: nil
            )
            
            // Add all participants to the game
            var updatedSession = gameSession
            for participant in match.participants {
                let gameParticipant = GameParticipant(
                    userId: participant.userId,
                    userName: participant.userName
                )
                _ = updatedSession.addPlayer(gameParticipant)
            }
            
            // Save to Firestore
            try await db.collection("gameSessions").document(updatedSession.id).setData(from: updatedSession)
            
            // Remove participants from queue
            await removeParticipantsFromQueue(match.participants, queueId: queueId)
            
            print("✅ GameService: Created game session \(updatedSession.id) with \(match.participants.count) players")
            
        } catch {
            print("❌ GameService: Error creating game session: \(error)")
        }
    }
    
    /// Removes matched participants from the queue
    private func removeParticipantsFromQueue(_ participants: [QueueParticipant], queueId: String) async {
        do {
            let queueRef = db.collection("gameQueues").document(queueId)
            
            try await db.runTransaction { transaction, errorPointer in
                let queueDoc: DocumentSnapshot
                do {
                    queueDoc = try transaction.getDocument(queueRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return
                }
                
                guard var updatedQueue = try? queueDoc.data(as: GameQueue.self) else {
                    return
                }
                
                // Remove matched participants
                let participantIds = Set(participants.map { $0.userId })
                updatedQueue.participants.removeAll { participantIds.contains($0.userId) }
                
                // Remove empty groups
                updatedQueue.groups.removeAll { groupId in
                    !updatedQueue.participants.contains { $0.groupId == groupId }
                }
                
                do {
                    try transaction.setData(from: updatedQueue, forDocument: queueRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                }
                return
            }
            
        } catch {
            print("❌ GameService: Error removing participants from queue: \(error)")
        }
    }
    
    /// Gets all groups for a specific queue
    private func getGroupsForQueue(_ queue: GameQueue) async -> [PlayerGroup] {
        guard !queue.groups.isEmpty else { return [] }
        
        do {
            let groupsSnapshot = try await db.collection("playerGroups")
                .whereField(FieldPath.documentID(), in: queue.groups)
                .getDocuments()
            
            return groupsSnapshot.documents.compactMap { doc in
                try? doc.data(as: PlayerGroup.self)
            }
            
        } catch {
            print("❌ GameService: Error fetching groups: \(error)")
            return []
        }
    }
    
    /// Generates a title for the game session
    private func generateGameTitle(for match: GameMatch) -> String {
        switch match.matchType {
        case .completeGroup:
            return "\(match.gameType.displayName) - Group Game"
        case .groupPlusIndividuals:
            return "\(match.gameType.displayName) - Mixed Game"
        case .individualsOnly:
            return "\(match.gameType.displayName) - Random Match"
        }
    }
    
    // MARK: - Real-time Listeners
    
    private func setupListeners() {
        // Listen for current game session updates
        $currentGameSession
            .compactMap { $0?.id }
            .removeDuplicates()
            .sink { [weak self] sessionId in
                self?.startListeningToGameSession(sessionId: sessionId)
            }
            .store(in: &cancellables)
    }
    
    private func startListeningToGameSession(sessionId: String) {
        let listener = db.collection("gameSessions").document(sessionId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = error
                    return
                }
                
                guard let snapshot = snapshot,
                      let session = GameSession.fromFirestore(snapshot) else {
                    return
                }
                
                Task { @MainActor in
                    self?.currentGameSession = session
                }
            }
        
        listeners["currentSession"] = listener
    }
    
    private func startListeningToQueue(queueId: String) {
        let listener = db.collection("gameQueues").document(queueId)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = error
                    return
                }
                
                guard let snapshot = snapshot,
                      let queue = try? snapshot.data(as: GameQueue.self) else {
                    return
                }
                
                Task { @MainActor in
                    self?.currentQueue = queue
                    self?.updateQueuePosition()
                }
            }
        
        listeners["queue"] = listener
    }
    
    private func stopListeningToQueue() {
        listeners["queue"]?.remove()
        listeners.removeValue(forKey: "queue")
    }
    
    private func updateQueuePosition() {
        guard let queue = currentQueue,
              let currentUser = Auth.auth().currentUser,
              let participantIndex = queue.participants.firstIndex(where: { $0.userId == currentUser.uid }) else {
            queuePosition = 0
            return
        }
        
        queuePosition = participantIndex + 1
        
        // Estimate wait time based on position and average game duration
        let averageGameDuration: TimeInterval = 600 // 10 minutes
        let playersNeeded = queue.gameType.maxPlayers
        let gamesAhead = participantIndex / playersNeeded
        estimatedWaitTime = TimeInterval(gamesAhead) * averageGameDuration
    }
    
    private func removeAllListeners() {
        for listener in listeners.values {
            listener.remove()
        }
        listeners.removeAll()
    }
}

// MARK: - Game Service Errors

enum GameServiceError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case gameFull
    case spectatorsFull
    case notEnoughPlayers
    case gameNotFound
    case alreadyInGame
    case invalidGameState
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .notAuthorized:
            return "Not authorized to perform this action"
        case .gameFull:
            return "Game is full"
        case .spectatorsFull:
            return "Maximum spectators reached"
        case .notEnoughPlayers:
            return "Not enough players to start game"
        case .gameNotFound:
            return "Game session not found"
        case .alreadyInGame:
            return "Already in a game session"
        case .invalidGameState:
            return "Invalid game state"
        }
    }
}
