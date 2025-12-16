import SwiftUI
import FirebaseAuth
import MusicKit
import Firebase
import FirebaseFirestore

// MARK: - Music Search Result Model
struct MusicSearchResult: Identifiable, Codable {
    let id: String
    let title: String
    let artistName: String
    let albumName: String
    let artworkURL: String?
    let itemType: String // "song", "artist", "album"
    let popularity: Int
    // Phase 2: Apple Music genre data
    let genreNames: [String]? // Artist genres from Apple Music
    let primaryGenre: String? // Primary genre classification
    // Phase 4: Cross-platform tracking
    let platform: String? // "apple_music" or "spotify"
    
    // Legacy initializer for backward compatibility
    init(id: String, title: String, artistName: String, albumName: String, artworkURL: String?, itemType: String, popularity: Int) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURL = artworkURL
        self.itemType = itemType
        self.popularity = popularity
        self.genreNames = nil
        self.primaryGenre = nil
        self.platform = nil
    }
    
    // Enhanced initializer with genre data
    init(id: String, title: String, artistName: String, albumName: String, artworkURL: String?, itemType: String, popularity: Int, genreNames: [String]?, primaryGenre: String?) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURL = artworkURL
        self.itemType = itemType
        self.popularity = popularity
        self.genreNames = genreNames
        self.primaryGenre = primaryGenre
        self.platform = nil
    }
    
    // Full initializer with platform tracking
    init(id: String, title: String, artistName: String, albumName: String, artworkURL: String?, itemType: String, popularity: Int, genreNames: [String]?, primaryGenre: String?, platform: String?) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURL = artworkURL
        self.itemType = itemType
        self.popularity = popularity
        self.genreNames = genreNames
        self.primaryGenre = primaryGenre
        self.platform = platform
    }
}

struct LogMusicView: View {
    @State private var searchText = ""
    @State private var selectedFilter: LogSearchFilter = .all
    @State private var searchResults: LogSearchResults = LogSearchResults()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedMusicResult: MusicSearchResult?
    @State private var showLogForm = false
    // @StateObject private var appleMusicManager = AppleMusicManager()
    
    // Paging state for Apple Music results
    @State private var musicOffset = 0
    @State private var hasMoreSongs = true
    @State private var isPaging = false
    // Performance optimization
    @State private var searchTask: Task<Void, Never>?
    @State private var debounceTimer: Timer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Filter Buttons
                filterButtons
                
