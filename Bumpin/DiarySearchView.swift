import SwiftUI
import MusicKit
import MediaPlayer

// New Diary Search that mirrors main Search format but only All/Songs/Artists/Albums and redirects selections to LogMusicFormView
struct DiarySearchView: View {
    // MARK: - Top Level Tabs (Search vs Library)
    enum PrimaryTab: String, CaseIterable, Identifiable {
        case search = "Search"
        case library = "Library"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .search: return "magnifyingglass"
            case .library: return "music.note.list"
            }
        }
    }
    
    // MARK: - Filters
    enum SearchFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case songs = "Songs"
        case artists = "Artists"
        case albums = "Albums"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .songs: return "music.note"
            case .artists: return "person.fill"
            case .albums: return "opticaldisc"
            }
        }
        var color: Color {
            switch self {
            case .all: return .purple
            case .songs: return .blue
            case .artists: return .green
            case .albums: return .orange
            }
        }
    }
    
    // MARK: - State
    @Environment(\.presentationMode) private var presentationMode
    @State private var primaryTab: PrimaryTab = .search
    @State private var selectedFilter: SearchFilter = .all
    @State private var searchText: String = ""
    @State private var searchResults: [MusicSearchResult] = []
    @State private var isSearching = false
    // TODO: Library categories will be reimplemented
    @State private var categoryItems: [MusicSearchResult] = []
    @State private var recentlyAdded: [MusicSearchResult] = []
    @State private var isLibrarySearching = false
    @State private var libraryResults: [MusicSearchResult] = []
    @State private var selectedResult: MusicSearchResult?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                primaryTabHeader
                searchBar
                if primaryTab == .search {
                    filterChips
                }
                resultsContent
                Spacer()
            }
            .navigationTitle("Search Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .fullScreenCover(item: $selectedResult, onDismiss: { selectedResult = nil }) { result in
            LogMusicFormView(searchResult: result)
        }
        .sheet(isPresented: $showPlaylistSheet) {
            PlaylistSongsView(songs: playlistSongs) { song in
                selectedResult = song
                showPlaylistSheet = false
                
            }
        }
    }
    
    // MARK: - Components
    private var primaryTabHeader: some View {
        HStack(spacing: 60) {
            ForEach(PrimaryTab.allCases) { tab in
                VStack(spacing: 4) {
                    Image(systemName: tab.icon)
                        .font(.title2)
                        .foregroundColor(primaryTab == tab ? .purple : .gray)
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .foregroundColor(primaryTab == tab ? .primary : .gray)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .onTapGesture { withAnimation { primaryTab = tab } }
            }
        }
        .padding(.top, 8)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField(searchPlaceholder, text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: searchText) { _, _ in
                    debounceSearch()
                }
            if (primaryTab == .search ? isSearching : isLibrarySearching) {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 6)
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases) { filter in
                    Button(action: { selectedFilter = filter }) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.caption)
                            Text(filter.rawValue)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? filter.color.opacity(0.2) : Color(.systemGray5))
                        .foregroundColor(selectedFilter == filter ? filter.color : .primary)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private var resultsContent: some View {
        Group {
            if primaryTab == .search {
                searchResultsView
            } else {
                libraryResultsView
            }
        }
    }
    
    private var searchResultsView: some View {
        Group {
            if isSearching {
                ProgressView().padding()
            } else if searchResults.isEmpty {
                emptyStateView(icon: selectedFilter.icon, title: "Search for \(selectedFilter.rawValue.lowercased())")
            } else {
                List(filteredSearchResults) { result in
                    resultRow(result)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var libraryResultsView: some View {
        Group {
            if !libraryResults.isEmpty {
                List(libraryResults) { result in
                    resultRow(result)
                }
                .listStyle(PlainListStyle())
            } else if isLibrarySearching {
                ProgressView().padding()
            } else if searchText.isEmpty {
                libraryHomeView
            } else {
                emptyStateView(icon: "music.note", title: "No results in your library")
            }
        }
    }
    
    // MARK: - Library Home (Recently Added + Categories)
    private var libraryHomeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                recentlyAddedSection
                libraryCategoriesSection
            }
            .padding(.top, 8)
        }
        // TODO: Library loading will be reimplemented
    }
    
    private var libraryCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Library")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
            // TODO: Library categories will be reimplemented
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
    
    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recently Added")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // TODO: Recently added cards will be reimplemented
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    @State private var showPlaylistSheet = false
    @State private var playlistSongs: [MusicSearchResult] = []

    // MARK: - Row
    private func resultRow(_ result: MusicSearchResult) -> some View {
        Button(action: {
            if result.itemType == "playlist" {
                Task {
                    // TODO: Implement playlist loading
                    // playlistSongs = await loadPlaylistSongs(for: result)
                    showPlaylistSheet = true
                }
            } else {
                selectedResult = result
                
            }
        }) {
            HStack(spacing: 12) {
                EnhancedArtworkView(
                    artworkUrl: result.artworkURL,
                    itemType: result.itemType,
                    size: 44
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !result.artistName.isEmpty {
                        Text(result.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(result.itemType.capitalized)
                    .font(.caption2)
                    .padding(4)
                    .background(colorForItemType(result.itemType).opacity(0.2))
                    .foregroundColor(colorForItemType(result.itemType))
                    .cornerRadius(6)
                Image(systemName: "plus.circle").foregroundColor(.purple)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helpers
    private var searchPlaceholder: String {
        "Search \(primaryTab == .search ? "Apple Music" : "your library")..."
    }
    
    private func emptyStateView(icon: String, title: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(.gray)
            Text(title).font(.headline).foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func colorForItemType(_ type: String) -> Color {
        switch type.lowercased() {
        case "song": return .blue
        case "artist": return .green
        case "album": return .orange
        default: return .purple
        }
    }
    
    private var filteredSearchResults: [MusicSearchResult] {
        let results = searchResults
        switch selectedFilter {
        case .all:
            return results
        case .songs:
            return results.filter { $0.itemType == "song" }
        case .artists:
            return results.filter { $0.itemType == "artist" }
        case .albums:
            return results.filter { $0.itemType == "album" }
        }
    }

    // MARK: - Debounce Helper
    @State private var debounceTask: DispatchWorkItem?
    private func debounceSearch() {
        debounceTask?.cancel()
        let task = DispatchWorkItem { performSearch() }
        debounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
    }

    // MARK: - Network Calls
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            libraryResults = []
            return
        }
        if primaryTab == .search {
            Task { await performSearch(query: searchText) }
        } else {
            performLibrarySearch()
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
            return
        }
        
        await MainActor.run {
            self.isSearching = true
        }
        
        // Use UnifiedMusicSearchService for proper deduplication
        let unifiedResults = await UnifiedMusicSearchService.shared.search(query: query, limit: 25)
        
        // Combine all results from the unified service
        let allResults = unifiedResults.songs + unifiedResults.artists + unifiedResults.albums
        
        await MainActor.run {
            self.searchResults = allResults
            self.isSearching = false
        }
    }
    
    private func performLibrarySearch() {
        isLibrarySearching = true
        // TODO: Implement actual library search
        // For now, just simulate search
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLibrarySearching = false
        }
    }
    
    // TODO: Library categories loading will be reimplemented
    
    // TODO: Library category loading will be reimplemented
}

// MARK: - AppleMusicLibraryManager Convenience (Commented out - class doesn't exist)
/* extension AppleMusicLibraryManager {
    /// Simple helper to search user library songs by title/artist. Returns top 30 results as MusicSearchResult.
    @MainActor
    func searchLibrary(query: String) async -> [MusicSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let lower = query.lowercased()
        let mediaQuery = MPMediaQuery.songs()
        let items = mediaQuery.items ?? []
        var results: [MusicSearchResult] = []
        for item in items {
            let title = (item.title ?? "").lowercased()
            let artist = (item.artist ?? "").lowercased()
            if title.contains(lower) || artist.contains(lower) {
                let artworkURL: String? = {
                    guard let artwork = item.artwork else { return nil }
                    let size = CGSize(width: 100, height: 100)
                    guard let image = artwork.image(at: size), let data = image.jpegData(compressionQuality: 0.8) else { return nil }
                    return "data:image/jpeg;base64,\(data.base64EncodedString())"
                }()
                let res = MusicSearchResult(
                    id: item.playbackStoreID.isEmpty ? UUID().uuidString : item.playbackStoreID,
                    title: item.title ?? "Unknown",
                    artistName: item.artist ?? "Unknown",
                    albumName: item.albumTitle ?? "",
                    artworkURL: artworkURL,
                    itemType: "song",
                    popularity: 0
                )
                results.append(res)
                if results.count >= 30 { break }
            }
        }
        return results
    }
} */