import SwiftUI
import FirebaseAuth

// MARK: - DJ Stream Interface

struct DJStreamView: View {
    @StateObject private var djService = DJStreamService.shared
    @StateObject private var chatService = DJChatService.shared
    @State private var showingStartStream = false
    @State private var showingStreamSettings = false
    @State private var selectedTab: DJTab = .controls
    @State private var isGridView = false
    @State private var selectedParticipant: DemoParticipant?
    @Environment(\.presentationMode) var presentationMode
    
    enum DJTab: String, CaseIterable {
        case controls = "Controls"
        case participants = "Listeners"
        case chat = "Chat"
        
        var icon: String {
            switch self {
            case .controls: return "music.mic"
            case .participants: return "person.2.fill"
            case .chat: return "message.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .controls: return .purple
            case .participants: return .blue
            case .chat: return .green
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Professional background
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.2), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if djService.isStreaming {
                // Professional tabbed streaming interface
                VStack(spacing: 0) {
                    // Professional Header
                    professionalHeader
                    
                    // Tab Content
                    tabContentView
                    
                    // Bottom Tab Bar
                    djTabBar
                }
            } else {
                // Enhanced start streaming interface
                enhancedStartStreamView
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingStartStream) {
            StartDJStreamView()
        }
        .sheet(isPresented: $showingStreamSettings) {
            DJStreamSettingsView()
        }
        .fullScreenCover(item: $selectedParticipant) { participant in
            NavigationView {
                UserProfileView(userId: participant.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back") { selectedParticipant = nil }
                        }
                    }
            }
        }
    }
    
    // MARK: - Header Components
    
    private var professionalHeader: some View {
        ZStack {
            // Top corner buttons (very top of screen)
            VStack {
                HStack {
                    // X button (very top left)
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(18)
                    }
                    
                    Spacer()
                    
                    // Top right controls (very top right)
                    HStack(spacing: 8) {
                        // Escape button (minimize stream)
                        Button(action: {
                            djService.minimizeStream()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.purple.opacity(0.8))
                                .cornerRadius(15)
                        }
                        
                        // Settings button (very top right)
                        Button(action: {
                            showingStreamSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(18)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                
                Spacer()
            }
            
            // Centered title and genre (moved up)
            VStack(spacing: 4) {
                Text(djService.streamTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Genre badge (smaller and more compact)
                Text(djService.streamGenre)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 0)
        }
        .frame(height: 68)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var tabContentView: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: DJ Controls
            djControlsTabView
                .tag(DJTab.controls)
            
            // Tab 2: Participants
            participantsTabView
                .tag(DJTab.participants)
            
            // Tab 3: Chat
            chatTabView
                .tag(DJTab.chat)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    private var djTabBar: some View {
        HStack(spacing: 0) {
            ForEach(DJTab.allCases, id: \.rawValue) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.title2)
                            .foregroundColor(selectedTab == tab ? tab.color : .white.opacity(0.6))
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == tab ? tab.color : .white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedTab == tab ? tab.color.opacity(0.2) : Color.clear
                    )
                    .overlay(
                        Rectangle()
                            .frame(height: 3)
                            .foregroundColor(selectedTab == tab ? tab.color : Color.clear),
                        alignment: .bottom
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Tab Views
    
    // Tab 1: DJ Controls
    private var djControlsTabView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stream Stats
                streamStatsSection
                
                // Stream Management
                streamManagementSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.black.opacity(0.1))
    }
    
    private var streamStatsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Stream Statistics")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                CleanStatCard(
                    icon: "person.2.fill",
                    value: "\(djService.listenerCount)",
                    label: "Listeners",
                    color: .blue
                )
                
                CleanStatCard(
                    icon: "clock",
                    value: streamDuration,
                    label: "Duration",
                    color: .green
                )
            }
        }
    }
    
