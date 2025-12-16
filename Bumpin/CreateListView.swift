import SwiftUI
import FirebaseAuth
import FirebaseStorage
import MusicKit

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
                            Text("No songs yet.")
                                .foregroundColor(.secondary)
                            Text("Tap 'Search & Add Music' to add songs to your list")
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
        .fullScreenCover(isPresented: $showMusicSearch) {
            ComprehensiveSearchView(
                listSelectionMode: true,
                onSongsSelected: { selectedSongs in
                    // Add selected songs to the list
                    for song in selectedSongs {
                        if let jsonData = try? JSONEncoder().encode(song),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        if !items.contains(jsonString) {
                            items.append(jsonString)
                            }
                        }
                    }
                }
            )
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
                    withAnimation {
                        if index >= 0 && index < items.count {
                    items.remove(at: index)
                        }
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
                    withAnimation {
                        if index >= 0 && index < items.count {
                    items.remove(at: index)
                        }
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