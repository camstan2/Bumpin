import SwiftUI
import FirebaseFirestore
import MusicKit

struct EditPinnedItemsView: View {
    let title: String
    @State var currentItems: [PinnedItem]
    let itemType: PinnedType
    let onSave: ([PinnedItem]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchResults: [MusicSearchResult] = []
    @State private var isLoading = false
    @State private var editedItems: [PinnedItem] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current Items Section
                if !editedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Current \(itemType == .song ? "Songs" : itemType == .artist ? "Artists" : "Albums") (\(editedItems.count)/10)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if editedItems.count < 10 {
                                Button("Add More") {
                                    isSearching = true
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.purple)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Reorderable List
                        List {
                            ForEach(editedItems, id: \.id) { item in
                                PinnedItemRow(
                                    item: item,
                                    itemType: itemType,
                                    onRemove: {
                                        removeItem(item)
                                    }
                                )
                            }
                            .onMove(perform: moveItems)
                        }
                        .listStyle(PlainListStyle())
                    }
                } else {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: itemType == .song ? "music.note" : itemType == .artist ? "person.wave.2" : "opticaldisc")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("No \(itemType == .song ? "songs" : itemType == .artist ? "artists" : "albums") pinned")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Add your favorite \(itemType == .song ? "songs" : itemType == .artist ? "artists" : "albums") to showcase them")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Add \(itemType == .song ? "Songs" : itemType == .artist ? "Artists" : "Albums")") {
                            isSearching = true
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedItems)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedItems.isEmpty)
                }
            }
        }
        .onAppear {
            editedItems = currentItems
        }
        .sheet(isPresented: $isSearching) {
            ComprehensiveSearchView(
                pinnedSelectionMode: true,
                pinnedItemType: itemType == .song ? "song" : (itemType == .album ? "album" : "artist"),
                onPinnedItemsSelected: { selectedItems in
                    for item in selectedItems {
                    addItem(item)
                    }
                }
            )
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        editedItems.move(fromOffsets: source, toOffset: destination)
    }
    
    private func removeItem(_ item: PinnedItem) {
        editedItems.removeAll { $0.id == item.id }
    }
    
    private func addItem(_ searchResult: MusicSearchResult) {
        guard editedItems.count < 10 else { return }
        
        let newItem = PinnedItem(
            id: searchResult.id,
            title: searchResult.title,
            artistName: searchResult.artistName,
            albumName: searchResult.albumName,
            artworkURL: searchResult.artworkURL,
            itemType: searchResult.itemType,
            dateAdded: Date()
        )
        
        // Check if item already exists
        if !editedItems.contains(where: { $0.id == newItem.id }) {
            editedItems.append(newItem)
        }
    }
}

struct PinnedItemRow: View {
    let item: PinnedItem
    let itemType: PinnedType
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Drag Handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            // Artwork
            Group {
                if let artworkURL = item.artworkURL, let url = URL(string: artworkURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: itemType == .artist ? 25 : 6)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: itemType == .song ? "music.note" : itemType == .artist ? "person.wave.2" : "opticaldisc")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: itemType == .artist ? 25 : 6)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: itemType == .song ? "music.note" : itemType == .artist ? "person.wave.2" : "opticaldisc")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(itemType == .artist ? 25 : 6)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if itemType != .artist {
                    Text(item.artistName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

