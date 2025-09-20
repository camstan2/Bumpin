import SwiftUI
import MusicKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Filter Options (using existing SongSortOption from ArtistSongsListView)

enum ArtistSongFilterOption: String, CaseIterable {
    case all = "All Songs"
    case rated = "Rated Only"
    case unrated = "Unrated"
    case recent = "Recent"
    case popular = "Popular"
    
    var systemImage: String {
        switch self {
        case .all: return "music.note"
        case .rated: return "star.circle"
        case .unrated: return "star.circle.slash"
        case .recent: return "clock.circle"
        case .popular: return "chart.line.uptrend.xyaxis.circle"
        }
    }
}

struct ArtistProfileView: View {
    let artistName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    
    // Enhanced ViewModel
    @StateObject private var viewModel: ArtistProfileViewModel
    
    // UI state
    @State private var showingFilterOptions = false
    @State private var showingSortOptions = false
    @State private var showingAllSongs = false
    @State private var showingAllAlbums = false
    @State private var displayedSongsCount = 10 // Initial display count
    @State private var maxDisplayedSongs = 10 // Current maximum to display
    @State private var selectedSortOption: SongSortOption = .popularity
    @State private var selectedFilterOption: ArtistSongFilterOption = .all
    
    // Listen Later integration
    @State private var isAddingToListenLater = false
    @State private var listenLaterSuccess = false
    
    // Log form
    @State private var showLogForm = false
    
    init(artistName: String) {
        self.artistName = artistName
        self._viewModel = StateObject(wrappedValue: ArtistProfileViewModel(artistName: artistName))
    }
    
    // MARK: - Computed Properties for Sort/Filter
    
    private var sortedAndFilteredSongs: [ArtistCatalogItem] {
        let filtered = filteredSongs
        return sortedSongs(filtered)
    }
    
    private var filteredSongs: [ArtistCatalogItem] {
        let allSongs = viewModel.displayedSongs
        
        switch selectedFilterOption {
        case .all:
            return allSongs
        case .rated:
            return allSongs.filter { $0.averageRating > 0 }
        case .unrated:
            return allSongs.filter { $0.averageRating == 0 }
        case .recent:
            // Filter songs from last 30 days (if we had release dates)
            return allSongs.filter { item in
                guard let releaseDate = item.releaseDate else { return false }
                return Calendar.current.dateInterval(of: .month, for: Date())?.contains(releaseDate) ?? false
            }
        case .popular:
            return allSongs.filter { $0.popularityScore > 5.0 }
        }
    }
    
