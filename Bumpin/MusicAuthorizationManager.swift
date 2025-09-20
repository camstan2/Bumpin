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
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    
    init() {
        // Check current authorization status
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        isAuthorized = authorizationStatus == .authorized
    }
    
    func requestMusicAuthorization() async {
        let status = await MPMediaLibrary.requestAuthorization()
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isAuthorized = status == .authorized
        }
    }
    
    func checkAuthorizationStatus() {
        let status = MPMediaLibrary.authorizationStatus()
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isAuthorized = status == .authorized
        }
    }
} 