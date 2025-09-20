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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar & chips from the main view
                searchBar
                filterChips
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
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.caption)
                            Text(filter.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedFilter == filter ? filter.color.opacity(0.2) : Color(.systemGray5))
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        Group {
            if isSearching { ProgressView().padding() }
            else if searchText.trimmingCharacters(in: .whitespaces).isEmpty { EmptyView() }
            else if filteredResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note").font(.system(size: 40)).foregroundColor(.gray)
                    Text("No results")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                List(filteredResults, id: \ .id) { result in row(for: result) }
                    .listStyle(.plain)
            }
        }
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
        selectedResult = musicResult
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
        }
    }
}