    private func sortedSongs(_ songs: [ArtistCatalogItem]) -> [ArtistCatalogItem] {
        switch selectedSortOption {
        case .popularity:
            return songs.sorted { $0.popularityScore > $1.popularityScore }
        case .rating:
            return songs.sorted { $0.averageRating > $1.averageRating }
        case .releaseDate:
            return songs.sorted { ($0.releaseDate ?? Date.distantPast) > ($1.releaseDate ?? Date.distantPast) }
        case .alphabetical:
            return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .duration:
            return songs.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Sophisticated background with subtle gradient
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 32) { // Increased spacing for better visual hierarchy
                    // Artist header with loading states
                    if viewModel.loadingState == .loading {
                        ArtistHeaderSkeleton()
                    } else {
                        artistHeaderContent
                    }
                    
                    // Loading state or content
                    switch viewModel.loadingState {
                    case .loading:
                        loadingSkeletonView
                    case .error(let message):
                        errorStateView(message: message)
                    case .loaded:
                        // Artist Rating Section
                        artistRatingSection
                        
                        // Rating Distribution Section
                        RatingDistributionView(
                            itemId: artistName.lowercased().replacingOccurrences(of: " ", with: "-"),
                            itemType: "artist",
                            itemTitle: artistName
                        )
                        
                        // Popularity Graph Section
                        PopularityGraphView(
                            itemId: artistName.lowercased().replacingOccurrences(of: " ", with: "-"),
                            itemType: "artist",
                            itemTitle: artistName
                        )
                        
                        // Top Songs Section
                        if !viewModel.displayedSongs.isEmpty {
                            enhancedTopSongsSection
                        } else if viewModel.totalSongsCount == 0 {
                            emptyTopSongsView
                        }
                        
                        // Albums Section
                        if !viewModel.displayedAlbums.isEmpty {
                            enhancedAlbumsSection
                        } else if viewModel.totalAlbumsCount == 0 {
                            emptyAlbumsView
                        }
                        
                        // Community Section for Artist
                        artistCommunitySection
                        
                        // Friends' Activity Section for Artist
                        artistFriendsActivitySection
                    case .idle:
                        EmptyView()
                    case .loadingMore:
                        EmptyView() // Handled within sections
                    }
                    
                    Spacer(minLength: 100)
                }
                .background(Color(.systemBackground).opacity(0.95)) // Subtle transparency for background effect
            }
            } // Close ZStack
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Close artist profile")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showLogForm = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.purple))
                            .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("Log this artist")
                }
            }
            .onAppear {
                print("🎯 ArtistProfileView: Appeared for artist: \(artistName)")
                Task {
                    // Optimize for device capabilities first
                    viewModel.optimizeForDeviceCapabilities()
                    await viewModel.loadArtistProfile()
                }
            }
            .refreshable {
                Task {
                    await viewModel.refreshData()
                }
            }
        }
        .sheet(isPresented: $showingSortOptions) {
            sortOptionsSheet
        }
        .sheet(isPresented: $showingFilterOptions) {
            filterOptionsSheet
        }
        .fullScreenCover(isPresented: $showLogForm) {
            // Create a MusicSearchResult for the artist to pass to LogMusicFormView
            LogMusicFormView(searchResult: MusicSearchResult(
                id: artistName.lowercased().replacingOccurrences(of: " ", with: "-"),
                title: artistName,
                artistName: artistName,
                albumName: "",
                artworkURL: viewModel.artistData.artworkURL,
                itemType: "artist",
                popularity: 0
            ))
        }
        .fullScreenCover(isPresented: $navigationCoordinator.showingMusicProfile) {
            if let musicItem = navigationCoordinator.selectedMusicItem {
                MusicProfileView(musicItem: musicItem, pinnedLog: nil)
            }
        }
        .fullScreenCover(isPresented: $showingAllSongs) {
            ArtistSongsListView(
                artistName: viewModel.artistName,
                songs: viewModel.artistData.allSongs
            )
            .environmentObject(navigationCoordinator)
        }
        .fullScreenCover(isPresented: $showingAllAlbums) {
            ArtistAlbumsGridView(
                artistName: viewModel.artistName,
                albums: viewModel.artistData.allAlbums
            )
            .environmentObject(navigationCoordinator)
        }
    }
    
    // MARK: - Enhanced Top Songs Section
    private var enhancedTopSongsSection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            // Professional section header with controls
            VStack(spacing: ProfileDesignSystem.Spacing.md) {
                HStack {
                    ProfileSectionHeader(
                title: "Top Songs",
                        subtitle: sortedAndFilteredSongs.isEmpty ? "No songs available" : nil,
                        icon: "music.note"
                    )
                    
                    Spacer()
                    
                    // Sort and Filter controls
                    HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                        // Sort button
                        Button(action: { showingSortOptions = true }) {
                            HStack(spacing: 4) {
                                Text("Sort")
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .fontWeight(.medium)
                            .padding(.horizontal, ProfileDesignSystem.Spacing.md)
                            .padding(.vertical, ProfileDesignSystem.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(ProfileDesignSystem.Colors.surface)
                            )
                            .foregroundColor(ProfileDesignSystem.Colors.primary)
                        }
                        
                        // Filter button
                        Button(action: { showingFilterOptions = true }) {
                            HStack(spacing: 4) {
                                Text("Filter")
                                Image(systemName: "line.3.horizontal.decrease")
                            }
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .fontWeight(.medium)
                            .padding(.horizontal, ProfileDesignSystem.Spacing.md)
                            .padding(.vertical, ProfileDesignSystem.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(ProfileDesignSystem.Colors.surface)
                            )
                            .foregroundColor(ProfileDesignSystem.Colors.primary)
                        }
                    }
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(sortedAndFilteredSongs.prefix(maxDisplayedSongs).enumerated()), id: \.element.id) { index, song in
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
                    .onAppear {
                        // Track visibility for intelligent preloading
                        viewModel.handleSongVisibility(index: index)
                        
                        // Performance monitoring for large lists
                        if index == 0 {
                            AnalyticsService.shared.logPerformanceMetrics(
                                event: "songs_section_appeared",
                                metadata: ["artist": viewModel.artistName, "displayed_count": viewModel.displayedSongs.count]
                            )
                        }
                    }
                }
                
                // Show loading skeletons when loading more
                if viewModel.songsLoadingState == .loadingMore {
                    ForEach(0..<4, id: \.self) { _ in
                        SongRowSkeleton()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                }
            }
            .padding(.horizontal, ProfileDesignSystem.Spacing.sm)
            
            // Pagination buttons
            if !viewModel.displayedSongs.isEmpty {
                paginationButtons
            }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
            .padding(.horizontal)
    }
    
    // MARK: - Pagination Buttons
    private var paginationButtons: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.md) {
            // Load More button
            if maxDisplayedSongs < sortedAndFilteredSongs.count {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        maxDisplayedSongs = min(maxDisplayedSongs + 10, sortedAndFilteredSongs.count)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Load More")
                    }
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(ProfileDesignSystem.Colors.primary)
                    .padding(.horizontal, ProfileDesignSystem.Spacing.lg)
                    .padding(.vertical, ProfileDesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                            .stroke(ProfileDesignSystem.Colors.primary, lineWidth: 1.5)
                    )
                }
            }
            
            // See Less button (show when displaying more than 10)
            if maxDisplayedSongs > 10 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        maxDisplayedSongs = 10
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle")
                        Text("See Less")
                    }
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    .padding(.horizontal, ProfileDesignSystem.Spacing.lg)
                    .padding(.vertical, ProfileDesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                            .stroke(ProfileDesignSystem.Colors.textSecondary, lineWidth: 1)
                    )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, ProfileDesignSystem.Spacing.md)
    }
    
    // MARK: - Sort Options Sheet
    private var sortOptionsSheet: some View {
        NavigationView {
            VStack(spacing: ProfileDesignSystem.Spacing.lg) {
                ForEach(SongSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedSortOption = option
                        showingSortOptions = false
                        // Reset pagination when sort changes
                        maxDisplayedSongs = 10
                    }) {
                        HStack(spacing: ProfileDesignSystem.Spacing.md) {
                            Image(systemName: option.icon)
                                .font(ProfileDesignSystem.Typography.bodyMedium)
                                .foregroundColor(ProfileDesignSystem.Colors.primary)
                                .frame(width: 24)
                            
                            Text(option.rawValue)
                                .font(ProfileDesignSystem.Typography.bodyMedium)
                                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            if selectedSortOption == option {
                                Image(systemName: "checkmark")
                                    .font(ProfileDesignSystem.Typography.bodyMedium)
                                    .foregroundColor(ProfileDesignSystem.Colors.primary)
                            }
                        }
                        .padding(ProfileDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                                .fill(selectedSortOption == option ? ProfileDesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                        )
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sort Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingSortOptions = false
                    }
                }
            }
        }
    }
    
    // MARK: - Filter Options Sheet
    private var filterOptionsSheet: some View {
        NavigationView {
            VStack(spacing: ProfileDesignSystem.Spacing.lg) {
                ForEach(ArtistSongFilterOption.allCases, id: \.self) { option in
                    Button(action: {
                        selectedFilterOption = option
                        showingFilterOptions = false
                        // Reset pagination when filter changes
                        maxDisplayedSongs = 10
                    }) {
                        HStack(spacing: ProfileDesignSystem.Spacing.md) {
                            Image(systemName: option.systemImage)
                                .font(ProfileDesignSystem.Typography.bodyMedium)
                                .foregroundColor(ProfileDesignSystem.Colors.primary)
                                .frame(width: 24)
                            
                            Text(option.rawValue)
                                .font(ProfileDesignSystem.Typography.bodyMedium)
                                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            if selectedFilterOption == option {
                                Image(systemName: "checkmark")
                                    .font(ProfileDesignSystem.Typography.bodyMedium)
                                    .foregroundColor(ProfileDesignSystem.Colors.primary)
                            }
                        }
                        .padding(ProfileDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                                .fill(selectedFilterOption == option ? ProfileDesignSystem.Colors.primary.opacity(0.1) : Color.clear)
                        )
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filter Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilterOptions = false
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Albums Section
    private var enhancedAlbumsSection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            // Professional section header
            ProfileSectionHeader(
                title: "Albums",
                subtitle: viewModel.displayedAlbums.isEmpty ? "No albums available" : nil,
                icon: "opticaldisc"
            )
            
            if viewModel.displayedAlbums.isEmpty {
                emptyAlbumsView
            } else {
            LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: ProfileDesignSystem.Spacing.lg),
                    GridItem(.flexible(), spacing: ProfileDesignSystem.Spacing.lg)
                ], spacing: ProfileDesignSystem.Spacing.lg) {
                ForEach(Array(viewModel.displayedAlbums.enumerated()), id: \.element.id) { index, album in
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
                    .onAppear {
                        // Track visibility for intelligent preloading
                        viewModel.handleAlbumVisibility(index: index)
                        
                        // Performance monitoring for large grids
                        if index == 0 {
                            AnalyticsService.shared.logPerformanceMetrics(
                                event: "albums_section_appeared",
                                metadata: ["artist": viewModel.artistName, "displayed_count": viewModel.displayedAlbums.count]
                            )
                        }
                    }
                }
                
                // Show loading skeletons when loading more albums
                if viewModel.albumsLoadingState == .loadingMore {
                    ForEach(0..<4, id: \.self) { _ in
                        AlbumCardSkeleton()
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                }
            }
            .padding(.horizontal)
        }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
        .padding(.horizontal)
    }
    
    // MARK: - Artist Community Section
    private var artistCommunitySection: some View {
        EnhancedSocialSection(
            comments: [], // TODO: Load artist comments
            userRatings: [:], // TODO: Load user ratings for artist songs
            onLoadMoreComments: {
                // Handle load more comments for artist
                print("Load more artist comments")
            },
            onAddComment: {
                // Handle add comment for artist
                print("Add comment for artist")
            },
            onCommentLike: { comment in
                print("Like artist comment from \(comment.username)")
            },
            onCommentRepost: { comment in
                print("Repost artist comment from \(comment.username)")
            },
            onCommentReply: { comment in
                print("Reply to artist comment from \(comment.username)")
            },
            onCommentThumbsDown: { comment in
                print("Thumbs down artist comment from \(comment.username)")
            }
        )
        .padding(.horizontal)
    }
    
    // MARK: - Artist Friends Activity Section
    private var artistFriendsActivitySection: some View {
        EnhancedFriendsLogsSection(
            itemId: artistName.lowercased().replacingOccurrences(of: " ", with: "-"),
            itemType: "artist",
            itemTitle: artistName
        )
        .padding(.horizontal)
    }
    
    // MARK: - Loading and Empty State Views
    
    private var loadingSkeletonView: some View {
        VStack(spacing: 24) {
            // Section header skeleton for songs
            SectionHeaderSkeleton()
            
            // Song rows skeleton
            VStack(spacing: 12) {
                ForEach(0..<8, id: \.self) { _ in
                    SongRowSkeleton()
                }
            }
            .padding(.horizontal)
            
            // Section header skeleton for albums
            SectionHeaderSkeleton()
            
            // Album cards skeleton
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(0..<8, id: \.self) { _ in
                    AlbumCardSkeleton()
                }
            }
            .padding(.horizontal)
        }
        .transition(.opacity)
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 20) {
            // Error icon with animation
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("Unable to Load Artist")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Retry button with loading state
            Button(action: {
                Task {
                    await viewModel.refreshData()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.top, 60)
        .transition(.scale.combined(with: .opacity))
    }
    
    private var emptyTopSongsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Songs Found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("This artist's songs aren't available in Apple Music or haven't been discovered yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
        .transition(.opacity)
    }
    
    private var emptyAlbumsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "opticaldisc")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Albums Found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("This artist's albums aren't available in Apple Music or haven't been discovered yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 40)
        .transition(.opacity)
    }
    
    // MARK: - Background & Visual Effects
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.purple.opacity(0.02),
                Color.blue.opacity(0.01),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Artist Header Content
    
    private var artistHeaderContent: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.xl) {
            // Artist profile header using design system
            VStack(spacing: ProfileDesignSystem.Spacing.lg) {
                // Artist artwork (circular for artists)
                ProfileArtworkView(
                    artworkURL: viewModel.artistData.artworkURL,
                    size: 140,
                    cornerRadius: 70 // Circular
                )
                
                // Artist info
                VStack(spacing: ProfileDesignSystem.Spacing.sm) {
                Text(artistName)
                        .font(ProfileDesignSystem.Typography.displayMedium)
                    .fontWeight(.bold)
                        .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                        .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                
                    ProfileItemTypeBadge(itemType: "artist")
                }
                
                // Follower stats (primary social metric for artists)
                if true { // TODO: Add actual follower count logic
                    ProfileQuickStat(
                        icon: "person.2.fill",
                        value: "0", // TODO: Replace with actual follower count
                        label: "Followers",
                        color: ProfileDesignSystem.Colors.primary
                    )
                }
            }
            
            // Enhanced action buttons
            enhancedArtistActionButtons
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard(elevation: ProfileDesignSystem.Shadows.large)
        .padding(.horizontal)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }
    
    // MARK: - Artist Rating Section
    private var artistRatingSection: some View {
        DisplayOnlyRatingView(
            userRating: 0, // Artists don't have direct ratings, only through their songs/albums
            averageRating: calculateOverallAverageRating(),
            totalRatings: calculateTotalRatingsForArtist()
        )
        .padding(.horizontal)
    }
    
    // MARK: - Rating Calculation Helpers
    private func calculateOverallAverageRating() -> Double {
        let allSongs = viewModel.displayedSongs
        let allAlbums = viewModel.displayedAlbums
        
        var totalRating = 0.0
        var ratingCount = 0
        
        // Aggregate ratings from songs
        for song in allSongs {
            if song.averageRating > 0 {
                totalRating += song.averageRating * Double(song.totalRatings)
                ratingCount += song.totalRatings
            }
        }
        
        // Aggregate ratings from albums
        for album in allAlbums {
            if album.averageRating > 0 {
                totalRating += album.averageRating * Double(album.totalRatings)
                ratingCount += album.totalRatings
            }
        }
        
        return ratingCount > 0 ? totalRating / Double(ratingCount) : 0.0
    }
    
    private func calculateTotalRatingsForArtist() -> Int {
        let allSongs = viewModel.displayedSongs
        let allAlbums = viewModel.displayedAlbums
        
        let songRatings = allSongs.reduce(0) { $0 + $1.totalRatings }
        let albumRatings = allAlbums.reduce(0) { $0 + $1.totalRatings }
        
        return songRatings + albumRatings
    }
    
    // MARK: - Enhanced Artist Action Buttons
    private var enhancedArtistActionButtons: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.md) {
            // Follow button (primary action)
            Button(action: {
                // TODO: Implement follow functionality
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                print("Follow artist: \(artistName)")
            }) {
                HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    Image(systemName: "person.badge.plus")
                    Text("Follow")
                }
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(ProfileDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                        .fill(ProfileDesignSystem.Colors.primary.gradient)
                )
            }
            
            // Share button (secondary action)
            Button(action: {
                shareArtist()
            }) {
                HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(ProfileDesignSystem.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(ProfileDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                        .stroke(ProfileDesignSystem.Colors.primary, lineWidth: 1.5)
                )
            }
        }
    }
    
    private var artistImageView: some View {
        CachedAsyncArtistImage(
            url: viewModel.artistData.artworkURL,
            width: 120,
            height: 120,
            cornerRadius: 60
        ) {
            AnyView(
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Image(systemName: viewModel.artistData.artworkURL != nil ? "person.fill" : "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.primary.opacity(0.15), radius: 12, x: 0, y: 6)
            )
        }
        .accessibilityLabel("Artist profile picture for \(artistName)")
        .accessibilityHint("Artist's official image")
        .accessibilityAddTraits(.isImage)
    }
    
    private var artistStatsView: some View {
        HStack {
            StatisticView(
                value: "0", // TODO: Implement actual follower count
                label: "Followers",
                isLoading: false
            )
        }
        .padding(.vertical, 20)
    }
    
    private var artistActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                // Follow artist - TODO: Implement
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                    Text("Follow")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Follow \(artistName)")
            .accessibilityHint("Double tap to follow this artist and see their updates")
            .accessibilityAddTraits(.isButton)
            
            Button(action: {
                shareArtist()
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.purple)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.purple.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Share \(artistName)")
            .accessibilityHint("Double tap to share this artist with others")
            .accessibilityAddTraits(.isButton)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Artist actions")
    }
    
    // MARK: - Helper Methods
    
    private func calculateAverageRating(_ items: [ArtistCatalogItem]) -> Double {
        let ratedItems = items.filter { $0.averageRating > 0 }
        guard !ratedItems.isEmpty else { return 0 }
        
        let totalRating = ratedItems.reduce(0) { $0 + $1.averageRating }
        return totalRating / Double(ratedItems.count)
    }
    
    private func calculateTotalRatings(_ items: [ArtistCatalogItem]) -> Int {
        return items.reduce(0) { $0 + $1.totalRatings }
    }
    
    private func calculateTotalLogs(_ items: [ArtistCatalogItem]) -> Int {
        return items.reduce(0) { $0 + $1.totalLogs }
    }
    
    // MARK: - Listen Later Integration
    private func addArtistToListenLater() {
        guard !isAddingToListenLater else { return }
        
        isAddingToListenLater = true
        
        Task {
            // Create MusicSearchResult for the artist
            let artistSearchResult = MusicSearchResult(
                id: artistName.replacingOccurrences(of: " ", with: "_").lowercased(),
                title: artistName,
                artistName: artistName,
                albumName: "",
                artworkURL: viewModel.artistData.artworkURL,
                itemType: "artist",
                popularity: 0
            )
            
            // Add to Listen Later using the service
            let success = await ListenLaterService.shared.addItem(artistSearchResult, type: .artist)
            
            await MainActor.run {
                isAddingToListenLater = false
                if success {
                    listenLaterSuccess = true
                    // Show success feedback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        listenLaterSuccess = false
                    }
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Trigger service refresh to update UI immediately
                    ListenLaterService.shared.refreshAllSections()
                }
            }
            
            print("✅ Artist '\(artistName)' added to Listen Later: \(success)")
        }
    }
    
    private func shareArtist() {
        guard let shareURL = viewModel.generateShareableLink(section: .profile) else {
            print("⚠️ Failed to generate shareable link for artist")
            return
        }
        
        let shareText = "Check out \(viewModel.artistName) on Bumpin! 🎵"
        let activityViewController = UIActivityViewController(
            activityItems: [shareText, shareURL],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Handle iPad presentation
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
        
        // Track sharing
        AnalyticsService.shared.logShare(
            contentType: "artist_profile",
            contentId: viewModel.artistName,
            method: "native_share_sheet"
        )
    }
    
    // MARK: - Legacy Components (to be removed)
    
    // NOTE: Legacy properties for compatibility during transition
    @State private var isLoadingCatalog = false
    @State private var artistArtwork: String?
    @State private var topSongs: [MusicSearchResult] = []
    @State private var albums: [MusicSearchResult] = []
    @State private var songRatings: [String: (averageRating: Double, totalRatings: Int)] = [:]
    @State private var albumRatings: [String: (averageRating: Double, totalRatings: Int)] = [:]
    
    // NOTE: These components are kept for compatibility during transition
    private func loadArtistCatalog() async {
        do {
            // Search for the artist first to get their catalog
            var request = MusicCatalogSearchRequest(term: artistName, types: [MusicKit.Artist.self])
            request.limit = 1
            
            let response = try await request.response()
            
            guard let artist = response.artists.first else {
                await MainActor.run {
                    self.isLoadingCatalog = false
                }
                return
            }
            
            // Get artist artwork
            await MainActor.run {
                self.artistArtwork = artist.artwork?.url(width: 300, height: 300)?.absoluteString
            }
            
            // Load top songs
            await loadTopSongs(for: artist)
            
            // Load albums
            await loadAlbums(for: artist)
            
            await MainActor.run {
                self.isLoadingCatalog = false
            }
            
        } catch {
            print("Error loading artist catalog: \(error)")
            await MainActor.run {
                self.isLoadingCatalog = false
            }
        }
    }
    
    private func loadTopSongs(for artist: MusicKit.Artist) async {
        do {
            // Search for songs by this artist using search API
            var songsSearchRequest = MusicCatalogSearchRequest(term: "\(artist.name) songs", types: [MusicKit.Song.self])
            songsSearchRequest.limit = 20
            
            let songsResponse = try await songsSearchRequest.response()
            
            // Filter to only songs by this exact artist
            let artistSongs = songsResponse.songs.filter { song in
                song.artistName.lowercased() == artist.name.lowercased()
            }
            
            let musicSearchResults = artistSongs.prefix(10).map { song in
                MusicSearchResult(
                    id: song.id.rawValue,
                    title: song.title,
                    artistName: song.artistName,
                    albumName: song.albumTitle ?? "",
                    artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: "song",
                    popularity: 0
                )
            }
            
            await MainActor.run {
                self.topSongs = Array(musicSearchResults)
            }
            
            // Load ratings for these songs
            await loadRatingsForSongs(Array(musicSearchResults))
            
        } catch {
            print("Error loading top songs: \(error)")
        }
    }
    
    private func loadAlbums(for artist: MusicKit.Artist) async {
        do {
            // Search for albums by this artist using search API
            var albumsSearchRequest = MusicCatalogSearchRequest(term: "\(artist.name) albums", types: [MusicKit.Album.self])
            albumsSearchRequest.limit = 20
            
            let albumsResponse = try await albumsSearchRequest.response()
            
            // Filter to only albums by this exact artist and exclude singles
            let filteredAlbums = albumsResponse.albums.compactMap { album -> MusicSearchResult? in
                // Check if album is by the correct artist
                guard album.artistName.lowercased() == artist.name.lowercased() else { return nil }
                
                let title = album.title.lowercased()
                if title.contains("single") || title.contains("ep") { return nil }
                
                return MusicSearchResult(
                    id: album.id.rawValue,
                    title: album.title,
                    artistName: album.artistName,
                    albumName: album.title,
                    artworkURL: album.artwork?.url(width: 300, height: 300)?.absoluteString,
                    itemType: "album",
                    popularity: 0
                )
            }
            
            await MainActor.run {
                self.albums = Array(filteredAlbums.prefix(12))
            }
            
            // Load ratings for these albums
            await loadRatingsForAlbums(Array(filteredAlbums.prefix(12)))
            
        } catch {
            print("Error loading albums: \(error)")
        }
    }
    
    private func loadRatingsForSongs(_ songs: [MusicSearchResult]) async {
        let db = Firestore.firestore()
        
        for song in songs {
            do {
                let snapshot = try await db.collection("logs")
                    .whereField("itemId", isEqualTo: song.id)
                    .whereField("itemType", isEqualTo: "song")
                    .getDocuments()
                
                let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                let ratings = logs.compactMap { $0.rating }
                
                if !ratings.isEmpty {
                    let averageRating = Double(ratings.reduce(0, +)) / Double(ratings.count)
                    
                    await MainActor.run {
                        self.songRatings[song.id] = (averageRating: averageRating, totalRatings: ratings.count)
                    }
                }
            } catch {
                print("Error loading ratings for song \(song.title): \(error)")
            }
        }
    }
    
    private func loadRatingsForAlbums(_ albums: [MusicSearchResult]) async {
        let db = Firestore.firestore()
        
        for album in albums {
            do {
                let snapshot = try await db.collection("logs")
                    .whereField("itemId", isEqualTo: album.id)
                    .whereField("itemType", isEqualTo: "album")
                    .getDocuments()
                
                let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                let ratings = logs.compactMap { $0.rating }
                
                if !ratings.isEmpty {
                    let averageRating = Double(ratings.reduce(0, +)) / Double(ratings.count)
                    
                    await MainActor.run {
                        self.albumRatings[album.id] = (averageRating: averageRating, totalRatings: ratings.count)
                    }
                }
            } catch {
                print("Error loading ratings for album \(album.title): \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct SongRowView: View {
    let song: MusicSearchResult
    let index: Int
    let rating: (averageRating: Double, totalRatings: Int)?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Track number
                Text("\(index)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                // Album artwork
                if let artworkURL = song.artworkURL, let url = URL(string: artworkURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundColor(.gray)
                        )
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !song.albumName.isEmpty {
                        Text(song.albumName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Rating display
                if let rating = rating {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating.averageRating))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Text("(\(rating.totalRatings))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No ratings")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AlbumCardView: View {
    let album: MusicSearchResult
    let rating: (averageRating: Double, totalRatings: Int)?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Album artwork
                if let artworkURL = album.artworkURL, let url = URL(string: artworkURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    }
                    .frame(height: 120)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                }
                
                // Album info
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Rating display
                    if let rating = rating {
                        HStack(spacing: 4) {
                            HStack(spacing: 1) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating.averageRating))
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            Text("(\(rating.totalRatings))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No ratings yet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced UI Components

struct EnhancedSongRowView: View {
    let song: ArtistCatalogItem
    let index: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var showingPopularityDetails = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback for better UX
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 12) {
                trackNumberSection
                artworkSection
                songInfoSection
                Spacer(minLength: 8)
                ratingSection
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(songRowBackground)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel("\(song.title) by \(song.artistName)")
        .accessibilityValue(song.averageRating > 0 ? "Rated \(String(format: "%.1f", song.averageRating)) out of 5 stars" : "Not rated")
        .accessibilityHint("Double tap to view song details and ratings")
        .accessibilityAddTraits(.isButton)
        .focusable(true) // Keyboard navigation support
    }
    
    // MARK: - Subviews
    
    private var trackNumberSection: some View {
        ZStack {
            // Background circle for track number
            Circle()
                .fill(popularityBackgroundColor)
                .frame(width: 32, height: 32)
            
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(popularityTextColor)
            
            // Animated popularity indicators
            if song.popularityScore > 0.8 {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .offset(x: 16, y: -10)
                    .scaleEffect(showingPopularityDetails ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: showingPopularityDetails)
            } else if song.popularityScore > 0.6 {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .offset(x: 16, y: -10)
                    .scaleEffect(showingPopularityDetails ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: showingPopularityDetails)
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showingPopularityDetails.toggle()
            }
        }
    }
    
    private var artworkSection: some View {
        AsyncImage(url: URL(string: song.artworkURL ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            case .failure(_):
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    )
            case .empty:
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    )
            @unknown default:
                EmptyView()
            }
        }
    }
    
    private var songInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Song title with more space (removed duration badge from same line)
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                .lineLimit(2) // Allow 2 lines for longer titles
                .multilineTextAlignment(.leading)
            
            // Album name with better styling
            if let albumName = song.albumName, !albumName.isEmpty {
                Text(albumName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Enhanced metadata row (removed timestamp/release year)
            HStack(spacing: 8) {
                // Duration badge (moved to metadata row)
                if let duration = song.duration {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                // Engagement indicator
                if song.totalLogs > 0 {
                    EngagementBadge(count: song.totalLogs, type: .logs)
                }
                
                Spacer()
            }
        }
    }
    
    private var ratingSection: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if song.averageRating > 0 {
                // Enhanced star rating
                RatingStarsView(
                    rating: song.averageRating,
                    starSize: 10,
                    spacing: 1,
                    animated: showingPopularityDetails
                )
                
                // Numeric rating with count
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", song.averageRating))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("(\(song.totalRatings))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Popularity score indicator
                if showingPopularityDetails {
                    HStack(spacing: 2) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption2)
                        Text(String(format: "%.0f%%", song.popularityScore * 100))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.purple)
                    .transition(.scale.combined(with: .opacity))
                }
                
            } else {
                VStack(spacing: 4) {
                    Text("Not rated")
                        .font(.caption2)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                    
                    if song.totalLogs > 0 {
                        Text("\(song.totalLogs) logs")
                            .font(.caption2)
                            .foregroundColor(.purple.opacity(0.6))
                    }
                }
            }
        }
    }
    
    private var songRowBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundColor)
            .shadow(color: shadowColor, radius: isPressed ? 2 : 6, x: 0, y: isPressed ? 1 : 3)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
    
    // MARK: - Computed Properties
    
    private var popularityBackgroundColor: Color {
        if song.popularityScore > 0.8 {
            return Color.orange.opacity(0.2)
        } else if song.popularityScore > 0.6 {
            return Color.green.opacity(0.2)
        } else if song.popularityScore > 0.3 {
            return Color.blue.opacity(0.2)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var popularityTextColor: Color {
        if song.popularityScore > 0.8 {
            return .orange
        } else if song.popularityScore > 0.6 {
            return .green
        } else if song.popularityScore > 0.3 {
            return .blue
        } else {
            return .secondary
        }
    }
    
    private var backgroundColor: Color {
        Color(.systemBackground)
    }
    
    private var shadowColor: Color {
        Color.primary.opacity(0.08) // Adapts to light/dark mode
    }
    
    private var borderColor: Color {
        Color.primary.opacity(0.1) // Better contrast in dark mode
    }
    
    private var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct EnhancedAlbumCardView: View {
    let album: ArtistCatalogItem
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Fixed aspect ratio artwork
                albumArtworkSection
                    .aspectRatio(1, contentMode: .fit)
                
                albumInfoSection
                    .frame(height: 60) // Fixed height for consistent card sizes
            }
            .frame(maxWidth: .infinity) // Ensure full width usage
            .padding(.vertical, 8)
            .background(albumCardBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showingDetails.toggle()
            }
        }
        .accessibilityLabel("\(album.title) album")
        .accessibilityValue(album.averageRating > 0 ? "Rated \(String(format: "%.1f", album.averageRating)) out of 5 stars" : "Not rated")
        .accessibilityHint("Double tap to view album details. Triple tap to show more information")
        .accessibilityAddTraits(.isButton)
        .focusable(true) // Keyboard navigation support
    }
    
    // MARK: - Subviews
    
    private var albumArtworkSection: some View {
        ZStack {
            // Main artwork
            AsyncImage(url: URL(string: album.artworkURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: shadowColorForAlbum, radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                case .failure(_):
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: gradientColorsForAlbum,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "opticaldisc")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Album")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        )
                        .shadow(color: shadowColorForAlbum, radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
                case .empty:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            // Popularity indicator overlay
            if album.popularityScore > 0.7 {
                VStack {
                    HStack {
                        Spacer()
                        popularityBadge
                    }
                    Spacer()
                }
                .padding(12)
            }
            
            // Rating overlay with glassmorphism effect
            if album.averageRating > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ratingOverlay
                    }
                }
                .padding(12)
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    private var albumInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Album title with consistent single line
            Text(album.title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            // Metadata row with icons and better spacing
            HStack(spacing: 8) {
                // Release year with icon
                if let releaseDate = album.releaseDate {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(yearFormatter.string(from: releaseDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Track count with icon
                if let trackCount = album.trackCount {
                    HStack(spacing: 3) {
                        Image(systemName: "music.note.list")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(trackCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Rating and engagement row
            HStack {
                if album.averageRating > 0 {
                    HStack(spacing: 4) {
                        // Compact star display
                        RatingStarsView(
                            rating: album.averageRating,
                            starSize: 8,
                            spacing: 1,
                            animated: false
                        )
                        
                        Text("(\(album.totalRatings))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Not rated")
                        .font(.caption2)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                
                Spacer()
                
                // Engagement indicator
                if album.totalLogs > 0 {
                    EngagementBadge(count: album.totalLogs, type: .logs)
                }
            }
            
            // Expandable details
            if showingDetails {
                expandableDetailsSection
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var expandableDetailsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.vertical, 2)
            
            if album.popularityScore > 0 {
                HStack {
                    Text("Popularity:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(album.popularityScore * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    Spacer()
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
    }
    
    private var albumCardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: isPressed ? 2 : 6, x: 0, y: isPressed ? 1 : 3)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }
    
    // MARK: - Subviews
    
    private var popularityBadge: some View {
        Group {
            if album.popularityScore > 0.9 {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            } else if album.popularityScore > 0.8 {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            } else if album.popularityScore > 0.7 {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }
    
    private var ratingOverlay: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundColor(.yellow)
            Text(String(format: "%.1f", album.averageRating))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var gradientColorsForAlbum: [Color] {
        // Generate colors based on album title hash for consistency
        let hash = album.title.hashValue
        let colorIndex = abs(hash) % 5
        
        switch colorIndex {
        case 0:
            return [Color.purple.opacity(0.7), Color.blue.opacity(0.7)]
        case 1:
            return [Color.blue.opacity(0.7), Color.teal.opacity(0.7)]
        case 2:
            return [Color.teal.opacity(0.7), Color.green.opacity(0.7)]
        case 3:
            return [Color.orange.opacity(0.7), Color.red.opacity(0.7)]
        default:
            return [Color.pink.opacity(0.7), Color.purple.opacity(0.7)]
        }
    }
    
    private var shadowColorForAlbum: Color {
        if album.popularityScore > 0.8 {
            return Color.orange.opacity(0.3)
        } else if album.popularityScore > 0.6 {
            return Color.purple.opacity(0.2)
        } else {
            return Color.primary.opacity(0.1) // Better for dark mode
        }
    }
    
    private var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }
}

// MARK: - Supporting Components

struct AdvancedSectionHeader: View {
    let title: String
    let icon: String
    let totalCount: Int
    let displayedCount: Int
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let showAllState: Bool
    let onLoadMore: () -> Void
    let onSeeAll: () -> Void
    let onToggleFilter: () -> Void
    
    @State private var isPressed = false
    @State private var showingFilterOptions = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Main header row
            HStack(spacing: 12) {
                // Title section with icon
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            // Loading indicator for section
                            if isLoadingMore {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            }
                        }
                        
                        Text(progressText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Filter button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingFilterOptions.toggle()
                    }
                    onToggleFilter()
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.purple)
                        .scaleEffect(showingFilterOptions ? 1.1 : 1.0)
                        .rotationEffect(.degrees(showingFilterOptions ? 180 : 0))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Filter options")
                .accessibilityValue(showingFilterOptions ? "Expanded" : "Collapsed")
                .accessibilityHint("Double tap to \(showingFilterOptions ? "hide" : "show") filter options")
                
                // Navigation button
                navigationButton
            }
            .padding(.horizontal, 20)
            
            // Progress indicator
            if totalCount > 0 {
                progressIndicator
                    .padding(.horizontal, 20)
            }
            
            // Filter options (expandable)
            if showingFilterOptions {
                filterOptionsView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top))
                    ))
                    .padding(.horizontal, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.primary.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) section")
        .accessibilityValue("Showing \(displayedCount) of \(totalCount) items")
        .accessibilityHint("Contains navigation and filter options for \(title.lowercased())")
    }
    
    // MARK: - Subviews
    
    private var navigationButton: some View {
        Group {
            if canLoadMore && !showAllState {
                Button(action: onLoadMore) {
                    HStack(spacing: 6) {
                        if isLoadingMore {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Load More")
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: isLoadingMore ? [Color.gray, Color.gray] : [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(isLoadingMore)
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(isLoadingMore ? "Loading more content" : "Load more items")
                .accessibilityHint("Double tap to load additional \(title.lowercased())")
                .accessibilityValue(isLoadingMore ? "Loading" : "Available")
                
            } else if totalCount > displayedCount {
                Button(action: onSeeAll) {
                    HStack(spacing: 6) {
                        Text("See All")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("See all \(title.lowercased())")
                .accessibilityHint("Opens full-screen view with all \(totalCount) items")
                .accessibilityValue("Available")
            }
        }
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * progressPercentage, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progressPercentage)
                }
            }
            .frame(height: 6)
            
            // Progress text with accessibility
            HStack {
                Text("Showing \(displayedCount) of \(totalCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Showing \(displayedCount) out of \(totalCount) items")
                
                Spacer()
                
                Text("\(Int(progressPercentage * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                    .accessibilityLabel("\(Int(progressPercentage * 100)) percent loaded")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Progress: \(displayedCount) of \(totalCount) items shown, \(Int(progressPercentage * 100)) percent complete")
        }
    }
    
    private var filterOptionsView: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack {
                Text("Sort & Filter")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            // Filter options will be implemented in future steps
            HStack(spacing: 12) {
                ArtistFilterChip(title: "All Time", isSelected: true, onTap: {})
                ArtistFilterChip(title: "Recent", isSelected: false, onTap: {})
                ArtistFilterChip(title: "Popular", isSelected: false, onTap: {})
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Computed Properties
    
    private var progressText: String {
        if displayedCount == totalCount {
            return "All \(totalCount) items"
        } else {
            return "\(displayedCount) of \(totalCount)"
        }
    }
    
    private var progressPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(displayedCount) / Double(totalCount)
    }
}

struct ArtistFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .purple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.purple : Color.purple.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.purple.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 0.1), 
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && !reduceMotion {
                    // Subtle haptic feedback for button presses
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
    }
}

struct ShimmerLoadingView: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cornerRadius: CGFloat
    let height: CGFloat?
    
    init(cornerRadius: CGFloat = 12, height: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.05),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                // Only show shimmer animation if motion isn't reduced
                Group {
                    if !reduceMotion {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.6),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: isAnimating ? 300 : -300)
                    }
                }
            )
            .frame(height: height)
            .clipped()
            .onAppear {
                if !reduceMotion {
                    withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
            }
            .accessibilityLabel("Loading content")
            .accessibilityValue("Please wait")
    }
}

struct ArtistHeaderSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Artist image skeleton
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay(
                    ShimmerLoadingView(cornerRadius: 60, height: 120)
                        .clipShape(Circle())
                )
            
            // Artist name skeleton
            VStack(spacing: 8) {
                ShimmerLoadingView(cornerRadius: 8, height: 24)
                    .frame(width: 150)
                
                ShimmerLoadingView(cornerRadius: 6, height: 16)
                    .frame(width: 60)
            }
            
            // Stats skeleton
            HStack(spacing: 40) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 4) {
                        ShimmerLoadingView(cornerRadius: 6, height: 20)
                            .frame(width: 30)
                        ShimmerLoadingView(cornerRadius: 4, height: 12)
                            .frame(width: 50)
                    }
                }
            }
            .padding(.vertical, 20)
            
            // Action buttons skeleton
            HStack(spacing: 12) {
                ShimmerLoadingView(cornerRadius: 20, height: 32)
                    .frame(width: 80)
                ShimmerLoadingView(cornerRadius: 20, height: 32)
                    .frame(width: 100)
            }
        }
        .padding(.top, 20)
    }
}

