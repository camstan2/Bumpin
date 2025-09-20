import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import MusicKit
import MediaPlayer

// MARK: - Environment Keys for Prompt Selection
struct PromptSelectionModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

struct OnPromptSongSelectedKey: EnvironmentKey {
    static let defaultValue: ((MusicSearchResult) -> Void)? = nil
}

extension EnvironmentValues {
    var promptSelectionMode: Bool {
        get { self[PromptSelectionModeKey.self] }
        set { self[PromptSelectionModeKey.self] = newValue }
    }
    
    var onPromptSongSelected: ((MusicSearchResult) -> Void)? {
        get { self[OnPromptSongSelectedKey.self] }
        set { self[OnPromptSongSelectedKey.self] = newValue }
    }
}

// Helper struct to make String identifiable for sheet presentation
struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

// MARK: - Search Types
    enum SearchTab: String, CaseIterable, Identifiable {
        case search = "Search"
        case appleMusicLibrary = "Apple Music Library"
        case spotifyLibrary = "Spotify Library"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .search: return "magnifyingglass"
            case .appleMusicLibrary: return "music.note"
            case .spotifyLibrary: return "music.note.list"
            }
        }
        
        var shortName: String {
            switch self {
            case .search: return "Search"
            case .appleMusicLibrary: return "Apple Music"
            case .spotifyLibrary: return "Spotify"
            }
        }
    }

    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case songs = "Songs"
        case albums = "Albums"
    case artists = "Artists"
        case users = "Users"
        case lists = "Lists"
    
    var displayName: String { rawValue }
        
        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .songs: return "music.note"
            case .albums: return "opticaldisc"
        case .artists: return "person.fill"
        case .users: return "person"
        case .lists: return "music.note.list"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .purple
            case .songs: return .blue
            case .albums: return .orange
        case .artists: return .green
            case .users: return .pink
            case .lists: return .indigo
            }
        }
    }
    
    struct SearchResults {
    var songs: [any SearchResult] = []
    var albums: [any SearchResult] = []
    var artists: [any SearchResult] = []
    var users: [any SearchResult] = []
    var lists: [any SearchResult] = []
    
    var all: [any SearchResult] {
        let allResults = songs + albums + artists + users + lists
        return deduplicateResults(allResults)
    }
    
    // MARK: - Enhanced Deduplication Logic
    private func deduplicateResults(_ results: [any SearchResult]) -> [any SearchResult] {
        var groups: [String: [any SearchResult]] = [:]
        
        func normalize(_ text: String) -> String {
            let lowered = text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.replacingOccurrences(of: "[\u{2018}\u{2019}'`]+", with: "", options: .regularExpression)
        }
        
        func normalizeAlbumTitle(_ title: String) -> String {
            var t = normalize(title)
            // Remove edition qualifiers - comprehensive patterns
            t = t.replacingOccurrences(of: "\\s*\\((deluxe|clean|explicit|remaster(ed)?|expanded|edition|version|single|ep|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)[^)]*\\)", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\s*-\\s*(single|ep|deluxe|clean|explicit|expanded|edition|version|remaster(ed)?|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)\\s*$", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\s*\\[(deluxe|clean|explicit|remaster(ed)?|expanded|edition|version|single|ep|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)[^\\]]*\\]", with: "", options: .regularExpression)
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Group similar results
        for result in results {
            let normalizedTitle = result.type == .album ? normalizeAlbumTitle(result.title) : normalize(result.title)
            let normalizedSubtitle = normalize(result.subtitle)
            let key = "\(normalizedTitle)|\(normalizedSubtitle)|\(result.type.rawValue)"
            
            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(result)
        }
        
        // Select best from each group
        var deduplicated: [any SearchResult] = []
        for (_, group) in groups {
            if let best = selectBestSearchResult(from: group) {
                deduplicated.append(best)
            }
        }
        
        return deduplicated
    }
    
    private func selectBestSearchResult(from group: [any SearchResult]) -> (any SearchResult)? {
        guard !group.isEmpty else { return nil }
        
        if group.count == 1 {
            return group.first
        }
        
        // Score each result
        let scored = group.map { result -> (any SearchResult, Int) in
            var score = 0
            
            // Prefer results with more complete metadata
            if !result.title.isEmpty {
                score += 5
            }
            if !result.subtitle.isEmpty {
                score += 3
            }
            
            // For albums, prefer titles without edition qualifiers
            if result.type == .album {
                let titleLower = result.title.lowercased()
                let hasEditionQualifier = titleLower.contains("deluxe") ||
                                        titleLower.contains("explicit") ||
                                        titleLower.contains("clean") ||
                                        titleLower.contains("single") ||
                                        titleLower.contains("remaster") ||
                                        titleLower.contains("anniversary") ||
                                        titleLower.contains("special") ||
                                        titleLower.contains("limited")
                if !hasEditionQualifier {
                    score += 10
                }
                
                // Prefer shorter titles (usually main releases)
                if result.title.count < 30 {
                    score += 5
                }
            }
            
            return (result, score)
        }
        
        return scored.max(by: { $0.1 < $1.1 })?.0
    }
    
    /// Smart prioritization based on search query
    func prioritized(for query: String) -> [any SearchResult] {
        return SearchResultsPrioritizer.prioritize(results: self, query: query)
    }
}

// MARK: - Smart Search Result Prioritizer
struct SearchResultsPrioritizer {
    static func prioritize(results: SearchResults, query: String) -> [any SearchResult] {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If query is too short or empty, use default order
        guard normalizedQuery.count >= 2 else {
            return results.all
        }
        
        var prioritized: [any SearchResult] = []
        
        // 1. HIGHEST PRIORITY: Exact artist name matches
        let exactArtistMatches = results.artists.filter { artist in
            artist.title.lowercased() == normalizedQuery
        }
        prioritized.append(contentsOf: exactArtistMatches)
        
        // 2. HIGH PRIORITY: Partial artist name matches (starts with query)
        let partialArtistMatches = results.artists.filter { artist in
            let artistName = artist.title.lowercased()
            return artistName.hasPrefix(normalizedQuery) && 
                   !exactArtistMatches.contains(where: { $0.id == artist.id })
        }
        prioritized.append(contentsOf: partialArtistMatches)
        
        // 3. MEDIUM-HIGH PRIORITY: Artist name contains query (but doesn't start with it)
        let containsArtistMatches = results.artists.filter { artist in
            let artistName = artist.title.lowercased()
            return artistName.contains(normalizedQuery) && 
                   !artistName.hasPrefix(normalizedQuery) &&
                   !exactArtistMatches.contains(where: { $0.id == artist.id }) &&
                   !partialArtistMatches.contains(where: { $0.id == artist.id })
        }
        prioritized.append(contentsOf: containsArtistMatches)
        
        // 4. MEDIUM PRIORITY: Songs by the matched artists (if any artists were found)
        let matchedArtistNames = Set((exactArtistMatches + partialArtistMatches + containsArtistMatches).map { $0.title.lowercased() })
        
        if !matchedArtistNames.isEmpty {
            let songsByMatchedArtists = results.songs.filter { song in
                matchedArtistNames.contains(song.subtitle.lowercased())
            }
            prioritized.append(contentsOf: songsByMatchedArtists)
            
            // Albums by matched artists
            let albumsByMatchedArtists = results.albums.filter { album in
                matchedArtistNames.contains(album.subtitle.lowercased())
            }
            prioritized.append(contentsOf: albumsByMatchedArtists)
        }
        
        // 5. LOWER PRIORITY: Exact song title matches
        let exactSongMatches = results.songs.filter { song in
            song.title.lowercased() == normalizedQuery &&
            !prioritized.contains(where: { $0.id == song.id })
        }
        prioritized.append(contentsOf: exactSongMatches)
        
        // 6. LOWER PRIORITY: Exact album title matches  
        let exactAlbumMatches = results.albums.filter { album in
            album.title.lowercased() == normalizedQuery &&
            !prioritized.contains(where: { $0.id == album.id })
        }
        prioritized.append(contentsOf: exactAlbumMatches)
        
        // 7. LOWEST PRIORITY: All remaining results (songs, albums that don't match above criteria)
        let remainingResults = results.all.filter { result in
            !prioritized.contains(where: { $0.id == result.id })
        }
        prioritized.append(contentsOf: remainingResults)
        
        // Debug logging
        print("🔍 Search prioritization for '\(query)':")
        print("   📊 Total results: \(prioritized.count)")
        print("   🎤 Exact artist matches: \(exactArtistMatches.count)")
        print("   🎤 Partial artist matches: \(partialArtistMatches.count)")
        print("   🎤 Contains artist matches: \(containsArtistMatches.count)")
        if let firstResult = prioritized.first {
            print("   🥇 First result: \(firstResult.title) (\(firstResult.type.rawValue))")
        }
        
        return deduplicatePrioritizedResults(prioritized)
    }
    
    // MARK: - Enhanced Deduplication for Prioritized Results
    private static func deduplicatePrioritizedResults(_ results: [any SearchResult]) -> [any SearchResult] {
        var groups: [String: [any SearchResult]] = [:]
        
        func normalize(_ text: String) -> String {
            let lowered = text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.replacingOccurrences(of: "[\u{2018}\u{2019}'`]+", with: "", options: .regularExpression)
        }
        
        func normalizeAlbumTitle(_ title: String) -> String {
            var t = normalize(title)
            // Remove edition qualifiers - comprehensive patterns
            t = t.replacingOccurrences(of: "\\s*\\((deluxe|clean|explicit|remaster(ed)?|expanded|edition|version|single|ep|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)[^)]*\\)", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\s*-\\s*(single|ep|deluxe|clean|explicit|expanded|edition|version|remaster(ed)?|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)\\s*$", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\s*\\[(deluxe|clean|explicit|remaster(ed)?|expanded|edition|version|single|ep|anniversary|special|limited|bonus|digital|vinyl|cd|extended|complete|ultimate|platinum|gold|collector's?)[^\\]]*\\]", with: "", options: .regularExpression)
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Group similar results while preserving order
        for result in results {
            let normalizedTitle = result.type == .album ? normalizeAlbumTitle(result.title) : normalize(result.title)
            let normalizedSubtitle = normalize(result.subtitle)
            let key = "\(normalizedTitle)|\(normalizedSubtitle)|\(result.type.rawValue)"
            
            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(result)
        }
        
        // Maintain original order while deduplicating
        var deduplicated: [any SearchResult] = []
        var processedKeys: Set<String> = []
        
        for result in results {
            let normalizedTitle = result.type == .album ? normalizeAlbumTitle(result.title) : normalize(result.title)
            let normalizedSubtitle = normalize(result.subtitle)
            let key = "\(normalizedTitle)|\(normalizedSubtitle)|\(result.type.rawValue)"
            
            if !processedKeys.contains(key), let group = groups[key] {
                // For prioritized results, prefer the first occurrence (highest priority)
                // but still select the best quality version from the group
                if let best = selectBestFromPrioritizedGroup(group, originalOrder: results) {
                    deduplicated.append(best)
                }
                processedKeys.insert(key)
            }
        }
        
        return deduplicated
    }
    
    private static func selectBestFromPrioritizedGroup(_ group: [any SearchResult], originalOrder: [any SearchResult]) -> (any SearchResult)? {
        guard !group.isEmpty else { return nil }
        
        if group.count == 1 {
            return group.first
        }
        
        // For prioritized results, prefer the one that appears first in original order
        // but also consider quality
        let scored = group.map { result -> (any SearchResult, Int) in
            var score = 0
            
            // Heavily weight original order (prioritization)
            if let originalIndex = originalOrder.firstIndex(where: { $0.title == result.title && $0.subtitle == result.subtitle }) {
                score += (1000 - originalIndex) // Earlier = higher score
            }
            
            // Quality factors (lower weight)
            if !result.title.isEmpty {
                score += 2
            }
            if !result.subtitle.isEmpty {
                score += 1
            }
            
            // For albums, prefer main releases
            if result.type == .album {
                let titleLower = result.title.lowercased()
                let hasEditionQualifier = titleLower.contains("deluxe") ||
                                        titleLower.contains("explicit") ||
                                        titleLower.contains("clean") ||
                                        titleLower.contains("single") ||
                                        titleLower.contains("remaster")
                if !hasEditionQualifier {
                    score += 3
                }
            }
            
            return (result, score)
        }
        
        return scored.max(by: { $0.1 < $1.1 })?.0
    }
}

// MARK: - Recently Tapped Card
struct RecentlyTappedCard: View {
    let item: RecentlyTappedItem
    let onTap: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Artwork
                AsyncImage(url: URL(string: item.artworkURL ?? "")) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: iconForType(item.type))
                                    .foregroundColor(.gray)
                                    .font(.system(size: 20))
                            )
                    }
                }
                .frame(width: 56, height: 56)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(item.subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Type indicator
                Text(item.type.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.purple.opacity(0.2))
                    )
                    .foregroundColor(.purple)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color(.systemGray4).opacity(0.1), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private func iconForType(_ type: SearchResultType) -> String {
        switch type {
        case .song: return "music.note"
        case .album: return "opticaldisc"
        case .artist: return "person.circle"
        case .user: return "person.crop.circle"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Apple Music Style Song Card
struct AppleMusicSongCard: View {
    let song: LibraryItem
    let onTap: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Album artwork - fixed position at top
                AsyncImage(url: URL(string: song.artworkURL ?? "")) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 24))
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                
                // Fixed height text container - accommodates 2 title lines + 1 artist line
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true) // Allow natural text wrapping
                    
                    Text(song.artistName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    
                    // Spacer fills remaining space to maintain consistent card height
                    Spacer(minLength: 0)
                }
                .frame(width: 120, height: 60, alignment: .top) // Increased height for 3 lines of text
                .padding(.top, 8) // Space between artwork and text
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation {
                isPressed = pressing
            }
        }, perform: {})
    }
}