    private var streamManagementSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Stream Controls")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Button(action: {
                djService.stopDJStream()
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text("End Stream")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
            }
        }
    }
    
    // Tab 2: Participants
    private var participantsTabView: some View {
        VStack(spacing: 0) {
            // Header with view toggle
            HStack {
                Text("Listeners (\(demoParticipants.count))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // View toggle buttons
                HStack(spacing: 8) {
                    Button(action: { isGridView = false }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(isGridView ? .secondary : .purple)
                            .font(.title3)
                    }
                    
                    Button(action: { isGridView = true }) {
                        Image(systemName: "grid")
                            .foregroundColor(isGridView ? .purple : .secondary)
                            .font(.title3)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.black.opacity(0.3))
            
            // Participants content
            ScrollView {
                if isGridView {
                    participantsGridView
                } else {
                    participantsListView
                }
            }
            .background(Color.black.opacity(0.1))
        }
    }
    
    private var participantsListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(demoParticipants) { participant in
                FullParticipantRow(participant: participant)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedParticipant = participant
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var participantsGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(demoParticipants) { participant in
                ParticipantGridCard(participant: participant)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedParticipant = participant
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // Tab 3: Chat (Original Format - NO EMOJI REACTIONS)
    private var chatTabView: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Text("Live Chat")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("1 messages")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color.black.opacity(0.3))
            
            // Chat messages (Simple format without reactions)
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(demoChatMessages, id: \.id) { message in
                        SimpleChatMessageRow(
                            message: message,
                            isCurrentUser: message.userId == Auth.auth().currentUser?.uid
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.black.opacity(0.1))
            
            // Chat input (Simple)
            HStack(spacing: 12) {
                TextField("Send a message...", text: .constant(""))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(25)
                    .foregroundColor(.white)
                
                Button(action: {}) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.green)
                        .cornerRadius(22)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.6))
        }
    }
    
    // MARK: - Start Stream View
    
    private var enhancedStartStreamView: some View {
        startStreamView
    }
    
    private var startStreamView: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "music.mic")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Start Your DJ Stream")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Connect your audio equipment and start streaming live to your audience")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Quick start button
            Button(action: {
                Task {
                    let success = await djService.startDJStream(title: "Live Mix Session", genre: "Electronic")
                    if success {
                        print("🎧 DJ Stream started successfully!")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("Go Live Now")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 40)
            
            // Custom stream button
            Button(action: {
                showingStartStream = true
            }) {
                HStack {
                    Image(systemName: "gearshape")
                        .font(.title2)
                    Text("Custom Stream Setup")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                )
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Properties
    
    private var streamDuration: String {
        // Simple duration calculation
        return "12:34"
    }
    
    private var demoParticipants: [DemoParticipant] {
        return [
            DemoParticipant(id: "1", username: "MusicLover23", profileImage: "", isActive: true),
            DemoParticipant(id: "2", username: "BeatDropper", profileImage: "", isActive: true),
            DemoParticipant(id: "3", username: "VibeChecker", profileImage: "", isActive: false),
            DemoParticipant(id: "4", username: "TrackHunter", profileImage: "", isActive: true),
            DemoParticipant(id: "5", username: "DanceFloor", profileImage: "", isActive: true)
        ]
    }
    
    private var demoChatMessages: [SimpleChatMessage] {
        return [
            SimpleChatMessage(id: "1", userId: "demo1", username: "Yuppp", message: "joined the chat", timestamp: Date()),
        ]
    }
}

// MARK: - Supporting Structs

struct CleanStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct FullParticipantRow: View {
    let participant: DemoParticipant
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            Image(systemName: "person.crop.circle.fill")
                .font(.title)
                .foregroundColor(.purple.opacity(0.7))
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.username)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(participant.isActive ? .green : .gray)
                    
                    Text(participant.isActive ? "Active" : "Away")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Activity indicator
            if participant.isActive {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct ParticipantGridCard: View {
    let participant: DemoParticipant
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile image
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.purple.opacity(0.7))
                .frame(width: 60, height: 60)
                .background(Color(.systemGray6))
                .cornerRadius(30)
            
            // Username
            Text(participant.username)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Status
            HStack(spacing: 4) {
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundColor(participant.isActive ? .green : .gray)
                
                Text(participant.isActive ? "Active" : "Away")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
}

struct DemoParticipant: Identifiable {
    let id: String
    let username: String
    let profileImage: String
    let isActive: Bool
}

struct SimpleChatMessage: Identifiable {
    let id: String
    let userId: String
    let username: String
    let message: String
    let timestamp: Date
}

struct SimpleChatMessageRow: View {
    let message: SimpleChatMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if !isCurrentUser {
                // System message style
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    
                    Text(message.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(12)
            }
        }
    }
}

struct UserProfilePlaceholderView: View {
    let userId: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            Text("User Profile")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Profile for user: \(userId)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.purple)
        }
        .padding()
    }
}

struct StartDJStreamView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Start DJ Stream")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Custom stream setup coming soon...")
                .foregroundColor(.secondary)
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.purple)
        }
        .padding()
    }
}

struct DJStreamSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Stream Settings")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Settings coming soon...")
                .foregroundColor(.secondary)
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.purple)
        }
        .padding()
    }
}