import SwiftUI

struct AlbumsLibraryView: View {
    @ObservedObject var libraryService: AppleMusicLibraryService
    @State private var selectedSortOption: AlbumSortOption = .recentlyAdded
    @State private var showingSortOptions = false
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    
    enum AlbumSortOption: String, CaseIterable {
        case recentlyAdded = "Recently Added"
        case alphabetical = "A to Z"
        case artist = "Artist"
        
        var icon: String {
            switch self {
            case .recentlyAdded: return "clock"
            case .alphabetical: return "textformat.abc"
            case .artist: return "person.fill"
            }
        }
        
        func sort(_ albums: [LibraryItem]) -> [LibraryItem] {
            switch self {
            case .recentlyAdded:
                return albums.sorted { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
            case .alphabetical:
                return albums.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .artist:
                return albums.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
            }
        }
    }
    
    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
        
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }
    
    private var filteredAlbums: [LibraryItem] {
        if searchText.isEmpty {
            return libraryService.libraryAlbums
        }
        
        let lowercaseQuery = searchText.lowercased()
        return libraryService.libraryAlbums.filter { album in
            album.title.lowercased().contains(lowercaseQuery) ||
            album.artistName.lowercased().contains(lowercaseQuery)
        }
    }
    
    private var sortedAlbums: [LibraryItem] {
        selectedSortOption.sort(filteredAlbums)
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
                    LibraryLoadingView(message: "Loading albums...")
                        .frame(maxHeight: .infinity)
                } else if sortedAlbums.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // View mode toggle
                        Button(action: { 
                            viewMode = viewMode == .grid ? .list : .grid
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
                ForEach(AlbumSortOption.allCases, id: \.self) { option in
                    Button(action: { selectedSortOption = option }) {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            }
        }
        .onAppear {
            if libraryService.libraryAlbums.isEmpty {
                Task {
                    await libraryService.loadLibraryAlbums()
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
                
                TextField("Search albums", text: $searchText)
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
            if viewMode == .grid {
                albumsGridView
            } else {
                albumsListView
            }
        }
    }
    
    // MARK: - Albums Grid View
    private var albumsGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                ForEach(sortedAlbums) { album in
                    AlbumGridCard(album: album) {
                        handleAlbumTap(album)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await libraryService.loadLibraryAlbums()
        }
    }
    
    // MARK: - Albums List View
    private var albumsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedAlbums) { album in
                    LibraryItemRow(item: album) {
                        handleAlbumTap(album)
                    }
                    .padding(.horizontal, 20)
                    
                    if album.id != sortedAlbums.last?.id {
                        Divider()
                            .padding(.leading, 82)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await libraryService.loadLibraryAlbums()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty {
                LibraryEmptyState(
                    title: "No Albums",
                    subtitle: "Albums will appear here when you add them to your Apple Music library.",
                    icon: "opticaldisc"
                )
            } else {
                LibraryEmptyState(
                    title: "No Results",
                    subtitle: "No albums match '\(searchText)'",
                    icon: "magnifyingglass"
                )
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func handleAlbumTap(_ album: LibraryItem) {
        let musicResult = album.toMusicSearchResult()
        NotificationCenter.default.post(
            name: NSNotification.Name("LibraryItemTapped"),
            object: musicResult
        )
    }
}

// MARK: - Album Grid Card
struct AlbumGridCard: View {
    let album: LibraryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Album artwork
                if let artworkUrl = album.artworkURL, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        albumPlaceholder
                    }
                    .frame(width: 140, height: 140)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    albumPlaceholder
                        .frame(width: 140, height: 140)
                        .cornerRadius(8)
                }
                
                // Album title
                Text(album.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 140, alignment: .leading)
                
                // Artist name
                Text(album.artistName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var albumPlaceholder: some View {
        Rectangle()
            .fill(Color.orange.opacity(0.3))
            .overlay(
                Image(systemName: "opticaldisc")
                    .foregroundColor(.orange)
                    .font(.title)
            )
    }
}

#Preview {
    AlbumsLibraryView(libraryService: AppleMusicLibraryService.shared)
}
