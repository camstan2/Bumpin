import SwiftUI
import FirebaseAuth

// MARK: - Matchmaking Bot Mock View

struct MatchmakingBotMockView: View {
    @State private var selectedMockType: MockType = .weeklyMatch
    @State private var showingMockConversation = false
    @State private var selectedMockMessage: MockBotMessage?
    
    enum MockType: String, CaseIterable, Identifiable {
        case weeklyMatch = "Weekly Match"
        case welcomeMessage = "Welcome Message"
        case reminderMessage = "Reminder Message"
        case conversationStarter = "Conversation Starter"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .weeklyMatch: return "heart.text.square.fill"
            case .welcomeMessage: return "hand.wave.fill"
            case .reminderMessage: return "bell.fill"
            case .conversationStarter: return "message.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    mockHeader
                    
                    // Mock type selector
                    mockTypeSelector
                    
                    // Mock messages
                    mockMessagesSection
                    
                    // Live demo button
                    liveDemoButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Bot Message Demo")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingMockConversation) {
            MockConversationView(mockMessage: selectedMockMessage)
        }
    }
    
    // MARK: - Mock Header
    
    private var mockHeader: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Music Matchmaking Bot")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Interactive Demo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("Experience how the bot connects users through music")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Mock Type Selector
    
    private var mockTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Message Types")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MockType.allCases) { type in
                        MockTypeCard(
                            type: type,
                            isSelected: selectedMockType == type,
                            action: { selectedMockType = type }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Mock Messages Section
    
    private var mockMessagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(selectedMockType.rawValue) Examples")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(mockMessages(for: selectedMockType), id: \.id) { message in
                MockMessagePreview(message: message) {
                    selectedMockMessage = message
                    showingMockConversation = true
                }
            }
        }
    }
    
    // MARK: - Live Demo Button
    
    private var liveDemoButton: some View {
        VStack(spacing: 12) {
            Text("Ready to Experience the Magic?")
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Button(action: {
                // Simulate opening a full conversation
                selectedMockMessage = mockMessages(for: .weeklyMatch).first
                showingMockConversation = true
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("View Full Conversation")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Mock Data
    
    private func mockMessages(for type: MockType) -> [MockBotMessage] {
        switch type {
        case .weeklyMatch:
            return [
                MockBotMessage(
                    id: "1",
                    type: .weeklyMatch,
                    text: "🎵 You've got a new music match! Meet Alex - you both love Taylor Swift and The Weeknd. Your compatibility: 87%",
                    matchData: MockMatchData(
                        name: "Alex Johnson",
                        username: "alexmusic",
                        profileImage: nil,
                        similarity: 0.87,
                        sharedArtists: ["Taylor Swift", "The Weeknd", "Billie Eilish"],
                        sharedGenres: ["Pop", "Alternative", "R&B"]
                    )
                ),
                MockBotMessage(
                    id: "2",
                    type: .weeklyMatch,
                    text: "🎶 Perfect match alert! You and Sarah both can't stop listening to Drake and Post Malone. 92% music compatibility!",
                    matchData: MockMatchData(
                        name: "Sarah Chen",
                        username: "sarahbeats",
                        profileImage: nil,
                        similarity: 0.92,
                        sharedArtists: ["Drake", "Post Malone", "Travis Scott"],
                        sharedGenres: ["Hip-Hop", "Rap", "Pop"]
                    )
                )
            ]
        case .welcomeMessage:
            return [
                MockBotMessage(
                    id: "3",
                    type: .welcomeMessage,
                    text: "👋 Welcome to Music Matchmaking! I'll help you connect with people who share your incredible taste in music. Every Thursday at 1 PM, I'll find someone special for you to chat with!",
                    matchData: nil
                )
            ]
        case .reminderMessage:
            return [
                MockBotMessage(
                    id: "4",
                    type: .reminderMessage,
                    text: "🔔 Don't forget - your weekly music match arrives tomorrow at 1 PM! Make sure your music logs are up to date for the best matches.",
                    matchData: nil
                )
            ]
        case .conversationStarter:
            return [
                MockBotMessage(
                    id: "5",
                    type: .conversationStarter,
                    text: "💬 Here's a conversation starter for you and Jamie: You both rated 'Anti-Hero' by Taylor Swift 5 stars! Why not ask about their favorite Taylor Swift era?",
                    matchData: MockMatchData(
                        name: "Jamie Rodriguez",
                        username: "jamietunes",
                        profileImage: nil,
                        similarity: 0.84,
                        sharedArtists: ["Taylor Swift", "Olivia Rodrigo", "Lorde"],
                        sharedGenres: ["Pop", "Indie Pop", "Alternative"]
                    )
                )
            ]
        }
    }
}

// MARK: - Supporting Components

struct MockTypeCard: View {
    let type: MatchmakingBotMockView.MockType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .purple)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(width: 120)
            .background(isSelected ? Color.purple : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct MockMessagePreview: View {
    let message: MockBotMessage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Bot header
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(.purple)
                        .font(.subheadline)
                    
                    Text("Music Matchmaking Bot")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Text("Just now")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Message content
                VStack(alignment: .leading, spacing: 12) {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let matchData = message.matchData {
                        MockMatchCard(matchData: matchData)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.purple.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct MockMatchCard: View {
    let matchData: MockMatchData
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile card
            HStack(spacing: 12) {
                // Profile image placeholder
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(matchData.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.purple)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(matchData.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("@\(matchData.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        
                        Text("\(Int(matchData.similarity * 100))% music match")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Shared interests
            if !matchData.sharedArtists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.purple)
                        
                        Text("What you have in common:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        if !matchData.sharedArtists.isEmpty {
                            HStack {
                                Text("Artists:")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                
                                Spacer()
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(matchData.sharedArtists.prefix(3), id: \.self) { artist in
                                        Text(artist)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        
                        if !matchData.sharedGenres.isEmpty {
                            HStack {
                                Text("Genres:")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                
                                Spacer()
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(matchData.sharedGenres.prefix(3), id: \.self) { genre in
                                        Text(genre)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.1))
                                            .foregroundColor(.green)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle")
                            .font(.caption)
                        Text("View Profile")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(16)
                }
                
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "message")
                            .font(.caption)
                        Text("Say Hi")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .cornerRadius(16)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Mock Conversation View

struct MockConversationView: View {
    let mockMessage: MockBotMessage?
    @Environment(\.dismiss) private var dismiss
    @State private var showingFullDemo = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Bot conversation header
                BotConversationHeader(conversation: mockConversation)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Welcome message
                        mockWelcomeMessage
                        
                        // Main bot message
                        if let message = mockMessage {
                            MockBotMessageView(message: message)
                        }
                        
                        // Conversation flow
                        if showingFullDemo {
                            mockConversationFlow
                        }
                    }
                    .padding(16)
                }
                
                // Message input (disabled for demo)
                HStack(spacing: 8) {
                    TextField("Message...", text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    
                    Button("Send") { }
                        .disabled(true)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("Music Matchmaking Bot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showingFullDemo ? "Collapse" : "Full Demo") {
                        withAnimation {
                            showingFullDemo.toggle()
                        }
                    }
                }
            }
        }
    }
    
    private var mockWelcomeMessage: some View {
        VStack(spacing: 8) {
            Text("👋 Welcome to your Music Matchmaking conversation!")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(16)
        }
    }
    
    private var mockConversationFlow: some View {
        VStack(spacing: 12) {
            // User response
            HStack {
                Spacer()
                Text("This is so cool! I love Taylor Swift too 🎵")
                    .padding(12)
                    .background(Color.purple.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .frame(maxWidth: 250, alignment: .trailing)
            }
            
            // Bot follow-up
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                        
                        Text("Music Matchmaking Bot")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                    
                    Text("Amazing! I've created a direct conversation between you two. Happy chatting! 🎶")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(12)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(16)
                .frame(maxWidth: 280, alignment: .leading)
                
                Spacer()
            }
        }
    }
    
    private var mockConversation: Conversation {
        Conversation(
            id: "mock",
            participantIds: ["current_user", MatchmakingBotService.botUserId],
            participantKey: "mock_key",
            inboxFor: ["current_user"],
            requestFor: [],
            lastMessage: "Your weekly music match is here!",
            lastTimestamp: Date(),
            conversationType: .bot
        )
    }
}

struct MockBotMessageView: View {
    let message: MockBotMessage
    
    var body: some View {
        HStack {
            VStack(spacing: 0) {
                // Bot header
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(.purple)
                        .font(.subheadline)
                    
                    Text("Music Matchmaking Bot")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Text(Date(), style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let matchData = message.matchData {
                        MockMatchCard(matchData: matchData)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.purple.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 320, alignment: .leading)
            
            Spacer()
        }
    }
}

// MARK: - Mock Data Models

struct MockBotMessage: Identifiable {
    let id: String
    let type: MessageType
    let text: String
    let matchData: MockMatchData?
    
    enum MessageType {
        case weeklyMatch
        case welcomeMessage
        case reminderMessage
        case conversationStarter
    }
}

struct MockMatchData {
    let name: String
    let username: String
    let profileImage: String?
    let similarity: Double
    let sharedArtists: [String]
    let sharedGenres: [String]
}

// MARK: - Preview

#Preview {
    MatchmakingBotMockView()
}
