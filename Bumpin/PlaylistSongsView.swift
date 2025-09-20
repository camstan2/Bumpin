import SwiftUI

/// Simple list of songs in a playlist allowing user to pick one to log
struct PlaylistSongsView: View {
    let songs: [MusicSearchResult]
    let onSelect: (MusicSearchResult) -> Void
    
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            List(songs) { song in
                Button {
                    presentationMode.wrappedValue.dismiss()
                    onSelect(song)
                } label: {
                    HStack(spacing: 12) {
                        EnhancedArtworkView(
                            artworkUrl: song.artworkURL,
                            itemType: "song",
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title).font(.subheadline).fontWeight(.medium)
                            Text(song.artistName).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle").foregroundColor(.purple)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Playlist Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
