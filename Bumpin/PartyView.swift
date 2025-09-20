//
//  PartyView.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import MediaPlayer
import UIKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Enhanced Color System
extension Color {
    static let bumpinPurple = Color(red: 0.55, green: 0.27, blue: 0.87) // Softer, more modern purple
    static let bumpinPurpleLight = Color(red: 0.65, green: 0.47, blue: 0.92) // Lighter variant
    static let bumpinPurpleDark = Color(red: 0.45, green: 0.17, blue: 0.77) // Darker variant
    static let bumpinAccent = Color(red: 0.85, green: 0.35, blue: 0.95) // Vibrant accent
    
    // Semantic colors for better accessibility
    static let bumpinSuccess = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let bumpinWarning = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let bumpinError = Color(red: 0.96, green: 0.26, blue: 0.21)
    
    // Surface colors
    static let bumpinSurface = Color(.systemGray6)
    static let bumpinSurfaceElevated = Color(.systemBackground)
}

// MARK: - Enhanced Typography System
extension Font {
    // Display fonts for headings
    static let bumpinDisplayLarge = Font.system(size: 28, weight: .bold, design: .rounded)
    static let bumpinDisplayMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let bumpinDisplaySmall = Font.system(size: 20, weight: .semibold, design: .rounded)
    
    // Body fonts for content
    static let bumpinBodyLarge = Font.system(size: 17, weight: .medium, design: .default)
    static let bumpinBodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let bumpinBodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    // Label fonts for UI elements
    static let bumpinLabelLarge = Font.system(size: 15, weight: .semibold, design: .default)
    static let bumpinLabelMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let bumpinLabelSmall = Font.system(size: 11, weight: .medium, design: .default)
    
    // Caption fonts for secondary text
    static let bumpinCaptionLarge = Font.system(size: 12, weight: .medium, design: .default)
    static let bumpinCaptionSmall = Font.system(size: 10, weight: .regular, design: .default)
}

// MARK: - Enhanced Button Styles
struct BumpinButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct BumpinPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Consistent Spacing System
struct BumpinSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Enhanced Card Style
struct BumpinCardStyle: ViewModifier {
    let elevation: CGFloat
    
    init(elevation: CGFloat = 8) {
        self.elevation = elevation
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: BumpinSpacing.lg)
                    .fill(Color.bumpinSurfaceElevated)
                    .shadow(color: Color.black.opacity(0.1), radius: elevation, x: 0, y: elevation/2)
            )
    }
}

// MARK: - Loading States & Skeleton Views
struct BumpinLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: BumpinSpacing.sm) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.bumpinPurple.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct BumpinSkeletonView: View {
    @State private var isAnimating = false
    let width: CGFloat
    let height: CGFloat
    
    init(width: CGFloat = 100, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.bumpinSurface)
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? width : -width)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            )
            .clipped()
            .onAppear {
                isAnimating = true
            }
    }
}

struct PartyMessage: Identifiable, Codable {
    var id: String { messageId }
    let messageId: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: Date?
    let profilePictureUrl: String?
    var mentions: [String]? = nil // userIds mentioned
    var reactions: [MessageReaction]? = nil
}

// MARK: - Speaker Action Enum
enum SpeakerAction {
    case makeSpeaker
    case removeSpeaker
    case mute
    case unmute
}

struct PartyView: View {
    @ObservedObject var partyManager: PartyManager
    @State private var showingInviteSheet = false
    @State private var toastMessage: String? = nil
    @State private var showingLeavePartyAlert = false
    @State private var showingEndPartyAlert = false
    @State private var chatListener: ListenerRegistration?
    @State private var selectedTab = 0
    
    // Auto-queue mode (using the one from SongPickerView)
    @State private var autoQueueMode: AutoQueueMode = .ordered
    
    // Queue display state
    @State private var showingFullQueue = false
    
    // Play Next song picker state
    @State private var showingPlayNextSongPicker = false
    
                            // Simple drag state management
    @State private var draggedSongId: String? = nil
    
    // Force UI updates for play/pause button
    @State private var isPlayingState: Bool = false
    
    // Explicit observation of MusicManager
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isPlaying: Bool = false
    
    // Timer for real-time updates
    @State private var updateTimer: Timer?
    
    // Observe current song for Now Playing section
    @State private var currentSong: Song?
    
    // Backup timer for Now Playing updates
    @State private var nowPlayingTimer: Timer?
    
    // Queue History View
    @State private var showingQueueHistory = false
    
    // Voice Chat
    @State private var showingVoiceChat = false
    @State private var voiceChatEnabled = true
    @State private var inviteToast: String? = nil
    
