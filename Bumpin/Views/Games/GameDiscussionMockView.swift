import SwiftUI

struct GameDiscussionMockView: View {
    @State private var selectedTab = 0
    @State private var showingGameChange = false
    @State private var messageText = ""
    
    // Mock data
    let participants = [
        ("Host", true, "H", Color.orange),
        ("Taylor", false, "T", Color.purple),
        ("Chris", false, "C", Color.blue),
        ("Sam", false, "S", Color.green),
        ("Lee", false, "L", Color.red)
    ]
    
    let gameMessages = [
        ("Host", "Welcome everyone! Let's play Imposter 🕵️", Date().addingTimeInterval(-300), false),
        ("Taylor", "Excited to play! First time trying this game", Date().addingTimeInterval(-250), false),
        ("Chris", "I'm ready! How many rounds are we doing?", Date().addingTimeInterval(-200), false),
        ("Host", "Let's do 3 rounds. I'll start the game in a minute", Date().addingTimeInterval(-150), false),
        ("Sam", "Perfect! Can't wait to see who the imposter is 😄", Date().addingTimeInterval(-100), false),
        ("Lee", "This is going to be fun! Good luck everyone", Date().addingTimeInterval(-50), false)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Bar
                tabBar
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    // Games Tab
                    gamesTabView
                        .tag(0)
                    
                    // People Tab
                    peopleTabView
                        .tag(1)
                    
                    // Chat Tab
                    chatTabView
                        .tag(2)
                    
                    // Settings Tab
                    settingsTabView
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Bang - Imposter")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") { },
                trailing: HStack {
                    Button(action: { }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title2)
                    }
                    Button(action: { }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                            .font(.title2)
                    }
                }
            )
        }
        .sheet(isPresented: $showingGameChange) {
            gameChangeView
        }
    }
    
    private var tabBar: some View {
        HStack {
            TabBarButton(
                icon: "gamecontroller.fill",
                title: "Games",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            TabBarButton(
                icon: "person.2.fill",
                title: "People",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            TabBarButton(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Chat",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            
            TabBarButton(
                icon: "gearshape.fill",
                title: "Settings",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    private var gamesTabView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Game Status
                VStack(spacing: 16) {
                    HStack {
                        Text("Current Game")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Imposter")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Social deduction game")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("LOBBY")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Text("5/8 players")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Game Info
                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.purple)
                                Text("10 min")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Duration")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.green)
                                Text("3-8")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Players")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.red)
                                Text("Easy")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Difficulty")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Game Actions
                VStack(spacing: 12) {
                    HStack {
                        Text("Game Actions")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start Game")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("Need at least 3 players")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Invite Friends")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("Send game invitations")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Game Rules
                VStack(spacing: 12) {
                    HStack {
                        Text("How to Play")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("1")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.blue)
                                .cornerRadius(10)
                            
                            Text("One player is secretly the imposter, others get the same word")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("2")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.green)
                                .cornerRadius(10)
                            
                            Text("Take turns saying one word to describe your assigned word")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        HStack(alignment: .top, spacing: 12) {
                            Text("3")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.orange)
                                .cornerRadius(10)
                            
                            Text("Vote to identify the imposter. If correct, everyone wins!")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
    
    private var peopleTabView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(Array(participants.enumerated()), id: \.offset) { index, participant in
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(participant.3)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(participant.1 ? Color.yellow : Color.clear, lineWidth: 3)
                                )
                            
                            Text(participant.2)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 4) {
                            Text(participant.0)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(participant.1 ? "Host" : "Member")
                                .font(.caption)
                                .foregroundColor(participant.1 ? .yellow : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(participant.1 ? Color.yellow.opacity(0.1) : Color(.systemGray5))
                                .cornerRadius(4)
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
    
    private var chatTabView: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(gameMessages.enumerated()), id: \.offset) { index, message in
                        HStack(alignment: .top, spacing: 12) {
                            // Avatar
                            Circle()
                                .fill(participants.first(where: { $0.0 == message.0 })?.3 ?? .gray)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(participants.first(where: { $0.0 == message.0 })?.2 ?? "?")
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
                                
                                Text(message.1)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            
            // Input
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    TextField("Type a message...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
        }
    }
    
    private var settingsTabView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Discussion Name
                VStack(alignment: .leading, spacing: 12) {
                    Text("Discussion Name")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.purple)
                        Text("Bang - Imposter")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Current Game
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Game")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Button(action: { showingGameChange = true }) {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Imposter")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("Social deduction game")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 0) {
                        SettingRow(
                            icon: "person.2.fill",
                            iconColor: .purple,
                            title: "Who Can Join",
                            value: "Open"
                        )
                        
                        Divider()
                            .padding(.leading, 44)
                        
                        SettingRow(
                            icon: "location.fill",
                            iconColor: .green,
                            title: "Discussion Location",
                            value: "Enabled"
                        )
                        
                        Divider()
                            .padding(.leading, 44)
                        
                        SettingRow(
                            icon: "mic.fill",
                            iconColor: .red,
                            title: "Speaking Permissions",
                            value: "Everyone"
                        )
                        
                        Divider()
                            .padding(.leading, 44)
                        
                        SettingRow(
                            icon: "person.badge.plus",
                            iconColor: .blue,
                            title: "Friends Auto Permission",
                            value: "Disabled"
                        )
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
    
    private var gameChangeView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Choose a different game for your discussion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    
                    VStack(spacing: 12) {
                        GameOptionRow(
                            name: "Imposter",
                            description: "Social deduction game",
                            players: "3-8 players",
                            duration: "10 min",
                            isSelected: true
                        )
                        
                        GameOptionRow(
                            name: "Word Chain",
                            description: "Creative word association",
                            players: "2-6 players",
                            duration: "5 min",
                            isSelected: false
                        )
                        
                        GameOptionRow(
                            name: "20 Questions",
                            description: "Guess the mystery item",
                            players: "2-8 players",
                            duration: "8 min",
                            isSelected: false
                        )
                        
                        GameOptionRow(
                            name: "Story Builder",
                            description: "Collaborative storytelling",
                            players: "3-6 players",
                            duration: "15 min",
                            isSelected: false
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Change Game")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingGameChange = false
                },
                trailing: Button("Save") {
                    showingGameChange = false
                }
                .fontWeight(.semibold)
            )
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

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .purple : .gray)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .purple : .gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct GameOptionRow: View {
    let name: String
    let description: String
    let players: String
    let duration: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(players)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(duration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GameDiscussionMockView_Previews: PreviewProvider {
    static var previews: some View {
        GameDiscussionMockView()
    }
}
