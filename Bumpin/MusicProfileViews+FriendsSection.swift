import SwiftUI

extension MusicProfileView {
    @ViewBuilder
    var friendsLogsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Always render the header so the section is visible
            Text("Friends' Logs")
                .font(.headline)
            if friendIds.isEmpty {
                // If empty, still render an empty view so layout is stable
                EmptyView()
            } else {
                EnhancedFriendsLogsSection(
                    itemId: musicItem.id,
                    itemType: musicItem.itemType,
                    itemTitle: musicItem.title
                )
            }
        }
    }
}
