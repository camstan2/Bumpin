import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ListDetailView: View {
    let list: MusicList
    var isOwner: Bool {
        Auth.auth().currentUser?.uid == list.userId
    }
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    // Playlist creation states
    @StateObject private var unifiedSearchService = UnifiedMusicSearchService.shared
    @StateObject private var playlistService = PlaylistCreationService.shared
    @State private var isCreatingPlaylist = false
    @State private var showingCreatePlaylistMenu = false
    @State private var showingResultAlert = false
    @State private var playlistResult: PlaylistCreationService.PlaylistCreationResult?
    
    // Ratings for items in the list
    @State private var itemRatings: [String: (average: Double, count: Int)] = [:]
    private let db = Firestore.firestore()
    
    // Navigation state
    @State private var selectedMusicResult: MusicSearchResult?
    @State private var selectedArtistName: String?
    @State private var showArtistProfile = false
    
    // Check if list has at least one song
    private var hasSongs: Bool {
        let songs = playlistService.filterSongsFromList(list)
        return !songs.isEmpty
    }
    
    // Check which platforms user wants and is authenticated for
    private var canCreateAppleMusicPlaylist: Bool {
        let pref = unifiedSearchService.platformPreference
        return (pref == .appleMusicOnly || pref == .both || pref == .appleMusicPrimary)
    }
    
    private var canCreateSpotifyPlaylist: Bool {
        let pref = unifiedSearchService.platformPreference
        return (pref == .spotifyOnly || pref == .both || pref == .spotifyPrimary)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 8) {
                    Text(list.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    if let desc = list.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                
                // Items Section
                HStack {
                    Text("Items")
                        .font(.headline)
                    Spacer()
                    Text("\(list.items.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                if list.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundColor(.gray)
                        Text("No items in this list.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(list.items.enumerated()), id: \.offset) { index, item in
                                itemView(for: item, at: index)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Create Playlist Button (for non-owners or always show)
                        // HIDDEN: Temporarily disabled while playlist creation is being fixed
                        /*
                        if hasSongs {
                            createPlaylistButton
                        }
                        */
                        
                        // Edit/Delete Menu (for owners only)
                        if isOwner {
                            Menu {
                                // Create Playlist options in menu for owners
                                // HIDDEN: Temporarily disabled while playlist creation is being fixed
                                /*
                                if hasSongs {
                                    if canCreateAppleMusicPlaylist {
                                        Button(action: {
                                            createPlaylist(platform: "apple_music")
                                        }) {
                                            Label("Create Apple Music Playlist", systemImage: "music.note")
                                        }
                                    }
                                    
                                    if canCreateSpotifyPlaylist {
                                        Button(action: {
                                            createPlaylist(platform: "spotify")
                                        }) {
                                            Label("Create Spotify Playlist", systemImage: "music.note")
                                        }
                                    }
                                    
                                    Divider()
                                }
                                */
                                
                                Button("Edit List") {
                                    onEdit?()
                                }
                                Button("Delete List", role: .destructive) {
                                    showingDeleteAlert = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
            .alert("Delete List", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete?()
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Are you sure you want to delete '\(list.title)'? This action cannot be undone.")
            }
            .alert(
                playlistResult?.platform ?? "Playlist",
                isPresented: $showingResultAlert,
                presenting: playlistResult
            ) { result in
                if result.success {
                    Button("Open in \(result.platform)") {
                        openPlaylist(result: result)
                    }
                    Button("Done", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: { result in
                if result.success {
                    if let skipped = result.skippedMessage {
                        Text("Playlist '\(result.playlistName)' created with \(result.addedSongs) song\(result.addedSongs == 1 ? "" : "s")! \(skipped).")
                    } else {
                        Text("Playlist '\(result.playlistName)' created successfully with \(result.addedSongs) song\(result.addedSongs == 1 ? "" : "s")!")
                    }
                } else {
                    Text(result.error?.localizedDescription ?? "Failed to create playlist")
                }
            }
            .overlay {
                if isCreatingPlaylist {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Creating playlist...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                    }
                }
            }
            .onAppear {
                fetchRatingsForItems()
            }
            .fullScreenCover(item: $selectedMusicResult) { music in
                MusicProfileView(musicItem: music, pinnedLog: nil)
            }
            .fullScreenCover(isPresented: $showArtistProfile) {
                if let artistName = selectedArtistName {
                    ArtistProfileView(artistName: artistName)
                }
            }
        }
    }
    
    // MARK: - Fetch Ratings
    
    private func fetchRatingsForItems() {
        Task {
            var ratings: [String: (average: Double, count: Int)] = [:]
            
            // Parse all items and extract song IDs
            var songIds: [String] = []
            for item in list.items {
                if let data = item.data(using: .utf8),
                   let result = try? JSONDecoder().decode(MusicSearchResult.self, from: data),
                   result.itemType == "song" {
                    songIds.append(result.id)
                }
            }
            
            // Fetch ratings for each song
            for songId in songIds {
                do {
                    let snapshot = try await db.collection("logs")
                        .whereField("itemId", isEqualTo: songId)
                        .whereField("itemType", isEqualTo: "song")
                        .getDocuments()
                    
                    let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                    let ratingsList = logs.compactMap { $0.rating }
                    
                    if !ratingsList.isEmpty {
                        let average = Double(ratingsList.reduce(0, +)) / Double(ratingsList.count)
                        let count = ratingsList.count
                        ratings[songId] = (average, count)
                    }
                } catch {
                    print("❌ Failed to fetch ratings for song \(songId): \(error)")
                }
            }
            
            await MainActor.run {
                itemRatings = ratings
            }
        }
    }
    
    // MARK: - Create Playlist Button (for non-owners)
    
    @ViewBuilder
    private var createPlaylistButton: some View {
        if !isOwner {
            // For non-owners, show standalone button(s)
            if canCreateAppleMusicPlaylist && canCreateSpotifyPlaylist {
                // Show menu with both options
                Menu {
                    Button(action: {
                        createPlaylist(platform: "apple_music")
                    }) {
                        Label("Apple Music", systemImage: "applelogo")
                    }
                    
                    Button(action: {
                        createPlaylist(platform: "spotify")
                    }) {
                        Label("Spotify", systemImage: "music.note")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
            } else if canCreateAppleMusicPlaylist {
                // Single Apple Music button
                Button(action: {
                    createPlaylist(platform: "apple_music")
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
            } else if canCreateSpotifyPlaylist {
                // Single Spotify button
                Button(action: {
                    createPlaylist(platform: "spotify")
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                }
            }
        }
    }
    
    // MARK: - Playlist Creation Logic
    
    private func createPlaylist(platform: String) {
        isCreatingPlaylist = true
        
        Task {
            let songs = playlistService.filterSongsFromList(list)
            let result: PlaylistCreationService.PlaylistCreationResult
            
            if platform == "apple_music" {
                result = await playlistService.createAppleMusicPlaylist(name: list.title, songs: songs)
            } else {
                result = await playlistService.createSpotifyPlaylist(name: list.title, songs: songs)
            }
            
            await MainActor.run {
                isCreatingPlaylist = false
                playlistResult = result
                showingResultAlert = true
            }
        }
    }
    
    private func openPlaylist(result: PlaylistCreationService.PlaylistCreationResult) {
        guard let playlistId = result.playlistId else { return }
        
        if result.platform == "Apple Music" {
            playlistService.openAppleMusicPlaylist(playlistId: playlistId)
        } else {
            playlistService.openSpotifyPlaylist(playlistId: playlistId)
        }
    }
    
    @ViewBuilder
    private func itemView(for item: String, at index: Int) -> some View {
        if let data = item.data(using: .utf8),
           let result = try? JSONDecoder().decode(MusicSearchResult.self, from: data) {
            // Modern JSON format - show full music item
            HStack(spacing: 12) {
                EnhancedArtworkView(
                    artworkUrl: result.artworkURL,
                    itemType: result.itemType,
                    size: 50
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !result.artistName.isEmpty {
                        Text(result.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    // Rating display (only for songs)
                    if result.itemType == "song" {
                        if let rating = itemRatings[result.id], rating.count > 0 {
                            HStack(spacing: 4) {
                                Text(String(format: "%.1f", rating.average))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                StarRatingView(rating: rating.average, size: 8)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.purple.opacity(0.1))
                            )
                        } else {
                            Text("No ratings yet")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.purple.opacity(0.1))
                                )
                        }
                    } else {
                        // For non-songs, show item type
                    Text(result.itemType.capitalized)
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.purple.opacity(0.1))
                        )
                    }
                }
                
                Spacer()
                
                Text("#\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                // Navigate based on item type
                if result.itemType == "artist" {
                    selectedArtistName = result.artistName
                    showArtistProfile = true
                } else {
                    // For songs and albums, navigate to music profile
                    selectedMusicResult = result
                }
            }
        } else {
            // Legacy format - show basic text
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                    Image(systemName: "music.note")
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Legacy Item")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("#\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
    
} 