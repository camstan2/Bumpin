//
//  JoinPartyView.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import FirebaseFirestore

@MainActor
struct JoinPartyView: View {
    @EnvironmentObject var partyManager: PartyManager
    @Environment(\.presentationMode) var presentationMode
    @State private var partyCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showFriendsParties = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Join a Party")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                // Party Code Input Section
                VStack(spacing: 16) {
                    Text("Enter Party Code")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    TextField("Party Code", text: $partyCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .onChange(of: partyCode) { _, newVal in
                            partyCode = newVal.replacingOccurrences(of: " ", with: "").uppercased()
                        }
                    Button("Paste Code") { if let s = UIPasteboard.general.string { partyCode = s.replacingOccurrences(of: " ", with: "").uppercased() } }
                        .font(.subheadline)
                        .foregroundColor(.purple)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: joinPartyByCode) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("Join Party")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || partyCode.isEmpty)
                }
                .padding(.horizontal, 30)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .padding(.horizontal, 30)
                
                // Friends' Parties Section
                VStack(spacing: 16) {
                    Button(action: { showFriendsParties.toggle() }) {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Join Friends' Parties")
                    Spacer()
                            Image(systemName: showFriendsParties ? "chevron.up" : "chevron.down")
                        }
                        .font(.headline)
                        .foregroundColor(.purple)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)
                    
                    if showFriendsParties {
                        if partyManager.liveFriendParties.isEmpty {
                            Text("No friends have live parties right now.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                } else {
                            VStack(spacing: 12) {
                                ForEach(partyManager.liveFriendParties) { party in
                        Button(action: {
                                        joinParty(party)
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "person.2.fill")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(party.name)
                                        .font(.headline)
                                    Text("Host: \(party.hostName)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal, 30)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        partyManager.showJoinParty = false
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
            .onAppear {
                NotificationCenter.default.addObserver(forName: NSNotification.Name("PartyJoined"), object: nil, queue: .main) { _ in
                    partyManager.showJoinParty = false
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PartyJoined"), object: nil)
            }
        }
    }
    
    private func joinPartyByCode() {
        let clean = partyCode.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            await partyManager.joinByCode(clean)
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func createPartyFromFirestore(data: [String: Any], id: String) -> Party? {
        guard let name = data["name"] as? String,
              let hostId = data["hostId"] as? String,
              let hostName = data["hostName"] as? String,
              let createdAt = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        var party = Party(name: name, hostId: hostId, hostName: hostName)
        party.id = id // Override the generated ID with the actual Firestore document ID
        party.createdAt = createdAt.dateValue()
        party.isActive = data["isActive"] as? Bool ?? true
        
        // Parse participants
        if let participantsData = data["participants"] as? [[String: Any]] {
            party.participants = participantsData.compactMap { participantData in
                guard let id = participantData["id"] as? String,
                      let name = participantData["name"] as? String,
                      let isHost = participantData["isHost"] as? Bool,
                      let joinedAt = participantData["joinedAt"] as? Timestamp else {
                    return nil
                }
                
                var participant = PartyParticipant(id: id, name: name, isHost: isHost)
                participant.joinedAt = joinedAt.dateValue()
                return participant
            }
        }
        
        // Parse current song
        if let songData = data["currentSong"] as? [String: Any], !songData.isEmpty {
            if let title = songData["title"] as? String,
               let artist = songData["artist"] as? String {
                let song = Song(
                    title: title,
                    artist: artist,
                    duration: songData["duration"] as? Double ?? 0,
                    appleMusicId: songData["appleMusicId"] as? String
                )
                party.currentSong = song
            }
        }
        
        return party
    }
    
    private func joinParty(_ party: Party) {
        print("Joining party: \(party.name)")
        partyManager.joinParty(party)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    JoinPartyView()
        .environmentObject(PartyManager())
}