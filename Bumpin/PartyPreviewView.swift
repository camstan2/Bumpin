import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

struct PartyPreviewView: View {
    let party: Party
    let currentLocation: CLLocation?
    let onJoin: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentSong: Song?
    @State private var queuePreview: [Song] = []
    @State private var recentActivity: [QueueHistoryItem] = []
    @State private var friendsInParty: [String] = []
    @State private var isLoading = true
    @State private var showingUserProfile = false
    @State private var selectedUserId: String?
    @State private var showingAllParticipants = false
    @State private var participantsDisplayCount = 10
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            if isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading party details...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Custom Header with Close Button
                    customHeaderSection
                    
                    // Current Song Section
                    if let song = currentSong {
                        currentSongSection(song)
                    } else {
                        noCurrentSongSection
                    }
                    
                    // Queue Preview Section
                    if !queuePreview.isEmpty {
                        queuePreviewSection
                    } else {
                        noQueueSection
                    }
                    
                    // Participants Section
                    participantsSection
                    
                    // Party Stats Section
                    partyStatsSection
                    
                    // Recent Activity Section
                    if !recentActivity.isEmpty {
                        recentActivitySection
                    } else {
                        noRecentActivitySection
                    }
                    
                    // Party Rules & Settings
                    partyRulesSection
                    
                    // Location & Discovery Info
                    if let location = currentLocation {
                        locationSection(location)
                    }
                    
