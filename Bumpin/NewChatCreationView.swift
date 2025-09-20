import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// View for creating a new DM chat by searching and selecting users
struct NewChatCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [UserProfile] = []
    @State private var selectedUsers: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCreatingChat = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Selected Users Display
                if !selectedUsers.isEmpty {
                    selectedUsersSection
                }
                
                // Content
                if isLoading {
                    loadingView
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else if searchResults.isEmpty {
                    emptyStateView
                } else {
                    searchResultsList
                }
                
                // Bottom Action Bar
                if !selectedUsers.isEmpty {
                    bottomActionBar
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.count >= 2 {
                searchUsers(query: newValue)
            } else {
                searchResults = []
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search for users...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Selected Users Section
    
    private var selectedUsersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Selected (\(selectedUsers.count))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Clear All") {
                    selectedUsers.removeAll()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.purple)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(getSelectedUserProfiles(), id: \.uid) { user in
                        SelectedUserChip(user: user) {
                            selectedUsers.remove(user.uid)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedUsers.count == 1 ? "1 person selected" : "\(selectedUsers.count) people selected")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(selectedUsers.count == 1 ? "Direct message" : "Group chat")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: createChat) {
                    HStack(spacing: 8) {
                        if isCreatingChat {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "message.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(isCreatingChat ? "Creating..." : "Start Chat")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.purple)
                    )
                }
                .disabled(isCreatingChat)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching users...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Start a New Chat")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Search for users by username or display name to start a conversation")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No users found")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Try searching with a different username or display name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Search Results List
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { user in
                    UserSearchResultRow(
                        user: user, 
                        isSelected: selectedUsers.contains(user.uid)
                    ) {
                        toggleUserSelection(user.uid)
                    }
                    
                    if user.id != searchResults.last?.id {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleUserSelection(_ userId: String) {
        if selectedUsers.contains(userId) {
            selectedUsers.remove(userId)
        } else {
            selectedUsers.insert(userId)
        }
    }
    
    private func getSelectedUserProfiles() -> [UserProfile] {
        return searchResults.filter { selectedUsers.contains($0.uid) }
    }
    
    private func createChat() {
        guard !selectedUsers.isEmpty else { return }
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isCreatingChat = true
        
        // Build Conversation model-compatible payload
        let conversationId = UUID().uuidString
        var participantIds = Array(selectedUsers)
        if !participantIds.contains(currentUserId) {
            participantIds.append(currentUserId)
        }
        let participantKey = Conversation.makeParticipantKey(participantIds)
        let now = Date()
        
        // For now, place the conversation directly in everyone's inbox
        let inboxFor = participantIds
        let requestFor: [String] = []
        
        let conversationData: [String: Any] = [
            "id": conversationId,
            "participantIds": participantIds,
            "participantKey": participantKey,
            "inboxFor": inboxFor,
            "requestFor": requestFor,
            "lastMessage": NSNull(),
            "lastTimestamp": now,
            "lastReadAtByUser": [:] as [String: Any]
        ]
        
        let ref = db.collection("conversations").document(conversationId)
        ref.setData(conversationData) { error in
            if let error = error {
                DispatchQueue.main.async {
                    isCreatingChat = false
                    print("❌ Error creating conversation: \(error.localizedDescription)")
                }
                return
            }
            // Fetch the created conversation as a model and open it
            ref.getDocument { snap, err in
                DispatchQueue.main.async {
                    isCreatingChat = false
                    if let err = err {
                        print("❌ Error fetching created conversation: \(err.localizedDescription)")
                        dismiss()
                        return
                    }
                    if let snap = snap, let convo = try? snap.data(as: Conversation.self) {
                        print("✅ Conversation created successfully: \(conversationId)")
                        NotificationCenter.default.post(name: NSNotification.Name("OpenConversation"), object: convo)
                    }
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Search Function
    
    private func searchUsers(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let searchQuery = query.lowercased()
        
        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: searchQuery)
            .whereField("username", isLessThan: searchQuery + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        searchResults = []
                        return
                    }
                    
                    // Parse user profiles
                    var results: [UserProfile] = []
                    for document in documents {
                        do {
                            let user = try document.data(as: UserProfile.self)
                            // Filter out current user
                            if user.uid != Auth.auth().currentUser?.uid {
                                results.append(user)
                            }
                        } catch {
                            print("Error parsing user: \(error)")
                        }
                    }
                    
                    // Also search by display name
                    db.collection("users")
                        .whereField("displayName", isGreaterThanOrEqualTo: searchQuery)
                        .whereField("displayName", isLessThan: searchQuery + "\u{f8ff}")
                        .limit(to: 20)
                        .getDocuments { snapshot2, error2 in
                            DispatchQueue.main.async {
                                if let documents2 = snapshot2?.documents {
                                    for document in documents2 {
                                        do {
                                            let user = try document.data(as: UserProfile.self)
                                            // Filter out current user and duplicates
                                            if user.uid != Auth.auth().currentUser?.uid && 
                                               !results.contains(where: { $0.uid == user.uid }) {
                                                results.append(user)
                                            }
                                        } catch {
                                            print("Error parsing user: \(error)")
                                        }
                                    }
                                }
                                
                                searchResults = results
                            }
                        }
                }
            }
    }
}

// MARK: - User Search Result Row

struct UserSearchResultRow: View {
    let user: UserProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile Picture
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                    )
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("@\(user.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Selection State
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Selected User Chip

struct SelectedUserChip: View {
    let user: UserProfile
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Small Profile Picture
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                )
            
            // User Name
            Text(user.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}


// MARK: - Preview

#Preview {
    NewChatCreationView()
}
