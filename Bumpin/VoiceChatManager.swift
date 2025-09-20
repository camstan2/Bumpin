//
//  VoiceChatManager.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import AVFoundation
import FirebaseFirestore
import FirebaseAuth

class VoiceChatManager: ObservableObject {
    @Published var isVoiceChatActive = false
    @Published var isSpeaking = false
    @Published var isMuted = false
    @Published var speakers: [VoiceSpeaker] = []
    @Published var listeners: [VoiceListener] = []
    @Published var currentSpeaker: VoiceSpeaker?
    @Published var speakerRequests: [SpeakerRequest] = []
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputNode: AVAudioOutputNode?
    private var mixer: AVAudioMixerNode?
    
    private var partyId: String?
    private var currentUserId: String?
    private var currentUserName: String?
    
    // Audio session for voice chat
    private var voiceChatSession: AVAudioSession?
    private var requestsListener: ListenerRegistration?
    
    init() {
        setupAudioSession()
        setupNotifications()
    }
    
    // MARK: - Audio Setup
    
    private func setupAudioSession() {
        voiceChatSession = AVAudioSession.sharedInstance()
        
        do {
            // Use .voiceChat mode which provides automatic echo cancellation
            // and prevents hearing your own voice through the speakers
            try voiceChatSession?.setCategory(
                .playAndRecord, 
                mode: .voiceChat, 
                options: [
                    .allowBluetooth, 
                    .allowBluetoothA2DP,
                    .defaultToSpeaker // Use speaker by default, not earpiece
                ]
            )
            
            // Set preferred input/output settings for better echo cancellation
            try voiceChatSession?.setPreferredIOBufferDuration(0.005) // Low latency
            
            try voiceChatSession?.setActive(true)
            print("✅ Audio session configured with echo cancellation")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio session interrupted - pause voice chat
            pauseVoiceChat()
        case .ended:
            // Audio session resumed - resume voice chat if it was active
            if isVoiceChatActive {
                resumeVoiceChat()
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        // Handle audio route changes (headphones, speaker, etc.)
        print("🎤 Audio route changed")
    }
    
    // MARK: - Voice Chat Control
    
    func startVoiceChat(partyId: String) {
        self.partyId = partyId
        self.currentUserId = Auth.auth().currentUser?.uid
        self.currentUserName = Auth.auth().currentUser?.displayName ?? "You"
        
        setupAudioEngine()
        isVoiceChatActive = true
        
        print("🎤 Voice chat started for party: \(partyId)")
        attachRequestsListener(partyId: partyId)
    }
    
    func stopVoiceChat() {
        isVoiceChatActive = false
        isSpeaking = false
        isMuted = false
        
        cleanupAudioEngine()
        
        print("🎤 Voice chat stopped")
        requestsListener?.remove(); requestsListener = nil
    }
    
    func joinAsSpeaker() {
        guard let userId = currentUserId,
              let userName = currentUserName,
              let partyId = partyId else { return }
        
        let speaker = VoiceSpeaker(userId: userId, name: userName)
        speakers.append(speaker)
        
        // Update Firestore
        updateSpeakersInFirestore()
        
        print("🎤 Joined as speaker: \(userName)")
    }
    
    func joinAsListener() {
        guard let userId = currentUserId,
              let userName = currentUserName,
              let partyId = partyId else { return }
        
        let listener = VoiceListener(userId: userId, name: userName)
        listeners.append(listener)
        
        // Update Firestore
        updateListenersInFirestore()
        
        print("👂 Joined as listener: \(userName)")
    }
    
    func leaveVoiceChat() {
        // Remove from speakers or listeners
        speakers.removeAll { $0.userId == currentUserId }
        listeners.removeAll { $0.userId == currentUserId }
        
        // Update Firestore
        updateSpeakersInFirestore()
        updateListenersInFirestore()
        
        print("🎤 Left voice chat")
    }
    
    func toggleMute() {
        isMuted.toggle()
        
        if isMuted {
            muteMicrophone()
        } else {
            unmuteMicrophone()
        }
        
        print("🎤 Microphone \(isMuted ? "muted" : "unmuted")")
    }
    
    func requestToSpeak() {
        guard let userId = currentUserId,
              let userName = currentUserName else { return }
        
        // Send request to host
        sendSpeakerRequest()
        if let partyId = partyId {
            AnalyticsService.shared.logSpeakerRequest(action: "request", partyId: partyId, userId: userId)
        }
        
        print("🎤 Requested to speak")
    }

    func cancelSpeakerRequestIfAny() {
        guard let partyId = partyId, let uid = currentUserId else { return }
        let db = Firestore.firestore()
        db.collection("parties").document(partyId).collection("speakerRequests")
            .whereField("userId", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { doc in
                    doc.reference.delete()
                }
            }
    }
    
    func updateSpeakingStatus(isSpeaking: Bool) {
        // Update the current user's speaking status if they're a speaker
        if let index = speakers.firstIndex(where: { $0.userId == currentUserId }) {
            speakers[index].isSpeaking = isSpeaking
            updateSpeakersInFirestore()
        }
    }
    
    // MARK: - Audio Engine
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else { return }
        
        // Setup input (microphone)
        inputNode = audioEngine.inputNode
        let inputFormat = inputNode?.outputFormat(forBus: 0)
        
        // Setup mixer for remote audio only (not local microphone)
        mixer = AVAudioMixerNode()
        audioEngine.attach(mixer!)
        
        // Connect mixer to output for remote participants' audio
        if let mixer = mixer {
            let outputNode = audioEngine.outputNode
            let outputFormat = outputNode.inputFormat(forBus: 0)
            audioEngine.connect(mixer, to: outputNode, format: outputFormat)
        }
        
        // DO NOT connect input directly to output to prevent hearing yourself
        // The input is only used for:
        // 1. Detecting speaking (via tap)
        // 2. Sending audio to remote participants (handled separately)
        
        // Install tap on input to detect speaking (but don't route audio to output)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            print("🎤 Audio engine started (no local monitoring)")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    private func cleanupAudioEngine() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        outputNode = nil
        mixer = nil
        
        print("🎤 Audio engine cleaned up")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Process audio to detect speaking
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        let threshold: Float = 0.01 // Adjust based on testing
        
        DispatchQueue.main.async {
            let wasSpeaking = self.isSpeaking
            self.isSpeaking = average > threshold && !self.isMuted
            
            // Update speaking status in Firestore if it changed
            if wasSpeaking != self.isSpeaking {
                self.updateSpeakingStatus(isSpeaking: self.isSpeaking)
            }
        }
    }
    
    private func muteMicrophone() {
        // Mute the input node instead of mixer since we're not routing input to output
        inputNode?.volume = 0
        print("🔇 Microphone muted")
    }
    
    private func unmuteMicrophone() {
        // Unmute the input node
        inputNode?.volume = 1
        print("🎤 Microphone unmuted")
    }
    
    private func pauseVoiceChat() {
        // Pause audio processing
        print("🎤 Voice chat paused")
    }
    
    private func resumeVoiceChat() {
        // Resume audio processing
        print("🎤 Voice chat resumed")
    }
    
    // MARK: - Firestore Integration
    private func attachRequestsListener(partyId: String) {
        let db = Firestore.firestore()
        requestsListener?.remove()
        requestsListener = db.collection("parties").document(partyId)
            .collection("speakerRequests")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                let items: [SpeakerRequest] = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    let id = doc.documentID
                    let userId = data["userId"] as? String ?? ""
                    let userName = data["userName"] as? String ?? ""
                    let status = data["status"] as? String ?? "pending"
                    let ts = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return SpeakerRequest(id: id, userId: userId, userName: userName, timestamp: ts, status: status)
                } ?? []
                DispatchQueue.main.async { self.speakerRequests = items }
            }
    }
    
    func updateSpeakersInFirestore() {
        guard let partyId = partyId else { return }
        
        let db = Firestore.firestore()
        let speakersData = speakers.map { speaker in
            [
                "id": speaker.id,
                "userId": speaker.userId,
                "name": speaker.name,
                "isHost": speaker.isHost,
                "isSpeaking": speaker.isSpeaking,
                "joinedAt": speaker.joinedAt,
                "avatarUrl": speaker.avatarUrl ?? NSNull()
            ] as [String: Any]
        }
        
        db.collection("parties").document(partyId).updateData([
            "speakers": speakersData
        ]) { error in
            if let error = error {
                print("❌ Error updating speakers: \(error)")
            } else {
                print("✅ Speakers updated in Firestore")
            }
        }
    }
    
    func updateListenersInFirestore() {
        guard let partyId = partyId else { return }
        
        let db = Firestore.firestore()
        let listenersData = listeners.map { listener in
            [
                "id": listener.id,
                "userId": listener.userId,
                "name": listener.name,
                "joinedAt": listener.joinedAt,
                "avatarUrl": listener.avatarUrl ?? NSNull()
            ] as [String: Any]
        }
        
        db.collection("parties").document(partyId).updateData([
            "listeners": listenersData
        ]) { error in
            if let error = error {
                print("❌ Error updating listeners: \(error)")
            } else {
                print("✅ Listeners updated in Firestore")
            }
        }
    }
    
    private func sendSpeakerRequest() {
        guard let partyId = partyId,
              let userId = currentUserId,
              let userName = currentUserName else { return }
        
        let db = Firestore.firestore()
        let requestData: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "timestamp": Date(),
            "status": "pending"
        ]
        
        db.collection("parties").document(partyId).collection("speakerRequests").addDocument(data: requestData) { error in
            if let error = error {
                print("❌ Error sending speaker request: \(error)")
            } else {
                print("✅ Speaker request sent")
            }
        }
    }

    // Host-only: approve/decline a request
    func approveSpeakerRequest(_ request: SpeakerRequest) {
        guard let partyId = partyId else { return }
        let db = Firestore.firestore()
        db.collection("parties").document(partyId).collection("speakerRequests").document(request.id).updateData(["status": "approved"]) { _ in }
        let speaker = VoiceSpeaker(userId: request.userId, name: request.userName)
        self.speakers.append(speaker)
        self.updateSpeakersInFirestore()
        AnalyticsService.shared.logSpeakerRequest(action: "approve", partyId: partyId, userId: request.userId)
    }
    func declineSpeakerRequest(_ request: SpeakerRequest) {
        guard let partyId = partyId else { return }
        let db = Firestore.firestore()
        db.collection("parties").document(partyId).collection("speakerRequests").document(request.id).updateData(["status": "declined"]) { _ in }
        AnalyticsService.shared.logSpeakerRequest(action: "decline", partyId: partyId, userId: request.userId)
    }
    
    deinit {
        cleanupAudioEngine()
        NotificationCenter.default.removeObserver(self)
    }
} 