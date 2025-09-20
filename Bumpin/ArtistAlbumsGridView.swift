import SwiftUI
import MusicKit

struct ArtistAlbumsGridView: View {
    let artistName: String
    let albums: [ArtistCatalogItem]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var searchText = ""
    @State private var selectedSortOption: AlbumSortOption = .popularity
    @State private var selectedAlbumFilter: AlbumFilter = .studioAlbums
    @State private var showingFilterSheet = false
    @State private var gridColumns: Int = 2
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter header
                searchAndFilterHeader
                
                // Albums grid
                albumsGridContent
            }
            .navigationTitle("\(artistName) - Albums")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { gridColumns = 2 }) {
                            Label("2 Columns", systemImage: "square.grid.2x2")
                        }
                        Button(action: { gridColumns = 3 }) {
                            Label("3 Columns", systemImage: "square.grid.3x3")
                        }
                        Divider()
                        Button(action: { showingFilterSheet = true }) {
                            Label("Filter & Sort", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                AlbumsFilterSheet(
                    selectedSort: $selectedSortOption,
                    selectedAlbumFilter: $selectedAlbumFilter,
                    onApply: {
                        showingFilterSheet = false
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // Filtering handled by computed properties
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Search and Filter Header
    
    private var searchAndFilterHeader: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search albums...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Results summary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(filteredAlbums.count) Albums")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if !searchText.isEmpty {
                        Text("Filtered from \(albums.count) total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Total discography")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Grid layout controls
                HStack(spacing: 8) {
                    Button(action: { gridColumns = 2 }) {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(gridColumns == 2 ? .purple : .gray)
                    }
                    Button(action: { gridColumns = 3 }) {
                        Image(systemName: "square.grid.3x3")
                            .foregroundColor(gridColumns == 3 ? .purple : .gray)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Albums Grid Content
    
    private var albumsGridContent: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns == 2 ? twoColumnGrid : threeColumnGrid, spacing: 16) {
                ForEach(filteredAlbums) { album in
                    EnhancedAlbumCardView(
                        album: album,
                        onTap: {
                            navigationCoordinator.navigateToMusicProfile(
                                TrendingItem(
                                    title: album.title,
                                    subtitle: album.artistName,
                                    artworkUrl: album.artworkURL,
                                    logCount: album.totalRatings,
                                    averageRating: album.averageRating > 0 ? album.averageRating : nil,
                                    itemType: "album",
                                    itemId: album.id
                                )
                            )
                        }
                    )
                }
                
                // Empty state for filtered results
                if filteredAlbums.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "opticaldisc")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No albums match '\(searchText)'")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Try adjusting your search terms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Clear Search") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                searchText = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .padding(.vertical, 60)
                    .gridCellColumns(gridColumns) // Span all columns
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.3), value: gridColumns)
    }
    
    // MARK: - Grid Configurations
    
    private var twoColumnGrid: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }
    
    private var threeColumnGrid: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }
    
    // MARK: - Computed Properties
    
    private var filteredAlbums: [ArtistCatalogItem] {
        var filtered = albums
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { album in
                album.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply album type filter
        if selectedAlbumFilter == .studioAlbums {
            filtered = filtered.filter { album in
                let title = album.title.lowercased()
                return !title.contains("single") && 
                       !title.contains("ep") && 
                       !title.contains("remix") &&
                       !title.contains("live") &&
                       !title.contains("deluxe edition") &&
                       !title.contains("remastered")
            }
        }
        
        // Apply sorting
        return sortAlbums(filtered, by: selectedSortOption)
    }
    
    private func sortAlbums(_ albums: [ArtistCatalogItem], by option: AlbumSortOption) -> [ArtistCatalogItem] {
        switch option {
        case .popularity:
            return albums.sorted { $0.popularityScore > $1.popularityScore }
        case .rating:
            return albums.sorted { album1, album2 in
                if album1.averageRating == album2.averageRating {
                    return album1.totalRatings > album2.totalRatings
                }
                return album1.averageRating > album2.averageRating
            }
        case .alphabetical:
            return albums.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .releaseDate:
            return albums.sorted { album1, album2 in
                let date1 = album1.releaseDate ?? Date.distantPast
                let date2 = album2.releaseDate ?? Date.distantPast
                return date1 > date2
            }
        case .trackCount:
            return albums.sorted { album1, album2 in
                let count1 = album1.trackCount ?? 0
                let count2 = album2.trackCount ?? 0
                return count1 > count2
            }
        }
    }
}

// MARK: - Supporting Components

struct AlbumsFilterSheet: View {
    @Binding var selectedSort: AlbumSortOption
    @Binding var selectedAlbumFilter: AlbumFilter
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Sort options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sort By")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 12) {
                        ForEach(AlbumSortOption.allCases, id: \.self) { option in
                            FilterOptionRow(
                                title: option.rawValue,
                                subtitle: option.description,
                                icon: option.icon,
                                isSelected: selectedSort == option,
                                onTap: {
                                    selectedSort = option
                                }
                            )
                        }
                    }
                }
                
                Divider()
                
                // Album type filter
                VStack(alignment: .leading, spacing: 16) {
                    Text("Album Type")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 12) {
                        ForEach(AlbumFilter.allCases, id: \.self) { filter in
                            FilterOptionRow(
                                title: filter.rawValue,
                                subtitle: filter.description,
                                icon: filter.icon,
                                isSelected: selectedAlbumFilter == filter,
                                onTap: {
                                    selectedAlbumFilter = filter
                                }
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Apply button
                Button(action: {
                    onApply()
                    dismiss()
                }) {
                    Text("Apply Filters")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding()
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        selectedSort = .popularity
                        selectedAlbumFilter = .studioAlbums
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Album Sort Options

enum AlbumSortOption: String, CaseIterable {
    case popularity = "Popularity"
    case rating = "Highest Rated"
    case alphabetical = "A to Z"
    case releaseDate = "Release Date"
    case trackCount = "Track Count"
    
    var icon: String {
        switch self {
        case .popularity: return "chart.line.uptrend.xyaxis"
        case .rating: return "star.fill"
        case .alphabetical: return "textformat.abc"
        case .releaseDate: return "calendar"
        case .trackCount: return "music.note.list"
        }
    }
    
    var description: String {
        switch self {
        case .popularity: return "Most popular albums first"
        case .rating: return "Highest rated albums first"
        case .alphabetical: return "Alphabetical order"
        case .releaseDate: return "Newest releases first"
        case .trackCount: return "Most tracks first"
        }
    }
}

extension AlbumFilter {
    var description: String {
        switch self {
        case .all: return "All releases including singles, EPs"
        case .studioAlbums: return "Studio albums only"
        }
    }
}

#Preview {
    ArtistAlbumsGridView(
        artistName: "Travis Scott",
        albums: []
    )
    .environmentObject(NavigationCoordinator())
}
