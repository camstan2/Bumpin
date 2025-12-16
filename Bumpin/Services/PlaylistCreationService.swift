//
//  PlaylistCreationService.swift
//  Bumpin
//
//  Handles playlist creation for Apple Music and Spotify
//

import Foundation
import MusicKit
import FirebaseAuth
import UIKit

class PlaylistCreationService: ObservableObject {
    
    static let shared = PlaylistCreationService()
    
    private init() {}
    
    // MARK: - Result Types
    
    struct PlaylistCreationResult {
        let success: Bool
        let playlistId: String?
        let playlistName: String
        let platform: String
        let totalSongs: Int
        let addedSongs: Int
        let skippedSongs: Int
        let error: Error?
        
        var skippedMessage: String? {
            guard skippedSongs > 0 else { return nil }
            return "\(skippedSongs) song\(skippedSongs == 1 ? "" : "s") could not be added"
        }
    }
    
    enum PlaylistCreationError: LocalizedError {
        case notAuthenticated
        case noSongsFound
        case creationFailed
        case addTracksFailed(addedCount: Int, totalCount: Int)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Please connect your account in Settings"
            case .noSongsFound:
                return "No songs found in this list"
            case .creationFailed:
                return "Failed to create playlist"
            case .addTracksFailed(let added, let total):
                return "Only \(added) of \(total) songs were added"
            }
        }
    }
    
    // MARK: - Authentication Checks
    
    func isAppleMusicAuthenticated() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }
    
    func isSpotifyAuthenticated() -> Bool {
        let spotifyService = SpotifyService.shared
        return spotifyService.userAccessToken != nil && spotifyService.currentUser != nil
    }
    
    // MARK: - Song Filtering
    
    func filterSongsFromList(_ list: MusicList) -> [MusicSearchResult] {
        var songs: [MusicSearchResult] = []
        
        for itemString in list.items {
            guard let data = itemString.data(using: .utf8),
                  let item = try? JSONDecoder().decode(MusicSearchResult.self, from: data) else {
                continue
            }
            
            // Only include songs
            if item.itemType.lowercased() == "song" {
                songs.append(item)
            }
        }
        
        print("📝 Filtered \(songs.count) songs from \(list.items.count) total items")
        return songs
    }
    
    // MARK: - Apple Music Playlist Creation
    
    func createAppleMusicPlaylist(name: String, songs: [MusicSearchResult]) async -> PlaylistCreationResult {
        print("🍎 Creating Apple Music playlist: \(name)")
        
        // Check authentication
        guard await isAppleMusicAuthenticated() else {
            return PlaylistCreationResult(
                success: false,
                playlistId: nil,
                playlistName: name,
                platform: "Apple Music",
                totalSongs: songs.count,
                addedSongs: 0,
                skippedSongs: songs.count,
                error: PlaylistCreationError.notAuthenticated
            )
        }
        
        guard !songs.isEmpty else {
            return PlaylistCreationResult(
                success: false,
                playlistId: nil,
                playlistName: name,
                platform: "Apple Music",
                totalSongs: 0,
                addedSongs: 0,
                skippedSongs: 0,
                error: PlaylistCreationError.noSongsFound
            )
        }
        
        do {
            // Create the playlist
            let playlist = try await MusicLibrary.shared.createPlaylist(name: name, description: nil)
            print("✅ Created Apple Music playlist: \(playlist.id.rawValue)")
            
            // Convert songs to MusicItemIDs and collect valid tracks
            var trackIDs: [MusicItemID] = []
            var skippedCount = 0
            
            for song in songs {
                // Check if this is an Apple Music item (has valid Apple Music ID)
                if let platform = song.platform?.lowercased(),
                   platform.contains("apple"),
                   !song.id.isEmpty {
                    // Add the ID to our collection
                    trackIDs.append(MusicItemID(song.id))
                } else {
                    print("⚠️ Skipping non-Apple Music song: \(song.title)")
                    skippedCount += 1
                }
            }
            
            // Fetch Song objects from catalog and add to playlist
            if !trackIDs.isEmpty {
                do {
                    // Add songs one by one to the playlist using their IDs
                    for trackID in trackIDs {
                        do {
                            // Fetch the song from catalog
                            let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: trackID)
                            let response = try await request.response()
                            
                            if let song = response.items.first {
                                try await MusicLibrary.shared.add(song, to: playlist)
                                print("✅ Added song: \(song.title)")
                            } else {
                                print("⚠️ Could not fetch song with ID: \(trackID)")
                                skippedCount += 1
                            }
                        } catch {
                            print("⚠️ Error adding song with ID \(trackID): \(error)")
                            skippedCount += 1
                        }
                    }
                    
                    let addedCount = trackIDs.count - skippedCount
                    print("✅ Added \(addedCount) songs to playlist")
                } catch {
                    print("⚠️ Error adding songs to playlist: \(error)")
                    // If adding failed, consider all as skipped
                    skippedCount = songs.count
                }
            }
            
            return PlaylistCreationResult(
                success: true,
                playlistId: playlist.id.rawValue,
                playlistName: name,
                platform: "Apple Music",
                totalSongs: songs.count,
                addedSongs: max(0, trackIDs.count - skippedCount),
                skippedSongs: skippedCount,
                error: nil
            )
            
        } catch {
            print("❌ Failed to create Apple Music playlist: \(error)")
            return PlaylistCreationResult(
                success: false,
                playlistId: nil,
                playlistName: name,
                platform: "Apple Music",
                totalSongs: songs.count,
                addedSongs: 0,
                skippedSongs: songs.count,
                error: error
            )
        }
    }
    
    // MARK: - Spotify Playlist Creation
    
    func createSpotifyPlaylist(name: String, songs: [MusicSearchResult]) async -> PlaylistCreationResult {
        print("🎵 Creating Spotify playlist: \(name)")
        
        let spotifyService = SpotifyService.shared
        
        // Check authentication
        guard isSpotifyAuthenticated(),
              let userId = spotifyService.currentUser?.id,
              let accessToken = spotifyService.userAccessToken else {
            return PlaylistCreationResult(
                success: false,
                playlistId: nil,
                playlistName: name,
                platform: "Spotify",
                totalSongs: songs.count,
                addedSongs: 0,
                skippedSongs: songs.count,
                error: PlaylistCreationError.notAuthenticated
            )
        }
        
        guard !songs.isEmpty else {
            return PlaylistCreationResult(
                success: false,
                playlistId: nil,
                playlistName: name,
                platform: "Spotify",
                totalSongs: 0,
                addedSongs: 0,
                skippedSongs: 0,
                error: PlaylistCreationError.noSongsFound
            )
        }
        
        do {
            // Step 1: Create the playlist
            let createURL = URL(string: "https://api.spotify.com/v1/users/\(userId)/playlists")!
            var createRequest = URLRequest(url: createURL)
            createRequest.httpMethod = "POST"
            createRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let playlistData: [String: Any] = [
                "name": name,
                "public": false,
                "description": "Created from Bumpin"
            ]
            createRequest.httpBody = try JSONSerialization.data(withJSONObject: playlistData)
            
            let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
            
            guard let httpResponse = createResponse as? HTTPURLResponse,
                  httpResponse.statusCode == 201 else {
                throw PlaylistCreationError.creationFailed
            }
            
            let createdPlaylist = try JSONDecoder().decode(SpotifyService.SpotifyPlaylist.self, from: createData)
            print("✅ Created Spotify playlist: \(createdPlaylist.id)")
            
            // Step 2: Collect valid Spotify track URIs
            var trackURIs: [String] = []
            var skippedCount = 0
            
            for song in songs {
                // Check if this is a Spotify item
                if let platform = song.platform?.lowercased(),
                   platform.contains("spotify"),
                   !song.id.isEmpty {
                    trackURIs.append("spotify:track:\(song.id)")
                } else {
                    // Try to search for the song on Spotify
                    print("🔍 Searching Spotify for: \(song.title) by \(song.artistName)")
                    let searchResults = await spotifyService.searchTracks(query: "\(song.title) \(song.artistName)")
                    
                    if let firstResult = searchResults.first {
                        trackURIs.append("spotify:track:\(firstResult.id)")
                        print("✅ Found match: \(firstResult.name)")
                    } else {
                        print("⚠️ No match found for: \(song.title)")
                        skippedCount += 1
                    }
                }
            }
            
            // Step 3: Add tracks to playlist (in batches of 100)
            if !trackURIs.isEmpty {
                let batchSize = 100
                for i in stride(from: 0, to: trackURIs.count, by: batchSize) {
                    let batch = Array(trackURIs[i..<min(i + batchSize, trackURIs.count)])
                    
                    let addURL = URL(string: "https://api.spotify.com/v1/playlists/\(createdPlaylist.id)/tracks")!
                    var addRequest = URLRequest(url: addURL)
                    addRequest.httpMethod = "POST"
                    addRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    addRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let tracksData: [String: Any] = ["uris": batch]
                    addRequest.httpBody = try JSONSerialization.data(withJSONObject: tracksData)
                    
                    let (_, addResponse) = try await URLSession.shared.data(for: addRequest)
                    
                    guard let httpResponse = addResponse as? HTTPURLResponse,
                          httpResponse.statusCode == 201 else {
                        print("⚠️ Failed to add batch of tracks")
                        continue
                    }
                }
                
                print("✅ Added \(trackURIs.count) tracks to Spotify playlist")
            }
            
            return PlaylistCreationResult(
                success: true,
                playlistId: createdPlaylist.id,
                playlistName: name,
                platform: "Spotify",
                totalSongs: songs.count,
                addedSongs: trackURIs.count,
                skippedSongs: skippedCount,
                error: nil
            )
            
        } catch {
            print("❌ Failed to create Spotify playlist: \(error)")
            return PlaylistCreationResult(
                success: false,
                playlistId: nil,
                playlistName: name,
                platform: "Spotify",
                totalSongs: songs.count,
                addedSongs: 0,
                skippedSongs: songs.count,
                error: error
            )
        }
    }
    
    // MARK: - Deep Link Helpers
    
    func openAppleMusicPlaylist(playlistId: String) {
        let urlString = "music://music.apple.com/library/playlist/\(playlistId)"
        if let url = URL(string: urlString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    func openSpotifyPlaylist(playlistId: String) {
        let urlString = "spotify:playlist:\(playlistId)"
        if let url = URL(string: urlString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to web
            let webUrl = URL(string: "https://open.spotify.com/playlist/\(playlistId)")!
            UIApplication.shared.open(webUrl)
        }
    }
}