protocol SearchResult: Identifiable {
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var artworkURL: URL? { get }
    var type: SearchResultType { get }
}

enum SearchResultType: String, Codable {
    case song, album, artist, user, list
}

// MARK: - SearchResult Implementations
struct MusicSongResult: SearchResult {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let type: SearchResultType = .song
    let albumName: String
    let artistName: String
    
    init(from song: MusicKit.Song) {
        self.id = song.id.rawValue
        self.title = song.title
        self.subtitle = song.artistName
        self.artworkURL = song.artwork?.url(width: 300, height: 300)
        self.albumName = song.albumTitle ?? ""
        self.artistName = song.artistName
    }
    
    // Custom initializer for MusicSearchResult conversion
    init(id: String, title: String, subtitle: String, artworkURL: URL?, albumName: String, artistName: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.albumName = albumName
        self.artistName = artistName
    }
}

struct MusicAlbumResult: SearchResult {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let type: SearchResultType = .album
    let artistName: String
    
    init(from album: MusicKit.Album) {
        self.id = album.id.rawValue
        self.title = album.title
        self.subtitle = album.artistName
        self.artworkURL = album.artwork?.url(width: 300, height: 300)
        self.artistName = album.artistName
    }
    
    // Custom initializer for MusicSearchResult conversion
    init(id: String, title: String, subtitle: String, artworkURL: URL?, artistName: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.artistName = artistName
    }
}

