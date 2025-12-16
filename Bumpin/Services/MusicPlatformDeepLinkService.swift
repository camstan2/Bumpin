import Foundation
import UIKit

// MARK: - Music Platform Deep Link Service

/// Service for handling deep links to Apple Music and Spotify apps/web
class MusicPlatformDeepLinkService {
    
    static let shared = MusicPlatformDeepLinkService()
    
    private init() {}
    
    // MARK: - Deep Link Methods
    
    /// Open a song in Apple Music or Spotify
    func openSong(itemId: String, platform: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        if platform.lowercased().contains("apple") {
            openAppleMusicSong(itemId: itemId, completion: completion)
        } else if platform.lowercased().contains("spotify") {
            openSpotifySong(trackId: itemId, completion: completion)
        } else {
            completion(.failure(.unsupportedPlatform))
        }
    }
    
    /// Open an album in Apple Music or Spotify
    func openAlbum(itemId: String, platform: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        if platform.lowercased().contains("apple") {
            openAppleMusicAlbum(itemId: itemId, completion: completion)
        } else if platform.lowercased().contains("spotify") {
            openSpotifyAlbum(albumId: itemId, completion: completion)
        } else {
            completion(.failure(.unsupportedPlatform))
        }
    }
    
    /// Open an artist in Apple Music or Spotify
    func openArtist(itemId: String, platform: String, artistName: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        if platform.lowercased().contains("apple") {
            openAppleMusicArtist(itemId: itemId, artistName: artistName, completion: completion)
        } else if platform.lowercased().contains("spotify") {
            openSpotifyArtist(artistId: itemId, completion: completion)
        } else {
            completion(.failure(.unsupportedPlatform))
        }
    }
    
    // MARK: - Apple Music Deep Links
    
    private func openAppleMusicSong(itemId: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        // Try app deep link first
        let appURL = URL(string: "music://music.apple.com/us/song/\(itemId)")!
        
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL) { success in
                if success {
                    completion(.success(()))
                } else {
                    // Fallback to web
                    self.openAppleMusicWeb(type: "song", itemId: itemId, completion: completion)
                }
            }
        } else {
            // App not installed, show error
            completion(.failure(.appNotInstalled(platform: "Apple Music")))
        }
    }
    
    private func openAppleMusicAlbum(itemId: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        let appURL = URL(string: "music://music.apple.com/us/album/\(itemId)")!
        
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL) { success in
                if success {
                    completion(.success(()))
                } else {
                    self.openAppleMusicWeb(type: "album", itemId: itemId, completion: completion)
                }
            }
        } else {
            completion(.failure(.appNotInstalled(platform: "Apple Music")))
        }
    }
    
    private func openAppleMusicArtist(itemId: String, artistName: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        // For artists, we typically don't have real Apple Music IDs, so use search
        // Only use direct link if itemId looks like a valid Apple Music ID (numeric)
        let isValidAppleMusicId = !itemId.isEmpty && itemId.allSatisfy { $0.isNumber }
        
        if isValidAppleMusicId {
            // Have a real Apple Music artist ID
            let appURL = URL(string: "music://music.apple.com/us/artist/\(itemId)")!
            
            if UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL) { success in
                    if success {
                        completion(.success(()))
                    } else {
                        // Fallback to search if direct link fails
                        self.openAppleMusicSearch(query: artistName, completion: completion)
                    }
                }
            } else {
                completion(.failure(.appNotInstalled(platform: "Apple Music")))
            }
        } else {
            // No valid ID, use search
            openAppleMusicSearch(query: artistName, completion: completion)
        }
    }
    
    private func openAppleMusicSearch(query: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        let searchQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        // Try the simpler search URL format
        let searchURL = URL(string: "music://search?term=\(searchQuery)")!
        
        if UIApplication.shared.canOpenURL(searchURL) {
            UIApplication.shared.open(searchURL) { success in
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(.failedToOpen))
                }
            }
        } else {
            completion(.failure(.appNotInstalled(platform: "Apple Music")))
        }
    }
    
    private func openAppleMusicWeb(type: String, itemId: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        let webURL = URL(string: "https://music.apple.com/us/\(type)/\(itemId)")!
        UIApplication.shared.open(webURL) { success in
            if success {
                completion(.success(()))
            } else {
                completion(.failure(.failedToOpen))
            }
        }
    }
    
    // MARK: - Spotify Deep Links
    
    private func openSpotifySong(trackId: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        let appURL = URL(string: "spotify:track:\(trackId)")!
        
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL) { success in
                if success {
                    completion(.success(()))
                } else {
                    // Fallback to web player
                    self.openSpotifyWeb(type: "track", itemId: trackId, completion: completion)
                }
            }
        } else {
            completion(.failure(.appNotInstalled(platform: "Spotify")))
        }
    }
    
    private func openSpotifyAlbum(albumId: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        let appURL = URL(string: "spotify:album:\(albumId)")!
        
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL) { success in
                if success {
                    completion(.success(()))
                } else {
                    self.openSpotifyWeb(type: "album", itemId: albumId, completion: completion)
                }
            }
        } else {
            completion(.failure(.appNotInstalled(platform: "Spotify")))
        }
    }
    
    private func openSpotifyArtist(artistId: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        let appURL = URL(string: "spotify:artist:\(artistId)")!
        
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL) { success in
                if success {
                    completion(.success(()))
                } else {
                    self.openSpotifyWeb(type: "artist", itemId: artistId, completion: completion)
                }
            }
        } else {
            completion(.failure(.appNotInstalled(platform: "Spotify")))
        }
    }
    
    private func openSpotifyWeb(type: String, itemId: String, completion: @escaping (Result<Void, DeepLinkError>) -> Void) {
        let webURL = URL(string: "https://open.spotify.com/\(type)/\(itemId)")!
        UIApplication.shared.open(webURL) { success in
            if success {
                completion(.success(()))
            } else {
                completion(.failure(.failedToOpen))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a music platform app is installed
    func isPlatformAppInstalled(_ platform: String) -> Bool {
        if platform.lowercased().contains("apple") {
            return UIApplication.shared.canOpenURL(URL(string: "music://")!)
        } else if platform.lowercased().contains("spotify") {
            return UIApplication.shared.canOpenURL(URL(string: "spotify:")!)
        }
        return false
    }
}

// MARK: - Deep Link Error

enum DeepLinkError: Error, LocalizedError {
    case appNotInstalled(platform: String)
    case failedToOpen
    case unsupportedPlatform
    
    var errorDescription: String? {
        switch self {
        case .appNotInstalled(let platform):
            return "\(platform) app is not installed. Please install it from the App Store to continue."
        case .failedToOpen:
            return "Failed to open the music platform. Please try again."
        case .unsupportedPlatform:
            return "This music platform is not supported."
        }
    }
}

