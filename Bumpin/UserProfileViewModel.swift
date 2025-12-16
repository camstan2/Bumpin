import Foundation
import FirebaseAuth
import FirebaseFirestore

struct PinnedItem: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var artistName: String
    var albumName: String?
    var artworkURL: String?
    var itemType: String
    var dateAdded: Date

    // Legacy support
    var name: String {
        get { title }
        set { title = newValue }
    }
    
    var artworkUrl: String? {
        get { artworkURL }
        set { artworkURL = newValue }
    }

    // Support legacy documents that used different keys
    enum CodingKeys: String, CodingKey {
        case id, title, artistName, albumName, artworkURL, itemType, dateAdded
        // Legacy fields
        case name
        case artworkUrl
        case appleMusicId
    }

    init(id: String, title: String, artistName: String, albumName: String? = nil, artworkURL: String? = nil, itemType: String, dateAdded: Date = Date()) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkURL = artworkURL
        self.itemType = itemType
        self.dateAdded = dateAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = (try? container.decode(String.self, forKey: .id))
            ?? (try? container.decode(String.self, forKey: .appleMusicId))
            ?? UUID().uuidString
            
        title = (try? container.decode(String.self, forKey: .title))
            ?? (try? container.decode(String.self, forKey: .name))
            ?? ""
            
        artistName = (try? container.decode(String.self, forKey: .artistName)) ?? ""
        albumName = try? container.decode(String.self, forKey: .albumName)
        
        artworkURL = (try? container.decode(String.self, forKey: .artworkURL))
            ?? (try? container.decode(String.self, forKey: .artworkUrl))
            
        itemType = (try? container.decode(String.self, forKey: .itemType)) ?? "song"
        dateAdded = (try? container.decode(Date.self, forKey: .dateAdded)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artistName, forKey: .artistName)
        try container.encodeIfPresent(albumName, forKey: .albumName)
        try container.encodeIfPresent(artworkURL, forKey: .artworkURL)
        try container.encode(itemType, forKey: .itemType)
        try container.encode(dateAdded, forKey: .dateAdded)
    }
}

struct PinnedList: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var description: String?
    var coverImageUrl: String?
    var dateAdded: Date
    
    init(id: String, name: String, description: String? = nil, coverImageUrl: String? = nil, dateAdded: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.coverImageUrl = coverImageUrl
        self.dateAdded = dateAdded
    }
}

struct UserProfile: Identifiable, Codable, Equatable {
    var id: String { uid }
    let uid: String
    let email: String
    let username: String
    let displayName: String
    let createdAt: Date?
    let profilePictureUrl: String?
    let profileHeaderUrl: String?
    let bio: String?
    // NOTE: followers/following arrays removed - now using subcollections
    // Legacy fields kept as optional for backward compatibility during decoding
    let followers: [String]?
    let following: [String]?
    let isVerified: Bool?
    let roles: [String]?
    let reportCount: Int?
    let violationCount: Int?
    let warningCount: Int? = nil
    let lastWarningAt: Date? = nil
    let isMuted: Bool? = nil
    let mutedUntil: Date? = nil
    let isSuspended: Bool? = nil
    let suspensionReason: String? = nil
    let suspensionExpiresAt: Date? = nil
    let isBanned: Bool? = nil
    let banReason: String? = nil
    let banExpiresAt: Date? = nil
    let locationSharingWith: [String]? // Friends you share location with
    let showNowPlaying: Bool?
    let nowPlayingSong: String?
    let nowPlayingArtist: String?
    let nowPlayingAlbumArt: String?
    let nowPlayingUpdatedAt: Date?
    // Make these mutable
    var pinnedSongs: [PinnedItem]?
    var pinnedArtists: [PinnedItem]?
    var pinnedAlbums: [PinnedItem]? // new
    var pinnedLists: [PinnedItem]? // new
    var pinnedSongsRanked: Bool? // user option to show ranking badges for songs
    var pinnedArtistsRanked: Bool? // user option to show ranking badges for artists
    var pinnedAlbumsRanked: Bool? // user option to show ranking badges for albums
    var pinnedListsRanked: Bool? // user option to show ranking badges for lists
    
