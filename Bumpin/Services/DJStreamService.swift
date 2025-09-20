import Foundation
import AVFoundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - DJ Stream Service

@MainActor
class DJStreamService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isStreaming = false
    @Published var isRecording = false
    @Published var streamTitle = ""
    @Published var streamGenre = "Electronic"
    @Published var listenerCount = 0
    @Published var audioLevel: Float = 0.0
    @Published var streamQuality: StreamQuality = .high
    @Published var errorMessage: String?
    
    // Stream minimization state
    @Published var isStreamMinimized: Bool = false
    @Published var showStreamView: Bool = false
    
    // MARK: - Stream Models
    
    struct DJStream: Codable, Identifiable {
        let id: String
        let djUserId: String
        let djUsername: String
        let djProfileImage: String?
        let title: String
        let genre: String
        let startTime: Date
        let isLive: Bool
        let listenerCount: Int
        let streamQuality: String
        let audioStreamURL: String?
        let chatRoomId: String
        
        enum CodingKeys: String, CodingKey {
            case id, djUserId, djUsername, djProfileImage, title, genre, startTime, isLive, listenerCount, streamQuality, audioStreamURL, chatRoomId
        }
    }
    
    enum StreamQuality: String, CaseIterable {
        case low = "Low (64kbps)"
        case medium = "Medium (128kbps)"
        case high = "High (256kbps)"
        case ultra = "Ultra (320kbps)"
        
        var bitrate: Int {
            switch self {
            case .low: return 64000
            case .medium: return 128000
            case .high: return 256000
            case .ultra: return 320000
            }
        }
    }
    
    // MARK: - Audio Engine Properties
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession?
    private var streamBuffer: AVAudioPCMBuffer?
    
    // MARK: - Firebase Properties
    
    private let db = Firestore.firestore()
    @Published var currentStreamId: String?
    private var streamListener: ListenerRegistration?
    private var audioLevelTimer: Timer?
    
    // MARK: - Singleton
    
    static let shared = DJStreamService()
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        // Clean up without calling @MainActor methods
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        streamListener?.remove()
        audioLevelTimer?.invalidate()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure for recording and playback
            try audioSession?.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession?.setActive(true)
            
            print("✅ DJ Audio session configured successfully")
        } catch {
            print("❌ DJ Audio session setup failed: \(error)")
            errorMessage = "Audio setup failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Stream Management
    
    func startDJStream(title: String, genre: String) async -> Bool {
        guard !isStreaming else {
            print("⚠️ Already streaming")
            return false
        }
        
        // Request microphone permission
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            errorMessage = "Microphone permission required for DJ streaming"
            return false
        }
        
        // Setup audio engine
        guard setupAudioEngine() else {
            errorMessage = "Failed to setup audio engine"
            return false
        }
        
        // Create stream in Firebase
        guard let streamId = await createStreamInFirebase(title: title, genre: genre) else {
            errorMessage = "Failed to create stream"
            return false
        }
        
        // Start audio capture
        guard startAudioCapture() else {
            errorMessage = "Failed to start audio capture"
            return false
        }
        
        currentStreamId = streamId
        isStreaming = true
        self.streamTitle = title
        self.streamGenre = genre
        
        // Start monitoring audio levels
        startAudioLevelMonitoring()
        
        print("🎧 DJ Stream started: \(title)")
        return true
    }
    
    func stopDJStream() {
        guard isStreaming else { return }
        
        stopAudioCapture()
        stopAudioLevelMonitoring()
        
        if let streamId = currentStreamId {
            Task {
                await endStreamInFirebase(streamId: streamId)
            }
        }
        
        isStreaming = false
        currentStreamId = nil
        streamTitle = ""
        listenerCount = 0
        
        print("🛑 DJ Stream stopped")
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() -> Bool {
        audioEngine = AVAudioEngine()
        
        guard let engine = audioEngine else {
            print("❌ Failed to create audio engine")
            return false
        }
        
        inputNode = engine.inputNode
        
        // Configure input format
        let inputFormat = inputNode?.outputFormat(forBus: 0)
        
        // Setup audio processing chain
        setupAudioProcessingChain()
        
        do {
            try engine.start()
            print("✅ Audio engine started successfully")
            return true
        } catch {
            print("❌ Audio engine start failed: \(error)")
            return false
        }
    }
    
    private func setupAudioProcessingChain() {
        guard let engine = audioEngine,
              let input = inputNode else { return }
        
        // Create mixer node for effects
        let mixer = AVAudioMixerNode()
        engine.attach(mixer)
        
        // Connect input to mixer
        engine.connect(input, to: mixer, format: input.outputFormat(forBus: 0))
        
        // Connect mixer to output
        engine.connect(mixer, to: engine.mainMixerNode, format: mixer.outputFormat(forBus: 0))
        
        // Install tap for streaming and level monitoring
        input.installTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0)) { [weak self] buffer, time in
            DispatchQueue.main.async {
                self?.processAudioBuffer(buffer, time: time)
            }
        }
    }
    
    // MARK: - Audio Capture
    
    private func startAudioCapture() -> Bool {
        guard let engine = audioEngine else {
            print("❌ Audio engine not initialized")
            return false
        }
        
        do {
            if !engine.isRunning {
                try engine.start()
            }
            isRecording = true
            print("✅ Audio capture started")
            return true
        } catch {
            print("❌ Audio capture failed: \(error)")
            return false
        }
    }
    
    private func stopAudioCapture() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        isRecording = false
        print("🛑 Audio capture stopped")
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Calculate audio level for UI
        updateAudioLevel(from: buffer)
        
        // Stream audio to listeners (simplified for now)
        streamAudioToListeners(buffer)
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        
        // Convert to dB and normalize
        let db = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (db + 60) / 60)) // Normalize -60dB to 0dB range
        
        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }
    
    private func streamAudioToListeners(_ buffer: AVAudioPCMBuffer) {
        // TODO: Implement WebRTC streaming or similar
        // For now, this is a placeholder for the streaming logic
        
        // In production, this would:
        // 1. Encode audio buffer to compressed format
        // 2. Send to streaming server/WebRTC peers
        // 3. Handle connection management
        
        print("🎵 Streaming audio buffer: \(buffer.frameLength) frames")
    }
    
    // MARK: - Permissions
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Firebase Stream Management
    
    private func createStreamInFirebase(title: String, genre: String) async -> String? {
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ No authenticated user for stream creation")
            return nil
        }
        
        let streamId = UUID().uuidString
        let chatRoomId = "dj_chat_\(streamId)"
        
        let streamData: [String: Any] = [
            "id": streamId,
            "djUserId": firebaseUser.uid,
            "djUsername": firebaseUser.displayName ?? "DJ User",
            "djProfileImage": firebaseUser.photoURL?.absoluteString ?? "",
            "title": title,
            "genre": genre,
            "startTime": Timestamp(),
            "isLive": true,
            "listenerCount": 0,
            "streamQuality": streamQuality.rawValue,
            "audioStreamURL": "", // Will be populated by streaming service
            "chatRoomId": chatRoomId,
            "createdAt": Timestamp()
        ]
        
        do {
            try await db.collection("djStreams").document(streamId).setData(streamData)
            print("✅ DJ Stream created in Firebase: \(streamId)")
            return streamId
        } catch {
            print("❌ Failed to create stream in Firebase: \(error)")
            return nil
        }
    }
    
    private func endStreamInFirebase(streamId: String) async {
        do {
            try await db.collection("djStreams").document(streamId).updateData([
                "isLive": false,
                "endTime": Timestamp(),
                "listenerCount": 0
            ])
            print("✅ DJ Stream ended in Firebase")
        } catch {
            print("❌ Failed to end stream in Firebase: \(error)")
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Audio level is updated in processAudioBuffer
            // This timer ensures UI updates even during silence
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
    
    // MARK: - Stream Discovery
    
    func loadLiveStreams() async -> [DJStream] {
        do {
            let snapshot = try await db.collection("djStreams")
                .whereField("isLive", isEqualTo: true)
                .order(by: "startTime", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            let streams = snapshot.documents.compactMap { doc -> DJStream? in
                try? doc.data(as: DJStream.self)
            }
            
            print("✅ Loaded \(streams.count) live DJ streams")
            return streams
        } catch {
            print("❌ Failed to load live streams: \(error)")
            return []
        }
    }
    
    // MARK: - Stream Minimization Functions
    
    /// Minimizes the DJ stream - keeps streaming but hides UI
    func minimizeStream() {
        guard isStreaming else { return }
        
        print("🔽 Minimizing DJ stream: \(streamTitle)")
        
        isStreamMinimized = true
        showStreamView = false
        
        // Keep streaming active in background
        // Audio engine continues running
        // Firebase listeners remain active
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("DJStreamMinimized"), object: nil)
    }
    
    /// Restores the DJ stream from minimized state
    func restoreStream() {
        guard isStreaming, isStreamMinimized else { return }
        
        print("🔼 Restoring DJ stream: \(streamTitle)")
        
        isStreamMinimized = false
        showStreamView = true
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("DJStreamRestored"), object: nil)
    }
    
    // MARK: - Demo Functions
    
    func createDemoStream() {
        Task {
            let success = await startDJStream(title: "Saturday Night Mix", genre: "House")
            if success {
                print("🎧 Demo DJ stream started!")
            }
        }
    }
}

// MARK: - Stream Errors

enum DJStreamError: Error, LocalizedError {
    case audioEngineSetupFailed
    case microphonePermissionDenied
    case streamCreationFailed
    case audioCaptureFailed
    
    var errorDescription: String? {
        switch self {
        case .audioEngineSetupFailed:
            return "Failed to setup audio engine"
        case .microphonePermissionDenied:
            return "Microphone permission required"
        case .streamCreationFailed:
            return "Failed to create stream"
        case .audioCaptureFailed:
            return "Failed to capture audio"
        }
    }
}
