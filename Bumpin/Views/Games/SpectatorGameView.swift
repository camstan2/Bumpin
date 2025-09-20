import SwiftUI

struct SpectatorGameView: View {
    let gameSession: GameSession
    let onLeaveSpectating: () -> Void
    
    @StateObject private var imposterManager = ImposterGameManager()
    @StateObject private var gameService = GameService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLeaveAlert = false
    @State private var spectatorCount = 0
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.05), Color.blue.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Spectator Header
                spectatorHeader
                
                // Game Content
                gameContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            imposterManager.initializeGame(session: gameSession)
            Task {
                await joinAsSpectator()
            }
        }
        .onDisappear {
            imposterManager.cleanup()
            Task {
                await leaveSpectating()
            }
        }
        .alert("Leave Spectating", isPresented: $showingLeaveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                onLeaveSpectating()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to stop watching this game?")
        }
    }
    
    private var spectatorHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Leave") {
                    showingLeaveAlert = true
                }
                .foregroundColor(.red)
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.orange)
                        
                        Text("Spectating")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(gameSession.gameType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Spectator Count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(spectatorCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal)
            
            // Game Info Banner
            SpectatorGameInfoBanner(gameSession: gameSession)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var gameContent: some View {
        if gameSession.gameType == .imposter {
            SpectatorImposterView(
                gameState: imposterManager.gameState,
                gameParticipants: gameSession.gameParticipants,
                currentPhase: imposterManager.currentPhase,
                timeRemaining: imposterManager.timeRemaining,
                votingResults: imposterManager.votingResults
            )
        } else {
            // Placeholder for other game types
            VStack(spacing: 20) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Spectating \(gameSession.gameType.displayName)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Game in progress...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func joinAsSpectator() async {
        do {
            try await gameService.spectateGameSession(gameSession)
            spectatorCount = gameSession.spectatorCount + 1
        } catch {
            print("❌ Error joining as spectator: \(error)")
        }
    }
    
    private func leaveSpectating() async {
        do {
            try await gameService.leaveGameSession()
        } catch {
            print("❌ Error leaving spectator mode: \(error)")
        }
    }
}

// MARK: - Spectator Game Info Banner

struct SpectatorGameInfoBanner: View {
    let gameSession: GameSession
    
    var body: some View {
        HStack(spacing: 16) {
            // Game Type Icon
            VStack(spacing: 4) {
                Image(systemName: gameSession.gameType.iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(gameSession.gameType.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 40)
            
            // Players Count
            VStack(spacing: 4) {
                Text("\(gameSession.activePlayerCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("Players")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 40)
            
            // Game Duration
            VStack(spacing: 4) {
                if let duration = gameSession.gameDuration {
                    Text(formatDuration(duration))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                } else {
                    Text("--:--")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
                
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Host Info
            VStack(alignment: .trailing, spacing: 4) {
                Text("Host")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(gameSession.topicChat.hostName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Spectator Imposter View

struct SpectatorImposterView: View {
    let gameState: ImposterGameState?
    let gameParticipants: [GameParticipant]
    let currentPhase: ImposterGamePhase
    let timeRemaining: TimeInterval
    let votingResults: VotingResults?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Phase Indicator
                SpectatorPhaseIndicator(
                    currentPhase: currentPhase,
                    timeRemaining: timeRemaining
                )
                .padding(.horizontal)
                
                // Phase-specific content
                switch currentPhase {
                case .wordAssignment:
                    SpectatorWordAssignmentView()
                    
                case .speaking:
                    SpectatorSpeakingView(
                        gameState: gameState,
                        gameParticipants: gameParticipants
                    )
                    
                case .voting:
                    SpectatorVotingView(
                        gameState: gameState,
                        gameParticipants: gameParticipants
                    )
                    
                case .results, .gameOver:
                    SpectatorResultsView(
                        results: votingResults,
                        gameState: gameState
                    )
                }
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Spectator Phase Indicator

struct SpectatorPhaseIndicator: View {
    let currentPhase: ImposterGamePhase
    let timeRemaining: TimeInterval
    
    private let phases: [ImposterGamePhase] = [.wordAssignment, .speaking, .voting, .results]
    
    var body: some View {
        VStack(spacing: 12) {
            // Phase Progress
            HStack(spacing: 8) {
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(phase == currentPhase ? Color.orange : 
                                  index < currentPhaseIndex ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                        
                        Text(phase.displayName)
                            .font(.caption)
                            .fontWeight(phase == currentPhase ? .semibold : .regular)
                            .foregroundColor(phase == currentPhase ? .orange : .secondary)
                        
                        if index < phases.count - 1 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            // Timer
            if timeRemaining > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text(formatTime(timeRemaining))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var currentPhaseIndex: Int {
        return phases.firstIndex(of: currentPhase) ?? 0
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Spectator Word Assignment View

struct SpectatorWordAssignmentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Players are receiving their roles")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("One player is the imposter, the others know the secret word")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Spectator Speaking View

struct SpectatorSpeakingView: View {
    let gameState: ImposterGameState?
    let gameParticipants: [GameParticipant]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Players Taking Turns")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            // Current Speaker
            if let state = gameState,
               let currentSpeaker = getCurrentSpeaker(state) {
                CurrentSpeakerCard(participant: currentSpeaker)
                    .padding(.horizontal)
            }
            
            // Round Info
            if let state = gameState {
                HStack {
                    Text("Round \(state.currentRound) of \(state.maxRounds)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(state.spokenWords.count) words spoken")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Spoken Words History
            if let state = gameState, !state.spokenWords.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Words")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(state.spokenWords.suffix(5).reversed(), id: \.id) { spokenWord in
                            SpectatorSpokenWordRow(spokenWord: spokenWord)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func getCurrentSpeaker(_ state: ImposterGameState) -> GameParticipant? {
        guard let currentSpeakerId = state.currentSpeakerId else { return nil }
        return gameParticipants.first { $0.userId == currentSpeakerId }
    }
}

// MARK: - Current Speaker Card

struct CurrentSpeakerCard: View {
    let participant: GameParticipant
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(participant.userName.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.userName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Currently speaking...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Spectator Spoken Word Row

struct SpectatorSpokenWordRow: View {
    let spokenWord: SpokenWord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(spokenWord.playerName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Round \(spokenWord.round)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(spokenWord.word)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Spectator Voting View

struct SpectatorVotingView: View {
    let gameState: ImposterGameState?
    let gameParticipants: [GameParticipant]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Players Are Voting")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            if let state = gameState {
                VStack(spacing: 12) {
                    Text("Who is the imposter?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Voting Progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("Votes Cast")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(state.votes.count) / \(gameParticipants.filter { $0.isActive }.count)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        ProgressView(value: Double(state.votes.count), total: Double(gameParticipants.filter { $0.isActive }.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    }
                    .padding(.horizontal)
                    
                    // Player List
                    LazyVStack(spacing: 8) {
                        ForEach(gameParticipants.filter { $0.isActive }, id: \.userId) { participant in
                            SpectatorVotingPlayerRow(
                                participant: participant,
                                hasVoted: state.votes.keys.contains(participant.userId)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Spectator Voting Player Row

struct SpectatorVotingPlayerRow: View {
    let participant: GameParticipant
    let hasVoted: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(participant.userName.prefix(1)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                )
            
            Text(participant.userName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            if hasVoted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Text("Voted")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                Text("Thinking...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Spectator Results View

struct SpectatorResultsView: View {
    let results: VotingResults?
    let gameState: ImposterGameState?
    
    var body: some View {
        VStack(spacing: 20) {
            if let results = results {
                // Winner Announcement
                VStack(spacing: 12) {
                    Image(systemName: results.wasImposterVotedOut ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(results.wasImposterVotedOut ? .green : .red)
                    
                    Text(results.wasImposterVotedOut ? "Word Holders Win!" : "Imposter Wins!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(results.wasImposterVotedOut ? .green : .red)
                    
                    if let word = gameState?.assignedWord {
                        VStack(spacing: 8) {
                            Text("The secret word was:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(word)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
                .background(
                    (results.wasImposterVotedOut ? Color.green : Color.red)
                        .opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                
                // Voting Results Summary
                if !results.voteCounts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Final Votes")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            ForEach(results.voteCounts.sorted { $0.value > $1.value }, id: \.key) { playerId, count in
                                SpectatorVoteResultRow(
                                    playerName: getPlayerName(playerId, from: results),
                                    voteCount: count,
                                    totalVotes: results.votingDetails.count,
                                    wasVotedOut: playerId == results.votedOutPlayerId
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private func getPlayerName(_ playerId: String, from results: VotingResults) -> String {
        return results.votingDetails.first { $0.votedForId == playerId }?.votedForName ?? "Unknown"
    }
}

// MARK: - Spectator Vote Result Row

struct SpectatorVoteResultRow: View {
    let playerName: String
    let voteCount: Int
    let totalVotes: Int
    let wasVotedOut: Bool
    
    var body: some View {
        HStack {
            Text(playerName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if wasVotedOut {
                Text("VOTED OUT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            Spacer()
            
            Text("\(voteCount) votes")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(wasVotedOut ? .red : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(wasVotedOut ? Color.red.opacity(0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SpectatorGameView(
        gameSession: GameSession.createNew(
            title: "Test Game",
            gameType: .imposter,
            hostId: "test",
            hostName: "Test Host"
        ),
        onLeaveSpectating: { }
    )
}
