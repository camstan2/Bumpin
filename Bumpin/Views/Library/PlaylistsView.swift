import SwiftUI

struct PlaylistsView: View {
    @ObservedObject var libraryService: AppleMusicLibraryService
    @State private var selectedPlaylist: LibraryPlaylist?
    @State private var playlistSongs: [LibraryItem] = []
    @State private var isLoadingPlaylistSongs = false
    @State private var selectedSortOption: PlaylistSortOption = .recentlyPlayed
    @State private var showingSortOptions = false
    @State private var searchText = ""
    @State private var isToggleMode = false
    @State private var showingManagementSheet = false
    
    enum PlaylistSortOption: String, CaseIterable {
        case recentlyPlayed = "Recently Played"
        case recentlyAdded = "Recently Added"
        case alphabetical = "A to Z"
        case songCount = "Song Count"
        
        var icon: String {
            switch self {
            case .recentlyPlayed: return "play.circle"
            case .recentlyAdded: return "clock"
            case .alphabetical: return "textformat.abc"
            case .songCount: return "music.note"
            }
        }
        
        func sort(_ playlists: [LibraryPlaylist]) -> [LibraryPlaylist] {
            switch self {
            case .recentlyPlayed:
                // Sort by last played date (most recent first), then by recently added as fallback
                let sorted = playlists.sorted { playlist1, playlist2 in
                    let date1 = playlist1.lastPlayedDate ?? Date.distantPast
                    let date2 = playlist2.lastPlayedDate ?? Date.distantPast
                    if date1 == date2 {
                        // Fallback to recently added if no play history
                        let addedDate1 = playlist1.dateAdded ?? Date.distantPast
                        let addedDate2 = playlist2.dateAdded ?? Date.distantPast
                        return addedDate1 > addedDate2
                    }
                    return date1 > date2
                }
                
                // Debug logging
                print("🔍 Recently Played Sort Debug:")
                for (index, playlist) in sorted.prefix(5).enumerated() {
                    let playedDate = playlist.lastPlayedDate?.description ?? "Never played"
                    print("  \(index + 1). '\(playlist.name)' - Last played: \(playedDate)")
                }
                
                return sorted
            case .recentlyAdded:
                return playlists.sorted { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
            case .alphabetical:
                return playlists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .songCount:
                return playlists.sorted { $0.songCount > $1.songCount }
            }
        }
    }
    
    private var filteredPlaylists: [LibraryPlaylist] {
        // Use all playlists in toggle mode, enabled playlists in normal mode
        let sourcePlaylist = isToggleMode ? libraryService.allPlaylists : libraryService.enabledPlaylists
        
        if searchText.isEmpty {
            return sourcePlaylist
        }
        
        let lowercaseQuery = searchText.lowercased()
        return sourcePlaylist.filter { playlist in
            playlist.name.lowercased().contains(lowercaseQuery) ||
            (playlist.curatorName?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    private var sortedPlaylists: [LibraryPlaylist] {
        selectedSortOption.sort(filteredPlaylists)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchSection
                
                // Header with count and sort info
                headerSection
                
                // Content
                if libraryService.isLoading {
                    LibraryLoadingView(message: "Loading playlists...")
                        .frame(maxHeight: .infinity)
                } else if sortedPlaylists.isEmpty {
                    emptyStateView
                } else {
                    playlistsGrid
                }
            }
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Enhanced manage button
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isToggleMode.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isToggleMode ? "checkmark.square.fill" : "square.grid.3x1.below.line.grid.1x2")
                                if isToggleMode {
                                    // Count removed
                                }
                            }
                            .foregroundColor(isToggleMode ? .purple : .gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                isToggleMode ? 
                                Color.purple.opacity(0.1) : 
                                Color.clear
                            )
                            .cornerRadius(8)
                        }
                        
