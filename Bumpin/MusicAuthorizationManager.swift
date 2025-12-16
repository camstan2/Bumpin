//
//  MusicAuthorizationManager.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import MediaPlayer
import StoreKit

@MainActor
class MusicAuthorizationManager: ObservableObject {
    static let shared = MusicAuthorizationManager()
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published private(set) var isManuallyDisconnected: Bool
    
    var isConnected: Bool {
        isAuthorized && !isManuallyDisconnected
    }
    
    private static let manualDisconnectKey = "apple_music_manual_disconnect"
    
    init() {
        let status = MPMediaLibrary.authorizationStatus()
        authorizationStatus = status
        isAuthorized = status == .authorized
        isManuallyDisconnected = UserDefaults.standard.bool(forKey: Self.manualDisconnectKey)
    }
    
    func requestMusicAuthorization() async {
        let status = await MPMediaLibrary.requestAuthorization()
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isAuthorized = status == .authorized
            if status == .authorized {
                self.isManuallyDisconnected = false
                UserDefaults.standard.set(false, forKey: Self.manualDisconnectKey)
            }
        }
    }
    
    func checkAuthorizationStatus() {
        let status = MPMediaLibrary.authorizationStatus()
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isAuthorized = status == .authorized
        }
    }
    
    func disconnectAppleMusic() {
        isManuallyDisconnected = true
        UserDefaults.standard.set(true, forKey: Self.manualDisconnectKey)
        NowPlayingSyncService.shared.disableSync()
    }
    
    func reconnectAppleMusic() async {
        isManuallyDisconnected = false
        UserDefaults.standard.set(false, forKey: Self.manualDisconnectKey)
        await requestMusicAuthorization()
    }
} 