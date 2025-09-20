import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import MusicKit
import MediaPlayer

// MARK: - DiaryMainSearchView
// An exact copy of the main search interface (ComprehensiveSearchView) but with
// tap behavior modified to open LogMusicFormView instead of profiles

struct DiaryMainSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var selectedFilter: SearchFilter = .all
    @State private var searchResults: SearchResults = SearchResults()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @StateObject private var smartSearchManager = SmartSearchManager()
    @State private var selectedMusicResult: MusicSearchResult?
    @State private var selectedArtistForProfile: String?
    @State private var showArtistProfile = false
    @StateObject private var recentItemsStore = RecentItemsStore()
    
    // Tab system - Search and Apple Music Library
    @State private var selectedTab: SearchTab = .search
    @State private var tabOffset: CGFloat = 0
    
    // Library services and state
    @StateObject private var libraryService = AppleMusicLibraryService.shared
    @StateObject private var unifiedLibraryService = UnifiedLibraryService.shared
    @StateObject private var platformPreferences = UnifiedMusicSearchService.shared
    @StateObject private var spotifyService = SpotifyService.shared
    @State private var librarySearchText = ""
    @State private var libraryViewState: LibraryNavigationState = .main
    @State private var selectedLibrarySection: LibrarySection?
    @State private var selectedPlaylist: LibraryPlaylist?
    @State private var playlistSongs: [LibraryItem] = []
    @State private var isLoadingPlaylistSongs = false
    
    // Search functionality
    @State private var searchTask: Task<Void, Never>?
    @State private var debounceTimer: Timer?
    @State private var recentQueryChips: [String] = []
    @State private var recentlyTappedItems: [RecentlyTappedItem] = []
    
    // MARK: - Dynamic Tab Logic
    private var availableTabs: [SearchTab] {
        var tabs: [SearchTab] = [.search]
        
        let preference = platformPreferences.platformPreference
        
        switch preference {
        case .appleMusicOnly, .appleMusicPrimary:
            tabs.append(.appleMusicLibrary)
        case .spotifyOnly, .spotifyPrimary:
            if spotifyService.isUserAuthenticated {
                tabs.append(.spotifyLibrary)
            }
        case .both:
            tabs.append(.appleMusicLibrary)
            if spotifyService.isUserAuthenticated {
                tabs.append(.spotifyLibrary)
            }
        }
        
        return tabs
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector (Search and Apple Music Library)
                tabSelector
                
                // Tab content
                TabView(selection: $selectedTab) {
                    searchTabView
                        .tag(SearchTab.search)
                    
                    if availableTabs.contains(.appleMusicLibrary) {
                        appleMusicLibraryTabView
                            .tag(SearchTab.appleMusicLibrary)
                    }
                    
                    if availableTabs.contains(.spotifyLibrary) {
                        spotifyLibraryTabView
                            .tag(SearchTab.spotifyLibrary)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Search Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
            debounceTimer?.invalidate()
        }
        .onAppear {
            // Load recent query chips
            if let data = UserDefaults.standard.array(forKey: "recent_search_queries") as? [String] {
                recentQueryChips = data
            }
            
            // Load recently tapped items
            loadRecentlyTappedItems()
            
            // Validate selected tab based on available tabs
            validateSelectedTab()
            
            // Set up library item navigation listeners
            NotificationCenter.default.addObserver(forName: NSNotification.Name("LibraryItemTapped"), object: nil, queue: .main) { note in
                if let musicResult = note.object as? MusicSearchResult {
                    selectedMusicResult = musicResult
                }
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("LibraryArtistTapped"), object: nil, queue: .main) { note in
                if let artistName = note.object as? String {
                    selectedArtistForProfile = artistName
                    showArtistProfile = true
                }
            }
        }
        // MODIFIED: Open LogMusicFormView instead of MusicProfileView
        .fullScreenCover(item: $selectedMusicResult) { music in
            LogMusicFormView(searchResult: music)
        }
        // MODIFIED: Open LogMusicFormView for artists too
        .fullScreenCover(isPresented: $showArtistProfile) {
            if let artistName = selectedArtistForProfile {
                // Convert artist to MusicSearchResult for logging
                let artistResult = MusicSearchResult(
                    id: UUID().uuidString,
                    title: artistName,
                    artistName: artistName,
                    albumName: "",
                    artworkURL: nil,
                    itemType: "artist",
                    popularity: 0
                )
                LogMusicFormView(searchResult: artistResult)
            }
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(availableTabs, id: \.id) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(tab.shortName)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .medium)
                            .foregroundColor(selectedTab == tab ? .purple : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.purple : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Search Tab View
    private var searchTabView: some View {
        VStack(spacing: 0) {
            // Search Header
            searchHeader
            
            // Search Content
            if searchText.isEmpty {
                emptySearchState
            } else if isLoading {
                SearchLoadingView()
            } else {
                searchResultsView
            }
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 16) {
            // Main search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search for music, artists, albums...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        if !searchText.isEmpty {
                            handleSearchTextChange(searchText)
                        }
                    }
                    .onChange(of: searchText) { _, newValue in
                        handleSearchTextChange(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
            // Filter pills (only when searching)
            if !searchText.isEmpty {
                filterPills
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Filter Pills (Music Only)
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Only show music-related filters
                ForEach([SearchFilter.all, .songs, .albums, .artists], id: \.self) { filter in
                    ModernFilterPill(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        action: {
                            selectedFilter = filter
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Recent searches
                if !recentQueryChips.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Searches")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recentQueryChips, id: \.self) { query in
                                    Button(query) {
                                        searchText = query
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // Recently tapped items
                if !recentlyTappedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recently Tapped")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(recentlyTappedItems.filter { item in
                                item.type == .song || item.type == .album || item.type == .artist
                            }.prefix(10)) { item in
                                RecentlyTappedCard(item: item) {
                                    handleRecentlyTappedItemTap(item)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Empty state message (only show if no recent content)
                let musicRecentlyTapped = recentlyTappedItems.filter { item in
                    item.type == .song || item.type == .album || item.type == .artist
                }
                if recentQueryChips.isEmpty && musicRecentlyTapped.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("Search for Music")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Find songs, artists, albums, and more")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 100)
                }
                
                // Add bottom padding for scroll
                Color.clear.frame(height: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(getFilteredResults(), id: \.id) { result in
                    SearchResultCard(result: result) {
                        handleResultTap(result)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Apple Music Library Tab View
    private var appleMusicLibraryTabView: some View {
        VStack(spacing: 0) {
            // Library Header
            libraryHeader
            
            // Library Content
            switch libraryViewState {
            case .main:
                mainLibraryContent
            case .sectionDetail:
                if let section = selectedLibrarySection {
                    sectionDetailView(section)
                }
            case .playlistDetail:
                if let playlist = selectedPlaylist {
                    playlistDetailView(playlist)
                }
            case .searchResults:
                librarySearchResults
            }
        }
        .onAppear {
            if libraryService.authorizationStatus == .notDetermined {
                Task {
                    _ = await libraryService.requestAuthorization()
                }
            } else if libraryService.authorizationStatus == .authorized && libraryService.recentlyAddedSongs.isEmpty {
                // Load library content if authorized but not yet loaded
                Task {
                    await libraryService.loadAllLibraryContent()
                }
            }
        }
    }
    
    // MARK: - Spotify Library Tab View
    private var spotifyLibraryTabView: some View {
        VStack(spacing: 0) {
            // Library Header (same as Apple Music)
            libraryHeader
            
            // Spotify Library Content (matching Apple Music structure)
            spotifyMainLibraryContent
        }
        .onAppear {
            if spotifyService.isUserAuthenticated {
                Task {
                    await unifiedLibraryService.loadSpotifyLibrary()
                }
            }
        }
    }
    
    // MARK: - Spotify Main Library Content (matching Apple Music structure)
    private var spotifyMainLibraryContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Authorization check
                if !spotifyService.isUserAuthenticated {
                    spotifyAuthorizationRequiredView
                } else if unifiedLibraryService.isLoading {
                    LibraryLoadingView()
                        .frame(height: 300)
                } else {
                    // Recently Added Section (matching Apple Music)
                    spotifyRecentlyAddedSection
                    
                    // Library Sections (matching Apple Music)
                    spotifyLibrarySectionsView
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await unifiedLibraryService.loadSpotifyLibrary()
        }
    }
    
    // MARK: - Spotify Recently Added Section (matching Apple Music)
    private var spotifyRecentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Added")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("See All") {
                    // Navigate to Spotify recently added
                }
                .font(.subheadline)
                .foregroundColor(.green)
            }
            .padding(.horizontal, 20)
            
            // Spotify style horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(getSpotifyRecentlyAdded(), id: \.id) { item in
                        SpotifyRecentlyAddedCard(item: item)
                            .onTapGesture {
                                // Convert to LibraryItem and handle tap
                                let libraryItem = LibraryItem(
                                    id: item.id,
                                    title: item.title,
                                    artistName: item.artistName,
                                    albumName: item.albumName,
                                    artworkURL: item.artworkURL,
                                    itemType: LibraryItemType(rawValue: item.itemType) ?? .song
                                )
                                handleLibraryItemTap(libraryItem)
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.trailing, 20)
            }
        }
    }
    
    // MARK: - Spotify Library Sections View (matching Apple Music)
    private var spotifyLibrarySectionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Library")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // 2x2 grid matching Apple Music library layout
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Songs section
                SpotifyLibrarySectionCard(
                    icon: "music.note",
                    title: "Songs",
                    count: getSpotifyLibraryCount(for: "songs"),
                    color: .green
                ) {
                    // Handle Spotify songs section tap
                }
                
                // Albums section
                SpotifyLibrarySectionCard(
                    icon: "opticaldisc",
                    title: "Albums",
                    count: getSpotifyLibraryCount(for: "albums"),
                    color: .orange
                ) {
                    // Handle Spotify albums section tap
                }
                
                // Artists section
                SpotifyLibrarySectionCard(
                    icon: "person.wave.2",
                    title: "Artists",
                    count: getSpotifyLibraryCount(for: "artists"),
                    color: .green
                ) {
                    // Handle Spotify artists section tap
                }
                
                // Playlists section
                SpotifyLibrarySectionCard(
                    icon: "music.note.list",
                    title: "Playlists",
                    count: getSpotifyLibraryCount(for: "playlists"),
                    color: .purple
                ) {
                    // Handle Spotify playlists section tap
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Spotify Authorization Required View
    private var spotifyAuthorizationRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Spotify Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Connect your Spotify account to view your library")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Connect Spotify") {
                Task {
                    await spotifyService.authenticateUser()
                }
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Library Header
    private var libraryHeader: some View {
        VStack(spacing: 16) {
            HStack {
                // Back button (when not in main view)
                if case .main = libraryViewState {
                    Text("Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Button(action: {
                        withAnimation {
                            libraryViewState = .main
                            selectedLibrarySection = nil
                            selectedPlaylist = nil
                            librarySearchText = ""
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                            Text("Library")
                                .font(.headline)
                        }
                        .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            
            // Search bar (always visible except in section/playlist detail views)
            if libraryViewState == .main || libraryViewState == .searchResults {
                LibrarySearchBar(searchText: $librarySearchText, onSearchChanged: { query in
                    Task {
                        await libraryService.searchLibrary(query: query)
                        if !query.isEmpty && !libraryService.searchResults.isEmpty {
                            libraryViewState = .searchResults
                        } else if query.isEmpty {
                            libraryViewState = .main
                        }
                    }
                })
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - Main Library Content
    private var mainLibraryContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Authorization check
                if libraryService.authorizationStatus != .authorized {
                    authorizationRequiredView
                } else if libraryService.isLoading {
                    LibraryLoadingView()
                        .frame(height: 300)
                } else {
                    // Recently Added Section
                    if !libraryService.recentlyAddedSongs.isEmpty {
                        recentlyAddedSection
                    }
                    
                    // Library Sections
                    librarySectionsView
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await libraryService.loadAllLibraryContent()
        }
    }
    
    // MARK: - Recently Added Section
    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Added")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("See All") {
                    let section = LibrarySection(
                        title: "Recently Added",
                        icon: "clock",
                        color: .purple,
                        itemCount: libraryService.recentlyAddedSongs.count,
                        itemType: .song
                    )
                    selectedLibrarySection = section
                    libraryViewState = .sectionDetail
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            .padding(.horizontal, 20)
            
            // Apple Music style horizontal scroll for songs only
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(libraryService.recentlyAddedSongs.prefix(20)), id: \.id) { song in
                        AppleMusicSongCard(song: song) {
                            handleLibraryItemTap(song)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.trailing, 20) // Extra padding for better scroll experience
            }
        }
    }
    
    // MARK: - Library Sections View
    private var librarySectionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Library")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(getLibrarySections(), id: \.id) { section in
                    LibrarySectionCard(section: section) {
                        selectedLibrarySection = section
                        libraryViewState = .sectionDetail
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Section Detail View
    private func sectionDetailView(_ section: LibrarySection) -> some View {
        Group {
            switch section.itemType {
            case .song:
                if section.title == "Recently Added" {
                    RecentlyAddedView(libraryService: libraryService)
                } else {
                    SongsLibraryView(libraryService: libraryService)
                }
            case .album:
                AlbumsLibraryView(libraryService: libraryService)
            case .artist:
                ArtistsLibraryView(libraryService: libraryService)
            case .playlist:
                PlaylistsView(libraryService: libraryService)
            }
        }
    }
    
    // MARK: - Playlist Detail View
    private func playlistDetailView(_ playlist: LibraryPlaylist) -> some View {
        PlaylistDetailView(playlist: playlist, libraryService: libraryService)
    }
    
    // MARK: - Library Search Results
    private var librarySearchResults: some View {
        LibrarySearchResultsView(
            libraryService: libraryService,
            searchText: librarySearchText
        )
    }
    
    // MARK: - Authorization Required View
    private var authorizationRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Apple Music Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Grant access to view your Apple Music library")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Grant Access") {
                Task {
                    _ = await libraryService.requestAuthorization()
                }
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.purple)
            .cornerRadius(12)
            
            if libraryService.authorizationStatus == .denied {
                VStack(spacing: 12) {
                    Text("Access Denied")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text("Please enable Apple Music access in Settings > Privacy & Security > Media & Apple Music")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Grant Access") {
                        Task {
                            _ = await libraryService.requestAuthorization()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func getLibrarySections() -> [LibrarySection] {
        return [
            LibrarySection(
                title: "Songs",
                icon: "music.note",
                color: .blue,
                itemCount: libraryService.librarySongs.count,
                itemType: .song
            ),
            LibrarySection(
                title: "Albums",
                icon: "opticaldisc",
                color: .orange,
                itemCount: libraryService.libraryAlbums.count,
                itemType: .album
            ),
            LibrarySection(
                title: "Artists",
                icon: "person.wave.2",
                color: .green,
                itemCount: libraryService.libraryArtists.count,
                itemType: .artist
            ),
            LibrarySection(
                title: "Playlists",
                icon: "music.note.list",
                color: .purple,
                itemCount: libraryService.enabledPlaylists.count,
                itemType: .playlist
            )
        ]
    }
    
    // MODIFIED: Handle library item tap to open LogMusicFormView
    private func handleLibraryItemTap(_ item: LibraryItem) {
        let musicResult = item.toMusicSearchResult()
        
        // Add to recent items
        let recentItem = RecentItem(
            type: RecentItemType(rawValue: item.itemType.rawValue) ?? .song,
            itemId: item.id,
            title: item.title,
            subtitle: item.artistName,
            artworkURL: item.artworkURL
        )
        recentItemsStore.upsert(recentItem)
        
        // Navigate to LogMusicFormView instead of profile
        if item.itemType == .artist {
            selectedArtistForProfile = item.artistName
            showArtistProfile = true
        } else {
            selectedMusicResult = musicResult
        }
    }
    
    // MARK: - Helper Functions
    
    private func getFilteredResults() -> [any SearchResult] {
        // Filter out users and lists, only show music content
        let musicResults = searchResults.prioritized(for: searchText).filter { result in
            result.type == .song || result.type == .album || result.type == .artist
        }
        
        switch selectedFilter {
        case .all: return musicResults
        case .songs: return musicResults.filter { $0.type == .song }
        case .albums: return musicResults.filter { $0.type == .album }
        case .artists: return musicResults.filter { $0.type == .artist }
        case .users, .lists: return [] // These filters shouldn't be available
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        debounceTimer?.invalidate()
        
        if newValue.isEmpty {
            searchResults = SearchResults()
            isLoading = false
            return
        }
        
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            performSearch(query: newValue)
        }
    }
    
    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        searchTask?.cancel()
        
        searchTask = Task {
            await MainActor.run { isLoading = true }
            
            do {
                let results = try await searchAppleMusic(query: query)
                
                await MainActor.run {
                    self.searchResults = results
                    self.isLoading = false
                    self.addToRecentSearches(query)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func searchAppleMusic(query: String) async throws -> SearchResults {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SearchResults()
        }
        
        // Search Apple Music catalog
        var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self, MusicKit.Artist.self, MusicKit.Album.self])
        request.limit = 25
        
        let response = try await request.response()
        
        // Helper to normalize titles for deduplication
        func normalizeTitle(_ title: String) -> String {
            return title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Process songs with deduplication
        var songResults: [any SearchResult] = []
        var seenSongs: Set<String> = []
        
        for song in response.songs {
            let normalizedTitle = normalizeTitle(song.title)
            let normalizedArtist = normalizeTitle(song.artistName)
            let key = "\(normalizedTitle)|\(normalizedArtist)"
            
            if !seenSongs.contains(key) {
                seenSongs.insert(key)
                songResults.append(MusicSongResult(from: song))
            }
        }
        
        // Process artists
        let artistResults: [any SearchResult] = response.artists.map { artist in
            MusicArtistResult(from: artist)
        }
        
        // Process albums with deduplication
        var albumResults: [any SearchResult] = []
        var seenAlbums: Set<String> = []

        func normalizeAlbumTitle(_ title: String) -> String {
            var t = normalizeTitle(title)
            t = t.replacingOccurrences(of: "\\s*\\((deluxe|clean|explicit|remaster(ed)?|expanded|edition|version|single|ep|anniversary|special|limited|bonus)[^)]*\\)", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\s*-\\s*(single|ep|deluxe|clean|explicit|expanded|edition|version|remaster(ed)?|anniversary|special|limited|bonus)\\s*$", with: "", options: .regularExpression)
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for album in response.albums {
            let normTitle = normalizeAlbumTitle(album.title)
            let normArtist = normalizeTitle(album.artistName)
            let key = "\(normTitle)|\(normArtist)"
            if !seenAlbums.contains(key) {
                seenAlbums.insert(key)
                albumResults.append(MusicAlbumResult(from: album))
            }
        }
        
        // Create results structure
        var results = SearchResults()
        results.songs = songResults
        results.artists = artistResults
        results.albums = albumResults
        
        return results
    }
    
    private func addToRecentSearches(_ query: String) {
        var recent = recentQueryChips
        recent.removeAll { $0 == query }
        recent.insert(query, at: 0)
        recentQueryChips = Array(recent.prefix(5))
        UserDefaults.standard.set(recentQueryChips, forKey: "recent_search_queries")
    }
    
    // MODIFIED: Handle result tap to open LogMusicFormView
    private func handleResultTap(_ result: any SearchResult) {
        print("🎯 Search result tapped: \(result.title) (type: \(result.type.rawValue))")
        
        // Add to recent items
        let recentItem = RecentItem(
            type: RecentItemType(rawValue: result.type.rawValue) ?? .song,
            itemId: result.id,
            title: result.title,
            subtitle: result.subtitle,
            artworkURL: result.artworkURL?.absoluteString
        )
        recentItemsStore.upsert(recentItem)
        
        // Add to recently tapped items
        addToRecentlyTapped(result)
        
        // Navigate to LogMusicFormView for all music types
        switch result.type {
        case .song, .album:
            // Convert SearchResult to MusicSearchResult for compatibility
            let musicResult = MusicSearchResult(
                id: result.id,
                title: result.title,
                artistName: result.subtitle,
                albumName: (result as? MusicSongResult)?.albumName ?? (result as? MusicAlbumResult)?.title ?? "",
                artworkURL: result.artworkURL?.absoluteString,
                itemType: result.type.rawValue,
                popularity: 0
            )
            print("🎯 Setting selectedMusicResult: \(musicResult.title)")
            selectedMusicResult = musicResult
        case .artist:
            print("🎯 Setting selectedArtistForProfile: \(result.title)")
            selectedArtistForProfile = result.title
            showArtistProfile = true
        case .user, .list:
            // Users and lists not supported in diary search
            break
        }
    }
    
    // MARK: - Recently Tapped Helper Functions
    private func addToRecentlyTapped(_ result: any SearchResult) {
        let newItem = RecentlyTappedItem(from: result)
        
        // Remove if already exists
        recentlyTappedItems.removeAll { $0.id == newItem.id }
        
        // Add to beginning
        recentlyTappedItems.insert(newItem, at: 0)
        
        // Keep only last 20 items
        recentlyTappedItems = Array(recentlyTappedItems.prefix(20))
        
        // Save to UserDefaults
        saveRecentlyTappedItems()
    }
    
    private func handleRecentlyTappedItemTap(_ item: RecentlyTappedItem) {
        // Convert back to SearchResult and handle tap
        let searchResult: any SearchResult
        
        switch item.type {
        case .song:
            searchResult = MusicSongResult(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                artworkURL: item.artworkURL != nil ? URL(string: item.artworkURL!) : nil,
                albumName: "",
                artistName: item.subtitle
            )
        case .album:
            searchResult = MusicAlbumResult(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                artworkURL: item.artworkURL != nil ? URL(string: item.artworkURL!) : nil,
                artistName: item.subtitle
            )
        case .artist:
            searchResult = MusicArtistResult(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                artworkURL: item.artworkURL != nil ? URL(string: item.artworkURL!) : nil,
                genreNames: nil
            )
        case .user, .list:
            // Users and lists not supported in diary search
            return
        }
        
        handleResultTap(searchResult)
    }
    
    private func saveRecentlyTappedItems() {
        if let encoded = try? JSONEncoder().encode(recentlyTappedItems) {
            UserDefaults.standard.set(encoded, forKey: "recently_tapped_items")
        }
    }
    
    private func loadRecentlyTappedItems() {
        if let data = UserDefaults.standard.data(forKey: "recently_tapped_items"),
           let decoded = try? JSONDecoder().decode([RecentlyTappedItem].self, from: data) {
            recentlyTappedItems = decoded
        }
    }
    
    private func validateSelectedTab() {
        // Ensure selected tab is available based on platform preferences
        if !availableTabs.contains(selectedTab) {
            selectedTab = availableTabs.first ?? .search
        }
    }
    
    private func getSpotifyRecentlyAdded() -> [MusicSearchResult] {
        // Return demo data for recently added Spotify songs
        return [
            MusicSearchResult(
                id: "spotify_recent_1",
                title: "As It Was",
                artistName: "Harry Styles",
                albumName: "Harry's House",
                artworkURL: nil,
                itemType: "song",
                popularity: 95
            ),
            MusicSearchResult(
                id: "spotify_recent_2",
                title: "Heat Waves",
                artistName: "Glass Animals",
                albumName: "Dreamland",
                artworkURL: nil,
                itemType: "song",
                popularity: 89
            ),
            MusicSearchResult(
                id: "spotify_recent_3",
                title: "Good 4 U",
                artistName: "Olivia Rodrigo",
                albumName: "SOUR",
                artworkURL: nil,
                itemType: "song",
                popularity: 88
            )
        ]
    }
    
    private func getSpotifyLibraryCount(for section: String) -> Int {
        // Return demo counts for Spotify library sections
        switch section {
        case "songs": return 1247
        case "albums": return 89
        case "artists": return 156
        case "playlists": return 23
        default: return 0
        }
    }
}
