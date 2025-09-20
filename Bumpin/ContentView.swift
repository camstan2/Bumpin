//
//  ContentView.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import MediaPlayer
import FirebaseFirestore

struct ContentView: View {
    @StateObject private var musicAuthManager = MusicAuthorizationManager()
    @StateObject private var userProfileVM = UserProfileViewModel()
    @EnvironmentObject var partyManager: PartyManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var nowPlayingManager: NowPlayingManager
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showPartyDiscovery = false
    // Join code sheet state
    @State private var showJoinCodeSheet: Bool = false
    @State private var pendingPartyForCode: Party? = nil
    @State private var joinCodeInput: String = ""
    // Removed Home segmented tabs; Home now shows Discover only
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Authorization Status — now the only header content
                switch musicAuthManager.authorizationStatus {
                case .notDetermined:
                    authorizationRequestView
                case .denied, .restricted:
                    authorizationDeniedView
                case .authorized:
                    PartyDiscoveryView()
                @unknown default:
                    authorizationRequestView
                }
            }
            .navigationBarHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            // Sign-out moved to Profile tab
        }
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
        .onAppear {
            musicAuthManager.checkAuthorizationStatus()
            userProfileVM.fetchCurrentUserProfile()
            // Handle profile deep-links from in-party taps
            NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenUserProfile"), object: nil, queue: .main) { note in
                if let userId = note.object as? String {
                    // Present the profile in full-screen (iOS 15+ safe window scene lookup)
                    let hosting = UIHostingController(rootView: NavigationView {
                        UserProfileView(userId: userId)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Back") {
                                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let window = scene.windows.first,
                                           let root = window.rootViewController {
                                            var top = root
                                            while let presented = top.presentedViewController {
                                                top = presented
                                            }
                                            top.dismiss(animated: true)
                                        }
                                    }
                                    .foregroundColor(.purple)
                                }
                            }
                    })
                    hosting.modalPresentationStyle = .fullScreen
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.windows.first,
                       let root = window.rootViewController {
                        var top = root
                        while let presented = top.presentedViewController {
                            top = presented
                        }
                        top.present(hosting, animated: true)
                    }
                }
            }
            // Handle party code prompt for gated parties → show SwiftUI sheet
            NotificationCenter.default.addObserver(forName: NSNotification.Name("PromptPartyCode"), object: nil, queue: .main) { note in
                guard let party = note.object as? Party else { return }
                self.pendingPartyForCode = party
                self.joinCodeInput = ""
                self.showJoinCodeSheet = true
            }
            // Friends-only denial info
            NotificationCenter.default.addObserver(forName: NSNotification.Name("FriendsOnlyDenied"), object: nil, queue: .main) { _ in
                let alert = UIAlertController(title: "Friends Only", message: "You must be friends with the host to join this party.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first,
                   let root = window.rootViewController {
                    root.present(alert, animated: true)
                }
            }
            // Queue permission toast
            NotificationCenter.default.addObserver(forName: NSNotification.Name("QueuePermissionDenied"), object: nil, queue: .main) { _ in
                let alert = UIAlertController(title: "Not Allowed", message: "Only the host or co-hosts can add songs right now.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first,
                   let root = window.rootViewController {
                    root.present(alert, animated: true)
                }
            }
            // Join code not found
            NotificationCenter.default.addObserver(forName: NSNotification.Name("JoinCodeNotFound"), object: nil, queue: .main) { note in
                let code = (note.object as? String) ?? ""
                let alert = UIAlertController(title: "Party Not Found", message: "No active party matches code \(code).", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first,
                   let root = window.rootViewController {
                    root.present(alert, animated: true)
                }
            }
        }
        // Join Code Sheet
        .sheet(isPresented: $showJoinCodeSheet) {
            if let party = pendingPartyForCode {
                JoinCodeSheet(
                    partyName: party.name,
                    onPaste: {
                        if let p = UIPasteboard.general.string { joinCodeInput = sanitizeCode(p) }
                    },
                    code: $joinCodeInput,
                    onCancel: { showJoinCodeSheet = false },
                    onSubmit: {
                        let code = sanitizeCode(joinCodeInput)
                        if code == String((party.accessCode ?? "").prefix(6)).uppercased() {
                            NotificationCenter.default.post(name: NSNotification.Name("JoinParty"), object: party)
                            showJoinCodeSheet = false
                            AnalyticsService.shared.logTap(category: "join_code_success", id: code)
                        } else {
                            // Keep sheet open; show invalid state
                            joinCodeInput = ""
                            NotificationCenter.default.post(name: NSNotification.Name("JoinCodeNotFound"), object: code)
                            AnalyticsService.shared.logJoinCodeInvalid(code: code)
                        }
                    }
                )
            }
        }
        // Party creation sheet removed - handled by PartyDiscoveryView
        .fullScreenCover(isPresented: $partyManager.showPartyView) {
            if let _ = partyManager.currentParty {
                PartyView(partyManager: partyManager)
            }
        }
        // Keep JoinPartyView sheet for deep-links, but no direct button entry here
        .sheet(isPresented: $partyManager.showJoinParty) {
            JoinPartyView()
                .environmentObject(partyManager)
        }
    }
    
    private var authorizationRequestView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Apple Music Access Required")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Bumpin needs access to Apple Music to sync songs with your party. This allows everyone to listen to the same song at the same time.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await musicAuthManager.requestMusicAuthorization()
                }
            }) {
                HStack {
                    Image(systemName: "music.note")
                    Text("Grant Apple Music Access")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var authorizationDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Apple Music Access Denied")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("To use Bumpin, you need to grant Apple Music access in Settings.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // Removed old Home segmented tabs and legacy Live DJs UI.
    
    // MARK: - Helper Functions
    
}

// MARK: - Join Code Sheet UI
private func sanitizeCode(_ raw: String) -> String {
    raw.replacingOccurrences(of: " ", with: "").uppercased()
}

struct JoinCodeSheet: View {
    let partyName: String
    let onPaste: () -> Void
    @Binding var code: String
    let onCancel: () -> Void
    let onSubmit: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter code for \(partyName)")
                    .font(.headline)
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { idx in
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .frame(width: 44, height: 54)
                            Text(char(at: idx))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Code input")
                
                TextField("ABC123", text: $code)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)
                    .onChange(of: code) { _, newVal in
                        code = sanitizeCode(String(newVal.prefix(6)))
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 220)
                
                HStack(spacing: 16) {
                    Button("Paste") { onPaste() }
                    Button("Join") { onSubmit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(code.count < 6)
                }
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { onCancel() } } }
        }
    }
    
    private func char(at index: Int) -> String {
        guard index < code.count else { return "" }
        let s = Array(code)
        return String(s[index])
    }
}

#Preview {
    ContentView(authViewModel: AuthViewModel())
}
