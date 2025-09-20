import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum DiscussionType {
    case randomChat
    case topicChat
}

struct UnifiedDiscussionView: View {
    @State private var chat: TopicChat
    let discussionType: DiscussionType
    let onClose: () -> Void
    
    init(chat: TopicChat, discussionType: DiscussionType, onClose: @escaping () -> Void) {
        self._chat = State(initialValue: chat)
        self.discussionType = discussionType
        self.onClose = onClose
    }
    
    @StateObject private var viewModel = UnifiedDiscussionViewModel()
    @StateObject private var voiceChatManager = VoiceChatManager()
    @EnvironmentObject var discussionManager: DiscussionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showingLeaveAlert = false
    @State private var showingParticipantActions = false
    @State private var selectedParticipant: TopicParticipant?
    @State private var selectedUserIdForProfile: IdentifiableString?
    @State private var showingTopicChange = false
    @State private var showingTopicSelection = false
    @State private var selectedCategory: TopicCategory = .music
    @State private var selectedTopic: DiscussionTopic? = nil
    @State private var showingNameEdit = false
    @State private var editedDiscussionName = ""
    
    private var isHost: Bool { chat.hostId == Auth.auth().currentUser?.uid }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header (matching party header style)
                discussionHeaderView
                
                // Tab Bar (matching party tab bar style)
                tabBarView
                
