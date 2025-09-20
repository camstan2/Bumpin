import Foundation
import SwiftUI

// MARK: - Library Item Types
enum LibraryItemType: String, CaseIterable, Codable {
    case song = "song"
    case album = "album"
    case artist = "artist"
    case playlist = "playlist"
    
    var displayName: String {
        switch self {
        case .song: return "Song"
        case .album: return "Album"
        case .artist: return "Artist"
        case .playlist: return "Playlist"
        }
    }
    
    var icon: String {
        switch self {
        case .song: return "music.note"
        case .album: return "opticaldisc"
        case .artist: return "person.wave.2"
        case .playlist: return "music.note.list"
        }
    }
    
    var color: Color {
        switch self {
        case .song: return .blue
        case .album: return .orange
        case .artist: return .green
        case .playlist: return .purple
        }
    }
}

// MARK: - Library Item Model
struct LibraryItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artistName: String
    let albumName: String?
    let artworkURL: String?
    let itemType: LibraryItemType
    let dateAdded: Date?
    
    init(id: String, title: String, artistName: String, albumName: String? = nil, artworkURL: String? = nil, itemType: LibraryItemType, dateAdded: Date? = nil) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURL = artworkURL
        self.itemType = itemType
        self.dateAdded = dateAdded
    }
    
    // Convert to MusicSearchResult for compatibility with existing profile views
    func toMusicSearchResult() -> MusicSearchResult {
        return MusicSearchResult(
            id: id,
            title: title,
            artistName: artistName,
            albumName: albumName ?? "",
            artworkURL: artworkURL,
            itemType: itemType.rawValue,
            popularity: 0
        )
    }
}

// MARK: - Library Playlist Model
struct LibraryPlaylist: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String?
    let artworkURL: String?
    let songCount: Int
    let curatorName: String?
    let isUserCreated: Bool
    let dateAdded: Date?
    var lastPlayedDate: Date? // For Apple Music-style recent ordering
    
    init(id: String, name: String, description: String? = nil, artworkURL: String? = nil, songCount: Int = 0, curatorName: String? = nil, isUserCreated: Bool = true, dateAdded: Date? = nil, lastPlayedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.artworkURL = artworkURL
        self.songCount = songCount
        self.curatorName = curatorName
        self.isUserCreated = isUserCreated
        self.dateAdded = dateAdded ?? Date()
        self.lastPlayedDate = lastPlayedDate
    }
    
    var displaySubtitle: String {
        if let curator = curatorName, !isUserCreated {
            return "\(curator) • \(songCount) songs"
        }
        return "\(songCount) songs"
    }
    
    // Convert to MusicSearchResult for compatibility
    func toMusicSearchResult() -> MusicSearchResult {
        return MusicSearchResult(
            id: id,
            title: name,
            artistName: displaySubtitle,
            albumName: "",
            artworkURL: artworkURL,
            itemType: "playlist",
            popularity: 0
        )
    }
    
    // Convert to LibraryItem for consistency
    func toLibraryItem() -> LibraryItem {
        return LibraryItem(
            id: id,
            title: name,
            artistName: displaySubtitle,
            albumName: nil,
            artworkURL: artworkURL,
            itemType: .playlist,
            dateAdded: dateAdded
        )
    }
}

// MARK: - Library Section Model
struct LibrarySection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let itemCount: Int
    let itemType: LibraryItemType
    
    init(title: String, icon: String, color: Color, itemCount: Int, itemType: LibraryItemType) {
        self.id = itemType.rawValue
        self.title = title
        self.icon = icon
        self.color = color
        self.itemCount = itemCount
        self.itemType = itemType
    }
    
    var displayCount: String {
        if itemCount > 0 {
            return "\(itemCount)"
        }
        return ""
    }
}

// MARK: - Library Sort Options
enum LibrarySortOption: String, CaseIterable {
    case recentlyAdded = "Recently Added"
    case alphabetical = "A to Z"
    case artist = "Artist"
    case mostPlayed = "Most Played"
    case dateAdded = "Date Added"
    
    var icon: String {
        switch self {
        case .recentlyAdded: return "clock"
        case .alphabetical: return "textformat.abc"
        case .artist: return "person.fill"
        case .mostPlayed: return "play.fill"
        case .dateAdded: return "calendar"
        }
    }
    
    func sort<T: LibraryItemSortable>(_ items: [T]) -> [T] {
        switch self {
        case .recentlyAdded:
            return items.sorted { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
        case .alphabetical:
            return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return items.sorted { $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending }
        case .mostPlayed:
            // For now, just return original order - would need play count data
            return items
        case .dateAdded:
            return items.sorted { ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast) }
        }
    }
}

// MARK: - Protocol for sortable library items
protocol LibraryItemSortable {
    var title: String { get }
    var artistName: String { get }
    var dateAdded: Date? { get }
}

extension LibraryItem: LibraryItemSortable {}
extension LibraryPlaylist: LibraryItemSortable {
    var title: String { name }
    var artistName: String { curatorName ?? "" }
}

// LibraryViewState is defined in ComprehensiveSearchView.swift

// MARK: - Playlist Optimization
struct PlaylistOptimizationSuggestion: Identifiable {
    let id = UUID()
    let playlist: LibraryPlaylist
    let type: SuggestionType
    let reason: String
    
    enum SuggestionType {
        case disableLarge
        case disableEmpty
        case enableRecent
        case enablePopular
        
        var actionTitle: String {
            switch self {
            case .disableLarge: return "Disable"
            case .disableEmpty: return "Disable"
            case .enableRecent: return "Enable"
            case .enablePopular: return "Enable"
            }
        }
        
        var color: Color {
            switch self {
            case .disableLarge, .disableEmpty: return .red
            case .enableRecent, .enablePopular: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .disableLarge: return "bolt.slash.fill"
            case .disableEmpty: return "trash.fill"
            case .enableRecent: return "clock.fill"
            case .enablePopular: return "star.fill"
            }
        }
    }
}
