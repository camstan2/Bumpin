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
    let followers: [String]?
    let following: [String]?
    let isVerified: Bool?
    let roles: [String]?
    let reportCount: Int?
    let violationCount: Int?
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
        // Fetch logs
        MusicLog.fetchLogsForUser(userId: userId) { logs, error in
            guard let logs = logs else { return }
            DispatchQueue.main.async {
                self.logCount = logs.count
                self.uniqueSongCount = Set(logs.filter { $0.itemType == "song" }.map { $0.itemId }).count
                self.uniqueArtistCount = Set(logs.map { $0.artistName }).count
                self.uniqueAlbumCount = Set(logs.filter { $0.itemType == "album" }.map { $0.itemId }).count
                self.reviewCount = logs.filter { ($0.review?.isEmpty == false) }.count
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
    
    func checkIfFollowing(userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("users").document(currentUserId)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                if let data = snapshot?.data(),
                   let following = data["following"] as? [String] {
                    DispatchQueue.main.async {
                        self.isFollowing = following.contains(userId)
                    }
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
                DispatchQueue.main.async { self.isFollowActionLoading = false; self.isFollowing = true }
                return
            }
            followUser(currentUserId: currentUserId, targetUserId: userId)
        }
    }
    
    private func followUser(currentUserId: String, targetUserId: String) {
        let db = Firestore.firestore()
        let currentUserRef = db.collection("users").document(currentUserId)
        let targetUserRef = db.collection("users").document(targetUserId)
        
        // Step 1: Update current user's following (authoritative success condition)
        currentUserRef.updateData(["following": FieldValue.arrayUnion([targetUserId])]) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.isFollowActionLoading = false
                    self.errorMessage = "Failed to follow user: \(error.localizedDescription)"
                }
                return
            }
            // Optimistically mark as following
            DispatchQueue.main.async { self.isFollowing = true }
            
            // Step 2 (best-effort): Update target user's followers
            targetUserRef.updateData(["followers": FieldValue.arrayUnion([currentUserId])]) { _ in
                // Ignore permission errors here; UI state is based on step 1
                DispatchQueue.main.async {
                    self.isFollowActionLoading = false
                    // If viewing target profile, update local snapshot
                    if let profile = self.profile, profile.uid == targetUserId {
                        var updated = profile
                        var followers = updated.followers ?? []
                        if !followers.contains(currentUserId) { followers.append(currentUserId) }
                        updated = UserProfile(
                            uid: updated.uid,
                            email: updated.email,
                            username: updated.username,
                            displayName: updated.displayName,
                            createdAt: updated.createdAt,
                            profilePictureUrl: updated.profilePictureUrl,
                            profileHeaderUrl: updated.profileHeaderUrl,
                            bio: updated.bio,
                            followers: followers,
                            following: updated.following,
                            isVerified: updated.isVerified,
                            roles: updated.roles,
                            reportCount: updated.reportCount,
                            violationCount: updated.violationCount,
                            locationSharingWith: updated.locationSharingWith,
                            showNowPlaying: updated.showNowPlaying,
                            nowPlayingSong: updated.nowPlayingSong,
                            nowPlayingArtist: updated.nowPlayingArtist,
                            nowPlayingAlbumArt: updated.nowPlayingAlbumArt,
                            nowPlayingUpdatedAt: updated.nowPlayingUpdatedAt,
                            pinnedSongs: updated.pinnedSongs,
                            pinnedArtists: updated.pinnedArtists,
                            pinnedAlbums: updated.pinnedAlbums,
                            pinnedLists: updated.pinnedLists,
                            pinnedSongsRanked: updated.pinnedSongsRanked,
                            pinnedArtistsRanked: updated.pinnedArtistsRanked,
                            pinnedAlbumsRanked: updated.pinnedAlbumsRanked,
                            pinnedListsRanked: updated.pinnedListsRanked
                        )
                        self.profile = updated
                    }
                }
            }
        }
    }
    
    private func unfollowUser(currentUserId: String, targetUserId: String) {
        let db = Firestore.firestore()
        let currentUserRef = db.collection("users").document(currentUserId)
        let targetUserRef = db.collection("users").document(targetUserId)
        
        // Step 1: Update current user's following
        currentUserRef.updateData(["following": FieldValue.arrayRemove([targetUserId])]) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.isFollowActionLoading = false
                    self.errorMessage = "Failed to unfollow user: \(error.localizedDescription)"
                }
                return
            }
            // Optimistically mark as not following
            DispatchQueue.main.async { self.isFollowing = false }
            
            // Step 2 (best-effort): Update target user's followers
            targetUserRef.updateData(["followers": FieldValue.arrayRemove([currentUserId])]) { _ in
                DispatchQueue.main.async {
                    self.isFollowActionLoading = false
                    if let profile = self.profile, profile.uid == targetUserId {
                        var updated = profile
                        var followers = updated.followers ?? []
                        followers.removeAll { $0 == currentUserId }
                        updated = UserProfile(
                            uid: updated.uid,
                            email: updated.email,
                            username: updated.username,
                            displayName: updated.displayName,
                            createdAt: updated.createdAt,
                            profilePictureUrl: updated.profilePictureUrl,
                            profileHeaderUrl: updated.profileHeaderUrl,
                            bio: updated.bio,
                            followers: followers,
                            following: updated.following,
                            isVerified: updated.isVerified,
                            roles: updated.roles,
                            reportCount: updated.reportCount,
                            violationCount: updated.violationCount,
                            locationSharingWith: updated.locationSharingWith,
                            showNowPlaying: updated.showNowPlaying,
                            nowPlayingSong: updated.nowPlayingSong,
                            nowPlayingArtist: updated.nowPlayingArtist,
                            nowPlayingAlbumArt: updated.nowPlayingAlbumArt,
                            nowPlayingUpdatedAt: updated.nowPlayingUpdatedAt,
                            pinnedSongs: updated.pinnedSongs,
                            pinnedArtists: updated.pinnedArtists,
                            pinnedAlbums: updated.pinnedAlbums,
                            pinnedLists: updated.pinnedLists,
                            pinnedSongsRanked: updated.pinnedSongsRanked,
                            pinnedArtistsRanked: updated.pinnedArtistsRanked,
                            pinnedAlbumsRanked: updated.pinnedAlbumsRanked,
                            pinnedListsRanked: updated.pinnedListsRanked
                        )
                        self.profile = updated
                    }
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