struct SongRowSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            // Track number skeleton
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    ShimmerLoadingView(cornerRadius: 16, height: 32)
                        .clipShape(Circle())
                )
            
            // Artwork skeleton
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay(
                    ShimmerLoadingView(cornerRadius: 12, height: 56)
                )
            
            // Song info skeleton
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    ShimmerLoadingView(cornerRadius: 6, height: 16)
                        .frame(width: 120)
                    Spacer()
                    ShimmerLoadingView(cornerRadius: 12, height: 14)
                        .frame(width: 40)
                }
                
                ShimmerLoadingView(cornerRadius: 4, height: 12)
                    .frame(width: 90)
                
                HStack(spacing: 8) {
                    ShimmerLoadingView(cornerRadius: 4, height: 10)
                        .frame(width: 30)
                    ShimmerLoadingView(cornerRadius: 8, height: 12)
                        .frame(width: 50)
                    Spacer()
                }
            }
            
            Spacer()
            
            // Rating skeleton
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
                
                ShimmerLoadingView(cornerRadius: 4, height: 12)
                    .frame(width: 40)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

struct AlbumCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Album artwork skeleton
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    ShimmerLoadingView(cornerRadius: 16)
                )
            
            // Album info skeleton
            VStack(alignment: .leading, spacing: 6) {
                ShimmerLoadingView(cornerRadius: 6, height: 16)
                    .frame(maxWidth: .infinity)
                
                HStack(spacing: 8) {
                    ShimmerLoadingView(cornerRadius: 4, height: 12)
                        .frame(width: 40)
                    ShimmerLoadingView(cornerRadius: 4, height: 12)
                        .frame(width: 30)
                    Spacer()
                }
                
                HStack {
                    HStack(spacing: 1) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Spacer()
                    ShimmerLoadingView(cornerRadius: 6, height: 10)
                        .frame(width: 30)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

struct SectionHeaderSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            ShimmerLoadingView(cornerRadius: 16, height: 32)
                                .clipShape(Circle())
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        ShimmerLoadingView(cornerRadius: 6, height: 18)
                            .frame(width: 100)
                        ShimmerLoadingView(cornerRadius: 4, height: 12)
                            .frame(width: 80)
                    }
                }
                
                Spacer()
                
                ShimmerLoadingView(cornerRadius: 16, height: 32)
                    .frame(width: 90)
            }
            .padding(.horizontal, 20)
            
            // Progress bar skeleton
            VStack(spacing: 8) {
                ShimmerLoadingView(cornerRadius: 4, height: 6)
                
                HStack {
                    ShimmerLoadingView(cornerRadius: 4, height: 10)
                        .frame(width: 80)
                    Spacer()
                    ShimmerLoadingView(cornerRadius: 4, height: 10)
                        .frame(width: 30)
                }
            }
            .padding(.horizontal, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 16)
    }
}

