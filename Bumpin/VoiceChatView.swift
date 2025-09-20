//
//  VoiceChatView.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import AVFoundation

struct VoiceChatView: View {
    @ObservedObject var voiceChatManager: VoiceChatManager
    @ObservedObject var partyManager: PartyManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingSpeakerRequest = false
    @State private var showingMuteOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                voiceChatHeader
                
                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Speaker
                        if let currentSpeaker = voiceChatManager.currentSpeaker {
                            currentSpeakerView(currentSpeaker)
                        }
                        
                        // Speakers Section
                        speakersSection
                        
                        // Listeners Section
                        listenersSection
                        
                        // Voice Chat Controls
                        voiceChatControls
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showingSpeakerRequest) {
            SpeakerRequestView(voiceChatManager: voiceChatManager)
        }
        .actionSheet(isPresented: $showingMuteOptions) {
            ActionSheet(
                title: Text("Voice Chat Options"),
                buttons: [
                    .default(Text("Join as Speaker")) {
                        voiceChatManager.joinAsSpeaker()
                    },
                    .default(Text("Join as Listener")) {
                        voiceChatManager.joinAsListener()
                    },
                    .destructive(Text("Leave Voice Chat")) {
                        voiceChatManager.leaveVoiceChat()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // MARK: - Header
    
    private var voiceChatHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Voice Chat")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(voiceChatManager.isVoiceChatActive ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text(voiceChatManager.isVoiceChatActive ? "Live" : "Offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { showingMuteOptions = true }) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            
            // Voice Chat Stats
            HStack(spacing: 20) {
                VStack {
                    Text("\(voiceChatManager.speakers.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Speakers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(voiceChatManager.listeners.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Listeners")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(voiceChatManager.speakers.count + voiceChatManager.listeners.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Current Speaker
    
    private func currentSpeakerView(_ speaker: VoiceSpeaker) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(speaker.name)
                        .font(.headline)
                    Text(speaker.isSpeaking ? "Speaking" : "Listening")
                        .font(.caption)
                        .foregroundColor(speaker.isSpeaking ? .green : .secondary)
                }
                
                Spacer()
                
                if speaker.isSpeaking {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.green)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: speaker.isSpeaking)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Speakers Section
    
    private var speakersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("Speakers")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(voiceChatManager.speakers.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if voiceChatManager.speakers.isEmpty {
                Text("No speakers yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(voiceChatManager.speakers) { speaker in
                        SpeakerRowView(speaker: speaker)
                    }
                }
            }
        }
    }
    
    // MARK: - Listeners Section
    
    private var listenersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ear.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Listeners")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(voiceChatManager.listeners.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if voiceChatManager.listeners.isEmpty {
                Text("No listeners yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(voiceChatManager.listeners) { listener in
                        ListenerRowView(listener: listener)
                    }
                }
            }
        }
    }
    
    // MARK: - Voice Chat Controls
    
    private var voiceChatControls: some View {
        VStack(spacing: 16) {
            // Mute/Unmute Button
            Button(action: { voiceChatManager.toggleMute() }) {
                HStack(spacing: 12) {
                    Image(systemName: voiceChatManager.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.title2)
                    Text(voiceChatManager.isMuted ? "Unmute" : "Mute")
                        .font(.headline)
                }
                .foregroundColor(voiceChatManager.isMuted ? .red : .green)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Request to Speak Button
            Button(action: { showingSpeakerRequest = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2)
                    Text("Request to Speak")
                        .font(.headline)
                }
                .foregroundColor(.purple)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Speaker Row View

struct SpeakerRowView: View {
    let speaker: VoiceSpeaker
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(speaker.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(speaker.isSpeaking ? "Speaking" : "Listening")
                    .font(.caption)
                    .foregroundColor(speaker.isSpeaking ? .green : .secondary)
            }
            
            Spacer()
            
            if speaker.isSpeaking {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundColor(.green)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: speaker.isSpeaking)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Listener Row View

struct ListenerRowView: View {
    let listener: VoiceListener
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(listener.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Listening")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Speaker Request View

struct SpeakerRequestView: View {
    @ObservedObject var voiceChatManager: VoiceChatManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Request to Speak")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Ask the host to let you speak in the voice chat")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    voiceChatManager.requestToSpeak()
                    dismiss()
                }) {
                    Text("Send Request")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    voiceChatManager.cancelSpeakerRequestIfAny()
                    dismiss()
                }) {
                    Text("Cancel Pending Request")
                        .font(.headline)
                        .foregroundColor(.purple)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Request to Speak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
} 