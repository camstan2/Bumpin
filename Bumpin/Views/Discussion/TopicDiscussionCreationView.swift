import SwiftUI

struct TopicDiscussionCreationView: View {
    let selectedTopic: DiscussionTopic
    let onDiscussionCreated: (TopicChat) -> Void
    let onCancel: () -> Void
    
    // Discussion settings
    @State private var discussionTitle: String = ""
    @State private var discussionDescription: String = ""
    @State private var admissionMode: String = "open"
    @State private var speakingPermissionMode: String = "everyone"
    @State private var friendsAutoSpeaker: Bool = false
    
    // Creation state
    @State private var isCreatingDiscussion = false
    
    init(selectedTopic: DiscussionTopic, onDiscussionCreated: @escaping (TopicChat) -> Void, onCancel: @escaping () -> Void) {
        self.selectedTopic = selectedTopic
        self.onDiscussionCreated = onDiscussionCreated
        self.onCancel = onCancel
        self._discussionTitle = State(initialValue: selectedTopic.name)
        self._discussionDescription = State(initialValue: selectedTopic.description ?? "")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                contentSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 50))
                .foregroundColor(.purple)
                .frame(width: 80, height: 80)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(20)
            
            Text("Create a Discussion")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Start a topic discussion and invite others to join")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
        .padding(.horizontal)
    }
    
    private var contentSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                topicInfoSection
                discussionSettingsSection
                createButtonSection
            }
            .padding()
        }
    }
    
    private var topicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Selected Topic")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: selectedTopic.category.icon)
                        .foregroundColor(selectedTopic.category.color)
                    Text(selectedTopic.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text(selectedTopic.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let description = selectedTopic.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var discussionSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discussion Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discussion Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter discussion title", text: $discussionTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Add a description", text: $discussionDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                admissionModeSection
                speakingPermissionSection
            }
        }
    }
    
    private var admissionModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who can join?")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("Admission Mode", selection: $admissionMode) {
                Text("Anyone").tag("open")
                Text("Friends only").tag("friends")
                Text("Invite only").tag("invite")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var speakingPermissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speaking permissions")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("Speaking Permission", selection: $speakingPermissionMode) {
                Text("Everyone can speak").tag("everyone")
                Text("Request to speak").tag("approval")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if speakingPermissionMode == "approval" {
                Toggle("Friends can speak automatically", isOn: $friendsAutoSpeaker)
                    .font(.caption)
            }
        }
    }
    
    private var createButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: createDiscussion) {
                HStack {
                    if isCreatingDiscussion {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text(isCreatingDiscussion ? "Creating..." : "Create Discussion")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(discussionTitle.isEmpty ? Color.gray : Color.purple)
                .cornerRadius(12)
            }
            .disabled(discussionTitle.isEmpty || isCreatingDiscussion)
            
            Text("You'll be the host of this discussion")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
    
    private func createDiscussion() {
        guard !discussionTitle.isEmpty else { return }
        
        isCreatingDiscussion = true
        
        Task {
            do {
                // Use TopicSystemManager to properly create discussion and update statistics
                let topicChat = try await TopicSystemManager.shared.createDiscussionFromTopic(
                    selectedTopic,
                    hostId: "current_user_id", // Replace with actual user ID
                    hostName: "Current User" // Replace with actual user name
                )
                
                // Update with custom settings
                var updatedChat = topicChat
                updatedChat.title = discussionTitle
                updatedChat.description = discussionDescription.isEmpty ? (selectedTopic.description ?? "") : discussionDescription
                updatedChat.admissionMode = admissionMode
                updatedChat.speakingPermissionMode = speakingPermissionMode
                updatedChat.friendsAutoSpeaker = friendsAutoSpeaker
                
                await MainActor.run {
                    self.isCreatingDiscussion = false
                    self.onDiscussionCreated(updatedChat)
                }
            } catch {
                await MainActor.run {
                    self.isCreatingDiscussion = false
                    // Handle error - could show alert
                    print("Error creating discussion: \(error)")
                }
            }
        }
    }
}