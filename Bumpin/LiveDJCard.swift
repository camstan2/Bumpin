import SwiftUI

struct LiveDJCard: View {
    let session: LiveDJSession
    let djStreamingManager: DJStreamingManager
    @State private var showingDJSession = false
    
    var body: some View {
        VStack(spacing: 8) {
            // DJ Profile Picture
            if let profilePictureUrl = session.djProfilePictureUrl, let url = URL(string: profilePictureUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(session.djUsername.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            
            // Session Info
            VStack(spacing: 4) {
                Text(session.djUsername)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(session.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Status and Listener Count
                HStack(spacing: 4) {
                    Circle()
                        .fill(session.status == .live ? Color.red : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text("\(session.listenerCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "person.2")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Current Track (if available)
            if let currentTrack = session.currentTrack {
                VStack(spacing: 2) {
                    Text("🎵 \(currentTrack.title)")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Text(currentTrack.artistName)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 120)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            showingDJSession = true
        }
        .sheet(isPresented: $showingDJSession) {
            DJSessionView(session: session, djStreamingManager: djStreamingManager)
        }
    }
}

#Preview {
    LiveDJCard(
        session: LiveDJSession(
            djId: "test",
            djUsername: "DJ Mike",
            title: "Late Night Vibes",
            status: .live,
            currentTrack: CurrentTrack(
                trackId: "1",
                title: "Example Song",
                artistName: "Example Artist"
            ),
            listenerCount: 42
        ),
        djStreamingManager: DJStreamingManager.shared
    )
} 