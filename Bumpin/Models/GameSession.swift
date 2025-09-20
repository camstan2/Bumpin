import Foundation
import FirebaseFirestore

// MARK: - Game Session Model

struct GameSession: Identifiable, Codable {
    let id: String
    var topicChat: TopicChat  // Reuse existing discussion structure
    var gameType: GameType
    var gameConfig: GameConfig
    var gameStatus: GameStatus
    var gamePhase: GamePhase
    
    // Game participants (extends TopicChat participants)
    var gameParticipants: [GameParticipant]
    var spectators: [GameParticipant]
    var maxSpectators: Int
    
    // Game state and progression
    var gameData: [String: String] // Flexible storage for game-specific state
    var currentRound: Int
    var totalRounds: Int?
    var roundStartTime: Date?
    var roundEndTime: Date?
    
    // Game timing
    var gameStartTime: Date?
    var gameEndTime: Date?
    var lastActivity: Date
    
    // Results
    var winners: [String]? // User IDs of winners
    var gameResult: GameResult?
    
    // Trending and discovery
    var spectatorCount: Int
    var trendingScore: Double
    var isHighlighted: Bool // For celebrity/influencer games
    
    init(topicChat: TopicChat, gameType: GameType, config: GameConfig? = nil) {
        self.id = topicChat.id
        self.topicChat = topicChat
        self.gameType = gameType
        self.gameConfig = config ?? GameConfig(gameType: gameType)
        self.gameStatus = .waiting
        self.gamePhase = .lobby
        
        // Convert TopicChat participants to GameParticipants
        self.gameParticipants = topicChat.participants.map { participant in
            GameParticipant(
                userId: participant.id,
                userName: participant.name,
                profileImageUrl: participant.profileImageUrl,
                isHost: participant.isHost
            )
        }
        
        self.spectators = []
        self.maxSpectators = self.gameConfig.maxSpectators
        
        // Initialize game state
        self.gameData = [:]
        self.currentRound = 0
        self.totalRounds = nil
        self.roundStartTime = nil
        self.roundEndTime = nil
        
        // Initialize timing
        self.gameStartTime = nil
        self.gameEndTime = nil
        self.lastActivity = Date()
        
        // Initialize results
        self.winners = nil
        self.gameResult = nil
        
        // Initialize discovery metrics
        self.spectatorCount = 0
        self.trendingScore = 0.0
        self.isHighlighted = topicChat.isVerified
    }
    
    // MARK: - Computed Properties
    
    var totalParticipants: Int {
        return gameParticipants.count
    }
    
    var activePlayers: [GameParticipant] {
        return gameParticipants.filter { $0.isActive && $0.role == .player }
    }
    
    var activePlayerCount: Int {
        return activePlayers.count
    }
    
    var canStartGame: Bool {
        return activePlayerCount >= gameConfig.minPlayers && gameStatus == .waiting
    }
    
    var isFull: Bool {
        return activePlayerCount >= gameConfig.maxPlayers
    }
    
    var canAcceptSpectators: Bool {
        return gameConfig.allowSpectators && spectators.count < maxSpectators
    }
    
    var isGameActive: Bool {
        return gameStatus == .inProgress || gameStatus == .starting
    }
    
