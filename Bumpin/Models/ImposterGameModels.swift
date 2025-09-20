import Foundation

// MARK: - Imposter Game Specific Models

enum ImposterGamePhase: String, Codable {
    case wordAssignment = "word_assignment"     // Assigning roles and words
    case speaking = "speaking"                  // Players take turns saying words
    case voting = "voting"                      // Players vote for who they think is the imposter
    case results = "results"                    // Show voting results
    case gameOver = "game_over"                // Final game results
}

enum ImposterRole: String, Codable {
    case imposter = "imposter"
    case wordHolder = "word_holder"
    
    var displayName: String {
        switch self {
        case .imposter:
            return "Imposter"
        case .wordHolder:
            return "Word Holder"
        }
    }
}

struct ImposterGameState: Codable {
    // Game progression
    var currentRound: Int
    var currentPlayerIndex: Int
    var maxRounds: Int
    
    // Role assignments
    var imposterPlayerId: String
    var playersWithWord: [String] // User IDs who know the word
    var assignedWord: String?
    
    // Speaking phase
    var spokenWords: [SpokenWord]
    var speakingOrder: [String] // User IDs in speaking order
    var currentSpeakerId: String?
    
    // Voting phase
    var votingPhase: Bool
    var votes: [String: String] // voter ID -> voted for ID
    var votingResults: VotingResults?
    
    // Game phase management
    var gamePhase: ImposterGamePhase
    var phaseStartTime: Date?
    var phaseTimeLimit: TimeInterval?
    
    // Game settings
    var allowDiscussion: Bool // Whether players can discuss before voting
    var discussionTimeLimit: TimeInterval?
    
    init(players: [String], imposterPlayerId: String, assignedWord: String) {
        self.currentRound = 1
        self.currentPlayerIndex = 0
        self.maxRounds = 3 // Default to 3 rounds of speaking
        
        self.imposterPlayerId = imposterPlayerId
        self.playersWithWord = players.filter { $0 != imposterPlayerId }
        self.assignedWord = assignedWord
        
        self.spokenWords = []
        self.speakingOrder = players.shuffled() // Randomize speaking order
        self.currentSpeakerId = speakingOrder.first
        
        self.votingPhase = false
        self.votes = [:]
        self.votingResults = nil
        
        self.gamePhase = .wordAssignment
        self.phaseStartTime = Date()
        self.phaseTimeLimit = 30 // 30 seconds to read assigned word/role
        
        self.allowDiscussion = true
        self.discussionTimeLimit = 60 // 1 minute discussion before voting
    }
}

struct SpokenWord: Identifiable, Codable {
    let id: String
    let playerId: String
    let playerName: String
    let word: String
    let spokenAt: Date
    let round: Int
    
    init(playerId: String, playerName: String, word: String, round: Int) {
        self.id = UUID().uuidString
        self.playerId = playerId
        self.playerName = playerName
        self.word = word
        self.spokenAt = Date()
        self.round = round
    }
}

struct VotingResults: Codable {
    let voteCounts: [String: Int] // player ID -> vote count
    let votedOutPlayerId: String? // Player with most votes (nil if tie)
    let wasImposterVotedOut: Bool
    let gameWinners: [GameWinner]
    let votingDetails: [VoteDetail]
    
    init(votes: [String: String], imposterPlayerId: String, allPlayers: [GameParticipant]) {
        // Count votes
        var counts: [String: Int] = [:]
        var details: [VoteDetail] = []
        
        for (voterId, votedForId) in votes {
            counts[votedForId, default: 0] += 1
            
            if let voter = allPlayers.first(where: { $0.userId == voterId }),
               let votedFor = allPlayers.first(where: { $0.userId == votedForId }) {
                details.append(VoteDetail(
                    voterName: voter.userName,
                    votedForName: votedFor.userName,
                    votedForId: votedForId
                ))
            }
        }
        
        self.voteCounts = counts
        self.votingDetails = details
        
        // Find player with most votes
        let maxVotes = counts.values.max() ?? 0
        let playersWithMaxVotes = counts.filter { $0.value == maxVotes }
        
        if playersWithMaxVotes.count == 1 {
            self.votedOutPlayerId = playersWithMaxVotes.first?.key
        } else {
            self.votedOutPlayerId = nil // Tie - no one voted out
        }
        
        // Determine if imposter was voted out
        self.wasImposterVotedOut = votedOutPlayerId == imposterPlayerId
        
        // Determine winners
        if wasImposterVotedOut {
            // Word holders win
            self.gameWinners = allPlayers
                .filter { $0.userId != imposterPlayerId }
                .map { GameWinner(playerId: $0.userId, playerName: $0.userName, role: .wordHolder) }
        } else {
            // Imposter wins
            self.gameWinners = [GameWinner(
                playerId: imposterPlayerId,
                playerName: allPlayers.first(where: { $0.userId == imposterPlayerId })?.userName ?? "Unknown",
                role: .imposter
            )]
        }
    }
}

struct VoteDetail: Codable {
    let voterName: String
    let votedForName: String
    let votedForId: String
}

struct GameWinner: Codable {
    let playerId: String
    let playerName: String
    let role: ImposterRole
}

// MARK: - Imposter Word Categories

