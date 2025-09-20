import Foundation
import SwiftUI

// MARK: - Unified Library Service (Demo Implementation)

@MainActor
class UnifiedLibraryService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var spotifyLibraryData: SpotifyLibraryData = SpotifyLibraryData()
    
    // MARK: - Library Data Models
    
    struct SpotifyLibraryData {
        var savedTracks: [SpotifyService.SpotifyTrack] = []
        var playlists: [SpotifyService.SpotifyPlaylist] = []
        var isLoaded: Bool = false
    }
    
    struct UnifiedPlaylist {
        let id: String
        let name: String
        let description: String?
        let trackCount: Int
        let artworkURL: String?
        let platform: String // "apple_music" or "spotify"
        let isPublic: Bool
    }
    
    // MARK: - Services
    private let spotifyService = SpotifyService.shared
    
    // MARK: - Singleton
    static let shared = UnifiedLibraryService()
    
    private init() {}
    
    // MARK: - Main Library Loading
    
    func loadSpotifyLibrary() async {
        guard spotifyService.isUserAuthenticated else {
            print("ℹ️ Spotify user not authenticated - using demo data")
            loadDemoSpotifyLibrary()
            return
        }
        
        isLoading = true
        
        let playlists = await spotifyService.getUserPlaylists()
        let savedTracks = await spotifyService.getSavedTracks()
        
        spotifyLibraryData = SpotifyLibraryData(
            savedTracks: savedTracks,
            playlists: playlists,
            isLoaded: true
        )
        
        isLoading = false
        print("🎵 Spotify library loaded: \(savedTracks.count) saved tracks, \(playlists.count) playlists")
    }
    
    private func loadDemoSpotifyLibrary() {
        let demoData = spotifyService.getDemoLibraryData()
        spotifyLibraryData = SpotifyLibraryData(
            savedTracks: demoData.savedTracks,
            playlists: demoData.playlists,
            isLoaded: true
        )
        print("🎵 Loaded demo Spotify library: \(demoData.savedTracks.count) tracks, \(demoData.playlists.count) playlists")
    }
    
    // MARK: - Library Access Methods
    
    func getSpotifyPlaylists() -> [UnifiedPlaylist] {
        return spotifyLibraryData.playlists.map { playlist in
            UnifiedPlaylist(
                id: playlist.id,
                name: playlist.name,
                description: playlist.description,
                trackCount: playlist.tracks.total,
                artworkURL: playlist.images?.first?.url,
                platform: "spotify",
                isPublic: playlist.`public` ?? false
            )
        }
    }
    
    func getSpotifySavedTracks() -> [MusicSearchResult] {
        return spotifyLibraryData.savedTracks.map { track in
            MusicSearchResult(
                id: track.id,
                title: track.name,
                artistName: track.artists.first?.name ?? "",
                albumName: track.album.name,
                artworkURL: track.album.images.first?.url,
                itemType: "song",
                popularity: track.popularity
            )
        }
    }
    
    // MARK: - Library Stats
    
    func getSpotifyLibraryStats() -> (savedTracks: Int, playlists: Int) {
        return (
            savedTracks: spotifyLibraryData.savedTracks.count,
            playlists: spotifyLibraryData.playlists.count
        )
    }
    
    var hasSpotifyLibraryData: Bool {
        return spotifyLibraryData.isLoaded && (!spotifyLibraryData.savedTracks.isEmpty || !spotifyLibraryData.playlists.isEmpty)
    }
}