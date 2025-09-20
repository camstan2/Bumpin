import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct EditPinnedListsView: View {
    let title: String
    @State var currentLists: [PinnedList]
    let onSave: ([PinnedList]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedLists: [PinnedList] = []
    @State private var availableLists: [MusicList] = []
    @State private var isLoadingLists = false
    @State private var showingListPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current Lists Section
                if !editedLists.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Pinned Lists (\(editedLists.count)/10)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if editedLists.count < 10 {
                                Button("Add More") {
                                    loadAvailableLists()
                                    showingListPicker = true
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.purple)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Reorderable List
                        List {
                            ForEach(editedLists, id: \.id) { list in
                                PinnedListRow(
                                    list: list,
                                    onRemove: {
                                        removeList(list)
                                    }
                                )
                            }
                            .onMove(perform: moveLists)
                        }
                        .listStyle(PlainListStyle())
                    }
                } else {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("No lists pinned")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Pin your favorite music lists to showcase them")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Add Lists") {
                            loadAvailableLists()
                            showingListPicker = true
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
                        onSave(editedLists)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedLists.isEmpty)
                }
            }
        }
        .onAppear {
            editedLists = currentLists
        }
        .sheet(isPresented: $showingListPicker) {
            ListPickerView(
                availableLists: availableLists,
                currentLists: editedLists,
                onAdd: { list in
                    addList(list)
                }
            )
        }
    }
    
    private func moveLists(from source: IndexSet, to destination: Int) {
        editedLists.move(fromOffsets: source, toOffset: destination)
    }
    
    private func removeList(_ list: PinnedList) {
        editedLists.removeAll { $0.id == list.id }
    }
    
    private func addList(_ musicList: MusicList) {
        guard editedLists.count < 10 else { return }
        
        let newPinnedList = PinnedList(
            id: musicList.id,
            name: musicList.title,
            description: musicList.description,
            coverImageUrl: musicList.coverImageUrl,
            dateAdded: Date()
        )
        
        // Check if list already exists
        if !editedLists.contains(where: { $0.id == newPinnedList.id }) {
            editedLists.append(newPinnedList)
        }
    }
    
    private func loadAvailableLists() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingLists = true
        let db = Firestore.firestore()
        
        db.collection("musicLists")
            .whereField("createdBy", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoadingLists = false
                    
                    if let error = error {
                        print("❌ Error loading lists: \(error.localizedDescription)")
                        return
                    }
                    
                    let lists = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: MusicList.self)
                    } ?? []
                    
                    // Filter out already pinned lists
                    availableLists = lists.filter { list in
                        !editedLists.contains { $0.id == list.id }
                    }
                }
            }
    }
}

struct PinnedListRow: View {
    let list: PinnedList
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Drag Handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            // Cover Art
            Group {
                if let coverImageUrl = list.coverImageUrl, let url = URL(string: coverImageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let description = list.description, !description.isEmpty {
                    Text(description)
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

struct ListPickerView: View {
    let availableLists: [MusicList]
    let currentLists: [PinnedList]
    let onAdd: (MusicList) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if availableLists.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("No lists available")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Create some music lists first to pin them")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Create List") {
                            // This would navigate to create list view
                            dismiss()
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
                } else {
                    List(availableLists, id: \.id) { list in
                        ListPickerRow(
                            list: list,
                            isAdded: currentLists.contains { $0.id == list.id },
                            onAdd: {
                                onAdd(list)
                                dismiss()
                            }
                        )
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Select Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ListPickerRow: View {
    let list: MusicList
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Cover Art
            Group {
                if let coverImageUrl = list.coverImageUrl, let url = URL(string: coverImageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(list.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text("\(list.items.count) songs")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Add Button
            Button(action: onAdd) {
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.purple)
                }
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}
