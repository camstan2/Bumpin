import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LiveDJSessionsListView: View {
    @State private var sessions: [LiveDJSession] = []
    @State private var isLoading: Bool = true
    @State private var listener: ListenerRegistration? = nil
    @StateObject private var djStreamingManager = DJStreamingManager.shared
    @State private var followingIds: [String] = []
    @State private var selectedMode: Mode = .all
    @State private var selectedGenre: String? = nil
    @State private var sortMode: SortMode = .recent

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().padding()
                } else if sessions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "radio.fill").font(.system(size: 30)).foregroundColor(.gray)
                        Text("No live DJs").foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                } else {
                    List {
                        Section(header: header) {
                            ForEach(displaySessions) { session in
                                LiveDJCard(session: session, djStreamingManager: djStreamingManager)
                                    .listRowSeparator(.hidden)
                                    .onAppear { AnalyticsService.shared.logTap(category: "live_dj_impression", id: session.id) }
                                    .onTapGesture { AnalyticsService.shared.logTap(category: "live_dj_tap", id: session.id) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Live DJs")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
        .onAppear { attachListener(); loadFollowingIds(); AnalyticsService.shared.logTap(category: "see_all_live_djs_open", id: "explore") }
        .onDisappear { detachListener() }
    }

    @Environment(\.dismiss) private var dismiss

    private func attachListener() {
        listener?.remove()
        isLoading = true
        listener = Firestore.firestore().collection("liveDJSessions")
            .whereField("status", isEqualTo: DJStreamStatus.live.rawValue)
            .addSnapshotListener { snap, _ in
                let items = snap?.documents.compactMap { try? $0.data(as: LiveDJSession.self) } ?? []
                DispatchQueue.main.async {
                    self.sessions = items
                    self.isLoading = false
                }
            }
    }

    private func detachListener() {
        listener?.remove()
        listener = nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Browse").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Button("Go Live") {
                    AnalyticsService.shared.logTap(category: "go_live_tap", id: "see_all")
                    DJStreamingManager.shared.startDJSession(title: "Live Session")
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            // Mode picker
            Picker("Mode", selection: $selectedMode) {
                Text("All").tag(Mode.all)
                Text("Following").tag(Mode.following)
                Text("Genre").tag(Mode.genre)
            }
            .pickerStyle(.segmented)
            // Sort picker
            Picker("Sort", selection: $sortMode) {
                Text("Recent").tag(SortMode.recent)
                Text("Popular").tag(SortMode.popular)
            }
            .pickerStyle(.segmented)
            // Genre selector
            if selectedMode == .genre {
                HStack {
                    Menu { ForEach(availableGenres, id: \.self) { g in Button(g) { selectedGenre = g } } } label: {
                        HStack { Image(systemName: "line.3.horizontal.decrease.circle"); Text(selectedGenre ?? "Choose Genre") }
                    }
                    if selectedGenre != nil { Button("Clear") { selectedGenre = nil } .font(.caption) }
                }
            }
        }
        .padding(.bottom, 4)
    }

    private enum Mode: Hashable { case all, following, genre }
    private enum SortMode: Hashable { case recent, popular }
    private var availableGenres: [String] { Array(Set(sessions.compactMap { $0.genre })).sorted() }
    private var filteredSessions: [LiveDJSession] {
        switch selectedMode {
        case .all: return sessions
        case .following: return sessions.filter { followingIds.contains($0.djId) }
        case .genre: return sessions.filter { selectedGenre == nil || $0.genre == selectedGenre }
        }
    }
    private var displaySessions: [LiveDJSession] {
        let base = filteredSessions
        switch sortMode {
        case .recent:
            return base.sorted { ($0.startedAt ?? $0.createdAt) > ($1.startedAt ?? $1.createdAt) }
        case .popular:
            return base.sorted { $0.listenerCount > $1.listenerCount }
        }
    }
    private func loadFollowingIds() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { snap, _ in
            if let ids = snap?.data()? ["following"] as? [String] { self.followingIds = ids }
        }
    }
}

import SwiftUI
import FirebaseAuth

struct DJSessionView: View {
    let session: LiveDJSession
    @ObservedObject var djStreamingManager: DJStreamingManager
    @Environment(\.dismiss) private var dismiss
    @State private var chatMessage = ""
    @State private var showingListeners = false
    @FocusState private var chatFieldFocused: Bool
    @State private var transientError: String? = nil
    @State private var snackbar: (message: String, actionTitle: String?, onAction: (() -> Void)?)? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with session info
                sessionHeader
                
                // Now Playing Section
                nowPlayingSection
                
                // Chat Section
                chatSection
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DJ Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Leave Session") {
                        if djStreamingManager.isDJ {
                            djStreamingManager.endSession()
                        } else {
                            djStreamingManager.leaveSession()
                        }
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("\(djStreamingManager.activeListeners.count)") {
                        showingListeners = true
                    }
                    .foregroundColor(.blue)
                    .overlay(
                        Image(systemName: "person.2")
                            .font(.caption)
                            .offset(x: -10, y: 0)
                    )
                }
            }
            .overlay(alignment: .top) {
                if let err = transientError, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(8)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if let bar = snackbar {
                    HStack {
                        Text(bar.message).foregroundColor(.white)
                        Spacer()
                        if let title = bar.actionTitle, let onAction = bar.onAction {
                            Button(title) { onAction(); snackbar = nil }
                                .foregroundColor(.white)
                                .bold()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(10)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: djStreamingManager.streamError) { _, newVal in
                guard let msg = newVal, !msg.isEmpty else { return }
                transientError = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { transientError = nil }
                }
            }
        }
        .onAppear {
            // Join session if not already in one
            if !djStreamingManager.isStreaming {
                djStreamingManager.joinSession(session)
            }
        }
        .sheet(isPresented: $showingListeners) {
            ListenersView(
                listeners: djStreamingManager.activeListeners,
                manager: djStreamingManager,
                isDJ: djStreamingManager.isDJ,
                mutedUserIds: djStreamingManager.currentSession?.mutedUserIds ?? [],
                bannedUserIds: djStreamingManager.currentSession?.bannedUserIds ?? [],
                onSnackbar: { message, actionTitle, onAction in
                    snackbar = (message, actionTitle, onAction)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { snackbar = nil }
                    }
                }
            )
        }
    }
    
    // MARK: - Session Header
    
    private var sessionHeader: some View {
        VStack(spacing: 12) {
            // DJ Info
            HStack(spacing: 12) {
                // DJ Profile Picture
                if let profilePictureUrl = session.djProfilePictureUrl, let url = URL(string: profilePictureUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(String(session.djUsername.prefix(1)).uppercased())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.djUsername)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text(session.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(session.status == .live ? Color.red : Color.orange)
                                .frame(width: 8, height: 8)
                                .scaleEffect(session.status == .live ? 1.2 : 1.0)
                                .animation(session.status == .live ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: session.status)
                            Text(session.status.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.caption)
                            Text("\(djStreamingManager.activeListeners.count) listening")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Session Description
            if let description = session.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Tags
            if !session.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Now Playing Section
    
    private var nowPlayingSection: some View {
        VStack(spacing: 16) {
            if let currentTrack = djStreamingManager.currentTrack {
                HStack(spacing: 16) {
                    // Album Artwork
                    if let artworkUrl = currentTrack.artworkUrl, let url = URL(string: artworkUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Track Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now Playing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(currentTrack.title)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        
                        Text(currentTrack.artistName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if let albumName = currentTrack.albumName {
                            Text(albumName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                
                // DJ Controls (only for DJ)
                if djStreamingManager.isDJ {
                    HStack(spacing: 8) {
                        Button(djStreamingManager.currentSession?.status == .live ? "Pause" : "Go Live") {
                            if djStreamingManager.currentSession?.status == .live {
                                djStreamingManager.pausePlayback()
                            } else {
                                djStreamingManager.goLive()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Skip") { djStreamingManager.skipToNext() }
                            .buttonStyle(.bordered)
                        
                        Menu("More") {
                            Button(djStreamingManager.currentSession?.chatEnabled == true ? "Disable Chat" : "Enable Chat") {
                                djStreamingManager.toggleChatEnabled()
                            }
                            Menu("Max Listeners") {
                                Button("No Limit") { djStreamingManager.setMaxListeners(nil) }
                                Button("25") { djStreamingManager.setMaxListeners(25) }
                                Button("50") { djStreamingManager.setMaxListeners(50) }
                                Button("100") { djStreamingManager.setMaxListeners(100) }
                            }
                            Button("End Session", role: .destructive) {
                                // Confirm end
                                djStreamingManager.endSession()
                                dismiss()
                            }
                        }
                    }
                    .padding(.top, 4)
                    if djStreamingManager.currentSession?.status == .paused {
                        HStack {
                            Text("Session paused")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Resume Live") {
                                djStreamingManager.resumePlayback()
                            }
                            .font(.caption)
                        }
                        .padding(8)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                    }
                    djControls
                    // Fake level meter for UX polish
                    LevelMeterView()
                        .frame(height: 8)
                        .padding(.top, 6)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No track playing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if djStreamingManager.isDJ {
                        Text("Search and play music to start the session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - DJ Controls
    
    private var djControls: some View {
        HStack(spacing: 20) {
            Button(action: {
                // TODO: Implement previous track
            }) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                if djStreamingManager.currentSession?.status == .live {
                    djStreamingManager.pausePlayback()
                } else {
                    djStreamingManager.resumePlayback()
                }
            }) {
                Image(systemName: djStreamingManager.currentSession?.status == .live ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                djStreamingManager.skipToNext()
            }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.top, 8)
    }

    // Simple level meter using FakeMeteringTransport if active
    struct LevelMeterView: View {
        @StateObject private var meter = FakeMeteringTransport()
        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4).fill(Color.green)
                        .frame(width: CGFloat(meter.level) * geo.size.width)
                }
            }
            .onAppear {
                Task { try? await meter.startStream() }
            }
            .onDisappear {
                Task { await meter.stopStream() }
            }
        }
    }
    
    // MARK: - Chat Section
    
    private var chatSection: some View {
        VStack(spacing: 0) {
            // Chat Header
            HStack {
                Text("Chat")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(djStreamingManager.chatMessages.count) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(BlockingService.shared.filterChatMessages(djStreamingManager.chatMessages)) { message in
                            ChatMessageRow(message: message)
                        }
                    }
                    .padding()
                }
                .onChange(of: djStreamingManager.chatMessages.count) { _ in
                    if let lastMessage = djStreamingManager.chatMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Chat Input (disabled if chat disabled and user not DJ)
            VStack(spacing: 6) {
                if djStreamingManager.currentSession?.chatEnabled == false && !djStreamingManager.isDJ {
                    Text("Chat is disabled by the DJ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 12) {
                    TextField("Send a message...", text: $chatMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($chatFieldFocused)
                        .disabled(djStreamingManager.currentSession?.chatEnabled == false && !djStreamingManager.isDJ)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(chatMessage.isEmpty ? .gray : .blue)
                    }
                    .disabled(chatMessage.isEmpty || (djStreamingManager.currentSession?.chatEnabled == false && !djStreamingManager.isDJ))
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Helper Functions
    
    private func sendMessage() {
        guard !chatMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        djStreamingManager.sendChatMessage(chatMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        chatMessage = ""
        chatFieldFocused = false
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    let message: DJChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // User Profile Picture
            if let profilePictureUrl = message.userProfilePictureUrl, let url = URL(string: profilePictureUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(String(message.username.prefix(1)).uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(message.username)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(message.isFromDJ ? .red : .primary)
                    
                    if message.isFromDJ {
                        Text("DJ")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    Text(timeAgoString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Report button (only show for other users' messages)
                    if let currentUserId = Auth.auth().currentUser?.uid, currentUserId != message.userId {
                        Menu {
                            ReportMenuButton(
                                contentId: message.id,
                                contentType: .chatMessage,
                                reportedUserId: message.userId,
                                reportedUsername: message.username,
                                contentPreview: message.message
                            )
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Text(message.message)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Listeners View

struct ListenersView: View {
    let listeners: [DJSessionListener]
    let manager: DJStreamingManager
    let isDJ: Bool
    let mutedUserIds: [String]
    let bannedUserIds: [String]
    let onSnackbar: (String, String?, (() -> Void)?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(listeners) { listener in
                HStack(spacing: 12) {
                    // Profile Picture
                    if let profilePictureUrl = listener.userProfilePictureUrl, let url = URL(string: profilePictureUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(listener.username.prefix(1)).uppercased())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(listener.username)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Joined \(timeAgoString(from: listener.joinedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if isDJ {
                        Menu("Actions") {
                            if mutedUserIds.contains(listener.userId) {
                                Button("Unmute") {
                                    manager.unmute(userId: listener.userId)
                                }
                            } else {
                                Button("Mute") {
                                    manager.mute(userId: listener.userId)
                                    onSnackbar("Muted \(listener.username)", "Undo") { manager.unmute(userId: listener.userId) }
                                }
                            }
                            if bannedUserIds.contains(listener.userId) {
                                Button("Unban") {
                                    manager.unban(userId: listener.userId)
                                }
                            } else {
                                Button("Ban", role: .destructive) {
                                    manager.ban(userId: listener.userId)
                                    onSnackbar("Banned \(listener.username)", "Undo") { manager.unban(userId: listener.userId) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Listeners (\(listeners.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    DJSessionView(
        session: LiveDJSession(
            djId: "test",
            djUsername: "DJ Mike",
            title: "Late Night Vibes",
            description: "Chill electronic music for late night studying",
            status: .live,
            currentTrack: CurrentTrack(
                trackId: "1",
                title: "Midnight City",
                artistName: "M83",
                albumName: "Hurry Up, We're Dreaming"
            ),
            listenerCount: 42,
            tags: ["Electronic", "Chill", "Study"]
        ),
        djStreamingManager: DJStreamingManager.shared
    )
} 