enum ImposterWordCategory: String, CaseIterable, Codable {
    case celebrities = "celebrities"
    case movies = "movies"
    case animals = "animals"
    case food = "food"
    case places = "places"
    case objects = "objects"
    case professions = "professions"
    case sports = "sports"
    case brands = "brands"
    case random = "random"
    
    var displayName: String {
        switch self {
        case .celebrities: return "Celebrities"
        case .movies: return "Movies"
        case .animals: return "Animals"
        case .food: return "Food"
        case .places: return "Places"
        case .objects: return "Objects"
        case .professions: return "Professions"
        case .sports: return "Sports"
        case .brands: return "Brands"
        case .random: return "Random"
        }
    }
}

struct ImposterWordBank {
    static let shared = ImposterWordBank()
    private init() {}
    
    private let wordsByCategory: [ImposterWordCategory: [String]] = [
        .celebrities: [
            "Taylor Swift", "Elon Musk", "Oprah Winfrey", "Leonardo DiCaprio", "Beyoncé",
            "Tom Hanks", "Jennifer Lawrence", "Will Smith", "Lady Gaga", "Robert Downey Jr.",
            "Scarlett Johansson", "The Rock", "Ryan Reynolds", "Emma Stone", "Chris Hemsworth"
        ],
        .movies: [
            "Titanic", "Avatar", "The Avengers", "Star Wars", "Jurassic Park",
            "The Lion King", "Frozen", "Black Panther", "Spider-Man", "Harry Potter",
            "The Matrix", "Forrest Gump", "Inception", "The Dark Knight", "Toy Story"
        ],
        .animals: [
            "Elephant", "Penguin", "Giraffe", "Dolphin", "Tiger",
            "Koala", "Kangaroo", "Panda", "Lion", "Monkey",
            "Octopus", "Flamingo", "Sloth", "Cheetah", "Whale"
        ],
        .food: [
            "Pizza", "Sushi", "Tacos", "Ice Cream", "Chocolate",
            "Pasta", "Hamburger", "Popcorn", "Pancakes", "Donuts",
            "Avocado", "Ramen", "Cheese", "Bacon", "Coffee"
        ],
        .places: [
            "Paris", "Tokyo", "New York", "London", "Sydney",
            "Rome", "Dubai", "Las Vegas", "Hawaii", "Egypt",
            "Brazil", "Canada", "India", "Germany", "Mexico"
        ],
        .objects: [
            "Smartphone", "Guitar", "Bicycle", "Camera", "Sunglasses",
            "Umbrella", "Watch", "Headphones", "Laptop", "Backpack",
            "Sneakers", "Pillow", "Mirror", "Candle", "Book"
        ],
        .professions: [
            "Doctor", "Teacher", "Chef", "Pilot", "Artist",
            "Engineer", "Lawyer", "Nurse", "Firefighter", "Police Officer",
            "Musician", "Writer", "Photographer", "Designer", "Scientist"
        ],
        .sports: [
            "Basketball", "Soccer", "Tennis", "Swimming", "Golf",
            "Baseball", "Football", "Volleyball", "Hockey", "Boxing",
            "Skiing", "Surfing", "Cycling", "Running", "Yoga"
        ],
        .brands: [
            "Apple", "Nike", "McDonald's", "Coca-Cola", "Google",
            "Disney", "Netflix", "Amazon", "Spotify", "Instagram",
            "Tesla", "Starbucks", "Uber", "TikTok", "YouTube"
        ]
    ]
    
    func getRandomWord(from category: ImposterWordCategory = .random) -> String {
        if category == .random {
            let allCategories = ImposterWordCategory.allCases.filter { $0 != .random }
            let randomCategory = allCategories.randomElement() ?? .celebrities
            return getRandomWord(from: randomCategory)
        }
        
        let words = wordsByCategory[category] ?? wordsByCategory[.celebrities]!
        return words.randomElement() ?? "Unknown"
    }
    
    func getWords(from category: ImposterWordCategory, count: Int = 10) -> [String] {
        let words = wordsByCategory[category] ?? []
        return Array(words.shuffled().prefix(count))
    }
    
    func getAllCategories() -> [ImposterWordCategory] {
        return ImposterWordCategory.allCases.filter { $0 != .random }
    }
}

// MARK: - Imposter Game Configuration

struct ImposterGameConfig: Codable {
    let wordCategory: ImposterWordCategory
    let maxRounds: Int
    let speakingTimeLimit: TimeInterval
    let votingTimeLimit: TimeInterval
    let allowDiscussion: Bool
    let discussionTimeLimit: TimeInterval
    let revealWordAfterGame: Bool
    
    init(wordCategory: ImposterWordCategory = .random,
         maxRounds: Int = 3,
         speakingTimeLimit: TimeInterval = 300,
         votingTimeLimit: TimeInterval = 60,
         allowDiscussion: Bool = true,
         discussionTimeLimit: TimeInterval = 60,
         revealWordAfterGame: Bool = true) {
        
        self.wordCategory = wordCategory
        self.maxRounds = maxRounds
        self.speakingTimeLimit = speakingTimeLimit
        self.votingTimeLimit = votingTimeLimit
        self.allowDiscussion = allowDiscussion
        self.discussionTimeLimit = discussionTimeLimit
        self.revealWordAfterGame = revealWordAfterGame
    }
}
