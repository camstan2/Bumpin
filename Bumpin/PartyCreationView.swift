//
//  PartyCreationView.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import CoreLocation
import FirebaseAuth

struct PartyCreationView: View {
    @ObservedObject var partyManager: PartyManager
    @EnvironmentObject private var locationManager: LocationManager
    @State private var partyName = ""
    @State private var showingNameError = false
    @State private var isPublic = false
    @State private var discoveryRangeMiles: Double = 0.25 // 0.25mi to 5mi
    @State private var showingLocationAlert = false
    @State private var partyLocationEnabled = true
    @State private var speakingEnabled = true
    @State private var admissionMode: String = "open" // open, invite, friends, followers
    @State private var speakingPermissionMode: String = "open" // open, approval
    @State private var friendsAutoSpeaker: Bool = false
    @State private var whoCanAddSongs: String = "all"
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Create a Party")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Start a music party and invite friends to listen together")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
    }
    
    private var partyNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Party Name")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Enter party name...", text: $partyName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.body)
                .onChange(of: partyName, { _, _ in
                    showingNameError = false
                })
            
            if showingNameError {
                Text("Please enter a party name")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // Extracted main content to reduce body complexity
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 20) {
            headerView
            ScrollView {
                VStack(spacing: 24) {
                    partyNameSection
                    // Settings section extracted
                    settingsSection
                }
                .padding(.horizontal, 30)
            }
        }
    }

    // Settings section extracted for clarity
    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Public/Private Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location.circle")
                        .foregroundColor(.purple)
                    Text("Public Party")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Toggle("", isOn: $isPublic)
                        .onChange(of: isPublic) { _, newValue in
                            if newValue && !(locationManager.isLocationEnabled) {
                                showingLocationAlert = true
                                isPublic = false
                            }
                        }
                }
                
                Text("Allow nearby people to discover and join your party")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Distance Setting (only show if public)
            if isPublic {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Discovery Range")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(distanceMilesLabel(discoveryRangeMiles))
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    
                    Slider(value: $discoveryRangeMiles, in: 0.25...5.0, step: 0.25)
                        .accentColor(.purple)
                    
                    Text("People within this distance can see your party")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Admission Mode
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.circle")
                        .foregroundColor(.purple)
                    Text("Who Can Join")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Menu(admissionMode.capitalized) {
                        Button("Open") { admissionMode = "open" }
                        Button("Invite") { admissionMode = "invite" }
                        Button("Friends") { admissionMode = "friends" }
                        Button("Followers") { admissionMode = "followers" }
                    }
                    .foregroundColor(.purple)
                }
                Text("Control who can join your party")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Party Location Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle")
                        .foregroundColor(.purple)
                    Text("Party Location")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Toggle("", isOn: $partyLocationEnabled)
                }
                
                Text("Show your party location to other users")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Speaking Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mic.circle")
                        .foregroundColor(.purple)
                    Text("Speaking")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Toggle("", isOn: $speakingEnabled)
                }
                
                Text("Allow voice chat during the party")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if speakingEnabled {
                // Speaking Permission Mode
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.wave.2")
                            .foregroundColor(.purple)
                        Text("Speaking Permissions")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Menu(speakingPermissionMode == "open" ? "Everyone" : "Approval") {
                            Button("Everyone") { speakingPermissionMode = "open" }
                            Button("Approval") { speakingPermissionMode = "approval" }
                        }
                        .foregroundColor(.purple)
                    }
                    Text("Choose if anyone can speak or host approval is required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Friends Auto Permission
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.2.circle")
                            .foregroundColor(.purple)
                        Text("Friends Auto Permission")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Toggle("", isOn: $friendsAutoSpeaker)
                    }
                    Text("Friends are auto-approved to speak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Who can add songs
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "music.note.list")
                        .foregroundColor(.purple)
                    Text("Who Can Add Songs")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Menu(whoCanAddSongs.capitalized) {
                        Button("All") { whoCanAddSongs = "all" }
                        Button("Host") { whoCanAddSongs = "host" }
                    }
                    .foregroundColor(.purple)
                }
                Text("Control queue access")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 0)
        .padding(.bottom, 30)
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            partyManager.showPartyCreation = false
                        }
                        .foregroundColor(.purple)
                    }
                }
                .alert("Location Permission Required", isPresented: $showingLocationAlert) {
                    Button("Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Location access is required for public parties. Please enable location services in Settings.")
                }
                .safeAreaInset(edge: .bottom) {
                    Button(action: createParty) {
                        HStack {
                            if partyManager.isCreatingParty {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(partyManager.isCreatingParty ? "Creating..." : "Create Party")
                                .fontWeight(.semibold)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(partyName.isEmpty ? Color.gray : Color.purple)
                        .cornerRadius(12)
                        .padding(.horizontal, 30)
                    }
                    .disabled(partyName.isEmpty || partyManager.isCreatingParty)
                    .background(Color(.systemBackground).ignoresSafeArea())
                }
        }
        .onAppear {
            if !locationManager.isLocationEnabled {
                locationManager.requestLocationPermission()
            }
        }
    }
    
    private func createParty() {
        let trimmedName = partyName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            showingNameError = true
            return
        }
        
        // Content moderation check for party name
        Task {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            let moderationResult = await ContentModerationService.shared.moderatePartyName(trimmedName, userId: userId)
            if !moderationResult.isAllowed {
                await MainActor.run {
                    // Show error for inappropriate party name
                    showingNameError = true
                    // You might want to add a specific error message property
                }
                return
            }
            
            await MainActor.run {
                // Get current location if public party
                var latitude: Double? = nil
                var longitude: Double? = nil
                
                if isPublic {
                    latitude = locationManager.currentLocation?.coordinate.latitude
                    longitude = locationManager.currentLocation?.coordinate.longitude
                }
                
                partyManager.createParty(
                    name: trimmedName,
                    latitude: latitude,
                    longitude: longitude,
                    isPublic: isPublic,
                    maxDistance: milesToMeters(discoveryRangeMiles),
                    partyLocationEnabled: partyLocationEnabled,
                    speakingEnabled: speakingEnabled,
                    admissionMode: admissionMode,
                    speakingPermissionMode: speakingPermissionMode,
                    friendsAutoSpeaker: friendsAutoSpeaker,
                    whoCanAddSongs: whoCanAddSongs
                )
            }
        }
    }

    private func milesToMeters(_ miles: Double) -> Double { miles * 1609.34 }
    private func distanceMilesLabel(_ miles: Double) -> String {
        if miles < 1.0 {
            return String(format: "%.2f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
}



#Preview {
    PartyCreationView(partyManager: PartyManager())
} 