    // MARK: - Music Matchmaking Preferences
    var matchmakingOptIn: Bool? // User opted into weekly music matchmaking
    var matchmakingGender: String? // "male", "female", "non_binary", "prefer_not_to_say"
    var matchmakingPreferredGender: String? // "male", "female", "any"
    var matchmakingLastActive: Date? // Last time user was active for matchmaking purposes
    
    // MARK: - Social Scoring
    var socialScore: Double? // Overall social rating score (0.0-10.0)
    var totalSocialRatings: Int? // Total number of social ratings received
    var socialBadges: [String]? // Array of earned social badge IDs
    var socialScoreLastUpdated: Date? // Last time social score was updated
    
    // MARK: - Denormalized follow counts (optional for fast loads)
    var followerCount: Int?
    var followingCount: Int?
}

class UserProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activityFeed: [ActivityItem] = []
    @Published var logCount: Int = 0
    @Published var uniqueSongCount: Int = 0
    @Published var uniqueArtistCount: Int = 0
    @Published var uniqueAlbumCount: Int = 0
    @Published var reviewCount: Int = 0
    @Published var listCount: Int = 0
    @Published var likeCount: Int = 0
    @Published var isFollowing = false
    @Published var isFollowActionLoading = false
    
    // NEW: Subcollection-based counts
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var isLoadingCounts = false
    
    private var listener: ListenerRegistration?
    private var activityListener: ListenerRegistration?
    
    func fetchCurrentUserProfile() {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        errorMessage = nil
        listener?.remove()
        listener = Firestore.firestore().collection("users").document(user.uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let snapshot = snapshot else {
                    self.errorMessage = "No profile data found."
                    return
                }
                do {
                    let profile = try snapshot.data(as: UserProfile.self)
                    self.profile = profile
                    // Seed counts from denormalized fields if present
                    if let followerCount = profile.followerCount {
                        self.followerCount = followerCount
                    }
                    if let followingCount = profile.followingCount {
                        self.followingCount = followingCount
                    }
                } catch {
                    self.errorMessage = "Failed to decode profile."
                }
            }
    }

    func stopListeners() {
        listener?.remove(); listener = nil
        activityListener?.remove(); activityListener = nil
    }
    
    func fetchActivityFeed(for userId: String, limit: Int = 10) {
        activityListener?.remove()
        activityListener = Firestore.firestore()
            .collection("users").document(userId)
            .collection("activity")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("[Firestore] Failed to fetch activity feed: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else {
                    self.activityFeed = []
                    return
                }
                self.activityFeed = documents.compactMap { doc in
                    try? doc.data(as: ActivityItem.self)
                }
            }
    }

    func fetchStats(for userId: String) {
        Task {
            do {
                let logs = try await MusicLogStore.shared.fetchLogs(forUserId: userId)
                await MainActor.run {
                    self.logCount = logs.count
                    self.uniqueSongCount = Set(logs.filter { $0.itemType == "song" }.map { $0.itemId }).count
                    self.uniqueArtistCount = Set(logs.map { $0.artistName }).count
                    self.uniqueAlbumCount = Set(logs.filter { $0.itemType == "album" }.map { $0.itemId }).count
                    self.reviewCount = logs.filter { ($0.review?.isEmpty == false) }.count
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        // Fetch lists
        MusicList.fetchListsForUser(userId: userId) { lists, error in
            guard let lists = lists else { return }
            DispatchQueue.main.async {
                self.listCount = lists.count
            }
        }
        
        // Fetch likes
        UserLike.getUserLikes(userId: userId) { likes, error in
            guard let likes = likes else { return }
            DispatchQueue.main.async {
                self.likeCount = likes.count
                }
            }
    }
    
    // MARK: - Follow/Unfollow Methods
    
    // NEW: Fetch follower/following counts from subcollections
    func fetchFollowerCount(for userId: String) async -> Int {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("followers")
                .getDocuments()
            return snapshot.documents.count
        } catch {
            print("❌ Error fetching follower count: \(error.localizedDescription)")
            return 0
        }
    }
    
    func fetchFollowingCount(for userId: String) async -> Int {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(userId)
                .collection("following")
                .getDocuments()
            return snapshot.documents.count
        } catch {
            print("❌ Error fetching following count: \(error.localizedDescription)")
            return 0
        }
    }
    
    func loadFollowCounts(for userId: String) {
        isLoadingCounts = true
        Task {
            let db = Firestore.firestore()
            let docRef = db.collection("users").document(userId)
            
            do {
                let snapshot = try await docRef.getDocument()
                let data = snapshot.data() ?? [:]
                
                var follower = data["followerCount"] as? Int
                var following = data["followingCount"] as? Int
                
                // If counts are missing, fall back to subcollection counts (slow path)
                if follower == nil || following == nil {
                    async let followersTask = fetchFollowerCount(for: userId)
                    async let followingTask = fetchFollowingCount(for: userId)
                    
                    let fetchedFollowers = try? await followersTask
                    let fetchedFollowing = try? await followingTask
                    
                    if follower == nil { follower = fetchedFollowers }
                    if following == nil { following = fetchedFollowing }
                    
                    // Backfill counts to the user document for faster future loads
                    var updates: [String: Any] = [:]
                    if let follower = follower { updates["followerCount"] = follower }
                    if let following = following { updates["followingCount"] = following }
                    if !updates.isEmpty {
                        try? await docRef.setData(updates, merge: true)
                    }
                }
                
                await MainActor.run {
                    self.followerCount = follower ?? 0
                    self.followingCount = following ?? 0
                    self.isLoadingCounts = false
                    print("✅ Loaded counts - Followers: \(self.followerCount), Following: \(self.followingCount)")
                }
                
            } catch {
                print("❌ Error loading follow counts: \(error.localizedDescription)")
                // Fallback to 0 if everything fails
                await MainActor.run {
                    self.followerCount = 0
                    self.followingCount = 0
                    self.isLoadingCounts = false
                }
            }
        }
    }
    
    func checkIfFollowing(userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ [checkIfFollowing] No current user")
            return
        }
        
        print("🔍 [checkIfFollowing] Checking if \(currentUserId) follows \(userId)")
        
        // Check the following subcollection instead of the array
        Firestore.firestore().collection("users")
            .document(currentUserId)
            .collection("following")
            .document(userId)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [checkIfFollowing] Error: \(error.localizedDescription)")
                } else {
                    let exists = snapshot?.exists ?? false
                    print("📊 [checkIfFollowing] Document exists: \(exists)")
                    print("   Path: users/\(currentUserId)/following/\(userId)")
                }
                
                DispatchQueue.main.async {
                    self.isFollowing = snapshot?.exists ?? false
                    print("✅ [checkIfFollowing] isFollowing set to: \(self.isFollowing)")
                }
            }
    }
    
    func toggleFollow(userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        guard currentUserId != userId else { return } // Can't follow yourself
        
        isFollowActionLoading = true
        
        if isFollowing {
            unfollowUser(currentUserId: currentUserId, targetUserId: userId)
        } else {
            // If offline, enqueue and optimistically update UI
            if !OfflineActionQueue.shared.isOnline {
                OfflineActionQueue.shared.enqueueFollow(currentUserId: currentUserId, targetUserId: userId)
                DispatchQueue.main.async {
                    self.isFollowActionLoading = false
                    self.isFollowing = true
                    self.followingCount += 1
                }
                return
            }
            followUser(currentUserId: currentUserId, targetUserId: userId)
        }
    }
    
    private func followUser(currentUserId: String, targetUserId: String) {
        let db = Firestore.firestore()
        
        print("🔄 [followUser] Starting follow action")
        print("   Current user: \(currentUserId)")
        print("   Target user: \(targetUserId)")
        
        // Use subcollections instead of arrays
        Task {
            do {
                // Step 1: Add to current user's following subcollection
                print("📝 [followUser] Writing to users/\(currentUserId)/following/\(targetUserId)")
                try await db.collection("users")
                    .document(currentUserId)
                    .collection("following")
                    .document(targetUserId)
                    .setData(["timestamp": FieldValue.serverTimestamp()])
                print("✅ [followUser] Step 1 complete")
                
                // Optimistically mark as following and update the TARGET user's follower count
                await MainActor.run {
                    self.isFollowing = true
                    self.followerCount += 1 // Target user gains a follower
                }
                
                // Step 2: Add to target user's followers subcollection
                print("📝 [followUser] Writing to users/\(targetUserId)/followers/\(currentUserId)")
                try await db.collection("users")
                    .document(targetUserId)
                    .collection("followers")
                    .document(currentUserId)
                    .setData(["timestamp": FieldValue.serverTimestamp()])
                print("✅ [followUser] Step 2 complete")
                
                // Create follow notification first (this is the important user-facing action)
                await NotificationService.shared.createFollowNotification(followedUserId: targetUserId)
                print("✅ [followUser] Notification created")
                
                await MainActor.run {
                    self.isFollowActionLoading = false
                    print("✅ [followUser] Successfully followed user: \(targetUserId)")
                }
                
                // Step 3: Denormalized counters for fast loads (fire-and-forget, don't let failures affect the follow state)
                Task.detached {
                    do {
                        // Use setData with merge to handle cases where the field doesn't exist
                        try await db.collection("users")
                            .document(currentUserId)
                            .setData(["followingCount": FieldValue.increment(Int64(1))], merge: true)
                        
                        try await db.collection("users")
                            .document(targetUserId)
                            .setData(["followerCount": FieldValue.increment(Int64(1))], merge: true)
                        
                        print("✅ [followUser] Denormalized counters updated")
                    } catch {
                        print("⚠️ [followUser] Failed to update denormalized counters (non-critical): \(error)")
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isFollowActionLoading = false
                    self.isFollowing = false // Revert optimistic update
                    self.followerCount = max(0, self.followerCount - 1) // Revert count
                    self.errorMessage = "Unable to follow user. Please try again."
                    print("❌ [followUser] Error following user: \(error)")
                    print("   Error details: \(error)")
                    
                    // Show alert to user
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFollowError"),
                        object: nil,
                        userInfo: ["message": "Unable to follow user. Please try again."]
                    )
                }
            }
        }
    }
    
    private func unfollowUser(currentUserId: String, targetUserId: String) {
        let db = Firestore.firestore()
        
        print("🔄 [unfollowUser] Starting unfollow action")
        print("   Current user: \(currentUserId)")
        print("   Target user: \(targetUserId)")
        
        // Use subcollections instead of arrays
        Task {
            do {
                // Step 1: Remove from current user's following subcollection
                print("📝 [unfollowUser] Deleting users/\(currentUserId)/following/\(targetUserId)")
                try await db.collection("users")
                    .document(currentUserId)
                    .collection("following")
                    .document(targetUserId)
                    .delete()
                print("✅ [unfollowUser] Step 1 complete")
                
                // Optimistically mark as not following and update the TARGET user's follower count
                await MainActor.run {
                    self.isFollowing = false
                    self.followerCount = max(0, self.followerCount - 1) // Target user loses a follower
                }
                
                // Step 2: Remove from target user's followers subcollection
                print("📝 [unfollowUser] Deleting users/\(targetUserId)/followers/\(currentUserId)")
                try await db.collection("users")
                    .document(targetUserId)
                    .collection("followers")
                    .document(currentUserId)
                    .delete()
                print("✅ [unfollowUser] Step 2 complete")
                
                await MainActor.run {
                    self.isFollowActionLoading = false
                    print("✅ [unfollowUser] Successfully unfollowed user: \(targetUserId)")
                }
                
                // Step 3: Denormalized counters for fast loads (fire-and-forget, don't let failures affect the unfollow state)
                Task.detached {
                    do {
                        // Use setData with merge to handle cases where the field doesn't exist
                        try await db.collection("users")
                            .document(currentUserId)
                            .setData(["followingCount": FieldValue.increment(Int64(-1))], merge: true)
                        
                        try await db.collection("users")
                            .document(targetUserId)
                            .setData(["followerCount": FieldValue.increment(Int64(-1))], merge: true)
                        
                        print("✅ [unfollowUser] Denormalized counters updated")
                    } catch {
                        print("⚠️ [unfollowUser] Failed to update denormalized counters (non-critical): \(error)")
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isFollowActionLoading = false
                    self.isFollowing = true // Revert optimistic update
                    self.followerCount += 1 // Revert count
                    self.errorMessage = "Unable to unfollow user. Please try again."
                    print("❌ [unfollowUser] Error unfollowing user: \(error)")
                    print("   Error details: \(error)")
                    
                    // Show alert to user
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFollowError"),
                        object: nil,
                        userInfo: ["message": "Unable to unfollow user. Please try again."]
                    )
                }
            }
        }
    }
    
    // Get users that the current user is following
    static func getFollowingUsers(completion: @escaping ([UserProfile]?, Error?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(nil, NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]))
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = snapshot?.data(),
                  let following = data["following"] as? [String],
                  !following.isEmpty else {
                completion([], nil)
                return
            }
            
            // Batch fetch following users (Firestore limits 'in' queries to 10 items)
            let batches = following.chunked(into: 10)
            var allUsers: [UserProfile] = []
            let dispatchGroup = DispatchGroup()
            
            for batch in batches {
                dispatchGroup.enter()
                db.collection("users").whereField("uid", in: batch).getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        let users = documents.compactMap { try? $0.data(as: UserProfile.self) }
                        allUsers.append(contentsOf: users)
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(allUsers, nil)
                }
            }
    }
    
    // MARK: - Fetch User Profile by ID
    
    /// Fetch a user profile by user ID (for social rating system)
    func fetchUserProfile(userId: String) async throws -> UserProfile {
        let db = Firestore.firestore()
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard document.exists else {
            throw NSError(domain: "UserProfile", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        return try document.data(as: UserProfile.self)
    }
    
    /// Fetch multiple user profiles by IDs
    func fetchUserProfiles(userIds: [String]) async throws -> [UserProfile] {
        guard !userIds.isEmpty else { return [] }
        
        let db = Firestore.firestore()
        var profiles: [UserProfile] = []
        
        // Firestore 'in' queries are limited to 10 items, so we need to batch
        let batches = userIds.chunked(into: 10)
        
        for batch in batches {
            let snapshot = try await db.collection("users")
                .whereField("uid", in: batch)
                .getDocuments()
            
            let batchProfiles = snapshot.documents.compactMap { document in
                try? document.data(as: UserProfile.self)
            }
            
            profiles.append(contentsOf: batchProfiles)
        }
        
        return profiles
    }
    
    // MARK: - Migration Function
    
    /// Migrates legacy array-based followers/following to subcollections
    /// Call this once for users with existing data
    static func migrateFollowDataToSubcollections(for userId: String) async throws {
        let db = Firestore.firestore()
        
        print("🔄 [Migration] Starting follow data migration for user: \(userId)")
        
        // Fetch user document
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let data = userDoc.data() else {
            print("⚠️ [Migration] No user data found")
            return
        }
        
        // Migrate followers
        if let followers = data["followers"] as? [String], !followers.isEmpty {
            print("📦 [Migration] Migrating \(followers.count) followers...")
            for followerId in followers {
                do {
                    try await db.collection("users")
                        .document(userId)
                        .collection("followers")
                        .document(followerId)
                        .setData(["timestamp": FieldValue.serverTimestamp(), "migrated": true])
                    print("✅ [Migration] Migrated follower: \(followerId)")
                } catch {
                    print("❌ [Migration] Failed to migrate follower \(followerId): \(error)")
                }
            }
        }
        
        // Migrate following
        if let following = data["following"] as? [String], !following.isEmpty {
            print("📦 [Migration] Migrating \(following.count) following...")
            for targetId in following {
                do {
                    // Add to current user's following subcollection
                    try await db.collection("users")
                        .document(userId)
                        .collection("following")
                        .document(targetId)
                        .setData(["timestamp": FieldValue.serverTimestamp(), "migrated": true])
                    
                    // Add to target user's followers subcollection
                    try await db.collection("users")
                        .document(targetId)
                        .collection("followers")
                        .document(userId)
                        .setData(["timestamp": FieldValue.serverTimestamp(), "migrated": true])
                    
                    print("✅ [Migration] Migrated following: \(targetId)")
                } catch {
                    print("❌ [Migration] Failed to migrate following \(targetId): \(error)")
                }
            }
        }
        
        print("✅ [Migration] Completed follow data migration for user: \(userId)")
    }
    
    deinit {
        listener?.remove()
        activityListener?.remove()
    }
}

// Extension to help with batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 