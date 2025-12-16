import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Spotify Web API Service

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
    
    struct SpotifyTokenResponse: Codable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token: String?
        let scope: String?
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
    
    struct SpotifyPlaylistTracksResponse: Codable {
        let items: [SpotifyPlaylistTrackItem]
        let total: Int
        let limit: Int
        let offset: Int
        
        struct SpotifyPlaylistTrackItem: Codable {
            let track: SpotifyTrack?
            let added_at: String
        }
    }
    
    // MARK: - Configuration
    
    private let baseURL = "https://api.spotify.com/v1"
    private let clientId = "1aef1115860843efa62b56eeb45735c1"
    // ✅ SECURITY: Client secret moved to Firebase Functions
    // No longer stored in the app
    
    // MARK: - Authentication
    
    @Published var isAuthenticated = false
    @Published var isUserAuthenticated = false
    @Published var accessToken: String?
    @Published var userAccessToken: String?
    private var userRefreshToken: String?
    private var tokenExpirationDate: Date?
    private var userTokenExpirationDate: Date?
    @Published var currentUser: SpotifyUser?
    
    // 🔒 CRITICAL FIX: Serialize token authentication to prevent race conditions
    private var ongoingAuthTask: Task<Bool, Never>?
    private var authTaskId: UUID?
    private let authTaskLock = NSLock()
    
    // MARK: - Singleton
    
    static let shared = SpotifyService()
    
    private init() {
        loadStoredToken()
        loadStoredUserToken()
    }
    
    // MARK: - Authentication Methods
    
    func authenticateWithClientCredentials() async -> Bool {
        // 🔒 CRITICAL FIX: Check if token is already valid (fast path, no lock needed)
        if let token = accessToken,
           let expiration = tokenExpirationDate,
           Date() < expiration.addingTimeInterval(-300) {
            return true
        }
        
        // Lock only for checking/setting the ongoing task
        authTaskLock.lock()
        
        // Double-check token validity while holding lock
        if let token = accessToken,
           let expiration = tokenExpirationDate,
           Date() < expiration.addingTimeInterval(-300) {
            authTaskLock.unlock()
            return true
        }
        
        // If authentication is already in progress, wait for it
        if let existingTask = ongoingAuthTask {
            let task = existingTask
            authTaskLock.unlock()
            print("⏳ Waiting for existing Spotify authentication...")
            return await task.value
        }
        
        // Start new authentication task (OFF main actor)
        let taskId = UUID()
        let newTask = Task<Bool, Never> {
            await self.performAuthentication()
        }
        ongoingAuthTask = newTask
        authTaskId = taskId
        authTaskLock.unlock()
        
        let result = await newTask.value
        
        // Clean up - only clear if this is still the current task
        authTaskLock.lock()
        if authTaskId == taskId {
            ongoingAuthTask = nil
            authTaskId = nil
        }
        authTaskLock.unlock()
        
        return result
    }
    
    private func performAuthentication() async -> Bool {
        print("🔑 Starting Spotify authentication via Firebase Functions...")
        do {
            // ✅ NEW: Call Firebase Function instead of direct Spotify API
            let tokenResponse = try await FirebaseFunctionsService.shared.getSpotifyClientToken()
            await MainActor.run {
                self.accessToken = tokenResponse.accessToken
                self.tokenExpirationDate = tokenResponse.expirationDate
                self.isAuthenticated = true
                // Save token for caching
                self.saveToken(SpotifyTokenResponse(
                    access_token: tokenResponse.accessToken,
                    token_type: tokenResponse.tokenType,
                    expires_in: tokenResponse.expiresIn,
                    refresh_token: nil,
                    scope: nil
                ))
            }
            print("✅ Spotify authentication successful via Firebase Functions")
            return true
        } catch {
            print("❌ Spotify authentication failed: \(error.localizedDescription)")
            await MainActor.run {
                self.isAuthenticated = false
            }
            return false
        }
    }
    
    // OLD METHOD - No longer needed, kept for reference
    /*
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
    */
    
    // MARK: - User Authentication Methods
    
    func authenticateUser() async -> Bool {
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
        
        // The actual authentication will be handled by the OAuth callback
        // We'll return true here to indicate the auth process has started
        // The real authentication status will be updated in handleOAuthCallback
        return true
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
    
    // MARK: - OAuth Callback Handler
    
    func handleOAuthCallback(url: URL) async {
        print("🔗 Handling Spotify OAuth callback: \(url)")
        
        // Parse the authorization code from the URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            print("❌ No authorization code found in callback URL")
            return
        }
        
        print("✅ Authorization code received: \(code.prefix(10))...")
        
        // Exchange authorization code for access token
        await exchangeCodeForToken(authorizationCode: code)
    }
    
    private func exchangeCodeForToken(authorizationCode: String) async {
        print("🔑 Exchanging authorization code for token via Firebase Functions...")
        
        do {
            // ✅ NEW: Call Firebase Function instead of direct Spotify API
            let redirectURI = "bumpin://spotify-callback"
            let tokenResponse = try await FirebaseFunctionsService.shared.exchangeSpotifyCode(
                code: authorizationCode,
                redirectUri: redirectURI
            )
            
            await MainActor.run {
                self.isUserAuthenticated = true
                self.userAccessToken = tokenResponse.accessToken
                self.userRefreshToken = tokenResponse.refreshToken
                self.userTokenExpirationDate = tokenResponse.expirationDate
            }
            
            // Save user token for persistence
            saveUserToken(SpotifyTokenResponse(
                access_token: tokenResponse.accessToken,
                token_type: tokenResponse.tokenType,
                expires_in: tokenResponse.expiresIn,
                refresh_token: tokenResponse.refreshToken,
                scope: nil
            ))
            
            print("✅ Spotify user authentication successful via Firebase Functions!")
            
            // Load user profile
            await loadUserProfile()
            
        } catch {
            print("❌ Token exchange error: \(error.localizedDescription)")
        }
    }
    
    // OLD METHOD - No longer needed
    /*
    private func exchangeCodeForToken(authorizationCode: String) async {
        guard let tokenURL = URL(string: "https://accounts.spotify.com/api/token") else {
            print("❌ Invalid token URL")
            return
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create the request body
        let redirectURI = "bumpin://spotify-callback"
        let bodyString = "grant_type=authorization_code&code=\(authorizationCode)&redirect_uri=\(redirectURI)&client_id=\(clientId)&client_secret=\(clientSecret)"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔑 Token exchange response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                    
                    await MainActor.run {
                        self.isUserAuthenticated = true
                        self.userAccessToken = tokenResponse.access_token
                        self.userRefreshToken = tokenResponse.refresh_token
                        self.userTokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
                    }
                    
                    // Save user token for persistence
                    saveUserToken(tokenResponse)
                    
                    print("✅ Spotify authentication successful!")
                    
                    // Load user profile
                    await loadUserProfile()
                    
                } else {
                    print("❌ Token exchange failed with status: \(httpResponse.statusCode)")
                    if let errorData = String(data: data, encoding: .utf8) {
                        print("Error details: \(errorData)")
                    }
                }
            }
        } catch {
            print("❌ Token exchange error: \(error.localizedDescription)")
        }
    }
    */
    
    private func loadUserProfile() async {
        guard let accessToken = userAccessToken else { return }
        
        do {
            let url = URL(string: "\(baseURL)/me")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let user = try JSONDecoder().decode(SpotifyUser.self, from: data)
                
                await MainActor.run {
                    self.currentUser = user
                }
                
                // Save user profile
                if let userData = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(userData, forKey: "spotify_user_profile")
                }
                
                print("✅ User profile loaded: \(user.display_name ?? "Unknown")")
            }
        } catch {
            print("❌ Failed to load user profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Token Management
    
    private func ensureUserTokenValid() async -> Bool {
        guard let token = userAccessToken,
              let expiration = userTokenExpirationDate else {
            return false
        }
        
        // Check if token is expired or will expire in the next 5 minutes
        if expiration.timeIntervalSinceNow < 300 {
            print("🔄 User token expired, refreshing...")
            return await refreshUserToken()
        }
        
        return true
    }
    
    private func refreshUserToken() async -> Bool {
        guard let refreshToken = userRefreshToken else {
            print("❌ No refresh token available")
            return false
        }
        
        print("🔄 Refreshing user token via Firebase Functions...")
        
        do {
            // ✅ NEW: Call Firebase Function instead of direct Spotify API
            let tokenResponse = try await FirebaseFunctionsService.shared.refreshSpotifyToken(
                refreshToken: refreshToken
            )
            
            await MainActor.run {
                self.userAccessToken = tokenResponse.accessToken
                // Keep existing refresh token if not returned
                self.userTokenExpirationDate = tokenResponse.expirationDate
            }
            
            // Save refreshed token
            saveUserToken(SpotifyTokenResponse(
                access_token: tokenResponse.accessToken,
                token_type: tokenResponse.tokenType,
                expires_in: tokenResponse.expiresIn,
                refresh_token: refreshToken, // Keep existing refresh token
                scope: nil
            ))
            
            print("✅ User token refreshed successfully via Firebase Functions")
            return true
            
        } catch {
            print("❌ Token refresh failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // OLD METHOD - No longer needed
    /*
    private func refreshUserToken() async -> Bool {
        guard let refreshToken = userRefreshToken else {
            print("❌ No refresh token available")
            return false
        }
        
        guard let tokenURL = URL(string: "https://accounts.spotify.com/api/token") else {
            return false
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(clientId)&client_secret=\(clientSecret)"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
                
                await MainActor.run {
                    self.userAccessToken = tokenResponse.access_token
                    if let refreshToken = tokenResponse.refresh_token {
                        self.userRefreshToken = refreshToken
                    }
                    self.userTokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
                }
                
                // Save refreshed token
                saveUserToken(tokenResponse)
                
                print("✅ User token refreshed successfully")
                return true
            }
        } catch {
            print("❌ Token refresh failed: \(error.localizedDescription)")
        }
        
        return false
    }
    */
    
    // MARK: - Search Methods
    
    func searchTracks(query: String, limit: Int = 25) async -> [SpotifyTrack] {
        print("🔍 [Spotify] Starting track search for: \(query)")
        
        guard await ensureValidToken() else {
            print("❌ [Spotify] No valid Spotify token for search")
            return []
        }
        
        guard let accessToken = accessToken else {
            print("❌ [Spotify] No access token available")
            return []
        }
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=track&limit=\(limit)"
            
            guard let url = URL(string: urlString) else {
                print("❌ [Spotify] Invalid URL for track search")
                return []
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10.0 // 10 second timeout
            
            print("🌐 [Spotify] Making track search request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("✅ [Spotify] Track search request completed")
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ [Spotify] Track search failed with status: \(httpResponse.statusCode)")
                return []
            }
            
            let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            let tracks = searchResponse.tracks?.items ?? []
            
            print("✅ [Spotify] Track search found \(tracks.count) tracks for: \(query)")
            return tracks
            
        } catch {
            print("❌ [Spotify] Track search error: \(error.localizedDescription)")
            return []
        }
    }
    
    func searchArtists(query: String, limit: Int = 25) async -> [SpotifyArtist] {
        print("🔍 [Spotify] Starting artist search for: \(query)")
        
        guard await ensureValidToken() else {
            print("❌ [Spotify] No valid token for artist search")
            return []
        }
        
        guard let accessToken = accessToken else {
            print("❌ [Spotify] No access token for artist search")
            return []
        }
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=artist&limit=\(limit)"
            
            guard let url = URL(string: urlString) else {
                print("❌ [Spotify] Invalid URL for artist search")
                return []
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10.0 // 10 second timeout
            
            print("🌐 [Spotify] Making artist search request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("✅ [Spotify] Artist search request completed")
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ [Spotify] Artist search failed with status: \(httpResponse.statusCode)")
                return []
            }
            
            let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            let artists = searchResponse.artists?.items ?? []
            
            print("✅ [Spotify] Artist search found \(artists.count) artists for: \(query)")
            return artists
            
        } catch {
            print("❌ [Spotify] Artist search error: \(error.localizedDescription)")
            return []
        }
    }
    
    func searchAlbums(query: String, limit: Int = 25) async -> [SpotifyAlbum] {
        print("🔍 [Spotify] Starting album search for: \(query)")
        
        guard await ensureValidToken() else {
            print("❌ [Spotify] No valid token for album search")
            return []
        }
        
        guard let accessToken = accessToken else {
            print("❌ [Spotify] No access token for album search")
            return []
        }
        
        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=album&limit=\(limit)"
            
            guard let url = URL(string: urlString) else {
                print("❌ [Spotify] Invalid URL for album search")
                return []
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10.0 // 10 second timeout
            
            print("🌐 [Spotify] Making album search request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("✅ [Spotify] Album search request completed")
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ [Spotify] Album search failed with status: \(httpResponse.statusCode)")
                return []
            }
            
            let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
            let albums = searchResponse.albums?.items ?? []
            
            print("✅ [Spotify] Album search found \(albums.count) albums for: \(query)")
            return albums
            
        } catch {
            print("❌ [Spotify] Album search error: \(error.localizedDescription)")
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
    
    // MARK: - User Token Persistence
    
    private func loadStoredUserToken() {
        // Load user access token
        if let userToken = UserDefaults.standard.string(forKey: "spotify_user_access_token"),
           let userRefreshToken = UserDefaults.standard.string(forKey: "spotify_user_refresh_token"),
           let expirationData = UserDefaults.standard.object(forKey: "spotify_user_token_expiration") as? Date {
            
            self.userAccessToken = userToken
            self.userRefreshToken = userRefreshToken
            self.userTokenExpirationDate = expirationData
            self.isUserAuthenticated = true
            
            print("✅ Loaded stored Spotify user token (expires: \(expirationData))")
            
            // Load user profile if available
            if let userData = UserDefaults.standard.data(forKey: "spotify_user_profile"),
               let user = try? JSONDecoder().decode(SpotifyUser.self, from: userData) {
                self.currentUser = user
                print("✅ Loaded stored user profile: \(user.display_name ?? "Unknown")")
            }
        }
    }
    
    private func saveUserToken(_ token: SpotifyTokenResponse) {
        UserDefaults.standard.set(token.access_token, forKey: "spotify_user_access_token")
        if let refreshToken = token.refresh_token {
            UserDefaults.standard.set(refreshToken, forKey: "spotify_user_refresh_token")
        }
        if let expiration = userTokenExpirationDate {
            UserDefaults.standard.set(expiration, forKey: "spotify_user_token_expiration")
        }
        
        // Save user profile if available
        if let user = currentUser, let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "spotify_user_profile")
        }
        
        print("💾 Saved Spotify user token to UserDefaults")
    }
    
    // MARK: - Connection Management
    
    @MainActor
    func disconnectSpotifySearch() {
        print("🔌 Disconnecting Spotify search authentication…")
        accessToken = nil
        tokenExpirationDate = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "spotify_token")
        UserDefaults.standard.removeObject(forKey: "spotify_token_expiration")
        print("✅ Spotify search disconnected")
    }
    
    @MainActor
    func disconnectSpotifyLibrary(removeRemoteData: Bool = true) async {
        print("🔌 Disconnecting Spotify library authentication…")
        userAccessToken = nil
        userRefreshToken = nil
        userTokenExpirationDate = nil
        currentUser = nil
        isUserAuthenticated = false
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "spotify_user_access_token")
        defaults.removeObject(forKey: "spotify_user_refresh_token")
        defaults.removeObject(forKey: "spotify_user_token_expiration")
        defaults.removeObject(forKey: "spotify_user_profile")
        
        if removeRemoteData, let uid = Auth.auth().currentUser?.uid {
            let docRef = Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection("private")
                .document("spotify")
            do {
                try await docRef.delete()
                print("🗑️ Removed stored Spotify refresh token from Firestore")
            } catch {
                print("⚠️ Failed to delete Spotify refresh token doc: \(error.localizedDescription)")
            }
        }
        
        print("✅ Spotify library disconnected")
    }
    
    @MainActor
    func disconnectAllSpotify() async {
        disconnectSpotifySearch()
        await disconnectSpotifyLibrary()
    }
    
    // MARK: - Conversion to Universal Format
    
    func convertToMusicSearchResult(_ spotifyTrack: SpotifyTrack, platform: String = "spotify") -> MusicSearchResult {
        return MusicSearchResult(
            id: spotifyTrack.id,
            title: spotifyTrack.name,
            artistName: spotifyTrack.artistName,
            albumName: spotifyTrack.album.name,
            artworkURL: spotifyTrack.album.images.first?.url,
            itemType: "song",
            popularity: spotifyTrack.popularity,
            genreNames: spotifyTrack.artists.first?.genres,
            primaryGenre: spotifyTrack.artists.first?.genres?.first,
            platform: platform
        )
    }
    
    func convertToMusicSearchResult(_ spotifyArtist: SpotifyArtist, platform: String = "spotify") -> MusicSearchResult {
        return MusicSearchResult(
            id: spotifyArtist.id,
            title: spotifyArtist.name,
            artistName: spotifyArtist.name,
            albumName: "",
            artworkURL: spotifyArtist.images?.first?.url,
            itemType: "artist",
            popularity: spotifyArtist.popularity ?? 0,
            genreNames: spotifyArtist.genres,
            primaryGenre: spotifyArtist.genres?.first,
            platform: platform
        )
    }
    
    func convertToMusicSearchResult(_ spotifyAlbum: SpotifyAlbum, platform: String = "spotify") -> MusicSearchResult {
        return MusicSearchResult(
            id: spotifyAlbum.id,
            title: spotifyAlbum.name,
            artistName: spotifyAlbum.artists.first?.name ?? "",
            albumName: spotifyAlbum.name,
            artworkURL: spotifyAlbum.images.first?.url,
            itemType: "album",
            popularity: 0,
            genreNames: spotifyAlbum.artists.first?.genres,
            primaryGenre: spotifyAlbum.artists.first?.genres?.first,
            platform: platform
        )
    }
    
    // MARK: - User Library Methods
    
    func getUserPlaylists(limit: Int = 50) async -> [SpotifyPlaylist] {
        guard isUserAuthenticated else {
            print("❌ User not authenticated for Spotify library access")
            return []
        }
        
        guard await ensureUserTokenValid() else {
            print("❌ Invalid user token for Spotify library access")
            return []
        }
        
        guard let userToken = userAccessToken else {
            print("❌ No user access token available")
            return []
        }
        
        do {
            var urlComponents = URLComponents(string: "\(baseURL)/me/playlists")!
            urlComponents.queryItems = [
                URLQueryItem(name: "limit", value: String(limit))
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ Failed to fetch playlists: \(httpResponse.statusCode)")
                return []
            }
            
            let playlistsResponse = try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
            
            print("🎵 Found \(playlistsResponse.items.count) Spotify playlists")
            return playlistsResponse.items
            
        } catch {
            print("❌ Error fetching Spotify playlists: \(error)")
            return []
        }
    }
    
    func getSavedTracks(limit: Int = 50) async -> [SpotifyTrack] {
        guard isUserAuthenticated else {
            print("❌ User not authenticated for Spotify library access")
            return []
        }
        
        guard await ensureUserTokenValid() else {
            print("❌ Invalid user token for Spotify library access")
            return []
        }
        
        guard let userToken = userAccessToken else {
            print("❌ No user access token available")
            return []
        }
        
        do {
            var urlComponents = URLComponents(string: "\(baseURL)/me/tracks")!
            urlComponents.queryItems = [
                URLQueryItem(name: "limit", value: String(limit))
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ Failed to fetch saved tracks: \(httpResponse.statusCode)")
                return []
            }
            
            let savedTracksResponse = try JSONDecoder().decode(SpotifySavedTracksResponse.self, from: data)
            
            print("🎵 Found \(savedTracksResponse.items.count) saved Spotify tracks")
            return savedTracksResponse.items.map { $0.track }
            
        } catch {
            print("❌ Error fetching saved Spotify tracks: \(error)")
            return []
        }
    }
    
    func getPlaylistTracks(playlistId: String, limit: Int = 100) async -> [SpotifyTrack] {
        guard isUserAuthenticated else {
            print("❌ User not authenticated for Spotify playlist access")
            return []
        }
        
        guard await ensureUserTokenValid() else {
            print("❌ Invalid user token for Spotify playlist access")
            return []
        }
        
        guard let userToken = userAccessToken else {
            print("❌ No user access token available")
            return []
        }
        
        do {
            var urlComponents = URLComponents(string: "\(baseURL)/playlists/\(playlistId)/tracks")!
            urlComponents.queryItems = [
                URLQueryItem(name: "limit", value: String(limit))
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ Failed to fetch playlist tracks: \(httpResponse.statusCode)")
                return []
            }
            
            let playlistTracksResponse = try JSONDecoder().decode(SpotifyPlaylistTracksResponse.self, from: data)
            
            print("🎵 Found \(playlistTracksResponse.items.count) tracks in playlist")
            return playlistTracksResponse.items.compactMap { $0.track }
            
        } catch {
            print("❌ Error fetching Spotify playlist tracks: \(error)")
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