struct MusicArtistResult: SearchResult {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let type: SearchResultType = .artist
    let genreNames: [String]?
    
    init(from artist: MusicKit.Artist) {
        self.id = artist.id.rawValue
        self.title = artist.name
        self.subtitle = artist.genreNames?.first ?? "Artist"
        self.artworkURL = artist.artwork?.url(width: 300, height: 300)
        self.genreNames = artist.genreNames
    }
    
    // Custom initializer for MusicSearchResult conversion
    init(id: String, title: String, subtitle: String, artworkURL: URL?, genreNames: [String]?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.genreNames = genreNames
    }
}

// Type alias for compatibility
typealias SearchResultItem = SearchResult

// MARK: - Recently Tapped Item
struct RecentlyTappedItem: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: String?
    let type: SearchResultType
    let tappedAt: Date
    
    init(from result: any SearchResult) {
        self.id = result.id
        self.title = result.title
        self.subtitle = result.subtitle
        self.artworkURL = result.artworkURL?.absoluteString
        self.type = result.type
        self.tappedAt = Date()
    }
}

// Library view state for navigation
enum LibraryNavigationState {
    case main
    case sectionDetail
    case playlistDetail
    case searchResults
}

struct ComprehensiveSearchView: View {
    @Environment(\.promptSelectionMode) private var promptSelectionMode
    @Environment(\.onPromptSongSelected) private var onPromptSongSelected
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var selectedFilter: SearchFilter = .all
    @State private var searchResults: SearchResults = SearchResults()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @StateObject private var smartSearchManager = SmartSearchManager()
    @State private var selectedUser: UserProfile?
    @State private var selectedMusicResult: MusicSearchResult?
    @State private var selectedList: MusicList?
    @State private var selectedArtistForProfile: String?
    @State private var showArtistProfile = false
    @StateObject private var recentItemsStore = RecentItemsStore()
    
    // Tab system
    @State private var selectedTab: SearchTab = .search
    @State private var tabOffset: CGFloat = 0
    
    // Library services and state
    @StateObject private var libraryService = AppleMusicLibraryService.shared
    @StateObject private var unifiedLibraryService = UnifiedLibraryService.shared
    @StateObject private var platformPreferences = UnifiedMusicSearchService.shared
    @StateObject private var spotifyService = SpotifyService.shared
    @State private var librarySearchText = ""
    @State private var libraryViewState: LibraryNavigationState = .main
    @State private var selectedLibrarySection: LibrarySection?
    @State private var selectedPlaylist: LibraryPlaylist?
    @State private var playlistSongs: [LibraryItem] = []
    @State private var isLoadingPlaylistSongs = false
    
    // User profile navigation state
    @State private var selectedUserIdForProfile: String?
    
    // MARK: - Dynamic Tab Logic
    
    private var availableTabs: [SearchTab] {
        var tabs: [SearchTab] = [.search]
        
        let preference = platformPreferences.platformPreference
        
        switch preference {
        case .appleMusicOnly, .appleMusicPrimary:
            tabs.append(.appleMusicLibrary)
        case .spotifyOnly, .spotifyPrimary:
            if spotifyService.isUserAuthenticated {
                tabs.append(.spotifyLibrary)
            }
        case .both:
            tabs.append(.appleMusicLibrary)
            if spotifyService.isUserAuthenticated {
                tabs.append(.spotifyLibrary)
            }
        }
        
        return tabs
    }
    
