import Foundation
import FirebaseFunctions

/// Service for calling Firebase Cloud Functions
/// Handles secure server-side operations like Spotify authentication
class FirebaseFunctionsService {
    static let shared = FirebaseFunctionsService()
    
    private let functions = Functions.functions()
    
    private init() {}
    
    // MARK: - Spotify Authentication Functions
    
    /// Get Spotify Client Credentials Token
    /// Used for: Search, Browse, Public Data
    /// - Returns: Spotify access token and expiration info
    func getSpotifyClientToken() async throws -> SpotifyTokenResponse {
        do {
            let result = try await functions.httpsCallable("getSpotifyClientToken").call()
            
            guard let data = result.data as? [String: Any],
                  let accessToken = data["accessToken"] as? String,
                  let expiresIn = data["expiresIn"] as? Int else {
                throw FirebaseFunctionsError.invalidResponse
            }
            
            return SpotifyTokenResponse(
                accessToken: accessToken,
                expiresIn: expiresIn,
                refreshToken: nil,
                tokenType: data["tokenType"] as? String ?? "Bearer"
            )
        } catch {
            print("❌ FirebaseFunctionsService.getSpotifyClientToken error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Exchange Spotify authorization code for access and refresh tokens
    /// Used for: User Authentication Flow
    /// - Parameters:
    ///   - code: Authorization code from Spotify OAuth
    ///   - redirectUri: The redirect URI used in the OAuth flow
    /// - Returns: Spotify tokens including refresh token
    func exchangeSpotifyCode(code: String, redirectUri: String) async throws -> SpotifyTokenResponse {
        do {
            let result = try await functions.httpsCallable("exchangeSpotifyCode").call([
                "code": code,
                "redirectUri": redirectUri
            ])
            
            guard let data = result.data as? [String: Any],
                  let accessToken = data["accessToken"] as? String,
                  let expiresIn = data["expiresIn"] as? Int,
                  let refreshToken = data["refreshToken"] as? String else {
                throw FirebaseFunctionsError.invalidResponse
            }
            
            return SpotifyTokenResponse(
                accessToken: accessToken,
                expiresIn: expiresIn,
                refreshToken: refreshToken,
                tokenType: data["tokenType"] as? String ?? "Bearer"
            )
        } catch {
            print("❌ FirebaseFunctionsService.exchangeSpotifyCode error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Refresh Spotify user access token
    /// Used for: Renewing expired user tokens
    /// - Parameter refreshToken: The refresh token to use
    /// - Returns: New access token
    func refreshSpotifyToken(refreshToken: String) async throws -> SpotifyTokenResponse {
        do {
            let result = try await functions.httpsCallable("refreshSpotifyToken").call([
                "refreshToken": refreshToken
            ])
            
            guard let data = result.data as? [String: Any],
                  let accessToken = data["accessToken"] as? String,
                  let expiresIn = data["expiresIn"] as? Int else {
                throw FirebaseFunctionsError.invalidResponse
            }
            
            return SpotifyTokenResponse(
                accessToken: accessToken,
                expiresIn: expiresIn,
                refreshToken: nil, // Refresh token doesn't change
                tokenType: data["tokenType"] as? String ?? "Bearer"
            )
        } catch {
            print("❌ FirebaseFunctionsService.refreshSpotifyToken error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get Spotify authorization URL for user authentication
    /// - Parameters:
    ///   - redirectUri: The redirect URI for OAuth callback
    ///   - state: Optional state parameter for CSRF protection
    ///   - scopes: Array of Spotify permission scopes
    /// - Returns: URL to redirect user to for Spotify OAuth
    func getSpotifyAuthUrl(
        redirectUri: String,
        state: String? = nil,
        scopes: [String]? = nil
    ) async throws -> String {
        do {
            var params: [String: Any] = ["redirectUri": redirectUri]
            if let state = state {
                params["state"] = state
            }
            if let scopes = scopes {
                params["scopes"] = scopes
            }
            
            let result = try await functions.httpsCallable("getSpotifyAuthUrl").call(params)
            
            guard let data = result.data as? [String: Any],
                  let authUrl = data["authUrl"] as? String else {
                throw FirebaseFunctionsError.invalidResponse
            }
            
            return authUrl
        } catch {
            print("❌ FirebaseFunctionsService.getSpotifyAuthUrl error: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Models

struct SpotifyTokenResponse {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let tokenType: String
    
    var expirationDate: Date {
        return Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

// MARK: - Errors

enum FirebaseFunctionsError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized request"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

