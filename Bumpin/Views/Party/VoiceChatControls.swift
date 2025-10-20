//
//  VoiceChatControls.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI

struct VoiceChatControls: View {
    @ObservedObject var partyManager: PartyManager
    @State private var showVolumePopup = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Volume control button
            Button(action: {
                showVolumePopup.toggle()
            }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            // Mic button
            MicButton(partyManager: partyManager)
        }
    }
}

struct MicButton: View {
    @ObservedObject var partyManager: PartyManager
    
    private var isMuted: Bool {
        partyManager.agoraVoiceService.isMuted
    }
    
    private var isSpeaking: Bool {
        !isMuted && partyManager.agoraVoiceService.isJoined
    }
    
    private var canSpeak: Bool {
        guard let party = partyManager.currentParty else { return false }
        let currentUserId = partyManager.currentUserId
        
        // Host can always speak
        if party.hostId == currentUserId {
            return true
        }
        
        // Check if user is in speakers list
        return party.speakers.contains(currentUserId)
    }
    
    var body: some View {
        Button(action: {
            if canSpeak {
                partyManager.toggleMicrophone()
            }
        }) {
            ZStack {
                // Pulsing background when speaking
                if isSpeaking {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .scaleEffect(isSpeaking ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isSpeaking)
                }
                
                // Mic icon
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(canSpeak ? (isMuted ? Color.red : Color.green) : Color.gray)
                    .clipShape(Circle())
            }
        }
        .disabled(!canSpeak)
    }
}

struct VolumeControlPopup: View {
    @ObservedObject var partyManager: PartyManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Volume Controls")
                .font(.headline)
                .foregroundColor(.white)
            
            // Music Volume
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.white)
                    Text("Music")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(partyManager.musicVolume * 100))%")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                
                Slider(value: $partyManager.musicVolume, in: 0...1)
                    .accentColor(.blue)
                    .onChange(of: partyManager.musicVolume) { newValue in
                        partyManager.setMusicVolume(newValue)
                    }
            }
            
            // Voice Volume
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white)
                    Text("Voice")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(partyManager.voiceVolume * 100))%")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                
                Slider(value: $partyManager.voiceVolume, in: 0...1)
                    .accentColor(.green)
                    .onChange(of: partyManager.voiceVolume) { newValue in
                        partyManager.setVoiceVolume(newValue)
                    }
            }
            
            Button("Done") {
                isPresented = false
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue)
            .clipShape(Capsule())
        }
        .padding(20)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .padding(.horizontal, 40)
    }
}

#Preview {
    VoiceChatControls(partyManager: PartyManager())
        .background(Color.black)
}