struct PopularityIndicator: View {
    let score: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: score)
                .stroke(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            popularityIcon
                .font(.system(size: size * 0.4))
                .foregroundColor(iconColor)
        }
        .frame(width: size, height: size)
    }
    
    private var gradientColors: [Color] {
        if score > 0.8 {
            return [.orange, .red]
        } else if score > 0.6 {
            return [.green, .teal]
        } else if score > 0.3 {
            return [.blue, .purple]
        } else {
            return [.gray, .gray]
        }
    }
    
    private var iconColor: Color {
        if score > 0.8 {
            return .orange
        } else if score > 0.6 {
            return .green
        } else if score > 0.3 {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var popularityIcon: Image {
        if score > 0.9 {
            return Image(systemName: "crown.fill")
        } else if score > 0.8 {
            return Image(systemName: "flame.fill")
        } else if score > 0.6 {
            return Image(systemName: "arrow.up.right")
        } else if score > 0.3 {
            return Image(systemName: "chart.line.uptrend.xyaxis")
        } else {
            return Image(systemName: "minus")
        }
    }
}

struct RatingStarsView: View {
    let rating: Double
    let maxRating: Int = 5
    let starSize: CGFloat
    let spacing: CGFloat
    let animated: Bool
    
    @State private var animatedRating: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(rating: Double, starSize: CGFloat = 12, spacing: CGFloat = 2, animated: Bool = false) {
        self.rating = rating
        self.starSize = starSize
        self.spacing = spacing
        self.animated = animated
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: starImage(for: star))
                    .font(.system(size: starSize))
                    .foregroundColor(starColor(for: star))
                    .scaleEffect(animated && Double(star) <= animatedRating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.2).delay(Double(star) * 0.1),
                        value: animatedRating
                    )
            }
        }
        .onAppear {
            if animated && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.5)) {
                    animatedRating = rating
                }
            } else {
                animatedRating = rating
            }
        }
        .onChange(of: rating) { _, newRating in
            if animated && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.3)) {
                    animatedRating = newRating
                }
            } else {
                animatedRating = newRating
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(String(format: "%.1f", rating)) out of \(maxRating) stars")
        .accessibilityValue("\(String(format: "%.1f", rating)) stars")
    }
    
    private func starImage(for position: Int) -> String {
        let currentRating = animated ? animatedRating : rating
        if currentRating >= Double(position) {
            return "star.fill"
        } else if currentRating >= Double(position) - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
    
    private func starColor(for position: Int) -> Color {
        let currentRating = animated ? animatedRating : rating
        if currentRating >= Double(position) - 0.5 {
            return .yellow
        } else {
            return .gray.opacity(0.4)
        }
    }
}

