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
        Group {
            if isLoading {
                loadingView
            } else if searchResults.filteredResults(for: selectedFilter).isEmpty && !searchText.isEmpty {
                emptyStateView
            } else if searchText.isEmpty {
                recentSearchesView
            } else {
                resultsListView
            }
        }
    }
    
    // MARK: - Loading View
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
    @State private var rating: Int = 0
    @State private var review: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var isLiked = false
    @State private var isReposted = false
    @State private var thumbsDown = false
    @State private var isPublic = true
    @State private var aiClassification: AIGenreClassificationService.ClassificationResult?
    @State private var isClassifyingGenre = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section - Song/Album Info
                    VStack(spacing: 20) {
                        // Album artwork with enhanced styling
                        Group {
                            if let artworkURL = searchResult.artworkURL, let url = URL(string: artworkURL) {
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.system(size: 30))
                                                .foregroundColor(.gray)
                                        )
                                }
                            } else {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .frame(width: 140, height: 140)
                        .cornerRadius(20)
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
                        
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        rating = star
                                    }
                                }) {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .scaleEffect(star <= rating ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: rating)
                            }
                            
                            Spacer()
                        }
                        
                        if rating > 0 {
                            Text("\(rating) star\(rating == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick actions")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 20) {
                            // Like Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isLiked.toggle()
                                    if isLiked {
                                        isReposted = false
                                        thumbsDown = false
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 18, weight: .medium))
                                    Text("Like")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(isLiked ? .red : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(isLiked ? Color.red.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isLiked ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Repost Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isReposted.toggle()
                                    if isReposted {
                                        isLiked = false
                                        thumbsDown = false
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: isReposted ? "arrow.2.squarepath" : "arrow.2.squarepath")
                                        .font(.system(size: 18, weight: .medium))
                                    Text("Repost")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(isReposted ? .blue : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(isReposted ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isReposted ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Skip Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    thumbsDown.toggle()
                                    if thumbsDown {
                                        isLiked = false
                                        isReposted = false
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                        .font(.system(size: 18, weight: .medium))
                                    Text("Skip")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(thumbsDown ? .orange : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(thumbsDown ? Color.orange.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(thumbsDown ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Review Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Add a review (optional)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextEditor(text: $review)
                            .frame(minHeight: 120)
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
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
                VStack(alignment: .leading, spacing: 12) {
                    // Primary genre display
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .foregroundColor(.purple)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(classification.primaryGenre)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            
                            Text("Primary Genre")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Confidence indicator
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(confidenceColor(classification.confidence))
                                    .frame(width: 8, height: 8)
                                Text("\(Int(classification.confidence * 100))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(confidenceColor(classification.confidence))
                            }
                            
                            Text("Confidence")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Apple Music genres (if available)
                    if !classification.appleMusicGenres.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Music Genres:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(classification.appleMusicGenres.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // AI reasoning (if available)
                    if let reasoning = classification.reasoning {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Reasoning:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(reasoning)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .italic()
                        }
                    }
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
            platform: "apple_music" // TODO: Detect actual platform from search source
        )
        
        await MainActor.run {
            let log = MusicLog(
                id: UUID().uuidString,
                userId: userId,
                itemId: searchResult.id,
                itemType: searchResult.itemType,
                title: searchResult.title,
                artistName: searchResult.artistName,
                artworkUrl: searchResult.artworkURL,
                dateLogged: Date(),
                rating: rating == 0 ? nil : rating,
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
                userCorrectedGenre: nil,
                genreConfidenceScore: classification.confidence,
                classificationMethod: classification.classificationMethod,
                universalTrackId: universalTrackId,
                musicPlatform: "apple_music",
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