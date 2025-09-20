import SwiftUI
import FirebaseAuth

struct GameCreationView: View {
    @Binding var selectedGameType: GameType
    let onGameCreated: (GameSession) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameService = GameService.shared
    
    @State private var gameTitle = ""
    @State private var isCreating = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Game Details")) {
                    TextField("Game Title", text: $gameTitle)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Game Type", selection: $selectedGameType) {
                        ForEach(GameType.allCases, id: \.self) { gameType in
                            HStack {
                                Image(systemName: gameType.iconName)
                                Text(gameType.displayName)
                            }
                            .tag(gameType)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Game Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: selectedGameType.iconName)
                                .foregroundColor(.purple)
                            Text(selectedGameType.displayName)
                                .font(.headline)
                            Spacer()
                        }
                        
                        Text(selectedGameType.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            gameInfoItem(
                                icon: "person.2.fill",
                                title: "Players",
                                value: "\(selectedGameType.minPlayers)-\(selectedGameType.maxPlayers)"
                            )
                            
                            gameInfoItem(
                                icon: "clock.fill",
                                title: "Duration",
                                value: formatDuration(selectedGameType.estimatedDuration)
                            )
                            
                            if selectedGameType.supportsSpectators {
                                gameInfoItem(
                                    icon: "eye.fill",
                                    title: "Spectators",
                                    value: "Yes"
                                )
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 4)
                }
                
                if selectedGameType == .imposter {
                    Section(header: Text("Imposter Settings")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to Play:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                bulletPoint("One player is secretly the imposter")
                                bulletPoint("Other players know the secret word")
                                bulletPoint("Take turns saying one word to describe it")
                                bulletPoint("Imposter tries to blend in without knowing the word")
                                bulletPoint("Vote to eliminate the imposter!")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Create Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGame()
                    }
                    .disabled(gameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func gameInfoItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.purple)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(.purple)
            Text(text)
            Spacer()
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
    }
    
    private func createGame() {
        guard !gameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isCreating = true
        
        Task {
            do {
                let gameSession = try await gameService.createGameSession(
                    title: gameTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    gameType: selectedGameType
                )
                
                await MainActor.run {
                    isCreating = false
                    onGameCreated(gameSession)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
