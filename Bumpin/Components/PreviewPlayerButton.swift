import SwiftUI
import MusicKit

// MARK: - Preview Player Button Component

/// Button with integrated progress bar for playing 30-second music previews
struct PreviewPlayerButton: View {
    let itemId: String
    let itemType: String
    let platform: String?
    let songTitle: String
    let artistName: String
    let artworkURL: String?
    
    @ObservedObject private var previewService = PreviewPlayerService.shared
    @State private var previewUrl: URL?
    @State private var isCheckingPreview = true
    
    private var progress: Double {
        guard previewService.duration > 0 else { return 0 }
        return min(previewService.currentTime / previewService.duration, 1.0)
    }
    
    private var timeDisplay: String {
        let current = Int(previewService.currentTime)
        let total = Int(previewService.duration)
        return "\(current):\(String(format: "%02d", current % 60))/\(total):\(String(format: "%02d", total % 60))"
    }
    
    private var isThisPreviewPlaying: Bool {
        guard let url = previewUrl else { 
            print("❌ No preview URL available")
            return false 
        }
        let urlString = url.absoluteString
        let isPlaying = previewService.isPlaying
        let currentUrl = previewService.currentPreviewUrl
        let matches = currentUrl == urlString
        
        print("🎵 isThisPreviewPlaying check:")
        print("   - isPlaying: \(isPlaying)")
        print("   - currentUrl: \(currentUrl ?? "nil")")
        print("   - thisUrl: \(urlString)")
        print("   - matches: \(matches)")
        
        return isPlaying && matches
    }
    
    var body: some View {
        Group {
            if !isCheckingPreview {
                if previewUrl != nil {
                    previewButton
                }
                // If no preview URL, hide button entirely
            } else {
                loadingButton
            }
        }
        .onAppear {
            fetchPreviewUrl()
        }
    }
    
    // MARK: - Preview Button
    
    private var previewButton: some View {
        Button(action: {
            handlePreviewTap()
        }) {
            VStack(spacing: 0) {
                // Button content
                HStack(spacing: 8) {
                    Image(systemName: isThisPreviewPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 16)
                    
                    Text(isThisPreviewPlaying ? "Pause" : "Preview")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                
                // Integrated progress bar at bottom
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                }
                .frame(height: 4)
            }
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Loading Button
    
    private var loadingButton: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Checking preview...")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.5))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func handlePreviewTap() {
        guard let url = previewUrl else { return }
        
        print("🔘 Preview button tapped!")
        print("🔘 isThisPreviewPlaying: \(isThisPreviewPlaying)")
        
        if isThisPreviewPlaying {
            print("🔘 Calling PAUSE")
            // Pause current preview (keep position)
            previewService.pause()
        } else {
            print("🔘 Calling PLAY")
            // Play this preview (or resume if same URL) and store song info
            previewService.playPreview(
                url: url,
                songTitle: songTitle,
                artistName: artistName,
                itemId: itemId,
                artworkURL: artworkURL != nil ? URL(string: artworkURL!) : nil
            )
        }
    }
    
    // MARK: - Fetch Preview URL
    
    private func fetchPreviewUrl() {
        Task {
            // Only try Apple Music previews (Spotify disabled due to blocking issues)
            let fetchTask = Task<URL?, Never> {
            // Determine platform preference
            let isAppleMusicItem = platform?.lowercased().contains("apple") ?? true
            
            if isAppleMusicItem {
                    // Try Apple Music preview
                if let appleMusicUrl = await fetchAppleMusicPreview() {
                        return appleMusicUrl
                    }
                }
                
                // No Spotify fallback - it causes main thread blocking
                print("ℹ️ No Apple Music preview available (Spotify fallback disabled)")
                return nil
            }
            
            // Add timeout for Apple Music fetch (5 seconds should be plenty)
            let timeoutTask = Task<URL?, Never> {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                return nil
            }
            
            let result = await withTaskGroup(of: URL?.self) { group in
                group.addTask { await fetchTask.value }
                group.addTask { await timeoutTask.value }
                
                // Wait for the first task to complete
                if let firstResult = await group.next() {
                    // Cancel the other task
                    fetchTask.cancel()
                    timeoutTask.cancel()
                    return firstResult
                }
                
                return nil
            }
            
            if Task.isCancelled {
                print("⚠️ Preview fetch was cancelled")
            }
            
            // Update UI on main thread
            await MainActor.run {
                self.previewUrl = result
                self.isCheckingPreview = false
                
                if result == nil {
                    print("ℹ️ No preview available - hiding preview button")
                }
            }
        }
    }
    
    private func fetchAppleMusicPreview() async -> URL? {
        do {
            // Try to fetch from Apple Music catalog
            guard !itemId.isEmpty else { return nil }
            
            let songID = MusicItemID(itemId)
            let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: songID)
            let response = try await request.response()
            
            if let song = response.items.first,
               let previewAsset = song.previewAssets?.first {
                print("✅ Found Apple Music preview: \(previewAsset.url?.absoluteString ?? "nil")")
                return previewAsset.url
            }
        } catch {
            print("❌ Error fetching Apple Music preview: \(error)")
        }
        
        return nil
    }
    
    private func fetchSpotifyPreview() async -> URL? {
        // Search Spotify for the track
        let spotifyService = SpotifyService.shared
        
        do {
            let searchQuery = "\(songTitle) \(artistName)"
            let results = try await spotifyService.searchTracks(query: searchQuery)
            
            if let firstTrack = results.first,
               let previewUrlString = firstTrack.preview_url,
               let previewUrl = URL(string: previewUrlString) {
                print("✅ Found Spotify preview: \(previewUrlString)")
                return previewUrl
            }
        } catch {
            print("❌ Error fetching Spotify preview: \(error)")
        }
        
        return nil
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PreviewPlayerButton(
            itemId: "123456",
            itemType: "song",
            platform: "apple_music",
            songTitle: "Gangstas",
            artistName: "Pop Smoke",
            artworkURL: nil
        )
    }
    .padding()
    .background(Color.black)
}

