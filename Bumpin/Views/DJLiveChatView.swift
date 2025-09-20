import SwiftUI
import FirebaseAuth

struct DJLiveChatView: View {
    let stream: DemoLiveDJStream
    @StateObject private var chatService = DJChatService.shared
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeaderView
            
            // Messages
            chatMessagesView
            
            // Input
            chatInputView
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            joinChat()
        }
        .onDisappear {
            chatService.leaveChat()
        }
    }
    
    // MARK: - Chat Header
    
    private var chatHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Chat")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("\(chatService.userCount) listeners")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(.red)
                
                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Chat Messages
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if chatService.isLoading {
                        ProgressView("Loading chat...")
                            .padding()
                    } else if chatService.messages.isEmpty {
                        emptyChatView
                    } else {
                        ForEach(chatService.messages) { message in
                            SimpleDJChatMessageView(
                                message: message,
                                currentUserId: Auth.auth().currentUser?.uid ?? ""
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chatService.messages.count) {
                // Auto-scroll to bottom when new message arrives
                if let lastMessage = chatService.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Chat View
    
    private var emptyChatView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No messages yet")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Be the first to say something!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Chat Input
    
    private var chatInputView: some View {
        HStack(spacing: 12) {
            TextField("Send a message...", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isTextFieldFocused)
            
            Button(action: {
                sendMessage()
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(18)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    
    private func joinChat() {
        Task {
            await chatService.joinChat(streamId: stream.id, isDJ: false)
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            await chatService.sendMessage(messageText)
            await MainActor.run {
                messageText = ""
                isTextFieldFocused = false
            }
        }
    }
}

// MARK: - Simple DJ Chat Message View (No Reactions)

struct SimpleDJChatMessageView: View {
    let message: DJChatService.DJChatMessage
    let currentUserId: String
    
    private var isCurrentUser: Bool {
        message.userId == currentUserId
    }
    
    private var messageColor: Color {
        switch message.messageType {
        case .user:
            return isCurrentUser ? .purple : .primary
        case .system:
            return .secondary
        case .djAnnouncement:
            return .orange
        }
    }
    
    private var messageIcon: String? {
        switch message.messageType {
        case .user:
            return nil
        case .system:
            return "info.circle"
        case .djAnnouncement:
            return "megaphone"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                // Other person's message (left side)
                HStack(alignment: .top, spacing: 8) {
                    // Profile Picture
                    if let url = message.userProfileImage, !url.isEmpty, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable().scaledToFit()
                                    .foregroundColor(.purple.opacity(0.5))
                            }
                        }
                        .frame(width: 32, height: 32)
                        .cornerRadius(16)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundColor(.purple.opacity(0.5))
                            .frame(width: 32, height: 32)
                    }
                    
                    // Message content
                    VStack(alignment: .leading, spacing: 4) {
                        // Username
                        Text(message.username)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // Message bubble
                        HStack {
                            if let icon = messageIcon {
                                Image(systemName: icon)
                                    .font(.caption)
                                    .foregroundColor(messageColor)
                            }
                            
                            Text(message.message)
                                .font(.subheadline)
                                .foregroundColor(messageColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
                
                Spacer()
            } else {
                // Own message (right side)
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatMessageTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    HStack {
                        if let icon = messageIcon {
                            Image(systemName: icon)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        Text(message.message)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(messageColor)
                    .cornerRadius(16)
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Demo Live DJ Stream Model

struct DemoLiveDJStream {
    let id: String
    let djName: String
    let title: String
    let genre: String
    let listenerCount: Int
    let isLive: Bool
    let imageUrl: String
}

// MARK: - Supporting Views
// Note: StartDJStreamView and DJStreamSettingsView are defined in DJStreamView.swift