                // Content Area with tabs
                TabView(selection: $selectedTab) {
                    // Participants Tab
                    participantsTabView
                        .tag(0)
                    
                    // Chat Tab (actual messaging)
                    chatTabView
                        .tag(1)
                    
                    // Settings Tab (host: editable, non-host: read-only except party creation)
                    settingsTabView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .onAppear {
                viewModel.setupDiscussion(chat: $chat, type: discussionType)
            }
            .onDisappear {
                viewModel.cleanup()
            }
            .alert("Leave Discussion", isPresented: $showingLeaveAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    onClose()
                }
            } message: {
                Text("Are you sure you want to leave this discussion?")
            }
        }
    }
    
    // MARK: - Header View
    
    private var discussionHeaderView: some View {
        VStack(spacing: 12) {
            ZStack {
                // Centered title and participant count
                VStack(spacing: 4) {
                    Text(chat.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text("\(chat.participants.count) participants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Leading and trailing buttons
                HStack {
                    Button("Close") {
                        onClose()
                    }
                    .foregroundColor(.purple)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        // Minimize Button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                discussionManager.minimizeDiscussion()
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                                .background(
                                    Circle()
                                        .fill(Color.purple.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                )
                                .shadow(color: Color.purple.opacity(0.2), radius: 3, x: 0, y: 1)
                        }
                        
                        // More options button
                        Button(action: {
                            showingLeaveAlert = true
                        }) {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Tab Bar View
    
    private var tabBarView: some View {
        HStack {
            ForEach(0..<3, id: \.self) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(for: index))
                            .font(.system(size: 16, weight: .medium))
                        Text(tabTitle(for: index))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == index ? .purple : .secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "person.2"
        case 1: return "message"
        case 2: return "gearshape"
        default: return "circle"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "People"
        case 1: return "Chat"
        case 2: return "Settings"
        default: return ""
        }
    }
    
    // MARK: - Participants Tab View
    
    private var participantsTabView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(chat.participants) { participant in
                    VStack(spacing: 12) {
                        // Profile Picture
                        Button(action: {
                            selectedUserIdForProfile = IdentifiableString(value: participant.id)
                        }) {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.purple)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(participant.isHost ? Color.yellow : Color.clear, lineWidth: 3)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Name and Role
                        VStack(spacing: 4) {
                            Button(action: {
                                selectedUserIdForProfile = IdentifiableString(value: participant.id)
                            }) {
                                Text(participant.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Role Badge
                            if participant.isHost {
                                Text("Host")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.15))
                                    .cornerRadius(8)
                            } else {
                                Text("Member")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(item: $selectedUserIdForProfile) { userIdWrapper in
            NavigationView {
                UserProfileView(userId: userIdWrapper.value)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                selectedUserIdForProfile = nil
                            }
                            .foregroundColor(.purple)
                        }
                    }
            }
        }
    }
    
    // MARK: - Chat Tab View
    
    private var chatTabView: some View {
        VStack(spacing: 0) {
            // Chat messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.messages.isEmpty {
                            Text("No messages yet")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message, isCurrentUser: message.userId == Auth.auth().currentUser?.uid)
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Chat input area
            chatInputView
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Settings Tab View
    
    private var settingsTabView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isHost {
                    // Host Settings
                    hostSettingsView
                } else {
                    // Non-Host View (Read-only)
                    nonHostSettingsView
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showingTopicChange) {
            TopicSelectionView(
                selectedCategory: $selectedCategory,
                selectedTopic: $selectedTopic,
                onSave: { newCategory, newTopic in
                    // Update the discussion topic
                    updateDiscussionTopic(category: newCategory, topic: newTopic)
                    showingTopicChange = false
                },
                onCancel: {
                    showingTopicChange = false
                }
            )
        }
    }
    
    // MARK: - Host Settings View
    
    private var hostSettingsView: some View {
        VStack(spacing: 20) {
            // Discussion Name Section
            discussionNameSection
            
            // Current Topic Section
            currentTopicSection
            
            // Discussion Settings Section
            discussionSettingsSection
        }
    }
    
    // MARK: - Non-Host Settings View
    
    private var nonHostSettingsView: some View {
        VStack(spacing: 20) {
            // Discussion Name Section (Read-only)
            discussionNameSectionReadOnly
            
            // Current Topic Section (Read-only)
            currentTopicSectionReadOnly
            
            // Current Settings Display (Read-only)
            currentSettingsDisplay
        }
    }
    
    // MARK: - Discussion Name Section
    
    private var discussionNameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discussion Name")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "text.bubble")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chat.title)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("Tap to edit the discussion name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Edit") {
                    editedDiscussionName = chat.title
                    showingNameEdit = true
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingNameEdit) {
            DiscussionNameEditView(
                discussionName: $editedDiscussionName,
                onSave: { newName in
                    updateDiscussionName(newName)
                    showingNameEdit = false
                },
                onCancel: {
                    showingNameEdit = false
                }
            )
        }
    }
    
    // MARK: - Discussion Name Section (Read-only)
    
    private var discussionNameSectionReadOnly: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discussion Name")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "text.bubble")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text(chat.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Current Topic Section
    
    private var currentTopicSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Topic")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .font(.title2)
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedTopic?.name ?? "No topic selected")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text("from \(selectedCategory.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Change Topic") {
                        selectedCategory = .music // Default category
                        selectedTopic = nil
                        showingTopicChange = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
                .padding()
                .background(selectedCategory.color.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Current Topic Section (Read-only)
    
    private var currentTopicSectionReadOnly: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Topic")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: selectedCategory.icon)
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTopic?.name ?? "No topic selected")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("from \(selectedCategory.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(selectedCategory.color.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Discussion Settings Section
    
    private var discussionSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Who Can Join
                discussionSettingRow(
                    icon: "person.2.circle",
                    title: "Who Can Join",
                    subtitle: "Control who can join your discussion",
                    value: admissionModeDisplayText,
                    action: { /* TODO: Add picker */ }
                )
                
                // Discussion Location
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "location.circle")
                            .foregroundColor(.purple)
                        Text("Discussion Location")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Toggle("", isOn: .constant(chat.locationSharingEnabled ?? false))
                    }
                    
                    Text("Show your discussion location to other users")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Speaking
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mic.circle")
                            .foregroundColor(.purple)
                        Text("Speaking")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Toggle("", isOn: .constant(true)) // TODO: Add speaking enabled property to TopicChat
                    }
                    
                    Text("Allow voice chat during the discussion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Speaking Permissions
                discussionSettingRow(
                    icon: "speaker.wave.2.circle",
                    title: "Speaking Permissions",
                    subtitle: "Choose if anyone can speak or host approval is required",
                    value: (chat.speakingPermissionMode ?? "everyone") == "everyone" ? "Everyone" : "Host Approval",
                    action: { /* TODO: Add picker */ }
                )
                
                // Friends Auto Permission
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.2.circle")
                            .foregroundColor(.purple)
                        Text("Friends Auto Permission")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Toggle("", isOn: .constant(chat.friendsAutoSpeaker ?? false))
                    }
                    
                    Text("Friends are auto-approved to speak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Current Settings Display (Read-only)
    
    private var currentSettingsDisplay: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                settingDisplayRow(
                    icon: "person.2.circle",
                    title: "Who Can Join",
                    value: admissionModeDisplayText
                )
                
                settingDisplayRow(
                    icon: "location.circle",
                    title: "Discussion Location",
                    value: (chat.locationSharingEnabled ?? false) ? "Enabled" : "Disabled"
                )
                
                settingDisplayRow(
                    icon: "speaker.wave.2.circle",
                    title: "Speaking Permissions",
                    value: (chat.speakingPermissionMode ?? "everyone") == "everyone" ? "Everyone" : "Host Approval"
                )
                
                settingDisplayRow(
                    icon: "person.2.circle",
                    title: "Friends Auto Permission",
                    value: (chat.friendsAutoSpeaker ?? false) ? "Enabled" : "Disabled"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Views
    
    private func discussionSettingRow(
        icon: String,
        title: String,
        subtitle: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func settingDisplayRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Helper Properties
    
    private var admissionModeDisplayText: String {
        switch chat.admissionMode ?? "open" {
        case "open": return "Open"
        case "invite": return "Invite Only"
        case "friends": return "Friends Only"
        case "followers": return "Followers Only"
        default: return "Open"
        }
    }
    
    // MARK: - Helper Functions
    
    private func updateDiscussionTopic(category: TopicCategory, topic: DiscussionTopic?) {
        // TODO: Implement Firestore update
        selectedCategory = category
        selectedTopic = topic
    }
    
    private func updateDiscussionName(_ newName: String) {
        // TODO: Implement Firestore update
        chat.title = newName
    }
    
    // MARK: - Message Bubble View
    
    private func MessageBubbleView(message: DiscussionMessage, isCurrentUser: Bool) -> some View {
        DiscussionMessageBubble(message: message, isCurrentUser: isCurrentUser, viewModel: viewModel)
    }
    
    // MARK: - Party Creation Section
    
    private var partyCreationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Party")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.partyVotingInProgress {
                // Show voting status
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Party Creation Vote in Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Votes: \(viewModel.currentVotes)/\(viewModel.requiredVotes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.votingTimeRemaining)s remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: Double(viewModel.currentVotes), total: Double(viewModel.requiredVotes))
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                Button {
                    viewModel.initiatePartyCreation()
                } label: {
                    HStack {
                        Image(systemName: "music.note.house.fill")
                        Text("Start Party Vote")
                        Spacer()
                        Text("Needs 3/4 votes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Enhanced Ice Breaker Section
    
    private var enhancedIceBreakerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Ice Breakers")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("Get the conversation started with these prompts")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.iceBreakers.prefix(6), id: \.self) { iceBreaker in
                    Button {
                        viewModel.messageText = iceBreaker
                    } label: {
                        Text(iceBreaker)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Chat Input View
    
    private var chatInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Message input field
                TextField("Type a message...", text: $viewModel.messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 36)
                
                // Send button
                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.messageText.isEmpty ? .secondary : .purple)
                }
                .disabled(viewModel.messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Discussion Message Bubble Component

struct DiscussionMessageBubble: View {
    let message: DiscussionMessage
    let isCurrentUser: Bool
    @ObservedObject var viewModel: UnifiedDiscussionViewModel
    @State private var showingReactionPicker = false
    @State private var showingUserProfile = false
    
    private var messageReactions: [ReactionSummary] {
        return viewModel.messageReactions[message.id] ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if isCurrentUser {
                    Spacer()
                }
                
                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                    // Username (only for other users) - tappable for profile
                    if !isCurrentUser {
                        Button(action: {
                            showingUserProfile = true
                        }) {
                            Text(message.userName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Message bubble with long press for reactions
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isCurrentUser ? Color.purple : Color(.systemGray5))
                        )
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .onLongPressGesture {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            showingReactionPicker = true
                        }
                    
                    // Timestamp
                    Text(formatMessageTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                }
                .frame(maxWidth: 280, alignment: isCurrentUser ? .trailing : .leading)
                
                if !isCurrentUser {
                    Spacer()
                }
            }
            
            // Reactions display
            if !messageReactions.isEmpty {
                HStack {
                    if isCurrentUser { Spacer() }
                    
                    MessageReactionView(reactions: messageReactions) { emoji in
                        viewModel.toggleReaction(on: message.id, emoji: emoji)
                    }
                    .padding(.leading, isCurrentUser ? 0 : 40) // Align with message
                    
                    if !isCurrentUser { Spacer() }
                }
            }
        }
        .sheet(isPresented: $showingReactionPicker) {
            EmojiReactionPicker(
                onEmojiSelected: { emoji in
                    viewModel.addReaction(to: message.id, emoji: emoji)
                    showingReactionPicker = false
                },
                onDismiss: {
                    showingReactionPicker = false
                }
            )
            .presentationDetents([.height(300)])
        }
        .fullScreenCover(isPresented: $showingUserProfile) {
            UserProfileView(userId: message.userId)
        }
        .onAppear {
            // Load reactions for this message
            Task {
                await viewModel.loadReactions(for: message.id)
            }
        }
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    let mockChat = TopicChat(
        title: "Music Discussion",
        description: "Talk about your favorite artists",
        category: .music,
        hostId: "host1",
        hostName: "Sarah"
    )
    
    UnifiedDiscussionView(
        chat: mockChat,
        discussionType: .randomChat,
        onClose: {}
    )
}