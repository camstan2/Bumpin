import SwiftUI

struct SongsLibraryView: View {
    @ObservedObject var libraryService: AppleMusicLibraryService
    @State private var selectedSortOption: SongSortOption = .recentlyAdded
    @State private var showingSortOptions = false
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .list
    
    enum SongSortOption: String, CaseIterable {
        case recentlyAdded = "Recently Added"
        case alphabetical = "A to Z"
        case artist = "Artist"
        case album = "Album"
        
        var icon: String {
            switch self {
            case .recentlyAdded: return "clock"
            case .alphabetical: return "textformat.abc"
            case .artist: return "person.fill"
            case .album: return "opticaldisc"
            }
        }
        
        func sort(_ songs: [LibraryItem]) -> [LibraryItem] {
            switch self {
            case .recentlyAdded:
                return songs.sorted { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
            case .alphabetical:
                return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .artist:
                return songs.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
            case .album:
                return songs.sorted { ($0.albumName ?? "").localizedCaseInsensitiveCompare($1.albumName ?? "") == .orderedAscending }
            }
        }
    }
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case grid = "Grid"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    private var filteredSongs: [LibraryItem] {
        if searchText.isEmpty {
            return libraryService.librarySongs
        }
        
        let lowercaseQuery = searchText.lowercased()
        return libraryService.librarySongs.filter { song in
            song.title.lowercased().contains(lowercaseQuery) ||
            song.artistName.lowercased().contains(lowercaseQuery) ||
            (song.albumName?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    private var sortedSongs: [LibraryItem] {
        selectedSortOption.sort(filteredSongs)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchSection
                
                // Header with controls
                headerSection
                
                // Content
                if libraryService.isLoading {
                    LibraryLoadingView(message: "Loading songs...")
                        .frame(maxHeight: .infinity)
                } else if sortedSongs.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Songs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // View mode toggle
                        Button(action: { 
                            viewMode = viewMode == .list ? .grid : .list
                        }) {
                            Image(systemName: viewMode.icon)
                        }
                        
                        // Sort options
                        Button(action: { showingSortOptions = true }) {
                            Image(systemName: selectedSortOption.icon)
                        }
                    }
                }
            }
            .confirmationDialog("Sort by", isPresented: $showingSortOptions, titleVisibility: .visible) {
                ForEach(SongSortOption.allCases, id: \.self) { option in
                    Button(action: { selectedSortOption = option }) {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            }
        }
        .onAppear {
            if libraryService.librarySongs.isEmpty {
                Task {
                    await libraryService.loadLibrarySongs()
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
                
                TextField("Search songs", text: $searchText)
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
        HStack {
            // Count removed
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("Sorted by \(selectedSortOption.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(viewMode.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Content View
    private var contentView: some View {
        Group {
            if viewMode == .list {
                songsListView
            } else {
                songsGridView
            }
        }
    }
    
    // MARK: - Songs List View
    private var songsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedSongs) { song in
                    LibraryItemRow(item: song) {
                        handleSongTap(song)
                    }
                    .padding(.horizontal, 20)
                    
                    if song.id != sortedSongs.last?.id {
                        Divider()
                            .padding(.leading, 82)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await libraryService.loadLibrarySongs()
        }
    }
    
    // MARK: - Songs Grid View
    private var songsGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(sortedSongs) { song in
                    SongGridCard(song: song) {
                        handleSongTap(song)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await libraryService.loadLibrarySongs()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty {
                LibraryEmptyState(
                    title: "No Songs",
                    subtitle: "Your songs will appear here when you add them to your Apple Music library.",
                    icon: "music.note"
                )
            } else {
                LibraryEmptyState(
                    title: "No Results",
                    subtitle: "No songs match '\(searchText)'",
                    icon: "magnifyingglass"
                )
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func handleSongTap(_ song: LibraryItem) {
        let musicResult = song.toMusicSearchResult()
        NotificationCenter.default.post(
            name: NSNotification.Name("LibraryItemTapped"),
            object: musicResult
        )
    }
}

// MARK: - Song Grid Card
struct SongGridCard: View {
    let song: LibraryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Song artwork
                if let artworkUrl = song.artworkURL, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        songPlaceholder
                    }
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    songPlaceholder
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                }
                
                // Song title
                Text(song.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 100, alignment: .leading)
                
                // Artist name
                Text(song.artistName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var songPlaceholder: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.blue)
                    .font(.title2)
            )
    }
}

#Preview {
    SongsLibraryView(libraryService: AppleMusicLibraryService.shared)
}
