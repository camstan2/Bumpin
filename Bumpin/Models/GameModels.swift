import Foundation
import FirebaseFirestore

// MARK: - Game Type Definitions

enum GameType: String, CaseIterable, Codable {
    case imposter = "imposter"
    // Future games can be added here
    // case wordAssociation = "word_association"
    // case trivia = "trivia"
    
    var displayName: String {
        switch self {
        case .imposter:
            return "Imposter"
        }
    }
    
    var description: String {
        switch self {
        case .imposter:
            return "Find the imposter among your group! Players describe a secret word while the imposter tries to blend in."
        }
    }
    
    var minPlayers: Int {
        switch self {
        case .imposter:
            return 3
        }
    }
    
    var maxPlayers: Int {
        switch self {
        case .imposter:
            return 8
        }
    }
    
    var supportsSpectators: Bool {
        switch self {
        case .imposter:
            return true
        }
    }
    
    var estimatedDuration: TimeInterval {
        switch self {
        case .imposter:
            return 600 // 10 minutes
        }
    }
    
    var iconName: String {
        switch self {
        case .imposter:
            return "person.fill.questionmark"
        }
    }
}

// MARK: - Game Configuration

struct GameConfig: Codable {
    let gameType: GameType
    let minPlayers: Int
    let maxPlayers: Int
    let roundTimeLimit: TimeInterval?
    let votingTimeLimit: TimeInterval?
    let allowSpectators: Bool
    let maxSpectators: Int
    let autoStartWhenFull: Bool
    
    init(gameType: GameType) {
        self.gameType = gameType
        self.minPlayers = gameType.minPlayers
        self.maxPlayers = gameType.maxPlayers
        self.allowSpectators = gameType.supportsSpectators
        self.maxSpectators = 50
        self.autoStartWhenFull = true
        
        // Game-specific configurations
        switch gameType {
        case .imposter:
            self.roundTimeLimit = 300 // 5 minutes for speaking rounds
            self.votingTimeLimit = 60 // 1 minute for voting
        }
    }
    
    // Custom configuration
    init(gameType: GameType, roundTimeLimit: TimeInterval?, votingTimeLimit: TimeInterval?, maxSpectators: Int = 50) {
        self.gameType = gameType
        self.minPlayers = gameType.minPlayers
        self.maxPlayers = gameType.maxPlayers
        self.roundTimeLimit = roundTimeLimit
        self.votingTimeLimit = votingTimeLimit
        self.allowSpectators = gameType.supportsSpectators
        self.maxSpectators = maxSpectators
        self.autoStartWhenFull = true
    }
}

// MARK: - Game State Management

enum GameStatus: String, Codable {
    case waiting = "waiting"           // Waiting for players
    case starting = "starting"         // Game is about to start
    case inProgress = "in_progress"    // Game is active
    case paused = "paused"            // Game is paused
    case finished = "finished"         // Game completed
    case cancelled = "cancelled"       // Game was cancelled
}

enum GamePhase: String, Codable {
    case lobby = "lobby"               // Pre-game lobby
    case preparation = "preparation"   // Setting up game (assigning roles, etc.)
    case playing = "playing"          // Main game phase
    case voting = "voting"            // Voting phase (if applicable)
    case results = "results"          // Showing results
    case gameOver = "game_over"       // Final results and cleanup
}

// MARK: - Player Group System

struct PlayerGroup: Identifiable, Codable {
    let id: String
    var leaderId: String
    var memberIds: [String]
    let gameType: GameType
    let createdAt: Date
    var inviteCode: String?
    
    init(leaderId: String, gameType: GameType) {
        self.id = UUID().uuidString
        self.leaderId = leaderId
        self.memberIds = [leaderId]
        self.gameType = gameType
        self.createdAt = Date()
        self.inviteCode = String(format: "%06d", Int.random(in: 100000...999999))
    }
    
    var memberCount: Int {
        return memberIds.count
    }
    
    var isLeader: Bool {
        return memberIds.first == leaderId
    }
}

// MARK: - Matchmaking Queue

enum GameQueueStatus: String, Codable {
    case active = "active"
    case matched = "matched"
    case cancelled = "cancelled"
    case expired = "expired"
}

struct QueueParticipant: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let groupId: String? // If part of a group
    let joinedAt: Date
    
    init(userId: String, userName: String, groupId: String? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userName = userName
        self.groupId = groupId
        self.joinedAt = Date()
    }
}