struct EngagementBadge: View {
    let count: Int
    let type: EngagementType
    
    enum EngagementType {
        case logs, ratings, plays
        
        var icon: String {
            switch self {
            case .logs: return "person.2.fill"
            case .ratings: return "star.fill"
            case .plays: return "play.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .logs: return .purple
            case .ratings: return .yellow
            case .plays: return .green
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: type.icon)
                .font(.caption2)
            Text(formattedCount)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(type.color.opacity(0.8))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(type.color.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var formattedCount: String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }
}

struct SectionStatsView: View {
    let totalItems: Int
    let averageRating: Double
    let totalRatings: Int
    let totalLogs: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Total items
            ArtistStatItem(
                value: "\(totalItems)",
                label: "Items",
                icon: "number.circle",
                color: .blue
            )
            
            // Average rating
            if averageRating > 0 {
                ArtistStatItem(
                    value: String(format: "%.1f", averageRating),
                    label: "Avg Rating",
                    icon: "star.circle",
                    color: .yellow
                )
            }
            
            // Total ratings
            if totalRatings > 0 {
                ArtistStatItem(
                    value: formatLargeNumber(totalRatings),
                    label: "Ratings",
                    icon: "person.circle",
                    color: .green
                )
            }
            
            // Total logs
            if totalLogs > 0 {
                ArtistStatItem(
                    value: formatLargeNumber(totalLogs),
                    label: "Logs",
                    icon: "book.circle",
                    color: .purple
                )
            }
            
            Spacer()
        }
    }
    
    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000.0)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        } else {
            return "\(number)"
        }
    }
}

struct ArtistStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatisticView: View {
    let value: String
    let label: String
    let isLoading: Bool
    
    @State private var animatedValue: String = "0"
    
    var body: some View {
        VStack(spacing: 4) {
            if isLoading {
                ShimmerLoadingView(cornerRadius: 6, height: 20)
                    .frame(width: 30)
            } else {
                Text(animatedValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
            }
            
            if isLoading {
                ShimmerLoadingView(cornerRadius: 4, height: 12)
                    .frame(width: 50)
            } else {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if !isLoading {
                withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                    animatedValue = value
                }
            }
        }
        .onChange(of: value) { _, newValue in
            if !isLoading {
                withAnimation(.easeInOut(duration: 0.5)) {
                    animatedValue = newValue
                }
            }
        }
        .onChange(of: isLoading) { _, loading in
            if !loading {
                withAnimation(.easeInOut(duration: 0.5)) {
                    animatedValue = value
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
        .accessibilityValue(isLoading ? "Loading" : "Loaded")
    }
}

#Preview {
    ArtistProfileView(artistName: "Travis Scott")
        .environmentObject(NavigationCoordinator())
}