    // Chat State
    @State private var isTyping = false
    @State private var typingTask: Task<Void, Never>? = nil
    @State private var showingReactionPicker = false
    @State private var selectedMessageForReaction: String? = nil
    @State private var showingUserProfile = false
    @State private var selectedUserForProfile: String? = nil

    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with party info only
                partyInfoHeaderView
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if let party = partyManager.currentParty, let url = DeepLinkParser.buildInviteURL(forCode: String((party.accessCode ?? "").prefix(6))) {
                                Button(action: {
                                    UIPasteboard.general.string = url.absoluteString
                                    inviteToast = "Invite link copied"
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { inviteToast = nil }
                                }) {
                                    Image(systemName: "link")
                                }
                                .accessibilityLabel("Copy invite link")
                            }
                        }
                    }
                
                // Tab Bar positioned above content
                tabBarView
                
                // Content Area
                TabView(selection: $selectedTab) {
                    // Music Tab
                    musicTabView
                        .tag(0)
                    
                    // Participants Tab (formerly Social)
                    participantsTabView
                        .tag(1)
                    
                    // Chat Tab
                    chatTabView
                        .tag(2)
                    
                    // Settings Tab (host only)
                    if let party = partyManager.currentParty,
                       party.hostId == partyManager.currentUserId {
                        settingsTabView
                            .tag(3)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: selectedTab)
                
            }
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                if let toast = inviteToast {
                    Text(toast)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.bumpinSuccess.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: inviteToast)
                }
            }
            .sheet(isPresented: $partyManager.showSongPicker) {
                SongPickerView(
                    isPresented: $partyManager.showSongPicker,
                    onSongSelected: { song in
                        // Always add to queue - auto-play will handle if nothing is playing
                        partyManager.addSongToQueue(song)
                    }
                )
            }
            .sheet(isPresented: $partyManager.showQueueSongPicker) {
                SongPickerView(
                    isPresented: $partyManager.showQueueSongPicker,
                    onSongSelected: { song in
                        // Always add to queue from the queue song picker
                        partyManager.addSongToQueue(song)
                    },
                    onMultipleSongsSelected: { songs, playlistId, playlistSongs in
                        // Add multiple songs to queue with playlist information
                        partyManager.addMultipleSongsToQueue(songs, fromPlaylist: playlistId, playlistSongs: playlistSongs)
                    },
                    isQueueMode: true,
                    autoQueueMode: autoQueueMode
                )
            }
            .sheet(isPresented: $showingPlayNextSongPicker) {
                PlayNextSongPickerView(
                    isPresented: $showingPlayNextSongPicker,
                    onSongSelected: { song in
                        // Add song to the top of the queue (play next)
                        partyManager.addSongToQueueTop(song)
                    },
                    onMultipleSongsSelected: { songs, playlistId, playlistSongs in
                        // Add multiple songs to the top of the queue (play next)
                        partyManager.addMultipleSongsToQueueTop(songs, fromPlaylist: playlistId, playlistSongs: playlistSongs)
                    }
                )
            }
            .sheet(isPresented: $showingInviteSheet) {
                if let party = partyManager.currentParty {
                    InviteFriendsSheet(partyId: party.id, partyName: party.name)
                } else {
                    InviteFriendsSheet(partyId: nil, partyName: nil)
                }
            }
            .alert("End Party", isPresented: $showingEndPartyAlert) {
                Button("Cancel", role: .cancel) { }
                Button("End Party", role: .destructive) {
                    partyManager.endParty()
                }
            } message: {
                Text("Are you sure you want to end this party? All participants will be disconnected.")
            }
            .onAppear {
                setupChatListener()
            }
            .onDisappear {
                chatListener?.remove()
            }
            .alert("Leave Party", isPresented: $showingLeavePartyAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    partyManager.leaveParty()
                }
            } message: {
                Text("Are you sure you want to leave this party?")
            }
            .sheet(isPresented: $showingReactionPicker) {
                if let messageId = selectedMessageForReaction {
                    EmojiReactionPicker(
                        onEmojiSelected: { emoji in
                            partyManager.addReaction(to: messageId, emoji: emoji)
                            showingReactionPicker = false
                        },
                        onDismiss: {
                            showingReactionPicker = false
                        }
                    )
                    .presentationDetents([.height(300)])
                }
            }
            .fullScreenCover(isPresented: $showingUserProfile) {
                if let userId = selectedUserForProfile {
                    UserProfileView(userId: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ToastMessage"))) { note in
            if let msg = note.object as? String { withAnimation { toastMessage = msg };
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { toastMessage = nil } }
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Party Info Header View (separated from tab bar)
    private var partyInfoHeaderView: some View {
            HStack {
            VStack(alignment: .leading, spacing: 2) {
                    if let party = partyManager.currentParty {
                        Text(party.name)
                        .font(.bumpinDisplayMedium)
                            .foregroundColor(.white)
                            
                            if party.isPublic {
                                Image(systemName: "globe")
                            .foregroundColor(.bumpinSuccess)
                                    .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
            HStack(spacing: 12) {
                // Minimize Party Button - New feature
                Button(action: { 
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        partyManager.minimizeParty()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.bumpinPurple)
                        .background(
                            Circle()
                                .fill(Color.bumpinPurple.opacity(0.15))
                                .frame(width: 32, height: 32)
                        )
                        .shadow(color: Color.bumpinPurple.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(BumpinButtonStyle())
                
                // Leave Party Button - Clean icon-only design
                Button(action: { showingLeavePartyAlert = true }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title3)
                        .foregroundColor(.bumpinError)
                        .background(
                            Circle()
                                .fill(Color.bumpinError.opacity(0.15))
                                .frame(width: 32, height: 32)
                        )
                        .shadow(color: Color.bumpinError.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(BumpinButtonStyle())
                
                // End Party Button - Enhanced with background and shadow
                Button(action: { showingEndPartyAlert = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.bumpinError)
                        .background(
                            Circle()
                                .fill(Color.bumpinError.opacity(0.15))
                                .frame(width: 32, height: 32)
                        )
                        .shadow(color: Color.bumpinError.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                
                // Voice Chat Button - Enhanced with background and shadow
                Button(action: { showingVoiceChat = true }) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundColor(.bumpinPurple)
                        .background(
                            Circle()
                                .fill(Color.bumpinPurple.opacity(0.15))
                                .frame(width: 32, height: 32)
                        )
                        .shadow(color: Color.bumpinPurple.opacity(0.2), radius: 3, x: 0, y: 1)
                }
            }
        }
        .padding(.horizontal, BumpinSpacing.xl)
        .padding(.top, 6)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Tab Bar View (separated from party info)
    private var tabBarView: some View {
        ZStack(alignment: .bottom) {
            // Glass background with blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.8))
            
            HStack(spacing: 0) {
                tabButton(index: 0, icon: "music.note", title: "Music")
                tabButton(index: 1, icon: "person.2", title: "Participants")
                tabButton(index: 2, icon: "message", title: "Chat")
                
                // Settings Tab (host only)
                if let party = partyManager.currentParty,
                   party.hostId == partyManager.currentUserId {
                    tabButton(index: 3, icon: "gearshape", title: "Settings")
                }
            }
            .padding(.horizontal, BumpinSpacing.xl)
            .padding(.vertical, 6)

        }
        .frame(height: 50) // Reduced height for tab bar
    }

    // MARK: - Page Indicator Overlay
    private var pageIndicatorOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                let tabCount = partyManager.currentParty?.hostId == partyManager.currentUserId ? 4 : 3
                ForEach(0..<tabCount, id: \.self) { index in
                    Circle()
                        .fill(selectedTab == index ? Color.white : Color.white.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(selectedTab == index ? 1.0 : 0.7)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))
            .clipShape(Capsule())
            .padding(.bottom, 25)
        }
    }
    
    // MARK: - Tab Button Helper
    private func tabButton(index: Int, icon: String, title: String) -> some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = index
            }
        }) {
                        VStack(spacing: 4) {
                Image(systemName: icon)
                                .font(.title3)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? .white : .gray)
                    .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedTab == index)
                
                Text(title)
                                .font(.caption)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? .white : .gray)
                        }
                        .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .background(
                selectedTab == index ? 
                Color.white.opacity(0.1) : Color.clear
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Music Tab View
    private var musicTabView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Now Playing Section
                if let currentSong = currentSong {
                    nowPlayingSection(currentSong)
                }
                
                // Music Controls (compact)
                musicControlsSection
                
                // Queue Section
                queueSection
                
                // Queue History Section
                queueHistorySection
            }
            .padding()
        }
        .background(Color(.systemGray6))
        .onAppear {
            // Initialize current song
            currentSong = partyManager.musicManager.currentSong
            print("🎵 PartyView appeared - currentSong: \(currentSong?.title ?? "nil")")
            
            // Start backup timer for Now Playing updates
            startNowPlayingTimer()
        }
        .onDisappear {
            // Stop backup timer
            stopNowPlayingTimer()
        }
        .onChange(of: partyManager.musicManager.currentSong) { _, newSong in
            print("🎵 PartyView received currentSong update: \(newSong?.title ?? "nil")")
            currentSong = newSong
            
            // Auto-switch to Music tab when a song starts playing
            if newSong != nil && selectedTab != 0 {
                print("🎵 Auto-switching to Music tab")
                selectedTab = 0
            }
        }
        .onChange(of: partyManager.musicManager.isPlaying) { _, isPlaying in
            print("🎵 PartyView received isPlaying update: \(isPlaying)")
            // Force refresh of current song when playback starts
            if isPlaying && currentSong == nil {
                currentSong = partyManager.musicManager.currentSong
                print("🎵 Forced currentSong update: \(currentSong?.title ?? "nil")")
            }
        }
    }
    
    // MARK: - Participants Tab View
    private var participantsTabView: some View {
        VStack(spacing: 0) {
            // Search/Filter toolbar moved to top
            manageParticipantsToolbar
            // Participants Section
            participantsSection
            Spacer(minLength: 0)
        }
        .onAppear {
            loadParticipantPermissions()
        }
        .sheet(isPresented: $showManageParticipantsSheet) {
            ManageParticipantsSheet(
                participants: partyManager.currentParty?.participants ?? [],
                mutedIds: partyManager.currentParty?.mutedUserIds ?? [],
                hostId: partyManager.currentParty?.hostId ?? "",
                onMuteToggle: { userId, mute in partyManager.toggleRoomMute(userId, mute: mute) },
                onKick: { userId in partyManager.kick(userId) },
                onBan: { userId in partyManager.ban(userId) },
                onPromote: { userId in partyManager.promoteToCoHost(userId) },
                onDemote: { userId in partyManager.demoteFromCoHost(userId) },
                onMuteAllExceptHost: { partyManager.muteAllExceptHost() },
                onUnmuteAll: { partyManager.unmuteAll() },
                voiceChatManager: partyManager.voiceChatManager
            )
        }
    }
    
    // MARK: - Chat Tab View
    private var chatTabView: some View {
        VStack(spacing: 0) {
            // Chat Header
            chatHeaderView
            
            // Chat Messages
            chatMessagesView
            
            // Message Input
            chatInputView
        }
        .background(Color(.systemGray6))
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 50 {
                        // Swipe down to dismiss keyboard
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
        )
    }
    
    // MARK: - Settings Tab View
    private var settingsTabView: some View {
        ScrollView {
        VStack(spacing: 0) {
            partySettingsSection
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGray6))
        .sheet(isPresented: $showInviteShareSheet) {
            if let party = partyManager.currentParty {
                ShareSheet(activityItems: [inviteText(for: party)])
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PartyUpdateSaved"))) { _ in
            withAnimation {
                showSavedToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { showSavedToast = false }
            }
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                Text("Saved")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.bumpinSuccess.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.top, 8)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PartyUpdateFailed"))) { note in
            guard let msg = note.object as? String else { return }
            lastErrorMessage = msg
            withAnimation { showErrorToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showErrorToast = false }
            }
        }
        .overlay(alignment: .top) {
            if showErrorToast {
                Text(lastErrorMessage.isEmpty ? "Save failed" : lastErrorMessage)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.bumpinError.opacity(0.95))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.top, 8)
            }
        }
    }
    
    private var syncStatusView: some View {
        HStack(spacing: 8) {
            // Enhanced sync indicator with pulse animation
            ZStack {
                Circle()
                    .fill(syncStatusColor.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(partyManager.syncManager.syncStatus == .syncing ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: partyManager.syncManager.syncStatus == .syncing)
                
            Circle()
                .fill(syncStatusColor)
                .frame(width: 8, height: 8)
                    .shadow(color: syncStatusColor.opacity(0.4), radius: 2, x: 0, y: 1)
            }
            
            Text(syncStatusText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
            
            if partyManager.syncManager.participantsInSync > 0 {
                Text("• \(partyManager.syncManager.participantsInSync) in sync")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.bumpinSuccess)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bumpinSuccess.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var syncStatusColor: Color {
        switch partyManager.syncManager.syncStatus {
        case .disconnected:
            return .bumpinError
        case .connecting:
            return .orange
        case .connected:
            return .bumpinSuccess
        case .syncing:
            return .blue
        case .error:
            return .bumpinError
        }
    }
    
    private var syncStatusText: String {
        switch partyManager.syncManager.syncStatus {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .syncing:
            return "Syncing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    // MARK: - Now Playing Section
    private func nowPlayingSection(_ song: Song) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.bumpinPurple)
                    .font(.title2)
                Text("Now Playing")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Album Art
                if let albumArt = song.albumArt,
                   let imageData = Data(base64Encoded: albumArt),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text("Unknown Album")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Music Controls Section (Enhanced with glassmorphism)
    private var musicControlsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.bumpinPurple)
                    .font(.title2)
                    .shadow(color: .bumpinPurple.opacity(0.3), radius: 2, x: 0, y: 1)
                Text("Music Controls")
                    .font(.bumpinDisplaySmall)
                Spacer()
            }
            
            // Time Scrubber
            if partyManager.musicManager.duration > 0 {
                VStack(spacing: 8) {
                    // Progress Slider with Apple Music-like behavior
                    CustomProgressSlider(
                        currentTime: currentTime,
                        duration: duration,
                        isPlaying: isPlaying,
                        onSeek: { newTime in
                            partyManager.musicManager.seekTo(newTime)
                        }
                    )
                    .onChange(of: partyManager.musicManager.currentTime, initial: false) { _, newTime in
                        print("🎵 PartyView received currentTime update: \(newTime)s")
                        currentTime = newTime
                    }
                    .onChange(of: partyManager.musicManager.duration, initial: false) { _, newDuration in
                        print("🎵 PartyView received duration update: \(newDuration)s")
                        duration = newDuration
                    }
                    .onChange(of: partyManager.musicManager.isPlaying, initial: false) { _, newIsPlaying in
                        print("🎵 PartyView received isPlaying update: \(newIsPlaying)")
                        isPlaying = newIsPlaying
                    }
                    .onAppear {
                        // Initialize local state
                        currentTime = partyManager.musicManager.currentTime
                        duration = partyManager.musicManager.duration
                        isPlaying = partyManager.musicManager.isPlaying
                        print("🎵 PartyView appeared - currentTime: \(currentTime)s, duration: \(duration)s, isPlaying: \(isPlaying)")
                        
                        // Start timer for real-time updates
                        startUpdateTimer()
                    }
                    .onDisappear {
                        // Stop timer when view disappears
                        stopUpdateTimer()
                    }
                    
                    // Time Labels
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
            
            // Enhanced Music Control Buttons with glassmorphism
            HStack(spacing: 20) {
                Button(action: { 
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    partyManager.musicManager.skipToPrevious() 
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.bumpinPurple)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .bumpinPurple.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(BumpinButtonStyle())
                
                Button(action: { 
                    print("▶️ Play/Pause button tapped!")
                    // Enhanced haptic feedback for primary action
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    partyManager.togglePlayback()
                    // Force UI update
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPlayingState = partyManager.musicManager.isPlaying
                    }
                }) {
                    Image(systemName: isPlayingState ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.bumpinPurple)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 64, height: 64)
                        )
                        .shadow(color: .bumpinPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(isPlayingState ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPlayingState)
                }
                .buttonStyle(BumpinPrimaryButtonStyle())
                .onAppear {
                    isPlayingState = partyManager.musicManager.isPlaying
                }
                .onChange(of: partyManager.musicManager.isPlaying, initial: false) { _, newValue in
                    isPlayingState = newValue
                }
                
                Button(action: { 
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    partyManager.musicManager.skipToNext() 
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.bumpinPurple)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .bumpinPurple.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(BumpinButtonStyle())
                
                Spacer()
                
                // Enhanced Mode Button
                Menu {
                    Button {
                        autoQueueMode = .ordered
                        partyManager.setQueueMode(.ordered)
                    } label: { Label("Ordered", systemImage: "list.number") }
                    Button {
                        autoQueueMode = .random
                        partyManager.setQueueMode(.random)
                    } label: { Label("Random", systemImage: "shuffle") }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: autoQueueMode == .ordered ? "list.number" : "shuffle")
                        .font(.subheadline)
                        Text("Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.bumpinPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
            .cornerRadius(12)
                    .shadow(color: .bumpinPurple.opacity(0.15), radius: 4, x: 0, y: 2)
                }
            }
            .padding(BumpinSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: BumpinSpacing.xl)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: BumpinSpacing.xl)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.bumpinPurple.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
        }
    }
    
    // Removed bulky Queue Mode section; moved to compact menu in controls
    
    // MARK: - Queue Section
    private var queueSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.bumpinPurple)
                    .font(.title2)
                Text("Queue")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                // Play Next button (host/co-host when restricted)
                if let party = partyManager.currentParty,
                   (party.whoCanAddSongs == "all" || partyManager.isHostOrCoHost(partyManager.currentUserId)) {
                    Button(action: { showingPlayNextSongPicker = true }) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                }
                
                // Add to Queue button
                if let party = partyManager.currentParty,
                   (party.whoCanAddSongs == "all" || partyManager.isHostOrCoHost(partyManager.currentUserId)) {
                    Button(action: { partyManager.showQueueSongPicker = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.bumpinPurple)
                    }
                }
                
                // Clear Queue button (host/co-host when host-only mode)
                if let party = partyManager.currentParty,
                   (party.whoCanAddSongs == "all" || partyManager.isHostOrCoHost(partyManager.currentUserId)) {
                    Button(action: { 
                        partyManager.clearQueue()
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundColor(.bumpinError)
                    }
                }
                
                // Overflow menu for shuffle and more (repeat not implemented)
                Menu {
                    if (partyManager.currentParty?.isShuffled ?? false) {
                        Button { partyManager.unshuffleQueue() } label: { Label("Unshuffle", systemImage: "arrow.uturn.left") }
                    } else {
                        Button { partyManager.shuffleQueue() } label: { Label("Shuffle", systemImage: "shuffle") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            
            if partyManager.musicManager.currentQueue.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Queue is empty")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add songs to get the party started!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    // Show songs based on display mode (excluding currently playing song)
                    let upcomingSongs = partyManager.musicManager.currentQueue.filter { song in
                        // Filter out the currently playing song
                        guard let currentSong = partyManager.musicManager.currentSong else { return true }
                        return song.id != currentSong.id
                    }
                    let songsToShow = showingFullQueue ? 
                        Array(upcomingSongs.enumerated()) :
                        Array(upcomingSongs.prefix(10).enumerated())
                    

                    
                    ForEach(songsToShow, id: \.offset) { index, song in
                        HStack(spacing: 12) {
                            // Drag handle (only for host)
                            if let party = partyManager.currentParty,
                               party.hostId == partyManager.currentUserId {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.bumpinPurple.opacity(0.6))
                                    .font(.caption)
                                    .padding(.trailing, 4)
                                    .opacity(0.8)
                            }
                            
                            // Album Art
                            if let albumArt = song.albumArt,
                               let imageData = Data(base64Encoded: albumArt),
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(6)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            }
                            
                            // Song Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Remove button (only for host)
                            if let party = partyManager.currentParty,
                               party.hostId == partyManager.currentUserId {
                                Button(action: {
                                    partyManager.removeSongFromQueue(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.bumpinError)
                                        .font(.title3)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        .onDrag {
                            // Create a drag item with the song ID
                            NSItemProvider(object: song.id as NSString)
                        }
                        .onDrop(of: [.text], delegate: DropViewDelegate(songId: song.id, songsToShow: songsToShow, partyManager: partyManager))
                    }
                    
                    // Show Full Queue / Show Less button
                    if partyManager.musicManager.currentQueue.count > 10 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingFullQueue.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: showingFullQueue ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                Text(showingFullQueue ? "Show Less" : "Show Full Queue (\(partyManager.musicManager.currentQueue.count) songs)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.bumpinPurple)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Participants Section
    private var participantsSection: some View {
        VStack(spacing: 0) {
            if partyManager.currentParty?.participants.isEmpty ?? true {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No participants yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Invite friends to join the party!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            } else {
                // Grid layout for participants starting from top left
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(filteredParticipants, id: \.id) { participant in
                        ParticipantGridItemView(
                            participant: participant,
                            isHost: participant.id == partyManager.currentParty?.hostId,
                            isCoHost: partyManager.currentParty?.coHostIds.contains(participant.id) ?? false,
                            isSpeaking: isParticipantSpeaking(participant.id),
                            isSpeaker: isParticipantSpeaker(participant.id),
                            isListener: isParticipantListener(participant.id),
                            onSpeakerAction: { action in
                                handleSpeakerAction(action, for: participant)
                            }
                        )
                        .contextMenu {
                            Button {
                                NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: participant.id)
                            } label: { Label("View Profile", systemImage: "person.crop.circle") }
                            
                            Button { 
                                toggleLocalMute(for: participant.id)
                            } label: { 
                                Label(isLocallyMuted(participant.id) ? "Unmute Locally" : "Mute Locally", 
                                      systemImage: isLocallyMuted(participant.id) ? "speaker" : "speaker.slash") 
                            }
                            
                            // Host-only permission controls
                            if partyManager.isHostOrCoHost(partyManager.currentUserId) && participant.id != partyManager.currentUserId {
                                Divider()
                                
                                Button {
                                    toggleSpeakingPermission(for: participant.id)
                                } label: {
                                    Label(hasSpeakingPermission(participant.id) ? "Revoke Speaking" : "Grant Speaking", 
                                          systemImage: "mic.fill")
                                }
                                
                                Button {
                                    toggleQueuePermission(for: participant.id)
                                } label: {
                                    Label(hasQueuePermission(participant.id) ? "Revoke Queue Access" : "Grant Queue Access", 
                                          systemImage: "music.note")
                                }
                                
                                Divider()
                                
                                Button("Mute in Room") { partyManager.toggleRoomMute(participant.id, mute: true) }
                                Button("Unmute in Room") { partyManager.toggleRoomMute(participant.id, mute: false) }
                                Button(role: .destructive) { partyManager.kick(participant.id) } label: { Label("Kick", systemImage: "person.fill.xmark") }
                                Button(role: .destructive) { partyManager.ban(participant.id) } label: { Label("Ban", systemImage: "hand.raised.fill") }
                            }
                        }
                        .onTapGesture {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: participant.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // Manage Participants
    @State private var participantFilter: String = "all" // all | speaking | muted
    @State private var participantQuery: String = ""
    
    private var manageParticipantsToolbar: some View {
        HStack(spacing: 8) {
            Menu {
                Button("All") { participantFilter = "all" }
                Button("Speaking") { participantFilter = "speaking" }
                Button("Muted") { participantFilter = "muted" }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(participantFilter.capitalized)
                }
                .foregroundColor(.bumpinPurple)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            TextField("Search participants", text: $participantQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if partyManager.isHostOrCoHost(partyManager.currentUserId) {
                HStack(spacing: 8) {
                    // Mute All Except Host Button
                    Button(action: { partyManager.muteAllExceptHost() }) {
                        Image(systemName: "mic.slash.circle.fill")
                            .font(.title3)
                            .foregroundColor(.bumpinError)
                            .background(
                                Circle()
                                    .fill(Color.bumpinError.opacity(0.1))
                                    .frame(width: 28, height: 28)
                            )
                    }
                    .buttonStyle(BumpinButtonStyle())
                    
                    // Unmute All Button
                    Button(action: { partyManager.unmuteAll() }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.title3)
                            .foregroundColor(.bumpinPurple)
                            .background(
                                Circle()
                                    .fill(Color.bumpinPurple.opacity(0.1))
                                    .frame(width: 28, height: 28)
                            )
                    }
                    .buttonStyle(BumpinButtonStyle())
                    
                    // Manage Button
                    Button(action: { showManageParticipantsSheet = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                    .foregroundColor(.blue)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 28, height: 28)
                            )
                    }
                    .buttonStyle(BumpinButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var filteredParticipants: [PartyParticipant] {
        let base = partyManager.currentParty?.participants ?? []
        let filteredByState: [PartyParticipant]
        switch participantFilter {
        case "speaking":
            filteredByState = base.filter { isParticipantSpeaking($0.id) }
        case "muted":
            filteredByState = base.filter { partyManager.currentParty?.mutedUserIds.contains($0.id) ?? false }
        default:
            filteredByState = base
        }
        
        let searchFiltered: [PartyParticipant]
        if participantQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchFiltered = filteredByState
        } else {
            searchFiltered = filteredByState.filter { $0.name.lowercased().contains(participantQuery.lowercased()) }
        }
        
        // Smart sorting: Host first, then friends, following, followers, others
        return sortParticipantsByRelationship(searchFiltered)
    }
    
    private func sortParticipantsByRelationship(_ participants: [PartyParticipant]) -> [PartyParticipant] {
        guard let hostId = partyManager.currentParty?.hostId else {
            return participants
        }
        
        let currentUserId = partyManager.currentUserId
        
        return participants.sorted { participant1, participant2 in
            let priority1 = getParticipantPriority(participant1.id, currentUserId: currentUserId, hostId: hostId)
            let priority2 = getParticipantPriority(participant2.id, currentUserId: currentUserId, hostId: hostId)
            
            if priority1 != priority2 {
                return priority1 < priority2 // Lower number = higher priority
            }
            
            // Same priority, sort alphabetically
            return participant1.name < participant2.name
        }
    }
    
    private func getParticipantPriority(_ participantId: String, currentUserId: String, hostId: String) -> Int {
        // Priority order: Host (0), Friends (1), Following (2), Followers (3), Others (4)
        if participantId == hostId {
            return 0 // Host always first
        }
        
        // Check relationship status
        let relationshipStatus = getRelationshipStatus(with: participantId, currentUserId: currentUserId)
        switch relationshipStatus {
        case .friend:
            return 1
        case .following:
            return 2
        case .follower:
            return 3
        case .none:
            return 4
        }
    }
    
    private enum RelationshipStatus {
        case friend, following, follower, none
    }
    
    private func getRelationshipStatus(with participantId: String, currentUserId: String) -> RelationshipStatus {
        // For now, return .none - we'll implement proper relationship checking later
        // This would typically check Firestore for following/followers relationships
        return .none
    }
    
    // MARK: - Permission Management
    
    @State private var locallyMutedParticipants: Set<String> = []
    @State private var participantPermissions: [String: ParticipantPermissions] = [:]
    
    struct ParticipantPermissions {
        var canSpeak: Bool = false
        var canQueue: Bool = false
    }
    
    // Local Muting Functions
    private func isLocallyMuted(_ participantId: String) -> Bool {
        return locallyMutedParticipants.contains(participantId)
    }
    
    private func toggleLocalMute(for participantId: String) {
        if locallyMutedParticipants.contains(participantId) {
            locallyMutedParticipants.remove(participantId)
        } else {
            locallyMutedParticipants.insert(participantId)
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // Permission Checking Functions
    private func hasSpeakingPermission(_ participantId: String) -> Bool {
        // Host and co-hosts always have speaking permission
        if participantId == partyManager.currentParty?.hostId ||
           partyManager.currentParty?.coHostIds.contains(participantId) == true {
            return true
        }
        
        return participantPermissions[participantId]?.canSpeak ?? false
    }
    
    private func hasQueuePermission(_ participantId: String) -> Bool {
        // Host and co-hosts always have queue permission
        if participantId == partyManager.currentParty?.hostId ||
           partyManager.currentParty?.coHostIds.contains(participantId) == true {
            return true
        }
        
        return participantPermissions[participantId]?.canQueue ?? false
    }
    
    // Permission Toggle Functions
    private func toggleSpeakingPermission(for participantId: String) {
        guard partyManager.isHostOrCoHost(partyManager.currentUserId) else { return }
        
        let currentPermissions = participantPermissions[participantId] ?? ParticipantPermissions()
        let newPermissions = ParticipantPermissions(
            canSpeak: !currentPermissions.canSpeak,
            canQueue: currentPermissions.canQueue
        )
        
        participantPermissions[participantId] = newPermissions
        
        // Update in Firestore
        updatePermissionsInFirestore(participantId: participantId, permissions: newPermissions)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func toggleQueuePermission(for participantId: String) {
        guard partyManager.isHostOrCoHost(partyManager.currentUserId) else { return }
        
        let currentPermissions = participantPermissions[participantId] ?? ParticipantPermissions()
        let newPermissions = ParticipantPermissions(
            canSpeak: currentPermissions.canSpeak,
            canQueue: !currentPermissions.canQueue
        )
        
        participantPermissions[participantId] = newPermissions
        
        // Update in Firestore
        updatePermissionsInFirestore(participantId: participantId, permissions: newPermissions)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // Firestore Integration
    private func updatePermissionsInFirestore(participantId: String, permissions: ParticipantPermissions) {
        guard let partyId = partyManager.currentParty?.id else { return }
        
        let db = Firestore.firestore()
        let permissionsData: [String: Any] = [
            "canSpeak": permissions.canSpeak,
            "canQueue": permissions.canQueue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("parties")
            .document(partyId)
            .collection("participantPermissions")
            .document(participantId)
            .setData(permissionsData, merge: true) { error in
                if let error = error {
                    print("Error updating participant permissions: \(error.localizedDescription)")
                } else {
                    print("Successfully updated permissions for participant: \(participantId)")
                }
            }
    }
    
    // Load permissions from Firestore
    private func loadParticipantPermissions() {
        guard let partyId = partyManager.currentParty?.id else { return }
        
        let db = Firestore.firestore()
        db.collection("parties")
            .document(partyId)
            .collection("participantPermissions")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if let error = error {
                        print("Error loading participant permissions: \(error.localizedDescription)")
                    }
                    return
                }
                
                var newPermissions: [String: ParticipantPermissions] = [:]
                for document in documents {
                    let data = document.data()
                    let participantId = document.documentID
                    let permissions = ParticipantPermissions(
                        canSpeak: data["canSpeak"] as? Bool ?? false,
                        canQueue: data["canQueue"] as? Bool ?? false
                    )
                    newPermissions[participantId] = permissions
                }
                
                DispatchQueue.main.async {
                    // Note: In a real implementation, we'd need to update the parent view's state
                    // For now, we'll store this locally but it won't persist across view updates
                    print("Loaded participant permissions: \(newPermissions)")
                }
            }
    }

    @State private var showManageParticipantsSheet: Bool = false

    // Full-screen manage sheet (simplified list)
    struct ManageParticipantsSheet: View {
        let participants: [PartyParticipant]
        let mutedIds: [String]
        let hostId: String
        let onMuteToggle: (String, Bool) -> Void
        let onKick: (String) -> Void
        let onBan: (String) -> Void
        let onPromote: (String) -> Void
        let onDemote: (String) -> Void
        let onMuteAllExceptHost: () -> Void
        let onUnmuteAll: () -> Void
        @ObservedObject var voiceChatManager: VoiceChatManager
        @Environment(\.dismiss) private var dismiss
        @State private var filter: String = "all"
        @State private var query: String = ""
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Menu(filter.capitalized) {
                            Button("All") { filter = "all" }
                            Button("Speaking") { filter = "speaking" }
                            Button("Muted") { filter = "muted" }
                        }
                        .foregroundColor(.bumpinPurple)
                        TextField("Search", text: $query)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding()
                    // Real-time counts
                    HStack(spacing: 16) {
                        Label("\(participants.count) Total", systemImage: "person.3.fill")
                        Label("\(speakingCount) Speaking", systemImage: "mic.fill")
                            .foregroundColor(.bumpinPurple)
                        Label("\(mutedIds.count) Muted", systemImage: "mic.slash")
                            .foregroundColor(.bumpinError)
                        Spacer()
                    }
                    .font(.caption)
                    .padding(.horizontal)
                    
                    List(filtered, id: \.id) { p in
                        HStack {
                            Text(p.name)
                            if p.id == hostId { Text("Host").font(.caption).foregroundColor(.yellow) }
                            Spacer()
                            if mutedIds.contains(p.id) {
                                Button("Unmute") { onMuteToggle(p.id, false) }
                            } else {
                                Button("Mute") { onMuteToggle(p.id, true) }
                            }
                            if p.id != hostId {
                                Button("Kick", role: .destructive) { onKick(p.id) }
                                Button("Ban", role: .destructive) { onBan(p.id) }
                                Button("Promote") { onPromote(p.id) }
                                Button("Demote") { onDemote(p.id) }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .navigationTitle("Manage Participants")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu("Bulk") {
                            Button("Mute all except host", role: .destructive) { onMuteAllExceptHost() }
                            Button("Unmute all") { onUnmuteAll() }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
                }
            }
        }
        
        private var filtered: [PartyParticipant] {
            let base: [PartyParticipant]
            switch filter {
            case "speaking": base = participants.filter { speakingIds.contains($0.id) }
            case "muted": base = participants.filter { mutedIds.contains($0.id) }
            default: base = participants
            }
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return base }
            return base.filter { $0.name.lowercased().contains(query.lowercased()) }
        }
        
        private var speakingIds: [String] { voiceChatManager.speakers.filter { $0.isSpeaking }.map { $0.userId } }
        private var speakingCount: Int { speakingIds.count }
    }
    
    // MARK: - Participant Grid Item View
    private func ParticipantGridItemView(
        participant: PartyParticipant,
        isHost: Bool,
        isCoHost: Bool,
        isSpeaking: Bool,
        isSpeaker: Bool,
        isListener: Bool,
        onSpeakerAction: @escaping (SpeakerAction) -> Void
    ) -> some View {
        VStack(spacing: 8) {
            // Permission Indicators (top-right corner)
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    // Speaking Permission Indicator
                    if hasSpeakingPermission(participant.id) {
                        Image(systemName: "mic.fill")
                            .font(.caption2)
                            .foregroundColor(.bumpinPurple)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.white.opacity(0.9)))
                    }
                    
                    // Queue Permission Indicator
                    if hasQueuePermission(participant.id) {
                        Image(systemName: "music.note")
                            .font(.caption2)
                            .foregroundColor(.bumpinAccent)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.white.opacity(0.9)))
                    }
                }
            }
            .frame(height: 16) // Fixed height to maintain layout consistency
            
            // Profile Picture with Speaking Indicator
            ZStack {
                // Profile Picture
                Circle()
                    .fill(Color.bumpinPurple.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.bumpinPurple)
                            .font(.system(size: 24))
                    )
                
                // Speaking Indicator (animated purple border)
                if isSpeaking {
                    Circle()
                        .stroke(Color.bumpinPurple, lineWidth: 4)
                        .frame(width: 72, height: 72)
                        .scaleEffect(1.0)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isSpeaking)
                    
                    // Pulsing outer ring
                    Circle()
                        .stroke(Color.bumpinPurple.opacity(0.4), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isSpeaking)
                }
                
                // Role Indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if isHost {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 16, height: 16))
                        } else if isCoHost {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 16, height: 16))
                        } else if isSpeaker {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.bumpinPurple)
                                .font(.caption)
                                .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 16, height: 16))
                        } else if isListener {
                            Image(systemName: "ear.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 16, height: 16))
                        }
                        // Muted badge
                        if partyManager.currentParty?.mutedUserIds.contains(participant.id) == true {
                            Image(systemName: "mic.slash")
                                .foregroundColor(.bumpinError)
                                .font(.caption)
                                .background(Circle().fill(Color.black.opacity(0.7)).frame(width: 16, height: 16))
                        }
                    }
                }
            }
            
            // Name and Status
            VStack(spacing: 2) {
                Text(participant.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if isSpeaking {
                    Text("Speaking")
                        .font(.caption2)
                        .foregroundColor(.bumpinPurple)
                        .fontWeight(.semibold)
                } else if isSpeaker {
                    Text("Speaker")
                        .font(.caption2)
                        .foregroundColor(.bumpinPurple)
                } else if isListener {
                    Text("Listener")
                        .font(.caption2)
                        .foregroundColor(.blue)
                } else {
                    Text("Online")
                        .font(.caption2)
                        .foregroundColor(.bumpinSuccess)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Speaker Management Row
    private func SpeakerManagementRow(
        participant: PartyParticipant?,
        speaker: VoiceSpeaker,
        onRemoveSpeaker: @escaping () -> Void,
        onMuteSpeaker: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            // Profile Picture
            Circle()
                .fill(Color.bumpinPurple.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.bumpinPurple)
                        .font(.system(size: 16))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(participant?.name ?? speaker.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    if speaker.isSpeaking {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.bumpinPurple)
                                .frame(width: 6, height: 6)
                            Text("Speaking")
                                .font(.caption)
                                .foregroundColor(.bumpinPurple)
                        }
                    }
                    
                    if speaker.isHost {
                        Text("Host")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onMuteSpeaker) {
                    Image(systemName: "mic.slash")
                        .foregroundColor(.bumpinError)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                
                if !speaker.isHost {
                    Button(action: onRemoveSpeaker) {
                        Image(systemName: "person.fill.xmark")
                            .foregroundColor(.bumpinError)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Functions for Voice Chat
    private func isParticipantSpeaking(_ participantId: String) -> Bool {
        return partyManager.voiceChatManager.speakers.first { $0.userId == participantId }?.isSpeaking ?? false
    }
    
    private func isParticipantSpeaker(_ participantId: String) -> Bool {
        return partyManager.voiceChatManager.speakers.contains { $0.userId == participantId }
    }
    
    private func isParticipantListener(_ participantId: String) -> Bool {
        return partyManager.voiceChatManager.listeners.contains { $0.userId == participantId }
    }
    
    private func handleSpeakerAction(_ action: SpeakerAction, for participant: PartyParticipant) {
        // TODO: Implement speaker management actions
        switch action {
        case .makeSpeaker:
            print("Make \(participant.name) a speaker")
        case .removeSpeaker:
            print("Remove \(participant.name) as speaker")
        case .mute:
            print("Mute \(participant.name)")
        case .unmute:
            print("Unmute \(participant.name)")
        }
    }
    
    // MARK: - Speaker Management Functions
    private func getParticipant(for userId: String) -> PartyParticipant? {
        return partyManager.currentParty?.participants.first { $0.id == userId }
    }
    
    private func removeSpeaker(_ userId: String) {
        // Remove from speakers and add to listeners
        if let index = partyManager.voiceChatManager.speakers.firstIndex(where: { $0.userId == userId }) {
            let speaker = partyManager.voiceChatManager.speakers[index]
            partyManager.voiceChatManager.speakers.remove(at: index)
            
            // Add to listeners
            let listener = VoiceListener(userId: speaker.userId, name: speaker.name)
            partyManager.voiceChatManager.listeners.append(listener)
            
            // Update Firestore
            partyManager.voiceChatManager.updateSpeakersInFirestore()
            partyManager.voiceChatManager.updateListenersInFirestore()
            
            print("🎤 Removed \(speaker.name) as speaker")
        }
    }
    
    private func muteSpeaker(_ userId: String) {
        // TODO: Implement one-way mute functionality
        print("🎤 Muted speaker: \(userId)")
    }
    
    private func makeSpeaker(_ userId: String) {
        // Add to speakers and remove from listeners
        if let index = partyManager.voiceChatManager.listeners.firstIndex(where: { $0.userId == userId }) {
            let listener = partyManager.voiceChatManager.listeners[index]
            partyManager.voiceChatManager.listeners.remove(at: index)
            
            // Add to speakers
            let speaker = VoiceSpeaker(userId: listener.userId, name: listener.name)
            partyManager.voiceChatManager.speakers.append(speaker)
            
            // Update Firestore
            partyManager.voiceChatManager.updateSpeakersInFirestore()
            partyManager.voiceChatManager.updateListenersInFirestore()
            
            print("🎤 Made \(listener.name) a speaker")
        }
    }
    
    // MARK: - Enhanced Chat Header View
    private var chatHeaderView: some View {
        HStack {
            Image(systemName: "message.fill")
                .foregroundColor(.bumpinPurple)
                .font(.title2)
                .shadow(color: .bumpinPurple.opacity(0.3), radius: 2, x: 0, y: 1)
            Text("Party Chat")
                    .font(.bumpinDisplaySmall)
            Spacer()
            // Enhanced message count badge
            HStack(spacing: 4) {
            Text("\(partyManager.chatMessages.count)")
                .font(.caption)
                    .fontWeight(.semibold)
                Image(systemName: "message")
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.bumpinPurple.opacity(0.8))
                    .shadow(color: .bumpinPurple.opacity(0.3), radius: 3, x: 0, y: 1)
            )
        }
        .padding()
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.bumpinPurple.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Chat Messages View
    private var chatMessagesView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if partyManager.chatMessages.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "message")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No messages yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Start the conversation!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(partyManager.chatMessages) { message in
                            ChatMessageView(message: message, isOwnMessage: message.senderId == partyManager.currentUserId)
                                .id(message.id)
                                .onTapGesture {
                                    NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: message.senderId)
                                }
                        }
                        
                        // Typing indicator
                        if isTyping {
                            TypingIndicatorView()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: partyManager.chatMessages.count, initial: false) { _, _ in
                if let last = partyManager.chatMessages.last?.id {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping on messages
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    // MARK: - Enhanced Chat Input View
    private var chatInputView: some View {
        VStack(spacing: 0) {
            // Subtle gradient separator
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.bumpinPurple.opacity(0.3), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            // Enhanced mentions bar when typing '@'
            if showMentionBar {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(mentionCandidates, id: \.id) { p in
                            Button(action: { selectMention(p) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "at")
                                        .font(.caption2)
                                    Text(p.name)
                                .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.bumpinPurple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                                .shadow(color: .bumpinPurple.opacity(0.2), radius: 3, x: 0, y: 1)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.ultraThinMaterial)
            }
            
            HStack(spacing: 12) {
                // Enhanced text input
                TextField("Type a message...", text: $partyManager.newMessageText, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.bumpinPurple.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .onChange(of: partyManager.newMessageText, initial: false) { _, _ in
                        handleTyping()
                        updateMentionCandidates()
                    }
                    .onSubmit {
                        print("📱 Keyboard send button pressed")
                        sendChatMessage()
                    }
                    .submitLabel(.send)
                    .keyboardType(.default)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
                
                // Enhanced send button
                Button(action: {
                    print("📱 Send button pressed")
                    sendChatMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(partyManager.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                      Color.gray.opacity(0.5) : Color.bumpinPurple)
                        )
                        .shadow(color: partyManager.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                               .clear : .bumpinPurple.opacity(0.3), radius: 4, x: 0, y: 2)
                        .scaleEffect(partyManager.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: partyManager.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .disabled(partyManager.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // Mention UI state
    @State private var showMentionBar: Bool = false
    @State private var mentionCandidates: [PartyParticipant] = []
    
    private func updateMentionCandidates() {
        let text = partyManager.newMessageText
        // Find the last '@' and derive a token of letters/numbers after it
        guard let atIndex = text.lastIndex(of: "@") else {
            showMentionBar = false
            mentionCandidates = []
            return
        }
        let afterAt = text.index(after: atIndex)
        let suffix = text[afterAt...]
        let allowed = CharacterSet.alphanumerics
        var token = ""
        for scalar in suffix.unicodeScalars {
            if allowed.contains(scalar) { token.unicodeScalars.append(scalar) } else { break }
        }
        // If user just typed '@' and nothing else, show everyone (limited)
        if token.isEmpty && suffix.isEmpty {
            let all = partyManager.currentParty?.participants ?? []
            mentionCandidates = Array(all.prefix(10))
            showMentionBar = !mentionCandidates.isEmpty
            return
        }
        guard !token.isEmpty else {
            showMentionBar = false
            mentionCandidates = []
            return
        }
        func sanitize(_ s: String) -> String { s.lowercased().replacingOccurrences(of: " ", with: "") }
        let query = sanitize(token)
        let participants = partyManager.currentParty?.participants ?? []
        let prioritized = participants
            .sorted {
                let a = sanitize($0.name), b = sanitize($1.name)
                let aStarts = a.hasPrefix(query), bStarts = b.hasPrefix(query)
                if aStarts != bStarts { return aStarts && !bStarts }
                return a < b
            }
            .filter { sanitize($0.name).contains(query) }
        mentionCandidates = Array(prioritized.prefix(10))
        showMentionBar = !mentionCandidates.isEmpty
    }
    
    private func selectMention(_ participant: PartyParticipant) {
        // Replace the last '@<token>' with canonical @Name and keep any trailing remainder
        let text = partyManager.newMessageText
        guard let atIndex = text.lastIndex(of: "@") else {
            showMentionBar = false
            mentionCandidates = []
            return
        }
        let afterAt = text.index(after: atIndex)
        let suffix = text[afterAt...]
        let allowed = CharacterSet.alphanumerics
        var tokenLength = 0
        for scalar in suffix.unicodeScalars {
            if allowed.contains(scalar) { tokenLength += 1 } else { break }
        }
        let tokenEnd = text.index(afterAt, offsetBy: tokenLength, limitedBy: text.endIndex) ?? text.endIndex
        let prefix = text[..<atIndex]
        let remainder = text[tokenEnd...]
        let canonical = "@" + participant.name.replacingOccurrences(of: " ", with: "") + " "
        partyManager.newMessageText = String(prefix) + canonical + String(remainder)
        if !partyManager.newMessageMentions.contains(participant.id) {
            partyManager.newMessageMentions.append(participant.id)
        }
        showMentionBar = false
        mentionCandidates = []
    }
    
    // MARK: - Chat Message View
    private func ChatMessageView(message: PartyMessage, isOwnMessage: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if !isOwnMessage {
                    // Other person's message (left side)
                    HStack(alignment: .top, spacing: 8) {
                        // Profile Picture (tappable for profile)
                        Button(action: {
                            selectedUserForProfile = message.senderId
                            showingUserProfile = true
                        }) {
                            if let url = message.profilePictureUrl, let imageUrl = URL(string: url) {
                                AsyncImage(url: imageUrl) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable().scaledToFit()
                                            .foregroundColor(.bumpinPurple.opacity(0.5))
                                    }
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable().scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.bumpinPurple.opacity(0.5))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(message.senderName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            if let date = message.timestamp {
                                Text(date.formatted(.dateTime.hour().minute()))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        highlightedMessage(message)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .onLongPressGesture {
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                selectedMessageForReaction = message.messageId
                                showingReactionPicker = true
                            }
                    }
                }
                
                Spacer()
            } else {
                // Own message (right side)
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let date = message.timestamp {
                        Text(date.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    highlightedMessage(message, isOwn: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.bumpinPurple)
                        .cornerRadius(16)
                        .onLongPressGesture {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            selectedMessageForReaction = message.messageId
                            showingReactionPicker = true
                        }
                }
            }
            }
            
            // Reactions display
            let messageReactions = partyManager.messageReactions[message.messageId] ?? []
            if !messageReactions.isEmpty {
                HStack {
                    if isOwnMessage { Spacer() }
                    
                    MessageReactionView(reactions: messageReactions) { emoji in
                        partyManager.toggleReaction(on: message.messageId, emoji: emoji)
                    }
                    .padding(.leading, isOwnMessage ? 0 : 40) // Align with message
                    
                    if !isOwnMessage { Spacer() }
                }
            }
        }
    }

    // Render text with simple @mention highlight
    @ViewBuilder
    private func highlightedMessage(_ message: PartyMessage, isOwn: Bool = false) -> some View {
        let rawParts = message.text.split(separator: " ")
        HStack(spacing: 4) {
            ForEach(Array(rawParts.enumerated()), id: \.offset) { _, raw in
                let token = String(raw)
                if token.hasPrefix("@") {
                    let stripped = token.dropFirst().lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                    let matchedId: String? = {
                        if let ids = message.mentions {
                            for id in ids {
                                if let name = partyManager.currentParty?.participants.first(where: { $0.id == id })?.name {
                                    let sanitized = name.replacingOccurrences(of: " ", with: "").lowercased()
                                    if sanitized == stripped { return id }
                                }
                            }
                        }
                        return partyManager.currentParty?.participants.first { $0.name.replacingOccurrences(of: " ", with: "").lowercased() == stripped }?.id
                    }()
                    Text(token)
                        .font(.body)
                        .foregroundColor(isOwn ? .yellow : .bumpinPurple)
                        .onTapGesture {
                            if let pid = matchedId {
                                NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: pid)
                            }
                        }
                } else {
                    Text(token)
                        .font(.body)
                        .foregroundColor(isOwn ? .white : .primary)
                }
            }
        }
    }
    
    // MARK: - Typing Indicator View
    private func TypingIndicatorView() -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Profile Picture
            Image(systemName: "person.crop.circle")
                .resizable().scaledToFit()
                .frame(width: 32, height: 32)
                .foregroundColor(.bumpinPurple.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Someone")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 6, height: 6)
                            .scaleEffect(1.0)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: isTyping
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Chat Section (Legacy - keeping for reference)
    private var chatSection: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(partyManager.chatMessages) { message in
                            HStack(alignment: .top, spacing: 8) {
                                if let url = message.profilePictureUrl, let imageUrl = URL(string: url) {
                                    AsyncImage(url: imageUrl) { phase in
                                        if let img = phase.image {
                                            img.resizable().scaledToFill()
                                        } else {
                                            Image(systemName: "person.crop.circle")
                                                .resizable().scaledToFit()
                                                .foregroundColor(.bumpinPurple.opacity(0.5))
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle")
                                        .resizable().scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(.bumpinPurple.opacity(0.5))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(message.senderName)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Text(message.text)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    if let date = message.timestamp {
                                        Text(date.formatted(.dateTime.hour().minute()))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: partyManager.chatMessages.count, initial: false) { _, _ in
                    if let last = partyManager.chatMessages.last?.id {
                        withAnimation { scrollProxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Message input
            HStack {
                TextField("Message...", text: $partyManager.newMessageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: partyManager.sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(partyManager.newMessageText.isEmpty ? .gray : .bumpinPurple)
                }
                .disabled(partyManager.newMessageText.isEmpty)
            }
            .padding([.horizontal, .bottom])
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Voice Chat Settings
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.bumpinPurple)
                            .font(.title2)
                        Text("Voice Chat Settings")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    // Voice Chat Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Voice Chat")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Enable voice chat for all participants")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $voiceChatEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: .bumpinPurple))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Host Mute/Unmute Button
                    Button(action: {
                        partyManager.voiceChatManager.toggleMute()
                    }) {
                        HStack {
                            Image(systemName: partyManager.voiceChatManager.isMuted ? "mic.slash.fill" : "mic.fill")
                                .foregroundColor(partyManager.voiceChatManager.isMuted ? .bumpinError : .bumpinSuccess)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(partyManager.voiceChatManager.isMuted ? "Unmute" : "Mute")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Your microphone")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Speaker Management
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("Speaker Management")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    // Current Speakers
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Speakers")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(partyManager.voiceChatManager.speakers.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if partyManager.voiceChatManager.speakers.isEmpty {
                            Text("No speakers yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(partyManager.voiceChatManager.speakers, id: \.id) { speaker in
                                    SpeakerManagementRow(
                                        participant: getParticipant(for: speaker.userId),
                                        speaker: speaker,
                                        onRemoveSpeaker: {
                                            removeSpeaker(speaker.userId)
                                        },
                                        onMuteSpeaker: {
                                            muteSpeaker(speaker.userId)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                
                // Speaker Requests
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("Speaker Requests")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    if partyManager.isHostOrCoHost(partyManager.currentUserId) {
                        if partyManager.voiceChatManager.speakerRequests.filter({ $0.status == "pending" }).isEmpty {
                            Text("No pending requests")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(partyManager.voiceChatManager.speakerRequests.filter { $0.status == "pending" }) { req in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(req.userName).font(.subheadline).fontWeight(.medium)
                                            Text(req.timestamp, style: .time).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button("Approve") { partyManager.voiceChatManager.approveSpeakerRequest(req) }
                                            .buttonStyle(.borderedProminent)
                                        Button("Decline") { partyManager.voiceChatManager.declineSpeakerRequest(req) }
                                            .buttonStyle(.bordered)
                                    }
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    } else {
                        Text("Only hosts can manage speaker requests")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    // Pending count badge
                    if !partyManager.voiceChatManager.speakerRequests.filter({ $0.status == "pending" }).isEmpty {
                        let count = partyManager.voiceChatManager.speakerRequests.filter { $0.status == "pending" }.count
                        Text("\(count) pending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Muted Participants
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "mic.slash.fill")
                            .foregroundColor(.bumpinError)
                            .font(.title2)
                        Text("Muted Participants")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    let mutedIds = partyManager.currentParty?.mutedUserIds ?? []
                    if mutedIds.isEmpty {
                        Text("No muted participants")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(mutedIds, id: \.self) { uid in
                                HStack {
                                    Text(getParticipant(for: uid)?.name ?? "User")
                                        .font(.subheadline)
                                    Spacer()
                                    if partyManager.isHostOrCoHost(partyManager.currentUserId) {
                                        Button("Unmute") { partyManager.toggleRoomMute(uid, mute: false) }
                                            .buttonStyle(.bordered)
                                    }
                                }
                                .overlay(alignment: .trailing) {
                                    Image(systemName: "mic.slash")
                                        .foregroundColor(.bumpinError)
                                        .padding(.trailing, 56)
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Party Settings (Step 8)
    private var partySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 8)
            if let party = partyManager.currentParty,
               party.hostId == partyManager.currentUserId {
                HStack {
                    Image(systemName: "gearshape")
                        .foregroundColor(.bumpinPurple)
                        .font(.title2)
                    Text("Party Settings")
                        .font(.bumpinDisplaySmall)
                    Spacer()
                }
                .padding(.horizontal)

                VStack(spacing: 16) {
                    // Party Name - Enhanced Card
                    VStack(alignment: .leading, spacing: 12) {
                    HStack {
                            Image(systemName: "textformat")
                                .foregroundColor(.bumpinPurple)
                                .font(.title3)
                        Text("Party Name")
                                .font(.bumpinLabelLarge)
                        Spacer()
                        }
                        
                        TextField("Enter party name", text: Binding(
                            get: { partyManager.currentParty?.name ?? "" },
                            set: { newVal in
                                if var p = partyManager.currentParty { p.name = newVal; partyManager.currentParty = p; }
                            })
                        )
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.bumpinPurple.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(BumpinSpacing.lg)
                    .modifier(BumpinCardStyle())

                    // Public Party - Enhanced Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.bumpinPurple)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Public Party")
                                    .font(.bumpinLabelLarge)
                                Text("Allow anyone nearby to discover and join")
                                    .font(.bumpinCaptionLarge)
                                .foregroundColor(.secondary)
                        }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { partyManager.currentParty?.isPublic ?? false },
                                set: { val in if var p = partyManager.currentParty { p.isPublic = val; partyManager.currentParty = p } }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: .bumpinPurple))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )

                    // Who Can Join - Enhanced Card
                    VStack(alignment: .leading, spacing: 12) {
                    HStack {
                            Image(systemName: "lock.circle")
                                .foregroundColor(.bumpinPurple)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Who Can Join")
                                .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Control who can join your party")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                            Menu {
                            Button("Open") { updatePartyField(key: "admissionMode", value: "open") }
                                Button("Invite") { updatePartyField(key: "admissionMode", value: "invite") }
                            Button("Friends") { updatePartyField(key: "admissionMode", value: "friends") }
                                Button("Followers") { updatePartyField(key: "admissionMode", value: "followers") }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(party.admissionMode.capitalized)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundColor(.bumpinPurple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.bumpinPurple.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )

                    // Invite code (when Invite)
                    if partyManager.currentParty?.admissionMode == "invite" {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Invite Code")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Generate") { generatePartyCode(); AnalyticsService.shared.logTap(category: "party_code_generate", id: partyManager.currentParty?.id ?? "-") }
                                    .foregroundColor(.bumpinPurple)
                                if let code = partyManager.currentParty?.accessCode {
                                    Text(code.prefix(6))
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            HStack(spacing: 12) {
                                Button {
                                    if let code = partyManager.currentParty?.accessCode {
                                        UIPasteboard.general.string = String(code.prefix(6))
                                        AnalyticsService.shared.logTap(category: "party_code_copy", id: String(code.prefix(6)))
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.prepare(); generator.impactOccurred()
                                        withAnimation { inviteToast = "Copied" }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { inviteToast = nil } }
                                    }
                                } label: {
                                    Label("Copy Code", systemImage: "doc.on.doc")
                                }
                                .foregroundColor(.bumpinPurple)
                                
                                Button {
                                    showInviteShareSheet = true
                                    AnalyticsService.shared.logTap(category: "party_invite_share", id: partyManager.currentParty?.id ?? "-")
                                } label: {
                                    Label("Share Invite", systemImage: "square.and.arrow.up")
                                }
                                .foregroundColor(.bumpinPurple)
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Party Location
                    VStack(alignment: .leading, spacing: 8) {
                    HStack {
                            Image(systemName: "mappin.circle")
                                .foregroundColor(.bumpinPurple)
                            Text("Party Location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { partyManager.currentParty?.locationSharingEnabled ?? true },
                                set: { val in if var p = partyManager.currentParty { p.locationSharingEnabled = val; partyManager.currentParty = p } }
                            ))
                        }
                        Text("Show your party location to other users")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Speaking (voice chat)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mic.circle")
                                .foregroundColor(.bumpinPurple)
                            Text("Speaking")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { partyManager.currentParty?.voiceChatEnabled ?? false },
                                set: { val in if var p = partyManager.currentParty { p.voiceChatEnabled = val; partyManager.currentParty = p } }
                            ))
                        }
                        Text("Allow voice chat during the party")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if partyManager.currentParty?.voiceChatEnabled == true {
                        // Speaking Permissions
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.wave.2")
                                    .foregroundColor(.bumpinPurple)
                                Text("Speaking Permissions")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Menu((partyManager.currentParty?.speakingPermissionMode ?? "open") == "open" ? "Everyone" : "Approval") {
                                    Button("Everyone") { updatePartyField(key: "speakingPermissionMode", value: "open") }
                                    Button("Approval") { updatePartyField(key: "speakingPermissionMode", value: "approval") }
                                }
                                .foregroundColor(.bumpinPurple)
                            }
                            Text("Choose if anyone can speak or host approval is required")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // Friends Auto Permission
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.2.circle")
                                    .foregroundColor(.bumpinPurple)
                                Text("Friends Auto Permission")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { partyManager.currentParty?.friendsAutoSpeaker ?? false },
                                    set: { val in if var p = partyManager.currentParty { p.friendsAutoSpeaker = val; partyManager.currentParty = p } }
                                ))
                            }
                            Text("Friends are auto-approved to speak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Who Can Add Songs
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "music.note.list")
                                .foregroundColor(.bumpinPurple)
                            Text("Who Can Add Songs")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        Spacer()
                        Menu(party.whoCanAddSongs.capitalized) {
                            Button("All") { updatePartyField(key: "whoCanAddSongs", value: "all") }
                            Button("Host") { updatePartyField(key: "whoCanAddSongs", value: "host") }
                        }
                            .foregroundColor(.bumpinPurple)
                        }
                        Text("Control queue access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Save
                    Button("Save Settings") { persistPartySettings() }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.bumpinPurple)
                        .cornerRadius(12)

                    // Co-host management
                    if let party = partyManager.currentParty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Co-hosts")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if party.participants.isEmpty {
                                Text("No participants")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(party.participants.filter { $0.id != party.hostId }, id: \.id) { participant in
                                    HStack {
                                        Text(participant.name)
                                            .font(.body)
                                        Spacer()
                                        if party.coHostIds.contains(participant.id) {
                                            Button("Demote") { partyManager.demoteFromCoHost(participant.id) }
                                                .foregroundColor(.bumpinError)
                                        } else {
                                            Button("Promote") { partyManager.promoteToCoHost(participant.id) }
                                                .foregroundColor(.bumpinPurple)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func updatePartyField(key: String, value: String) {
        if var p = partyManager.currentParty {
            switch key {
            case "admissionMode": p.admissionMode = value
            case "whoCanAddSongs": p.whoCanAddSongs = value
            default: break
            }
            partyManager.currentParty = p
            // Analytics for setting changes
            if key == "admissionMode" { AnalyticsService.shared.logAdmissionMode(mode: value) }
            if key == "whoCanAddSongs" { AnalyticsService.shared.logQueuePermission(mode: value) }
        }
    }

    private func persistPartySettings() {
        guard let party = partyManager.currentParty else { return }
        let db = Firestore.firestore()
        let update: [String: Any] = [
            "name": party.name,
            "voiceChatEnabled": party.voiceChatEnabled,
            "isPublic": party.isPublic,
            "locationSharingEnabled": party.locationSharingEnabled,
            "admissionMode": party.admissionMode,
            "whoCanAddSongs": party.whoCanAddSongs,
            "speakingPermissionMode": party.speakingPermissionMode,
            "friendsAutoSpeaker": party.friendsAutoSpeaker,
            "accessCode": party.accessCode ?? NSNull()
        ]
        db.collection("parties").document(party.id).updateData(update)
    }

    private func generatePartyCode() {
        let code = String(UUID().uuidString.prefix(6)).uppercased()
        if var p = partyManager.currentParty { p.accessCode = code; partyManager.currentParty = p }
    }

    @State private var showInviteShareSheet: Bool = false
    private func inviteText(for party: Party) -> String {
        let code = party.accessCode ?? ""
        return "Join my Bumpin party ‘\(party.name)’! Enter code: \(code.prefix(6)). Open Bumpin > Home > Discover and use Quick Join with code."
    }
    @State private var showSavedToast: Bool = false
    @State private var showErrorToast: Bool = false
    @State private var lastErrorMessage: String = ""
    
    // MARK: - Typing Handler Functions
    private func handleTyping() {
        if !isTyping {
            isTyping = true
        }
        
        // Reset typing debounce with Task
        typingTask?.cancel()
        typingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled { stopTyping() }
        }
    }
    
    private func stopTyping() {
        isTyping = false
        typingTask?.cancel()
        typingTask = nil
    }
    
    private func sendChatMessage() {
        let trimmedText = partyManager.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📱 Send button tapped - text: '\(trimmedText)'")
        
        if !trimmedText.isEmpty {
            print("📱 Sending message...")
            
            // Try to send via Firestore first
            partyManager.sendMessage()
            
            // Also add to local messages immediately for better UX
            let user = Auth.auth().currentUser
            let senderId = user?.uid ?? ""
            let senderName = user?.displayName ?? "You"
            
            let localMessage = PartyMessage(
                messageId: UUID().uuidString,
                senderId: senderId,
                senderName: senderName,
                text: trimmedText,
                timestamp: Date(),
                profilePictureUrl: nil
            )
            
            // Add to local messages immediately
            DispatchQueue.main.async {
                self.partyManager.chatMessages.append(localMessage)
                self.partyManager.newMessageText = ""
                self.partyManager.newMessageMentions = []
                self.showMentionBar = false
                self.mentionCandidates = []
            }
            
            stopTyping()
            
            // Dismiss keyboard after sending
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        } else {
            print("📱 Message is empty, not sending")
        }
    }
    
    // MARK: - Helper Functions
    private func setupChatListener() {
        guard let partyId = partyManager.currentParty?.id else { return }
        
        let db = Firestore.firestore()
        chatListener = db.collection("parties").document(partyId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error listening for chat messages: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No chat messages found")
                    return
                }
                
                let serverMessages = documents.compactMap { document -> PartyMessage? in
                    try? document.data(as: PartyMessage.self)
                }
                
                DispatchQueue.main.async {
                    // Only update if we have new messages from server
                    // Don't overwrite local messages that haven't been saved yet
                    if !serverMessages.isEmpty {
                        // Combine server messages with local messages
                        var combinedMessages = serverMessages
                        
                        // Add any local messages that aren't in server messages
                        // Since we're in a struct, we need to access localMessages through the partyManager
                        let currentLocalMessages = self.partyManager.chatMessages.filter { message in
                            // Keep messages that are very recent (within last 10 seconds) as local
                            return message.timestamp?.timeIntervalSinceNow ?? 0 > -10
                        }
                        
                        for localMessage in currentLocalMessages {
                            if !combinedMessages.contains(where: { $0.messageId == localMessage.messageId }) {
                                combinedMessages.append(localMessage)
                            }
                        }
                        
                        // Sort by timestamp
                        combinedMessages.sort { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
                        
                        self.partyManager.chatMessages = combinedMessages
                    }
                }
            }
    }
    

    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Timer for Real-time Updates
    private func startUpdateTimer() {
        print("⏰ Starting PartyView update timer...")
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                let newCurrentTime = self.partyManager.musicManager.currentTime
                let newDuration = self.partyManager.musicManager.duration
                let newIsPlaying = self.partyManager.musicManager.isPlaying
                
                // Only update if values actually changed
                if self.currentTime != newCurrentTime {
                    self.currentTime = newCurrentTime
                    print("⏰ PartyView timer updated currentTime: \(newCurrentTime)s")
                }
                
                if self.duration != newDuration {
                    self.duration = newDuration
                }
                
                if self.isPlaying != newIsPlaying {
                    self.isPlaying = newIsPlaying
                }
            }
        }
        print("⏰ PartyView update timer started")
    }
    
    private func stopUpdateTimer() {
        print("⏰ Stopping PartyView update timer...")
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏰ PartyView update timer stopped")
    }
    
    // MARK: - Now Playing Backup Timer
    private func startNowPlayingTimer() {
        print("🎵 Starting Now Playing backup timer...")
        nowPlayingTimer?.invalidate()
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                let newCurrentSong = self.partyManager.musicManager.currentSong
                if self.currentSong?.id != newCurrentSong?.id {
                    print("🎵 Backup timer detected song change: \(newCurrentSong?.title ?? "nil")")
                    self.currentSong = newCurrentSong
                    
                    // Auto-switch to Music tab if song is playing
                    if newCurrentSong != nil && self.selectedTab != 0 {
                        print("🎵 Backup timer auto-switching to Music tab")
                        self.selectedTab = 0
                    }
                }
            }
        }
        print("🎵 Now Playing backup timer started")
    }
    
    private func stopNowPlayingTimer() {
        print("🎵 Stopping Now Playing backup timer...")
        nowPlayingTimer?.invalidate()
        nowPlayingTimer = nil
        print("🎵 Now Playing backup timer stopped")
    }

    // MARK: - Queue History View
    private var queueHistorySection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.bumpinPurple)
                    .font(.title2)
                Text("Queue History")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button(action: {
                    // Show full history view
                    showingQueueHistory = true
                }) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.bumpinPurple)
                }
            }
            
            // Show last 10 played songs
            if let party = partyManager.currentParty {
                let recentHistory = Array(party.getHistory().prefix(10))
                
                if !recentHistory.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(recentHistory) { item in
                            QueueHistoryItemViewContent(item: item)
                        }
                    }
                } else {
                    Text("No songs played yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .sheet(isPresented: $showingQueueHistory) {
            FullQueueHistoryView(partyManager: partyManager)
        }
        .sheet(isPresented: $showingVoiceChat) {
            VoiceChatView(voiceChatManager: partyManager.voiceChatManager, partyManager: partyManager)
        }
    }
    

}

// MARK: - Queue History Item View Content
struct QueueHistoryItemViewContent: View {
    let item: QueueHistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Album Art
            if let albumArt = item.song.albumArt,
               let imageData = Data(base64Encoded: albumArt),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.song.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(item.song.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(item.playedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.playedByName)
                    .font(.caption2)
                    .foregroundColor(.bumpinPurple)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PartyView(partyManager: {
        let manager = PartyManager()
        manager.currentParty = Party(name: "Test Party", hostId: "123", hostName: "Host")
        return manager
    }())
}

// MARK: - Drop View Delegate
struct DropViewDelegate: DropDelegate {
    let songId: String
    let songsToShow: [(offset: Int, element: Song)]
    let partyManager: PartyManager
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else { return false }
        
        itemProvider.loadObject(ofClass: NSString.self) { string, error in
            guard let draggedSongId = string as? String else { return }
            
            DispatchQueue.main.async {
                // Find the source and destination indices
                guard let sourceIndex = self.partyManager.musicManager.currentQueue.firstIndex(where: { $0.id == draggedSongId }),
                      let destinationIndex = self.partyManager.musicManager.currentQueue.firstIndex(where: { $0.id == self.songId }) else { return }
                
                // Only allow reordering if the indices are different
                if sourceIndex != destinationIndex {
                    self.partyManager.reorderQueue(from: sourceIndex, to: destinationIndex)
                }
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback when dragging over a drop target
    }
    
    func dropExited(info: DropInfo) {
        // Optional: Remove visual feedback when leaving drop target
    }
}

// MARK: - Custom Progress Slider (Apple Music-like)
struct CustomProgressSlider: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
    let onSeek: (TimeInterval) -> Void
    
    @State private var isDragging = false
    @State private var dragTime: TimeInterval = 0
    @State private var dragLocation: CGPoint = .zero
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return isDragging ? (dragTime / duration) : (currentTime / duration)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                // Progress track
                Rectangle()
                    .fill(Color.bumpinPurple)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .cornerRadius(2)
                
                // Thumb (slider handle)
                Circle()
                    .fill(Color.bumpinPurple)
                    .frame(width: 20, height: 20)
                    .position(x: geometry.size.width * progress, y: 2)
                    .shadow(radius: 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                dragLocation = value.location
                                
                                // Calculate new time based on drag position
                                let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                dragTime = percentage * duration
                                
                                // Update time labels in real-time
                                onSeek(dragTime)
                            }
                            .onEnded { _ in
                                isDragging = false
                                // Final seek to the dragged position
                                onSeek(dragTime)
                            }
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            dragTime = currentTime
            print("🎯 CustomProgressSlider appeared with currentTime: \(currentTime)s")
        }
        .onChange(of: currentTime, initial: false) { _, newTime in
            print("🎯 CustomProgressSlider received currentTime update: \(newTime)s")
            if !isDragging {
                dragTime = newTime
            }
        }
        .onChange(of: progress, initial: false) { _, newProgress in
            print("🎯 CustomProgressSlider progress updated: \(newProgress)")
        }
    }
}

// MARK: - Full Queue History View
struct FullQueueHistoryView: View {
    @ObservedObject var partyManager: PartyManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("History View", selection: $selectedTab) {
                    Text("All Songs").tag(0)
                    Text("Most Played").tag(1)
                    Text("Most Active").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    allSongsView
                        .tag(0)
                    
                    mostPlayedView
                        .tag(1)
                    
                    mostActiveView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Queue History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var allSongsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let party = partyManager.currentParty {
                    ForEach(party.getHistory()) { item in
                        QueueHistoryItemViewContent(item: item)
                    }
                }
            }
            .padding()
        }
    }
    
    private var mostPlayedView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let party = partyManager.currentParty {
                    ForEach(party.getMostPlayedSongs(), id: \.0.id) { song, count in
                        MostPlayedItemView(song: song, count: count)
                    }
                }
            }
            .padding()
        }
    }
    
    private var mostActiveView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let party = partyManager.currentParty {
                    ForEach(party.getMostActiveUsers(), id: \.0) { userId, count in
                        MostActiveUserView(userId: userId, count: count)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Most Played Item View
private func MostPlayedItemView(song: Song, count: Int) -> some View {
    HStack(spacing: 12) {
        // Album Art
        if let albumArt = song.albumArt,
           let imageData = Data(base64Encoded: albumArt),
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .cornerRadius(8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                )
        }
        
        VStack(alignment: .leading, spacing: 4) {
            Text(song.title)
                .font(.headline)
                .lineLimit(1)
            Text(song.artist)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.bumpinPurple)
            Text("plays")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
}

// MARK: - Most Active User View
private func MostActiveUserView(userId: String, count: Int) -> some View {
    HStack(spacing: 12) {
        Circle()
            .fill(Color.bumpinPurple)
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(userId.prefix(1).uppercased()))
                    .font(.headline)
                    .foregroundColor(.white)
            )
        
        VStack(alignment: .leading, spacing: 4) {
            Text("User \(userId.prefix(8))")
                .font(.headline)
                .lineLimit(1)
            Text("Added \(count) songs")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.bumpinPurple)
            Text("songs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
}

 