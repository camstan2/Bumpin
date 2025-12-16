import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Full-screen view showing likes, dislikes (thumbs down), and reposts for a log
struct LogActivityView: View {
    let logId: String
    let log: MusicLog // To show rating info
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: ActivityTab = .likes
    @State private var likes: [ActivityUser] = []
    @State private var dislikes: [ActivityUser] = []
    @State private var reposts: [ActivityUser] = []
    @State private var isLoading = false
    
    enum ActivityTab: String, CaseIterable, Identifiable {
        case likes = "Likes"
        case dislikes = "Dislikes"
        case reposts = "Reposts"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .likes: return "heart.fill"
            case .dislikes: return "hand.thumbsdown.fill"
            case .reposts: return "arrow.2.squarepath"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Activity Type", selection: $selectedTab) {
                    ForEach(ActivityTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    let users = currentUsers
                    if users.isEmpty {
                        Spacer()
                        Text(emptyMessage)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(users) { user in
                                    ActivityUserRow(user: user, logItemId: log.itemId, logItemType: log.itemType)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            loadActivity()
        }
    }
    
    private var currentUsers: [ActivityUser] {
        let users: [ActivityUser]
        switch selectedTab {
        case .likes: 
            users = likes
            print("📱 [LogActivityView] Displaying Likes tab: \(users.count) users")
        case .dislikes: 
            users = dislikes
            print("📱 [LogActivityView] Displaying Dislikes tab: \(users.count) users")
        case .reposts: 
            users = reposts
            print("📱 [LogActivityView] Displaying Reposts tab: \(users.count) users")
        }
        print("   Usernames: \(users.map { $0.username }.joined(separator: ", "))")
        return users
    }
    
    private var emptyMessage: String {
        switch selectedTab {
        case .likes: return "No likes yet"
        case .dislikes: return "No dislikes yet"
        case .reposts: return "No reposts yet"
        }
    }
    
    private func loadActivity() {
        isLoading = true
        
        print("🔍 [LogActivityView] Loading activity for log: \(logId)")
        
        Task {
            // Load sequentially to avoid any potential race conditions
            let loadedLikes = await fetchActivityUsers(collection: "likes")
            let loadedDislikes = await fetchActivityUsers(collection: "thumbsDown")
            let loadedReposts = await fetchActivityUsers(collection: "reposts")
            
            print("✅ [LogActivityView] Loaded activity:")
            print("   Likes: \(loadedLikes.count) users - IDs: \(loadedLikes.map { $0.id })")
            print("   Likes usernames: \(loadedLikes.map { $0.username }.joined(separator: ", "))")
            print("   Dislikes: \(loadedDislikes.count) users - IDs: \(loadedDislikes.map { $0.id })")
            print("   Dislikes usernames: \(loadedDislikes.map { $0.username }.joined(separator: ", "))")
            print("   Reposts: \(loadedReposts.count) users - IDs: \(loadedReposts.map { $0.id })")
            print("   Reposts usernames: \(loadedReposts.map { $0.username }.joined(separator: ", "))")
            
            await MainActor.run {
                self.likes = loadedLikes
                self.dislikes = loadedDislikes
                self.reposts = loadedReposts
                self.isLoading = false
                
                print("🎯 [LogActivityView] AFTER ASSIGNMENT:")
                print("   self.likes: \(self.likes.count) users - \(self.likes.map { $0.username }.joined(separator: ", "))")
                print("   self.dislikes: \(self.dislikes.count) users - \(self.dislikes.map { $0.username }.joined(separator: ", "))")
                print("   self.reposts: \(self.reposts.count) users - \(self.reposts.map { $0.username }.joined(separator: ", "))")
            }
        }
    }
    
    private func fetchActivityUsers(collection: String) async -> [ActivityUser] {
        let db = Firestore.firestore()
        
        print("🔍 [LogActivityView] Fetching \(collection) for log: \(logId)")
        
        do {
            let snapshot = try await db.collection("logs").document(logId).collection(collection).getDocuments()
            
            print("📊 [LogActivityView] Found \(snapshot.documents.count) documents in \(collection)")
            
            var activityUsers: [ActivityUser] = []
            var seenUserIds = Set<String>() // Deduplicate users
            
            for doc in snapshot.documents {
                guard let userId = doc.data()["userId"] as? String else { continue }
                
                print("   - User ID: \(userId)")
                
                // Skip if we've already processed this user (deduplication)
                if seenUserIds.contains(userId) {
                    print("   ⚠️ Skipping duplicate user: \(userId)")
                    continue
                }
                seenUserIds.insert(userId)
                
                // Fetch user profile
                let userDoc = try await db.collection("users").document(userId).getDocument()
                guard let userData = userDoc.data() else {
                    print("   ⚠️ User profile not found for: \(userId)")
                    continue
                }
                
                let username = userData["username"] as? String ?? "Unknown"
                let avatarUrl = (userData["profilePictureUrl"] as? String)
                    ?? (userData["profileImageUrl"] as? String)
                    ?? (userData["profileImageURL"] as? String)
                
                // Fetch user's rating for this log's item
                let logsSnapshot = try await db.collection("logs")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("itemId", isEqualTo: log.itemId)
                    .whereField("itemType", isEqualTo: log.itemType)
                    .limit(to: 1)
                    .getDocuments()
                
                let rating = logsSnapshot.documents.first?.data()["rating"] as? Double
                
                activityUsers.append(ActivityUser(
                    id: userId,
                    username: username,
                    avatarUrl: avatarUrl,
                    rating: rating
                ))
                
                print("   ✅ Added user: \(username)")
            }
            
            print("✅ [LogActivityView] Fetched \(activityUsers.count) unique users from \(collection)")
            
            // Sort: friends/following first
            return await sortUsersAsync(activityUsers)
            
        } catch {
            print("❌ Error fetching \(collection): \(error)")
            return []
        }
    }
    
    private func sortUsers(_ users: [ActivityUser]) -> [ActivityUser] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return users.shuffled() }
        
