import SwiftUI

struct ArtistsLibraryView: View {
    @ObservedObject var libraryService: AppleMusicLibraryService
    @State private var selectedSortOption: ArtistSortOption = .alphabetical
    @State private var showingSortOptions = false
    @State private var searchText = ""
    
    enum ArtistSortOption: String, CaseIterable {
        case alphabetical = "A to Z"
        case recentlyAdded = "Recently Added"
        
        var icon: String {
            switch self {
            case .alphabetical: return "textformat.abc"
            case .recentlyAdded: return "clock"
            }
        }
        
        func sort(_ artists: [LibraryItem]) -> [LibraryItem] {
            switch self {
            case .alphabetical:
                return artists.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
            case .recentlyAdded:
                return artists.sorted { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
            }
        }
    }
    
    private var filteredArtists: [LibraryItem] {
        if searchText.isEmpty {
            return libraryService.libraryArtists
        }
        
        let lowercaseQuery = searchText.lowercased()
        return libraryService.libraryArtists.filter { artist in
            artist.artistName.lowercased().contains(lowercaseQuery)
        }
    }
    
    private var sortedArtists: [LibraryItem] {
        selectedSortOption.sort(filteredArtists)
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
                    LibraryLoadingView(message: "Loading artists...")
                        .frame(maxHeight: .infinity)
                } else if sortedArtists.isEmpty {
                    emptyStateView
                } else {
                    artistsGrid
                }
            }
            .navigationTitle("Artists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSortOptions = true }) {
                        Image(systemName: selectedSortOption.icon)
                    }
                }
            }
            .confirmationDialog("Sort by", isPresented: $showingSortOptions, titleVisibility: .visible) {
                ForEach(ArtistSortOption.allCases, id: \.self) { option in
                    Button(action: { selectedSortOption = option }) {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            }
        }
        .onAppear {
            if libraryService.libraryArtists.isEmpty {
                Task {
                    await libraryService.loadLibraryArtists()
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
                
                TextField("Search artists", text: $searchText)
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
            
            Text("Sorted by \(selectedSortOption.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Artists Grid
    private var artistsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                ForEach(sortedArtists) { artist in
                    ArtistGridCard(artist: artist) {
                        handleArtistTap(artist)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await libraryService.loadLibraryArtists()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty {
                LibraryEmptyState(
                    title: "No Artists",
                    subtitle: "Artists will appear here when you add their music to your library.",
                    icon: "person.wave.2"
                )
            } else {
                LibraryEmptyState(
                    title: "No Results",
                    subtitle: "No artists match '\(searchText)'",
                    icon: "magnifyingglass"
                )
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    private func handleArtistTap(_ artist: LibraryItem) {
        // Navigate to artist profile using existing system
        NotificationCenter.default.post(
            name: NSNotification.Name("LibraryArtistTapped"),
            object: artist.artistName
        )
    }
}

// MARK: - Artist Grid Card
struct ArtistGridCard: View {
    let artist: LibraryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Artist artwork (circular)
                if let artworkUrl = artist.artworkURL, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        artistPlaceholder
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    artistPlaceholder
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                }
                
                // Artist name
                Text(artist.artistName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 100)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artistPlaceholder: some View {
        Circle()
            .fill(Color.green.opacity(0.3))
            .overlay(
                Image(systemName: "person.wave.2")
                    .foregroundColor(.green)
                    .font(.title2)
            )
    }
}

#Preview {
    ArtistsLibraryView(libraryService: AppleMusicLibraryService.shared)
}
