//
//  AgoraVoiceService.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import AgoraRtcKit
import AVFoundation

@MainActor
class AgoraVoiceService: NSObject, ObservableObject {
    @Published var isJoined = false
    @Published var isMuted = true
    @Published var activeSpeakers: [String] = []
    @Published var networkQuality: NetworkQuality = .unknown
    @Published var error: AgoraError?
    
    private var agoraKit: AgoraRtcEngineKit?
    private var channelId: String?
    private var userId: UInt?
    private var isAudioSessionActive = false
    
    override init() {
        super.init()
        initializeAgoraEngine()
        // Don't activate audio session until joining a channel
    }
    
    deinit {
        // Cleanup directly in deinit since we can't call MainActor methods
        agoraKit?.leaveChannel(nil)
        AgoraRtcEngineKit.destroy()
    }
    
    // MARK: - Audio Session Setup
    private func activateAudioSession() {
        guard !isAudioSessionActive else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            isAudioSessionActive = true
            print("✅ Agora audio session activated")
        } catch {
            print("❌ Failed to activate Agora audio session: \(error)")
        }
    }
    
    private func deactivateAudioSession() {
        guard isAudioSessionActive else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
            print("✅ Agora audio session deactivated")
        } catch {
            print("❌ Failed to deactivate Agora audio session: \(error)")
        }
    }
    
    // MARK: - Agora Engine Initialization
    private func initializeAgoraEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = AgoraConfig.appId
        config.channelProfile = .communication
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        
        // Configure audio settings
        agoraKit?.setAudioProfile(.musicHighQuality, scenario: .gameStreaming)
        agoraKit?.enableAudioVolumeIndication(1000, smooth: 3, reportVad: true)
    }
    
    // MARK: - Channel Management
    func joinChannel(_ channelId: String, userId: String) async {
        guard let agoraKit = agoraKit else {
            error = .engineNotInitialized
            return
        }
        
        // Activate audio session when joining channel
        activateAudioSession()
        
        self.channelId = channelId
        self.userId = UInt(userId.hashValue)
        
        let token = "" // For testing, use empty token
        let result = agoraKit.joinChannel(byToken: token, channelId: channelId, info: nil, uid: self.userId!, joinSuccess: nil)
        
        if result != 0 {
            error = .joinChannelFailed(code: Int(result))
            deactivateAudioSession()
        }
    }
    
    func leaveChannel() async {
        guard let agoraKit = agoraKit else { return }
        
        agoraKit.leaveChannel(nil)
        isJoined = false
        activeSpeakers.removeAll()
        channelId = nil
        userId = nil
        
        // Deactivate audio session when leaving channel
        deactivateAudioSession()
    }
    
    // MARK: - Audio Controls
    func toggleMicrophone() {
        guard let agoraKit = agoraKit else { return }
        
        isMuted.toggle()
        agoraKit.muteLocalAudioStream(isMuted)
    }
    
    func setVoiceVolume(_ volume: Float) {
        guard let agoraKit = agoraKit else { return }
        
        agoraKit.adjustRecordingSignalVolume(Int(volume * 100))
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraVoiceService: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("✅ Joined voice channel: \(channel) with UID: \(uid)")
        isJoined = true
        error = nil
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("👋 User \(uid) left voice channel")
        activeSpeakers.removeAll { $0 == String(uid) }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        let currentSpeakers = speakers.compactMap { info in
            info.volume > 0 ? String(info.uid) : nil
        }
        
        activeSpeakers = currentSpeakers
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        // Use the worse of the two qualities
        let quality = txQuality.rawValue > rxQuality.rawValue ? txQuality : rxQuality
        networkQuality = NetworkQuality.fromAgoraQuality(quality)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("❌ Agora error: \(errorCode.rawValue)")
        error = .engineError(code: Int(errorCode.rawValue))
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        print("⚠️ Agora warning: \(warningCode.rawValue)")
    }
}

// MARK: - Supporting Types
enum NetworkQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case poor = "poor"
    case bad = "bad"
    case down = "down"
    case unknown = "unknown"
    
    static func fromAgoraQuality(_ quality: AgoraNetworkQuality) -> NetworkQuality {
        switch quality {
        case .excellent: return .excellent
        case .good: return .good
        case .poor: return .poor
        case .bad: return .bad
        case .down: return .down
        default: return .unknown
        }
    }
}

enum AgoraError: Error, LocalizedError {
    case engineNotInitialized
    case joinChannelFailed(code: Int)
    case engineError(code: Int)
    
    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            return "Agora engine not initialized"
        case .joinChannelFailed(let code):
            return "Failed to join channel (code: \(code))"
        case .engineError(let code):
            return "Agora engine error (code: \(code))"
        }
    }
}
