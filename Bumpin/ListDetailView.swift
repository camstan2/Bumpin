import SwiftUI
import FirebaseAuth

struct ListDetailView: View {
    let list: MusicList
    var isOwner: Bool {
        Auth.auth().currentUser?.uid == list.userId
    }
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 8) {
                    Text(list.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    if let desc = list.description, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Button(action: { toggleListRepost() }) {
                            Label("Repost", systemImage: "arrow.2.squarepath")
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        Spacer()
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                
                // Items Section
                HStack {
                    Text("Items")
                        .font(.headline)
                    Spacer()
                    Text("\(list.items.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                if list.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundColor(.gray)
                        Text("No items in this list.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(list.items.enumerated()), id: \.offset) { index, item in
                                itemView(for: item, at: index)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isOwner {
                        Menu {
                            Button("Edit List") {
                                onEdit?()
                            }
                            Button("Delete List", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Delete List", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete?()
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Are you sure you want to delete '\(list.title)'? This action cannot be undone.")
            }
        }
    }
    
    @ViewBuilder
    private func itemView(for item: String, at index: Int) -> some View {
        if let data = item.data(using: .utf8),
           let result = try? JSONDecoder().decode(MusicSearchResult.self, from: data) {
            // Modern JSON format - show full music item
            HStack(spacing: 12) {
                EnhancedArtworkView(
                    artworkUrl: result.artworkURL,
                    itemType: result.itemType,
                    size: 50
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !result.artistName.isEmpty {
                        Text(result.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(result.itemType.capitalized)
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.purple.opacity(0.1))
                        )
                }
                
                Spacer()
                
                Text("#\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        } else {
            // Legacy format - show basic text
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                    Image(systemName: "music.note")
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Legacy Item")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("#\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
    }
    
    private func toggleListRepost() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // Treat list repost as item-level with itemType "list"
        Repost.hasReposted(userId: uid, itemId: list.id, itemType: "list") { exists in
            if exists {
                Repost.remove(forUser: uid, itemId: list.id, itemType: "list") { _ in }
            } else {
                Repost.add(Repost(itemId: list.id, itemType: "list", userId: uid)) { _ in }
            }
        }
    }
} 