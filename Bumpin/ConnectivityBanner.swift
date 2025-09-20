import SwiftUI

struct ConnectivityBanner: View {
    @State private var isOnline: Bool = true
    var body: some View {
        Group {
            if !isOnline {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Offline – showing cached results")
                        .font(.footnote)
                    Spacer()
                    Button("Retry") {
                        NotificationCenter.default.post(name: Notification.Name("DiscoveryRetryRequested"), object: nil)
                    }
                }
                .padding(8)
                .background(Color.yellow.opacity(0.9))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: OfflineActionQueue.reachabilityChanged)) { note in
            if let online = note.object as? Bool { self.isOnline = online }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DiscoveryRetryRequested"))) { _ in
            // no-op here; the view listening will handle it. This keeps the publisher alive.
        }
    }
}


