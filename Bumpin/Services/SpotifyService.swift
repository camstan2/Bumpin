import Foundation
import SwiftUI

// MARK: - Spotify Web API Service

@MainActor
class SpotifyService: ObservableObject {
    
    // MARK: - Spotify Models
    
    struct SpotifyTrack: Codable {
        let id: String
        let name: String
        let artists: [SpotifyArtist]
        let album: SpotifyAlbum
        let duration_ms: Int
        let external_ids: SpotifyExternalIds?
        let preview_url: String?
        let popularity: Int
        
        var artistName: String {
            artists.map { $0.name }.joined(separator: ", ")
        }
        
        var duration: TimeInterval {
            Double(duration_ms) / 1000.0
        }
        
        var isrcCode: String? {
            external_ids?.isrc
        }
    }
    
    struct SpotifyArtist: Codable {
        let id: String
        let name: String
        let genres: [String]?
        let images: [SpotifyImage]?
        let popularity: Int?
    }
    
    struct SpotifyAlbum: Codable {
        let id: String
        let name: String
        let images: [SpotifyImage]
        let release_date: String?
        let artists: [SpotifyArtist]
    }
    
    struct SpotifyImage: Codable {
        let url: String
        let height: Int?
        let width: Int?
    }
    
    struct SpotifyExternalIds: Codable {
        let isrc: String?
    }
    
    struct SpotifySearchResponse: Codable {
        let tracks: SpotifyTracksResponse?
        let artists: SpotifyArtistsResponse?
        let albums: SpotifyAlbumsResponse?
    }
    
    struct SpotifyTracksResponse: Codable {
        let items: [SpotifyTrack]
        let total: Int
    }
    
    struct SpotifyArtistsResponse: Codable {
        let items: [SpotifyArtist]
        let total: Int
    }
    
    struct SpotifyAlbumsResponse: Codable {
        let items: [SpotifyAlbum]
        let total: Int
    }
    
    struct SpotifyUser: Codable {
        let id: String
        let display_name: String?
        let email: String?
        let country: String?
        let followers: SpotifyFollowers?
        let images: [SpotifyImage]?
        
        struct SpotifyFollowers: Codable {
            let total: Int
        }
        
        struct SpotifyImage: Codable {
            let url: String
            let height: Int?
            let width: Int?
        }
    }
    
    struct SpotifyPlaylist: Codable {
        let id: String
        let name: String
        let description: String?
        let images: [SpotifyUser.SpotifyImage]?
        let tracks: SpotifyPlaylistTracks
        let owner: SpotifyPlaylistOwner
        let `public`: Bool?
        
        struct SpotifyPlaylistTracks: Codable {
            let total: Int
        }
        
        struct SpotifyPlaylistOwner: Codable {
            let id: String
            let display_name: String?
        }
    }
    
    struct SpotifyPlaylistsResponse: Codable {
        let items: [SpotifyPlaylist]
        let total: Int
        let limit: Int
        let offset: Int
    }
    
    struct SpotifySavedTracksResponse: Codable {
        let items: [SpotifySavedTrackItem]
        let total: Int
        let limit: Int
        let offset: Int
        
        struct SpotifySavedTrackItem: Codable {
            let track: SpotifyTrack
            let added_at: String
        }
    }
    
    // MARK: - Configuration
    
    private let baseURL = "https://api.spotify.com/v1"
    private let clientId = "1aef1115860843efa62b56eeb45735c1"
    private let clientSecret = "251f18cdb80445a593681a3b17c37418"
    
    // MARK: - Authentication
    
    @Published var isAuthenticated = false
    @Published var isUserAuthenticated = false
    @Published var accessToken: String?
    @Published var userAccessToken: String?
    private var tokenExpirationDate: Date?
    private var userTokenExpirationDate: Date?
    @Published var currentUser: SpotifyUser?
    
    // MARK: - Singleton
    
    static let shared = SpotifyService()
    
    private init() {
        loadStoredToken()
    }
    
    // MARK: - Authentication Methods
    