        // This will be enhanced with following data once we fetch it
        // For now, return users as-is (will be improved asynchronously)
        return users
    }
    
    private func sortUsersAsync(_ users: [ActivityUser]) async -> [ActivityUser] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return users.shuffled() }
        
        let db = Firestore.firestore()
        
        do {
            // Fetch current user's following and followers
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            let following = userDoc.data()?["following"] as? [String] ?? []
            let followers = userDoc.data()?["followers"] as? [String] ?? []
            
            // Combine into friends/following set
            let friendsAndFollowing = Set(following + followers)
            
            // Partition users: friends/following first, then others (shuffled)
            let friendUsers = users.filter { friendsAndFollowing.contains($0.id) }
            let otherUsers = users.filter { !friendsAndFollowing.contains($0.id) }.shuffled()
            
            return friendUsers + otherUsers
            
        } catch {
            print("❌ Error fetching user relationships: \(error)")
            return users.shuffled()
        }
    }
}

// MARK: - Activity User Model
struct ActivityUser: Identifiable {
    let id: String // userId
    let username: String
    let avatarUrl: String?
    let rating: Double?
}

// MARK: - Activity User Row
struct ActivityUserRow: View {
    let user: ActivityUser
    let logItemId: String
    let logItemType: String
    
    @State private var isFollowing = false
    @State private var isLoadingFollow = false
    @State private var currentUserFollowing: [String] = []
    @State private var showUserProfile = false
    
    private var isCurrentUser: Bool {
        Auth.auth().currentUser?.uid == user.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture (tappable)
            Button(action: { showUserProfile = true }) {
                Group {
                    if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Username (tappable)
            Button(action: { showUserProfile = true }) {
                Text(user.username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Rating (if available)
            if let rating = user.rating {
                StarRatingDisplayView(
                    rating: rating,
                    starSize: 12,
                    spacing: 1,
                    showNumber: false
                )
                .padding(.leading, 4)
            }
            
            Spacer()
            
            // Follow/Unfollow button (only if not current user)
            if user.id != Auth.auth().currentUser?.uid {
                Button(action: { toggleFollow() }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isFollowing ? .primary : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isFollowing ? Color(.systemGray5) : Color.purple)
                        .cornerRadius(6)
                }
                .disabled(isLoadingFollow)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .onAppear {
            loadFollowStatus()
        }
        .fullScreenCover(isPresented: $showUserProfile) {
            UserProfileView(userId: user.id, showFullProfile: !isCurrentUser)
        }
    }
    
    private func loadFollowStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let db = Firestore.firestore()
            do {
                // Prefer dedicated subcollection for following relationships
                let snapshot = try await db.collection("users")
                    .document(currentUserId)
                    .collection("following")
                    .getDocuments()
                var following = snapshot.documents.map { $0.documentID }
                
                // Fallback to legacy array field if subcollection empty
                if following.isEmpty {
                let userDoc = try await db.collection("users").document(currentUserId).getDocument()
                    following = userDoc.data()?["following"] as? [String] ?? []
                }
                
                await MainActor.run {
                    self.currentUserFollowing = following
                    self.isFollowing = following.contains(user.id)
                }
            } catch {
                print("❌ Error loading follow status: \(error)")
            }
        }
    }
    
    private func toggleFollow() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoadingFollow = true
        
        Task {
            let db = Firestore.firestore()
            
            do {
                if isFollowing {
                    // Unfollow
                    try await db.collection("users").document(currentUserId).updateData([
                        "following": FieldValue.arrayRemove([user.id])
                    ])
                    try await db.collection("users").document(user.id).updateData([
                        "followers": FieldValue.arrayRemove([currentUserId])
                    ])
                    
                    await MainActor.run {
                        isFollowing = false
                        isLoadingFollow = false
                    }
                } else {
                    // Follow
                    try await db.collection("users").document(currentUserId).updateData([
                        "following": FieldValue.arrayUnion([user.id])
                    ])
                    try await db.collection("users").document(user.id).updateData([
                        "followers": FieldValue.arrayUnion([currentUserId])
                    ])
                    
                    await MainActor.run {
                        isFollowing = true
                        isLoadingFollow = false
                    }
                }
            } catch {
                print("❌ Error toggling follow: \(error)")
                await MainActor.run {
                    isLoadingFollow = false
                }
            }
        }
    }
}