    // Search functionality
    @State private var searchTask: Task<Void, Never>?
    @State private var debounceTimer: Timer?
    @State private var recentQueryChips: [String] = []
    @State private var recentlyTappedItems: [RecentlyTappedItem] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
            // Tab selector
            tabSelector
            
            // Tab content
            TabView(selection: $selectedTab) {
                        searchTabView
                    .tag(SearchTab.search)
                        
                        if availableTabs.contains(.appleMusicLibrary) {
                            appleMusicLibraryTabView
                                .tag(SearchTab.appleMusicLibrary)
                        }
                        
                        if availableTabs.contains(.spotifyLibrary) {
                            spotifyLibraryTabView
                                .tag(SearchTab.spotifyLibrary)
                        }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle(promptSelectionMode ? "Select Song" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if promptSelectionMode {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
        }
        }
        .onDisappear {
            // Cancel timers and tasks to avoid stray work
            searchTask?.cancel()
            debounceTimer?.invalidate()
        }
        .onAppear {
            // Load recent query chips
            if let data = UserDefaults.standard.array(forKey: "recent_search_queries") as? [String] {
                recentQueryChips = data
            }
            
            // Load recently tapped items
            loadRecentlyTappedItems()
            
            // Validate selected tab based on available tabs
            validateSelectedTab()
            
            // Set up library item navigation listeners
            NotificationCenter.default.addObserver(forName: NSNotification.Name("LibraryItemTapped"), object: nil, queue: .main) { note in
                if let musicResult = note.object as? MusicSearchResult {
                    // MODIFIED: Check if we're in prompt selection mode
                    if promptSelectionMode {
                        onPromptSongSelected?(musicResult)
                    } else {
                        selectedMusicResult = musicResult
                    }
                }
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("LibraryArtistTapped"), object: nil, queue: .main) { note in
                if let artistName = note.object as? String {
                    selectedArtistForProfile = artistName
                    showArtistProfile = true
                }
            }
        }
        .sheet(item: $selectedUser) { user in
            UserProfileView(userId: user.uid)
        }
        .fullScreenCover(item: $selectedMusicResult) { music in
            MusicProfileView(musicItem: music, pinnedLog: nil)
        }
        .sheet(item: $selectedList) { list in
            ListDetailView(list: list)
        }
        .fullScreenCover(isPresented: $showArtistProfile) {
            if let artistName = selectedArtistForProfile {
                ArtistProfileView(artistName: artistName)
            }
        }
        .sheet(item: Binding<IdentifiableString?>(
            get: { selectedUserIdForProfile.map(IdentifiableString.init) },
            set: { selectedUserIdForProfile = $0?.value }
        )) { userIdWrapper in
            UserProfileView(userId: userIdWrapper.value)
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
            HStack(spacing: 0) {
                ForEach(availableTabs, id: \.id) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(tab.shortName)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .medium)
                            .foregroundColor(selectedTab == tab ? .purple : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.purple : Color.clear)
                            .frame(height: 2)
                    }
                        }
                        .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Search Tab View
    private var searchTabView: some View {
        VStack(spacing: 0) {
            // Search Header (always visible)
            searchHeader
            
            // Search Content
            if searchText.isEmpty {
                emptySearchState
            } else {
                // Show results or loading, but keep search bar visible
                if isLoading {
                    SearchLoadingView()
                } else {
                    searchResultsView
                }
            }
        }
    }
    
    // MARK: - Apple Music Library Tab View
    private var appleMusicLibraryTabView: some View {
        VStack(spacing: 0) {
            // Library Header
            libraryHeader
            
            // Library Content
            switch libraryViewState {
            case .main:
                mainLibraryContent
            case .sectionDetail:
                if let section = selectedLibrarySection {
                    sectionDetailView(section)
                }
            case .playlistDetail:
            if let playlist = selectedPlaylist {
                playlistDetailView(playlist)
                }
            case .searchResults:
                librarySearchResults
            }
        }
            .onAppear {
                if libraryService.authorizationStatus == .notDetermined {
                    Task {
                        _ = await libraryService.requestAuthorization()
                    }
                } else if libraryService.authorizationStatus == .authorized && libraryService.recentlyAddedSongs.isEmpty {
                    // Load library content if authorized but not yet loaded
                    Task {
                        await libraryService.loadAllLibraryContent()
                    }
                }
            }
    }
    
    // MARK: - Spotify Library Tab View
    private var spotifyLibraryTabView: some View {
        VStack(spacing: 0) {
            // Library Header (same as Apple Music)
            libraryHeader
            
            // Spotify Library Content (matching Apple Music structure)
            spotifyMainLibraryContent
        }
        .onAppear {
            if spotifyService.isUserAuthenticated {
                Task {
                    await unifiedLibraryService.loadSpotifyLibrary()
                }
            }
        }
    }
    
