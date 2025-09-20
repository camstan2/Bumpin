import SwiftUI
import MusicKit

final class AppLifecyclePrefetch: ObservableObject {
    static let shared = AppLifecyclePrefetch()
    private init() {}
    func onForeground(viewModel: SocialFeedViewModel) {
        // Lightweight prefetch: refresh trending rails and genre trending
        Task { await viewModel.loadGenreTrendingAsync(for: viewModel.selectedGenre) }
        viewModel.prefetchTrendingRails()
        // Warm a couple of common search queries for faster perceived search
        Task { await self.warmSearchQueries(["drake", "taylor", "the weeknd"]) }
    }
    
    private func cacheKey(query: String, filter: String) -> String {
        "q=\(query.lowercased())|f=\(filter)"
    }
    
    private func warmSearchQueries(_ queries: [String]) async {
        for q in queries {
            let key = cacheKey(query: q, filter: "All")
            if SearchDiskCache.shared.load(key: key) != nil { continue }
            do {
                var request = MusicCatalogSearchRequest(term: q, types: [MusicKit.Song.self, MusicKit.Artist.self, MusicKit.Album.self])
                request.limit = 10
                let response = try await request.response()
                let songs = response.songs.map { MusicSearchResult(id: $0.id.rawValue, title: $0.title, artistName: $0.artistName, albumName: $0.albumTitle ?? "", artworkURL: $0.artwork?.url(width: 100, height: 100)?.absoluteString, itemType: "song", popularity: 0) }
                let artists = response.artists.map { MusicSearchResult(id: $0.id.rawValue, title: $0.name, artistName: $0.name, albumName: "", artworkURL: $0.artwork?.url(width: 100, height: 100)?.absoluteString, itemType: "artist", popularity: 0) }
                let albums = response.albums.compactMap { album -> MusicSearchResult? in
                    let t = album.title.lowercased()
                    if t.contains(" - single") || t == "single" || t.hasSuffix(" single") { return nil }
                    return MusicSearchResult(id: album.id.rawValue, title: album.title, artistName: album.artistName, albumName: album.title, artworkURL: album.artwork?.url(width: 100, height: 100)?.absoluteString, itemType: "album", popularity: 0)
                }
                let results = CachedSearchResults(users: [], songs: songs, artists: artists, albums: albums, lists: [], savedAt: Date())
                SearchDiskCache.shared.save(key: key, results: results)
            } catch {
                // ignore
            }
        }
    }
}

struct LifecyclePrefetchModifier: ViewModifier {
    @ObservedObject var prefetch = AppLifecyclePrefetch.shared
    @ObservedObject var vm: SocialFeedViewModel
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { phase in
                if phase == .active { prefetch.onForeground(viewModel: vm) }
            }
    }
}

extension View {
    func lifecyclePrefetch(with vm: SocialFeedViewModel) -> some View {
        modifier(LifecyclePrefetchModifier(vm: vm))
    }
}