                    // Join Button
                    joinButtonSection
                }
                .padding(.horizontal)
                .padding(.bottom)
                }
            }
        }
        .onAppear {
            loadPartyDetails()
        }
        .fullScreenCover(isPresented: $showingUserProfile) {
            if let userId = selectedUserId {
                NavigationView {
                    UserProfileView(userId: userId)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Back") {
                                    showingUserProfile = false
                                }
                                .foregroundColor(.purple)
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Custom Header Section
    private var customHeaderSection: some View {
        VStack(spacing: 0) {
            // Top bar with close button and menu
            HStack {
                Button("Close") {
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.primary)
                
                Spacer()
                
                Text("Party Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Menu {
                    Button("Share Party") {
                        shareParty()
                    }
                    Button("Report Party", role: .destructive) {
                        reportParty()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
            
            // Party header content
            headerSection
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Party Name and Type
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(party.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        // Party type badges
                        if party.isInfluencerParty {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                        
                        if party.isFriendsParty && party.friendsOnly {
                            Text("Friends Only")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Host info with profile picture
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 20))
                            )
                            .onTapGesture {
                                selectedUserId = party.hostId
                                showingUserProfile = true
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 0) {
                                Text("Hosted by ")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(party.hostName)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                    .onTapGesture {
                                        selectedUserId = party.hostId
                                        showingUserProfile = true
                                    }
                            }
                            
                            if party.isInfluencerParty, let followerCount = party.followerCount {
                                Text("\(formatFollowerCount(followerCount)) followers")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            
            // Party duration
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("Running for \(formatDuration(Date().timeIntervalSince(party.createdAt)))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Voice chat status
                if party.voiceChatActive {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.green)
                        Text("Live Voice")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Current Song Section
    private func currentSongSection(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now Playing")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Song artwork
                if let albumArt = song.albumArt, let url = URL(string: albumArt) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(formatDuration(song.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Queue Preview Section
    private var queuePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up Next")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(queuePreview.count) songs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(queuePreview.prefix(5).enumerated()), id: \.offset) { index, song in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        if let albumArt = song.albumArt, let url = URL(string: albumArt) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 40, height: 40)
                            .cornerRadius(4)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                        }
                        
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
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Sorted Participants
    private var sortedParticipants: [PartyParticipant] {
        return party.participants.sorted { participant1, participant2 in
            // Host always comes first
            if participant1.isHost && !participant2.isHost {
                return true
            }
            if !participant1.isHost && participant2.isHost {
                return false
            }
            
            // Then friends/followed users
            let isFriend1 = friendsInParty.contains(participant1.id)
            let isFriend2 = friendsInParty.contains(participant2.id)
            
            if isFriend1 && !isFriend2 {
                return true
            }
            if !isFriend1 && isFriend2 {
                return false
            }
            
            // Finally, sort by join time (most recent first)
            return participant1.joinedAt > participant2.joinedAt
        }
    }
    
    // MARK: - Displayed Participants
    private var displayedParticipants: [PartyParticipant] {
        if showingAllParticipants {
            return sortedParticipants
        } else {
            return Array(sortedParticipants.prefix(participantsDisplayCount))
        }
    }
    
    // MARK: - Participants Section
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Participants")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(party.participants.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(displayedParticipants) { participant in
                    Button(action: {
                        selectedUserId = participant.id
                        showingUserProfile = true
                    }) {
                        HStack(spacing: 12) {
                            // Profile picture
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.purple)
                                        .font(.system(size: 16))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(participant.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    // Role badges
                                    if participant.isHost {
                                        Text("Host")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.yellow.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    
                                    // Friends indicator
                                    if friendsInParty.contains(participant.id) {
                                        Text("Friend")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text("Joined \(formatTimeAgo(participant.joinedAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // See More/Less Button
            if party.participants.count > participantsDisplayCount {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if showingAllParticipants {
                            showingAllParticipants = false
                        } else {
                            participantsDisplayCount += 10
                            if participantsDisplayCount >= party.participants.count {
                                showingAllParticipants = true
                            }
                        }
                    }
                }) {
                    HStack {
                        Text(showingAllParticipants ? "See Less" : "See More")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: showingAllParticipants ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Party Stats Section
    private var partyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Party Stats")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(party.participants.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(recentActivity.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Songs Played")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text(party.voiceChatActive ? "Live" : "Off")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(party.voiceChatActive ? .green : .gray)
                    Text("Voice Chat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(recentActivity.prefix(5))) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.playedByName) played \(item.song.title)")
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Text(formatTimeAgo(item.playedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Party Rules Section
    private var partyRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Party Rules")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("Who can add songs: \(party.whoCanAddSongs == "all" ? "Everyone" : "Host Only")")
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("Admission: \(party.admissionMode == "open" ? "Open" : party.admissionMode == "code" ? "Code Required" : "Friends Only")")
                        .font(.subheadline)
                    Spacer()
                }
                
                if party.voiceChatEnabled {
                    HStack {
                        Image(systemName: "mic")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Voice chat: \(party.voiceChatActive ? "Active" : "Available")")
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Location Section
    private func locationSection(_ location: CLLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let partyLocation = party.location {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(formatDistance(partyLocation.distance(from: location))) away")
                            .font(.subheadline)
                        
                        if let distanceText = party.formattedDistance(to: location) {
                            Text(distanceText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Join Button Section
    private var joinButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: onJoin) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.title3)
                    Text("Join Party")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            Text("You'll be able to listen to music and chat with other members")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - No Current Song Section
    private var noCurrentSongSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now Playing")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Placeholder artwork
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No song currently playing")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("Music will appear here when the party starts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - No Queue Section
    private var noQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up Next")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("0 songs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                // Placeholder artwork
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No songs in queue")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Songs will appear here when added to the queue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - No Recent Activity Section
    private var noRecentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Placeholder icon
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No recent activity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Song plays will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Functions
    private func loadPartyDetails() {
        isLoading = true
        
        // Load current song and queue
        currentSong = party.currentSong
        queuePreview = Array(party.musicQueue.prefix(5))
        
        // Load recent activity
        recentActivity = Array(party.queueHistory.prefix(5))
        
        // Check for friends in party
        loadFriendsInParty()
        
        isLoading = false
    }
    
    private func loadFriendsInParty() {
        // This would typically check against the user's friends list and followed users
        // For now, we'll use a placeholder implementation
        // In a real app, this would query Firestore for the current user's friends/following
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            friendsInParty = []
            return
        }
        
        // Placeholder: Check if any participants are friends/followed
        // In a real implementation, you would:
        // 1. Get the current user's friends list from Firestore
        // 2. Get the current user's following list from Firestore
        // 3. Check if any party participants are in those lists
        
        let db = Firestore.firestore()
        
        // Example implementation (you would need to adapt this to your data structure):
        Task {
            do {
                // Get current user's friends
                let friendsDoc = try await db.collection("users").document(currentUserId).getDocument()
                let friendsData = friendsDoc.data()
                let friendsList = friendsData?["friends"] as? [String] ?? []
                
                // Get current user's following
                let followingList = friendsData?["following"] as? [String] ?? []
                
                // Combine friends and following
                let allConnections = Set(friendsList + followingList)
                
                // Find participants who are friends/followed
                let friendsInPartyList = party.participants.compactMap { participant in
                    allConnections.contains(participant.id) ? participant.id : nil
                }
                
                await MainActor.run {
                    self.friendsInParty = friendsInPartyList
                }
            } catch {
                print("Error loading friends in party: \(error)")
                await MainActor.run {
                    self.friendsInParty = []
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval) / 60
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval) / 3600
            return "\(hours)h ago"
        } else {
            let days = Int(interval) / 86400
            return "\(days)d ago"
        }
    }
    
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    private func formatFollowerCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    private func shareParty() {
        // Implement party sharing
        let text = "Check out this party: \(party.name) by \(party.hostName)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(av, animated: true)
        }
    }
    
    private func reportParty() {
        // Implement party reporting
        print("Report party: \(party.id)")
    }
}

#Preview {
    let mockParty = Party(
        name: "Drake's Late Night",
        hostId: "host123",
        hostName: "Drake",
        isInfluencerParty: true,
        followerCount: 5000000,
        isVerified: true
    )
    
    // Add mock current song and queue data
    var partyWithMusic = mockParty
    partyWithMusic.currentSong = Song(
        title: "God's Plan",
        artist: "Drake",
        albumArt: "https://example.com/godsplan.jpg",
        duration: 198.0,
        appleMusicId: "123456789",
        isCatalogSong: true
    )
    
    partyWithMusic.musicQueue = [
        Song(title: "Hotline Bling", artist: "Drake", albumArt: "https://example.com/hotline.jpg", duration: 267.0, appleMusicId: "987654321", isCatalogSong: true),
        Song(title: "One Dance", artist: "Drake", albumArt: "https://example.com/onedance.jpg", duration: 173.0, appleMusicId: "456789123", isCatalogSong: true),
        Song(title: "In My Feelings", artist: "Drake", albumArt: "https://example.com/feelings.jpg", duration: 217.0, appleMusicId: "789123456", isCatalogSong: true),
        Song(title: "Started From the Bottom", artist: "Drake", albumArt: "https://example.com/started.jpg", duration: 145.0, appleMusicId: "321654987", isCatalogSong: true),
        Song(title: "Hold On, We're Going Home", artist: "Drake", albumArt: "https://example.com/holdon.jpg", duration: 228.0, appleMusicId: "654987321", isCatalogSong: true)
    ]
    
    partyWithMusic.queueHistory = [
        QueueHistoryItem(
            song: Song(title: "Passionfruit", artist: "Drake", albumArt: "https://example.com/passionfruit.jpg", duration: 298.0, appleMusicId: "147258369", isCatalogSong: true),
            playedBy: "host123",
            playedByName: "Drake"
        ),
        QueueHistoryItem(
            song: Song(title: "Fake Love", artist: "Drake", albumArt: "https://example.com/fakelove.jpg", duration: 199.0, appleMusicId: "258369147", isCatalogSong: true),
            playedBy: "host123",
            playedByName: "Drake"
        )
    ]
    
    return PartyPreviewView(
        party: partyWithMusic,
        currentLocation: CLLocation(latitude: 40.7128, longitude: -74.0060),
        onJoin: {}
    )
}