    func authenticateWithClientCredentials() async -> Bool {
        do {
            let token = try await requestClientCredentialsToken()
            await MainActor.run {
                self.accessToken = token.access_token
                self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(token.expires_in))
                self.isAuthenticated = true
                self.saveToken(token)
            }
            print("✅ Spotify authentication successful")
            return true
        } catch {
            print("❌ Spotify authentication failed: \(error.localizedDescription)")
            await MainActor.run {
                self.isAuthenticated = false
            }
            return false
        }
    }
    
    private func requestClientCredentialsToken() async throws -> SpotifyTokenResponse {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let body = "grant_type=client_credentials"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SpotifyError.authenticationFailed
        }
        
        return try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
    }
    
    struct SpotifyTokenResponse: Codable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token: String?
    }
    
    // MARK: - User Authentication Methods
    
    func authenticateUser() async -> Bool {
        // For now, we'll use a simplified approach with Safari
        // In production, you'd implement full OAuth flow
        
        guard let authURL = buildAuthURL() else {
            print("❌ Failed to build Spotify auth URL")
            return false
        }
        
        print("🔗 Opening Spotify authorization URL...")
        print("🌐 URL: \(authURL.absoluteString)")
        
        // Open Safari for user to authorize
        await MainActor.run {
            if UIApplication.shared.canOpenURL(authURL) {
                UIApplication.shared.open(authURL)
            }
        }
        
        // For demo purposes, simulate successful authentication
        // In production, you'd handle the callback and exchange code for token
        return await simulateUserAuth()
    }
    
    private func buildAuthURL() -> URL? {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: "bumpin://spotify-callback"),
            URLQueryItem(name: "scope", value: "user-library-read playlist-read-private playlist-read-collaborative user-read-email user-read-private"),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        return components?.url
    }
    
    private func simulateUserAuth() async -> Bool {
        // Simulate authentication delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await MainActor.run {
            self.isUserAuthenticated = true
            self.userAccessToken = "simulated_user_token_\(UUID().uuidString.prefix(8))"
            self.userTokenExpirationDate = Date().addingTimeInterval(3600) // 1 hour
            self.currentUser = SpotifyUser(
                id: "demo_user",
                display_name: "Demo Spotify User",
                email: "demo@spotify.com",
                country: "US",
                followers: SpotifyUser.SpotifyFollowers(total: 42),
                images: nil
            )
        }
        
        print("✅ Spotify user authentication successful (demo mode)")
        return true
    }
    
    // MARK: - Search Methods
    
    func searchTracks(query: String, limit: Int = 25) async -> [SpotifyTrack] {
        guard await ensureValidToken() else {
            print("❌ No valid Spotify token for search")
            return []
        }
        
        guard let accessToken = accessToken else { return [] }
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=track&limit=\(limit)"
            
            guard let url = URL(string: urlString) else { return [] }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ Spotify search failed with status: \(httpResponse.statusCode)")
                return []
            }
            
            let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            let tracks = searchResponse.tracks?.items ?? []
            
            print("🎵 Spotify search found \(tracks.count) tracks for: \(query)")
            return tracks
            
        } catch {
            print("❌ Spotify search error: \(error.localizedDescription)")
            return []
        }
    }
    
    func searchArtists(query: String, limit: Int = 25) async -> [SpotifyArtist] {
        guard await ensureValidToken() else { return [] }
        guard let accessToken = accessToken else { return [] }
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=artist&limit=\(limit)"
            
            guard let url = URL(string: urlString) else { return [] }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            
            return searchResponse.artists?.items ?? []
        } catch {
            print("❌ Spotify artist search error: \(error.localizedDescription)")
            return []
        }
    }
    
    func searchAlbums(query: String, limit: Int = 25) async -> [SpotifyAlbum] {
        guard await ensureValidToken() else { return [] }
        guard let accessToken = accessToken else { return [] }
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=album&limit=\(limit)"
            
            guard let url = URL(string: urlString) else { return [] }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            
            return searchResponse.albums?.items ?? []
        } catch {
            print("❌ Spotify album search error: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Token Management
    
    private func ensureValidToken() async -> Bool {
        if let token = accessToken,
           let expirationDate = tokenExpirationDate,
           Date() < expirationDate.addingTimeInterval(-300) { // Refresh 5 minutes early
            return true
        }
        
        return await authenticateWithClientCredentials()
    }
    
    private func loadStoredToken() {
        if let tokenData = UserDefaults.standard.data(forKey: "spotify_token"),
           let token = try? JSONDecoder().decode(SpotifyTokenResponse.self, from: tokenData),
           let expirationData = UserDefaults.standard.object(forKey: "spotify_token_expiration") as? Date,
           Date() < expirationData {
            
            accessToken = token.access_token
            tokenExpirationDate = expirationData
            isAuthenticated = true
        }
    }
    
    private func saveToken(_ token: SpotifyTokenResponse) {
        if let tokenData = try? JSONEncoder().encode(token) {
            UserDefaults.standard.set(tokenData, forKey: "spotify_token")
            UserDefaults.standard.set(tokenExpirationDate, forKey: "spotify_token_expiration")
        }
    }
    
    // MARK: - Conversion to Universal Format
    
    func convertToMusicSearchResult(_ spotifyTrack: SpotifyTrack) -> MusicSearchResult {
        return MusicSearchResult(
            id: spotifyTrack.id,
            title: spotifyTrack.name,
            artistName: spotifyTrack.artistName,
            albumName: spotifyTrack.album.name,
            artworkURL: spotifyTrack.album.images.first?.url,
            itemType: "song",
            popularity: spotifyTrack.popularity,
            genreNames: spotifyTrack.artists.first?.genres,
            primaryGenre: spotifyTrack.artists.first?.genres?.first
        )
    }
    
    func convertToMusicSearchResult(_ spotifyArtist: SpotifyArtist) -> MusicSearchResult {
        return MusicSearchResult(
            id: spotifyArtist.id,
            title: spotifyArtist.name,
            artistName: spotifyArtist.name,
            albumName: "",
            artworkURL: spotifyArtist.images?.first?.url,
            itemType: "artist",
            popularity: spotifyArtist.popularity ?? 0,
            genreNames: spotifyArtist.genres,
            primaryGenre: spotifyArtist.genres?.first
        )
    }
    
    func convertToMusicSearchResult(_ spotifyAlbum: SpotifyAlbum) -> MusicSearchResult {
        return MusicSearchResult(
            id: spotifyAlbum.id,
            title: spotifyAlbum.name,
            artistName: spotifyAlbum.artists.first?.name ?? "",
            albumName: spotifyAlbum.name,
            artworkURL: spotifyAlbum.images.first?.url,
            itemType: "album",
            popularity: 0,
            genreNames: spotifyAlbum.artists.first?.genres,
            primaryGenre: spotifyAlbum.artists.first?.genres?.first
        )
    }
    
    // MARK: - User Library Methods
    
    func getUserPlaylists(limit: Int = 50) async -> [SpotifyPlaylist] {
        guard isUserAuthenticated, let userToken = userAccessToken else {
            print("❌ User not authenticated for Spotify library access")
            return []
        }
        
        do {
            var urlComponents = URLComponents(string: "\(baseURL)/me/playlists")!
            urlComponents.queryItems = [
                URLQueryItem(name: "limit", value: String(limit))
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
            
            print("🎵 Found \(response.items.count) Spotify playlists")
            return response.items
            
        } catch {
            print("❌ Error fetching Spotify playlists: \(error)")
            return []
        }
    }
    
    func getSavedTracks(limit: Int = 50) async -> [SpotifyTrack] {
        guard isUserAuthenticated, let userToken = userAccessToken else {
            print("❌ User not authenticated for Spotify library access")
            return []
        }
        
        do {
            var urlComponents = URLComponents(string: "\(baseURL)/me/tracks")!
            urlComponents.queryItems = [
                URLQueryItem(name: "limit", value: String(limit))
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SpotifySavedTracksResponse.self, from: data)
            
            print("🎵 Found \(response.items.count) saved Spotify tracks")
            return response.items.map { $0.track }
            
        } catch {
            print("❌ Error fetching saved Spotify tracks: \(error)")
            return []
        }
    }
    
    func getCurrentUser() async -> SpotifyUser? {
        guard isUserAuthenticated, let userToken = userAccessToken else {
            print("❌ User not authenticated for Spotify profile access")
            return nil
        }
        
        do {
            let url = URL(string: "\(baseURL)/me")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let user = try JSONDecoder().decode(SpotifyUser.self, from: data)
            
            await MainActor.run {
                self.currentUser = user
            }
            
            print("✅ Spotify user profile loaded: \(user.display_name ?? "Unknown")")
            return user
            
        } catch {
            print("❌ Error fetching Spotify user profile: \(error)")
            return nil
        }
    }
    
    // MARK: - Demo Library Data (for testing)
    
    func getDemoLibraryData() -> (playlists: [SpotifyPlaylist], savedTracks: [SpotifyTrack]) {
        let demoPlaylists = [
            SpotifyPlaylist(
                id: "demo_playlist_1",
                name: "My Liked Songs",
                description: "Your saved tracks on Spotify",
                images: nil,
                tracks: SpotifyPlaylist.SpotifyPlaylistTracks(total: 234),
                owner: SpotifyPlaylist.SpotifyPlaylistOwner(id: "demo_user", display_name: "You"),
                public: false
            ),
            SpotifyPlaylist(
                id: "demo_playlist_2", 
                name: "Chill Vibes",
                description: "Relaxing music for any time",
                images: nil,
                tracks: SpotifyPlaylist.SpotifyPlaylistTracks(total: 67),
                owner: SpotifyPlaylist.SpotifyPlaylistOwner(id: "demo_user", display_name: "You"),
                public: true
            ),
            SpotifyPlaylist(
                id: "demo_playlist_3",
                name: "Workout Mix",
                description: "High energy tracks",
                images: nil,
                tracks: SpotifyPlaylist.SpotifyPlaylistTracks(total: 89),
                owner: SpotifyPlaylist.SpotifyPlaylistOwner(id: "demo_user", display_name: "You"),
                public: false
            )
        ]
        
        let demoSavedTracks = [
            SpotifyTrack(
                id: "demo_track_1",
                name: "Blinding Lights",
                artists: [SpotifyArtist(id: "weeknd", name: "The Weeknd", genres: ["pop"], images: [], popularity: 95)],
                album: SpotifyAlbum(id: "after_hours", name: "After Hours", images: [], release_date: "2020", artists: []),
                duration_ms: 200040,
                external_ids: nil,
                preview_url: nil,
                popularity: 95
            ),
            SpotifyTrack(
                id: "demo_track_2", 
                name: "Good 4 U",
                artists: [SpotifyArtist(id: "olivia", name: "Olivia Rodrigo", genres: ["pop"], images: [], popularity: 89)],
                album: SpotifyAlbum(id: "sour", name: "SOUR", images: [], release_date: "2021", artists: []),
                duration_ms: 178147,
                external_ids: nil,
                preview_url: nil,
                popularity: 89
            ),
            SpotifyTrack(
                id: "demo_track_3",
                name: "As It Was",
                artists: [SpotifyArtist(id: "harry", name: "Harry Styles", genres: ["pop"], images: [], popularity: 92)],
                album: SpotifyAlbum(id: "harrys_house", name: "Harry's House", images: [], release_date: "2022", artists: []),
                duration_ms: 167000,
                external_ids: nil,
                preview_url: nil,
                popularity: 92
            ),
            SpotifyTrack(
                id: "demo_track_4",
                name: "Heat Waves",
                artists: [SpotifyArtist(id: "glass_animals", name: "Glass Animals", genres: ["indie"], images: [], popularity: 88)],
                album: SpotifyAlbum(id: "dreamland", name: "Dreamland", images: [], release_date: "2020", artists: []),
                duration_ms: 238000,
                external_ids: nil,
                preview_url: nil,
                popularity: 88
            ),
            SpotifyTrack(
                id: "demo_track_5",
                name: "Anti-Hero",
                artists: [SpotifyArtist(id: "taylor", name: "Taylor Swift", genres: ["pop"], images: [], popularity: 98)],
                album: SpotifyAlbum(id: "midnights", name: "Midnights", images: [], release_date: "2022", artists: []),
                duration_ms: 200560,
                external_ids: nil,
                preview_url: nil,
                popularity: 98
            )
        ]
        
        return (playlists: demoPlaylists, savedTracks: demoSavedTracks)
    }
}

// MARK: - Spotify Errors

enum SpotifyError: Error, LocalizedError {
    case authenticationFailed
    case invalidResponse
    case networkError
    case tokenExpired
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Failed to authenticate with Spotify"
        case .invalidResponse:
            return "Invalid response from Spotify API"
        case .networkError:
            return "Network error while contacting Spotify"
        case .tokenExpired:
            return "Spotify access token has expired"
        }
    }
}

