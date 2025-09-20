import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Imposter Game Manager
// Manages the specific logic for the Imposter game

@MainActor
class ImposterGameManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var gameState: ImposterGameState?
    @Published var currentPhase: ImposterGamePhase = .wordAssignment
    @Published var timeRemaining: TimeInterval = 0
    @Published var canSpeak = false
    @Published var canVote = false
    @Published var hasVoted = false
    @Published var myRole: ImposterRole?
    @Published var assignedWord: String?
    @Published var votingResults: VotingResults?
    @Published var isGameOver = false
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var gameSession: GameSession?
    private var phaseTimer: Timer?
    private var gameListener: ListenerRegistration?
    
    // MARK: - Game Initialization
    
    func initializeGame(session: GameSession) {
        self.gameSession = session
        setupGameListener()
        
        // Initialize game state if host
        if isHost {
            Task {
                await setupNewGame()
            }
        }
    }
    
    func cleanup() {
        phaseTimer?.invalidate()
        gameListener?.remove()
        gameState = nil
        resetState()
    }
    
    // MARK: - Game Setup (Host Only)
    
    private func setupNewGame() async {
        guard let session = gameSession, isHost else { return }
        
        let activePlayers = session.activePlayers
        guard activePlayers.count >= 3 else { return }
        
        // Randomly select imposter
        let imposterPlayer = activePlayers.randomElement()!
        
        // Get random word
        let wordCategory: ImposterWordCategory = .random
        let assignedWord = ImposterWordBank.shared.getRandomWord(from: wordCategory)
        
        // Create game state
        let playerIds = activePlayers.map { $0.userId }
        let newGameState = ImposterGameState(
            players: playerIds,
            imposterPlayerId: imposterPlayer.userId,
            assignedWord: assignedWord
        )
        
        // Save game state to session
        var updatedSession = session
        updatedSession.gamePhase = .preparation
        updatedSession.updateGameData(key: "imposterGameState", value: encodeGameState(newGameState))
        
        do {
            try await db.collection("gameSessions").document(session.id).setData(from: updatedSession)
            print("✅ Imposter game initialized")
        } catch {
            print("❌ Error initializing game: \(error)")
        }
    }
    
    // MARK: - Game Phase Management
    
    func startWordAssignmentPhase() async {
        guard isHost, var state = gameState else { return }
        
        state.gamePhase = .wordAssignment
        state.phaseStartTime = Date()
        state.phaseTimeLimit = 30 // 30 seconds to read word/role
        
        await updateGameState(state)
        startPhaseTimer(duration: 30) {
            Task { await self.startSpeakingPhase() }
        }
    }
    
    func startSpeakingPhase() async {
        guard isHost, var state = gameState else { return }
        
        state.gamePhase = .speaking
        state.phaseStartTime = Date()
        state.phaseTimeLimit = 300 // 5 minutes for speaking
        
        await updateGameState(state)
        startPhaseTimer(duration: 300) {
            Task { await self.startVotingPhase() }
        }
    }
    
    func startVotingPhase() async {
        guard isHost, var state = gameState else { return }
        
        state.gamePhase = .voting
        state.votingPhase = true
        state.phaseStartTime = Date()
        state.phaseTimeLimit = 60 // 1 minute for voting
        
        await updateGameState(state)
        startPhaseTimer(duration: 60) {
            Task { await self.calculateResults() }
        }
    }
    
    // MARK: - Game Actions
    
    func submitWord(_ word: String) async {
        guard let state = gameState,
              let session = gameSession,
              let currentUser = Auth.auth().currentUser,
              state.gamePhase == .speaking,
              state.currentSpeakerId == currentUser.uid else {
            return
        }
        
        let playerName = session.gameParticipants.first { $0.userId == currentUser.uid }?.userName ?? "Unknown"
        let spokenWord = SpokenWord(
            playerId: currentUser.uid,
            playerName: playerName,
            word: word,
            round: state.currentRound
        )
        
        var updatedState = state
        updatedState.spokenWords.append(spokenWord)
        
        // Move to next player
        let currentIndex = updatedState.speakingOrder.firstIndex(of: currentUser.uid) ?? 0
        let nextIndex = (currentIndex + 1) % updatedState.speakingOrder.count
        
        // Check if round is complete
        if nextIndex == 0 {
            // Round complete
            if updatedState.currentRound >= updatedState.maxRounds {
                // All rounds complete, move to voting
                await startVotingPhase()
                return
            } else {
                // Start next round
                updatedState.currentRound += 1
            }
        }
        
        updatedState.currentSpeakerId = updatedState.speakingOrder[nextIndex]
        await updateGameState(updatedState)
    }
    
    func submitVote(for playerId: String) async {
        guard var state = gameState,
              let currentUser = Auth.auth().currentUser,
              state.gamePhase == .voting,
              !state.votes.keys.contains(currentUser.uid) else {
            return
        }
        
        state.votes[currentUser.uid] = playerId
        await updateGameState(state)
        
        hasVoted = true
        
        // Check if all players have voted
        if let session = gameSession {
            let activePlayerCount = session.activePlayerCount
            if state.votes.count >= activePlayerCount {
                await calculateResults()
            }
        }
    }
    
    private func calculateResults() async {
        guard isHost,
              var state = gameState,
              let session = gameSession else { return }
        
        // Calculate voting results
        let results = VotingResults(
            votes: state.votes,
            imposterPlayerId: state.imposterPlayerId,
            allPlayers: session.gameParticipants
        )
        
        state.votingResults = results
        state.gamePhase = .results
        
        // End the game session
        var updatedSession = session
        updatedSession.endGame(winners: results.gameWinners.map { $0.playerId })
        
        do {
            // Update game state
            await updateGameState(state)
            
            // Update session
            try await db.collection("gameSessions").document(session.id).setData(from: updatedSession)
            
            print("✅ Game results calculated")
        } catch {
            print("❌ Error calculating results: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private var isHost: Bool {
        guard let session = gameSession,
              let currentUser = Auth.auth().currentUser else { return false }
        return session.topicChat.hostId == currentUser.uid
    }
    
    private var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    private func updateGameState(_ state: ImposterGameState) async {
        guard let session = gameSession else { return }
        
        var updatedSession = session
        updatedSession.updateGameData(key: "imposterGameState", value: encodeGameState(state))
        
        do {
            try await db.collection("gameSessions").document(session.id).setData(from: updatedSession)
        } catch {
            print("❌ Error updating game state: \(error)")
        }
    }
    
    private func setupGameListener() {
        guard let session = gameSession else { return }
        
        gameListener = db.collection("gameSessions").document(session.id)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Game listener error: \(error)")
                    return
                }
                
                guard let snapshot = snapshot,
                      let updatedSession = GameSession.fromFirestore(snapshot) else {
                    return
                }
                
                Task { @MainActor in
                    self?.gameSession = updatedSession
                    self?.processGameUpdate(updatedSession)
                }
            }
    }
    
    private func processGameUpdate(_ session: GameSession) {
        // Decode game state from session data
        if let stateData = session.gameData["imposterGameState"],
           let decodedState = decodeGameState(stateData) {
            gameState = decodedState
            updateUIState(decodedState)
        }
    }
    
    private func updateUIState(_ state: ImposterGameState) {
        currentPhase = state.gamePhase
        
        // Update user-specific state
        if let userId = currentUserId {
            myRole = userId == state.imposterPlayerId ? .imposter : .wordHolder
            assignedWord = myRole == .imposter ? nil : state.assignedWord
            canSpeak = state.currentSpeakerId == userId && state.gamePhase == .speaking
            canVote = state.gamePhase == .voting && !state.votes.keys.contains(userId)
            hasVoted = state.votes.keys.contains(userId)
        }
        
        votingResults = state.votingResults
        isGameOver = state.gamePhase == .results || state.gamePhase == .gameOver
        
        // Update timer
        updatePhaseTimer(state)
    }
    
    private func updatePhaseTimer(_ state: ImposterGameState) {
        guard let startTime = state.phaseStartTime,
              let timeLimit = state.phaseTimeLimit else {
            timeRemaining = 0
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        timeRemaining = max(0, timeLimit - elapsed)
    }
    
    private func startPhaseTimer(duration: TimeInterval, completion: @escaping () -> Void) {
        phaseTimer?.invalidate()
        
        timeRemaining = duration
        
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                self?.timeRemaining -= 1
                
                if self?.timeRemaining ?? 0 <= 0 {
                    timer.invalidate()
                    completion()
                }
            }
        }
    }
    
    private func resetState() {
        currentPhase = .wordAssignment
        timeRemaining = 0
        canSpeak = false
        canVote = false
        hasVoted = false
        myRole = nil
        assignedWord = nil
        votingResults = nil
        isGameOver = false
    }
    
    // MARK: - Encoding/Decoding Helpers
    
    private func encodeGameState(_ state: ImposterGameState) -> String {
        do {
            let data = try JSONEncoder().encode(state)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("❌ Error encoding game state: \(error)")
            return ""
        }
    }
    
    private func decodeGameState(_ stateString: String) -> ImposterGameState? {
        guard let data = stateString.data(using: .utf8) else { return nil }
        
        do {
            return try JSONDecoder().decode(ImposterGameState.self, from: data)
        } catch {
            print("❌ Error decoding game state: \(error)")
            return nil
        }
    }
}
