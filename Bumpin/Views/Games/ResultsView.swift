import SwiftUI

struct ResultsView: View {
    let results: VotingResults?
    let myRole: ImposterRole?
    let assignedWord: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Results Header
                if let results = results {
                    VStack(spacing: 16) {
                        // Winner Announcement
                        VStack(spacing: 12) {
                            Image(systemName: results.wasImposterVotedOut ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(results.wasImposterVotedOut ? .green : .red)
                            
                            Text(results.wasImposterVotedOut ? "Word Holders Win!" : "Imposter Wins!")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(results.wasImposterVotedOut ? .green : .red)
                            
                            Text(getResultDescription(results))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(
                            (results.wasImposterVotedOut ? Color.green : Color.red)
                                .opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Your Performance
                        YourPerformanceView(
                            myRole: myRole,
                            didWin: didPlayerWin(results),
                            assignedWord: assignedWord
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Voting Breakdown
                if let results = results {
                    VotingBreakdownView(results: results)
                        .padding(.horizontal)
                }
                
                // Winners List
                if let results = results {
                    WinnersListView(winners: results.gameWinners)
                        .padding(.horizontal)
                }
                
                // Word Reveal
                if let word = assignedWord {
                    WordRevealView(word: word)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
    }
    
    private func getResultDescription(_ results: VotingResults) -> String {
        if results.wasImposterVotedOut {
            if let votedOut = results.votedOutPlayerId,
               let votedOutPlayer = results.gameWinners.first(where: { _ in true }) {
                return "The imposter was successfully identified and voted out!"
            } else {
                return "The vote was tied, but the word holders still won!"
            }
        } else {
            return "The imposter successfully deceived everyone!"
        }
    }
    
    private func didPlayerWin(_ results: VotingResults) -> Bool {
        guard let myRole = myRole else { return false }
        
        if myRole == .imposter {
            return !results.wasImposterVotedOut
        } else {
            return results.wasImposterVotedOut
        }
    }
}

// MARK: - Your Performance View

struct YourPerformanceView: View {
    let myRole: ImposterRole?
    let didWin: Bool
    let assignedWord: String?
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Your Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // Role
                VStack(spacing: 6) {
                    Image(systemName: myRole == .imposter ? "person.fill.questionmark" : "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(myRole == .imposter ? .red : .blue)
                    
                    Text(myRole?.displayName ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Your Role")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 50)
                
                // Result
                VStack(spacing: 6) {
                    Image(systemName: didWin ? "trophy.fill" : "hand.thumbsdown.fill")
                        .font(.title2)
                        .foregroundColor(didWin ? .yellow : .gray)
                    
                    Text(didWin ? "You Won!" : "You Lost")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(didWin ? .green : .red)
                    
                    Text("Result")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let word = assignedWord {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 50)
                    
                    // Word
                    VStack(spacing: 6) {
                        Image(systemName: "textformat")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text(word)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Text("The Word")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Voting Breakdown View

struct VotingBreakdownView: View {
    let results: VotingResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voting Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(sortedVoteCounts, id: \.key) { playerId, count in
                    VotingResultRow(
                        playerId: playerId,
                        playerName: getPlayerName(playerId),
                        voteCount: count,
                        totalVotes: results.votingDetails.count,
                        wasVotedOut: playerId == results.votedOutPlayerId,
                        wasImposter: playerId == getImposterPlayerId()
                    )
                }
            }
            
            // Voting Details
            if !results.votingDetails.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vote Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(results.votingDetails.indices, id: \.self) { index in
                        let detail = results.votingDetails[index]
                        HStack {
                            Text("\(detail.voterName) voted for")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(detail.votedForName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var sortedVoteCounts: [(key: String, value: Int)] {
        return results.voteCounts.sorted { $0.value > $1.value }
    }
    
    private func getPlayerName(_ playerId: String) -> String {
        return results.votingDetails.first { $0.votedForId == playerId }?.votedForName ?? "Unknown"
    }
    
    private func getImposterPlayerId() -> String {
        // We need to get this from the game state - for now return empty
        return ""
    }
}

// MARK: - Voting Result Row

struct VotingResultRow: View {
    let playerId: String
    let playerName: String
    let voteCount: Int
    let totalVotes: Int
    let wasVotedOut: Bool
    let wasImposter: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(playerName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if wasImposter {
                        Text("IMPOSTER")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    if wasVotedOut {
                        Text("VOTED OUT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                // Vote Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        
                        Rectangle()
                            .fill(wasVotedOut ? Color.orange : Color.blue)
                            .frame(width: geometry.size.width * votePercentage, height: 6)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(voteCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(wasVotedOut ? .orange : .primary)
                
                Text("votes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var votePercentage: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(voteCount) / Double(totalVotes)
    }
}

// MARK: - Winners List View

struct WinnersListView: View {
    let winners: [GameWinner]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Winners")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(winners.indices, id: \.self) { index in
                    let winner = winners[index]
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundColor(.yellow)
                        
                        Text(winner.playerName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("(\(winner.role.displayName))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Word Reveal View

struct WordRevealView: View {
    let word: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("The Secret Word Was")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(word)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(.blue)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Game Over View

struct GameOverView: View {
    let results: VotingResults?
    let onNewGame: () -> Void
    let onLeaveGame: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Game Over!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Thanks for playing Imposter!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                Button("Play Again") {
                    onNewGame()
                }
                .buttonStyle(PrimaryGameButtonStyle())
                
                Button("Leave Game") {
                    onLeaveGame()
                }
                .buttonStyle(SecondaryGameButtonStyle())
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Additional Button Styles

struct SecondaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ResultsView(
        results: VotingResults(
            votes: ["1": "2", "2": "3", "3": "2"],
            imposterPlayerId: "2",
            allPlayers: [
                GameParticipant(userId: "1", userName: "Alice"),
                GameParticipant(userId: "2", userName: "Bob"),
                GameParticipant(userId: "3", userName: "Charlie")
            ]
        ),
        myRole: .wordHolder,
        assignedWord: "Pizza"
    )
}
