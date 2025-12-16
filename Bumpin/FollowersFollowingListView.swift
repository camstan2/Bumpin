import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum FollowListType {
    case following
    case followers
    
    var title: String {
        switch self {
        case .following: return "Following"
        case .followers: return "Followers"
        }
    }
}

struct FollowersFollowingListView: View {
    let userId: String
    let listType: FollowListType
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FollowListViewModel
    @State private var searchText = ""
    @State private var selectedUserId: String?
    @State private var showUserProfile = false
    
    init(userId: String, listType: FollowListType) {
        self.userId = userId
        self.listType = listType
        _viewModel = StateObject(wrappedValue: FollowListViewModel(userId: userId, listType: listType))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // User list
                if viewModel.isLoading {
                    loadingView
                } else if filteredUsers.isEmpty {
                    emptyStateView
                } else {
                    userList
                }
            }
            .navigationTitle(listType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadUsers()
                }
            }
            .fullScreenCover(isPresented: $showUserProfile) {
                if let userId = selectedUserId {
                    UserProfileView(userId: userId, showFullProfile: false)
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search \(listType.title.lowercased())...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - User List
    
    private var userList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredUsers) { user in
                    FollowUserRow(
                        user: user,
                        currentUserId: Auth.auth().currentUser?.uid ?? "",
                        onTap: {
                            selectedUserId = user.uid
                            showUserProfile = true
                        },
                        onFollowToggle: {
                            Task {
                                await viewModel.toggleFollow(userId: user.uid)
                            }
                        }
                    )
                    
                    if user.id != filteredUsers.last?.id {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: listType == .following ? "person.2" : "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No \(listType.title)")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No users found matching '\(searchText)'"
        } else {
            switch listType {
            case .following:
                return "Not following anyone yet"
            case .followers:
                return "No followers yet"
            }
        }
    }
    
    // MARK: - Filtered Users
    
    private var filteredUsers: [FollowUser] {
        if searchText.isEmpty {
            return viewModel.users
        } else {
            let query = searchText.lowercased()
            return viewModel.users.filter { user in
                user.username.lowercased().contains(query) ||
                user.displayName.lowercased().contains(query)
            }
        }
    }
}

// MARK: - Follow User Row

struct FollowUserRow: View {
    let user: FollowUser
    let currentUserId: String
    let onTap: () -> Void
    let onFollowToggle: () -> Void
    
    @State private var isFollowing: Bool
    