                // Search Results
                searchResultsView
            }
            .navigationTitle("Search Music")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        // Handle close action
                    }
                    .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showLogForm) {
                if let result = selectedMusicResult {
                    LogMusicFormView(searchResult: result)
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search \(selectedFilter.rawValue.lowercased())...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { _, newValue in
                        // Cancel previous search
                        searchTask?.cancel()
                        debounceTimer?.invalidate()
                        
                        // Debounce search to avoid too many requests
                        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                            if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                searchTask = Task {
                                    await performSearch()
                                }
                            } else {
                                searchResults = LogSearchResults()
                                isLoading = false
                            }
                        }
                    }
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Filter Buttons
    private var filterButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LogSearchFilter.allCases, id: \.self) { filter in
                    LogFilterButton(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        action: {
                            selectedFilter = filter
                            if !searchText.isEmpty {
                                Task {
                                    await performSearch()
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Search Results
    private var searchResultsView: some View {
        ZStack {
            // Main content stays in place
            Group {
                if searchResults.filteredResults(for: selectedFilter).isEmpty && !searchText.isEmpty {
                    emptyStateView
                } else if searchText.isEmpty {
                    recentSearchesView
                } else {
                    resultsListView
                }
            }
            
            // Loading overlay appears on top without hiding content
            if isLoading {
                searchingOverlay
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Inline Searching Overlay (keeps header and filters visible)
    private var searchingOverlay: some View {
        ZStack {
            // Subtle dim without blocking layout
            Color.clear
            HStack(spacing: 10) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Searching...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No results found")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Recent Searches View
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Searches")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(LogSearchFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        searchText = "Search \(filter.rawValue.lowercased())"
                        Task {
                            await performSearch()
                        }
                    }) {
                        HStack {
                            Image(systemName: filter.icon)
                                .foregroundColor(filter.color)
                                .frame(width: 20)
                            Text("Search \(filter.rawValue.lowercased())")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Results List View
    private var resultsListView: some View {
        List {
            ForEach(searchResults.filteredResults(for: selectedFilter)) { item in
                LogSearchResultRow(item: item) {
                    handleResultTap(item)
                }
            }
            if (selectedFilter == .songs || selectedFilter == .all) && hasMoreSongs {
                HStack {
                    Spacer()
                    if isPaging {
                        ProgressView()
                            .padding()
                    } else {
                        Button(action: {
                            loadMoreSongs()
                        }) {
                            Text("Load More")
                                .foregroundColor(.blue)
                        }
                    }
                    Spacer()
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Search Functions
    private func performSearch() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            musicOffset = 0
            hasMoreSongs = true
        }
        
        let (songs, artists, albums) = await searchMusicAsync()
        let lists = await searchListsAsync()
        let users = await searchUsersAsync()
        
        await MainActor.run {
            searchResults = LogSearchResults(
                songs: songs,
                artists: artists,
                albums: albums,
                lists: lists,
                users: users
            )
            isLoading = false
        }
    }
    
    private func searchMusicAsync(offset: Int = 0) async -> ([MusicSearchResult], [MusicSearchResult], [MusicSearchResult]) {
        // Use unified search service for cross-platform results
        let unifiedResults = await UnifiedMusicSearchService.shared.search(query: searchText, limit: 25)
        
        // Update hasMoreSongs flag based on results
        if unifiedResults.songs.count < 25 { hasMoreSongs = false }
        
        print("🔍 Unified search results: \(unifiedResults.songs.count) songs, \(unifiedResults.artists.count) artists, \(unifiedResults.albums.count) albums")
        
        return (unifiedResults.songs, unifiedResults.artists, unifiedResults.albums)
    }
    
    // MARK: - Load More Paging
    private func loadMoreSongs() {
        guard hasMoreSongs, !isPaging else { return }
        isPaging = true
        Task {
            let nextOffset = musicOffset + 25
            let more = await searchMusicAsync(offset: nextOffset)
            await MainActor.run {
                musicOffset = nextOffset
                // Append new songs avoiding duplicates
                let existingIds = Set(searchResults.songs.map { $0.id })
                searchResults.songs.append(contentsOf: more.0.filter { !existingIds.contains($0.id) })
                // Also append artists/albums when using All filter
                if selectedFilter == .all {
                    let existingArtistIds = Set(searchResults.artists.map { $0.id })
                    searchResults.artists.append(contentsOf: more.1.filter { !existingArtistIds.contains($0.id) })
                    let existingAlbumIds = Set(searchResults.albums.map { $0.id })
                    searchResults.albums.append(contentsOf: more.2.filter { !existingAlbumIds.contains($0.id) })
                }
                isPaging = false
            }
        }
    }
    
    private func searchListsAsync() async -> [MusicList] {
        let db = Firestore.firestore()
        let term = searchText.lowercased()
        var lists: [MusicList] = []

        do {
            async let prefixSnap = db.collection("musicLists")
                .whereField("titleLower", isGreaterThanOrEqualTo: term)
                .whereField("titleLower", isLessThanOrEqualTo: term + "\u{f8ff}")
                .limit(to: 25)
                .getDocuments()

            async let keywordSnap = db.collection("musicLists")
                .whereField("keywords", arrayContains: term)
                .limit(to: 25)
                .getDocuments()

            let (prefixResults, keywordResults) = try await (prefixSnap, keywordSnap)

            // Merge and deduplicate
            var uniqueLists = [String: MusicList]()
            for doc in prefixResults.documents {
                if let list = try? doc.data(as: MusicList.self) {
                    uniqueLists[list.id] = list
                }
            }
            for doc in keywordResults.documents {
                if let list = try? doc.data(as: MusicList.self) {
                    uniqueLists[list.id] = list
                }
            }
            lists = Array(uniqueLists.values)
        } catch {
            print("🔥 Error searching lists: \(error.localizedDescription)")
        }
        return lists
    }
    
    private func searchUsersAsync() async -> [UserProfile] {
        let db = Firestore.firestore()
        let term = searchText.lowercased()
        var users: [UserProfile] = []
        
        do {
            let snapshot = try await db.collection("users")
                .whereField("displayNameLower", isGreaterThanOrEqualTo: term)
                .whereField("displayNameLower", isLessThanOrEqualTo: term + "\u{f8ff}")
                .limit(to: 25)
                .getDocuments()
            
            for document in snapshot.documents {
                if let user = try? document.data(as: UserProfile.self) {
                    users.append(user)
                }
            }
        } catch {
            print("🔥 Error searching users: \(error.localizedDescription)")
        }
        return users
    }
    
    // MARK: - Result Handling
    private func handleResultTap(_ item: MusicSearchResult) {
        selectedMusicResult = item
        showLogForm = true
    }
}

// MARK: - Log Search Filter
enum LogSearchFilter: String, CaseIterable {
    case all = "All"
    case songs = "Songs"
    case artists = "Artists"
    case albums = "Albums"
    
    var icon: String {
        switch self {
        case .all: return "music.note.list"
        case .songs: return "music.note"
        case .artists: return "person.2"
        case .albums: return "rectangle.stack"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .songs: return .green
        case .artists: return .orange
        case .albums: return .purple
        }
    }
}

// MARK: - Log Search Results
struct LogSearchResults {
    var songs: [MusicSearchResult] = []
    var artists: [MusicSearchResult] = []
    var albums: [MusicSearchResult] = []
    var lists: [MusicList] = []
    var users: [UserProfile] = []
    
    func filteredResults(for filter: LogSearchFilter) -> [MusicSearchResult] {
        switch filter {
        case .all:
            return songs + artists + albums
        case .songs:
            return songs
        case .artists:
            return artists
        case .albums:
            return albums
        }
    }
}

// MARK: - Log Filter Button Component
struct LogFilterButton: View {
    let filter: LogSearchFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? filter.color : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Log Search Result Row Component
struct LogSearchResultRow: View {
    let item: MusicSearchResult
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Artwork
                AsyncImage(url: URL(string: item.artworkURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: item.itemType == "song" ? "music.note" : 
                                   item.itemType == "artist" ? "person" : "rectangle.stack")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(item.artistName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if item.itemType == "song" && !item.albumName.isEmpty {
                        Text(item.albumName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Type indicator
                VStack {
                    Image(systemName: item.itemType == "song" ? "music.note" : 
                           item.itemType == "artist" ? "person" : "rectangle.stack")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.itemType.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Log Music Form View
struct LogMusicFormView: View {
    let searchResult: MusicSearchResult
    @Environment(\.presentationMode) var presentationMode
    @State private var rating: Double = 0.0
    @State private var review: String = ""
    @FocusState private var focusedField: FocusedField?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var isLiked = false
    @State private var isReposted = false
    @State private var thumbsDown = false
    @State private var isPublic = true
    @State private var aiClassification: AIGenreClassificationService.ClassificationResult?
    @State private var isClassifyingGenre = false
    
    // Mention state
    @State private var mentionSuggestions: [MentionSuggestion] = []
    @State private var showMentionSuggestions = false
    @State private var currentMentionQuery = ""
    @State private var mentionStartIndex: String.Index?
    @State private var tappedInsideReview = false

    // Artist artwork fallback
    @State private var fetchedArtworkURL: String? = nil
    @State private var isLoadingArtwork = false

    private enum FocusedField: Hashable {
        case review
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section - Song/Album Info
                    VStack(spacing: 20) {
                        // Album/Artist artwork with enhanced styling
                        Group {
                            let artworkURL = fetchedArtworkURL ?? searchResult.artworkURL
                            if let artworkURL = artworkURL, let url = URL(string: artworkURL) {
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .overlay(
                                            Image(systemName: searchResult.itemType == "artist" ? "person.wave.2" : "music.note")
                                                .font(.system(size: 30))
                                                .foregroundColor(.gray)
                                        )
                                }
                            } else if isLoadingArtwork {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .overlay(
                                        ProgressView()
                                    )
                            } else {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .overlay(
                                        Image(systemName: searchResult.itemType == "artist" ? "person.wave.2" : "music.note")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .frame(width: 140, height: 140)
                        .cornerRadius(searchResult.itemType == "artist" ? 70 : 20)
                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                        
                        VStack(spacing: 8) {
                            Text(searchResult.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            Text(searchResult.artistName)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text(searchResult.itemType.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.purple.opacity(0.1))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Rating Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How would you rate this?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        PreciseStarRatingView(rating: $rating)
                    }
                    .padding(.horizontal, 20)
                    
                    // Review Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Add a review (optional)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 0) {
                            // Mention suggestions
                            if showMentionSuggestions && !mentionSuggestions.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(mentionSuggestions) { suggestion in
                                            Button(action: {
                                                insertMention(suggestion)
                                            }) {
                                                HStack(spacing: 8) {
                                                    // Profile picture
                                                    if let profileUrl = suggestion.profilePictureUrl, let url = URL(string: profileUrl) {
                                                        CachedAsyncImage(url: url) { image in
                                                            image
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                        } placeholder: {
                                                            Circle()
                                                                .fill(Color.purple.opacity(0.2))
                                                        }
                                                        .frame(width: 32, height: 32)
                                                        .clipShape(Circle())
                                                    } else {
                                                        Circle()
                                                            .fill(Color.purple.opacity(0.2))
                                                            .frame(width: 32, height: 32)
                                                            .overlay(
                                                                Text(String(suggestion.username.prefix(1)).uppercased())
                                                                    .font(.caption)
                                                                    .foregroundColor(.purple)
                                                            )
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(suggestion.username)
                                                            .font(.subheadline)
                                                            .fontWeight(.semibold)
                                                            .foregroundColor(.primary)
                                                        
                                                        if suggestion.displayName != suggestion.username {
                                                            Text(suggestion.displayName)
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 12)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(12)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                                .padding(.bottom, 8)
                            }
                            
                            // Text editor
                            TextEditor(text: $review)
                                .frame(minHeight: 120)
                                .padding(16)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .focused($focusedField, equals: .review)
                                .onChange(of: review) { oldValue, newValue in
                                    handleTextChange(newValue)
                                }
                                .simultaneousGesture(
                                    TapGesture()
                                        .onEnded {
                                            tappedInsideReview = true
                                        }
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // AI Genre Classification Preview
                    genreClassificationSection
                    
                    // Privacy Section
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $isPublic) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Public log")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text(isPublic ? "Visible to followers and in trends" : "Only you can see this log")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                    .padding(.horizontal, 20)
                    
                    // Error Message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Success Message
                    if showSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Log saved successfully!")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Save Button
                    Button(action: saveLog) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Saving...")
                            } else {
                                Text("Save Log")
                            }
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSaving)
                    .buttonStyle(BumpinPrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if tappedInsideReview {
                            tappedInsideReview = false
                        } else {
                            focusedField = nil
                            hideKeyboard()
                            showMentionSuggestions = false
                        }
                    }
            )
            .navigationTitle("Log Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Close log music form")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
        .onAppear {
            // Trigger AI genre classification when form appears
            Task {
                await classifyGenre()
            }
            
            // Fetch artist artwork if missing
            if searchResult.itemType == "artist" && searchResult.artworkURL == nil {
                Task {
                    await fetchArtistArtwork()
                }
            }
        }
    }
    
    // MARK: - Genre Classification Section
    
    @ViewBuilder
    private var genreClassificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Genre Classification")
                .font(.headline)
                .fontWeight(.semibold)
            
            if isClassifyingGenre {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("AI is analyzing genre...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if let classification = aiClassification {
                HStack(spacing: 16) {
                    // Genre icon
                    Image(systemName: genreIcon(for: classification.primaryGenre))
                        .font(.system(size: 28))
                            .foregroundColor(.purple)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.purple.opacity(0.1))
                        )
                    
                    // Genre name
                            Text(classification.primaryGenre)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        
                        Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Genre classification unavailable")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    Button("Retry") {
                        Task { await classifyGenre() }
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Genre Icon Mapping
    
    private func genreIcon(for genre: String) -> String {
        let lowercasedGenre = genre.lowercased()
        
        // Hip-Hop & Rap
        if lowercasedGenre.contains("hip") || lowercasedGenre.contains("hop") || lowercasedGenre.contains("rap") {
            return "speaker.wave.3.fill"
        }
        // Rock
        else if lowercasedGenre.contains("rock") {
            return "guitars.fill"
        }
        // Pop
        else if lowercasedGenre.contains("pop") {
            return "star.circle.fill"
        }
        // Electronic / EDM
        else if lowercasedGenre.contains("electronic") || lowercasedGenre.contains("edm") || 
                lowercasedGenre.contains("house") || lowercasedGenre.contains("techno") ||
                lowercasedGenre.contains("dubstep") || lowercasedGenre.contains("trance") {
            return "waveform"
        }
        // Jazz
        else if lowercasedGenre.contains("jazz") {
            return "music.mic"
        }
        // Classical
        else if lowercasedGenre.contains("classical") || lowercasedGenre.contains("orchestra") {
            return "music.quarternote.3"
        }
        // Country
        else if lowercasedGenre.contains("country") {
            return "figure.walk"
        }
        // R&B / Soul
        else if lowercasedGenre.contains("r&b") || lowercasedGenre.contains("soul") || 
                lowercasedGenre.contains("rnb") {
            return "heart.text.square.fill"
        }
        // Blues
        else if lowercasedGenre.contains("blues") {
            return "music.note"
        }
        // Reggae
        else if lowercasedGenre.contains("reggae") || lowercasedGenre.contains("ska") {
            return "sun.max.fill"
        }
        // Metal
        else if lowercasedGenre.contains("metal") {
            return "bolt.fill"
        }
        // Punk
        else if lowercasedGenre.contains("punk") {
            return "flame.fill"
        }
        // Latin
        else if lowercasedGenre.contains("latin") || lowercasedGenre.contains("salsa") || 
                lowercasedGenre.contains("reggaeton") {
            return "globe.americas.fill"
        }
        // Indie / Alternative
        else if lowercasedGenre.contains("indie") || lowercasedGenre.contains("alternative") {
            return "sparkles"
        }
        // Folk
        else if lowercasedGenre.contains("folk") || lowercasedGenre.contains("acoustic") {
            return "leaf.fill"
        }
        // Ambient / Chillout
        else if lowercasedGenre.contains("ambient") || lowercasedGenre.contains("chill") {
            return "cloud.fill"
        }
        // Gospel / Worship
        else if lowercasedGenre.contains("gospel") || lowercasedGenre.contains("worship") ||
                lowercasedGenre.contains("christian") {
            return "hands.sparkles.fill"
        }
        // K-Pop / J-Pop / Asian
        else if lowercasedGenre.contains("k-pop") || lowercasedGenre.contains("j-pop") ||
                lowercasedGenre.contains("cpop") {
            return "globe.asia.australia.fill"
        }
        // Funk / Disco
        else if lowercasedGenre.contains("funk") || lowercasedGenre.contains("disco") {
            return "figure.dance"
        }
        // World Music
        else if lowercasedGenre.contains("world") || lowercasedGenre.contains("african") ||
                lowercasedGenre.contains("middle east") {
            return "globe"
        }
        // Default
        else {
            return "music.note.list"
        }
    }
    
    // MARK: - Artist Artwork Fetching
    
    private func fetchArtistArtwork() async {
        guard searchResult.itemType == "artist" else { return }
        
        await MainActor.run {
            isLoadingArtwork = true
        }
        
        do {
            // Search for the artist using MusicKit
            var request = MusicCatalogSearchRequest(term: searchResult.artistName, types: [MusicKit.Artist.self])
            request.limit = 5
            
            let response = try await request.response()
            
            // Find the best matching artist
            let artist = response.artists.first { artist in
                artist.name.lowercased() == searchResult.artistName.lowercased()
            } ?? response.artists.first
            
            if let artist = artist, let artworkURL = artist.artwork?.url(width: 512, height: 512)?.absoluteString {
                await MainActor.run {
                    fetchedArtworkURL = artworkURL
                    isLoadingArtwork = false
                }
                print("✅ Fetched artist artwork for \(searchResult.artistName): \(artworkURL)")
            } else {
                await MainActor.run {
                    isLoadingArtwork = false
                }
                print("⚠️ No artwork found for artist: \(searchResult.artistName)")
            }
        } catch {
            print("❌ Error fetching artist artwork: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingArtwork = false
            }
        }
    }
    
    // MARK: - Genre Classification Methods
    
    private func classifyGenre() async {
        await MainActor.run {
            isClassifyingGenre = true
        }
        
        let result = await AIGenreClassificationService.shared.classifyForMusicLog(searchResult: searchResult)
        
        await MainActor.run {
            aiClassification = result
            isClassifyingGenre = false
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }

    // Phase 3: Calculate confidence score for genre classification
    private func calculateConfidenceScore(searchResult: MusicSearchResult) -> Double {
        if searchResult.genreNames != nil && !(searchResult.genreNames?.isEmpty ?? true) {
            return 0.9 // High confidence for Apple Music data
        } else if searchResult.primaryGenre != nil {
            return 0.7 // Medium confidence for stored primary genre
        } else {
            return 0.5 // Lower confidence for fallback classification
        }
    }
    
    // Phase 3: Determine how the genre was classified
    private func determineClassificationMethod(searchResult: MusicSearchResult) -> String {
        if searchResult.genreNames != nil && !(searchResult.genreNames?.isEmpty ?? true) {
            return "apple_music"
        } else if searchResult.primaryGenre != nil {
            return "stored_primary"
        } else {
            return "artist_database_fallback"
        }
    }

    // MARK: - Mention Handling
    
    private func handleTextChange(_ newValue: String) {
        // Detect if user is typing a mention
        if let lastAtIndex = newValue.lastIndex(of: "@") {
            // Check if @ is at the start or preceded by a space
            let isValidMention: Bool
            if lastAtIndex == newValue.startIndex {
                isValidMention = true
            } else {
                let charBeforeAt = newValue[newValue.index(before: lastAtIndex)]
                isValidMention = charBeforeAt.isWhitespace
            }
            
            if isValidMention {
                // Extract the query after @
                let afterAtIndex = newValue.index(after: lastAtIndex)
                let afterAt = String(newValue[afterAtIndex...])
                
                // Check if there's a space after @ (if so, stop suggesting)
                if let spaceIndex = afterAt.firstIndex(of: " ") {
                    let query = String(afterAt[..<spaceIndex])
                    if query.isEmpty {
                        showMentionSuggestions = false
                        mentionSuggestions = []
                    }
                } else {
                    // Continue suggesting
                    currentMentionQuery = afterAt
                    mentionStartIndex = lastAtIndex
                    showMentionSuggestions = true
                    fetchMentionSuggestions(query: afterAt)
                }
            } else {
                showMentionSuggestions = false
            }
        } else {
            // No @ found, hide suggestions
            showMentionSuggestions = false
            mentionSuggestions = []
        }
    }
    
    private func fetchMentionSuggestions(query: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let suggestions = await MentionService.shared.getSuggestions(
                query: query,
                logId: nil, // No log ID yet since we're creating a new log
                currentUserId: currentUserId
            )
            
            await MainActor.run {
                mentionSuggestions = suggestions
            }
        }
    }
    
    private func insertMention(_ suggestion: MentionSuggestion) {
        guard let startIndex = mentionStartIndex else { return }
        
        // Replace from @ to current position with @username
        let beforeAt = String(review[..<startIndex])
        let mentionText = "@\(suggestion.username) "
        
        review = beforeAt + mentionText
        
        // Hide suggestions
        showMentionSuggestions = false
        mentionSuggestions = []
        mentionStartIndex = nil
    }
    
    func saveLog() {
        isSaving = true
        errorMessage = nil
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to save a log."
            isSaving = false
            return
        }
        
        // Content moderation check
        Task {
            // Check if review content is appropriate
            if !review.isEmpty {
                let moderationResult = await ContentModerationService.shared.moderateReview(review, userId: userId)
                if !moderationResult.isAllowed {
                    await MainActor.run {
                        self.errorMessage = "Review contains inappropriate content: \(moderationResult.reason)"
                        self.isSaving = false
                    }
                    return
                }
            }
            
            await saveLogAfterModeration(userId: userId)
        }
    }
    
    private func saveLogAfterModeration(userId: String) async {
        // Use existing AI classification or get new one
        let classification: AIGenreClassificationService.ClassificationResult
        if let existing = aiClassification {
            classification = existing
        } else {
            classification = await AIGenreClassificationService.shared.classifyForMusicLog(searchResult: searchResult)
        }
        
        // Get or create universal track for cross-platform unification
        let universalTrackId = await UnifiedMusicSearchService.shared.createUniversalTrackForLog(
            searchResult: searchResult,
            platform: searchResult.platform ?? "apple_music" // Use actual platform from search result
        )
        
        await MainActor.run {
            // Create genres array with primaryGenre for Firestore querying
            let genresArray: [String] = [classification.primaryGenre]
            
            // Use fetched artwork if available, otherwise use original
            let finalArtworkURL = fetchedArtworkURL ?? searchResult.artworkURL
            
            let log = MusicLog(
                id: UUID().uuidString,
                userId: userId,
                itemId: searchResult.id,
                itemType: searchResult.itemType,
                title: searchResult.title,
                artistName: searchResult.artistName,
                artworkUrl: finalArtworkURL,
                dateLogged: Date(),
                rating: rating < 1.0 ? nil : rating,
                review: review.isEmpty ? nil : review,
                notes: nil,
                commentCount: nil,
                helpfulCount: nil,
                unhelpfulCount: nil,
                reviewPhotos: nil,
                isLiked: isLiked,
                thumbsUp: isReposted,
                thumbsDown: thumbsDown,
                isPublic: isPublic,
                appleMusicGenres: classification.appleMusicGenres,
                primaryGenre: classification.primaryGenre,
                genres: genresArray,
                userCorrectedGenre: nil,
                genreConfidenceScore: classification.confidence,
                classificationMethod: classification.classificationMethod,
                universalTrackId: universalTrackId,
                musicPlatform: searchResult.platform ?? "apple_music",
                platformMatchingConfidence: 1.0
            )
            
            print("🎯 AI classified '\(searchResult.title)': \(classification.primaryGenre) (confidence: \(String(format: "%.2f", classification.confidence)))")
            
            MusicLog.createLog(log) { error in
                DispatchQueue.main.async {
                    self.isSaving = false
                    if let error = error {
                        self.errorMessage = "Failed to save log: \(error.localizedDescription)"
                        print("❌ Error saving log: \(error.localizedDescription)")
                    } else {
                        print("✅ Log saved successfully with content moderation and AI genre classification!")
                        self.showSuccess = true
                        self.errorMessage = nil
                        
                        // Send mention notifications if review contains @mentions
                        if !self.review.isEmpty {
                            Task {
                                // Get user profile for username
                                let db = Firestore.firestore()
                                if let userDoc = try? await db.collection("users").document(userId).getDocument(),
                                   let username = userDoc.data()?["username"] as? String {
                                    let profilePictureUrl = userDoc.data()?["profilePictureUrl"] as? String
                                    
                                    await MentionService.shared.sendMentionNotifications(
                                        text: self.review,
                                        contentType: "log_caption",
                                        contentId: log.id,
                                        logId: log.id,
                                        logTitle: log.title,
                                        logArtist: log.artistName,
                                        mentionerUserId: userId,
                                        mentionerUsername: username,
                                        mentionerProfilePicture: profilePictureUrl
                                    )
                                }
                            }
                        }
                        
                        // Show success message briefly before dismissing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
} 