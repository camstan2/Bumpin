import SwiftUI
import FirebaseFirestore

// MARK: - Models
struct QueueRequest: Identifiable, Codable {
    let id: String
    let userId: String
    let userName: String
    let groupSize: Int
    let genderPreference: GenderPreference?
    let timestamp: Date
    var groupMembers: [String]
    var status: QueueStatus
    
    init(userId: String, userName: String, groupSize: Int = 1, genderPreference: GenderPreference? = nil) {
        self.id = UUID().uuidString
        self.userId = userId
        self.userName = userName
        self.groupSize = groupSize
        self.genderPreference = genderPreference
        self.timestamp = Date()
        self.groupMembers = [userId]
        self.status = .waiting
    }
}

enum GenderPreference: String, Codable {
    case male = "male"
    case female = "female"
    case any = "any"
}

enum QueueStatus: String, Codable {
    case waiting = "waiting"
    case matching = "matching"
    case matched = "matched"
    case failed = "failed"
}

// MARK: - Main View
struct RandomChatView: View {
    @StateObject private var viewModel = RandomChatViewModel()
    @EnvironmentObject var discussionManager: DiscussionManager
    @State private var showingGroupSizeSheet = false
    @State private var showingPreferencesSheet = false
    @State private var showingInviteFriendsSheet = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Random Chat")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Meet new people in voice chat")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // Queue Status
            if viewModel.isInQueue {
                queueStatusView
            }
            
            // Main Queue Button
            if !viewModel.isInQueue {
                queueOptionsView
            }
            
            Spacer()
            
            // Stats
            statsView
        }
        .padding()
        .sheet(isPresented: $showingGroupSizeSheet) {
            GroupSizeSelectionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingPreferencesSheet) {
            PreferencesSelectionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingInviteFriendsSheet) {
            InviteFriendsView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $discussionManager.showDiscussionView) {
            if let chat = discussionManager.currentDiscussion,
               discussionManager.currentDiscussionType == .randomChat {
                UnifiedDiscussionView(
                    chat: chat,
                    discussionType: .randomChat,
                    onClose: {
                        discussionManager.leaveDiscussion()
                        viewModel.endMatch()
                    }
                )
            }
        }
        .onChange(of: viewModel.matchedChat) { newChat in
            if let chat = newChat {
                // When a match is found, join the discussion through the manager
                discussionManager.joinDiscussion(chat, type: .randomChat)
            }
        }
    }
    
    private var queueStatusView: some View {
        QueueStatusView(viewModel: viewModel)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private var queueOptionsView: some View {
        VStack(spacing: 16) {
            // Solo Queue
            Button {
                viewModel.joinQueue()
            } label: {
                HStack {
                    Image(systemName: "person.fill")
                    Text("Start Solo Chat")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Group Queue
            Button {
                showingGroupSizeSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("Group Chat (2v2 or 3v3)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Mock Discussion Button for Testing
            Button {
                viewModel.createMockMatch()
            } label: {
                HStack {
                    Image(systemName: "eye.fill")
                    Text("Preview Discussion (Test)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Preferences
            Button {
                showingPreferencesSheet = true
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Chat Preferences")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
    
    private var statsView: some View {
        VStack(spacing: 8) {
            Text("Current Activity")
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack {
                    Text("\(viewModel.activeChats)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Active Chats")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.queuedUsers)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("In Queue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(viewModel.averageWaitTime)s")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Avg. Wait")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }
}
