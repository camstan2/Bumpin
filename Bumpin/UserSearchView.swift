import SwiftUI
import FirebaseFirestore

struct UserSearchView: View {
    @State private var searchText = ""
    @State private var results: [UserProfile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedUser: UserProfile? = nil
    @State private var searchWorkItem: DispatchWorkItem? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search users by username or name", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    .onSubmit { searchUsers() }
                    .onChange(of: searchText) { _, _ in
                        // Debounce networked search
                        searchWorkItem?.cancel()
                        let work = DispatchWorkItem { self.searchUsers() }
                        searchWorkItem = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
                    }
                    Button(action: searchUsers) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.purple)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding([.horizontal, .top])
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                List(results) { user in
                    Button(action: { selectedUser = user }) {
                        HStack(spacing: 16) {
                            if let url = user.profilePictureUrl, let imageUrl = URL(string: url) {
                                AsyncImage(url: imageUrl) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable().scaledToFit()
                                            .foregroundColor(.purple.opacity(0.5))
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable().scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(.purple.opacity(0.5))
                            }
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Search Users")
        }
        .sheet(item: $selectedUser) { user in
            UserProfileView(userId: user.uid)
        }
    }
    
    private func searchUsers() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        isLoading = true
        errorMessage = nil
        let db = Firestore.firestore()
        let searchLower = searchText.lowercased()
        db.collection("users")
            .whereField("username_lower", isGreaterThanOrEqualTo: searchLower)
            .whereField("username_lower", isLessThanOrEqualTo: searchLower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                var found: [UserProfile] = []
                if let docs = snapshot?.documents {
                    for doc in docs {
                        if let user = try? doc.data(as: UserProfile.self) {
                            found.append(user)
                        }
                    }
                }
                // Also search by displayName_lower if username search is empty
                if found.isEmpty {
                    db.collection("users")
                        .whereField("displayName_lower", isGreaterThanOrEqualTo: searchLower)
                        .whereField("displayName_lower", isLessThanOrEqualTo: searchLower + "\u{f8ff}")
                        .limit(to: 20)
                        .getDocuments { snapshot, error in
                            if let docs = snapshot?.documents {
                                for doc in docs {
                                    if let user = try? doc.data(as: UserProfile.self) {
                                        found.append(user)
                                    }
                                }
                            }
                            results = found
                        }
                } else {
                    results = found
                }
            }
    }
} 