
import SwiftUI

// Shared helper types extracted from PartyDiscoveryView

enum FriendStatus {
    case online, offline, away
    var displayText: String {
        switch self { case .online: return "Online"; case .offline: return "Offline"; case .away: return "Away" }
    }
    var color: Color {
        switch self { case .online: return .green; case .offline: return .gray; case .away: return .orange }
    }
}

struct FriendRowView: View {
    let friend: UserProfile
    let status: FriendStatus
    let isLocationSharing: Bool
    let onToggleLocationSharing: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            if let profileUrl = friend.profilePictureUrl, let url = URL(string: profileUrl) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                    .frame(width: 40, height: 40).clipShape(Circle())
            } else {
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 40)
                    .overlay(Text(String(friend.displayName.prefix(1)).uppercased()).font(.headline).fontWeight(.medium).foregroundColor(.white))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(friend.displayName).font(.subheadline).fontWeight(.medium)
                    Circle().fill(status.color).frame(width: 8, height: 8)
                }
                HStack(spacing: 4) {
                    Text("@\(friend.username)").font(.caption).foregroundColor(.secondary)
                    Text("• \(status.displayText)").font(.caption).foregroundColor(status.color)
                }
            }
            Spacer()
            Button(action: onToggleLocationSharing) {
                HStack(spacing: 4) {
                    Image(systemName: isLocationSharing ? "location.fill" : "location").font(.caption)
                        .foregroundColor(isLocationSharing ? .blue : .gray)
                    Text(isLocationSharing ? "Sharing" : "Share").font(.caption)
                        .foregroundColor(isLocationSharing ? .blue : .gray)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(isLocationSharing ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1)))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// TopicChatCard moved to PartyDiscoveryView.swift as private struct

struct ExploreSectionDetailView: View {
    let title: String
    let parties: [Party]
    let onJoin: (Party) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(parties) { p in
                        PartyCard(party: p, currentLocation: nil, onJoin: { onJoin(p) }, isNearbyParty: false, isExploreParty: false)
                    }
                }
                .padding(.horizontal, 0).padding(.vertical, 16)
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct MapFiltersView: View {
    @Binding var selectedFilter: MapFilter
    let onApply: (MapFilter) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(MapFilter.allCases, id: \.self) { f in
                    HStack { Text(f.displayName); Spacer(); if f == selectedFilter { Image(systemName: "checkmark") } }
                        .contentShape(Rectangle()).onTapGesture { selectedFilter = f }
                }
            }
            .navigationTitle("Map Filters")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Apply") { onApply(selectedFilter); dismiss() } } }
        }
    }
}

struct EnhancedPartyDetailView: View {
    let party: Party
    let onQuickJoin: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(party.name).font(.title2).fontWeight(.bold)
                Text(party.hostName).font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Button("Join", action: onQuickJoin).buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Party")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