    init(user: FollowUser, currentUserId: String, onTap: @escaping () -> Void, onFollowToggle: @escaping () -> Void) {
        self.user = user
        self.currentUserId = currentUserId
        self.onTap = onTap
        self.onFollowToggle = onFollowToggle
        _isFollowing = State(initialValue: user.isFollowing)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile picture
                AsyncImage(url: user.profilePictureUrl.flatMap { URL(string: $0) }) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 24))
                            )
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        // Friend badge
                        if user.isFriend {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                Text("Friend")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                    }
                    
                    Text("@\(user.username)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Follow/Unfollow button (only if not current user)
                if user.uid != currentUserId {
                    followButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var followButton: some View {
        Button(action: {
            Task {
                // Optimistic UI update
                isFollowing.toggle()
                onFollowToggle()
            }
        }) {
            Text(isFollowing ? "Following" : "Follow")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isFollowing ? .primary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isFollowing ? Color(.systemGray5) : Color.purple)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Follow User Model

struct FollowUser: Identifiable {
    let id: String
    let uid: String
    let username: String
    let displayName: String
    let profilePictureUrl: String?
    let isFriend: Bool
    let isFollowing: Bool
    
    init(from profile: UserProfile, isFriend: Bool, isFollowing: Bool) {
        self.id = profile.uid
        self.uid = profile.uid
        self.username = profile.username
        self.displayName = profile.displayName
        self.profilePictureUrl = profile.profilePictureUrl
        self.isFriend = isFriend
        self.isFollowing = isFollowing
    }
    
    init(id: String, uid: String, username: String, displayName: String, profilePictureUrl: String?, isFriend: Bool, isFollowing: Bool) {
        self.id = id
        self.uid = uid
        self.username = username
        self.displayName = displayName
        self.profilePictureUrl = profilePictureUrl
        self.isFriend = isFriend
        self.isFollowing = isFollowing
    }
}

// MARK: - View Model

@MainActor
class FollowListViewModel: ObservableObject {
    @Published var users: [FollowUser] = []
    @Published var isLoading = false
    
    private let userId: String
    private let listType: FollowListType
    private let db = Firestore.firestore()
    
    init(userId: String, listType: FollowListType) {
        self.userId = userId
        self.listType = listType
    }
    
    func loadUsers() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ [FollowList] No current user")
            return
        }
        
        print("🔄 [FollowList] Loading \(listType.title) for user: \(userId)")
        print("   Current user ID: \(currentUserId)")
        
        do {
            // Get user IDs from the appropriate collection
            let userIds = try await fetchUserIds()
            print("📋 [FollowList] Found \(userIds.count) user IDs to fetch: \(userIds)")
            
            if userIds.isEmpty {
                print("⚠️ [FollowList] No user IDs found - list will be empty")
                users = []
                return
            }
            
            // Fetch user profiles
            var profiles: [UserProfile] = []
            var failedIds: [String] = []
            
            for userId in userIds {
                do {
                    let profile = try await db.collection("users").document(userId).getDocument().data(as: UserProfile.self)
                    profiles.append(profile)
                    print("✅ [FollowList] Loaded profile for: \(profile.username) (uid: \(profile.uid))")
                } catch {
                    failedIds.append(userId)
                    print("⚠️ [FollowList] Could not load profile for userId: \(userId)")
                    print("   Error: \(error.localizedDescription)")
                }
            }
            
            if !failedIds.isEmpty {
                print("⚠️ [FollowList] Failed to load \(failedIds.count) profiles: \(failedIds)")
            }
            
            print("📋 [FollowList] Successfully loaded \(profiles.count)/\(userIds.count) profiles")
            
            // Get current user's following and followers for relationship info
            let followingIds = try await fetchFollowingIds(for: currentUserId)
            let followerIds = try await fetchFollowerIds(for: currentUserId)
            
            print("📊 [FollowList] Current user relationships:")
            print("   Following: \(followingIds.count) users - \(Array(followingIds))")
            print("   Followers: \(followerIds.count) users - \(Array(followerIds))")
            
            // Create FollowUser objects with relationship info
            var followUsers: [FollowUser] = profiles.map { profile in
                let isFollowing = followingIds.contains(profile.uid)
                let isFollower = followerIds.contains(profile.uid)
                let isFriend = isFollowing && isFollower
                
                print("   User \(profile.username): following=\(isFollowing), follower=\(isFollower), friend=\(isFriend)")
                
                return FollowUser(
                    from: profile,
                    isFriend: isFriend,
                    isFollowing: isFollowing
                )
            }
            
            // Sort: Friends first, then following, then rest
            followUsers.sort { user1, user2 in
                // Both friends or both not friends
                if user1.isFriend == user2.isFriend {
                    if listType == .following {
                        // For following list, all are following, so sort alphabetically
                        return user1.displayName.lowercased() < user2.displayName.lowercased()
                    } else {
                        // For followers list, prioritize those we follow back
                        if user1.isFollowing == user2.isFollowing {
                            return user1.displayName.lowercased() < user2.displayName.lowercased()
                        }
                        return user1.isFollowing && !user2.isFollowing
                    }
                }
                // Friends come first
                return user1.isFriend && !user2.isFriend
            }
            
            users = followUsers
            print("✅ [FollowList] Successfully loaded \(users.count) users for \(listType.title)")
            print("   Friends: \(followUsers.filter { $0.isFriend }.count)")
            print("   Following: \(followUsers.filter { $0.isFollowing }.count)")
            
        } catch {
            print("❌ [FollowList] Error loading users: \(error)")
            print("   Error details: \(error.localizedDescription)")
            if let firestoreError = error as NSError? {
                print("   Firestore Error Code: \(firestoreError.code)")
                print("   Error Domain: \(firestoreError.domain)")
            }
            users = []
        }
    }
    
    private func fetchUserIds() async throws -> [String] {
        let collection = listType == .following ? "following" : "followers"
        print("🔍 [FollowList] Fetching from subcollection: users/\(userId)/\(collection)")
        
        // Try subcollections first (new method)
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection(collection)
            .getDocuments()
        
        var userIds = snapshot.documents.map { $0.documentID }
        print("✅ [FollowList] Found \(userIds.count) user IDs in subcollection: \(userIds)")
        
        // Fallback: If subcollections are empty, try user document arrays (old method)
        if userIds.isEmpty {
            print("⚠️ [FollowList] Subcollection empty, trying fallback to user document arrays...")
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if let data = userDoc.data(),
               let arrayIds = data[collection] as? [String], !arrayIds.isEmpty {
                userIds = arrayIds
                print("✅ [FollowList] Found \(userIds.count) user IDs in user document array: \(userIds)")
            } else {
                print("⚠️ [FollowList] No user IDs found in either subcollection or document array")
            }
        }
        
        return userIds
    }
    
    private func fetchFollowingIds(for userId: String) async throws -> Set<String> {
        // Try subcollection first
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("following")
            .getDocuments()
        
        var ids = Set(snapshot.documents.map { $0.documentID })
        
        // Fallback to user document array if subcollection is empty
        if ids.isEmpty {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let data = userDoc.data(),
               let arrayIds = data["following"] as? [String] {
                ids = Set(arrayIds)
            }
        }
        
        return ids
    }
    
    private func fetchFollowerIds(for userId: String) async throws -> Set<String> {
        // Try subcollection first
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("followers")
            .getDocuments()
        
        var ids = Set(snapshot.documents.map { $0.documentID })
        
        // Fallback to user document array if subcollection is empty
        if ids.isEmpty {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let data = userDoc.data(),
               let arrayIds = data["followers"] as? [String] {
                ids = Set(arrayIds)
            }
        }
        
        return ids
    }
    
    func toggleFollow(userId targetUserId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Find the user in the list
        guard let index = users.firstIndex(where: { $0.uid == targetUserId }) else { return }
        let user = users[index]
        
        do {
            if user.isFollowing {
                // Unfollow
                try await db.collection("users")
                    .document(currentUserId)
                    .collection("following")
                    .document(targetUserId)
                    .delete()
                
                try await db.collection("users")
                    .document(targetUserId)
                    .collection("followers")
                    .document(currentUserId)
                    .delete()
                
                // Update local state
                users[index] = FollowUser(
                    id: user.uid,
                    uid: user.uid,
                    username: user.username,
                    displayName: user.displayName,
                    profilePictureUrl: user.profilePictureUrl,
                    isFriend: false,
                    isFollowing: false
                )
                
                print("✅ Unfollowed user: \(targetUserId)")
            } else {
                // Follow
                try await db.collection("users")
                    .document(currentUserId)
                    .collection("following")
                    .document(targetUserId)
                    .setData(["timestamp": FieldValue.serverTimestamp()])
                
                try await db.collection("users")
                    .document(targetUserId)
                    .collection("followers")
                    .document(currentUserId)
                    .setData(["timestamp": FieldValue.serverTimestamp()])
                
                // Check if they follow us back to determine friend status
                let followerIds = try await fetchFollowerIds(for: currentUserId)
                let isFriend = followerIds.contains(targetUserId)
                
                // Update local state
                users[index] = FollowUser(
                    id: user.uid,
                    uid: user.uid,
                    username: user.username,
                    displayName: user.displayName,
                    profilePictureUrl: user.profilePictureUrl,
                    isFriend: isFriend,
                    isFollowing: true
                )
                
                print("✅ Followed user: \(targetUserId)")
                
                // Create follow notification
                await NotificationService.shared.createFollowNotification(followedUserId: targetUserId)
            }
            
            // Re-sort the list
            await loadUsers()
            
        } catch {
            print("❌ Error toggling follow: \(error)")
        }
    }
}

#Preview {
    FollowersFollowingListView(
        userId: "demo_user_id",
        listType: .following
    )
}


