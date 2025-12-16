import SwiftUI

// MARK: - Listen On Platform Buttons Component

/// Reusable buttons for opening music items in Apple Music or Spotify
/// Automatically shows/hides buttons based on user's platform preference
struct ListenOnPlatformButtons: View {
    let itemId: String
    let itemType: String // "song", "album", "artist"
    let platform: String? // "apple_music", "spotify", or nil
    let artistName: String? // For artists without proper IDs
    let songTitle: String? // For songs/albums to enable search fallback
    
    @StateObject private var unifiedSearchService = UnifiedMusicSearchService.shared
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Determine which buttons to show based on user preference and availability
    private var shouldShowAppleMusic: Bool {
        let pref = unifiedSearchService.platformPreference
        let userWantsAppleMusic = pref == .appleMusicOnly || pref == .both || pref == .appleMusicPrimary
        
        // Don't show for artists without valid Apple Music IDs
        if itemType.lowercased() == "artist" && !hasAppleMusicId {
            return false
        }
        
        // For "Both Platforms" or "Apple Music Primary", always show if user wants it
        if pref == .both || pref == .appleMusicPrimary {
            return userWantsAppleMusic
        }
        
        // Otherwise only show if item is from Apple Music
        let isAppleMusicItem = platform?.lowercased().contains("apple") ?? true
        return isAppleMusicItem && userWantsAppleMusic
    }
    
    private var shouldShowSpotify: Bool {
        let pref = unifiedSearchService.platformPreference
        let userWantsSpotify = pref == .spotifyOnly || pref == .both || pref == .spotifyPrimary
        
        // Always show if user wants Spotify (we can search if we don't have the ID)
        return userWantsSpotify
    }
    
    private var showBothButtons: Bool {
        return shouldShowAppleMusic && shouldShowSpotify
    }
    
    // Check if we have the actual ID for the platform
    private var hasAppleMusicId: Bool {
        // For artists, check if the ID is numeric (valid Apple Music artist ID)
        if itemType.lowercased() == "artist" {
            return !itemId.isEmpty && itemId.allSatisfy { $0.isNumber }
        }
        // For songs/albums, assume we have it if platform is Apple Music
        return platform?.lowercased().contains("apple") ?? true
    }
    
    private var hasSpotifyId: Bool {
        return platform?.lowercased().contains("spotify") ?? false
    }
    
    var body: some View {
        Group {
            if showBothButtons {
                // Show both buttons side by side
                HStack(spacing: 8) {
                    if shouldShowAppleMusic {
                        appleMusicButton
                            .frame(maxWidth: .infinity)
                    }
                    if shouldShowSpotify {
                        spotifyButton
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                // Show single button (full width)
                if shouldShowAppleMusic {
                    appleMusicButton
                } else if shouldShowSpotify {
                    spotifyButton
                }
            }
        }
        .alert("Music App Not Found", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Apple Music Button
    
    private var appleMusicButton: some View {
        Button(action: {
            handleAppleMusicTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "applelogo")
                    .font(.system(size: 14, weight: .semibold))
                Text(showBothButtons ? "Music" : "Open in Apple Music")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                LinearGradient(
                    colors: [Color.pink, Color.red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.pink.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Spotify Button
    
    private var spotifyButton: some View {
        Button(action: {
            handleSpotifyTap()
        }) {
            HStack(spacing: 8) {
                // Spotify logo approximation (using circle with dot)
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                    Image(systemName: "waveform")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(red: 30/255, green: 215/255, blue: 96/255))
                }
                Text(showBothButtons ? "Spotify" : "Open in Spotify")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                Color(red: 30/255, green: 215/255, blue: 96/255)
            )
            .cornerRadius(12)
            .shadow(color: Color(red: 30/255, green: 215/255, blue: 96/255).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Action Handlers
    
    private func handleAppleMusicTap() {
        let service = MusicPlatformDeepLinkService.shared
        
        switch itemType.lowercased() {
        case "song":
            service.openSong(itemId: itemId, platform: "apple_music") { result in
                handleResult(result, platform: "Apple Music")
            }
        case "album":
            service.openAlbum(itemId: itemId, platform: "apple_music") { result in
                handleResult(result, platform: "Apple Music")
            }
        case "artist":
            service.openArtist(itemId: itemId, platform: "apple_music", artistName: artistName ?? "") { result in
                handleResult(result, platform: "Apple Music")
            }
        default:
            alertMessage = "Unsupported item type"
            showAlert = true
        }
    }
    
    private func handleSpotifyTap() {
        // If we don't have a Spotify ID, open search instead
        if !hasSpotifyId {
            openSpotifySearch()
            return
        }
        
        let service = MusicPlatformDeepLinkService.shared
        
        switch itemType.lowercased() {
        case "song":
            service.openSong(itemId: itemId, platform: "spotify") { result in
                handleResult(result, platform: "Spotify")
            }
        case "album":
            service.openAlbum(itemId: itemId, platform: "spotify") { result in
                handleResult(result, platform: "Spotify")
            }
        case "artist":
            service.openArtist(itemId: itemId, platform: "spotify", artistName: artistName ?? "") { result in
                handleResult(result, platform: "Spotify")
            }
        default:
            alertMessage = "Unsupported item type"
            showAlert = true
        }
    }
    
    private func openSpotifySearch() {
        // Build search query
        var searchQuery = ""
        if let title = songTitle {
            searchQuery += title
        }
        if let artist = artistName {
            if !searchQuery.isEmpty {
                searchQuery += " "
            }
            searchQuery += artist
        }
        
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
        
        // Try Spotify app search
        let spotifySearchURL = URL(string: "spotify:search:\(encodedQuery)")!
        
        if UIApplication.shared.canOpenURL(spotifySearchURL) {
            UIApplication.shared.open(spotifySearchURL) { success in
                if !success {
                    // Fallback to web search
                    self.openSpotifyWebSearch(query: encodedQuery)
                }
            }
        } else {
            // App not installed
            DispatchQueue.main.async {
                self.alertMessage = "Spotify app is not installed. Please install it from the App Store to continue."
                self.showAlert = true
            }
        }
    }
    
    private func openSpotifyWebSearch(query: String) {
        let webURL = URL(string: "https://open.spotify.com/search/\(query)")!
        UIApplication.shared.open(webURL)
    }
    
    private func handleResult(_ result: Result<Void, DeepLinkError>, platform: String) {
        DispatchQueue.main.async {
            switch result {
            case .success:
                print("✅ Successfully opened \(platform)")
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ListenOnPlatformButtons(
            itemId: "123456",
            itemType: "song",
            platform: "apple_music",
            artistName: "Pop Smoke",
            songTitle: "Gangstas"
        )
    }
    .padding()
}