    // MARK: - Library Header
    private var libraryHeader: some View {
        VStack(spacing: 16) {
            HStack {
                // Back button (when not in main view)
                if case .main = libraryViewState {
                        Text("Library")
                        .font(.largeTitle)
                    .fontWeight(.bold)
                        .foregroundColor(.primary)
            } else {
                Button(action: {
                        withAnimation {
                            libraryViewState = .main
                            selectedLibrarySection = nil
                        selectedPlaylist = nil
                            librarySearchText = ""
                        }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                        Text("Library")
                            .font(.headline)
                    }
                        .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            
            // Search bar (always visible except in section/playlist detail views)
            if libraryViewState == .main || libraryViewState == .searchResults {
                LibrarySearchBar(searchText: $librarySearchText, onSearchChanged: { query in
                    Task {
                        await libraryService.searchLibrary(query: query)
                        if !query.isEmpty && !libraryService.searchResults.isEmpty {
                            libraryViewState = .searchResults
                        } else if query.isEmpty {
                            libraryViewState = .main
                        }
                    }
                })
            }
            }
            .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - Main Library Content
    private var mainLibraryContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Authorization check
                if libraryService.authorizationStatus != .authorized {
                    authorizationRequiredView
                } else if libraryService.isLoading {
                    LibraryLoadingView()
                        .frame(height: 300)
            } else {
                    // Recently Added Section
                    if !libraryService.recentlyAddedSongs.isEmpty {
                        recentlyAddedSection
                    }
                    
                    // Library Sections
                    librarySectionsView
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await libraryService.loadAllLibraryContent()
        }
    }
    
    // MARK: - Spotify Main Library Content (matching Apple Music structure)
    private var spotifyMainLibraryContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Authorization check
                if !spotifyService.isUserAuthenticated {
                    spotifyAuthorizationRequiredView
                } else if unifiedLibraryService.isLoading {
                    LibraryLoadingView()
                        .frame(height: 300)
                } else {
                    // Recently Added Section (matching Apple Music)
                    spotifyRecentlyAddedSection
                    
                    // Library Sections (matching Apple Music)
                    spotifyLibrarySectionsView
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await unifiedLibraryService.loadSpotifyLibrary()
        }
    }
    
    // MARK: - Spotify Recently Added Section (matching Apple Music)
    private var spotifyRecentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Added")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("See All") {
                    // Handle see all action for Spotify
                    print("See all Spotify recently added")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(getSpotifyRecentlyAdded(), id: \.id) { item in
                        SpotifyRecentlyAddedCard(item: item)
                            .onTapGesture {
                                // Handle tap
                                print("Tapped Spotify item: \(item.title)")
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - Recently Added Section
    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Added")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                Button("See All") {
                    let section = LibrarySection(
                        title: "Recently Added",
                        icon: "clock",
                        color: .purple,
                        itemCount: libraryService.recentlyAddedSongs.count,
                        itemType: .song
                    )
                    selectedLibrarySection = section
                    libraryViewState = .sectionDetail
                }
                .font(.subheadline)
                .foregroundColor(.purple)
                }
                .padding(.horizontal, 20)
            
            // Apple Music style horizontal scroll for songs only
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(libraryService.recentlyAddedSongs.prefix(20)), id: \.id) { song in
                        AppleMusicSongCard(song: song) {
                            handleLibraryItemTap(song)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.trailing, 20) // Extra padding for better scroll experience
            }
        }
    }
    
    // MARK: - Spotify Library Sections View (matching Apple Music)
    private var spotifyLibrarySectionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Library")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(getSpotifyLibrarySections(), id: \.title) { section in
                    LibrarySectionCard(section: section) {
                        // Handle section tap for Spotify
                        print("Tapped Spotify section: \(section.title)")
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Library Sections View
    private var librarySectionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Library")
                    .font(.title2)
                    .fontWeight(.bold)
                        .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(getLibrarySections(), id: \.id) { section in
                    LibrarySectionCard(section: section) {
                        selectedLibrarySection = section
                        libraryViewState = .sectionDetail
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    
    // MARK: - Section Detail View
    private func sectionDetailView(_ section: LibrarySection) -> some View {
        Group {
            switch section.itemType {
            case .song:
                if section.title == "Recently Added" {
                    RecentlyAddedView(libraryService: libraryService)
            } else {
                    SongsLibraryView(libraryService: libraryService)
                }
            case .album:
                AlbumsLibraryView(libraryService: libraryService)
            case .artist:
                ArtistsLibraryView(libraryService: libraryService)
            case .playlist:
                PlaylistsView(libraryService: libraryService)
            }
        }
    }
    
    // MARK: - Playlist Detail View
    private func playlistDetailView(_ playlist: LibraryPlaylist) -> some View {
        PlaylistDetailView(playlist: playlist, libraryService: libraryService)
    }
    
    // MARK: - Library Search Results
    private var librarySearchResults: some View {
        LibrarySearchResultsView(
            libraryService: libraryService,
            searchText: librarySearchText
        )
    }
    
    // MARK: - Authorization Required View
    private var authorizationRequiredView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundColor(.purple.opacity(0.6))
                
                Text("Apple Music Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("To access your music library, please grant permission to Apple Music.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                Task {
                    _ = await libraryService.requestAuthorization()
                    if libraryService.authorizationStatus == .authorized {
                        await libraryService.loadAllLibraryContent()
                    }
                }
            }) {
                HStack(spacing: 8) {
                                Image(systemName: "music.note")
                    Text("Grant Access")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.purple)
                .cornerRadius(12)
            }
            
            if libraryService.authorizationStatus == .denied {
                VStack(spacing: 12) {
                    Text("Access Denied")
                        .font(.headline)
                    .foregroundColor(.red)
                    
                    Text("Please enable Apple Music access in Settings > Privacy & Security > Media & Apple Music")
                            .font(.caption)
                                .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Grant Access") {
                        Task {
                            _ = await libraryService.requestAuthorization()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 16) {
            // Main search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                TextField("Search for music, artists, albums...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        if !searchText.isEmpty {
                            handleSearchTextChange(searchText)
                        }
                    }
                    .onChange(of: searchText) { newValue in
                        handleSearchTextChange(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
            .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
        .padding(.horizontal, 20)
            
            // Filter pills (only when searching and not in prompt selection mode)
            if !searchText.isEmpty && !promptSelectionMode {
                filterPills
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Filter Pills
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    ModernFilterPill(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        action: {
                            selectedFilter = filter
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Empty Search State
    private var emptySearchState: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Recent searches
                if !recentQueryChips.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
            HStack {
                            Text("Recent Searches")
                                .font(.headline)
                                .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                                ForEach(recentQueryChips, id: \.self) { query in
                                    Button(query) {
                                        searchText = query
                                    }
                            .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
                // Recently tapped items (filter to songs only in prompt selection mode)
                let filteredRecentlyTapped = promptSelectionMode ? 
                    recentlyTappedItems.filter { $0.type == .song } : 
                    recentlyTappedItems
                
                if !filteredRecentlyTapped.isEmpty {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                            Text("Recently Tapped")
                    .font(.headline)
                                .fontWeight(.semibold)
                Spacer()
                }
            .padding(.horizontal, 20)
            
                        LazyVStack(spacing: 12) {
                            ForEach(filteredRecentlyTapped.prefix(10)) { item in
                                RecentlyTappedCard(item: item) {
                                    handleRecentlyTappedItemTap(item)
                        }
                    }
                }
                .padding(.horizontal, 20)
                    }
                }
                
                // Empty state message (only show if no recent content)
                if recentQueryChips.isEmpty && filteredRecentlyTapped.isEmpty {
                    VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("Search for Music")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Find songs, artists, albums, and more")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 100)
                }
                
                // Add bottom padding for scroll
                Color.clear.frame(height: 100)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(getFilteredResults(), id: \.id) { result in
                    SearchResultCard(result: result) {
                        handleResultTap(result)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Spotify Helper Methods
    private func getSpotifyLibrarySections() -> [LibrarySection] {
        // MODIFIED: In prompt selection mode, show songs and playlists
        if promptSelectionMode {
            return [
                LibrarySection(
                    title: "Songs",
                    icon: "music.note",
                    color: .blue,
                    itemCount: unifiedLibraryService.getSpotifySavedTracks().count,
                    itemType: .song
                ),
                LibrarySection(
                    title: "Playlists",
                    icon: "music.note.list",
                    color: .purple,
                    itemCount: unifiedLibraryService.getSpotifyPlaylists().count,
                    itemType: .playlist
                )
            ]
        }
        
        // Regular Spotify library sections for main search
        return [
            LibrarySection(
                title: "Songs",
                icon: "music.note",
                color: .blue,
                itemCount: unifiedLibraryService.getSpotifySavedTracks().count,
                itemType: .song
            ),
            LibrarySection(
                title: "Albums",
                icon: "opticaldisc",
                color: .orange,
                itemCount: getDemoSpotifyAlbumsCount(),
                itemType: .album
            ),
            LibrarySection(
                title: "Artists",
                icon: "person.wave.2",
                color: .green,
                itemCount: getDemoSpotifyArtistsCount(),
                itemType: .artist
            ),
            LibrarySection(
                title: "Playlists",
                icon: "music.note.list",
                color: .purple,
                itemCount: unifiedLibraryService.getSpotifyPlaylists().count,
                itemType: .playlist
            )
        ]
    }
    
    private func getSpotifyRecentlyAdded() -> [MusicSearchResult] {
        // Return demo data for recently added Spotify songs only
        return [
            MusicSearchResult(
                id: "spotify_recent_1",
                title: "As It Was",
                artistName: "Harry Styles",
                albumName: "Harry's House",
                artworkURL: nil,
                itemType: "song",
                popularity: 95
            ),
            MusicSearchResult(
                id: "spotify_recent_2",
                title: "Heat Waves",
                artistName: "Glass Animals",
                albumName: "Dreamland",
                artworkURL: nil,
                itemType: "song",
                popularity: 89
            ),
            MusicSearchResult(
                id: "spotify_recent_3",
                title: "Good 4 U",
                artistName: "Olivia Rodrigo",
                albumName: "SOUR",
                artworkURL: nil,
                itemType: "song",
                popularity: 88
            )
        ]
    }
    
    private var spotifyAuthorizationRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Connect Your Spotify Account")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Connect your Spotify account to see your saved songs, playlists, and personal library.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await spotifyService.authenticateUser()
                }
            }) {
                HStack {
                    Image(systemName: "music.note.list")
                    Text("Connect to Spotify")
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
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Methods
    private func getLibrarySections() -> [LibrarySection] {
        // MODIFIED: In prompt selection mode, show songs and playlists
        if promptSelectionMode {
            return [
                LibrarySection(
                    title: "Songs",
                    icon: "music.note",
                    color: .blue,
                    itemCount: libraryService.librarySongs.count,
                    itemType: .song
                ),
                LibrarySection(
                    title: "Playlists",
                    icon: "music.note.list",
                    color: .purple,
                    itemCount: libraryService.enabledPlaylists.count,
                    itemType: .playlist
                )
            ]
        }
        
        // Regular library sections for main search
        return [
            LibrarySection(
                title: "Songs",
                icon: "music.note",
                color: .blue,
                itemCount: libraryService.librarySongs.count,
                itemType: .song
            ),
            LibrarySection(
                title: "Albums",
                icon: "opticaldisc",
                color: .orange,
                itemCount: libraryService.libraryAlbums.count,
                itemType: .album
            ),
            LibrarySection(
                title: "Artists",
                icon: "person.wave.2",
                color: .green,
                itemCount: libraryService.libraryArtists.count,
                itemType: .artist
            ),
            LibrarySection(
                title: "Playlists",
                icon: "music.note.list",
                color: .purple,
                itemCount: libraryService.enabledPlaylists.count,
                itemType: .playlist
            )
        ]
    }
    
    private func handleLibraryItemTap(_ item: LibraryItem) {
        let musicResult = item.toMusicSearchResult()
        
        // Add to recent items
        let recentItem = RecentItem(
            type: RecentItemType(rawValue: item.itemType.rawValue) ?? .song,
            itemId: item.id,
            title: item.title,
            subtitle: item.artistName,
            artworkURL: item.artworkURL
        )
        recentItemsStore.upsert(recentItem)
        
        // Navigate to profile
        if item.itemType == .artist {
            selectedArtistForProfile = item.artistName
            showArtistProfile = true
                    } else {
            selectedMusicResult = musicResult
        }
    }
    
    private func handleSearchTextChange(_ newValue: String) {
        debounceTimer?.invalidate()
        
        if newValue.isEmpty {
            searchResults = SearchResults()
            isLoading = false
            return
        }
        
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            performSearch(query: newValue)
        }
    }
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        searchTask = Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let results = try await searchAppleMusic(query: query)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchResults = results
                        self.addToRecentSearches(query)
            }
                }
        } catch {
                if !Task.isCancelled {
                await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.searchResults = SearchResults()
            }
        }
    }
    
            if !Task.isCancelled {
        await MainActor.run {
                self.isLoading = false
                }
            }
        }
    }
    
    private func searchAppleMusic(query: String) async throws -> SearchResults {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SearchResults()
        }
        
        // Search Apple Music catalog
        var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self, MusicKit.Artist.self, MusicKit.Album.self])
        request.limit = 25
        
                let response = try await request.response()
                
        // Helper to normalize titles for deduplication
        func normalizeTitle(_ title: String) -> String {
            return title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Process songs with deduplication
        var songResults: [any SearchResult] = []
        var seenSongs: Set<String> = []
        
        for song in response.songs {
            let normalizedTitle = normalizeTitle(song.title)
            let normalizedArtist = normalizeTitle(song.artistName)
            let key = "\(normalizedTitle)|\(normalizedArtist)"
            
            if !seenSongs.contains(key) {
                seenSongs.insert(key)
                songResults.append(MusicSongResult(from: song))
            }
        }
        
        // Process artists
        let artistResults: [any SearchResult] = response.artists.map { artist in
            MusicArtistResult(from: artist)
        }
        
        // Process albums
        // Deduplicate albums similar to songs
        var albumResults: [any SearchResult] = []
        var seenAlbums: Set<String> = []

        func normalizeAlbumTitle(_ title: String) -> String {
            // Basic normalization + removal of edition qualifiers
            var t = normalizeTitle(title)
            t = t.replacingOccurrences(of: "\\s*\\((deluxe|clean|explicit|remaster(ed)?|expanded|edition|version|single|ep|anniversary|special|limited|bonus)[^)]*\\)", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\s*-\\s*(single|ep|deluxe|clean|explicit|expanded|edition|version|remaster(ed)?|anniversary|special|limited|bonus)\\s*$", with: "", options: .regularExpression)
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for album in response.albums {
            let normTitle = normalizeAlbumTitle(album.title)
            let normArtist = normalizeTitle(album.artistName)
            let key = "\(normTitle)|\(normArtist)"
            if !seenAlbums.contains(key) {
                seenAlbums.insert(key)
                albumResults.append(MusicAlbumResult(from: album))
            }
        }
        
        // Create results structure
        var results = SearchResults()
        results.songs = songResults
        results.artists = artistResults
        results.albums = albumResults
        
        return results
    }
    
    private func addToRecentSearches(_ query: String) {
        var recent = recentQueryChips
        recent.removeAll { $0 == query }
        recent.insert(query, at: 0)
        recentQueryChips = Array(recent.prefix(5))
        UserDefaults.standard.set(recentQueryChips, forKey: "recent_search_queries")
    }
    
    private func getFilteredResults() -> [any SearchResult] {
        // MODIFIED: In prompt selection mode, only show songs
        if promptSelectionMode {
            return searchResults.songs
        }
        
        // Regular filtering for main search
        switch selectedFilter {
        case .all:
            // Use smart prioritization for "All" results
            return searchResults.prioritized(for: searchText)
        case .songs:
            return searchResults.songs
        case .albums:
            return searchResults.albums
        case .artists:
            return searchResults.artists
        case .users:
            return searchResults.users
        case .lists:
            return searchResults.lists
        }
    }
    
    private func getResultCount(for filter: SearchFilter) -> Int {
        switch filter {
        case .all:
            return searchResults.all.count
        case .songs:
            return searchResults.songs.count
        case .albums:
            return searchResults.albums.count
        case .artists:
            return searchResults.artists.count
        case .users:
            return searchResults.users.count
        case .lists:
            return searchResults.lists.count
        }
    }
    
    private func handleResultTap(_ result: any SearchResult) {
        print("🎯 Search result tapped: \(result.title) (type: \(result.type.rawValue))")
        
        // Add to recent items
        let recentItem = RecentItem(
            type: RecentItemType(rawValue: result.type.rawValue) ?? .song,
            itemId: result.id,
            title: result.title,
            subtitle: result.subtitle,
            artworkURL: result.artworkURL?.absoluteString
        )
        recentItemsStore.upsert(recentItem)
        
        // Add to recently tapped items
        addToRecentlyTapped(result)
        
        // MODIFIED: Check if we're in prompt selection mode
        if promptSelectionMode {
            // Convert SearchResult to MusicSearchResult for prompt selection
            let musicResult = MusicSearchResult(
                id: result.id,
                title: result.title,
                artistName: result.subtitle,
                albumName: (result as? MusicSongResult)?.albumName ?? (result as? MusicAlbumResult)?.title ?? "",
                artworkURL: result.artworkURL?.absoluteString,
                itemType: result.type.rawValue,
                popularity: 0
            )
            
            // Call the prompt selection callback
            onPromptSongSelected?(musicResult)
            return
        }
        
        // Regular navigation behavior
        switch result.type {
        case .song, .album:
            // Convert SearchResult to MusicSearchResult for compatibility
            let musicResult = MusicSearchResult(
                id: result.id,
                title: result.title,
                artistName: result.subtitle,
                albumName: (result as? MusicSongResult)?.albumName ?? (result as? MusicAlbumResult)?.title ?? "",
                artworkURL: result.artworkURL?.absoluteString,
                itemType: result.type.rawValue,
                    popularity: 0
                )
            print("🎯 Setting selectedMusicResult: \(musicResult.title)")
            selectedMusicResult = musicResult
        case .artist:
            print("🎯 Setting selectedArtistForProfile: \(result.title)")
            selectedArtistForProfile = result.title
            showArtistProfile = true
        case .user:
            // User search results not implemented yet
            print("⚠️ User search results not implemented yet")
            break
        case .list:
            // List search results not implemented yet
            print("⚠️ List search results not implemented yet")
            break
        }
    }
    
    // MARK: - Recently Tapped Helper Functions
    private func addToRecentlyTapped(_ result: any SearchResult) {
        let tappedItem = RecentlyTappedItem(from: result)
        
        // Remove existing item with same ID if it exists
        recentlyTappedItems.removeAll { $0.id == tappedItem.id }
        
        // Add to beginning of array
        recentlyTappedItems.insert(tappedItem, at: 0)
        
        // Keep only the most recent 20 items
        if recentlyTappedItems.count > 20 {
            recentlyTappedItems = Array(recentlyTappedItems.prefix(20))
        }
        
        // Save to UserDefaults
        saveRecentlyTappedItems()
        
        print("🔖 Added to recently tapped: \(result.title) (type: \(result.type.rawValue))")
    }
    
    private func handleRecentlyTappedItemTap(_ item: RecentlyTappedItem) {
        print("🔖 Recently tapped item tapped: \(item.title) (type: \(item.type.rawValue))")
        
        // Move this item to the front
        recentlyTappedItems.removeAll { $0.id == item.id }
        recentlyTappedItems.insert(item, at: 0)
        saveRecentlyTappedItems()
        
        // MODIFIED: Check if we're in prompt selection mode
        if promptSelectionMode {
            let musicResult = MusicSearchResult(
                id: item.id,
                title: item.title,
                artistName: item.subtitle,
                albumName: item.type == .album ? item.title : "",
                artworkURL: item.artworkURL,
                itemType: item.type.rawValue,
                popularity: 0
            )
            onPromptSongSelected?(musicResult)
            return
        }
        
        // Regular navigation behavior
        switch item.type {
        case .song, .album:
            let musicResult = MusicSearchResult(
                id: item.id,
                title: item.title,
                artistName: item.subtitle,
                albumName: item.type == .album ? item.title : "",
                artworkURL: item.artworkURL,
                itemType: item.type.rawValue,
                popularity: 0
            )
            selectedMusicResult = musicResult
        case .artist:
            selectedArtistForProfile = item.title
            showArtistProfile = true
        case .user:
            // User profile navigation not implemented yet
            break
        case .list:
            // List navigation not implemented yet
            break
        }
    }
    
    private func saveRecentlyTappedItems() {
        if let encoded = try? JSONEncoder().encode(recentlyTappedItems) {
            UserDefaults.standard.set(encoded, forKey: "recently_tapped_items")
        }
    }
    
    private func loadRecentlyTappedItems() {
        if let data = UserDefaults.standard.data(forKey: "recently_tapped_items"),
           let decoded = try? JSONDecoder().decode([RecentlyTappedItem].self, from: data) {
            recentlyTappedItems = decoded
        }
    }
    
    private func validateSelectedTab() {
        // Ensure selected tab is available based on platform preferences
        if !availableTabs.contains(selectedTab) {
            selectedTab = availableTabs.first ?? .search
        }
    }
    
    // MARK: - Spotify Library Components
    
    private var spotifyLibraryHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Search bar for Spotify library (matching Apple Music design)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                
                TextField("Search your library", text: $librarySearchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !librarySearchText.isEmpty {
                    Button(action: {
                        librarySearchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    private var spotifyNotConnectedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Connect Your Spotify Account")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Connect your Spotify account to see your saved songs, playlists, and personal library.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    let success = await spotifyService.authenticateUser()
                    if success {
                        await unifiedLibraryService.loadSpotifyLibrary()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "music.note.list")
                    Text("Connect to Spotify")
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
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var spotifyLibraryContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Recently Added Section (Spotify equivalent)
                SpotifyRecentlyAddedView()
                
                // Your Spotify Library - 4 sections matching Apple Music layout
                VStack(spacing: 16) {
                    HStack {
                        Text("Your Library")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // 2x2 grid matching Apple Music library layout
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        // Songs section
                        SpotifyLibrarySectionCard(
                            icon: "music.note",
                            title: "Songs",
                            count: unifiedLibraryService.getSpotifySavedTracks().count,
                            color: .blue,
                            action: {
                                // Navigate to Spotify songs view
                                print("Navigate to Spotify songs")
                            }
                        )
                        
                        // Albums section  
                        SpotifyLibrarySectionCard(
                            icon: "opticaldisc",
                            title: "Albums",
                            count: getDemoSpotifyAlbumsCount(),
                            color: .orange,
                            action: {
                                // Navigate to Spotify albums view
                                print("Navigate to Spotify albums")
                            }
                        )
                        
                        // Artists section
                        SpotifyLibrarySectionCard(
                            icon: "person.fill",
                            title: "Artists",
                            count: getDemoSpotifyArtistsCount(),
                            color: .green,
                            action: {
                                // Navigate to Spotify artists view
                                print("Navigate to Spotify artists")
                            }
                        )
                        
                        // Playlists section
                        SpotifyLibrarySectionCard(
                            icon: "music.note.list",
                            title: "Playlists",
                            count: unifiedLibraryService.getSpotifyPlaylists().count,
                            color: .purple,
                            action: {
                                // Navigate to Spotify playlists view
                                print("Navigate to Spotify playlists")
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Demo Data Helpers
    
    private func getDemoSpotifyAlbumsCount() -> Int {
        return 24 // Demo count for Spotify albums
    }
    
    private func getDemoSpotifyArtistsCount() -> Int {
        return 18 // Demo count for Spotify artists
    }
}

struct SpotifyRecentlyAddedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recently Added")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button("See All") {
                    print("See all recently added Spotify music")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(getDemoSpotifyRecentlyAdded(), id: \.id) { item in
                        SpotifyRecentlyAddedCard(item: item)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func getDemoSpotifyRecentlyAdded() -> [MusicSearchResult] {
        return [
            MusicSearchResult(
                id: "spotify_recent_1",
                title: "As It Was",
                artistName: "Harry Styles",
                albumName: "Harry's House",
                artworkURL: nil,
                itemType: "song",
                popularity: 92
            ),
            MusicSearchResult(
                id: "spotify_recent_2",
                title: "Heat Waves",
                artistName: "Glass Animals",
                albumName: "Dreamland",
                artworkURL: nil,
                itemType: "album",
                popularity: 88
            ),
            MusicSearchResult(
                id: "spotify_recent_3",
                title: "Bad Bunny",
                artistName: "Bad Bunny",
                albumName: "",
                artworkURL: nil,
                itemType: "artist",
                popularity: 96
            )
        ]
    }
}

struct SpotifyRecentlyAddedCard: View {
    let item: MusicSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork (matching Apple Music design exactly)
            if let artworkUrl = item.artworkURL, let url = URL(string: artworkUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .frame(width: 100, height: 100)
                .cornerRadius(item.itemType == "artist" ? 50 : 6)
                .clipped()
            } else {
                artworkPlaceholder
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(item.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 100)
    }
    
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: item.itemType == "artist" ? 50 : 6)
            .fill(Color(.systemGray4))
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: getIcon(for: item.itemType))
                    .font(.title2)
                    .foregroundColor(.secondary)
            )
    }
    
    private func getIcon(for type: String) -> String {
        switch type {
        case "song": return "music.note"
        case "album": return "opticaldisc"
        case "artist": return "person.fill"
        default: return "music.note"
        }
    }
}

struct SpotifyLibrarySectionCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon with Spotify-themed background
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // Show count like Apple Music library
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SpotifyPlaylistCard: View {
    let playlist: UnifiedLibraryService.UnifiedPlaylist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Playlist artwork placeholder matching Apple Music design
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray4))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "music.note.list")
                        .font(.title)
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("\(playlist.trackCount) songs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120)
    }
}

struct SpotifySongRow: View {
    let song: MusicSearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Song artwork placeholder matching Apple Music design
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray4))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(song.artistName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


#Preview {
    ComprehensiveSearchView()
} 
