import SwiftUI

struct VotingPhaseView: View {
    let gameState: ImposterGameState?
    let gameParticipants: [GameParticipant]
    let canVote: Bool
    let hasVoted: Bool
    let onVoteSubmitted: (String) -> Void
    
    @State private var selectedPlayerId: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Voting Header
                VStack(spacing: 12) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Time to Vote!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Who do you think is the imposter?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Voting Status
                if let state = gameState {
                    VotingStatusView(
                        totalPlayers: gameParticipants.filter { $0.isActive }.count,
                        votesSubmitted: state.votes.count,
                        hasVoted: hasVoted
                    )
                }
                
                // Player List for Voting
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select a Player")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 12) {
                        ForEach(activeGameParticipants, id: \.userId) { participant in
                            PlayerVoteCard(
                                participant: participant,
                                isSelected: selectedPlayerId == participant.userId,
                                canVote: canVote && !hasVoted,
                                spokenWords: getSpokenWords(for: participant.userId),
                                onTap: {
                                    if canVote && !hasVoted {
                                        selectedPlayerId = participant.userId
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Submit Vote Button
                if canVote && !hasVoted {
                    Button("Submit Vote") {
                        if let playerId = selectedPlayerId {
                            onVoteSubmitted(playerId)
                        }
                    }
                    .buttonStyle(VoteButtonStyle(isEnabled: selectedPlayerId != nil))
                    .disabled(selectedPlayerId == nil)
                    .padding(.horizontal)
                }
                
                // Already Voted Message
                if hasVoted {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        Text("Vote Submitted!")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("Waiting for other players...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
    }
    
    private var activeGameParticipants: [GameParticipant] {
        return gameParticipants.filter { $0.isActive && $0.role == .player }
    }
    
    private func getSpokenWords(for playerId: String) -> [SpokenWord] {
        return gameState?.spokenWords.filter { $0.playerId == playerId } ?? []
    }
}

// MARK: - Voting Status View

struct VotingStatusView: View {
    let totalPlayers: Int
    let votesSubmitted: Int
    let hasVoted: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(votesSubmitted)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("Votes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text("of")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(totalPlayers)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 4) {
                Image(systemName: hasVoted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(hasVoted ? .green : .gray)
                
                Text("You")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Player Vote Card

struct PlayerVoteCard: View {
    let participant: GameParticipant
    let isSelected: Bool
    let canVote: Bool
    let spokenWords: [SpokenWord]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Player Info
                HStack {
                    // Profile Image Placeholder
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(participant.userName.prefix(1)))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(participant.userName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if participant.isHost {
                            Text("Host")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    
                    Spacer()
                    
                    // Selection Indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    } else if canVote {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                
                // Spoken Words Summary
                if !spokenWords.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Words spoken:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            ForEach(spokenWords.prefix(3), id: \.id) { word in
                                Text(word.word)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            if spokenWords.count > 3 {
                                Text("+\(spokenWords.count - 3)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canVote)
        .opacity(canVote ? 1.0 : 0.6)
    }
}

// MARK: - Vote Button Style

struct VoteButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isEnabled ? 
                (configuration.isPressed ? Color.red.opacity(0.8) : Color.red) :
                Color.gray.opacity(0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VotingPhaseView(
        gameState: ImposterGameState(
            players: ["1", "2", "3"],
            imposterPlayerId: "1",
            assignedWord: "Pizza"
        ),
        gameParticipants: [
            GameParticipant(userId: "1", userName: "Alice", isHost: true),
            GameParticipant(userId: "2", userName: "Bob"),
            GameParticipant(userId: "3", userName: "Charlie")
        ],
        canVote: true,
        hasVoted: false,
        onVoteSubmitted: { _ in }
    )
}
