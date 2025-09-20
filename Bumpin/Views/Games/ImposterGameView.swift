import SwiftUI

struct ImposterGameView: View {
    let gameSession: GameSession
    let onGameEnd: () -> Void
    
    @StateObject private var imposterManager = ImposterGameManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Game Header
                gameHeader
                
                // Phase Content
                phaseContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            imposterManager.initializeGame(session: gameSession)
        }
        .onDisappear {
            imposterManager.cleanup()
        }
        .alert("Game Ended", isPresented: $imposterManager.isGameOver) {
            Button("OK") {
                onGameEnd()
                dismiss()
            }
        } message: {
            if let results = imposterManager.votingResults {
                Text(results.wasImposterVotedOut ? "Word holders win!" : "Imposter wins!")
            }
        }
    }
    
    private var gameHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Leave Game") {
                    dismiss()
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Text("Imposter")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Timer
                if imposterManager.timeRemaining > 0 {
                    Text(formatTime(imposterManager.timeRemaining))
                        .font(.headline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal)
            
            // Phase Indicator
            PhaseProgressView(currentPhase: imposterManager.currentPhase)
                .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var phaseContent: some View {
        switch imposterManager.currentPhase {
        case .wordAssignment:
            WordAssignmentView(
                role: imposterManager.myRole,
                assignedWord: imposterManager.assignedWord
            )
            
        case .speaking:
            SpeakingPhaseView(
                gameState: imposterManager.gameState,
                canSpeak: imposterManager.canSpeak,
                onWordSubmitted: { word in
                    Task {
                        await imposterManager.submitWord(word)
                    }
                }
            )
            
        case .voting:
            VotingPhaseView(
                gameState: imposterManager.gameState,
                gameParticipants: gameSession.gameParticipants,
                canVote: imposterManager.canVote,
                hasVoted: imposterManager.hasVoted,
                onVoteSubmitted: { playerId in
                    Task {
                        await imposterManager.submitVote(for: playerId)
                    }
                }
            )
            
        case .results:
            ResultsView(
                results: imposterManager.votingResults,
                myRole: imposterManager.myRole,
                assignedWord: imposterManager.assignedWord
            )
            
        case .gameOver:
            GameOverView(
                results: imposterManager.votingResults,
                onNewGame: {
                    // TODO: Implement new game functionality
                },
                onLeaveGame: {
                    onGameEnd()
                    dismiss()
                }
            )
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Phase Progress View

struct PhaseProgressView: View {
    let currentPhase: ImposterGamePhase
    
    private let phases: [ImposterGamePhase] = [.wordAssignment, .speaking, .voting, .results]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                HStack(spacing: 4) {
                    Circle()
                        .fill(phase == currentPhase ? Color.blue : 
                              index < currentPhaseIndex ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    Text(phase.displayName)
                        .font(.caption)
                        .fontWeight(phase == currentPhase ? .semibold : .regular)
                        .foregroundColor(phase == currentPhase ? .blue : .secondary)
                    
                    if index < phases.count - 1 {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    
    private var currentPhaseIndex: Int {
        return phases.firstIndex(of: currentPhase) ?? 0
    }
}

// MARK: - Word Assignment View

struct WordAssignmentView: View {
    let role: ImposterRole?
    let assignedWord: String?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Role Card
            VStack(spacing: 20) {
                Image(systemName: role == .imposter ? "person.fill.questionmark" : "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundColor(role == .imposter ? .red : .blue)
                
                Text("You are the \(role?.displayName ?? "Unknown")")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let word = assignedWord {
                    VStack(spacing: 12) {
                        Text("Your word is:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(word)
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("You don't know the word!")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("Listen carefully and try to blend in")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(30)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            Text("Memorize your role and get ready to play!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Speaking Phase View

struct SpeakingPhaseView: View {
    let gameState: ImposterGameState?
    let canSpeak: Bool
    let onWordSubmitted: (String) -> Void
    
    @State private var currentWord = ""
    @State private var showingWordInput = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Speaker Indicator
                if let state = gameState, let currentSpeaker = getCurrentSpeakerName(state) {
                    VStack(spacing: 8) {
                        Text("Current Speaker")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(currentSpeaker)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(canSpeak ? .blue : .primary)
                    }
                    .padding()
                    .background(canSpeak ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Round Indicator
                if let state = gameState {
                    Text("Round \(state.currentRound) of \(state.maxRounds)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Spoken Words History
                if let state = gameState, !state.spokenWords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Words Spoken")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(state.spokenWords.reversed(), id: \.id) { spokenWord in
                                SpokenWordRow(spokenWord: spokenWord)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Your Turn Button
                if canSpeak {
                    VStack(spacing: 16) {
                        Text("It's your turn!")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Button("Say a Word") {
                            showingWordInput = true
                        }
                        .buttonStyle(PrimaryGameButtonStyle())
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingWordInput) {
            WordInputView(
                currentWord: $currentWord,
                onSubmit: { word in
                    onWordSubmitted(word)
                    currentWord = ""
                    showingWordInput = false
                },
                onCancel: {
                    showingWordInput = false
                }
            )
        }
    }
    
    private func getCurrentSpeakerName(_ state: ImposterGameState) -> String? {
        // This would need access to participant names - we'll need to pass this in
        return state.currentSpeakerId
    }
}

// MARK: - Spoken Word Row

struct SpokenWordRow: View {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Word Input View

struct WordInputView: View {
    @Binding var currentWord: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Enter your word")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Say one word that describes or relates to the secret word")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                TextField("Your word", text: $currentWord)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title3)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                
                Button("Submit Word") {
                    if !currentWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSubmit(currentWord.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .buttonStyle(PrimaryGameButtonStyle())
                .disabled(currentWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Say a Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Button Styles

struct PrimaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension ImposterGamePhase {
    var displayName: String {
        switch self {
        case .wordAssignment:
            return "Setup"
        case .speaking:
            return "Speaking"
        case .voting:
            return "Voting"
        case .results:
            return "Results"
        case .gameOver:
            return "Game Over"
        }
    }
}

#Preview {
    ImposterGameView(
        gameSession: GameSession.createNew(
            title: "Test Game",
            gameType: .imposter,
            hostId: "test",
            hostName: "Test Host"
        ),
        onGameEnd: { }
    )
}
