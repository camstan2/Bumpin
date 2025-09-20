import Foundation
import AVFoundation
import MediaPlayer
import MusicKit
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - DJ Streaming Manager

@MainActor
class DJStreamingManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentSession: LiveDJSession?
    @Published var isStreaming = false
    @Published var isDJ = false
    @Published var currentTrack: CurrentTrack?
    @Published var chatMessages: [DJChatMessage] = []
    @Published var activeListeners: [DJSessionListener] = []
    @Published var streamError: String?
    private var lastDjChatSentAt: Date = .distantPast
    
    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private let audioPlayerNode = AVAudioPlayerNode()
    private let audioSession = AVAudioSession.sharedInstance()
    private var currentAudioFile: AVAudioFile?
    private var chatListener: ListenerRegistration?
    private var sessionListener: ListenerRegistration?
    private var listenersListener: ListenerRegistration?
    private var musicPlayer = ApplicationMusicPlayer.shared
    private var cancellables = Set<AnyCancellable>()
    enum TransportKind { case real, noop }
    private var transport: DJTransport = RealBackendTransport()
    private(set) var transportKind: TransportKind = .real
    func setTransport(_ kind: TransportKind) {
        transportKind = kind
        switch kind {
        case .real: transport = RealBackendTransport()
        case .noop: transport = NoopDJTransport()
        }
    }
    private var heartbeatTimer: Timer?
    
    // MARK: - Singleton
    static let shared = DJStreamingManager()
    
    override init() {
        super.init()
        setupAudioEngine()
        setupMusicPlayerObservation()
    }
    
    deinit {
        Task { @MainActor in
            stopStreaming()
        }
        audioEngine.stop()
        chatListener?.remove()
        sessionListener?.remove()
        listenersListener?.remove()
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        // Configure audio session for live streaming
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        // Setup audio engine
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    // MARK: - Music Player Observation
    
    private func setupMusicPlayerObservation() {
        // Observe music player state changes - simplified for now
        // Note: MusicKit's ApplicationMusicPlayer doesn't have a direct state publisher
        // This would need to be implemented with periodic checks or other methods
    }
    
    private func handleMusicPlayerStateChange(_ state: ApplicationMusicPlayer.State) {
        // Update streaming state based on music player
        if isDJ && isStreaming {
            // Handle play/pause state changes
            switch state.playbackStatus {
            case .playing:
                updateSessionStatus(.live)
            case .paused:
                updateSessionStatus(.paused)
            case .stopped:
                // Don't automatically end session on stop
                break
            default:
                break
            }
        }
    }
    
    private func handleCurrentTrackChange(_ entry: MusicKit.ApplicationMusicPlayer.Queue.Entry?) {
        guard isDJ && isStreaming, let entry = entry else { return }
        
        // Create CurrentTrack from queue entry
        let track = CurrentTrack(
            trackId: String(describing: entry.id),
            title: entry.title ?? "Unknown Title",
            artistName: "Unknown Artist", // Will need proper implementation with streaming setup
            albumName: nil,
            artworkUrl: nil
        )
        
        currentTrack = track
        Task { await transport.sendNowPlaying(track) }
        
        // Update the session with the new track
        if let session = currentSession {
            LiveDJSession.updateCurrentTrack(sessionId: session.id, track: track) { error in
                if let error = error {
                    Task { @MainActor in
                        self.streamError = "Failed to update track: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    // MARK: - DJ Session Management
    
    func startDJSession(title: String, description: String? = nil, genre: String? = nil, tags: [String] = []) {
        guard let currentUser = Auth.auth().currentUser else {
            streamError = "User not authenticated"
            return
        }
        
        Task {
            do {
                // Fetch user profile to get username
                let userDoc = try await Firestore.firestore().collection("users").document(currentUser.uid).getDocument()
                let userProfile = try? userDoc.data(as: UserProfile.self)
                
                let session = LiveDJSession(
                    djId: currentUser.uid,
                    djUsername: userProfile?.username ?? "Unknown DJ",
                    djProfilePictureUrl: userProfile?.profilePictureUrl,
                    title: title,
                    description: description,
                    genre: genre,
                    tags: tags
                )
                
                try await LiveDJSession.createSession(session)
                
                await MainActor.run {
                    self.currentSession = session
                    self.isDJ = true
                    self.isStreaming = true
                }
                AnalyticsService.shared.logDJ(action: "start_session", props: ["sessionId": session.id])
                CrashReporter.shared.setKey("dj.sessionId", value: session.id)
                CrashReporter.shared.setKey("dj.djId", value: session.djId)
                
                // Connect transport
                try? await self.transport.connect(sessionId: session.id)
                try? await self.transport.startStream()
                
                // Start listening to session updates
                startListeningToSession(sessionId: session.id)
                startHeartbeat()
                
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to start DJ session: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func endSession() {
        guard isDJ, let session = currentSession else { return }
        
        Task {
            do {
                // Stop music playback
                musicPlayer.stop()
                await transport.stopStream()
                await transport.disconnect()
                
                // Update session status to ended
                try await LiveDJSession.updateStatus(sessionId: session.id, status: .ended)
                
                await MainActor.run {
                    self.currentSession = nil
                    self.isDJ = false
                    self.isStreaming = false
                    self.currentTrack = nil
                    self.chatMessages = []
                    self.activeListeners = []
                }
                AnalyticsService.shared.logDJ(action: "end_session", props: ["sessionId": session.id])
                CrashReporter.shared.setKey("dj.sessionId", value: "")
                CrashReporter.shared.setKey("dj.djId", value: "")
                
                // Remove listeners
                sessionListener?.remove()
                chatListener?.remove()
                listenersListener?.remove()
                stopHeartbeat()
                
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to end session: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func joinSession(_ session: LiveDJSession) {
        guard let currentUser = Auth.auth().currentUser else {
            streamError = "User not authenticated"
            return
        }
        
        Task {
            do {
                // Guardrails: fetch latest session and enforce bans/capacity
                let db = Firestore.firestore()
                let sessionSnap = try await db.collection("liveDJSessions").document(session.id).getDocument()
                guard var latest = try? sessionSnap.data(as: LiveDJSession.self) else {
                    await MainActor.run { self.streamError = "Session not found" }
                    return
                }
                CrashReporter.shared.setKey("dj.sessionId", value: latest.id)
                if let banned = latest.bannedUserIds, banned.contains(currentUser.uid) {
                    await MainActor.run { self.streamError = "You have been banned from this session." }
                    return
                }
                if let max = latest.maxListeners, max > 0 {
                    let activeCount = try await db.collection("liveDJSessions").document(session.id).collection("listeners").whereField("isActive", isEqualTo: true).getDocuments().documents.count
                    if activeCount >= max {
                        await MainActor.run { self.streamError = "Session is full. Try again later." }
                        return
                    }
                }
                // Get user profile
                let userDoc = try await db.collection("users").document(currentUser.uid).getDocument()
                let userProfile = try? userDoc.data(as: UserProfile.self)
                
                let listener = DJSessionListener(
                    sessionId: session.id,
                    userId: currentUser.uid,
                    username: userProfile?.username ?? "Unknown User",
                    userProfilePictureUrl: userProfile?.profilePictureUrl,
                    joinedAt: Date()
                )
                
                try await DJSessionListener.create(listener)
                
                await MainActor.run {
                    self.currentSession = latest
                    self.isDJ = false
                }
                AnalyticsService.shared.logDJ(action: "join_session", props: ["sessionId": latest.id])
                CrashReporter.shared.setKey("dj.sessionId", value: latest.id)
                CrashReporter.shared.setKey("dj.djId", value: latest.djId)
                
                // Start listening to session updates
                startListeningToSession(sessionId: session.id)
                startHeartbeat()
                // Attempt initial sync if a track is already live
                await MainActor.run {
                    if let t = latest.currentTrack { self.syncListenerPlaybackIfNeeded(with: t) }
                }
                
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to join session: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func leaveSession() {
        guard let currentUser = Auth.auth().currentUser,
              let session = currentSession else { return }
        
        Task {
            do {
                try await DJSessionListener.remove(sessionId: session.id, userId: currentUser.uid)
                
                await MainActor.run {
                    self.stopListening()
                    self.currentSession = nil
                    self.isDJ = false
                    self.isStreaming = false
                    self.chatMessages = []
                    self.activeListeners = []
                }
                AnalyticsService.shared.logDJ(action: "leave_session", props: ["sessionId": session.id])
                await self.transport.disconnect()
                stopHeartbeat()
                CrashReporter.shared.setKey("dj.sessionId", value: "")
                CrashReporter.shared.setKey("dj.djId", value: "")
                
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to leave session: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func stopStreaming() {
        isStreaming = false
        isDJ = false
        currentSession = nil
        currentTrack = nil
        chatMessages.removeAll()
        activeListeners.removeAll()
        
        stopListening()
        
        // Stop music player if necessary
        Task {
            try? await musicPlayer.stop()
        }
    }
    
    // MARK: - Session Listeners
    
    private func startListeningToSession(sessionId: String) {
        let db = Firestore.firestore()
        
        // Listen to session updates
        sessionListener = db.collection("liveDJSessions").document(sessionId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.streamError = "Session listening error: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let document = documentSnapshot, document.exists,
                          let session = try? document.data(as: LiveDJSession.self) else {
                        self?.streamError = "Session not found"
                        return
                    }
                    
                    self?.currentSession = session
                    self?.currentTrack = session.currentTrack
                    if self?.isDJ == false, let t = session.currentTrack {
                        self?.syncListenerPlaybackIfNeeded(with: t)
                    }
                }
            }
        
        // Listen to chat messages
        chatListener = db.collection("liveDJSessions").document(sessionId)
            .collection("chatMessages")
            .order(by: "timestamp")
            .addSnapshotListener { [weak self] querySnapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.streamError = "Chat listening error: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    self?.chatMessages = documents.compactMap { document in
                        try? document.data(as: DJChatMessage.self)
                    }
                }
            }
        
        // Listen to listeners
        listenersListener = db.collection("liveDJSessions").document(sessionId)
            .collection("listeners")
            .addSnapshotListener { [weak self] querySnapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.streamError = "Listeners error: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else { return }
                    
                    self?.activeListeners = documents.compactMap { document in
                        try? document.data(as: DJSessionListener.self)
                    }
                    // Update listenerCount in session doc (best-effort)
                    if let sessionId = self?.currentSession?.id {
                        LiveDJSession.updateListenerCount(sessionId: sessionId, count: self?.activeListeners.count ?? 0) { _ in }
                    }
                }
            }
    }
    
    func stopListening() {
        sessionListener?.remove()
        chatListener?.remove()
        listenersListener?.remove()
        sessionListener = nil
        chatListener = nil
        listenersListener = nil
    }

    // MARK: - Heartbeat Presence
    private func startHeartbeat() {
        stopHeartbeat()
        guard let sessionId = currentSession?.id, let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            let ref = db.collection("liveDJSessions").document(sessionId).collection("listeners").document(uid)
            ref.setData(["isActive": true, "joinedAt": FieldValue.serverTimestamp() as Any, "lastSeenAt": FieldValue.serverTimestamp()], merge: true)
        }
        heartbeatTimer?.tolerance = 5
        heartbeatTimer?.fire()
    }
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    // MARK: - Music Playback
    
    func playTrack(_ track: CurrentTrack) {
        guard isDJ, let session = currentSession else {
            streamError = "Only DJ can control playback"
            return
        }
        
        Task {
            do {
                // Request music authorization if needed
                let status = await MusicAuthorization.request()
                guard status == .authorized else {
                    await MainActor.run {
                        self.streamError = "Music authorization required"
                    }
                    return
                }
                
                // Update current track in session
                LiveDJSession.updateCurrentTrack(sessionId: session.id, track: track) { [weak self] error in
                    Task { @MainActor in
                        if let error = error {
                            self?.streamError = "Failed to update track: \(error.localizedDescription)"
                            return
                        }
                        
                        self?.currentTrack = track
                        
                        // Play the track using MediaPlayer
                        self?.playMusicKitTrack(track)
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to play track: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func playMusicKitTrack(_ track: CurrentTrack) {
        Task {
            do {
                let status = await MusicAuthorization.request()
                guard status == .authorized else { await MainActor.run { self.streamError = "Music authorization required" }; return }
                let song = try await loadSong(for: track)
                try await musicPlayer.queue.insert(song, position: .tail)
                try await musicPlayer.play()
                Task { await self.transport.sendNowPlaying(track) }
            } catch {
                await MainActor.run { self.streamError = "Playback error: \(error.localizedDescription)" }
            }
        }
    }
    
    func pausePlayback() {
        guard isDJ else { return }
        musicPlayer.pause()
        updateSessionStatus(.paused)
        if let sessionId = currentSession?.id { AnalyticsService.shared.logDJ(action: "pause", props: ["sessionId": sessionId]) }
    }
    
    func resumePlayback() {
        guard isDJ else { return }
        
        Task {
            do {
                try await musicPlayer.play()
                updateSessionStatus(.live)
                if let sessionId = currentSession?.id { AnalyticsService.shared.logDJ(action: "resume", props: ["sessionId": sessionId]) }
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to resume playback: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func skipToNext() {
        guard isDJ else { return }
        
        Task {
            do {
                try await musicPlayer.skipToNextEntry()
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to skip to next track: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Status Controls
    func goLive() {
        updateSessionStatus(.live)
        if let sessionId = currentSession?.id { AnalyticsService.shared.logDJ(action: "go_live", props: ["sessionId": sessionId]) }
    }
    
    // MARK: - Session Status Updates
    
    private func updateSessionStatus(_ status: DJStreamStatus) {
        guard let session = currentSession else { return }
        
        Task {
            do {
                try await LiveDJSession.updateStatus(sessionId: session.id, status: status)
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to update session status: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Listener Sync
    private func syncListenerPlaybackIfNeeded(with track: CurrentTrack) {
        guard !isDJ else { return }
        Task {
            do {
                let status = await MusicAuthorization.request()
                guard status == .authorized else { await MainActor.run { self.streamError = "Music authorization required" }; return }
                let song = try await loadSong(for: track)
                try await musicPlayer.queue.insert(song, position: .afterCurrentEntry)
                try await musicPlayer.play()
                // Seek to current offset since DJ started the track
                let elapsed = max(0, Date().timeIntervalSince(track.startedAt))
                musicPlayer.playbackTime = elapsed
            } catch {
                await MainActor.run { self.streamError = "Sync error: \(error.localizedDescription)" }
            }
        }
    }

    private func loadSong(for track: CurrentTrack) async throws -> MusicKit.Song {
        let id = MusicKit.Song.ID(rawValue: track.trackId)
        let req = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: id)
        let resp = try await req.response()
        if let song = resp.items.first { return song }
        // Fallback: search by title and artist
        var query = track.title
        if !track.artistName.isEmpty { query += " " + track.artistName }
        var search = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
        search.limit = 1
        let result = try await search.response()
        if let song = result.songs.first { return song }
        throw NSError(domain: "DJStreaming", code: 404, userInfo: [NSLocalizedDescriptionKey: "Song not found in catalog"])
    }
    
    // MARK: - Utility Functions
    
    func fetchSession(sessionId: String, completion: @escaping (LiveDJSession?, Error?) -> Void) {
        LiveDJSession.fetchSession(sessionId: sessionId, completion: completion)
    }
    
    // MARK: - Chat Management
    
    func sendChatMessage(_ message: String) {
        guard let currentUser = Auth.auth().currentUser,
              var session = currentSession else {
            streamError = "Cannot send message"
            return
        }
        if session.chatEnabled == false { streamError = "Chat is disabled"; return }
        if let muted = session.mutedUserIds, muted.contains(currentUser.uid) { streamError = "You are muted"; return }
        if let banned = session.bannedUserIds, banned.contains(currentUser.uid) { streamError = "You are banned"; return }
        // Throttle chat send to 5/sec
        let now = Date()
        if now.timeIntervalSince(lastDjChatSentAt) < 0.2 { return }
        lastDjChatSentAt = now
        
        Task {
            // Content moderation check
            let moderationResult = await ContentModerationService.shared.moderateChatMessage(message, userId: currentUser.uid)
            if !moderationResult.isAllowed {
                await MainActor.run {
                    self.streamError = "Message blocked: \(moderationResult.reason)"
                }
                return
            }
            
            do {
                let userDoc = try await Firestore.firestore().collection("users").document(currentUser.uid).getDocument()
                let userProfile = try? userDoc.data(as: UserProfile.self)
                
                let chatMessage = DJChatMessage(
                    sessionId: session.id,
                    userId: currentUser.uid,
                    username: userProfile?.username ?? "Unknown User",
                    userProfilePictureUrl: userProfile?.profilePictureUrl,
                    message: message,
                    timestamp: Date()
                )
                
                try await DJChatMessage.create(chatMessage)
                
            } catch {
                await MainActor.run {
                    self.streamError = "Failed to send message: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Moderation
    func toggleChatEnabled() {
        guard isDJ, var s = currentSession else { return }
        s.chatEnabled.toggle()
        currentSession = s
        LiveDJSession.updateSession(s) { _ in }
        AnalyticsService.shared.logDJ(action: "toggle_chat", props: ["sessionId": s.id, "enabled": s.chatEnabled])
    }
    func setMaxListeners(_ value: Int?) {
        guard isDJ, var s = currentSession else { return }
        s.maxListeners = value
        currentSession = s
        LiveDJSession.updateSession(s) { _ in }
        AnalyticsService.shared.logDJ(action: "set_max_listeners", props: ["sessionId": s.id, "value": value as Any])
    }
    func mute(userId: String) {
        guard isDJ, var s = currentSession else { return }
        var arr = s.mutedUserIds ?? []
        if !arr.contains(userId) { arr.append(userId) }
        s.mutedUserIds = arr
        currentSession = s
        LiveDJSession.updateSession(s) { _ in }
        AnalyticsService.shared.logDJ(action: "mute", props: ["sessionId": s.id, "targetUserId": userId])
    }
    func ban(userId: String) {
        guard isDJ, var s = currentSession else { return }
        var arr = s.bannedUserIds ?? []
        if !arr.contains(userId) { arr.append(userId) }
        s.bannedUserIds = arr
        currentSession = s
        LiveDJSession.updateSession(s) { _ in }
        AnalyticsService.shared.logDJ(action: "ban", props: ["sessionId": s.id, "targetUserId": userId])
    }
    func unmute(userId: String) {
        guard isDJ, var s = currentSession else { return }
        var arr = s.mutedUserIds ?? []
        arr.removeAll { $0 == userId }
        s.mutedUserIds = arr
        currentSession = s
        LiveDJSession.updateSession(s) { _ in }
        AnalyticsService.shared.logDJ(action: "unmute", props: ["sessionId": s.id, "targetUserId": userId])
    }
    func unban(userId: String) {
        guard isDJ, var s = currentSession else { return }
        var arr = s.bannedUserIds ?? []
        arr.removeAll { $0 == userId }
        s.bannedUserIds = arr
        currentSession = s
        LiveDJSession.updateSession(s) { _ in }
        AnalyticsService.shared.logDJ(action: "unban", props: ["sessionId": s.id, "targetUserId": userId])
    }
} 