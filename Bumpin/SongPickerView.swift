//
//  SongPickerView.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import MediaPlayer
import MusicKit

// Auto-queue mode enum (shared between structs)
enum AutoQueueMode: String, Codable {
    case ordered
    case random
}

// Play Next Song Picker View (enables multi-selection but disables auto-queue)
struct PlayNextSongPickerView: View {
    @Binding var isPresented: Bool
    let onSongSelected: (Song) -> Void
    let onMultipleSongsSelected: (([Song], String?, [Song]?) -> Void)?
    
    init(isPresented: Binding<Bool>, 
         onSongSelected: @escaping (Song) -> Void,
         onMultipleSongsSelected: (([Song], String?, [Song]?) -> Void)? = nil) {
        self._isPresented = isPresented
        self.onSongSelected = onSongSelected
        self.onMultipleSongsSelected = onMultipleSongsSelected
    }
    
    @State private var searchText = ""
    @State private var searchResults: [MusicSearchResult] = []
    @State private var isSearching = false
    @State private var selectedTab = 0 // 0 = Search, 1 = Library
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedSongs: Set<String> = [] // For multiple selection
    @State private var selectionMode = false
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("", selection: $selectedTab) {
                    Text("Search").tag(0)
                    Text("Library").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    catalogSearchView
                } else {
                    CustomMediaPicker(
                        onSongSelected: onSongSelected,
                        onMultipleSongsSelected: onMultipleSongsSelected,
                        isPresented: $isPresented,
                        selectionMode: selectionMode,
                        autoQueueMode: .ordered,
                        isQueueMode: true, // Enable multi-selection
                        disableAutoQueue: true // Disable auto-queue for Play Next
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { 
                        selectedSongs.removeAll()
                        selectionMode = false
                        isPresented = false 
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if selectionMode {
                            Button("Done (\(selectedSongs.count))") {
                                addSelectedSongsToQueue()
                            }
                            .disabled(selectedSongs.isEmpty)
                        } else {
                            Button("Select Multiple") {
                                selectionMode = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Play Next")
        }
    }
    
    private var catalogSearchView: some View {
        VStack {
            SearchBar(text: $searchText, placeholder: "Search for songs...")
                .onChange(of: searchText) { _ in
                    startSearch()
                }
            
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults, id: \.id) { result in
                            HStack(spacing: 12) {
                                // Album Art
                                if let artworkUrl = result.artworkURL, let url = URL(string: artworkUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(6)
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 20))
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Text(result.artistName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // Selection indicator
                                if selectionMode {
                                    Image(systemName: selectedSongs.contains(result.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedSongs.contains(result.id) ? .purple : .gray)
                                        .font(.title2)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .opacity(selectionMode && !selectedSongs.contains(result.id) ? 0.6 : 1.0)
                            .onTapGesture {
                                if selectionMode {
                                    if selectedSongs.contains(result.id) {
                                        selectedSongs.remove(result.id)
                                    } else {
                                        selectedSongs.insert(result.id)
                                    }
                                } else {
                                    let song = Song(
                                        title: result.title,
                                        artist: result.artistName,
                                        albumArt: result.artworkURL,
                                        duration: 0,
                                        appleMusicId: result.id,
                                        isCatalogSong: true
                                    )
                                    onSongSelected(song)
                                    isPresented = false
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func startSearch() {
        searchTask?.cancel()
        searchTask = Task {
            await performSearch(query: searchText)
        }
    }
    
    private func performSearch(query: String) async {
        isSearching = true
        // TODO: Implement actual search using MusicKit
        // For now, just simulate search
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        isSearching = false
    }
    
    private func addSelectedSongsToQueue() {
        let selectedResults = searchResults.filter { selectedSongs.contains($0.id) }
        let songObjects = selectedResults.map { result in
            Song(
                title: result.title,
                artist: result.artistName,
                                                        albumArt: result.artworkURL,
                duration: 0,
                appleMusicId: result.id,
                isCatalogSong: true
            )
        }
        
        if let onMultipleSongsSelected = onMultipleSongsSelected {
            onMultipleSongsSelected(songObjects, nil, nil)
        } else {
            for song in songObjects {
                onSongSelected(song)
            }
        }
        
        selectedSongs.removeAll()
        selectionMode = false
        isPresented = false
    }
}

struct SongPickerView: View {
    @Binding var isPresented: Bool
    let onSongSelected: (Song) -> Void
    let onMultipleSongsSelected: (([Song], String?, [Song]?) -> Void)?
    let isQueueMode: Bool
    let autoQueueMode: AutoQueueMode?
    
    init(isPresented: Binding<Bool>, 
         onSongSelected: @escaping (Song) -> Void,
         onMultipleSongsSelected: (([Song], String?, [Song]?) -> Void)? = nil,
         isQueueMode: Bool = false,
         autoQueueMode: AutoQueueMode? = nil) {
        self._isPresented = isPresented
        self.onSongSelected = onSongSelected
        self.onMultipleSongsSelected = onMultipleSongsSelected
        self.isQueueMode = isQueueMode
        self.autoQueueMode = autoQueueMode
    }
    
    @State private var searchText = ""
    @State private var searchResults: [MusicSearchResult] = []
    @State private var isSearching = false
    @State private var selectedTab = 0 // 0 = Search, 1 = Library
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedSongs: Set<String> = []
    @State private var selectionMode = false
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("", selection: $selectedTab) {
                    Text("Search").tag(0)
                    Text("Library").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    catalogSearchView
                } else {
                    CustomMediaPicker(
                        onSongSelected: onSongSelected,
                        onMultipleSongsSelected: onMultipleSongsSelected,
                        isPresented: $isPresented,
                        selectionMode: selectionMode,
                        autoQueueMode: autoQueueMode,
                        isQueueMode: isQueueMode,
                        disableAutoQueue: false // Regular Add to Queue
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { 
                        selectedSongs.removeAll()
                        selectionMode = false
                        isPresented = false 
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isQueueMode {
                            if selectionMode {
                                Button("Done (\(selectedSongs.count))") {
                                    addSelectedSongsToQueue()
                                }
                                .disabled(selectedSongs.isEmpty)
                            } else {
                                Button("Select Multiple") {
                                    selectionMode = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isQueueMode ? "Add to Queue" : "Choose Song")
        }
    }
    
    private var catalogSearchView: some View {
        VStack {
            SearchBar(text: $searchText, placeholder: "Search for songs...")
                .onChange(of: searchText) { _ in
                    searchTask?.cancel()
                    if !searchText.isEmpty {
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                            if !Task.isCancelled {
                                print("🔍 SongPickerView: Performing search for '\(searchText)'")
                                await performSearch(query: searchText)
                            }
                        }
                    } else {
                        // Clear results when search text is empty
                        searchResults = []
                    }
                }
            
            // Selection mode indicator
            if selectionMode {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                    Text("Tap songs to select multiple")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack {
                    Text("No results found")
                        .foregroundColor(.secondary)
                    // Error handling removed for now
                    Text("Search failed")
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Using ForEach with LazyVStack instead of List to avoid tap gesture conflicts
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults.filter { $0.itemType == "song" }) { result in
                            songRowView(for: result)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedSongs.contains(result.id) ? Color.purple.opacity(0.1) : Color.clear)
                                )
                                .onTapGesture {
                                    handleSongTap(result: result)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
    }
    
    private func songRowView(for result: MusicSearchResult) -> some View {
        HStack(spacing: 12) {
            // Album artwork
                                                    AsyncImage(url: URL(string: result.artworkURL ?? "")) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            .opacity(selectionMode && !selectedSongs.contains(result.id) ? 0.6 : 1.0)
            
            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.headline)
                    .foregroundColor(selectionMode && selectedSongs.contains(result.id) ? .purple : .primary)
                Text(result.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Selection indicator
            if selectionMode {
                Image(systemName: selectedSongs.contains(result.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedSongs.contains(result.id) ? .purple : .gray)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    private func handleSongTap(result: MusicSearchResult) {
        if selectionMode {
            // Toggle selection
            if selectedSongs.contains(result.id) {
                selectedSongs.remove(result.id)
            } else {
                selectedSongs.insert(result.id)
            }
        } else {
            // Single song selection
            let song = Song(
                title: result.title,
                artist: result.artistName,
                albumArt: result.artworkURL,
                duration: 0,
                appleMusicId: result.id,
                isCatalogSong: true
            )
            
            // Check if we should fetch album context for auto-queuing
            if !isQueueMode {
                Task {
                    await fetchAlbumContextAndQueue(for: song, selectedSong: song)
                }
            } else {
                onSongSelected(song)
                isPresented = false
            }
        }
    }
    
    private func performSearch(query: String) async {
        isSearching = true
        // TODO: Implement actual search using MusicKit
        // For now, just simulate search
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        isSearching = false
    }
    
    private var libraryView: some View {
        CustomMediaPicker(
            onSongSelected: onSongSelected,
            onMultipleSongsSelected: onMultipleSongsSelected,
            isPresented: $isPresented,
            selectionMode: selectionMode,
            autoQueueMode: autoQueueMode,
            isQueueMode: isQueueMode,
            disableAutoQueue: false // Regular Add to Queue
        )
    }
    
    private func addSelectedSongsToQueue() {
        let selectedResults = searchResults.filter { selectedSongs.contains($0.id) }
        let songsToAdd = selectedResults.map { result in
            Song(
                title: result.title,
                artist: result.artistName,
                albumArt: result.artworkURL,
                duration: 0,
                appleMusicId: result.id,
                isCatalogSong: true
            )
        }
        
        if let onMultipleSongsSelected = onMultipleSongsSelected {
            onMultipleSongsSelected(songsToAdd, nil, nil)
        } else {
            // Fallback: add songs one by one
            for song in songsToAdd {
                onSongSelected(song)
            }
        }
        
        selectedSongs.removeAll()
        selectionMode = false
        isPresented = false
    }
    
    private func fetchAlbumContextAndQueue(for song: Song, selectedSong: Song) async {
        guard let appleMusicId = song.appleMusicId else {
            // Fallback: just add the single song
            await MainActor.run {
                onSongSelected(song)
                isPresented = false
            }
            return
        }
        
        do {
            // Get the song from Apple Music to find its album
            let songID = MusicItemID(appleMusicId)
            let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: songID)
            let response = try await request.response()
            
            guard let catalogSong = response.items.first,
                  let albumID = catalogSong.albums?.first?.id else {
                // Fallback: just add the single song
                await MainActor.run {
                    onSongSelected(song)
                    isPresented = false
                }
                return
            }
            
            // Fetch the full album
            let albumRequest = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: albumID)
            let albumResponse = try await albumRequest.response()
            
            guard let album = albumResponse.items.first else {
                // Fallback: just add the single song
                await MainActor.run {
                    onSongSelected(song)
                    isPresented = false
                }
                return
            }
            
            // Get album tracks with the selected song and queue the rest
            let detailedAlbumRequest = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: albumID)
            let detailedResponse = try await detailedAlbumRequest.response()
            
            guard let detailedAlbum = detailedResponse.items.first else {
                // Fallback: just add the single song
                await MainActor.run {
                    onSongSelected(song)
                    isPresented = false
                }
                return
            }
            
            // Create Song objects from album tracks  
            let albumSongs = detailedAlbum.tracks?.compactMap { track -> Song? in
                Song(
                    title: track.title,
                    artist: track.artistName,
                    albumArt: track.artwork?.url(width: 300, height: 300)?.absoluteString,
                    duration: TimeInterval(track.duration ?? 0),
                    appleMusicId: track.id.rawValue,
                    isCatalogSong: true
                )
            } ?? []
            
            // Find the selected song in the album and queue from that point
            if let selectedIndex = albumSongs.firstIndex(where: { $0.appleMusicId == selectedSong.appleMusicId }) {
                let songsToQueue = Array(albumSongs[selectedIndex...])
                
                await MainActor.run {
                    // Play the selected song first
                    onSongSelected(selectedSong)
                    
                    // Queue the rest of the album (if there's a multiple songs callback)
                    if let onMultipleSongsSelected = onMultipleSongsSelected,
                       songsToQueue.count > 1 {
                        let remainingSongs = Array(songsToQueue.dropFirst())
                        onMultipleSongsSelected(remainingSongs, nil, nil)
                    }
                    
                    isPresented = false
                }
            } else {
                // Fallback: just add the single song
                await MainActor.run {
                    onSongSelected(song)
                    isPresented = false
                }
            }
            
        } catch {
            // Error fallback: just add the single song
            await MainActor.run {
                onSongSelected(song)
                isPresented = false
            }
        }
    }
}

// MARK: - Custom Media Picker

struct CustomMediaPicker: View {
    let onSongSelected: (Song) -> Void
    let onMultipleSongsSelected: (([Song], String?, [Song]?) -> Void)?
    @Binding var isPresented: Bool
    let selectionMode: Bool
    let autoQueueMode: AutoQueueMode?
    let isQueueMode: Bool
    let disableAutoQueue: Bool // New parameter to disable auto-queue for Play Next
    
    @StateObject private var mediaManager = CustomMediaManager()
    @State private var selectedSongs: Set<String> = []
    @State private var searchText = ""
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    // Auto-queue mode enum (now defined at file level)
    
    @State private var currentView: MediaViewType = .browse
    @State private var navigationStack: [MediaViewType] = []
    @State private var currentPlaylist: MediaPlaylist?
    
    enum MediaViewType {
        case browse
        case playlists
        case songs
        case playlistSongs
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar (only show on songs view)
                if currentView == .songs {
                    SearchBar(text: $searchText, placeholder: "Search your library...")
                        .onChange(of: searchText) { _ in
                            mediaManager.filterSongs(searchText)
                        }
                }
                
                // Selection mode indicator
                if selectionMode {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.purple)
                        Text("Tap items to select multiple")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                        Spacer()
                        if !selectedSongs.isEmpty {
                            Text("\(selectedSongs.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Button("Done (\(selectedSongs.count))") {
                            addSelectedSongsToQueue()
                        }
                        .disabled(selectedSongs.isEmpty)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // Content based on current view
                Group {
                                    switch currentView {
                case .browse:
                    browseView
                case .playlists:
                    playlistsView
                case .songs:
                    songsView
                case .playlistSongs:
                    playlistSongsView

                }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentView == .browse {
                        Button("Cancel") {
                            selectedSongs.removeAll()
                            isPresented = false
                        }
                    } else {
                        Button("Back") {
                            navigateBack()
                        }
                    }
                }
            }
        }
        .onAppear {
            mediaManager.requestPermissionAndLoadMedia()
        }
        .onChange(of: mediaManager.hasPermission) { hasPermission in
            if !hasPermission && !mediaManager.isLoading {
                permissionAlertMessage = "Please allow access to your music library in Settings to use this feature."
                showingPermissionAlert = true
            }
        }
        .alert("Library Access", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
        .sheet(isPresented: $mediaManager.showingPlaylistSelector) {
            PlaylistSelectorView(mediaManager: mediaManager)
        }
    }
    
    private var navigationTitle: String {
        switch currentView {
        case .browse: return "Library"
        case .playlists: return "Playlists"
        case .songs: return "Songs"
        case .playlistSongs: return currentPlaylist?.name ?? "Playlist"

        }
    }
    
    // MARK: - Browse View
    
    private var browseView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                browseCard(
                    title: "Playlists",
                    subtitle: mediaManager.isLoadingPlaylists ? "Loading..." : "\(mediaManager.playlists.count) playlists",
                    icon: "music.note.list",
                    color: .blue,
                    showSettings: true
                ) {
                    mediaManager.loadPlaylistsIfNeeded()
                    currentView = .playlists
                    navigationStack.append(.browse)
                } settingsAction: {
                    mediaManager.showingPlaylistSelector = true
                }
                
                browseCard(
                    title: "Songs",
                    subtitle: mediaManager.isLoadingSongs ? "Loading..." : "\(mediaManager.songs.count) songs",
                    icon: "music.note",
                    color: .purple
                ) {
                    mediaManager.loadSongsIfNeeded()
                    currentView = .songs
                    navigationStack.append(.browse)
                }
            }
            .padding()
        }
    }
    
    private func browseCard(title: String, subtitle: String, icon: String, color: Color, showSettings: Bool = false, action: @escaping () -> Void, settingsAction: (() -> Void)? = nil) -> some View {
        ZStack {
            Button(action: action) {
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if showSettings, let settingsAction = settingsAction {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: settingsAction) {
                            Image(systemName: "gearshape.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(6)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(radius: 1)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
        }
    }
    
    // MARK: - Playlists View
    
    private var playlistsView: some View {
        Group {
            if mediaManager.isLoadingPlaylists {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading playlists...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Phase 2: Background processing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mediaManager.playlists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No playlists found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Make sure you have playlists in your library")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(mediaManager.playlists) { playlist in
                            playlistRow(playlist)
                                .onTapGesture {
                                    currentPlaylist = playlist
                                    currentView = .playlistSongs
                                    navigationStack.append(.playlists)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func playlistRow(_ playlist: MediaPlaylist) -> some View {
        HStack(spacing: 12) {
            // Playlist artwork
            if let artworkData = playlist.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                Color.blue.opacity(0.2)
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .foregroundColor(.blue)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(playlist.songCount) songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    
    // MARK: - Songs View
    
    private var songsView: some View {
        Group {
            if mediaManager.isLoadingSongs {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading songs...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Phase 2: Background processing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mediaManager.songs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No songs found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if !mediaManager.hasPermission {
                        Text("Please allow access to your music library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Make sure you have songs in your library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mediaManager.filteredSongs.isEmpty && !searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No matching songs")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(mediaManager.filteredSongs) { song in
                            songRow(song)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedSongs.contains(song.id) ? Color.purple.opacity(0.1) : Color.clear)
                                )
                                .onTapGesture {
                                    handleSongTap(song)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Playlist Songs View
    
    private var playlistSongsView: some View {
        Group {
            if let playlist = currentPlaylist {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(playlist.songs) { song in
                            songRow(song)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedSongs.contains(song.id) ? Color.purple.opacity(0.1) : Color.clear)
                                )
                                .onTapGesture {
                                    handleSongTap(song)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("Playlist not found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    

    
    // MARK: - Song Row
    
    private func songRow(_ song: MediaSong) -> some View {
        HStack(spacing: 12) {
            // Album artwork
            Group {
                if let artworkData = song.artworkData,
                   let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                } else {
                    Color.gray.opacity(0.2)
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        )
                }
            }
            .opacity(selectionMode && !selectedSongs.contains(song.id) ? 0.6 : 1.0)
            
            // Song info with auto-queue indicator
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(song.title)
                        .font(.headline)
                        .foregroundColor(selectionMode && selectedSongs.contains(song.id) ? .purple : .primary)
                    
                    // Auto-queue indicator (only show in playlist context)
                    if currentPlaylist != nil && !selectionMode {
                        HStack(spacing: 2) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .opacity(0.7)
                            
                            // Mode indicator
                            if let queueMode = autoQueueMode {
                                Image(systemName: queueMode == .random ? "shuffle" : "list.number")
                                    .foregroundColor(.blue)
                                    .font(.caption2)
                                    .opacity(0.7)
                            }
                        }
                    }
                }
                
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let album = song.album {
                    Text(album)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Selection indicator
            if selectionMode {
                Image(systemName: selectedSongs.contains(song.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedSongs.contains(song.id) ? .purple : .gray)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Navigation
    
    private func navigateBack() {
        if let previousView = navigationStack.popLast() {
            currentView = previousView
        } else {
            currentView = .browse
        }
    }
    
    // MARK: - Song Selection
    
    private func handleSongTap(_ song: MediaSong) {
        if selectionMode {
            // Toggle selection
            if selectedSongs.contains(song.id) {
                selectedSongs.remove(song.id)
            } else {
                selectedSongs.insert(song.id)
            }
        } else {
            // Check if we're in a playlist context for auto-queue (only if isQueueMode is true and auto-queue is not disabled)
            if let currentPlaylist = currentPlaylist, isQueueMode && !disableAutoQueue {
                // Auto-queue feature: add song + next 19 songs from playlist
                autoQueueFromPlaylist(startingSong: song, playlist: currentPlaylist)
            } else {
                // Regular single song selection
                let songObject = Song(
                    title: song.title,
                    artist: song.artist,
                    albumArt: song.artworkData?.base64EncodedString(),
                    duration: song.duration,
                    appleMusicId: song.appleMusicId,
                    isCatalogSong: false
                )
                
                onSongSelected(songObject)
            }
            isPresented = false
        }
    }
    
    private func addSelectedSongsToQueue() {
        let songsToAdd: [MediaSong]
        
        switch currentView {
        case .songs:
            songsToAdd = mediaManager.filteredSongs.filter { selectedSongs.contains($0.id) }
        case .playlistSongs:
            songsToAdd = currentPlaylist?.songs.filter { selectedSongs.contains($0.id) } ?? []
        default:
            songsToAdd = []
        }
        
        let songObjects = songsToAdd.map { mediaSong in
            Song(
                title: mediaSong.title,
                artist: mediaSong.artist,
                albumArt: mediaSong.artworkData?.base64EncodedString(),
                duration: mediaSong.duration,
                appleMusicId: mediaSong.appleMusicId,
                isCatalogSong: false
            )
        }
        
        if let onMultipleSongsSelected = onMultipleSongsSelected {
            // Pass playlist information if we're in a playlist context
            let playlistId = currentPlaylist?.id
            let playlistSongs = currentPlaylist?.songs.map { mediaSong in
                Song(
                    title: mediaSong.title,
                    artist: mediaSong.artist,
                    albumArt: mediaSong.artworkData?.base64EncodedString(),
                    duration: mediaSong.duration,
                    appleMusicId: mediaSong.appleMusicId,
                    isCatalogSong: false
                )
            }
            onMultipleSongsSelected(songObjects, playlistId, playlistSongs)
        } else {
            // Fallback: add songs one by one
            for song in songObjects {
                onSongSelected(song)
            }
        }
        
        selectedSongs.removeAll()
        isPresented = false
    }
    
    // Auto-queue feature: Add song + next batch of songs from playlist
    private func autoQueueFromPlaylist(startingSong: MediaSong, playlist: MediaPlaylist) {
        guard let startingIndex = playlist.songs.firstIndex(where: { $0.id == startingSong.id }) else {
            // Fallback to single song if not found
            let songObject = Song(
                title: startingSong.title,
                artist: startingSong.artist,
                albumArt: startingSong.artworkData?.base64EncodedString(),
                duration: startingSong.duration,
                appleMusicId: startingSong.appleMusicId,
                isCatalogSong: false
            )
            onSongSelected(songObject)
            return
        }
        
        // Calculate the batch of songs to queue based on mode
        let batchSize = 20 // You can adjust this number
        var songsToQueue: [MediaSong]
        
        if let queueMode = autoQueueMode, queueMode == .random {
            // Random mode: put selected song first, then add random songs
            var availableSongs = playlist.songs
            // Remove the selected song from the available songs to avoid duplicates
            availableSongs.removeAll { $0.id == startingSong.id }
            // Shuffle the remaining songs and take batchSize - 1 (since we're adding the selected song first)
            let randomSongs = Array(availableSongs.shuffled().prefix(batchSize - 1))
            // Put the selected song first, then add the random songs
            songsToQueue = [startingSong] + randomSongs
            print("🎲 Random mode: queuing selected song first, then \(randomSongs.count) random songs")
        } else {
            // Ordered mode: get songs starting from the tapped song
            let endIndex = min(startingIndex + batchSize, playlist.songs.count)
            songsToQueue = Array(playlist.songs[startingIndex..<endIndex])
            print("📋 Ordered mode: queuing \(songsToQueue.count) songs starting from position \(startingIndex)")
        }
        
        print("🎵 Auto-queuing \(songsToQueue.count) songs from playlist '\(playlist.name)' starting from '\(startingSong.title)'")
        
        // Convert to Song objects
        let songObjects = songsToQueue.map { mediaSong in
            Song(
                title: mediaSong.title,
                artist: mediaSong.artist,
                albumArt: mediaSong.artworkData?.base64EncodedString(),
                duration: mediaSong.duration,
                appleMusicId: mediaSong.appleMusicId,
                isCatalogSong: false
            )
        }
        
        // Add all songs to queue with playlist information
        if let onMultipleSongsSelected = onMultipleSongsSelected {
            // Pass playlist information for smart queue regeneration
            let playlistId = playlist.id
            let playlistSongs = playlist.songs.map { mediaSong in
                Song(
                    title: mediaSong.title,
                    artist: mediaSong.artist,
                    albumArt: mediaSong.artworkData?.base64EncodedString(),
                    duration: mediaSong.duration,
                    appleMusicId: mediaSong.appleMusicId,
                    isCatalogSong: false
                )
            }
            onMultipleSongsSelected(songObjects, playlistId, playlistSongs)
        } else {
            // Fallback: add songs one by one
            for song in songObjects {
                onSongSelected(song)
            }
        }
        
        // Show feedback to user
        showAutoQueueFeedback(songCount: songsToQueue.count, playlistName: playlist.name)
    }
    
    // Show feedback for auto-queue action
    private func showAutoQueueFeedback(songCount: Int, playlistName: String) {
        // You can implement a toast notification here
        print("🎵 Auto-queued \(songCount) songs from '\(playlistName)'")
        
        // For now, we'll just print to console
        // In the future, you could add a toast notification or haptic feedback
    }
}

// MARK: - Custom Library Browser





struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.searchBarStyle = .minimal
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        let parent: SearchBar
        
        init(_ parent: SearchBar) {
            self.parent = parent
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
} 

// MARK: - Custom Media Manager

class CustomMediaManager: ObservableObject {
    @Published var songs: [MediaSong] = []
    @Published var filteredSongs: [MediaSong] = []
    @Published var playlists: [MediaPlaylist] = []
    @Published var isLoading = false
    @Published var hasPermission = false
    @Published var showingPlaylistSelector = false
    @Published var selectedPlaylistIds: Set<String> = []
    
    // Phase 2: Smart Loading - Caching and Lazy Loading
    @Published var songsLoaded = false
    @Published var playlistsLoaded = false
    @Published var isLoadingSongs = false
    @Published var isLoadingPlaylists = false
    
    private var allSongs: [MediaSong] = []
    private var allPlaylists: [MediaPlaylist] = []
    private let userDefaults = UserDefaults.standard
    private let selectedPlaylistsKey = "SelectedPlaylistIds"
    
    // Phase 2: Caching system
    private let songsCacheKey = "CachedSongs"
    private let playlistsCacheKey = "CachedPlaylists"
    private let lastCacheUpdateKey = "LastCacheUpdate"
    
    init() {
        loadSelectedPlaylists()
        loadCachedData()
    }
    
    private func loadSelectedPlaylists() {
        if let savedIds = userDefaults.array(forKey: selectedPlaylistsKey) as? [String] {
            selectedPlaylistIds = Set(savedIds)
        }
    }
    
    private func saveSelectedPlaylists() {
        userDefaults.set(Array(selectedPlaylistIds), forKey: selectedPlaylistsKey)
    }
    
    // Phase 2: Cache management
    private func loadCachedData() {
        // Load cached songs if available and not too old (24 hours)
        if let cachedSongsData = userDefaults.data(forKey: songsCacheKey),
           let lastUpdate = userDefaults.object(forKey: lastCacheUpdateKey) as? Date,
           Date().timeIntervalSince(lastUpdate) < 86400 { // 24 hours
            do {
                let songs = try JSONDecoder().decode([MediaSong].self, from: cachedSongsData)
                self.allSongs = songs
                self.songs = songs
                self.filteredSongs = songs
                self.songsLoaded = true
                print("📚 Loaded \(songs.count) songs from cache")
            } catch {
                print("❌ Failed to load cached songs: \(error)")
            }
        }
        
        // Load cached playlists if available and not too old (24 hours)
        if let cachedPlaylistsData = userDefaults.data(forKey: playlistsCacheKey),
           let lastUpdate = userDefaults.object(forKey: lastCacheUpdateKey) as? Date,
           Date().timeIntervalSince(lastUpdate) < 86400 { // 24 hours
            do {
                let playlists = try JSONDecoder().decode([MediaPlaylist].self, from: cachedPlaylistsData)
                self.allPlaylists = playlists
                
                // Apply playlist filtering based on selected playlists
                applyPlaylistFiltering()
                
                self.playlistsLoaded = true
                print("📚 Loaded \(playlists.count) playlists from cache, filtered to \(self.playlists.count) selected playlists")
            } catch {
                print("❌ Failed to load cached playlists: \(error)")
            }
        }
    }
    
    private func saveCachedData() {
        do {
            // Cache songs
            let songsData = try JSONEncoder().encode(allSongs)
            userDefaults.set(songsData, forKey: songsCacheKey)
            
            // Cache playlists
            let playlistsData = try JSONEncoder().encode(allPlaylists)
            userDefaults.set(playlistsData, forKey: playlistsCacheKey)
            
            // Update cache timestamp
            userDefaults.set(Date(), forKey: lastCacheUpdateKey)
            
            print("📚 Cached \(allSongs.count) songs and \(allPlaylists.count) playlists")
        } catch {
            print("❌ Failed to cache data: \(error)")
        }
    }
    
    // Helper function to apply playlist filtering
    private func applyPlaylistFiltering() {
        print("🔍 Debug: applyPlaylistFiltering called")
        print("🔍 Debug: allPlaylists.count = \(self.allPlaylists.count)")
        print("🔍 Debug: selectedPlaylistIds.count = \(self.selectedPlaylistIds.count)")
        print("🔍 Debug: selectedPlaylistIds = \(Array(self.selectedPlaylistIds))")
        
        if selectedPlaylistIds.isEmpty {
            // Show all playlists if none selected
            self.playlists = self.allPlaylists
            print("📚 Showing all playlists: \(self.playlists.count)")
        } else {
            // Show only selected playlists
            let filteredPlaylists = self.allPlaylists.filter { playlist in
                let isSelected = selectedPlaylistIds.contains(playlist.id)
                print("🔍 Debug: Playlist '\(playlist.name)' (ID: \(playlist.id)) - Selected: \(isSelected)")
                return isSelected
            }
            self.playlists = filteredPlaylists
            print("📚 Showing selected playlists: \(self.playlists.count) out of \(self.allPlaylists.count) total")
        }
        
        // Additional debug info
        print("📚 Final playlists array: \(self.playlists.map { $0.name })")
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func requestPermissionAndLoadMedia() {
        isLoading = true
        
        Task {
            // Check MediaPlayer authorization
            let mediaPlayerStatus = await MPMediaLibrary.requestAuthorization()
            
            print("🔍 Debug: MediaPlayer authorization status: \(mediaPlayerStatus.rawValue)")
            
            // Test if we can access the media library
            let testQuery = MPMediaQuery.songs()
            let testSongs = testQuery.items ?? []
            print("🔍 Debug: Can access songs: \(testSongs.count) songs found")
            
            let testPlaylists = MPMediaQuery.playlists()
            let testCollections = testPlaylists.collections ?? []
            print("🔍 Debug: Can access playlists: \(testCollections.count) playlist collections found")
            
            // Additional test: try to get a specific playlist
            if let firstCollection = testCollections.first {
                print("🔍 Debug: First playlist name: \(firstCollection.value(forProperty: MPMediaPlaylistPropertyName) ?? "Unknown")")
                print("🔍 Debug: First playlist has \(firstCollection.items.count) songs")
            }
            
            await MainActor.run {
                hasPermission = mediaPlayerStatus == .authorized
                
                if hasPermission {
                    print("✅ Music authorization granted")
                    // Phase 2: Smart loading - check cache first, then load if needed
                    if songsLoaded && playlistsLoaded {
                        // Data already loaded from cache
                        isLoading = false
                        print("📚 Using cached data - no loading needed!")
                    } else {
                        // Load fresh data
                        loadAllMedia()
                    }
                } else {
                    print("❌ Music authorization denied")
                    isLoading = false
                }
            }
        }
    }
    
    // Phase 2: Lazy loading functions
    func loadSongsIfNeeded() {
        if !songsLoaded && !isLoadingSongs {
            Task {
                await loadSongs()
            }
        }
    }
    
    func loadPlaylistsIfNeeded() {
        print("🔍 loadPlaylistsIfNeeded called")
        print("🔍 playlistsLoaded: \(playlistsLoaded)")
        print("🔍 isLoadingPlaylists: \(isLoadingPlaylists)")
        print("🔍 allPlaylists.count: \(allPlaylists.count)")
        
        // Force reload if playlists are marked as loaded but actually empty
        if (playlistsLoaded && allPlaylists.isEmpty) || (!playlistsLoaded && !isLoadingPlaylists) {
            print("🔄 Loading playlists...")
            Task {
                await loadPlaylists()
            }
        } else {
            print("⏭️ Skipping playlist load - already loaded or loading")
        }
    }
    

    
    private func loadAllMedia() {
        Task {
            print("📚 Starting Phase 2 smart loading...")
            
            // Phase 2: Load songs and playlists in parallel on background threads
            async let songsTask = loadSongs()
            async let playlistsTask = loadPlaylists()
            
            // Wait for both to complete
            let (songsCount, playlistsCount) = await (songsTask, playlistsTask)
            
            await MainActor.run {
                self.isLoading = false
                print("📚 Phase 2 complete - Songs: \(songsCount), Playlists: \(playlistsCount)")
            }
        }
    }
    
    private func loadSongs() async -> Int {
        await MainActor.run {
            self.isLoadingSongs = true
        }
        
        return await Task.detached(priority: .userInitiated) {
            let query = MPMediaQuery.songs()
            query.addFilterPredicate(MPMediaPropertyPredicate(value: false, forProperty: MPMediaItemPropertyIsCloudItem))
            
            if let items = query.items {
                let mediaSongs = items.map { item in
                    MediaSong(
                        id: item.playbackStoreID,
                        title: item.title ?? "Unknown",
                        artist: item.artist ?? "Unknown",
                        album: item.albumTitle,
                        duration: item.playbackDuration,
                        appleMusicId: item.playbackStoreID,
                        artworkData: item.artwork?.image(at: CGSize(width: 50, height: 50))?.jpegData(compressionQuality: 0.6)
                    )
                }
                
                let sortedSongs = mediaSongs.sorted { $0.title.lowercased() < $1.title.lowercased() }
                
                await MainActor.run {
                    self.allSongs = sortedSongs
                    self.songs = sortedSongs
                    self.filteredSongs = sortedSongs
                    self.songsLoaded = true
                    self.isLoadingSongs = false
                    
                    // Phase 2: Save to cache
                    self.saveCachedData()
                }
                
                return sortedSongs.count
            }
            
            await MainActor.run {
                self.isLoadingSongs = false
            }
            
            return 0
        }.value
    }
    
    private func loadPlaylists() async -> Int {
        await MainActor.run {
            self.isLoadingPlaylists = true
        }
        
        return await Task.detached(priority: .userInitiated) {
            print("📚 === STARTING PLAYLIST LOADING ===")
            print("📚 Loading playlists in background...")
            
            // Try multiple approaches to get playlists
            var allPlaylists: [MediaPlaylist] = []
            
            // Approach 1: Use MPMediaQuery.playlists()
            let query = MPMediaQuery.playlists()
            
            print("🔍 Debug: MPMediaQuery.playlists() created")
            print("🔍 Debug: query object: \(query)")
            
            if let collections = query.collections, !collections.isEmpty {
                print("📚 Found \(collections.count) playlist collections")
                
                // Debug: Print all collection properties
                for (index, collection) in collections.enumerated() {
                    print("🔍 Collection \(index):")
                    print("  - MPMediaPlaylistPropertyName: \(collection.value(forProperty: MPMediaPlaylistPropertyName) ?? "nil")")
                    print("  - MPMediaPlaylistPropertyPersistentID: \(collection.value(forProperty: MPMediaPlaylistPropertyPersistentID) ?? "nil")")
                    print("  - Items count: \(collection.items.count)")
                }
                
                let mediaPlaylists = collections.compactMap { collection -> MediaPlaylist? in
                    guard let playlist = collection.representativeItem else {
                        print("❌ No representative item for playlist collection")
                        return nil
                    }
                    
                    // Debug: Print available properties
                    print("🔍 Collection properties: \(collection.value(forProperty: MPMediaPlaylistPropertyName) ?? "nil")")
                    print("🔍 Representative item properties: \(playlist.value(forProperty: MPMediaPlaylistPropertyName) ?? "nil")")
                    
                    // Try different ways to get playlist name
                    var playlistName: String?
                    
                    // Method 1: Try the collection name directly
                    if let name = collection.value(forProperty: MPMediaPlaylistPropertyName) as? String {
                        playlistName = name
                        print("✅ Found playlist name via collection property: \(name)")
                    }
                    // Method 2: Try the representative item
                    else if let name = playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String {
                        playlistName = name
                        print("✅ Found playlist name via representative item: \(name)")
                    }
                    // Method 3: Try alternative property names
                    else if let name = playlist.value(forProperty: "name") as? String {
                        playlistName = name
                        print("✅ Found playlist name via 'name' property: \(name)")
                    }
                    // Method 4: Try using the collection description
                    else if let name = collection.value(forProperty: "name") as? String {
                        playlistName = name
                        print("✅ Found playlist name via collection 'name': \(name)")
                    }
                    // Method 5: Try using the collection title
                    else if let name = collection.value(forProperty: "title") as? String {
                        playlistName = name
                        print("✅ Found playlist name via collection 'title': \(name)")
                    }
                    // Method 6: Try using persistentID as fallback
                    else if let persistentID = collection.value(forProperty: MPMediaPlaylistPropertyPersistentID) as? NSNumber {
                        playlistName = "Playlist \(persistentID)"
                        print("⚠️ Using persistentID as playlist name: \(playlistName!)")
                    }
                    // Method 7: Fallback to index
                    else {
                        playlistName = "Playlist \(collections.firstIndex(of: collection) ?? 0)"
                        print("⚠️ Using fallback playlist name: \(playlistName!)")
                    }
                    
                    guard let finalPlaylistName = playlistName else {
                        print("❌ Could not determine playlist name")
                        return nil
                    }
                    
                    let songs = collection.items.map { item in
                        MediaSong(
                            id: item.playbackStoreID,
                            title: item.title ?? "Unknown",
                            artist: item.artist ?? "Unknown",
                            album: item.albumTitle,
                            duration: item.playbackDuration,
                            appleMusicId: item.playbackStoreID,
                            artworkData: item.artwork?.image(at: CGSize(width: 50, height: 50))?.jpegData(compressionQuality: 0.6)
                        )
                    }
                    
                    print("📚 Playlist '\(finalPlaylistName)' has \(songs.count) songs")
                    
                    // Try to get the actual playlist name from the first song (optimized)
                    var actualPlaylistName = finalPlaylistName
                    if let firstSong = collection.items.first,
                       let songPlaylistName = firstSong.value(forProperty: "playlistName") as? String {
                        actualPlaylistName = songPlaylistName
                        print("✅ Found actual playlist name from song: \(actualPlaylistName)")
                    }
                    
                    return MediaPlaylist(
                        id: actualPlaylistName,
                        name: actualPlaylistName,
                        songCount: songs.count,
                        songs: songs,
                        artworkData: songs.first?.artworkData
                    )
                }
                
                print("📚 Successfully created \(mediaPlaylists.count) media playlists")
                
                let sortedPlaylists = mediaPlaylists.sorted { $0.name.lowercased() < $1.name.lowercased() }
                
                await MainActor.run {
                    print("📚 Setting allPlaylists to \(sortedPlaylists.count) playlists")
                    self.allPlaylists = sortedPlaylists
                    
                    // Apply playlist filtering using the helper function
                    self.applyPlaylistFiltering()
                    
                    self.playlistsLoaded = true
                    self.isLoadingPlaylists = false
                    
                    // Phase 2: Save to cache
                    self.saveCachedData()
                    
                    print("📚 Updated playlists array with \(self.playlists.count) playlists (selected from \(sortedPlaylists.count) total)")
                }
                
                return sortedPlaylists.count
            } else {
                print("❌ No playlist collections found or collections is empty")
                print("🔍 Debug: query.collections is \(query.collections == nil ? "nil" : "empty")")
                
                await MainActor.run {
                    print("📚 Setting empty playlists arrays")
                    self.allPlaylists = []
                    self.playlists = []
                    self.isLoadingPlaylists = false
                    self.playlistsLoaded = true
                }
                
                return 0
            }
        }.value
    }
    
    // Fallback method for playlist loading
    private func loadPlaylistsFallback() async -> Int {
        print("🔄 Attempting fallback playlist loading...")
        
        // Simple fallback: return 0 and let the main method handle it
        // This avoids MusicKit API issues
        print("⚠️ Fallback method disabled - using main playlist loading only")
        
        await MainActor.run {
            self.allPlaylists = []
            self.playlists = []
            self.playlistsLoaded = true
        }
        
        return 0
    }
    
    func togglePlaylistSelection(_ playlistId: String) {
        if selectedPlaylistIds.contains(playlistId) {
            selectedPlaylistIds.remove(playlistId)
        } else {
            selectedPlaylistIds.insert(playlistId)
        }
        saveSelectedPlaylists()
        
        // Update displayed playlists using the helper function
        applyPlaylistFiltering()
    }
    
    func isPlaylistSelected(_ playlistId: String) -> Bool {
        return selectedPlaylistIds.contains(playlistId)
    }
    
    func getAvailablePlaylists() -> [MediaPlaylist] {
        return allPlaylists
    }
    
    func getSelectedPlaylists() -> [MediaPlaylist] {
        return allPlaylists.filter { selectedPlaylistIds.contains($0.id) }
    }
    

    
    func filterSongs(_ searchText: String) {
        if searchText.isEmpty {
            filteredSongs = songs
        } else {
            let lowercasedSearch = searchText.lowercased()
            filteredSongs = songs.filter { song in
                song.title.lowercased().contains(lowercasedSearch) ||
                song.artist.lowercased().contains(lowercasedSearch) ||
                (song.album?.lowercased().contains(lowercasedSearch) ?? false)
            }
        }
    }
    
    // Debug function to check playlist state
    func debugPlaylistState() {
        print("🔍 === PLAYLIST DEBUG INFO ===")
        print("🔍 allPlaylists.count: \(allPlaylists.count)")
        print("🔍 playlists.count: \(playlists.count)")
        print("🔍 selectedPlaylistIds.count: \(selectedPlaylistIds.count)")
        print("🔍 selectedPlaylistIds: \(Array(selectedPlaylistIds))")
        print("🔍 playlistsLoaded: \(playlistsLoaded)")
        print("🔍 isLoadingPlaylists: \(isLoadingPlaylists)")
        print("🔍 hasPermission: \(hasPermission)")
        
        print("🔍 All playlists:")
        for (index, playlist) in allPlaylists.enumerated() {
            let isSelected = selectedPlaylistIds.contains(playlist.id)
            print("  \(index + 1). '\(playlist.name)' (ID: \(playlist.id)) - Selected: \(isSelected)")
        }
        
        print("🔍 Currently displayed playlists:")
        for (index, playlist) in playlists.enumerated() {
            print("  \(index + 1). '\(playlist.name)' (ID: \(playlist.id))")
        }
        print("🔍 === END DEBUG INFO ===")
    }
    
    // Function to reset playlist selection and show all playlists
    func resetPlaylistSelection() {
        print("🔄 Resetting playlist selection...")
        selectedPlaylistIds.removeAll()
        saveSelectedPlaylists()
        applyPlaylistFiltering()
        print("✅ Playlist selection reset - showing all playlists")
    }
    
    // Test function to check MediaPlayer access
    func testMediaPlayerAccess() {
        print("🧪 === TESTING MEDIA PLAYER ACCESS ===")
        
        // Test 1: Check authorization status
        let authStatus = MPMediaLibrary.authorizationStatus()
        print("🧪 Authorization status: \(authStatus.rawValue)")
        
        // Test 2: Try to get songs
        let songsQuery = MPMediaQuery.songs()
        let songs = songsQuery.items ?? []
        print("🧪 Songs found: \(songs.count)")
        
        // Test 3: Try to get playlists
        let playlistsQuery = MPMediaQuery.playlists()
        let collections = playlistsQuery.collections ?? []
        print("🧪 Playlist collections found: \(collections.count)")
        
        // Test 4: Try to get albums
        let albumsQuery = MPMediaQuery.albums()
        let albums = albumsQuery.collections ?? []
        print("🧪 Album collections found: \(albums.count)")
        
        // Test 5: Check if we can access the first playlist
        if let firstCollection = collections.first {
            print("🧪 First playlist name: \(firstCollection.value(forProperty: MPMediaPlaylistPropertyName) ?? "Unknown")")
            print("🧪 First playlist songs: \(firstCollection.items.count)")
        } else {
            print("🧪 No playlists found!")
        }
        
        print("🧪 === END MEDIA PLAYER TEST ===")
        
        // Force reload playlists after test
        print("🔄 Force reloading playlists after test...")
        Task {
            await loadPlaylists()
        }
    }
    
    // Force reload playlists function
    func forceReloadPlaylists() {
        print("🔄 Force reloading playlists...")
        playlistsLoaded = false
        allPlaylists = []
        playlists = []
        
        Task {
            await loadPlaylists()
        }
    }
}

// MARK: - Media Data Models

struct MediaSong: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let appleMusicId: String
    let artworkData: Data?
}

struct MediaPlaylist: Identifiable, Codable {
    let id: String
    let name: String
    let songCount: Int
    let songs: [MediaSong]
    let artworkData: Data?
}

 

// MARK: - Playlist Selector View

struct PlaylistSelectorView: View {
    @ObservedObject var mediaManager: CustomMediaManager
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    var filteredPlaylists: [MediaPlaylist] {
        if searchText.isEmpty {
            return mediaManager.getAvailablePlaylists()
        } else {
            return mediaManager.getAvailablePlaylists().filter { playlist in
                playlist.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search playlists...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Header info
                VStack(spacing: 8) {
                    Text("Select Playlists")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Choose which playlists to show in your library. This will make browsing faster and more organized.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Playlist list
                if filteredPlaylists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No playlists found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Make sure you have playlists in your library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredPlaylists) { playlist in
                                playlistSelectorRow(playlist)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Playlist Selector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func playlistSelectorRow(_ playlist: MediaPlaylist) -> some View {
        HStack(spacing: 12) {
            // Playlist artwork
            if let artworkData = playlist.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                Color.blue.opacity(0.2)
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .foregroundColor(.blue)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(playlist.songCount) songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Selection indicator
            Image(systemName: mediaManager.isPlaylistSelected(playlist.id) ? "checkmark.circle.fill" : "circle")
                .foregroundColor(mediaManager.isPlaylistSelected(playlist.id) ? .blue : .gray)
                .font(.title2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(mediaManager.isPlaylistSelected(playlist.id) ? Color.blue.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            mediaManager.togglePlaylistSelection(playlist.id)
        }
    }
}