struct GameQueue: Identifiable, Codable {
    let id: String
    let gameType: GameType
    var participants: [QueueParticipant]
    var groups: [String] // Group IDs in this queue
    let createdAt: Date
    var status: GameQueueStatus
    var estimatedWaitTime: TimeInterval?
    
    init(gameType: GameType) {
        self.id = UUID().uuidString
        self.gameType = gameType
        self.participants = []
        self.groups = []
        self.createdAt = Date()
        self.status = .active
        self.estimatedWaitTime = nil
    }
    
    var totalParticipants: Int {
        return participants.count
    }
    
    var canStartGame: Bool {
        return totalParticipants >= gameType.minPlayers
    }
    
    var isFull: Bool {
        return totalParticipants >= gameType.maxPlayers
    }
}

// MARK: - Game Participant

struct GameParticipant: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let profileImageUrl: String?
    var role: GameRole
    var isHost: Bool
    var isActive: Bool
    var joinedAt: Date
    var leftAt: Date?
    
    init(userId: String, userName: String, profileImageUrl: String? = nil, isHost: Bool = false) {
        self.id = userId
        self.userId = userId
        self.userName = userName
        self.profileImageUrl = profileImageUrl
        self.role = .player
        self.isHost = isHost
        self.isActive = true
        self.joinedAt = Date()
        self.leftAt = nil
    }
}

enum GameRole: String, Codable {
    case player = "player"
    case spectator = "spectator"
    case host = "host"
}

// MARK: - Game Results

struct GameResult: Identifiable, Codable {
    let id: String
    let gameSessionId: String
    let gameType: GameType
    let winners: [String] // User IDs of winners
    let participants: [GameParticipant]
    let gameData: [String: String] // Game-specific result data
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    
    init(gameSessionId: String, gameType: GameType, winners: [String], participants: [GameParticipant], gameData: [String: String], startTime: Date) {
        self.id = UUID().uuidString
        self.gameSessionId = gameSessionId
        self.gameType = gameType
        self.winners = winners
        self.participants = participants
        self.gameData = gameData
        self.startTime = startTime
        self.endTime = Date()
        self.duration = Date().timeIntervalSince(startTime)
    }
}

// MARK: - Game Statistics

struct GameStats: Codable {
    let userId: String
    let gameType: GameType
    var gamesPlayed: Int
    var gamesWon: Int
    var totalPlayTime: TimeInterval
    var averageGameDuration: TimeInterval
    var lastPlayedAt: Date?
    
    init(userId: String, gameType: GameType) {
        self.userId = userId
        self.gameType = gameType
        self.gamesPlayed = 0
        self.gamesWon = 0
        self.totalPlayTime = 0
        self.averageGameDuration = 0
        self.lastPlayedAt = nil
    }
    
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(gamesWon) / Double(gamesPlayed)
    }
}

// MARK: - Group Invites

enum GroupInviteStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"
}

struct GroupInvite: Identifiable, Codable {
    let id: String
    let groupId: String
    let fromUserId: String
    let fromUserName: String
    let toUserId: String
    let toUserName: String
    let gameType: GameType
    let createdAt: Date
    var status: GroupInviteStatus
    let expiresAt: Date
    
    init(groupId: String, fromUserId: String, fromUserName: String, toUserId: String, toUserName: String, gameType: GameType) {
        self.id = UUID().uuidString
        self.groupId = groupId
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.toUserId = toUserId
        self.toUserName = toUserName
        self.gameType = gameType
        self.createdAt = Date()
        self.status = .pending
        self.expiresAt = Date().addingTimeInterval(24 * 60 * 60) // 24 hours
    }
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
}

// MARK: - Game Matches

enum GameMatchType: String, Codable, CaseIterable {
    case completeGroup = "complete_group"
    case groupPlusIndividuals = "group_plus_individuals"
    case individualsOnly = "individuals_only"
    
    var displayName: String {
        switch self {
        case .completeGroup:
            return "Complete Group"
        case .groupPlusIndividuals:
            return "Group + Individuals"
        case .individualsOnly:
            return "Random Match"
        }
    }
}

struct GameMatch: Identifiable, Codable {
    let id: String
    let gameType: GameType
    let participants: [QueueParticipant]
    let groups: [PlayerGroup]
    let matchType: GameMatchType
    let gameSessionId: String?
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        gameType: GameType,
        participants: [QueueParticipant],
        groups: [PlayerGroup],
        matchType: GameMatchType,
        gameSessionId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.gameType = gameType
        self.participants = participants
        self.groups = groups
        self.matchType = matchType
        self.gameSessionId = gameSessionId
        self.createdAt = createdAt
    }
}