// MARK: - Demo and Testing

extension SpotifyService {
    
    /// Demo function to test Spotify search
    func demonstrateSpotifySearch() async {
        print("🎵 === SPOTIFY SEARCH DEMO ===")
        
        // Authenticate first
        let authenticated = await authenticateWithClientCredentials()
        guard authenticated else {
            print("❌ Failed to authenticate with Spotify")
            return
        }
        
        // Search for "Sicko Mode"
        print("🔍 Searching Spotify for 'Sicko Mode'...")
        let tracks = await searchTracks(query: "Sicko Mode Travis Scott")
        
        if let sickoMode = tracks.first {
            print("✅ Found on Spotify:")
            print("   Title: \(sickoMode.name)")
            print("   Artist: \(sickoMode.artistName)")
            print("   Spotify ID: \(sickoMode.id)")
            print("   Duration: \(sickoMode.duration)s")
            print("   ISRC: \(sickoMode.isrcCode ?? "N/A")")
            
            // Convert to universal format
            let musicSearchResult = convertToMusicSearchResult(sickoMode)
            print("🔄 Converted to MusicSearchResult format")
            
            // Test universal track matching
            let universalTrack = await TrackMatchingService.shared.getUniversalTrack(
                title: sickoMode.name,
                artist: sickoMode.artistName,
                albumName: sickoMode.album.name,
                duration: sickoMode.duration,
                spotifyId: sickoMode.id,
                isrcCode: sickoMode.isrcCode
            )
            
            print("🎯 Universal Track ID: \(universalTrack.id)")
            print("🎉 Spotify users will now see the same profile as Apple Music users!")
        }
    }
}
