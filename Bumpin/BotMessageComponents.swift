import SwiftUI
import FirebaseAuth

// MARK: - Bot Message Components

/// Enhanced message view that handles different message types including bot messages
struct EnhancedMessageView: View {
    let message: DirectMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                userMessageView
            } else {
                if message.messageType == .botMatchmaking {
                    botMatchmakingMessageView
                } else if message.senderId == MatchmakingBotService.botUserId {
                    botSystemMessageView
                } else {
                    otherUserMessageView
                }
                Spacer()
            }
        }
    }
    
    // MARK: - User Message
    
    private var userMessageView: some View {
        Text(message.text)
            .padding(12)
            .background(Color.purple.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(16)
            .frame(maxWidth: 250, alignment: .trailing)
    }
    
    // MARK: - Other User Message
    
    private var otherUserMessageView: some View {
        Text(message.text)
            .padding(12)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
            .cornerRadius(16)
            .frame(maxWidth: 250, alignment: .leading)
    }
    
    // MARK: - Bot System Message
    
    private var botSystemMessageView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.purple)
                    .font(.caption)
                
                Text("Music Matchmaking Bot")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                
                Spacer()
            }
            
            Text(message.text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 280, alignment: .leading)
    }
    
    // MARK: - Bot Matchmaking Message
    
    private var botMatchmakingMessageView: some View {
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
                
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if let matchData = message.matchmakingData {
                MatchmakingMessageCard(
                    message: message.text,
                    matchData: matchData
                )
            } else {
                // Fallback for bot messages without match data
                Text(message.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
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
    }
}

// MARK: - Matchmaking Message Card

struct MatchmakingMessageCard: View {
    let message: String
    let matchData: MatchmakingMessageData
    @State private var showingUserProfile = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Bot message text
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
            
            // Match profile card
            matchProfileCard
            
            // Shared interests
            if !matchData.sharedArtists.isEmpty || !matchData.sharedGenres.isEmpty {
                sharedInterestsSection
            }
            
            // Action buttons
            actionButtons
        }
        .padding(.bottom, 16)
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView(userId: matchData.matchedUserId)
        }
    }
    
    // MARK: - Match Profile Card
    
    private var matchProfileCard: some View {
        HStack(spacing: 12) {
            // Profile image
            AsyncImage(url: URL(string: matchData.matchedProfileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .overlay(
                        Text(matchData.matchedDisplayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.purple)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(matchData.matchedDisplayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("@\(matchData.matchedUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Compatibility score
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    
                    Text("\(Int(matchData.similarityScore * 100))% music match")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - Shared Interests Section
    
    private var sharedInterestsSection: some View {
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
            
            if !matchData.sharedArtists.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Artists")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(matchData.sharedArtists.prefix(5), id: \.self) { artist in
                                Text(artist)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            if !matchData.sharedGenres.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Genres")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(matchData.sharedGenres.prefix(4), id: \.self) { genre in
                                Text(genre)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { showingUserProfile = true }) {
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
            
            Button(action: startConversation) {
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
        .padding(.horizontal, 16)
    }
    
    // MARK: - Actions
    
    private func startConversation() {
        Task {
            await BotConversationService.shared.handleMatchAction(
                .startConversation,
                matchData: matchData
            )
        }
    }
}

// MARK: - Bot Conversation Header

struct BotConversationHeader: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Bot avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Music Matchmaking Bot")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Your weekly music matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Bot indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                
                Text("BOT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
}

// MARK: - Conversation List Item Enhancement

struct EnhancedConversationListItem: View {
    let conversation: Conversation
    let displayName: String
    let profileImageUrl: String?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with bot indicator
                ZStack(alignment: .bottomTrailing) {
                    if conversation.isBotConversation {
                        botAvatarView
                    } else {
                        userAvatarView
                    }
                    
                    if conversation.isBotConversation {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 2, y: 2)
                    }
                }
                
                // Conversation info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if conversation.isBotConversation {
                            Text("BOT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        if let timestamp = conversation.lastTimestamp {
                            Text(timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(conversation.lastMessage ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Avatar Views
    
    private var botAvatarView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
            
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
        }
    }
    
    private var userAvatarView: some View {
        AsyncImage(url: URL(string: profileImageUrl ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(Color(.systemGray4))
                .overlay(
                    Text(displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                )
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    VStack {
        EnhancedMessageView(
            message: DirectMessage(
                id: "1",
                conversationId: "conv1",
                senderId: MatchmakingBotService.botUserId,
                text: "You've been matched with someone who loves the same music!",
                createdAt: Date(),
                messageType: .botMatchmaking,
                matchmakingData: MatchmakingMessageData(
                    matchedUserId: "user123",
                    matchedUsername: "musiclover",
                    matchedDisplayName: "Alex Johnson",
                    matchedProfileImageUrl: nil,
                    sharedArtists: ["Taylor Swift", "The Weeknd"],
                    sharedGenres: ["Pop", "R&B"],
                    similarityScore: 0.85,
                    weekId: "2024-W12"
                )
            ),
            isCurrentUser: false
        )
        
        Spacer()
    }
    .padding()
}