                        // Management sheet button (when in toggle mode)
                        if isToggleMode {
                            Button(action: { showingManagementSheet = true }) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        
                        // Sort button (only when not in toggle mode)
                        if !isToggleMode {
                            Button(action: { showingSortOptions = true }) {
                                Image(systemName: selectedSortOption.icon)
                            }
                        }
                    }
                }
            }
            .confirmationDialog("Sort by", isPresented: $showingSortOptions, titleVisibility: .visible) {
                ForEach(PlaylistSortOption.allCases, id: \.self) { option in
                    Button(action: { selectedSortOption = option }) {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            }
            .sheet(isPresented: $showingManagementSheet) {
                PlaylistManagementSheet(libraryService: libraryService)
            }
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistDetailView(
                playlist: playlist,
                libraryService: libraryService
            )
        }
        .onAppear {
            if libraryService.userPlaylists.isEmpty {
                Task {
                    await libraryService.loadUserPlaylists()
                }
            }
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search playlists", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Main header row
            HStack {
                if isToggleMode {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Playlists enabled/disabled")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Text("Tap playlists to enable/disable")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Count removed
                }
                
                Spacer()
                
                if !isToggleMode {
                    Text("Sorted by \(selectedSortOption.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Bulk action buttons (only in toggle mode)
            if isToggleMode {
                HStack(spacing: 12) {
                    // Enable All button
                    Button(action: {
                        HapticManager.impact(style: .light)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            for playlist in sortedPlaylists {
                                if !libraryService.isPlaylistSelected(playlist.id) {
                                    libraryService.togglePlaylistSelection(playlist.id)
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Enable All")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    // Disable All button
                    Button(action: {
                        HapticManager.impact(style: .light)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            for playlist in sortedPlaylists {
                                if libraryService.isPlaylistSelected(playlist.id) {
                                    libraryService.togglePlaylistSelection(playlist.id)
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "minus.circle.fill")
                            Text("Disable All")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    Spacer()
                    
                    // Reset to Default button
                    Button(action: {
                        HapticManager.impact(style: .medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            // Enable all playlists (default state)
                            for playlist in sortedPlaylists {
                                if !libraryService.isPlaylistSelected(playlist.id) {
                                    libraryService.togglePlaylistSelection(playlist.id)
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Playlists Grid
    private var playlistsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                ForEach(sortedPlaylists) { playlist in
                    if isToggleMode {
                        ToggleablePlaylistCard(
                            playlist: playlist,
                            isSelected: libraryService.isPlaylistSelected(playlist.id),
                            onTap: {
                                selectedPlaylist = playlist
                                libraryService.markPlaylistAsPlayed(playlist.id)
                            },
                            onToggle: {
                                libraryService.togglePlaylistSelection(playlist.id)
                            }
                        )
                    } else {
                        PlaylistCard(playlist: playlist) {
                            selectedPlaylist = playlist
                            libraryService.markPlaylistAsPlayed(playlist.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await libraryService.loadUserPlaylists()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty {
                LibraryEmptyState(
                    title: "No Playlists",
                    subtitle: "Your playlists will appear here when you create them in Apple Music.",
                    icon: "music.note.list"
                )
            } else {
                LibraryEmptyState(
                    title: "No Results",
                    subtitle: "No playlists match '\(searchText)'",
                    icon: "magnifyingglass"
                )
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Playlist Detail View
struct PlaylistDetailView: View {
    let playlist: LibraryPlaylist
    @ObservedObject var libraryService: AppleMusicLibraryService
    @State private var songs: [LibraryItem] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Playlist header
                playlistHeaderSection
                
                // Songs list
                if isLoading {
                    LibraryLoadingView(message: "Loading playlist songs...")
                        .frame(maxHeight: .infinity)
                } else if songs.isEmpty {
                    LibraryEmptyState(
                        title: "No Songs",
                        subtitle: "This playlist doesn't contain any songs.",
                        icon: "music.note"
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    songsListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { /* Add shuffle functionality */ }) {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                        Button(action: { /* Add play functionality */ }) {
                            Label("Play", systemImage: "play.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadPlaylistSongs()
            }
        }
    }
    
    // MARK: - Playlist Header
    private var playlistHeaderSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Playlist artwork
                if let artworkUrl = playlist.artworkURL, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        playlistPlaceholder
                    }
                    .frame(width: 140, height: 140)
                    .cornerRadius(12)
                    .clipped()
                } else {
                    playlistPlaceholder
                        .frame(width: 140, height: 140)
                        .cornerRadius(12)
                }
                
                // Playlist info
                VStack(alignment: .leading, spacing: 8) {
                    Text(playlist.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let curator = playlist.curatorName {
                        Text("by \(curator)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(playlist.displaySubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let description = playlist.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Songs List
    private var songsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    PlaylistSongRow(
                        song: song,
                        trackNumber: index + 1,
                        onTap: { handleSongTap(song) }
                    )
                    
                    if song.id != songs.last?.id {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Views
    private var playlistPlaceholder: some View {
        Rectangle()
            .fill(Color.purple.opacity(0.3))
            .overlay(
                Image(systemName: "music.note.list")
                    .foregroundColor(.purple)
                    .font(.title)
            )
    }
    
    // MARK: - Helper Methods
    private func loadPlaylistSongs() async {
        isLoading = true
        songs = await libraryService.loadPlaylistSongs(for: playlist)
        isLoading = false
    }
    
    private func handleSongTap(_ song: LibraryItem) {
        // Navigate to song profile
        let musicResult = song.toMusicSearchResult()
        NotificationCenter.default.post(
            name: NSNotification.Name("LibraryItemTapped"),
            object: musicResult
        )
    }
}

// MARK: - Playlist Song Row
struct PlaylistSongRow: View {
    let song: LibraryItem
    let trackNumber: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Track number
                Text("\(trackNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)
                
                // Song artwork
                if let artworkUrl = song.artworkURL, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        songPlaceholder
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
                    .clipped()
                } else {
                    songPlaceholder
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(song.artistName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // More options
                Button(action: { /* Add more options */ }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var songPlaceholder: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.blue)
                    .font(.caption)
            )
    }
}

// MARK: - Playlist Management Sheet
struct PlaylistManagementSheet: View {
    @ObservedObject var libraryService: AppleMusicLibraryService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingPerformanceInfo = false
    
    private var filteredPlaylists: [LibraryPlaylist] {
        if searchText.isEmpty {
            return libraryService.allPlaylists
        }
        
        let lowercaseQuery = searchText.lowercased()
        return libraryService.allPlaylists.filter { playlist in
            playlist.name.lowercased().contains(lowercaseQuery) ||
            (playlist.curatorName?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with stats
                headerSection
                
                // Search bar
                searchSection
                
                // Playlists list
                if filteredPlaylists.isEmpty {
                    emptyStateView
                } else {
                    playlistsList
                }
            }
            .navigationTitle("Manage Playlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Stats row
            HStack(spacing: 24) {
                LibraryStatCard(
                    title: "Enabled",
                    value: "—",
                    color: .purple,
                    icon: "checkmark.circle.fill"
                )
                
                LibraryStatCard(
                    title: "Disabled", 
                    value: "—",
                    color: .red,
                    icon: "minus.circle.fill"
                )
                
                LibraryStatCard(
                    title: "Total",
                    value: "—",
                    color: .gray,
                    icon: "music.note.list"
                )
            }
            
            // Quick actions
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Enable All",
                    icon: "checkmark.circle.fill",
                    color: .purple
                ) {
                    enableAllPlaylists()
                }
                
                QuickActionButton(
                    title: "Disable All",
                    icon: "minus.circle.fill",
                    color: .red
                ) {
                    disableAllPlaylists()
                }
                
                QuickActionButton(
                    title: "Smart Select",
                    icon: "brain.head.profile",
                    color: .blue
                ) {
                    smartSelectPlaylists()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search playlists...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Playlists List
    private var playlistsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredPlaylists) { playlist in
                    PlaylistManagementRow(
                        playlist: playlist,
                        isEnabled: libraryService.isPlaylistSelected(playlist.id),
                        onToggle: {
                            HapticManager.impact(style: .medium)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                libraryService.togglePlaylistSelection(playlist.id)
                            }
                        }
                    )
                    
                    if playlist.id != filteredPlaylists.last?.id {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No playlists found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func enableAllPlaylists() {
        HapticManager.impact(style: .light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            for playlist in libraryService.allPlaylists {
                if !libraryService.isPlaylistSelected(playlist.id) {
                    libraryService.togglePlaylistSelection(playlist.id)
                }
            }
        }
    }
    
    private func disableAllPlaylists() {
        HapticManager.impact(style: .light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            for playlist in libraryService.allPlaylists {
                if libraryService.isPlaylistSelected(playlist.id) {
                    libraryService.togglePlaylistSelection(playlist.id)
                }
            }
        }
    }
    
    private func smartSelectPlaylists() {
        HapticManager.impact(style: .medium)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Smart selection: Enable playlists with reasonable song counts (5-500 songs)
            // and recently created playlists
            for playlist in libraryService.allPlaylists {
                let shouldEnable = playlist.songCount >= 5 && playlist.songCount <= 500
                let isCurrentlyEnabled = libraryService.isPlaylistSelected(playlist.id)
                
                if shouldEnable && !isCurrentlyEnabled {
                    libraryService.togglePlaylistSelection(playlist.id)
                } else if !shouldEnable && isCurrentlyEnabled {
                    libraryService.togglePlaylistSelection(playlist.id)
                }
            }
        }
    }
}

// MARK: - Supporting Components
struct LibraryStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct PlaylistManagementRow: View {
    let playlist: LibraryPlaylist
    let isEnabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Playlist artwork
            if let artworkUrl = playlist.artworkURL, let url = URL(string: artworkUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    playlistPlaceholder
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                .clipped()
                .opacity(isEnabled ? 1.0 : 0.5)
                .saturation(isEnabled ? 1.0 : 0.3)
            } else {
                playlistPlaceholder
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    .opacity(isEnabled ? 1.0 : 0.5)
                    .saturation(isEnabled ? 1.0 : 0.3)
            }
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(playlist.displaySubtitle)
                        .font(.caption)
                        .foregroundColor(isEnabled ? .secondary : Color.secondary.opacity(0.6))
                    
                    if !isEnabled {
                        Text("• DISABLED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Toggle button
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? Color.purple : Color.red)
                        .frame(width: 32, height: 32)
                        .shadow(color: isEnabled ? .purple.opacity(0.3) : .red.opacity(0.3), radius: 3, x: 0, y: 1)
                    
                    Image(systemName: isEnabled ? "checkmark" : "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .opacity(isEnabled ? 1.0 : 0.7)
    }
    
    private var playlistPlaceholder: some View {
        Rectangle()
            .fill(Color.purple.opacity(0.3))
            .overlay(
                Image(systemName: "music.note.list")
                    .foregroundColor(.purple)
                    .font(.title3)
            )
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(value)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

#Preview {
    PlaylistsView(libraryService: AppleMusicLibraryService.shared)
}
