import SwiftUI

struct RecentlyAddedView: View {
    @ObservedObject var libraryService: AppleMusicLibraryService
    @State private var selectedSortOption: LibrarySortOption = .recentlyAdded
    @State private var showingSortOptions = false
    
    // Only show songs - no filter needed
    private var recentlyAddedSongs: [LibraryItem] {
        // Get up to 30 recently added songs
        Array(libraryService.recentlyAddedSongs.prefix(30))
    }
    
    private var sortedItems: [LibraryItem] {
        selectedSortOption.sort(recentlyAddedSongs)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with filters and sort
                headerSection
                
                // Content
                if libraryService.isLoading {
                    LibraryLoadingView(message: "Loading recently added...")
                        .frame(maxHeight: .infinity)
                } else if sortedItems.isEmpty {
                    LibraryEmptyState(
                        title: "No Recently Added Songs",
                        subtitle: "Songs you add to your Apple Music library will appear here.",
                        icon: "music.note"
                    )
                } else {
                    contentView
                }
            }
            .navigationTitle("Recently Added")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSortOptions = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .confirmationDialog("Sort by", isPresented: $showingSortOptions, titleVisibility: .visible) {
                ForEach(LibrarySortOption.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        selectedSortOption = option
                    }
                }
            }
        }
        .onAppear {
            if libraryService.recentlyAddedSongs.isEmpty {
                Task {
                    await libraryService.loadRecentlyAdded()
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Results count - songs only, up to 30
            HStack {
                // Count removed
                
                Spacer()
                
                Text("Sorted by \(selectedSortOption.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Content View
    private var contentView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                ForEach(sortedItems) { item in
                    RecentlyAddedCard(item: item) {
                        handleItemTap(item)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    private func handleItemTap(_ item: LibraryItem) {
        // Navigate to appropriate profile
        let musicResult = item.toMusicSearchResult()
        
        // This would need to be passed up to the parent view for navigation
        // For now, we'll use NotificationCenter as a temporary solution
        NotificationCenter.default.post(
            name: NSNotification.Name("LibraryItemTapped"),
            object: musicResult
        )
    }
}

// MARK: - Library Filter Chip
struct LibraryFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple.opacity(0.15) : Color(.systemGray6))
            .foregroundColor(isSelected ? .purple : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    RecentlyAddedView(libraryService: AppleMusicLibraryService.shared)
}
