import SwiftUI
import FirebaseAuth

struct GameLobbyView: View {
    let gameSession: GameSession
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameService = GameService.shared
    @EnvironmentObject var discussionManager: DiscussionManager
    
    @State private var showingLeaveAlert = false
    @State private var isStarting = false
    @State private var showingGame = false
    
    private var isHost: Bool {
        guard let currentUser = Auth.auth().currentUser else { return false }
        return gameSession.topicChat.hostId == currentUser.uid
    }
    
    private var canStartGame: Bool {
        return isHost && gameSession.canStartGame && !isStarting
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                gameHeaderView
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Game Info Section
                        gameInfoSection
                        
                        // Players Section
                        playersSection
                        
                        // Spectators Section (if any)
                        if !gameSession.spectators.isEmpty {
                            spectatorsSection
                        }
                        
                        // Game Rules Section
                        gameRulesSection
                        
                        Spacer(minLength: 100) // Space for start button
                    }
                    .padding(.vertical)
                }
                
                // Bottom Actions
                bottomActionsView
            }
            .navigationTitle("Game Lobby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Leave") {
                        showingLeaveAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                if isHost {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Start Game") {
                            startGame()
                        }
                        .disabled(!canStartGame)
                        .fontWeight(.semibold)
                        .foregroundColor(canStartGame ? .purple : .secondary)
                    }
                }
            }
            .alert("Leave Game", isPresented: $showingLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    leaveGame()
                }
            } message: {
                Text("Are you sure you want to leave this game lobby?")
            }
        }
        .onReceive(gameService.$currentGameSession) { updatedSession in
            // Handle game state changes
            if let session = updatedSession, session.id == gameSession.id {
                if session.gameStatus == .starting || session.gameStatus == .inProgress {
                    // Game started, transition to game view
                    showingGame = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingGame) {
            if gameSession.gameType == .imposter {
                ImposterGameView(gameSession: gameSession) {
                    showingGame = false
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var gameHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: gameSession.gameType.iconName)
                    .font(.title)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gameSession.topicChat.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(gameSession.gameType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                gameStatusBadge
            }
            
            // Progress bar for player count
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(gameSession.activePlayerCount)/\(gameSession.gameConfig.maxPlayers)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                ProgressView(value: Double(gameSession.activePlayerCount), total: Double(gameSession.gameConfig.maxPlayers))
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                    .scaleEffect(y: 2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var gameStatusBadge: some View {
        Text(gameSession.gameStatus.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.2))
            .foregroundColor(.blue)
            .cornerRadius(4)
    }
    
    // MARK: - Content Sections
    
    private var gameInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Game Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 20) {
                infoTile(
                    icon: "clock.fill",
                    title: "Duration",
                    value: formatDuration(gameSession.gameType.estimatedDuration)
                )
                
                infoTile(
                    icon: "person.2.fill",
                    title: "Min Players",
                    value: "\(gameSession.gameConfig.minPlayers)"
                )
                
                infoTile(
                    icon: "person.3.fill",
                    title: "Max Players",
                    value: "\(gameSession.gameConfig.maxPlayers)"
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Players (\(gameSession.activePlayerCount))")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(gameSession.activePlayers, id: \.id) { player in
                    playerRow(player)
                }
                
                // Show empty slots
                ForEach(0..<(gameSession.gameConfig.maxPlayers - gameSession.activePlayerCount), id: \.self) { _ in
                    emptyPlayerSlot
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var spectatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spectators (\(gameSession.spectators.count))")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(gameSession.spectators, id: \.id) { spectator in
                    spectatorRow(spectator)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var gameRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("How to Play")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if gameSession.gameType == .imposter {
                    ruleItem(number: 1, text: "One player is secretly the imposter")
                    ruleItem(number: 2, text: "Other players receive a secret word")
                    ruleItem(number: 3, text: "Take turns saying one word to describe it")
                    ruleItem(number: 4, text: "Imposter tries to blend in without knowing the word")
                    ruleItem(number: 5, text: "Vote to eliminate who you think is the imposter!")
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var bottomActionsView: some View {
        VStack(spacing: 12) {
            if !canStartGame && gameSession.activePlayerCount < gameSession.gameConfig.minPlayers {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("Need at least \(gameSession.gameConfig.minPlayers) players to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            if isHost {
                Button(action: startGame) {
                    HStack {
                        if isStarting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        
                        Text(isStarting ? "Starting Game..." : "Start Game")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canStartGame ? Color.purple : Color.secondary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canStartGame)
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Views
    
    private func infoTile(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func playerRow(_ player: GameParticipant) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.purple)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(player.userName.prefix(1)).uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.userName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if player.isHost {
                    Text("Host")
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var emptyPlayerSlot: some View {
        HStack(spacing: 8) {
            Circle()
                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
            
            Text("Waiting for player...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
    }
    
    private func spectatorRow(_ spectator: GameParticipant) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.orange)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(spectator.userName.prefix(1)).uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            Text(spectator.userName)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
    
    private func ruleItem(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.purple)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes) min"
    }
    
    private func startGame() {
        guard canStartGame else { return }
        
        isStarting = true
        
        Task {
            do {
                try await gameService.startGameSession(gameSession)
                await MainActor.run {
                    showingGame = true
                    isStarting = false
                }
            } catch {
                await MainActor.run {
                    isStarting = false
                    // Handle error - could show alert
                }
            }
        }
    }
    
    private func leaveGame() {
        Task {
            try await gameService.leaveGameSession()
            await MainActor.run {
                dismiss()
            }
        }
    }
}
