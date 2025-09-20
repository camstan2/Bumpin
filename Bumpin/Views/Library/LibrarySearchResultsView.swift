import SwiftUI

struct LibrarySearchResultsView: View {
    @ObservedObject var libraryService: AppleMusicLibraryService
    let searchText: String
    @State private var selectedFilter: LibrarySearchFilter = .all
    
    enum LibrarySearchFilter: String, CaseIterable {
        case all = "All"
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
        case playlists = "Playlists"
        
        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .songs: return "music.note"
            case .albums: return "opticaldisc"
            case .artists: return "person.wave.2"
            case .playlists: return "music.note.list"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .purple
            case .songs: return .blue
            case .albums: return .orange
            case .artists: return .green
            case .playlists: return .purple
            }
        }
    }
    
    private var filteredResults: [LibraryItem] {
        switch selectedFilter {
        case .all:
            return libraryService.searchResults
        case .songs:
            return libraryService.searchResults.filter { $0.itemType == .song }
        case .albums:
            return libraryService.searchResults.filter { $0.itemType == .album }
        case .artists:
            return libraryService.searchResults.filter { $0.itemType == .artist }
        case .playlists:
            return libraryService.searchResults.filter { $0.itemType == .playlist }
        }
    }
    
    private var groupedResults: [LibraryItemType: [LibraryItem]] {
        Dictionary(grouping: libraryService.searchResults) { $0.itemType }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search info and filters
            headerSection
            
            // Content
            if libraryService.isSearching {
                searchLoadingView
            } else if libraryService.searchResults.isEmpty {
                emptySearchView
            } else {
                searchResultsContent
            }
        }
        .navigationTitle("Search Results")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Trigger search if not already searching
            if !libraryService.isSearching && libraryService.searchResults.isEmpty {
                Task {
                    await libraryService.searchLibrary(query: searchText)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Search query info
            HStack {
                Text("Results for \"\(searchText)\"")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Count removed
            }
            .padding(.horizontal, 20)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LibrarySearchFilter.allCases, id: \.self) { filter in
                        let count = getCountForFilter(filter)
                        
                        LibraryFilterChip(
                            title: filter.rawValue,
                            icon: filter.icon,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                        .opacity(count > 0 || filter == .all ? 1.0 : 0.5)
                        .disabled(count == 0 && filter != .all)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Search Loading View
    private var searchLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching your library...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty Search View
    private var emptySearchView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("No items in your library match \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Search Apple Music Instead") {
                // Switch to global search
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToGlobalSearch"),
                    object: searchText
                )
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.purple)
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Search Results Content
    private var searchResultsContent: some View {
        ScrollView {
            if selectedFilter == .all {
                // Show grouped results when "All" is selected
                groupedResultsView
            } else {
                // Show filtered results
                filteredResultsView
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Grouped Results View
    private var groupedResultsView: some View {
        LazyVStack(spacing: 24) {
            ForEach(LibraryItemType.allCases, id: \.self) { itemType in
                if let items = groupedResults[itemType], !items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Section header
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: itemType.icon)
                                    .foregroundColor(itemType.color)
                                
                                Text(itemType.displayName.capitalized)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            // Count removed
                        }
                        .padding(.horizontal, 20)
                        
                        // Items
                        LazyVStack(spacing: 0) {
                            ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { index, item in
                                LibraryItemRow(item: item) {
                                    handleItemTap(item)
                                }
                                .padding(.horizontal, 20)
                                
                                if index < min(4, items.count - 1) {
                                    Divider()
                                        .padding(.leading, 82)
                                }
                            }
                        }
                        
                        // Show more button if there are more items
                        if items.count > 5 {
                            Button("Show all \(itemType.displayName.lowercased())") {
                                selectedFilter = LibrarySearchFilter(rawValue: itemType.displayName) ?? .all
                            }
                            .font(.subheadline)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Filtered Results View
    private var filteredResultsView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, item in
                LibraryItemRow(item: item) {
                    handleItemTap(item)
                }
                .padding(.horizontal, 20)
                
                if index < filteredResults.count - 1 {
                    Divider()
                        .padding(.leading, 82)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    private func getCountForFilter(_ filter: LibrarySearchFilter) -> Int {
        switch filter {
        case .all:
            return libraryService.searchResults.count
        case .songs:
            return libraryService.searchResults.filter { $0.itemType == .song }.count
        case .albums:
            return libraryService.searchResults.filter { $0.itemType == .album }.count
        case .artists:
            return libraryService.searchResults.filter { $0.itemType == .artist }.count
        case .playlists:
            return libraryService.searchResults.filter { $0.itemType == .playlist }.count
        }
    }
    
    private func handleItemTap(_ item: LibraryItem) {
        let musicResult = item.toMusicSearchResult()
        
        // Add to recent items
        let recentItem = RecentItem(
            type: RecentItemType(rawValue: item.itemType.rawValue) ?? .song,
            itemId: item.id,
            title: item.title,
            subtitle: item.artistName,
            artworkURL: item.artworkURL
        )
        
        // Navigate to profile
        if item.itemType == .artist {
            NotificationCenter.default.post(
                name: NSNotification.Name("LibraryArtistTapped"),
                object: item.artistName
            )
        } else {
            NotificationCenter.default.post(
                name: NSNotification.Name("LibraryItemTapped"),
                object: musicResult
            )
        }
    }
}

// Extension removed - LibrarySearchFilter is nested inside LibrarySearchResultsView

#Preview {
    NavigationStack {
        LibrarySearchResultsView(
            libraryService: AppleMusicLibraryService.shared,
            searchText: "Taylor Swift"
        )
    }
}
