import SwiftUI

// MARK: - LogMusicSearchView
// A lightweight clone of ComprehensiveSearchView that sends selected items
// to LogMusicFormView instead of profile views. It reuses all the global
// helper structs (SearchResult, MusicSongResult, etc.) already declared in
// ComprehensiveSearchView.swift.

struct LogMusicSearchView: View {
    // MARK: - State
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var searchResults = SearchResults()
    @State private var isSearching = false
    @State private var selectedResult: MusicSearchResult?
    @State private var recentQueryChips: [String] = []
    @State private var recentlyTappedItems: [RecentlyTappedItem] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar & chips from the main view
                searchBar
                if !searchText.isEmpty {
                    filterChips
                }
                resultsList
                Spacer(minLength: 0)
            }
            .navigationTitle("Search Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }
            }
        }
        .fullScreenCover(item: $selectedResult) { res in
            LogMusicFormView(searchResult: res)
        }
        .onAppear {
            loadRecentSearches()
            loadRecentlyTappedItems()
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search Apple Music…", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: searchText) { _, _ in debounceSearch() }
            if isSearching { ProgressView().scaleEffect(0.8) }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
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
            .padding(.vertical, 6)
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        Group {
            if isSearching {
                ProgressView().padding()
            } else if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                emptySearchState
            } else if filteredResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.6))
                    Text("No results")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Try a different search")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredResults, id: \.id) { result in
                            SearchResultCard(result: result) {
                                handleTap(result)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
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
                                    RecentSearchPill(query: query) {
                                        searchText = query
                                    }
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
                        
                        Text("Find songs, artists, and albums to log")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 100)
                }
                
                // Add bottom padding for scroll
                Color.clear.frame(height: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Row
    @ViewBuilder private func row(for result: any SearchResult) -> some View {
        Button(action: { handleTap(result) }) {
            HStack(spacing: 12) {
                EnhancedArtworkView(artworkUrl: result.artworkURL?.absoluteString, itemType: result.type.rawValue, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title).font(.subheadline).fontWeight(.medium).lineLimit(1)
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text(result.type.rawValue.capitalized)
                    .font(.caption2)
                    .padding(4)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers
    private var filteredResults: [any SearchResult] {
        let results = searchResults.prioritized(for: searchText)
        switch selectedFilter {
        case .all: return results
        case .songs: return results.filter { $0.type == .song }
        case .albums: return results.filter { $0.type == .album }
        case .artists: return results.filter { $0.type == .artist }
        case .users, .lists: return []
        }
    }

    private func handleTap(_ result: any SearchResult) {
        // Convert to MusicSearchResult and open log form
        let musicResult = MusicSearchResult(
            id: result.id,
            title: result.title,
            artistName: result.subtitle,
            albumName: result.title,
            artworkURL: result.artworkURL?.absoluteString,
            itemType: result.type.rawValue,
            popularity: 0
        )
        
        // Add to recently tapped items
        addToRecentlyTapped(result)
        
        selectedResult = musicResult
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
        
        handleTap(searchResult)
    }
    
    private func saveRecentlyTappedItems() {
        recentlyTappedItems = RecentlyTappedStore.save(recentlyTappedItems, key: "recently_tapped_items_diary")
    }
    
    private func loadRecentlyTappedItems() {
        recentlyTappedItems = RecentlyTappedStore.load(key: "recently_tapped_items_diary")
    }
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.array(forKey: "recent_search_queries_diary") as? [String] {
            recentQueryChips = data
        }
    }
    
    private func addToRecentSearches(_ query: String) {
        var recent = recentQueryChips
        recent.removeAll { $0 == query }
        recent.insert(query, at: 0)
        recentQueryChips = Array(recent.prefix(5))
        UserDefaults.standard.set(recentQueryChips, forKey: "recent_search_queries_diary")
    }

    // Debounce helper
    @State private var debounceTask: DispatchWorkItem?
    private func debounceSearch() {
        debounceTask?.cancel()
        let task = DispatchWorkItem { Task { await performSearch(query: searchText) } }
        debounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
    }

    private func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run { self.searchResults = .init(); self.isSearching = false }
            return
        }
        await MainActor.run { self.isSearching = true }
        let unified = await UnifiedMusicSearchService.shared.search(query: query, limit: 30)
        await MainActor.run {
            // Convert MusicSearchResult to SearchResult implementations
            self.searchResults.songs = unified.songs.map { musicResult in
                // Create MusicSongResult with custom initializer
                var songResult = MusicSongResult(
                    id: musicResult.id,
                    title: musicResult.title,
                    subtitle: musicResult.artistName,
                    artworkURL: musicResult.artworkURL != nil ? URL(string: musicResult.artworkURL!) : nil,
                    albumName: musicResult.albumName,
                    artistName: musicResult.artistName
                )
                return songResult as any SearchResult
            }
            
            self.searchResults.artists = unified.artists.map { musicResult in
                // Create MusicArtistResult with custom initializer
                var artistResult = MusicArtistResult(
                    id: musicResult.id,
                    title: musicResult.title,
                    subtitle: musicResult.artistName,
                    artworkURL: musicResult.artworkURL != nil ? URL(string: musicResult.artworkURL!) : nil,
                    genreNames: nil
                )
                return artistResult as any SearchResult
            }
            
            self.searchResults.albums = unified.albums.map { musicResult in
                // Create MusicAlbumResult with custom initializer
                var albumResult = MusicAlbumResult(
                    id: musicResult.id,
                    title: musicResult.title,
                    subtitle: musicResult.artistName,
                    artworkURL: musicResult.artworkURL != nil ? URL(string: musicResult.artworkURL!) : nil,
                    artistName: musicResult.artistName
                )
                return albumResult as any SearchResult
            }
            
            self.isSearching = false
            
            // Add to recent searches
            self.addToRecentSearches(query)
        }
    }
}
