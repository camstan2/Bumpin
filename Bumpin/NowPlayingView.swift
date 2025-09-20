import SwiftUI

struct NowPlayingView: View {
    let song: String?
    let artist: String?
    let albumArt: String?
    let updatedAt: Date?
    
    var body: some View {
        if let song = song, let artist = artist {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Now Playing")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let updatedAt = updatedAt {
                        Text(timeAgoString(from: updatedAt))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    // Album Art
                    if let albumArt = albumArt, let imageData = Data(base64Encoded: albumArt),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 20))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        
                        Text(artist)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    NowPlayingView(
        song: "Bohemian Rhapsody",
        artist: "Queen",
        albumArt: nil,
        updatedAt: Date()
    )
    .padding()
} 