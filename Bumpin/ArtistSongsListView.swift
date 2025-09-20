import SwiftUI
import MusicKit

struct ArtistSongsListView: View {
    let artistName: String
    let songs: [ArtistCatalogItem]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var searchText = ""
    @State private var selectedSortOption: SongSortOption = .popularity
    @State private var selectedTimeFilter: TimeFilter = .allTime
    @State private var showingFilterSheet = false
    @State private var showingSearchFilters = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter header
                searchAndFilterHeader
                
                // Songs list
                songsListContent
            }
            .navigationTitle("\(artistName) - Songs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                SongsFilterSheet(
                    selectedSort: $selectedSortOption,
                    selectedTimeFilter: $selectedTimeFilter,
                    onApply: {
                        showingFilterSheet = false
                        // Apply filters with animation
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // Filtering is handled by computed properties
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
                
                TextField("Search songs...", text: $searchText)
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
            
            // Active filters display
            if selectedSortOption != .popularity || selectedTimeFilter != .allTime {
                activeFiltersView
            }
            
            // Results summary
            resultsSummaryView
        }
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if selectedSortOption != .popularity {
                    FilterPill(
                        title: "Sort: \(selectedSortOption.rawValue)",
                        isActive: true,
                        onRemove: { selectedSortOption = .popularity }
                    )
                }
                
                if selectedTimeFilter != .allTime {
                    FilterPill(
                        title: "Time: \(selectedTimeFilter.rawValue)",
                        isActive: true,
                        onRemove: { selectedTimeFilter = .allTime }
                    )
                }
                
                Button("Clear All") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSortOption = .popularity
                        selectedTimeFilter = .allTime
                    }
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
        }
    }
    
    private var resultsSummaryView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(filteredSongs.count) Songs")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if !searchText.isEmpty {
                    Text("Filtered from \(songs.count) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Sort indicator
            HStack(spacing: 4) {
                Image(systemName: selectedSortOption.icon)
                    .font(.caption)
                Text(selectedSortOption.rawValue)
                    .font(.caption)
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.horizontal)
    }
    
    // MARK: - Songs List Content
    
    private var songsListContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
                    EnhancedSongRowView(
                        song: song,
                        index: index + 1,
                        onTap: {
                            navigationCoordinator.navigateToMusicProfile(
                                TrendingItem(
                                    title: song.title,
                                    subtitle: song.artistName,
                                    artworkUrl: song.artworkURL,
                                    logCount: song.totalRatings,
                                    averageRating: song.averageRating > 0 ? song.averageRating : nil,
                                    itemType: "song",
                                    itemId: song.id
                                )
                            )
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
                }
                
                // Empty state for filtered results
                if filteredSongs.isEmpty && !searchText.isEmpty {
                    emptySearchResultsView
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .background(Color(.systemBackground))
    }
    
    private var emptySearchResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No songs match '\(searchText)'")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try adjusting your search terms or filters")
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
    }
    
    // MARK: - Computed Properties
    
    private var filteredSongs: [ArtistCatalogItem] {
        var filtered = songs
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { song in
                song.title.localizedCaseInsensitiveContains(searchText) ||
                song.albumName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply time filter
        if selectedTimeFilter == .recent {
            let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            filtered = filtered.filter { song in
                song.releaseDate ?? Date.distantPast >= sixMonthsAgo
            }
        }
        
        // Apply sorting
        return sortSongs(filtered, by: selectedSortOption)
    }
    
    private func sortSongs(_ songs: [ArtistCatalogItem], by option: SongSortOption) -> [ArtistCatalogItem] {
        switch option {
        case .popularity:
            return songs.sorted { $0.popularityScore > $1.popularityScore }
        case .rating:
            return songs.sorted { song1, song2 in
                if song1.averageRating == song2.averageRating {
                    return song1.totalRatings > song2.totalRatings
                }
                return song1.averageRating > song2.averageRating
            }
        case .alphabetical:
            return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .releaseDate:
            return songs.sorted { song1, song2 in
                let date1 = song1.releaseDate ?? Date.distantPast
                let date2 = song2.releaseDate ?? Date.distantPast
                return date1 > date2
            }
        case .duration:
            return songs.sorted { song1, song2 in
                let duration1 = song1.duration ?? 0
                let duration2 = song2.duration ?? 0
                return duration1 > duration2
            }
        }
    }
}

// MARK: - Supporting Components

struct FilterPill: View {
    let title: String
    let isActive: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(isActive ? .white : .purple)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.purple : Color.purple.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.purple.opacity(0.3), lineWidth: isActive ? 0 : 1)
        )
    }
}

struct SongsFilterSheet: View {
    @Binding var selectedSort: SongSortOption
    @Binding var selectedTimeFilter: TimeFilter
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
                        ForEach(SongSortOption.allCases, id: \.self) { option in
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
                
                // Time filter options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Time Period")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 12) {
                        ForEach(TimeFilter.allCases, id: \.self) { filter in
                            FilterOptionRow(
                                title: filter.rawValue,
                                subtitle: filter.description,
                                icon: filter.icon,
                                isSelected: selectedTimeFilter == filter,
                                onTap: {
                                    selectedTimeFilter = filter
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
                        selectedTimeFilter = .allTime
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

struct FilterOptionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.purple : Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sort Options

enum SongSortOption: String, CaseIterable {
    case popularity = "Popularity"
    case rating = "Highest Rated"
    case alphabetical = "A to Z"
    case releaseDate = "Release Date"
    case duration = "Duration"
    
    var icon: String {
        switch self {
        case .popularity: return "chart.line.uptrend.xyaxis"
        case .rating: return "star.fill"
        case .alphabetical: return "textformat.abc"
        case .releaseDate: return "calendar"
        case .duration: return "clock"
        }
    }
    
    var description: String {
        switch self {
        case .popularity: return "Most popular songs first"
        case .rating: return "Highest rated songs first"
        case .alphabetical: return "Alphabetical order"
        case .releaseDate: return "Newest releases first"
        case .duration: return "Longest songs first"
        }
    }
}

extension TimeFilter {
    var description: String {
        switch self {
        case .allTime: return "All releases"
        case .recent: return "Last 6 months only"
        }
    }
}

#Preview {
    ArtistSongsListView(
        artistName: "Travis Scott",
        songs: []
    )
    .environmentObject(NavigationCoordinator())
}
