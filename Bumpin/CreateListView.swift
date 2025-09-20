import SwiftUI
import FirebaseAuth
import FirebaseStorage

struct CreateListView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var items: [String] = [] // Store as JSON strings for full metadata
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showMusicSearch = false
    @State private var coverImage: UIImage? = nil
    @State private var isUploadingCover = false
    @State private var showingImagePicker = false
    
    var onListCreated: (() -> Void)?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title").font(.headline)) {
                    TextField("List title", text: $title)
                }
                Section(header: Text("Description (optional)").font(.headline)) {
                    TextField("Description", text: $description)
                }
                Section(header: Text("Items").font(.headline)) {
                    // Cover image picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cover Image (optional)").font(.subheadline)
                        HStack(spacing: 12) {
                            Group {
                                if let img = coverImage {
                                    Image(uiImage: img).resizable().scaledToFill()
                                } else {
                                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                }
                            }
                            .frame(width: 72, height: 72)
                            .cornerRadius(8)
                            Spacer()
                            Button("Change Cover") { showMusicSearch = false; isUploadingCover = false; showingImagePicker = true }
                                .foregroundColor(.purple)
                        }
                    }
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
                            Text("\(items.count) item\(items.count == 1 ? "" : "s") added")
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
                            Text("Save List")
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
            .navigationTitle("Create List")
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
            errorMessage = "You must be logged in to create a list."
            isSaving = false
            return
        }
        var list = MusicList(
            id: UUID().uuidString,
            userId: userId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageUrl: nil,
            items: items,
            createdAt: Date()
        )
        func finishCreate() {
            MusicList.createList(list) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        errorMessage = "Failed to save list: \(error.localizedDescription)"
                    } else {
                        onListCreated?()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        if let img = coverImage, let uid = Auth.auth().currentUser?.uid {
            uploadListCover(img: img, ownerUid: uid, listId: list.id) { url in
                if let url = url { list.coverImageUrl = url }
                finishCreate()
            }
        } else {
            finishCreate()
        }
    }

    private func uploadListCover(img: UIImage, ownerUid: String, listId: String, completion: @escaping (String?) -> Void) {
        let resized = downscale(img, maxDim: 1024)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { completion(nil); return }
        let ref = Storage.storage().reference().child("lists/\(ownerUid)/\(listId)/covers/cover.jpg")
        ref.putData(data, metadata: nil) { _, err in
            if err != nil { completion(nil); return }
            ref.downloadURL { url, _ in completion(url?.absoluteString) }
        }
    }
    private func downscale(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxDim else { return image }
        let scale = maxDim / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
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

// MARK: - List Music Search View
struct ListMusicSearchView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab: ListSearchTab = .songs
    @State private var searchText = ""
    @State private var searchResults: [MusicSearchResult] = []
    @State private var isSearching = false
    @State private var searchErrorMessage: String?
    @State private var selectedItems: [MusicSearchResult] = []
    
    let onItemsSelected: ([MusicSearchResult]) -> Void
    
    enum ListSearchTab: String, CaseIterable, Identifiable {
        case songs = "Songs"
        case artists = "Artists"
        case albums = "Albums"
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Tabs
                Picker("Search Type", selection: $selectedTab) {
                    ForEach(ListSearchTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding([.horizontal, .top])
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(searchPlaceholder, text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onSubmit {
                            Task { await performSearch(query: searchText) }
                        }
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Selected items indicator
                if !selectedItems.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.purple)
                        Text("\(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s") selected")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                        Spacer()
                        Button("Clear All") {
                            selectedItems.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Search Results
                if let error = searchErrorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if !filteredResults.isEmpty {
                    List(filteredResults) { result in
                        resultRow(for: result)
                    }
                    .listStyle(PlainListStyle())
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: searchIcon)
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Search for \(selectedTab.rawValue.lowercased())")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Find \(selectedTab.rawValue.lowercased()) to add to your list")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Add Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add (\(selectedItems.count))") {
                        onItemsSelected(selectedItems)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selectedItems.isEmpty)
                }
            }
            .onChange(of: selectedTab) { _, _ in
                // Clear results when switching tabs
                            searchResults = []
            searchErrorMessage = nil
            }
        }
    }
    
    private var searchPlaceholder: String {
        switch selectedTab {
        case .songs:
            return "Search for songs..."
        case .artists:
            return "Search for artists..."
        case .albums:
            return "Search for albums..."
        }
    }
    
    private var searchIcon: String {
        switch selectedTab {
        case .songs:
            return "music.note"
        case .artists:
            return "person.fill"
        case .albums:
            return "opticaldisc"
        }
    }
    
    private var filteredResults: [MusicSearchResult] {
        switch selectedTab {
        case .songs:
            return searchResults.filter { $0.itemType == "song" }
        case .artists:
            return searchResults.filter { $0.itemType == "artist" }
        case .albums:
            return searchResults.filter { $0.itemType == "album" }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        // TODO: Implement actual search using MusicKit
        // For now, just simulate search
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        isSearching = false
    }
    
    private func toggleSelection(_ result: MusicSearchResult) {
        if let index = selectedItems.firstIndex(where: { $0.id == result.id }) {
            selectedItems.remove(at: index)
        } else {
            selectedItems.append(result)
        }
    }
    
    @ViewBuilder
    private func resultRow(for result: MusicSearchResult) -> some View {
        HStack(spacing: 12) {
            // Selection indicator
            Button(action: {
                toggleSelection(result)
            }) {
                Image(systemName: selectedItems.contains(where: { $0.id == result.id }) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedItems.contains(where: { $0.id == result.id }) ? .purple : .gray)
                    .font(.title2)
            }
            // Artwork
            EnhancedArtworkView(
                artworkUrl: result.artworkURL,
                itemType: result.itemType,
                size: 44
            )
            // Text content
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
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(result)
        }
    }
} 