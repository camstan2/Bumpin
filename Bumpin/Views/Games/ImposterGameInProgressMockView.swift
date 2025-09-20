import SwiftUI

struct ImposterGameInProgressMockView: View {
    @State private var messageText = ""
    @State private var showingVotingPhase = false
    @State private var currentPhase: ImposterGamePhase = .speaking
    @State private var timeRemaining = 45
    @State private var currentSpeaker = "Alex"
    @State private var myRole: ImposterRole = .wordHolder
    @State private var assignedWord = "Donald Trump"
    @State private var hasSpoken = false
    
    // Mock game state
    let players = [
        ("Alex", "A", false, true), // (name, initial, isImposter, hasSpoken)
        ("Jordan", "J", false, true),
        ("Sam", "S", true, false), // This is the imposter
        ("Riley", "R", false, false),
        ("Casey", "C", false, false) // Current user
    ]
    
    let gameMessages = [
        ("Alex", "Politics", Date().addingTimeInterval(-120), false),
        ("Jordan", "Hair", Date().addingTimeInterval(-105), false),
        ("Sam", "Popular", Date().addingTimeInterval(-90), false),
        ("Riley", "Orange", Date().addingTimeInterval(-75), false),
        ("Casey", "Controversial", Date().addingTimeInterval(-60), false),
        ("Alex", "President", Date().addingTimeInterval(-45), false),
        ("Jordan", "Twitter", Date().addingTimeInterval(-30), false),
        ("Sam", "Famous", Date().addingTimeInterval(-15), false)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Game Header
                gameHeader
                
                // Game Chat Messages
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(gameMessages.enumerated()), id: \.offset) { index, message in
                            gameMessageRow(message: message)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                
                // Game Input
                gameInputSection
            }
            .navigationTitle("Bang - Imposter")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Leave") { },
                trailing: Button("Vote") {
                    showingVotingPhase = true
                }
                .foregroundColor(.red)
                .fontWeight(.semibold)
            )
        }
        .sheet(isPresented: $showingVotingPhase) {
            votingPhaseView
        }
    }
    
    private var gameHeader: some View {
        VStack(spacing: 12) {
            // Phase and Timer
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speaking Phase")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Round 2 of 3")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(timeRemaining)s")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(timeRemaining < 20 ? .red : .primary)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Your Role Info
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.blue)
                    Text("Your Role: Word Holder")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(.green)
                    Text("Your Word: \(assignedWord)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Player Status
            playerStatusSection
            
            Divider()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }
    
    private var playerStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Players (5)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(player.3 ? Color.green : Color(.systemGray4))
                                .frame(width: 32, height: 32)
                            
                            Text(player.1)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(player.3 ? .white : .secondary)
                        }
                        
                        Text(player.0)
                            .font(.caption2)
                            .foregroundColor(player.0 == currentSpeaker ? .blue : .secondary)
                            .fontWeight(player.0 == currentSpeaker ? .semibold : .regular)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func gameMessageRow(message: (String, String, Date, Bool)) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Player Avatar
            Circle()
                .fill(playerColor(for: message.0))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(message.0.first ?? "?"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.0)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(timeAgo(from: message.2))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // The spoken word
                Text(message.1)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            Spacer(minLength: 0)
        }
    }
    
    private var gameInputSection: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(spacing: 12) {
                // Current turn indicator
                if currentSpeaker == "Casey" {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                        Text("Your turn to speak!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                } else {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Waiting for \(currentSpeaker) to speak...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                
                // Input section
                HStack(spacing: 12) {
                    TextField("Enter one word...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(currentSpeaker != "Casey")
                    
                    Button(action: {
                        // Submit word
                        messageText = ""
                        hasSpoken = true
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty || currentSpeaker != "Casey" ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty || currentSpeaker != "Casey")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color(.systemBackground))
        }
    }
    
    private var votingPhaseView: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("🕵️ Voting Time!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Who do you think is the imposter?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                
                VStack(spacing: 16) {
                    ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                        if player.0 != "Casey" { // Don't show self
                            Button(action: {
                                // Vote for this player
                            }) {
                                HStack {
                                    Circle()
                                        .fill(playerColor(for: player.0))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(player.1)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        )
                                    
                                    Text(player.0)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Text("⏱️ 30 seconds to vote")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                    
                    Text("Majority vote determines the outcome")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Vote for Imposter")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingVotingPhase = false
                }
            )
        }
    }
    
    private func playerColor(for name: String) -> Color {
        switch name {
        case "Alex": return .blue
        case "Jordan": return .purple
        case "Sam": return .red
        case "Riley": return .green
        case "Casey": return .orange
        default: return .gray
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            return "\(minutes)m"
        }
    }
}

struct ImposterGameInProgressMockView_Previews: PreviewProvider {
    static var previews: some View {
        ImposterGameInProgressMockView()
    }
}