    var gameDuration: TimeInterval? {
        guard let startTime = gameStartTime else { return nil }
        let endTime = gameEndTime ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    var currentRoundDuration: TimeInterval? {
        guard let roundStart = roundStartTime else { return nil }
        let roundEnd = roundEndTime ?? Date()
        return roundEnd.timeIntervalSince(roundStart)
    }
    
    // MARK: - Game Management Methods
    
    mutating func addPlayer(_ participant: GameParticipant) -> Bool {
        guard !isFull else { return false }
        
        // Check if user is already in the game
        if gameParticipants.contains(where: { $0.userId == participant.userId }) {
            return false
        }
        
        gameParticipants.append(participant)
        lastActivity = Date()
        return true
    }
    
    mutating func removePlayer(userId: String) {
        if let index = gameParticipants.firstIndex(where: { $0.userId == userId }) {
            gameParticipants[index].isActive = false
            gameParticipants[index].leftAt = Date()
        }
        lastActivity = Date()
    }
    
    mutating func addSpectator(_ spectator: GameParticipant) -> Bool {
        guard canAcceptSpectators else { return false }
        
        // Check if user is already spectating
        if spectators.contains(where: { $0.userId == spectator.userId }) {
            return false
        }
        
        var spectatorParticipant = spectator
        spectatorParticipant.role = .spectator
        spectators.append(spectatorParticipant)
        spectatorCount = spectators.count
        lastActivity = Date()
        return true
    }
    
    mutating func removeSpectator(userId: String) {
        spectators.removeAll { $0.userId == userId }
        spectatorCount = spectators.count
        lastActivity = Date()
    }
    
    mutating func startGame() {
        guard canStartGame else { return }
        
        gameStatus = .starting
        gamePhase = .preparation
        gameStartTime = Date()
        lastActivity = Date()
    }
    
    mutating func startRound() {
        currentRound += 1
        roundStartTime = Date()
        gamePhase = .playing
        lastActivity = Date()
    }
    
    mutating func endRound() {
        roundEndTime = Date()
        lastActivity = Date()
    }
    
    mutating func endGame(winners: [String]? = nil) {
        gameStatus = .finished
        gamePhase = .gameOver
        gameEndTime = Date()
        self.winners = winners
        lastActivity = Date()
        
        // Create game result
        if let startTime = gameStartTime {
            gameResult = GameResult(
                gameSessionId: id,
                gameType: gameType,
                winners: winners ?? [],
                participants: gameParticipants,
                gameData: gameData,
                startTime: startTime
            )
        }
    }
    
    mutating func updateGameData(key: String, value: String) {
        gameData[key] = value
        lastActivity = Date()
    }
    
    mutating func updateTrendingScore() {
        // Calculate trending score based on spectators, activity, and game type popularity
        let spectatorScore = min(50.0, Double(spectatorCount) * 2.0)
        let activityScore = max(0.0, 30.0 * exp(-lastActivity.timeIntervalSinceNow / 3600.0))
        let gameTypeScore = gameType == .imposter ? 20.0 : 10.0 // Boost popular games
        let highlightBonus = isHighlighted ? 25.0 : 0.0
        
        trendingScore = spectatorScore + activityScore + gameTypeScore + highlightBonus
    }
}

// MARK: - Game Session Extensions

extension GameSession {
    
    /// Creates a GameSession from an existing TopicChat
    static func fromTopicChat(_ topicChat: TopicChat, gameType: GameType, config: GameConfig? = nil) -> GameSession {
        return GameSession(topicChat: topicChat, gameType: gameType, config: config)
    }
    
    /// Creates a new GameSession for a specific game type
    static func createNew(title: String, gameType: GameType, hostId: String, hostName: String, config: GameConfig? = nil) -> GameSession {
        let topicChat = TopicChat(
            title: title,
            description: "Playing \(gameType.displayName)",
            category: .gaming, // Use gaming category for game sessions
            hostId: hostId,
            hostName: hostName
        )
        
        return GameSession(topicChat: topicChat, gameType: gameType, config: config)
    }
    
    /// Converts GameSession back to TopicChat for compatibility
    var asTopicChat: TopicChat {
        var updatedChat = topicChat
        updatedChat.title = "\(gameType.displayName): \(topicChat.title)"
        updatedChat.description = "Game in progress - \(gameStatus.rawValue)"
        updatedChat.participants = gameParticipants.map { gameParticipant in
            TopicParticipant(
                id: gameParticipant.userId,
                name: gameParticipant.userName,
                profileImageUrl: gameParticipant.profileImageUrl,
                isHost: gameParticipant.isHost
            )
        }
        updatedChat.isActive = isGameActive
        return updatedChat
    }
}

// MARK: - Firestore Extensions

extension GameSession {
    
    /// Creates a GameSession from Firestore document
    static func fromFirestore(_ document: DocumentSnapshot) -> GameSession? {
        return try? document.data(as: GameSession.self)
    }
    
    /// Converts GameSession to Firestore data
    func toFirestore() -> [String: Any] {
        do {
            let data = try Firestore.Encoder().encode(self)
            return data
        } catch {
            print("Error encoding GameSession: \(error)")
            return [:]
        }
    }
}
