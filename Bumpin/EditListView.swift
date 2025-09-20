import SwiftUI
import FirebaseAuth
import FirebaseStorage

struct EditListView: View {
    let list: MusicList
    var onListUpdated: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String
    @State private var description: String
    @State private var items: [String]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showMusicSearch = false
    @State private var coverImage: UIImage? = nil
    @State private var showingImagePicker = false
    
    init(list: MusicList, onListUpdated: (() -> Void)? = nil) {
        self.list = list
        self.onListUpdated = onListUpdated
        _title = State(initialValue: list.title)
        _description = State(initialValue: list.description ?? "")
        _items = State(initialValue: list.items)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title").font(.headline)) {
                    TextField("List title", text: $title)
                }
                Section(header: Text("Description (optional)").font(.headline)) {
                    TextField("Description", text: $description)
                }
                Section(header: Text("Cover Image").font(.headline)) {
                    HStack(spacing: 12) {
                        Group {
                            if let img = coverImage {
                                Image(uiImage: img).resizable().scaledToFill()
                            } else if let url = list.coverImageUrl.flatMap(URL.init(string:)) {
                                AsyncImage(url: url) { phase in
                                    if let i = phase.image { i.resizable().scaledToFill() } else { Color(.systemGray5) }
                                }
                            } else {
                                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).overlay(Image(systemName: "photo").foregroundColor(.gray))
                            }
                        }
                        .frame(width: 72, height: 72)
                        .cornerRadius(8)
                        Spacer()
                        Button("Change Cover") { showingImagePicker = true }.foregroundColor(.purple)
                    }
                }
                Section(header: Text("Items").font(.headline)) {
                    Button(action: { showMusicSearch = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.purple)
                            Text("Search & Add Music")
                                .foregroundColor(.purple)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                            Text("No items yet.")
                                .foregroundColor(.secondary)
                            Text("Tap 'Search & Add Music' to add songs, albums, or artists")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(items.count) item\(items.count == 1 ? "" : "s") in list")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                itemView(for: item, at: index)
                            }
                        }
                    }
                }
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
                Section {
                    Button(action: saveList) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Changes")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Capsule().fill(Color.purple))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || items.isEmpty)
                }
            }
            .navigationTitle("Edit List")
            .navigationBarItems(leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() })
        }
        .sheet(isPresented: $showMusicSearch) {
            ListMusicSearchView(onItemsSelected: { selectedItems in
                // Add selected items to the list
                for item in selectedItems {
                    if let jsonData = try? JSONEncoder().encode(item),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        if !items.contains(jsonString) {
                            items.append(jsonString)
                        }
                    }
                }
            })
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $coverImage)
        }
    }
    
    func saveList() {
        isSaving = true
        errorMessage = nil
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to edit a list."
            isSaving = false
            return
        }
        var updatedList = MusicList(
            id: list.id,
            userId: userId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageUrl: list.coverImageUrl,
            items: items,
            createdAt: list.createdAt
        )
        func finishUpdate() {
            MusicList.updateList(updatedList) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        errorMessage = "Failed to update list: \(error.localizedDescription)"
                    } else {
                        onListUpdated?()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        if let img = coverImage, let uid = Auth.auth().currentUser?.uid, let data = img.jpegData(compressionQuality: 0.85) {
            let ref = Storage.storage().reference().child("lists/\(uid)/\(list.id)/covers/cover.jpg")
            ref.putData(data, metadata: nil) { _, err in
                if err != nil { finishUpdate(); return }
                ref.downloadURL { url, _ in
                    if let url = url { updatedList.coverImageUrl = url.absoluteString }
                    finishUpdate()
                }
            }
        } else {
            finishUpdate()
        }
    }
    
    @ViewBuilder
    private func itemView(for item: String, at index: Int) -> some View {
        if let data = item.data(using: .utf8),
           let result = try? JSONDecoder().decode(MusicSearchResult.self, from: data) {
            HStack(spacing: 12) {
                EnhancedArtworkView(
                    artworkUrl: result.artworkURL,
                    itemType: result.itemType,
                    size: 40
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
                
                Button(action: { 
                    if let itemIndex = items.firstIndex(of: item) {
                        items.remove(at: itemIndex)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        } else {
            // Fallback for any non-JSON items (legacy data)
            HStack {
                Text(item)
                    .font(.subheadline)
                Spacer()
                Button(action: { 
                    if let itemIndex = items.firstIndex(of: item) {
                        items.remove(at: itemIndex)
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }
} 