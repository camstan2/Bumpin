import SwiftUI
import MusicKit

struct AddToListenLaterView: View {
    let selectedSection: ListenLaterItemType
    @ObservedObject var listenLaterService: ListenLaterService
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [MusicSearchResult] = []
    @State private var isSearching = false
    @State private var selectedFilter: ListenLaterItemType = .song
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Filter Tabs
                filterTabs
                
                // Search Results
                searchResultsView
            }
            .navigationTitle("Add to Listen Later")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            selectedFilter = selectedSection
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search \(selectedFilter.displayName.lowercased())...", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: searchText) { _, newValue in
                    debounceSearch()
                }
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(ListenLaterItemType.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                    if !searchText.isEmpty {
                        debounceSearch()
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 12, weight: .medium))
                            
                            Text(filter.displayName)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(selectedFilter == filter ? filter.color : .secondary)
                        
                        Rectangle()
                            .fill(selectedFilter == filter ? filter.color : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        .padding(.top, 8)
    }
    
    // MARK: - Search Results
    private var searchResultsView: some View {
        Group {
            if isSearching {
                loadingView
            } else if searchResults.isEmpty && !searchText.isEmpty {
                emptyStateView
            } else if searchText.isEmpty {
                initialStateView
            } else {
                resultsList
            }
        }
    }
    
    // Results list
    private var resultsList: some View {
        List(filteredResults) { result in
            AddToListenLaterResultRow(
                result: result,
                onAdd: { result in
                    Task {
                        let success = await listenLaterService.addItem(result, type: selectedFilter)
                        if success {
                            // Trigger a refresh to ensure UI updates
                            await MainActor.run {
                                listenLaterService.refreshAllSections()
                            }
                            dismiss()
                        }
                    }
                }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
        .listStyle(.plain)
    }
    
    // Filtered results based on selected filter
    private var filteredResults: [MusicSearchResult] {
        return searchResults.filter { result in
            switch selectedFilter {
            case .song: return result.itemType == "song"
            case .album: return result.itemType == "album"
            case .artist: return result.itemType == "artist"
            }
        }
    }
    
    // Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter.icon)
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Initial state view
    private var initialStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedFilter.icon)
                .font(.system(size: 48))
                .foregroundColor(selectedFilter.color.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Search for \(selectedFilter.displayName)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Find \(selectedFilter.displayName.lowercased()) to add to your Listen Later list")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Search Functions
    private func debounceSearch() {
        searchTask?.cancel()
        
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
            await performSearch()
        }
    }
    
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
        }
        
        do {
            // Use UnifiedMusicSearchService for proper deduplication
            let unifiedResults = await UnifiedMusicSearchService.shared.search(query: searchText, limit: 25)
            
            // Combine all results from the unified service
            let allResults = unifiedResults.songs + unifiedResults.artists + unifiedResults.albums
            
            await MainActor.run {
                searchResults = allResults
                isSearching = false
            }
            
        } catch {
            print("❌ Search failed: \(error)")
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
        }
    }
    
}

// MARK: - Add to Listen Later Result Row
struct AddToListenLaterResultRow: View {
    let result: MusicSearchResult
    let onAdd: (MusicSearchResult) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Artwork
            Group {
                if let artworkURL = result.artworkURL, let url = URL(string: artworkURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        placeholderView
                    }
                } else {
                    placeholderView
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(result.itemType == "artist" ? 25 : 6)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if result.itemType != "artist" {
                    Text(result.artistName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(result.itemType.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorForItemType(result.itemType))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(colorForItemType(result.itemType).opacity(0.1))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Add button
            Button(action: {
                onAdd(result)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: result.itemType == "artist" ? 25 : 6)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Image(systemName: iconForItemType(result.itemType))
                    .font(.system(size: 20))
                    .foregroundColor(.gray.opacity(0.6))
            )
    }
    
    private func colorForItemType(_ itemType: String) -> Color {
        switch itemType.lowercased() {
        case "song": return .blue
        case "album": return .green
        case "artist": return .orange
        default: return .purple
        }
    }
    
    private func iconForItemType(_ itemType: String) -> String {
        switch itemType.lowercased() {
        case "song": return "music.note"
        case "album": return "opticaldisc"
        case "artist": return "person.wave.2"
        default: return "music.note"
        }
    }
}
