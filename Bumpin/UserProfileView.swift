import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MusicKit
import FirebaseStorage
import Charts

// Fixed spacing constants
private let sectionGap: CGFloat = 32 // Space between sections
private let sectionPadding: CGFloat = 16 // Horizontal padding
private let sectionSpacing: CGFloat = 12 // Internal spacing


enum PinnedType { case song, artist, album }

// Genre detail navigation item
struct GenreDetailItem: Identifiable {
    let id: String
    let genre: String
    
    init(genre: String) {
        self.genre = genre
        self.id = genre.lowercased()
    }
}

// Add StatCategory at the top level

enum StatCategory: Identifiable {
    case songs, artists, albums, reposts, lists, logs
    var id: String {
        switch self {
        case .songs: return "songs"
        case .artists: return "artists"
        case .albums: return "albums"
        case .reposts: return "reposts"
        case .lists: return "lists"
        case .logs: return "logs"
        }
    }
    var title: String {
        switch self {
        case .songs: return "Rated Songs"
        case .artists: return "Rated Artists"
        case .albums: return "Rated Albums"
        case .reposts: return "Reposts"
        case .lists: return "Lists"
        case .logs: return "Logs"
        }
    }
}

// MARK: - LazyView Wrapper for Memory Safety
struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

struct UserProfileView: View {
    let userId: String?
    let showFullProfile: Bool // If false, only show overview even for current user
    let prefetchedProfile: UserProfile? // Optional pre-fetched profile to prevent crashes
    let showDismissButton: Bool // If true, show dismiss button even for current user (e.g., when opened from search)
    
    init(userId: String?, showFullProfile: Bool = true, prefetchedProfile: UserProfile? = nil, showDismissButton: Bool = false) {
        self.userId = userId
        self.showFullProfile = showFullProfile
        self.prefetchedProfile = prefetchedProfile
        self.showDismissButton = showDismissButton
    }
    
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile?
    @State private var logs: [MusicLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLog: MusicLog?
    @State private var selectedTab: ProfileTab = .overview
    @State private var logToEdit: MusicLog?
    @State private var showingLogMusicView = false
    @State private var userLists: [MusicList] = []
    @State private var isLoadingLists = false
    @State private var showCreateListSheet = false
    @State private var listCoverImages: [String: URL] = [:]
    @State private var selectedList: MusicList?
    @State private var showEditListSheet = false
    @State private var listToEdit: MusicList?
    @State private var pendingEditList: MusicList? = nil
    @State private var showEditProfile = false
    @State private var showEditPinnedSongs = false
    @State private var showEditPinnedArtists = false
    @State private var showReorderPinnedSongs = false
    @State private var showReorderPinnedArtists = false
    @State private var showReorderPinnedAlbums = false
    @State private var showEditPinnedAlbums = false
    @State private var showHeaderPicker = false
    @State private var headerImage: UIImage? = nil
    // Navigation targets
    @State private var showDiaryLogDetail: Bool = false
    @State private var selectedDiaryLogDetail: MusicLog? = nil
    @State private var selectedStatCategory: StatCategory? = nil
    @State private var listenLaterList: MusicList? = nil
    @State private var isLoadingListenLater = false
    @State private var listenLaterError: String? = nil
    @State private var showAddToListenLater = false
    @State private var selectedListenLaterTab = 0
    @State private var selectedConversation: Conversation? = nil
    @State private var showingSettings = false
    @State private var showBlockedUsers = false
    @State private var showReportsAdmin = false
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    // Followers/Following list navigation
    @State private var showFollowersList = false
    @State private var showFollowingList = false
    // Alert for follow/unfollow errors
    @State private var showAlert = false
    @State private var alertMessage = ""
    // Music profile navigation
    @State private var selectedMusicItem: MusicSearchResult? = nil
    @State private var selectedPinnedLog: MusicLog? = nil
    // Artist profile navigation
    @State private var selectedArtistName: String? = nil
    @State private var showArtistProfile = false
    // Diary view toggles
    @State private var diaryViewFormat: DiaryViewFormat = .list
    @State private var diarySortOption: DiarySortOption = .mostRecent
    
    // Ranking toggle states for pinned sections
    @State private var showRankingForSongs = true
    @State private var showRankingForArtists = true
    @State private var showRankingForAlbums = true
    @State private var selectedRatingBucket: RatingDistributionData?
    @StateObject private var blockingService = BlockingService.shared
    
    // Verified block status (async check against authoritative source)
    @State private var verifiedBlockedByUser: Bool? = nil
    @State private var isVerifyingBlockStatus: Bool = false
    
    // Listen Later section state
    @State private var selectedListenLaterSection: ListenLaterItemType = .song
    @State private var showAddToListenLaterSheet = false
    @ObservedObject private var listenLaterService = ListenLaterService.shared
    
    // Log edit/delete state
    @State private var showDeleteConfirmation = false
    @State private var logToDelete: MusicLog? = nil
    // Phase 3: Genre correction state
    @State private var showGenreCorrection = false
    @State private var logToCorrectGenre: MusicLog? = nil
    // Genre detail navigation
    @State private var selectedGenreForDetail: String? = nil
    // Cache genre data to prevent pie chart spinning
    @State private var cachedGenreData: [GenreData] = []
    @State private var lastLogCount: Int = 0
    @State private var genreLogsByName: [String: [MusicLog]] = [:]
    
    // Reposts state
    @State private var userReposts: [Repost] = []
    @State private var repostedLogs: [MusicLog] = [] // The actual logs that were reposted
    @State private var isLoadingReposts = false

    // Removed duplicate View extension that caused invalid redeclaration at file scope.
    
    @StateObject var viewModel: UserProfileViewModel = UserProfileViewModel()
    @EnvironmentObject var nowPlayingManager: NowPlayingManager
    @EnvironmentObject var adminState: AdminState
    @Namespace private var pinnedBadgeNS
    
    enum ProfileTab: String, CaseIterable, Identifiable {
        case overview = "Profile"
        case diary = "Logs"
        case lists = "Playlists"
        case listenLater = "Listen Later"
        var id: String { rawValue }
    }
    
    enum DiaryViewFormat: String, CaseIterable {
        case list = "List"
        case grid = "Grid"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "grid"
            }
        }
    }
    
    enum DiarySortOption: String, CaseIterable {
        case mostRecent = "Most Recent"
        case mostPopular = "Most Popular"
        case oldest = "Oldest"
        case alphabetical = "Alphabetical"
        case highestRated = "Highest Rated"
        
        var icon: String {
            switch self {
            case .mostRecent: return "clock"
            case .mostPopular: return "heart.fill"
            case .oldest: return "clock.arrow.circlepath"
            case .alphabetical: return "textformat.abc"
            case .highestRated: return "star.fill"
            }
        }
    }
    
    var isCurrentUser: Bool {
        guard let userId = userId else { return true }
        return userId == Auth.auth().currentUser?.uid
    }
    
    // MARK: - Log Management Functions
    
    private func deleteLog(_ log: MusicLog) {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              log.userId == currentUserId else {
            print("❌ Cannot delete log: Not authorized")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("logs").document(log.id).delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error deleting log: \(error.localizedDescription)")
                    // You could show an error alert here
                } else {
                    print("✅ Successfully deleted log")
                    // Refresh the logs list
                    self.fetchProfileAndLogs()
                    
                    // Show success feedback
                    withAnimation {
                        // Optional: Add a toast or success indicator
                    }
                }
            }
        }
    }
    
    // MARK: - Pinned Items Update Functions
    
    private func updatePinnedSongs(_ updatedItems: [PinnedItem]) {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "pinnedSongs": updatedItems.map { item in
                [
                    "id": item.id,
                    "title": item.title,
                    "artistName": item.artistName,
                    "albumName": item.albumName ?? "",
                    "artworkURL": item.artworkURL ?? "",
                    "itemType": item.itemType,
                    "dateAdded": item.dateAdded
                ]
            }
        ]) { error in
            if let error = error {
                print("❌ Error updating pinned songs: \(error.localizedDescription)")
            } else {
                print("✅ Successfully updated pinned songs")
                DispatchQueue.main.async {
                    self.fetchProfileAndLogs(forceProfileRefresh: true)
                }
            }
        }
    }
    
    private func updatePinnedArtists(_ updatedItems: [PinnedItem]) {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "pinnedArtists": updatedItems.map { item in
                [
                    "id": item.id,
                    "title": item.title,
                    "artistName": item.artistName,
                    "albumName": item.albumName ?? "",
                    "artworkURL": item.artworkURL ?? "",
                    "itemType": item.itemType,
                    "dateAdded": item.dateAdded
                ]
            }
        ]) { error in
            if let error = error {
                print("❌ Error updating pinned artists: \(error.localizedDescription)")
            } else {
                print("✅ Successfully updated pinned artists")
                DispatchQueue.main.async {
                    self.fetchProfileAndLogs(forceProfileRefresh: true)
                }
            }
        }
    }
    
    private func updatePinnedAlbums(_ updatedItems: [PinnedItem]) {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "pinnedAlbums": updatedItems.map { item in
                [
                    "id": item.id,
                    "title": item.title,
                    "artistName": item.artistName,
                    "albumName": item.albumName ?? "",
                    "artworkURL": item.artworkURL ?? "",
                    "itemType": item.itemType,
                    "dateAdded": item.dateAdded
                ]
            }
        ]) { error in
            if let error = error {
                print("❌ Error updating pinned albums: \(error.localizedDescription)")
            } else {
                print("✅ Successfully updated pinned albums")
                DispatchQueue.main.async {
                    self.fetchProfileAndLogs(forceProfileRefresh: true)
                }
            }
        }
    }
    
    // MARK: - Fetch User Reposts
    private func fetchUserReposts() {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else { return }
        
        isLoadingReposts = true
        
        print("🔍 [Reposts] Fetching reposts for user: \(userId)")
        
        Task {
            let db = Firestore.firestore()
            
            do {
                // Use collection group query to find all reposts by this user
                let repostsSnapshot = try await db.collectionGroup("reposts")
                    .whereField("userId", isEqualTo: userId)
                    .getDocuments()
                
                print("🔍 [Reposts] Found \(repostsSnapshot.documents.count) repost documents")
                
                var repostedLogs: [(Repost, MusicLog)] = []
                
                for repostDoc in repostsSnapshot.documents {
                    // Extract the log ID from the document reference path
                    // Path format: logs/{logId}/reposts/{userId}
                    let pathComponents = repostDoc.reference.path.components(separatedBy: "/")
                    guard pathComponents.count >= 2,
                          pathComponents[0] == "logs",
                          let logId = pathComponents.dropFirst().first else {
                        continue
                    }
                    
                    print("🔍 [Reposts] Processing repost for log: \(logId)")
                    
                    // Fetch the log
                    let logDoc = try await db.collection("logs").document(logId).getDocument()
                    
                    guard logDoc.exists,
                          let log = try? logDoc.data(as: MusicLog.self),
                          let timestamp = (repostDoc.data()["timestamp"] as? Timestamp)?.dateValue() else {
                        print("⚠️ [Reposts] Log not found or invalid for: \(logId)")
                        continue
                    }
                    
                    var repost = Repost(logId: log.id, userId: userId)
                    repost.id = repostDoc.documentID
                    repost.createdAt = timestamp
                    
                    repostedLogs.append((repost, log))
                    print("✅ [Reposts] Added repost: \(log.title)")
                }
                
                // Sort by repost date (most recent first)
                repostedLogs.sort { $0.0.createdAt > $1.0.createdAt }
                
                print("✅ [Reposts] Total reposts loaded: \(repostedLogs.count)")
                
                await MainActor.run {
                    self.userReposts = repostedLogs.map { $0.0 }
                    self.repostedLogs = repostedLogs.map { $0.1 }
                    self.isLoadingReposts = false
                }
                
            } catch {
                print("❌ Error fetching reposts: \(error)")
                await MainActor.run {
                    self.isLoadingReposts = false
                }
            }
        }
    }
    
    @MainActor
    private func refreshProfile() async {
        fetchProfileAndLogs(forceProfileRefresh: true)
        fetchUserReposts()
        
        let uid = userId ?? Auth.auth().currentUser?.uid
        if let uid = uid {
            viewModel.loadFollowCounts(for: uid)
        }
        
        if let targetUserId = userId, !isCurrentUser {
            viewModel.checkIfFollowing(userId: targetUserId)
            // Verify block status against authoritative source to handle stale blockedBy data
            verifyBlockStatus(for: targetUserId)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
            if profile == nil && isLoading {
                    loadingView
            } else if let errorMessage = errorMessage {
                    errorView(errorMessage)
                } else if let profile = profile {
                    profileOrBlockedView(for: profile)
                } else {
                    fallbackView
                }
                }
            }
            .refreshable {
                await refreshProfile()
            }
            .onAppear {
            // Move all state modifications to Task to prevent "Modifying state during view update"
            Task { @MainActor in
                // Reset verified block status for fresh check
                verifiedBlockedByUser = nil
                
                // DISABLED: Prefetch was causing EXC_BAD_ACCESS crashes
                // The prefetched profile data appears to be corrupted or incompletely initialized
                // Always fetch fresh from Firestore instead
                // if let prefetchedProfile = prefetchedProfile, profile == nil {
                //     print("✅ Using prefetched profile for user: \(prefetchedProfile.displayName)")
                //     profile = prefetchedProfile
                // }
            
                // Always fetch fresh data
                fetchProfileAndLogs()
                fetchUserReposts()
                
                // Load follower/following counts from subcollections
                let uid = userId ?? Auth.auth().currentUser?.uid
                if let uid = uid {
                    viewModel.loadFollowCounts(for: uid)
                }
                
                // Check follow status if viewing another user's profile
                if let targetUserId = userId, !isCurrentUser {
                    viewModel.checkIfFollowing(userId: targetUserId)
                    // Verify block status against authoritative source to handle stale blockedBy data
                    verifyBlockStatus(for: targetUserId)
                }
                
                // Initialize Listen Later service early
                    listenLaterService.refreshAllSections()
            }
                }
        .fullScreenCover(item: $selectedMusicItem) { musicItem in
            MusicProfileView(musicItem: musicItem, pinnedLog: selectedPinnedLog)
        }
        .fullScreenCover(isPresented: $showArtistProfile) {
            if let artistName = selectedArtistName {
                ArtistProfileView(artistName: artistName)
                    .environmentObject(NavigationCoordinator())
            }
        }
        .sheet(item: Binding<GenreDetailItem?>(
            get: { selectedGenreForDetail.map { GenreDetailItem(genre: $0) } },
            set: { selectedGenreForDetail = $0?.genre }
        )) { item in
            GenreDetailView(
                genre: item.genre,
                userLogs: logsForGenre(item.genre),
                isPrefiltered: true
            )
        }
        .fullScreenCover(item: $selectedStatCategory) { category in
            StatDetailListView(
                category: category,
                logs: logs,
                userLists: userLists,
                listCoverImages: listCoverImages,
                userReposts: userReposts,
                repostedLogs: repostedLogs,
                profile: profile
            )
        }
        .fullScreenCover(item: $selectedRatingBucket) { bucket in
            let bucketLogs = logsForBucket(bucket, in: logs)
            ProfileRatingBucketDetailView(
                bucket: bucket,
                logs: bucketLogs,
                subtitle: "\(bucketLogs.count) \(bucketLogs.count == 1 ? "log" : "logs")",
                isCurrentUser: isCurrentUser,
                onLogTap: { log in
                    navigateToMusicProfile(log: log)
                },
                onEdit: isCurrentUser ? { log in
                    logToEdit = log
                } : nil,
                onDelete: isCurrentUser ? { log in
                    logToDelete = log
                    showDeleteConfirmation = true
                } : nil,
                onCorrectGenre: isCurrentUser ? { log in
                    logToCorrectGenre = log
                    showGenreCorrection = true
                } : nil
            )
        }
        .fullScreenCover(item: $selectedList) { list in
            ListDetailView(
                list: list,
                onEdit: {
                    pendingEditList = list
                    selectedList = nil
                },
                onDelete: {
                    deleteList(list)
                }
            )
        }
        .onChange(of: selectedList) { _, _ in
            if selectedList == nil, let toEdit = pendingEditList {
                listToEdit = toEdit
                showEditListSheet = true
                pendingEditList = nil
            }
        }
        .fullScreenCover(isPresented: $showEditListSheet) {
            if let list = listToEdit {
                EditListView(list: list, onListUpdated: {
                    fetchLists()
                })
            }
        }
        .fullScreenCover(isPresented: $showFollowersList) {
            if let profile = profile {
                FollowersFollowingListView(userId: profile.uid, listType: .followers)
            }
        }
        .fullScreenCover(isPresented: $showFollowingList) {
            if let profile = profile {
                FollowersFollowingListView(userId: profile.uid, listType: .following)
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Delete Log", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                logToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let log = logToDelete {
                    deleteLog(log)
                }
                logToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this log? This action cannot be undone.")
        }
        .sheet(isPresented: $showGenreCorrection, onDismiss: { logToCorrectGenre = nil }) {
            if let log = logToCorrectGenre {
                GenreCorrectionView(log: log) {
                    fetchProfileAndLogs()
                }
            }
        }
        .fullScreenCover(isPresented: $showingLogMusicView, onDismiss: {
            // Refresh diary after logging new music
            fetchProfileAndLogs()
        }) {
            DiaryMainSearchView()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(userProfileVM: viewModel)
                .environmentObject(nowPlayingManager)
        }
        .sheet(isPresented: $showEditPinnedSongs) {
            EditPinnedItemsView(
                title: "Edit Pinned Songs",
                currentItems: profile?.pinnedSongs ?? [],
                itemType: .song,
                onSave: { updatePinnedSongs($0) }
            )
        }
        .sheet(isPresented: $showEditPinnedArtists) {
            EditPinnedItemsView(
                title: "Edit Pinned Artists",
                currentItems: profile?.pinnedArtists ?? [],
                itemType: .artist,
                onSave: { updatePinnedArtists($0) }
            )
        }
        .sheet(isPresented: $showEditPinnedAlbums) {
            EditPinnedItemsView(
                title: "Edit Pinned Albums",
                currentItems: profile?.pinnedAlbums ?? [],
                itemType: .album,
                onSave: { updatePinnedAlbums($0) }
            )
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(adminState)
        }
        .fullScreenCover(item: $selectedConversation, onDismiss: { selectedConversation = nil }) { convo in
            ConversationView(
                conversation: convo,
                onDismiss: { selectedConversation = nil },
                initialDisplayName: profile?.displayName,
                initialProfilePictureUrl: profile?.profilePictureUrl ?? profile?.profileHeaderUrl
            )
        }
        .sheet(isPresented: $showBlockedUsers) {
            NavigationView {
                BlockedUsersView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showBlockedUsers = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showReportsAdmin) {
            AdminReportsView()
        }
        .sheet(isPresented: $showReportSheet) {
            if let targetId = userId, let username = profile?.username {
                ReportContentView(
                    contentId: targetId,
                    contentType: .userBio,
                    reportedUserId: targetId,
                    reportedUsername: username,
                    contentPreview: profile?.bio
                )
            }
        }
        .sheet(isPresented: $showBlockSheet) {
            if let targetId = userId, let username = profile?.username {
                BlockUserView(
                    userId: targetId,
                    username: username,
                    profilePictureUrl: profile?.profilePictureUrl
                )
            }
        }
        .fullScreenCover(isPresented: $showAddToListenLaterSheet) {
            ComprehensiveSearchView(
                listenLaterSelectionMode: true,
                onListenLaterItemsSelected: { items in
                    Task {
                        for item in items {
                            let type: ListenLaterItemType
                            switch item.itemType {
                            case "song": type = .song
                            case "album": type = .album
                            case "artist": type = .artist
                            default: continue
                            }
                            _ = await ListenLaterService.shared.addItem(item, type: type)
                        }
                        await MainActor.run {
                            listenLaterService.refreshAllSections()
                        }
                    }
                }
            )
        }
    }
    
    // MARK: - Profile Content View (Main Content)
    private var profileContentView: some View {
        VStack(spacing: 0) {
            // Show tabs only for current user AND when showing full profile
            if isCurrentUser && showFullProfile {
                        // Custom tabs matching Social Feed design - moved to top, tightened spacing
                    HStack(spacing: 0) {
                        ForEach(ProfileTab.allCases) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }) {
                                    VStack(spacing: 2) {
                                    Text(tab.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(selectedTab == tab ? .bold : .regular)
                                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                                            .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                    
                                    // Bottom indicator line
                                    if selectedTab == tab {
                                        Rectangle()
                                            .fill(Color.purple)
                                            .frame(height: 3)
                                    } else {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(height: 3)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .background(selectedTab == tab ? Color.purple.opacity(0.12) : Color.clear)
                        }
                    }
                    .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                    
                    // Tab Content - Lazy loaded to prevent memory crashes
                    ZStack {
                        if selectedTab == .overview {
                            LazyView(overviewTab)
                                .transition(.opacity)
                        } else if selectedTab == .diary {
                            LazyView(diaryTab)
                                .transition(.opacity)
                        } else if selectedTab == .lists {
                            LazyView(listsTab)
                                .transition(.opacity)
                        } else if selectedTab == .listenLater {
                            LazyView(listenLaterTab)
                                .transition(.opacity)
                        }
                    }
                } else {
                    // Only show overview for other users OR when not showing full profile
                    overviewTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                // Show close button for non-current users, or anytime we're in a compact/embedded profile experience
                if !isCurrentUser || showDismissButton || !showFullProfile {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 32, height: 32)
                            )
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
            }
    }
    
    // MARK: - Diary Tab Content

    private struct DiaryLogCard: View {
        let log: MusicLog
        let onTap: () -> Void
        let onEdit: (() -> Void)?
        let onDelete: (() -> Void)?
        let onCorrectGenre: (() -> Void)?
        let isCurrentUser: Bool
        @State private var userProfile: UserProfile? = nil
        @State private var showingComments = false
        @State private var isPressed = false
        
        // Engagement state
        @State private var isLiked: Bool = false
        @State private var likeCount: Int = 0
        @State private var hasThumbsDown: Bool = false
        @State private var hasReposted: Bool = false
        @State private var repostCount: Int = 0
        @State private var showActivity = false
        
        // Artist artwork fallback
        @State private var fetchedArtworkURL: String? = nil
        @State private var hasAttemptedFetch = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    // Album/Artist artwork
                    Group {
                        let artworkURL = fetchedArtworkURL ?? log.artworkUrl
                        if let artwork = artworkURL, let url = URL(string: artwork) {
                            CachedAsyncImage(url: url) { image in 
                                image.resizable().scaledToFill() 
                            } placeholder: { 
                                Color.gray.opacity(0.3) 
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: log.itemType == "artist" ? "person.wave.2" : "music.note")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .frame(width: 64, height: 64)
                    .cornerRadius(log.itemType == "artist" ? 32 : 10)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Title and artist
                        Text(log.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        if !log.artistName.isEmpty {
                            Text(log.artistName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Username and rating
                        HStack(spacing: 8) {
                            if let urlString = userProfile?.profilePictureUrl, let url = URL(string: urlString) {
                                CachedAsyncImage(url: url) { image in 
                                    image.resizable().scaledToFill() 
                                } placeholder: { 
                                    Color.gray.opacity(0.3) 
                                }
                                .frame(width: 18, height: 18)
                                .clipShape(Circle())
                            } else {
                                Circle().fill(Color.gray.opacity(0.3)).frame(width: 18, height: 18)
                            }
                            
                            Text("@\(userProfile?.username ?? "user")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if let rating = log.rating {
                                StarRatingDisplayView(
                                    rating: rating,
                                    starSize: 10,
                                    spacing: 1
                                )
                            }
                            
                            if log.isPublic == false {
                                HStack(spacing: 4) { 
                                    Image(systemName: "lock.fill").font(.caption2)
                                    Text("Private").font(.caption2) 
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .overlay(alignment: .topTrailing) {
                    Text(RelativeTimeFormatter.shared.string(for: log.dateLogged))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                
                // Review text
                if let review = log.review, !review.isEmpty {
                    InteractiveMentionText(
                        review,
                        font: .caption,
                        color: .primary,
                        mentionColor: .purple
                    )
                    .lineLimit(3)
                    .padding(.horizontal, 2)
                }
                
                // Engagement bar
                HStack(spacing: 16) {
                    // Like button
                    Button(action: { 
                        if isLiked {
                            LogEngagementHaptics.unlike()
                        } else {
                            LogEngagementHaptics.like()
                        }
                        toggleLike() 
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                            Text("\(likeCount)")
                        }
                    }
                    .foregroundColor(isLiked ? .red : .secondary)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Comment button
                    Button(action: { 
                        LogEngagementHaptics.comment()
                        showingComments = true 
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                            Text("\(log.commentCount ?? 0)")
                        }
                    }
                    .foregroundColor(.secondary)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Thumbs down button
                    Button(action: { 
                        LogEngagementHaptics.thumbsDown()
                        toggleThumbsDown() 
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: hasThumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            if hasThumbsDown {
                                Text("1")
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Repost button
                    Button(action: { 
                        if hasReposted {
                            LogEngagementHaptics.unrepost()
                        } else {
                            LogEngagementHaptics.repost()
                        }
                        handleRepost() 
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.2.squarepath")
                                .foregroundColor(hasReposted ? .green : .secondary)
                            if repostCount > 0 {
                                Text("\(repostCount)")
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // View Activity button
                    Button(action: { 
                        LogEngagementHaptics.viewActivity()
                        showActivity = true 
                    }) {
                        Text("View Activity")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .font(.caption)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .onTapGesture {
                onTap()
            }
            .contextMenu {
                if isCurrentUser {
                    Button(action: {
                        onEdit?()
                    }) {
                        Label("Edit Log", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        onCorrectGenre?()
                    }) {
                        Label("Correct Genre", systemImage: "music.note.list")
                    }
                    
                    Button(role: .destructive, action: {
                        onDelete?()
                    }) {
                        Label("Delete Log", systemImage: "trash")
                    }
                }
            }
            .onAppear {
                if userProfile == nil {
                    Task { await fetchUser() }
                }
                loadEngagement()
                
                // Fetch artist artwork if missing
                if log.itemType == "artist" && log.artworkUrl == nil && !hasAttemptedFetch {
                    hasAttemptedFetch = true
                    Task {
                        await fetchArtistArtwork()
                    }
                }
            }
            .fullScreenCover(isPresented: $showingComments) {
                UnifiedLogCommentsView(log: log)
            }
            .fullScreenCover(isPresented: $showActivity) {
                LogActivityView(logId: log.id, log: log)
            }
        }
        
        private func fetchUser() async {
            do {
                let snap = try await Firestore.firestore().collection("users").document(log.userId).getDocument()
                if let profile = try? snap.data(as: UserProfile.self) {
                    await MainActor.run { self.userProfile = profile }
                }
            } catch { }
        }
        
        private func loadEngagement() {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            likeCount = log.likeCount ?? 0
            repostCount = log.repostCount ?? 0
            
            Task {
                let engagement = await LogEngagementCache.shared.getEngagement(logId: log.id, userId: currentUserId)
                await MainActor.run {
                    isLiked = engagement.isLiked
                    hasThumbsDown = engagement.hasThumbsDown
                    hasReposted = engagement.hasReposted
                }
            }
        }
        
        private func fetchArtistArtwork() async {
            guard log.itemType == "artist" else { return }
            
            do {
                // Search for the artist using MusicKit
                var request = MusicCatalogSearchRequest(term: log.artistName, types: [MusicKit.Artist.self])
                request.limit = 5
                
                let response = try await request.response()
                
                // Find the best matching artist
                let artist = response.artists.first { artist in
                    artist.name.lowercased() == log.artistName.lowercased()
                } ?? response.artists.first
                
                if let artist = artist, let artworkURL = artist.artwork?.url(width: 512, height: 512)?.absoluteString {
                    await MainActor.run {
                        fetchedArtworkURL = artworkURL
                    }
                    print("✅ Fetched artist artwork for log card: \(log.artistName)")
                } else {
                    print("⚠️ No artwork found for artist in log card: \(log.artistName)")
                }
            } catch {
                print("❌ Error fetching artist artwork for log card: \(error.localizedDescription)")
            }
        }
        
        private func toggleLike() {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            Task {
                let db = Firestore.firestore()
                let likeRef = db.collection("logs").document(log.id).collection("likes").document(currentUserId)
                
                do {
                    if isLiked {
                        try await likeRef.delete()
                        try await db.collection("logs").document(log.id).updateData([
                            "likeCount": FieldValue.increment(Int64(-1))
                        ])
                        
                        await MainActor.run {
                            isLiked = false
                            likeCount -= 1
                            LogEngagementCache.shared.updateEngagement(logId: log.id, isLiked: false)
                        }
                    } else {
                        try await likeRef.setData([
                            "userId": currentUserId,
                            "timestamp": FieldValue.serverTimestamp()
                        ])
                        try await db.collection("logs").document(log.id).updateData([
                            "likeCount": FieldValue.increment(Int64(1))
                        ])
                        
                        // Create like notification
                        await NotificationService.shared.createLikeNotification(
                            logId: log.id,
                            logOwnerId: log.userId,
                            log: log
                        )
                        
                        await MainActor.run {
                            isLiked = true
                            likeCount += 1
                            LogEngagementCache.shared.updateEngagement(logId: log.id, isLiked: true)
                        }
                    }
                } catch {
                    print("❌ Error toggling like: \(error)")
                }
            }
        }
        
        private func toggleThumbsDown() {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            Task {
                let db = Firestore.firestore()
                let thumbsDownRef = db.collection("logs").document(log.id).collection("thumbsDown").document(currentUserId)
                
                do {
                    if hasThumbsDown {
                        try await thumbsDownRef.delete()
                        
                        // ✅ Decrement the thumbs down count
                        try await db.collection("logs").document(log.id).updateData([
                            "thumbsDownCount": FieldValue.increment(Int64(-1))
                        ])
                        
                        await MainActor.run {
                            hasThumbsDown = false
                            LogEngagementCache.shared.updateEngagement(logId: log.id, hasThumbsDown: false)
                        }
                    } else {
                        try await thumbsDownRef.setData([
                            "userId": currentUserId,
                            "timestamp": FieldValue.serverTimestamp()
                        ])
                        
                        // ✅ Increment the thumbs down count
                        try await db.collection("logs").document(log.id).updateData([
                            "thumbsDownCount": FieldValue.increment(Int64(1))
                        ])
                        
                        // Create dislike notification
                        await NotificationService.shared.createDislikeNotification(
                            logId: log.id,
                            logOwnerId: log.userId,
                            log: log
                        )
                        
                        await MainActor.run {
                            hasThumbsDown = true
                            LogEngagementCache.shared.updateEngagement(logId: log.id, hasThumbsDown: true)
                        }
                    }
                } catch {
                    print("❌ Error toggling thumbs down: \(error)")
                }
            }
        }
        
        private func handleRepost() {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }
            
            Task {
                let db = Firestore.firestore()
                let repostRef = db.collection("logs").document(log.id).collection("reposts").document(currentUserId)
                
                do {
                    if hasReposted {
                        try await repostRef.delete()
                        try await db.collection("logs").document(log.id).updateData([
                            "repostCount": FieldValue.increment(Int64(-1))
                        ])
                        
                        await MainActor.run {
                            hasReposted = false
                            repostCount = max(0, repostCount - 1)
                            LogEngagementCache.shared.updateEngagement(logId: log.id, hasReposted: false)
                        }
                    } else {
                        try await repostRef.setData([
                            "userId": currentUserId,
                            "timestamp": FieldValue.serverTimestamp()
                        ])
                        try await db.collection("logs").document(log.id).updateData([
                            "repostCount": FieldValue.increment(Int64(1))
                        ])
                        
                        // Create repost notification
                        await NotificationService.shared.createRepostNotification(
                            logId: log.id,
                            logOwnerId: log.userId,
                            log: log
                        )
                        
                        await MainActor.run {
                            hasReposted = true
                            repostCount += 1
                            LogEngagementCache.shared.updateEngagement(logId: log.id, hasReposted: true)
                        }
                    }
                } catch {
                    print("❌ Error toggling repost: \(error)")
                }
            }
        }
    }
    
    private struct DiaryToggleControls: View {
        @Binding var viewFormat: DiaryViewFormat
        @Binding var sortOption: DiarySortOption
        
        var body: some View {
            // Centered row with all controls
            HStack {
                Spacer()
                
                HStack(spacing: 16) {
                    // Combined List/Grid Toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewFormat = viewFormat == .list ? .grid : .list
                        }
                    }) {
                        Image(systemName: viewFormat.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Sort Menu
                Menu {
                        ForEach(DiarySortOption.allCases, id: \.self) { option in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    sortOption = option
                                }
                            }) {
                                HStack {
                                    Image(systemName: option.icon)
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                    }
                } label: {
                    HStack(spacing: 6) {
                            Image(systemName: sortOption.icon)
                                .font(.system(size: 14))
                            Text(sortOption.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                        .foregroundColor(.primary)
                    }
                    
                }
                
                Spacer()
            }


            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    

    
    private struct ListCard: View {
        let list: MusicList
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        if let url = list.coverImageUrl.flatMap(URL.init(string:)) {
                            CachedAsyncImage(url: url) { image in 
                                image.resizable().scaledToFill() 
                            } placeholder: { 
                                Color(.systemGray6) 
                            }
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                        } else if !list.items.isEmpty {
                            // Try to show artwork from first item if no cover image
                            if let decoded = decodeListItem(from: list.items[0]),
                               let artworkUrl = decoded.artworkURL,
                               let url = URL(string: artworkUrl) {
                                CachedAsyncImage(url: url) { image in 
                                    image.resizable().scaledToFill() 
                                } placeholder: { 
                                    Color(.systemGray6) 
                                }
                                .frame(width: 64, height: 64)
                                .cornerRadius(12)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 28))
                                            .foregroundColor(.purple)
                                    )
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 28))
                                        .foregroundColor(.purple)
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(list.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        if let desc = list.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 8) {
                            Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            LikeButton(
                                itemId: list.id,
                                itemType: .list,
                                itemTitle: list.title,
                                itemArtist: nil,
                                itemArtworkUrl: list.coverImageUrl,
                                showCount: true
                            )
                        }
                    }
                }
                
                // Preview thumbnails
                if !list.items.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                            let previewItems = Array(list.items.prefix(6))
                            ForEach(previewItems, id: \.self) { rawItem in
                                if let decoded = decodeListItem(from: rawItem),
                                   let artworkUrl = decoded.artworkURL,
                               let url = URL(string: artworkUrl) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                        Color(.systemGray6)
                                }
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(8)
                            } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                        .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "music.note")
                                                .font(.system(size: 18))
                                            .foregroundColor(.purple)
                                    )
                            }
                        }
                        }
                        .padding(.trailing, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        
        private func decodeListItem(from raw: String) -> MusicSearchResult? {
            guard let data = raw.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(MusicSearchResult.self, from: data)
        }
    }

    private struct DiaryGridCard: View {
        let log: MusicLog
        let onTap: () -> Void
        let onEdit: (() -> Void)?
        let onDelete: (() -> Void)?
        let onCorrectGenre: (() -> Void)?
        let isCurrentUser: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                // Album artwork
                Group {
                    if let artwork = log.artworkUrl, let url = URL(string: artwork) {
                        CachedAsyncImage(url: url) { image in 
                            image.resizable().scaledToFill() 
                        } placeholder: { 
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray4))
                                .overlay(
                                    Image(systemName: "music.note")
            .font(.caption)
                                        .foregroundColor(.white)
                                )
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray4))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Title
                    Text(log.title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    // Artist
                    if !log.artistName.isEmpty {
                        Text(log.artistName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Rating stars
                    if let rating = log.rating {
                        StarRatingDisplayView(rating: rating, starSize: 8, spacing: 1, showNumber: true)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            .contextMenu {
                if isCurrentUser {
                    Button(action: {
                        onEdit?()
                    }) {
                        Label("Edit Log", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        onCorrectGenre?()
                    }) {
                        Label("Correct Genre", systemImage: "music.note.list")
                    }
                    
                    Button(role: .destructive, action: {
                        onDelete?()
                    }) {
                        Label("Delete Log", systemImage: "trash")
                    }
                }
            }
        }
    }

    // Rank badge for pinned items
    private func rankBadge(_ rank: Int) -> some View {
        Text("\(rank)")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.85))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .padding(4)
    }
    
    private func updatePinnedItems(type: PinnedType, newPinned: [PinnedItem]) {
        // Try to get UID from profile first, then fall back to current user
        let uid = profile?.uid ?? Auth.auth().currentUser?.uid
        guard let uid = uid else { 
            print("❌ No profile UID or current user UID available for updating pinned items")
            return 
        }
        
        print("🎵 PINNED_ITEMS: Updating pinned \(type) items for user \(uid)")
        print("🎵 PINNED_ITEMS: Items to save: \(newPinned.map { $0.name })")
        
        let db = Firestore.firestore()
        let field: String = {
            switch type {
            case .song: return "pinnedSongs"
            case .artist: return "pinnedArtists"
            case .album: return "pinnedAlbums" // reused for lists via separate call below if needed
            }
        }()
        let array = newPinned.map { [
            "id": $0.id,
            "name": $0.name,
            "artworkUrl": $0.artworkUrl as Any
        ]}
        
        print("🎵 PINNED_ITEMS: Saving to Firestore field '\(field)': \(array)")
        
        // Use setData with merge: true to ensure the document and field exist
        db.collection("users").document(uid).setData([
            field: array
        ], merge: true) { err in
            DispatchQueue.main.async {
                if let err = err {
                    print("🎵 PINNED_ITEMS: ❌ Failed to update pinned items: \(err.localizedDescription)")
                } else {
                    print("🎵 PINNED_ITEMS: ✅ Successfully updated pinned items")
                    self.fetchProfileAndLogs()
                }
            }
        }
    }
    
    private var diaryTab: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                diaryTabContent
                
                // Floating Action Button
                if isCurrentUser && !isLoading {
                    Button(action: { showingLogMusicView = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.purple).shadow(radius: 4))
                    }
                    .padding([.trailing, .bottom], 24)
                    .accessibilityLabel("Log new music")
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    // Separate computed property to reduce complexity and prevent memory issues
    private var diaryTabContent: some View {
        VStack(spacing: 0) {
            // Toggle Controls
            if !logs.isEmpty {
                DiaryToggleControls(
                    viewFormat: $diaryViewFormat,
                    sortOption: $diarySortOption
                )
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            
            if isLoading {
                ProgressView().padding()
            } else if let error = errorMessage {
                Text(error).foregroundColor(.red).padding()
            } else if logs.isEmpty {
                emptyDiaryState
            } else {
                diaryScrollContent
            }
        }
    }
    
    // Empty state view
    private var emptyDiaryState: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundColor(.purple)
            }
            
            // Text content
            VStack(spacing: 8) {
                Text("No music logs yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(isCurrentUser ? "Start logging the music you listen to\nand share your thoughts with friends" : "This user hasn't logged any music yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            // CTA Button
            if isCurrentUser {
                Button(action: {
                    showingLogMusicView = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Log Your First Song")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.purple)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // Scroll content view
    private var diaryScrollContent: some View {
        ScrollView {
            if diaryViewFormat == .list {
                diaryListView
            } else {
                diaryGridView
            }
        }
        .refreshable { 
            fetchProfileAndLogs()
        }
    }
    
    // List view
    private var diaryListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(sortedAndFilteredLogs) { log in
                DiaryLogCard(
                    log: log,
                    onTap: { navigateToMusicProfile(log: log) },
                    onEdit: isCurrentUser ? { logToEdit = log } : nil,
                    onDelete: isCurrentUser ? {
                        logToDelete = log
                        showDeleteConfirmation = true
                    } : nil,
                    onCorrectGenre: isCurrentUser ? {
                        logToCorrectGenre = log
                        showGenreCorrection = true
                    } : nil,
                    isCurrentUser: isCurrentUser
                )
            }
        }
        .padding(.horizontal)
    }
    
    // Grid view
    private var diaryGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
            ForEach(sortedAndFilteredLogs) { log in
                DiaryGridCard(
                    log: log,
                    onTap: { navigateToMusicProfile(log: log) },
                    onEdit: isCurrentUser ? { logToEdit = log } : nil,
                    onDelete: isCurrentUser ? {
                        logToDelete = log
                        showDeleteConfirmation = true
                    } : nil,
                    onCorrectGenre: isCurrentUser ? {
                        logToCorrectGenre = log
                        showGenreCorrection = true
                    } : nil,
                    isCurrentUser: isCurrentUser
                )
            }
        }
        .padding(.horizontal)
    }
    

    // Sorted and filtered logs
    // Sorted logs (genre filtering removed)
    private var sortedAndFilteredLogs: [MusicLog] {
        // Safety guard: don't process logs while loading to prevent race conditions
        guard !isLoading else { return [] }
        
        // Remove duplicates based on ID first
        let uniqueLogs = Dictionary(grouping: logs, by: { $0.id })
            .compactMap { $0.value.first }
        
        // Then sort
        return uniqueLogs.sorted { log1, log2 in
            switch diarySortOption {
            case .mostRecent:
                return log1.dateLogged > log2.dateLogged
            case .oldest:
                return log1.dateLogged < log2.dateLogged
            case .alphabetical:
                return log1.title.localizedCaseInsensitiveCompare(log2.title) == .orderedAscending
            case .highestRated:
                let rating1 = log1.rating ?? 0
                let rating2 = log2.rating ?? 0
                if rating1 == rating2 {
                    return log1.dateLogged > log2.dateLogged // Secondary sort by date
                }
                return rating1 > rating2
            case .mostPopular:
                // Calculate weighted engagement score: likes×1 + comments×2 + reposts×3
                let engagement1 = (log1.likeCount ?? 0) + ((log1.commentCount ?? 0) * 2) + ((log1.repostCount ?? 0) * 3)
                let engagement2 = (log2.likeCount ?? 0) + ((log2.commentCount ?? 0) * 2) + ((log2.repostCount ?? 0) * 3)
                if engagement1 == engagement2 {
                    return log1.dateLogged > log2.dateLogged // Tie-breaker: most recent
                }
                return engagement1 > engagement2
            }
        }
    }
    
    // Helper functions
    private func navigateToMusicProfile(log: MusicLog) {
        let result = MusicSearchResult(
            id: log.itemId,
            title: log.title,
            artistName: log.artistName,
            albumName: "",
            artworkURL: log.artworkUrl,
            itemType: log.itemType,
            popularity: 0
        )
        selectedPinnedLog = log
        selectedMusicItem = result
    }
    

    


    private func exportCSV() {
        let header = "date,title,artist,rating,public\n"
        let rows = logs.map { log in
            let date = ISO8601DateFormatter().string(from: log.dateLogged)
            let rating = String(log.rating ?? 0)
            let pub = (log.isPublic ?? true) ? "true" : "false"
            let safeTitle = log.title.replacingOccurrences(of: ",", with: " ")
            let safeArtist = log.artistName.replacingOccurrences(of: ",", with: " ")
            return "\(date),\(safeTitle),\(safeArtist),\(rating),\(pub)"
        }.joined(separator: "\n")
        let csv = header + rows
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("diary.csv")
        try? csv.data(using: .utf8)?.write(to: tmp)
        let av = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true)
    }

    private var listsTab: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading) {
                if isLoadingLists {
                    ProgressView().padding()
                } else if userLists.isEmpty {
                    VStack(spacing: 20) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "music.note.list")
                                .font(.system(size: 48))
                                .foregroundColor(.purple)
                        }
                        
                        // Text content
                        VStack(spacing: 8) {
                            Text("No lists yet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(isCurrentUser ? "Create curated playlists and collections\nof your favorite music" : "This user hasn't created any lists yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        
                        // CTA Button
                        if isCurrentUser {
                            Button(action: {
                                showCreateListSheet = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Create Your First List")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(Color.purple)
                                )
                                .foregroundColor(.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(userLists) { list in
                                ListCard(list: list)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        print("🎵 List card tapped: \(list.title) (id: \(list.id))")
                                        selectedList = list
                                        print("🎵 selectedList set to: \(list.title)")
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onAppear {
                        print("🎵 Lists tab appeared with \(userLists.count) lists")
                    }
                }
            }
            // Floating Action Button
            if isCurrentUser && !isLoadingLists {
                Button(action: { showCreateListSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.purple).shadow(radius: 4))
                }
                .padding([.trailing, .bottom], 24)
                .accessibilityLabel("Create new list")
            }
        }
        .onAppear(perform: fetchLists)
        .fullScreenCover(item: $selectedList) { list in
            ListDetailView(
                list: list,
                onEdit: {
                    pendingEditList = list
                    selectedList = nil // Dismiss detail sheet
                },
                onDelete: {
                    deleteList(list)
                }
            )
        }
        .onChange(of: selectedList) { _, _ in
            // When detail sheet is dismissed and pendingEditList is set, show edit sheet
            if selectedList == nil, let toEdit = pendingEditList {
                listToEdit = toEdit
                showEditListSheet = true
                pendingEditList = nil
            }
        }
        .fullScreenCover(isPresented: $showEditListSheet) {
            if let list = listToEdit {
                EditListView(list: list, onListUpdated: {
                    fetchLists()
                })
            }
        }
        .fullScreenCover(isPresented: $showCreateListSheet) {
            CreateListView {
                fetchLists()
            }
        }
    }

    private func deleteList(_ list: MusicList) {
        MusicList.deleteList(listId: list.id) { _ in
            fetchLists()
        }
    }
    
    private func fetchLists() {
        let uid = userId ?? Auth.auth().currentUser?.uid
        print("[DEBUG] Fetching lists for uid: \(uid ?? "nil")")
        guard let uid else {
            userLists = []
            return
        }
        isLoadingLists = true
        // TEMP: Fetch all lists for debugging
        MusicList.fetchAllLists { lists, error in
            DispatchQueue.main.async {
                isLoadingLists = false
                if let lists = lists {
                    print("[DEBUG] Total lists fetched: \(lists.count)")
                    // Filter for this user and exclude Listen Next lists
                    let filtered = lists.filter { $0.userId == uid && $0.listType != "listenNext" }
                    print("[DEBUG] Regular lists matching userId: \(filtered.count)")
                    userLists = filtered
                    
                    let covers = filtered.reduce(into: [String: URL]()) { acc, list in
                        if let urlString = list.coverImageUrl,
                           !urlString.isEmpty,
                           let url = URL(string: urlString) {
                            acc[list.id] = url
                        }
                    }
                    listCoverImages = covers
                } else {
                    print("[DEBUG] No lists fetched or error: \(error?.localizedDescription ?? "none")")
                    userLists = []
                    listCoverImages = [:]
                }
            }
        }
    }
    
    private func fetchProfileAndLogs(forceProfileRefresh: Bool = false) {
        let uid = userId ?? Auth.auth().currentUser?.uid
        guard let uid else {
            errorMessage = "You must be logged in to view this profile."
            return
        }
        
        // Skip profile fetch if we already have it from prefetch (to prevent duplicate fetches and scrolling issues)
        let shouldFetchProfile = forceProfileRefresh || (profile == nil)
        
        if shouldFetchProfile {
        isLoading = true
        errorMessage = nil
        }
        
        // Fetch profile only if needed
        if shouldFetchProfile {
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                if let data = snapshot?.data() {
                    print("🎵 PINNED_ITEMS: 🔍 Raw Firestore data keys: \(Array(data.keys))")
                    print("🎵 PINNED_ITEMS: 🔍 pinnedSongs data: \(data["pinnedSongs"] ?? "nil")")
                    
                    // SAFETY: Try to decode with better error handling
                    do {
                        let profile = try Firestore.Decoder().decode(UserProfile.self, from: data)
                        print("🎵 PINNED_ITEMS: ✅ Profile fetched successfully - pinnedSongs count: \(profile.pinnedSongs?.count ?? 0)")
                        
                        // Relax validation: proceed even if some fields are empty; log warning only
                        if profile.uid.isEmpty || profile.username.isEmpty {
                            print("⚠️ Profile validation warning: empty uid/username, continuing")
                        }
                        
                        self.profile = profile
                        // Use denormalized follow counts immediately if available
                        self.viewModel.followerCount = profile.followerCount ?? self.viewModel.followerCount
                        self.viewModel.followingCount = profile.followingCount ?? self.viewModel.followingCount
                        self.isLoading = false
                        self.errorMessage = nil
                    } catch {
                        print("🎵 PINNED_ITEMS: ❌ Decode error: \(error)")
                        // Try to create a minimal profile manually
                        if let currentUser = Auth.auth().currentUser {
                            print("🎵 PINNED_ITEMS: 🔧 Creating minimal profile for UID: \(currentUser.uid)")
                            
                            // Extract pinned items from the data if they exist
                            var pinnedSongs: [PinnedItem]? = nil
                            var pinnedArtists: [PinnedItem]? = nil
                            var pinnedAlbums: [PinnedItem]? = nil
                            var pinnedLists: [PinnedItem]? = nil
                            
                            // Extract pinned songs
                            if let pinnedSongsData = data["pinnedSongs"] as? [[String: Any]] {
                                pinnedSongs = pinnedSongsData.compactMap { songData in
                                    guard let id = songData["id"] as? String else { return nil }
                                    let title = (songData["title"] as? String) ?? (songData["name"] as? String) ?? ""
                                    let artistName = (songData["artistName"] as? String) ?? ""
                                    let albumName = songData["albumName"] as? String
                                    let artworkURL = (songData["artworkURL"] as? String) ?? (songData["artworkUrl"] as? String)
                                    let itemType = (songData["itemType"] as? String) ?? "song"
                                    let dateAdded = (songData["dateAdded"] as? Date) ?? Date()
                                    return PinnedItem(id: id, title: title, artistName: artistName, albumName: albumName, artworkURL: artworkURL, itemType: itemType, dateAdded: dateAdded)
                                }
                                print("🎵 PINNED_ITEMS: 🎯 Extracted \(pinnedSongs?.count ?? 0) pinned songs")
                            }
                            
                            // Extract pinned artists
                            if let pinnedArtistsData = data["pinnedArtists"] as? [[String: Any]] {
                                pinnedArtists = pinnedArtistsData.compactMap { artistData in
                                    guard let id = artistData["id"] as? String else { return nil }
                                    let title = (artistData["title"] as? String) ?? (artistData["name"] as? String) ?? ""
                                    let artistName = (artistData["artistName"] as? String) ?? title
                                    let albumName = artistData["albumName"] as? String
                                    let artworkURL = (artistData["artworkURL"] as? String) ?? (artistData["artworkUrl"] as? String)
                                    let itemType = (artistData["itemType"] as? String) ?? "artist"
                                    let dateAdded = (artistData["dateAdded"] as? Date) ?? Date()
                                    return PinnedItem(id: id, title: title, artistName: artistName, albumName: albumName, artworkURL: artworkURL, itemType: itemType, dateAdded: dateAdded)
                                }
                                print("🎵 PINNED_ITEMS: 🎯 Extracted \(pinnedArtists?.count ?? 0) pinned artists")
                            }
                            
                            // Extract pinned albums
                            if let pinnedAlbumsData = data["pinnedAlbums"] as? [[String: Any]] {
                                pinnedAlbums = pinnedAlbumsData.compactMap { albumData in
                                    guard let id = albumData["id"] as? String else { return nil }
                                    let title = (albumData["title"] as? String) ?? (albumData["name"] as? String) ?? ""
                                    let artistName = (albumData["artistName"] as? String) ?? ""
                                    let albumName = albumData["albumName"] as? String
                                    let artworkURL = (albumData["artworkURL"] as? String) ?? (albumData["artworkUrl"] as? String)
                                    let itemType = (albumData["itemType"] as? String) ?? "album"
                                    let dateAdded = (albumData["dateAdded"] as? Date) ?? Date()
                                    return PinnedItem(id: id, title: title, artistName: artistName, albumName: albumName, artworkURL: artworkURL, itemType: itemType, dateAdded: dateAdded)
                                }
                                print("🎵 PINNED_ITEMS: 🎯 Extracted \(pinnedAlbums?.count ?? 0) pinned albums")
                            }
                            
                            // Extract pinned lists
                            if let pinnedListsData = data["pinnedLists"] as? [[String: Any]] {
                                pinnedLists = pinnedListsData.compactMap { listData in
                                    guard let id = listData["id"] as? String else { return nil }
                                    let title = (listData["title"] as? String) ?? (listData["name"] as? String) ?? ""
                                    let artistName = (listData["artistName"] as? String) ?? ""
                                    let albumName = listData["albumName"] as? String
                                    let artworkURL = (listData["artworkURL"] as? String) ?? (listData["artworkUrl"] as? String)
                                    let itemType = (listData["itemType"] as? String) ?? "list"
                                    let dateAdded = (listData["dateAdded"] as? Date) ?? Date()
                                    return PinnedItem(id: id, title: title, artistName: artistName, albumName: albumName, artworkURL: artworkURL, itemType: itemType, dateAdded: dateAdded)
                                }
                                print("🎵 PINNED_ITEMS: 🎯 Extracted \(pinnedLists?.count ?? 0) pinned lists")
                            }
                            
                            // Create a temporary profile with all pinned items
                            var tempProfile = UserProfile(
                                uid: currentUser.uid,
                                email: currentUser.email ?? "",
                                username: currentUser.displayName ?? "User", 
                                displayName: currentUser.displayName ?? "User",
                                createdAt: nil,
                                profilePictureUrl: nil,
                                profileHeaderUrl: nil,
                                bio: nil,
                                followers: nil,
                                following: nil,
                                isVerified: nil,
                                roles: nil,
                                reportCount: nil,
                                violationCount: nil,
                                locationSharingWith: nil,
                                showNowPlaying: nil,
                                nowPlayingSong: nil,
                                nowPlayingArtist: nil,
                                nowPlayingAlbumArt: nil,
                                nowPlayingUpdatedAt: nil,
                                pinnedSongs: pinnedSongs,
                                pinnedArtists: pinnedArtists,
                                pinnedAlbums: pinnedAlbums,
                                pinnedLists: pinnedLists,
                                pinnedSongsRanked: nil,
                                pinnedArtistsRanked: nil,
                                pinnedAlbumsRanked: nil,
                                pinnedListsRanked: nil
                            )
                            self.profile = tempProfile
                            print("🎵 PINNED_ITEMS: ✅ Created manual profile with:")
                            print("  - \(pinnedSongs?.count ?? 0) pinned songs")
                            print("  - \(pinnedArtists?.count ?? 0) pinned artists") 
                            print("  - \(pinnedAlbums?.count ?? 0) pinned albums")
                            print("  - \(pinnedLists?.count ?? 0) pinned lists")
                        }
                    }
                } else {
                    print("🎵 PINNED_ITEMS: ❌ No data in Firestore snapshot")
                }
                
                // Fetch logs after profile is loaded
                self.fetchLogs(for: uid)
            }
            }
        } else {
            // Profile already loaded from prefetch, just fetch logs
            print("✅ [UserProfileView] Using prefetched profile, fetching logs only")
            fetchLogs(for: uid)
        }
    }
    
    private func fetchLogs(for uid: String) {
        Task {
            do {
                let logs = try await MusicLogStore.shared.fetchLogs(forUserId: uid)
                await MainActor.run {
                    self.logs = logs
                    self.isLoading = false
                    self.fetchLists()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    let message = error.localizedDescription
                    if message.contains("index") || message.contains("create_composite") {
                        print("⚠️ Firestore index needed: \(message)")
                    } else {
                        self.errorMessage = message
                    }
                    self.fetchLists()
                }
            }
        }
    }
    


    private var overviewTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Settings button at top right, only for current user
                if isCurrentUser && showFullProfile {
                    HStack {
                        Spacer()
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                        }
                        .accessibilityLabel("Settings")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
                
                // Split into groups to reduce complexity and prevent crashes
                profileAndSocialGroup
                    .id("profile-social")
                pinnedItemsGroup
                    .id("pinned-items")
                analyticsGroup
                    .id("analytics")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Extra padding for tab bar
        }
    }
    
    // MARK: - Overview Tab Groups (Uses AnyView to prevent stack overflow from deep type nesting)
    
    private var profileAndSocialGroup: AnyView {
        AnyView(
        VStack(spacing: 24) {
                // Split into smaller sections to prevent type resolution crashes
                profileBasicInfoSection
                profileBioSection
                profileSocialStatsSection
                profileActionsSection
            recentDiarySection
        }
        )
    }
    
    private var pinnedItemsGroup: AnyView {
        AnyView(
        VStack(spacing: 20) {
            pinnedSongsSection
            pinnedArtistsSection
            pinnedAlbumsSection
        }
        )
    }
    
    private var analyticsGroup: AnyView {
        AnyView(
        VStack(spacing: 24) {
            ratingDistributionSection
            genreChartSection
            statsSection
        }
        )
    }
    
    // MARK: - Profile Header Sections (Split for Type Resolution)
    
    // Basic info: Picture, Name, Username - wrapped in AnyView to break type chain
    private var profileBasicInfoSection: AnyView {
        guard let profile = profile, !profile.uid.isEmpty, !profile.username.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
                    VStack(spacing: 20) {
                profilePicturePlaceholder // Use simple placeholder to avoid type complexity
                    .overlay(
                        // Load actual image on top if available
                        Group {
                            if let urlString = profile.profilePictureUrl,
                               !urlString.isEmpty,
                               let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if case .success(let image) = phase {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                    )
                
                VStack(spacing: 6) {
                            Text(profile.displayName)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                            Text("@\(profile.username)")
                        .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
        )
    }
    
    // Bio section - wrapped in AnyView
    private var profileBioSection: AnyView {
        guard let profile = profile, let bio = profile.bio, !bio.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
                                Text(bio)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .lineSpacing(2)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
        )
                }
                
    // Social stats: Followers/Following - wrapped in AnyView
    private var profileSocialStatsSection: AnyView {
        guard let profile = profile, !profile.uid.isEmpty else {
            return AnyView(EmptyView())
                }
        return AnyView(
            VStack(spacing: 12) {
                // Followers and Following (simplified - removed social score to reduce complexity)
                HStack(spacing: 40) {
                    Button(action: { showFollowersList = true }) {
                        VStack(spacing: 6) {
                            Text("\(formatNumber(viewModel.followerCount))")
                                .font(.system(size: 24, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                            
                            Text("Followers")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1, height: 40)
                    
                    Button(action: { showFollowingList = true }) {
                        VStack(spacing: 6) {
                            Text("\(formatNumber(viewModel.followingCount))")
                                .font(.system(size: 24, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                            
                            Text("Following")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 8)
            }
        )
    }
                
    // Action buttons: Edit/Follow/Message/Block - wrapped in AnyView
    private var profileActionsSection: AnyView {
        guard let profile = profile, !profile.uid.isEmpty else {
            return AnyView(EmptyView())
        }
                if isCurrentUser {
            return AnyView(
                VStack(spacing: 12) {
                    Button(action: { showEditProfile = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .medium))
                                    Text("Edit Profile")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.purple)
                        .cornerRadius(22)
                    }
                    .padding(.horizontal, 24)

                    Button(action: { showBlockedUsers = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 14, weight: .medium))
                            Text("Blocked Users")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(22)
                    }
                    .padding(.horizontal, 24)
                }
            )
                        } else {
            return AnyView(profileOtherUserActionsSimple(profile: profile))
        }
    }
    
    // Simplified other user actions to reduce type complexity
    private func profileOtherUserActionsSimple(profile: UserProfile) -> some View {
                    HStack(spacing: 12) {
            // Follow button
                        Button(action: {
                            if let userId = userId {
                                viewModel.toggleFollow(userId: userId)
                            }
                        }) {
                                    Text(viewModel.isFollowing ? "Following" : "Follow")
                                        .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    .background(viewModel.isFollowing ? Color.gray : Color.purple)
                            .cornerRadius(22)
                        }
                        .disabled(viewModel.isFollowActionLoading)
                        
            // Message button
                        Button(action: {
                            guard let target = userId else { return }
                            DirectMessageService.shared.getOrCreateConversation(with: target) { convo, _ in
                                if let convo = convo {
                                    DispatchQueue.main.async { self.selectedConversation = convo }
                                }
                            }
                        }) {
                                Text("Message")
                                    .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(22)
            }
            
            // More menu
                        Menu {
                Button("Report User") { showReportSheet = true }
                Button("Block User") { showBlockSheet = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                }
    
    // MARK: - Profile Picture Placeholder (extracted to avoid type complexity)
    private var profilePicturePlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.4))
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white, Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
        
    // MARK: - Profile Picture View (Safe with Fallback)
    @ViewBuilder
    private func profilePictureView(profile: UserProfile) -> some View {
        if let urlString = profile.profilePictureUrl,
           !urlString.isEmpty,
           let imageUrl = URL(string: urlString) {
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white, Color.gray.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
                case .failure(_):
                    profilePicturePlaceholder
                case .empty:
                    profilePicturePlaceholder
                @unknown default:
                    profilePicturePlaceholder
                }
            }
        } else {
            profilePicturePlaceholder
        }
    }

    
    // MARK: - Helper Functions
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000.0)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
                                        } else {
            return "\(number)"
        }
    }

    // MARK: - Simple subviews to reduce body complexity
    
    /// Decides whether to show blocked view or profile content - extracted to simplify body type inference
    @ViewBuilder
    private func profileOrBlockedView(for profile: UserProfile) -> some View {
        // Use verified block status if available, otherwise use cached value
        let isBlockedByThisUser: Bool = {
            if let verified = verifiedBlockedByUser {
                return verified
            }
            return blockingService.hasUserBlockedMe(profile.uid)
        }()
        
        if isBlockedByThisUser {
            blockedProfileView(message: "You are blocked by this user.")
        } else if blockingService.isUserBlocked(profile.uid) {
            blockedProfileView(message: "You have blocked this user.")
        } else {
            profileContentView
        }
    }
    
    /// Verify block status against authoritative source (the other user's blockedUsers array)
    private func verifyBlockStatus(for userId: String) {
        guard !isCurrentUser else { return }
        
        isVerifyingBlockStatus = true
        
        Task {
            let actuallyBlocked = await blockingService.hasUserBlockedMeAsync(userId)
            await MainActor.run {
                verifiedBlockedByUser = actuallyBlocked
                isVerifyingBlockStatus = false
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
            Text("Loading profile...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 12)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Unable to load profile")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") {
                fetchProfileAndLogs()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var fallbackView: some View {
        VStack {
            Spacer()
            Text("No profile data available")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Blocked Profile View
    @ViewBuilder
    private func blockedProfileView(message: String) -> some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.purple)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.red)
                Text(message)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("This profile is not available.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
    }
    
    // MARK: - Recent Diary Section
    private var recentDiarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                        .frame(width: 20, height: 20)
                    
                    Text("Recent Diary")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    selectedStatCategory = .logs
                }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(BumpinButtonStyle())
            }
            .padding(.horizontal, 4)
            
            // Scrollable Diary Content
            if isLoading {
                // Loading state with shimmer effect
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<5, id: \.self) { _ in
                            diaryLoadingCard
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else if logs.isEmpty {
                // Empty state
                diaryEmptyState
            } else {
                // Actual diary entries
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(logs.prefix(10))) { log in
                            diaryEntryCard(log: log)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    // MARK: - Diary Entry Card
    private func diaryEntryCard(log: MusicLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cover Art
                                                Button(action: {
                // Navigate to song/album profile (atomic approach)
                print("🎯 UserProfileView: Navigating to profile for: \(log.title) (ID: \(log.itemId))")
                
                // Set state atomically - no delays, no race conditions
                selectedPinnedLog = log // Highlight this specific log
                selectedMusicItem = MusicSearchResult(
                    id: log.itemId,
                    title: log.title,
                    artistName: log.artistName,
                    albumName: log.itemType == "album" ? log.title : "",
                    artworkURL: log.artworkUrl,
                    itemType: log.itemType,
                                                        popularity: 0
                                                    )
                print("🎯 UserProfileView: State set atomically with pinned log")
                AnalyticsService.shared.logTap(category: "diary_entry_artwork", id: log.itemId)
            }) {
                Group {
                    if let artworkUrl = log.artworkUrl, let url = URL(string: artworkUrl) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray.opacity(0.6))
                                )
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray.opacity(0.6))
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(BumpinButtonStyle())
            
            // Title and Artist
            VStack(alignment: .leading, spacing: 4) {
                                            Button(action: {
                    // Navigate to song/album profile (atomic approach)
                    print("🎯 UserProfileView: Navigating to profile for title: \(log.title)")
                    
                    // Set state atomically
                    selectedPinnedLog = nil // No specific log to highlight
                    selectedMusicItem = MusicSearchResult(
                        id: log.itemId,
                        title: log.title,
                        artistName: log.artistName,
                        albumName: log.itemType == "album" ? log.title : "",
                        artworkURL: log.artworkUrl,
                        itemType: log.itemType,
                                                    popularity: 0
                                                )
                    print("🎯 UserProfileView: Title navigation state set atomically")
                    AnalyticsService.shared.logTap(category: "diary_entry_title", id: log.itemId)
                                            }) {
                    Text(log.title)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                                                    .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                                            }
                                            .buttonStyle(.plain)
                
                Button(action: {
                    // Navigate to enhanced artist profile instead of music profile
                    print("🎯 UserProfileView: Tapping artist name: \(log.artistName)")
                    selectedArtistName = log.artistName
                    showArtistProfile = true
                    AnalyticsService.shared.logTap(category: "diary_entry_artist", id: log.artistName)
                }) {
                    Text(log.artistName)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 120, alignment: .leading)
            
            // Star Rating (clickable)
            if let rating = log.rating {
                Button(action: {
                    // Navigate to song profile with highlighted log (like diary tab)
                    print("🎯 UserProfileView: Navigating to profile with highlighted log: \(log.title)")
                    
                    // Set state atomically
                    selectedPinnedLog = log // Highlight this specific log
                    selectedMusicItem = MusicSearchResult(
                        id: log.itemId,
                        title: log.title,
                        artistName: log.artistName,
                        albumName: log.itemType == "album" ? log.title : "",
                        artworkURL: log.artworkUrl,
                        itemType: log.itemType,
                        popularity: 0
                    )
                    print("🎯 UserProfileView: Stars navigation state set atomically with highlighted log")
                    AnalyticsService.shared.logTap(category: "diary_entry_rating", id: log.id)
                }) {
                    StarRatingDisplayView(rating: rating, starSize: 12, spacing: 2, showNumber: true)
                        .padding(.vertical, 4)
                }
                .buttonStyle(BumpinButtonStyle())
                    } else {
                // No rating placeholder
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { _ in
                        Image(systemName: "star")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray.opacity(0.2))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 120, height: 180) // Consistent height with other cards
        .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray6), lineWidth: 1)
        )
    }
    
    // MARK: - Diary Loading Card
    private var diaryLoadingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Loading cover art
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 120)
                .shimmer()
            
            // Loading title and artist
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 14)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 80, height: 12)
                    .shimmer()
            }
            
            // Loading stars
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 12, height: 12)
                        .shimmer()
                }
            }
        }
        .frame(width: 120, height: 180) // Consistent height with music cards
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Diary Empty State
    private var diaryEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("No diary entries yet")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                
                Text("Start logging your music to see it here")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
                        if isCurrentUser {
                Button(action: {
                    showingLogMusicView = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Log Your First Song")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(BumpinPrimaryButtonStyle())
            }
                    }
                    .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
    
    // MARK: - Pinned Section Components
    
    // Reusable section header for pinned sections
    private func pinnedSectionHeader(title: String, icon: String, onEdit: (() -> Void)?, showRankingToggle: Binding<Bool>?) -> some View {
        HStack(alignment: .center, spacing: 8) {
            // Left side: Icon + Title (with more space)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.purple)
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8) // Allow slight scaling if needed
            }
            
            Spacer(minLength: 8) // Ensure minimum space
            
            // Right side: More compact controls
            HStack(spacing: 6) {
                // Ranking toggle for current user (smaller)
                if let showRankingToggle = showRankingToggle, isCurrentUser {
                    Toggle("", isOn: showRankingToggle)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .scaleEffect(0.7) // Smaller toggle
                }
                
                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 3) {
                            Text("Edit")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(14)
                    }
                    .buttonStyle(BumpinButtonStyle())
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // Reusable pinned music card (songs, artists, albums)
    private func pinnedMusicCard(item: PinnedItem, index: Int, type: PinnedType, showRanking: Bool) -> some View {
        PinnedMusicCardView(item: item, index: index, type: type, showRanking: showRanking, onTap: {
            navigateToPinnedItem(item: item, type: type)
        }, onArtistTap: { artistName in
            selectedArtistName = artistName
            showArtistProfile = true
            AnalyticsService.shared.logTap(category: "pinned_\(type == .song ? "song" : "album")_artist", id: artistName)
        })
    }
    
    // Artwork component for pinned music card
    private func pinnedMusicCardArtwork(item: PinnedItem, index: Int, type: PinnedType, showRanking: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Button(action: {
                navigateToPinnedItem(item: item, type: type)
            }) {
                Group {
                    if let artworkUrl = item.artworkUrl, let url = URL(string: artworkUrl) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            pinnedPlaceholder(type: type)
                        }
                    } else {
                        pinnedPlaceholder(type: type)
                    }
                }
                .frame(width: 120, height: 120)
                .cornerRadius(type == .artist ? 60 : 12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: type == .artist ? 60 : 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(BumpinButtonStyle())
            
            if showRanking {
                pinnedRankingBadge(index: index)
            }
        }
    }
    
    // Title component for pinned music card
    private func pinnedMusicCardTitle(item: PinnedItem, type: PinnedType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title (clickable)
                                        Button(action: {
                navigateToPinnedItem(item: item, type: type)
                                        }) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                                                .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 120, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
            
            // Artist name (for songs and albums, clickable)
            if type != .artist && !item.artistName.isEmpty {
                Button(action: {
                    // Navigate to artist profile
                    selectedArtistName = item.artistName
                    showArtistProfile = true
                    AnalyticsService.shared.logTap(category: "pinned_\(type == .song ? "song" : "album")_artist", id: item.artistName)
                }) {
                    Text(item.artistName)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .frame(width: 120, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 120, alignment: .leading)
    }
    
    // Ranking badge component
    private func pinnedRankingBadge(index: Int) -> some View {
        Text("#\(index)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.purple.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
            .offset(x: -8, y: 8)
    }
    
    // Navigation helper for pinned items
    private func navigateToPinnedItem(item: PinnedItem, type: PinnedType) {
        let artistName = type == .artist ? item.name : "Unknown Artist"
        let albumName = type == .album ? item.name : ""
        let itemType: String = {
            switch type {
            case .song: return "song"
            case .artist: return "artist"
            case .album: return "album"
            }
        }()
        
        // Set state atomically
        selectedPinnedLog = nil // No specific log to highlight
        selectedMusicItem = MusicSearchResult(
            id: item.id,
            title: item.title,
            artistName: artistName,
            albumName: albumName,
            artworkURL: item.artworkURL,
            itemType: itemType,
            popularity: 0
        )
        print("🎯 UserProfileView: Pinned item navigation state set atomically")
        AnalyticsService.shared.logTap(category: "pinned_\(itemType)", id: item.id)
    }
    
    // Placeholder for pinned items without artwork
    private func pinnedPlaceholder(type: PinnedType) -> some View {
        RoundedRectangle(cornerRadius: type == .artist ? 60 : 12)
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: pinnedTypeIcon(type))
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.6))
            )
    }
    
    // Empty state for pinned sections
    private func pinnedEmptyState(type: PinnedType, icon: String, title: String, subtitle: String, buttonTitle: String, onAdd: (() -> Void)?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let onAdd = onAdd {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text(buttonTitle)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(BumpinPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    // Helper function for pinned type icons
    private func pinnedTypeIcon(_ type: PinnedType) -> String {
        switch type {
        case .song: return "music.note"
        case .artist: return "person.wave.2"
        case .album: return "opticaldisc"
        }
    }
    
    // MARK: - Pinned Songs Section
    private var pinnedSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            pinnedSectionHeader(
                title: "Pinned Songs",
                icon: "music.note",
                onEdit: isCurrentUser ? { showEditPinnedSongs = true } : nil,
                showRankingToggle: isCurrentUser ? $showRankingForSongs : nil
            )
            
            // Scrollable Content
            if let profile = profile, let pinnedSongs = profile.pinnedSongs, !pinnedSongs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(pinnedSongs.enumerated()), id: \.element.id) { index, item in
                            pinnedMusicCard(
                                item: item,
                                index: index + 1,
                                type: .song,
                                showRanking: showRankingForSongs
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                pinnedEmptyState(
                    type: .song,
                    icon: "music.note",
                    title: "No pinned songs",
                    subtitle: isCurrentUser ? "Pin your favorite songs to showcase them" : "No songs pinned yet",
                    buttonTitle: "Pin Songs",
                    onAdd: isCurrentUser ? { showEditPinnedSongs = true } : nil
                )
            }
        }
    }
    
    // MARK: - Pinned Artists Section
    private var pinnedArtistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            pinnedSectionHeader(
                title: "Pinned Artists",
                icon: "person.wave.2",
                onEdit: isCurrentUser ? { showEditPinnedArtists = true } : nil,
                showRankingToggle: isCurrentUser ? $showRankingForArtists : nil
            )
            
            // Scrollable Content
            if let profile = profile, let pinnedArtists = profile.pinnedArtists, !pinnedArtists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(pinnedArtists.enumerated()), id: \.element.id) { index, item in
                            pinnedMusicCard(
                                item: item,
                                index: index + 1,
                                type: .artist,
                                showRanking: showRankingForArtists
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                    } else {
                pinnedEmptyState(
                    type: .artist,
                    icon: "person.wave.2",
                    title: "No pinned artists",
                    subtitle: isCurrentUser ? "Pin your favorite artists to showcase them" : "No artists pinned yet",
                    buttonTitle: "Pin Artists",
                    onAdd: isCurrentUser ? { showEditPinnedArtists = true } : nil
                )
            }
        }
    }
    
    // MARK: - Pinned Albums Section
    private var pinnedAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            pinnedSectionHeader(
                title: "Pinned Albums",
                icon: "opticaldisc",
                onEdit: isCurrentUser ? { showEditPinnedAlbums = true } : nil,
                showRankingToggle: isCurrentUser ? $showRankingForAlbums : nil
            )
            
            // Scrollable Content
            if let profile = profile, let pinnedAlbums = profile.pinnedAlbums, !pinnedAlbums.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(pinnedAlbums.enumerated()), id: \.element.id) { index, item in
                            pinnedMusicCard(
                                item: item,
                                index: index + 1,
                                type: .album,
                                showRanking: showRankingForAlbums
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                pinnedEmptyState(
                    type: .album,
                    icon: "opticaldisc",
                    title: "No pinned albums",
                    subtitle: isCurrentUser ? "Pin your favorite albums to showcase them" : "No albums pinned yet",
                    buttonTitle: "Pin Albums",
                    onAdd: isCurrentUser ? { showEditPinnedAlbums = true } : nil
                )
            }
        }
    }
    
    // MARK: - Rating Distribution Section
    private var ratingDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                        .frame(width: 20, height: 20)
                    
                    Text("Rating Distribution")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if !logs.isEmpty {
                    let totalRatings = logs.filter { $0.rating != nil && $0.rating! > 0 }.count
                    if totalRatings > 0 {
                        Text("\(totalRatings) total ratings")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Rating Distribution Content
            if isLoading {
                ratingDistributionLoadingState
            } else if logs.isEmpty || logs.filter({ $0.rating != nil && $0.rating! > 0 }).isEmpty {
                ratingDistributionEmptyState
            } else {
                ratingDistributionContent
            }
        }
    }
    
    // MARK: - Rating Distribution Content
    private var ratingDistributionContent: some View {
        let ratedLogs = logs.filter { $0.rating != nil && $0.rating! > 0 }
        let ratingData = calculateRatingDistribution(from: ratedLogs)
        
        return VStack(spacing: 8) {
            ForEach(ratingData.sorted(by: { $0.lowerBound > $1.lowerBound })) { bucket in
                RatingBarRow(
                    bucket: bucket,
                    maxCount: ratingData.map(\.count).max() ?? 1,
                    color: colorForBucket(bucket),
                    onTap: {
                        selectedRatingBucket = bucket
                    }
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private struct RatingBarRow: View {
        let bucket: RatingDistributionData
        let maxCount: Int
        let color: Color
        var onTap: (() -> Void)? = nil
        
        private var barWidth: CGFloat {
            guard maxCount > 0, bucket.count >= 0 else { return 0 }
            let width = CGFloat(bucket.count) / CGFloat(maxCount)
            return min(max(width, 0), 1)
        }
        
        var body: some View {
            HStack(spacing: 12) {
                // Rating label
                Text(bucket.bucketRange)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray6))
                            .frame(height: 20)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * barWidth, height: 20)
                            .shadow(color: color.opacity(0.25), radius: 2, x: 0, y: 1)
                    }
                }
                .frame(height: 20)
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(bucket.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(Int(bucket.percentage))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.12), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Profile Rating Bucket Detail Sheet
    private struct ProfileRatingBucketDetailView: View {
        @Environment(\.dismiss) private var dismiss
        let bucket: RatingDistributionData
        let logs: [MusicLog]
        let subtitle: String?
        let isCurrentUser: Bool
        let onLogTap: (MusicLog) -> Void
        let onEdit: ((MusicLog) -> Void)?
        let onDelete: ((MusicLog) -> Void)?
        let onCorrectGenre: ((MusicLog) -> Void)?
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                    }
                    
                    Divider()
                    
                    if logs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 44, weight: .light))
                                .foregroundColor(.secondary)
                            Text("No logs in this range yet.")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(.systemGroupedBackground))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(logs) { log in
                                    DiaryLogCard(
                                        log: log,
                                        onTap: {
                                            dismiss()
                                            onLogTap(log)
                                        },
                                        onEdit: wrappedAction(for: onEdit, log: log),
                                        onDelete: wrappedAction(for: onDelete, log: log),
                                        onCorrectGenre: wrappedAction(for: onCorrectGenre, log: log),
                                        isCurrentUser: isCurrentUser
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .navigationTitle(bucket.bucketRange)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
        
        private func wrappedAction(for action: ((MusicLog) -> Void)?, log: MusicLog) -> (() -> Void)? {
            guard let action else { return nil }
            return {
                dismiss()
                action(log)
            }
        }
    }
    
    // MARK: - Rating Distribution Loading State
    private var ratingDistributionLoadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading ratings...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Rating Distribution Empty State
    private var ratingDistributionEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No ratings yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(isCurrentUser ? "Log more music to see your rating distribution" : "No ratings available yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if isCurrentUser {
                Button(action: { showingLogMusicView = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start Logging Music")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Rating Distribution Helper Methods
    private func calculateRatingDistribution(from logs: [MusicLog]) -> [RatingDistributionData] {
        let totalCount = logs.count
        
        // Define 10 half-star buckets
        let buckets: [(Double, Double)] = [
            (1.0, 1.4),
            (1.5, 1.9),
            (2.0, 2.4),
            (2.5, 2.9),
            (3.0, 3.4),
            (3.5, 3.9),
            (4.0, 4.4),
            (4.5, 4.9),
            (5.0, 5.0)  // Exactly 5.0 stars
        ]
        
        // Count ratings in each bucket
        var bucketCounts: [Int] = Array(repeating: 0, count: buckets.count)
        
        for log in logs {
            guard let rating = log.rating, rating > 0 else { continue }
            
            // Find which bucket this rating belongs to
            for (index, bucket) in buckets.enumerated() {
                if rating >= bucket.0 && rating <= bucket.1 {
                    bucketCounts[index] += 1
                    break
                }
            }
        }
        
        // Create distribution data
        return buckets.enumerated().map { index, bucket in
            RatingDistributionData(
                lowerBound: bucket.0,
                upperBound: bucket.1,
                count: bucketCounts[index],
                totalRatings: totalCount
            )
        }
    }
    
    private func colorForBucket(_ bucket: RatingDistributionData) -> Color {
        let midPoint = (bucket.lowerBound + bucket.upperBound) / 2.0
        
        switch midPoint {
        case 0..<1.75:
            return .red
        case 1.75..<2.75:
            return .orange
        case 2.75..<3.75:
            return .yellow
        case 3.75..<4.5:
            return .green
        default:
            return .blue
        }
    }
    
    // MARK: - Genre Chart Section
    private var genreChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(alignment: .center) {
                        HStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                        .frame(width: 20, height: 20)
                    
                    Text("Music Taste")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Genre Chart Content
            if isLoading {
                genreChartLoadingState
            } else if logs.isEmpty {
                genreChartEmptyState
                } else {
                genreChartContent
            }
        }
    }
    
    // MARK: - Genre Chart Content
    private var genreChartContent: some View {
        // Use cached genre data to prevent pie chart spinning
        let genreData = getCachedGenreData()
        
        return VStack(spacing: 20) {
            if !genreData.isEmpty {
                // Pie Chart (stable, no animations)
                genrePieChart(data: genreData)
                    .id("stable-pie-chart-\(genreData.count)") // Stable ID based on data
                    .animation(nil) // Disable all animations on pie chart
                    .transaction { transaction in
                        transaction.disablesAnimations = true // Force disable animations
                    }
                
                // Genre Legend
                genreLegend(data: genreData)
                        } else {
                genreChartEmptyState
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            updateCachedGenreData()
        }
        .onChange(of: logs.count) { _ in
            updateCachedGenreData()
        }
    }
    
    // MARK: - Genre Pie Chart
    private func genrePieChart(data: [GenreData]) -> some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color(.systemGray6).opacity(0.3))
                .frame(width: 200, height: 200)
            
            // Pie chart segments (completely stable)
            ForEach(Array(data.enumerated()), id: \.element.id) { index, genre in
                PieSlice(
                    startAngle: startAngle(for: index, in: data),
                    endAngle: endAngle(for: index, in: data)
                )
                .fill(genreColor(for: genre.name))
                .frame(width: 180, height: 180)
            }
            
            // Center circle with total count
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 80, height: 80)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .overlay(
                    VStack(spacing: 2) {
                        Text("\(logs.count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Logs")
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                    }
                )
        }
        .frame(width: 200, height: 200)
    }
    
    // MARK: - Genre Legend
    private func genreLegend(data: [GenreData]) -> some View {
        VStack(spacing: 12) {
            ForEach(data.prefix(6)) { genre in
                GenreLegendRow(genre: genre, onTap: {
                    selectedGenreForDetail = genre.name
                    print("🎯 Opening genre detail for: \(genre.name)")
                }, genreColor: genreColor)
            }
            
            // Show more genres if there are more than 6
            if data.count > 6 {
                Button(action: {
                    // TODO: Show all genres in a sheet
                    print("Show all \(data.count) genres")
                }) {
                    HStack(spacing: 6) {
                        Text("View \(data.count - 6) more genres")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                        .foregroundColor(.purple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(BumpinButtonStyle())
            }
        }
    }
    
    // MARK: - Genre Chart Loading State
    private var genreChartLoadingState: some View {
        VStack(spacing: 20) {
            // Loading pie chart
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 200, height: 200)
                .shimmer()
                .overlay(
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 80, height: 80)
                        .shimmer()
                )
            
            // Loading legend
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 12, height: 12)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 14)
                            .shimmer()
                        
                Spacer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 40, height: 12)
                            .shimmer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Genre Chart Empty State
    private var genreChartEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("No genre data yet")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                
                Text(isCurrentUser ? "Log more music to see your taste distribution" : "No music logged yet")
                    .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if isCurrentUser {
                Button(action: {
                    showingLogMusicView = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Start Logging Music")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(BumpinPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                        .frame(width: 20, height: 20)
                    
                    Text("Music Stats")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Stats Grid
            if isLoading {
                statsLoadingState
        } else {
                statsContent
            }
        }
    }
    
    // MARK: - Stats Content
    private var statsContent: some View {
        let stats = calculateUserStats()
        
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 12) {
            ForEach(stats, id: \.category) { stat in
                statsCard(stat: stat)
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Individual Stats Card
    private func statsCard(stat: UserStat) -> some View {
        StatsCardView(stat: stat, onTap: {
            selectedStatCategory = stat.statCategory
            AnalyticsService.shared.logTap(category: "profile_stat", id: stat.category)
        }, formatNumber: formatNumber)
    }
    
    // MARK: - Stats Loading State
    private var statsLoadingState: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                statsLoadingCard
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Stats Loading Card
    private var statsLoadingCard: some View {
        VStack(spacing: 12) {
            // Loading icon
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .shimmer()
            
            // Loading number and label
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 20)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 50, height: 12)
                    .shimmer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
                                        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Stats Data Model
    struct UserStat {
        let category: String
        let label: String
        let count: Int
        let icon: String
        let color: Color
        let statCategory: StatCategory
    }
    
    // Calculate all user statistics
    private func calculateUserStats() -> [UserStat] {
        let uniqueSongs = Set(logs.filter { $0.itemType == "song" }.map { $0.itemId }).count
        let uniqueArtists = Set(logs.map { $0.artistName }).count
        let uniqueAlbums = Set(logs.filter { $0.itemType == "album" }.map { $0.itemId }).count
        let repostsCount = userReposts.count
        
        return [
            UserStat(
                category: "logs",
                label: "Total Logs",
                count: logs.count,
                icon: "music.note.list",
                color: .purple,
                statCategory: .logs
            ),
            UserStat(
                category: "songs",
                label: "Songs",
                count: uniqueSongs,
                icon: "music.note",
                color: .blue,
                statCategory: .songs
            ),
            UserStat(
                category: "artists",
                label: "Artists",
                count: uniqueArtists,
                icon: "person.wave.2",
                color: .orange,
                statCategory: .artists
            ),
            UserStat(
                category: "albums",
                label: "Albums",
                count: uniqueAlbums,
                icon: "opticaldisc",
                color: .green,
                statCategory: .albums
            ),
            UserStat(
                category: "reposts",
                label: "Reposts",
                count: repostsCount,
                icon: "arrow.2.squarepath",
                color: .red,
                statCategory: .reposts
            ),
            UserStat(
                category: "lists",
                label: "Lists",
                count: userLists.count,
                icon: "list.bullet.rectangle",
                color: .indigo,
                statCategory: .lists
            )
        ]
    }
    
    // MARK: - Pie Chart Shape
    struct PieSlice: Shape {
        let startAngle: Angle
        let endAngle: Angle
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
            path.closeSubpath()
            
            return path
        }
    }
    
    // MARK: - Genre Chart Data Models and Helpers
    
    struct GenreData: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let count: Int
        let percentage: Double
        
        static func == (lhs: GenreData, rhs: GenreData) -> Bool {
            return lhs.name == rhs.name && lhs.count == rhs.count && lhs.percentage == rhs.percentage
        }
    }
    
    // Cache management for stable pie chart
    private func getCachedGenreData() -> [GenreData] {
        if cachedGenreData.isEmpty || lastLogCount != logs.count {
            return calculateGenreDistribution()
        }
        return cachedGenreData
    }
    
    private func updateCachedGenreData() {
        if lastLogCount != logs.count {
            cachedGenreData = calculateGenreDistribution()
            lastLogCount = logs.count
            print("🎯 Genre data cached: \(cachedGenreData.count) genres for \(logs.count) logs")
        }
    }
    
    // Calculate genre distribution from user's song logs only
    private func calculateGenreDistribution() -> [GenreData] {
        guard !logs.isEmpty else { return [] }
        
        // Filter to only include songs (not albums or artists)
        let songLogs = logs.filter { $0.itemType == "song" }
        guard !songLogs.isEmpty else { return [] }
        
        // Count genres from song logs using the AI-classified primaryGenre field
        var genreCounts: [String: Int] = [:]
        
        var logsByGenre: [String: [MusicLog]] = [:]
        
        for log in songLogs {
            let genre = resolvedGenre(for: log)
            genreCounts[genre, default: 0] += 1
            logsByGenre[genre, default: []].append(log)
        }
        
        genreLogsByName = logsByGenre
        
        let totalCount = songLogs.count
        
        // Convert to GenreData and sort by count
        let genreData = genreCounts.map { (genre, count) in
            GenreData(
                name: genre,
                count: count,
                percentage: (Double(count) / Double(totalCount)) * 100.0
            )
        }.sorted { $0.count > $1.count }
        
        print("🎯 Genre distribution calculated: \(genreData.map { "\($0.name): \($0.count)" }.joined(separator: ", "))")
        return genreData
    }
    
    private func resolvedGenre(for log: MusicLog) -> String {
        if let primaryGenre = log.primaryGenre, !primaryGenre.isEmpty {
            print("🤖 Using AI-classified genre: \(log.title) by \(log.artistName) → \(primaryGenre)")
            return primaryGenre
        }
        return classifyGenreFallback(title: log.title, artist: log.artistName)
    }
    
    // Phase 2: Map Apple Music genres to our standardized categories
    private func mapAppleMusicGenre(_ appleMusicGenre: String) -> String {
        let genre = appleMusicGenre.lowercased()
        
        // Map Apple Music genres to our categories
        switch genre {
        // Hip-Hop variations
        case let g where g.contains("hip hop") || g.contains("hip-hop") || g.contains("rap") || 
                        g.contains("trap") || g.contains("drill") || g.contains("grime"):
            return "Hip-Hop"
            
        // Pop variations  
        case let g where g.contains("pop") && !g.contains("k-pop") && !g.contains("latin pop"):
            return "Pop"
            
        // R&B variations
        case let g where g.contains("r&b") || g.contains("rnb") || g.contains("soul") || 
                        g.contains("rhythm") || g.contains("contemporary r&b"):
            return "R&B"
            
        // Electronic variations
        case let g where g.contains("electronic") || g.contains("edm") || g.contains("house") ||
                        g.contains("techno") || g.contains("trance") || g.contains("dubstep") ||
                        g.contains("ambient") || g.contains("electro") || g.contains("dance"):
            return "Electronic"
            
        // Rock variations
        case let g where g.contains("rock") && !g.contains("country rock") || g.contains("metal") ||
                        g.contains("punk") || g.contains("grunge") || g.contains("hardcore"):
            return "Rock"
            
        // Indie variations
        case let g where g.contains("indie") || g.contains("alternative") || g.contains("lo-fi") ||
                        g.contains("bedroom pop") || g.contains("dream pop"):
            return "Indie"
            
        // Country variations
        case let g where g.contains("country") || g.contains("folk") || g.contains("bluegrass") ||
                        g.contains("americana") || g.contains("western"):
            return "Country"
            
        // K-Pop variations
        case let g where g.contains("k-pop") || g.contains("korean") || g.contains("j-pop"):
            return "K-Pop"
            
        // Latin variations
        case let g where g.contains("latin") || g.contains("reggaeton") || g.contains("salsa") ||
                        g.contains("bachata") || g.contains("cumbia") || g.contains("mariachi"):
            return "Latin"
            
        // Jazz variations
        case let g where g.contains("jazz") || g.contains("swing") || g.contains("bebop") ||
                        g.contains("fusion") || g.contains("smooth jazz"):
            return "Jazz"
            
        // Classical variations
        case let g where g.contains("classical") || g.contains("orchestra") || g.contains("symphony") ||
                        g.contains("baroque") || g.contains("romantic") || g.contains("opera"):
            return "Classical"
            
        // Reggae variations
        case let g where g.contains("reggae") || g.contains("dub") || g.contains("ska") ||
                        g.contains("dancehall"):
            return "Reggae"
            
        // Funk variations
        case let g where g.contains("funk") || g.contains("disco") || g.contains("groove"):
            return "Funk"
            
        // Blues variations
        case let g where g.contains("blues") || g.contains("delta") || g.contains("chicago blues"):
            return "Blues"
            
        default:
            print("🎯 Unmapped Apple Music genre: \(appleMusicGenre)")
            return "Other"
        }
    }
    
    private func logsForGenre(_ genre: String) -> [MusicLog] {
        if let cached = genreLogsByName[genre], !cached.isEmpty {
            return cached
        }
        // Fallback: filter song logs using resolved genre
        return logs.filter { $0.itemType == "song" && resolvedGenre(for: $0) == genre }
    }
    
    // Phase 3: Enhanced classifier that learns from user corrections
    private func classifyGenreWithLearning(title: String, artist: String) -> String {
        let result = classifyGenreFallback(title: title, artist: artist)
        
        // Phase 3: Check if we have user corrections for this artist
        checkForUserCorrections(artist: artist) { correctedGenre in
            if let correctedGenre = correctedGenre, correctedGenre != result {
                print("🧠 Found user correction for \(artist): \(result) → \(correctedGenre)")
                // In a real implementation, we might update the classification in real-time
            }
        }
        
        return result
    }
    
    // Phase 3: Check for user corrections to learn from
    private func checkForUserCorrections(artist: String, completion: @escaping (String?) -> Void) {
        let db = Firestore.firestore()
        db.collection("genreCorrections")
            .whereField("artistName", isEqualTo: artist.lowercased())
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents, !documents.isEmpty {
                    let correctedGenre = documents.first?.data()["correctedGenre"] as? String
                    completion(correctedGenre)
                } else {
                    completion(nil)
                }
            }
    }
    
    // Fallback genre classifier for older logs without AI classification
    private func classifyGenreFallback(title: String, artist: String) -> String {
        let artistLower = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let titleLower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedText = "\(titleLower) \(artistLower)"
        
        // PHASE 1: Comprehensive Artist Database (200+ artists)
        let artistGenreMap: [String: String] = [
            // Hip-Hop Artists (Major Artists)
            "drake": "Hip-Hop", "kendrick lamar": "Hip-Hop", "travis scott": "Hip-Hop", "kanye west": "Hip-Hop",
            "tyler the creator": "Hip-Hop", "asap rocky": "Hip-Hop", "j cole": "Hip-Hop", "future": "Hip-Hop",
            "lil baby": "Hip-Hop", "lil wayne": "Hip-Hop", "eminem": "Hip-Hop", "jay-z": "Hip-Hop",
            "nas": "Hip-Hop", "biggie": "Hip-Hop", "tupac": "Hip-Hop", "snoop dogg": "Hip-Hop",
            "dr dre": "Hip-Hop", "50 cent": "Hip-Hop", "nicki minaj": "Hip-Hop", "cardi b": "Hip-Hop",
            "megan thee stallion": "Hip-Hop", "doja cat": "Hip-Hop", "ice spice": "Hip-Hop", "lil uzi vert": "Hip-Hop",
            "playboi carti": "Hip-Hop", "21 savage": "Hip-Hop", "metro boomin": "Hip-Hop", "gunna": "Hip-Hop",
            "young thug": "Hip-Hop", "roddy ricch": "Hip-Hop", "dababy": "Hip-Hop", "polo g": "Hip-Hop",
            "lil durk": "Hip-Hop", "pop smoke": "Hip-Hop", "juice wrld": "Hip-Hop", "xxxtentacion": "Hip-Hop",
            "ski mask the slump god": "Hip-Hop", "denzel curry": "Hip-Hop", "jid": "Hip-Hop", "earthgang": "Hip-Hop",
            "trippie redd": "Hip-Hop", "lil nas x": "Hip-Hop", "migos": "Hip-Hop", "offset": "Hip-Hop",
            "quavo": "Hip-Hop", "takeoff": "Hip-Hop", "rae sremmurd": "Hip-Hop", "swae lee": "Hip-Hop",
            
            // Pop Artists
            "taylor swift": "Pop", "ariana grande": "Pop", "billie eilish": "Pop", "dua lipa": "Pop",
            "olivia rodrigo": "Pop", "harry styles": "Pop", "ed sheeran": "Pop", "justin bieber": "Pop",
            "selena gomez": "Pop", "miley cyrus": "Pop", "katy perry": "Pop", "lady gaga": "Pop",
            "britney spears": "Pop", "madonna": "Pop", "beyonce": "Pop", "rihanna": "Pop",
            "adele": "Pop", "sam smith": "Pop", "charlie puth": "Pop", "shawn mendes": "Pop",
            "camila cabello": "Pop", "halsey": "Pop", "lorde": "Pop", "troye sivan": "Pop",
            "demi lovato": "Pop", "jonas brothers": "Pop", "maroon 5": "Pop", "onerepublic": "Pop",
            "imagine dragons": "Pop", "coldplay": "Pop", "the chainsmokers": "Pop", "zedd": "Pop",
            "bruno mars": "Pop", "post malone": "Pop", "lizzo": "Pop", "sia": "Pop",
            
            // R&B Artists
            "sza": "R&B", "frank ocean": "R&B", "the weeknd": "R&B", "bryson tiller": "R&B",
            "summer walker": "R&B", "jhene aiko": "R&B", "kehlani": "R&B", "h.e.r.": "R&B",
            "daniel caesar": "R&B", "brent faiyaz": "R&B", "kali uchis": "R&B", "solange": "R&B",
            "alicia keys": "R&B", "usher": "R&B", "chris brown": "R&B", "trey songz": "R&B",
            "miguel": "R&B", "john legend": "R&B", "maxwell": "R&B", "d'angelo": "R&B",
            "erykah badu": "R&B", "lauryn hill": "R&B", "mary j blige": "R&B", "whitney houston": "R&B",
            "mariah carey": "R&B", "janet jackson": "R&B", "prince": "R&B", "stevie wonder": "R&B",
            "anderson .paak": "R&B", "silk sonic": "R&B", "lucky daye": "R&B", "giveon": "R&B",
            
            // Electronic Artists
            "calvin harris": "Electronic", "deadmau5": "Electronic", "skrillex": "Electronic", "diplo": "Electronic",
            "martin garrix": "Electronic", "david guetta": "Electronic", "tiesto": "Electronic", "avicii": "Electronic",
            "swedish house mafia": "Electronic", "disclosure": "Electronic", "flume": "Electronic", "odesza": "Electronic",
            "porter robinson": "Electronic", "madeon": "Electronic", "rezz": "Electronic", "illenium": "Electronic",
            "marshmello": "Electronic", "alan walker": "Electronic", "daft punk": "Electronic", "justice": "Electronic",
            "aphex twin": "Electronic", "boards of canada": "Electronic", "burial": "Electronic", "four tet": "Electronic",
            
            // Rock Artists
            "foo fighters": "Rock", "red hot chili peppers": "Rock", "nirvana": "Rock", "pearl jam": "Rock",
            "soundgarden": "Rock", "alice in chains": "Rock", "stone temple pilots": "Rock", "green day": "Rock", 
            "blink-182": "Rock", "linkin park": "Rock", "system of a down": "Rock", "metallica": "Rock", 
            "iron maiden": "Rock", "black sabbath": "Rock", "led zeppelin": "Rock", "pink floyd": "Rock", 
            "the beatles": "Rock", "queens of the stone age": "Rock", "tool": "Rock", "rage against the machine": "Rock", 
            "audioslave": "Rock",
            
            // Indie Artists (keeping indie classification for these artists)
            "arctic monkeys": "Indie", "the strokes": "Indie", "radiohead": "Indie", "tame impala": "Indie", 
            "mac miller": "Indie", "rex orange county": "Indie", "clairo": "Indie", "boy pablo": "Indie", 
            "cuco": "Indie", "still woozy": "Indie", "the 1975": "Indie", "vampire weekend": "Indie", 
            "foster the people": "Indie", "mgmt": "Indie", "two door cinema club": "Indie", "phoenix": "Indie", 
            "alt-j": "Indie", "glass animals": "Indie", "cage the elephant": "Indie", "interpol": "Indie", 
            "yeah yeah yeahs": "Indie",
            
            // Country Artists
            "kacey musgraves": "Country", "chris stapleton": "Country", "maren morris": "Country",
            "keith urban": "Country", "carrie underwood": "Country", "blake shelton": "Country", "luke bryan": "Country",
            "florida georgia line": "Country", "dan + shay": "Country", "old dominion": "Country", "thomas rhett": "Country",
            "kenny chesney": "Country", "brad paisley": "Country", "tim mcgraw": "Country", "faith hill": "Country",
            
            // K-Pop Artists
            "bts": "K-Pop", "blackpink": "K-Pop", "twice": "K-Pop", "red velvet": "K-Pop",
            "itzy": "K-Pop", "aespa": "K-Pop", "newjeans": "K-Pop", "ive": "K-Pop",
            "stray kids": "K-Pop", "seventeen": "K-Pop", "txt": "K-Pop", "enhypen": "K-Pop",
            "girls generation": "K-Pop", "super junior": "K-Pop", "exo": "K-Pop", "nct": "K-Pop",
            
            // Latin Artists
            "bad bunny": "Latin", "j balvin": "Latin", "ozuna": "Latin", "maluma": "Latin",
            "karol g": "Latin", "daddy yankee": "Latin", "shakira": "Latin", "manu chao": "Latin",
            "rosalia": "Latin", "jesse & joy": "Latin", "mau y ricky": "Latin", "cnco": "Latin",
            
            // Jazz Artists
            "miles davis": "Jazz", "john coltrane": "Jazz", "ella fitzgerald": "Jazz", "billie holiday": "Jazz",
            "louis armstrong": "Jazz", "duke ellington": "Jazz", "charlie parker": "Jazz", "thelonious monk": "Jazz",
            "herbie hancock": "Jazz", "weather report": "Jazz", "chick corea": "Jazz", "pat metheny": "Jazz",
            
            // Alternative Artists (unique entries only)
            "the smiths": "Alternative", "joy division": "Alternative", "new order": "Alternative",
            "the cure": "Alternative", "depeche mode": "Alternative", "pixies": "Alternative", "sonic youth": "Alternative",
            "my bloody valentine": "Alternative", "slowdive": "Alternative", "ride": "Alternative"
        ]
        
        // Check artist database first (most reliable)
        if let genre = artistGenreMap[artistLower] {
            print("🎯 Genre classified by artist database: \(artist) → \(genre)")
            return genre
        }
        
        // Enhanced keyword matching with more comprehensive terms
        let genreKeywords: [String: [String]] = [
            "Hip-Hop": [
                "rap", "hip hop", "hiphop", "trap", "drill", "grime", "gangsta rap",
                "conscious rap", "mumble rap", "boom bap", "freestyle", "cipher",
                "lil ", "young ", "big ", "mc ", "dj ", "producer", "beats"
            ],
            "Pop": [
                "pop", "mainstream", "chart", "radio", "commercial", "dance pop",
                "electropop", "synthpop", "bubblegum", "teen pop", "adult contemporary"
            ],
            "R&B": [
                "r&b", "rnb", "rhythm and blues", "soul", "neo soul", "contemporary r&b",
                "quiet storm", "new jack swing", "urban contemporary", "smooth"
            ],
            "Rock": [
                "rock", "metal", "punk", "grunge", "hardcore", "alternative rock",
                "indie rock", "classic rock", "hard rock", "progressive rock",
                "psychedelic", "garage rock", "post punk", "new wave"
            ],
            "Electronic": [
                "electronic", "edm", "dance", "techno", "house", "trance", "dubstep",
                "drum and bass", "ambient", "synthwave", "electro", "breakbeat",
                "deep house", "progressive house", "big room", "future bass"
            ],
            "Indie": [
                "indie", "independent", "alternative", "lo-fi", "bedroom pop",
                "dream pop", "shoegaze", "post rock", "math rock", "experimental"
            ],
            "Country": [
                "country", "folk", "bluegrass", "americana", "western", "honky tonk",
                "outlaw country", "contemporary country", "country rock", "alt country"
            ],
            "Latin": [
                "latin", "reggaeton", "salsa", "bachata", "merengue", "cumbia",
                "latin pop", "latin rock", "banda", "mariachi", "ranchera"
            ],
            "K-Pop": [
                "k-pop", "kpop", "korean", "korea", "seoul", "hallyu", "idol"
            ],
            "Jazz": [
                "jazz", "swing", "bebop", "cool jazz", "fusion", "smooth jazz",
                "free jazz", "hard bop", "post bop", "contemporary jazz"
            ],
            "Classical": [
                "classical", "orchestra", "symphony", "concerto", "sonata",
                "baroque", "romantic", "modern classical", "chamber music"
            ],
            "Reggae": [
                "reggae", "dub", "ska", "dancehall", "roots reggae", "ragga"
            ],
            "Funk": [
                "funk", "disco", "groove", "p-funk", "funk rock", "electro funk"
            ],
            "Blues": [
                "blues", "delta blues", "chicago blues", "electric blues", "country blues"
            ],
            "Alternative": [
                "alternative", "alt rock", "grunge", "britpop", "post grunge",
                "alternative metal", "nu metal", "emo", "screamo"
            ]
        ]
        
        // Check for genre keywords in combined text
        for (genre, keywords) in genreKeywords {
            for keyword in keywords {
                if combinedText.contains(keyword) {
                    print("🎯 Genre classified by keyword '\(keyword)': \(artist) - \(title) → \(genre)")
                    return genre
                }
            }
        }
        
        // Enhanced artist name pattern matching
        if artistLower.contains("lil ") || artistLower.contains("young ") || 
           artistLower.contains("big ") || artistLower.hasPrefix("mc ") ||
           artistLower.contains("$") || artistLower.contains("21 ") {
            print("🎯 Genre classified by hip-hop pattern: \(artist) → Hip-Hop")
            return "Hip-Hop"
        }
        
        // Check for featuring patterns (often hip-hop)
        if combinedText.contains("feat.") || combinedText.contains("ft.") || combinedText.contains("featuring") {
            print("🎯 Genre classified by featuring pattern: \(artist) - \(title) → Hip-Hop")
            return "Hip-Hop"
        }
        
        // Song title pattern matching
        if titleLower.contains("remix") || titleLower.contains("mix") {
            print("🎯 Genre classified by remix pattern: \(title) → Electronic")
            return "Electronic"
        }
        
        // Default fallback with better distribution
        let fallbackGenres = ["Hip-Hop", "Pop", "R&B", "Rock", "Electronic", "Indie"]
        let hash = abs(artistLower.hashValue)
        let selectedGenre = fallbackGenres[hash % fallbackGenres.count]
        print("🎯 Genre classified by fallback: \(artist) - \(title) → \(selectedGenre)")
        return selectedGenre
    }
    
    // Color scheme for standardized genres (matches AI classification service)
    private func genreColor(for genre: String) -> Color {
        switch genre {
        case "Hip-Hop": return Color.orange
        case "Pop": return Color.pink
        case "R&B": return Color.purple
        case "Electronic": return Color.blue
        case "Rock": return Color.red
        case "Indie": return Color.green
        case "Country": return Color.brown
        case "K-Pop": return Color.mint
        case "Latin": return Color.yellow
        case "Jazz": return Color.indigo
        case "Classical": return Color.gray
        case "Reggae": return Color.teal
        case "Funk": return Color.orange.opacity(0.7)
        case "Blues": return Color.cyan
        case "Alternative": return Color.secondary
        case "Other": return Color.gray.opacity(0.5)
        default: return Color.gray.opacity(0.5)
        }
    }
    
    // Pie chart angle calculations
    private func startAngle(for index: Int, in data: [GenreData]) -> Angle {
        let totalPercentage = data.prefix(index).reduce(0) { $0 + $1.percentage }
        return Angle(degrees: (totalPercentage / 100.0) * 360.0 - 90) // Start from top
    }
    
    private func endAngle(for index: Int, in data: [GenreData]) -> Angle {
        let totalPercentage = data.prefix(index + 1).reduce(0) { $0 + $1.percentage }
        return Angle(degrees: (totalPercentage / 100.0) * 360.0 - 90) // Start from top
    }
    
    // MARK: - Listen Later Tab Implementation
    private var listenLaterTab: some View {
        VStack(spacing: 0) {
            // Custom Tab Selector
            tabSelector
            
            // Swipeable Content
            TabView(selection: $selectedListenLaterSection) {
                ForEach(Array(ListenLaterItemType.allCases.enumerated()), id: \.offset) { index, section in
                    sectionContent(for: section)
                        .tag(section)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedListenLaterSection)
        }
        .overlay(
            // Purple Plus Button
            purplePlusButton,
            alignment: .bottomTrailing
        )
        .onAppear {
            print("🎯 Listen Later tab appeared")
            // Always refresh when tab appears to ensure fresh data
            listenLaterService.refreshAllSections()
        }
    }
    
    // MARK: - Listen Later Components
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ListenLaterItemType.allCases, id: \.self) { section in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedListenLaterSection = section
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.system(size: 16, weight: .medium))
                            Text(section.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedListenLaterSection == section ? .purple : .secondary)
                        
                        // Underline indicator
                        Rectangle()
                            .fill(selectedListenLaterSection == section ? Color.purple : Color.clear)
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.3), value: selectedListenLaterSection)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func sectionContent(for section: ListenLaterItemType) -> some View {
        let items = listenLaterService.getItems(for: section)
        let isLoading = listenLaterService.isLoading(for: section)
        
        print("🎯 Section \(section.displayName): \(items.count) items, loading: \(isLoading)")
        
        return Group {
            if isLoading {
                listenLaterLoadingView
            } else if items.isEmpty {
                emptyStateView(for: section)
            } else {
                itemsList(items: items, section: section)
            }
        }
        .refreshable {
            print("🔄 Pull to refresh Listen Later")
            listenLaterService.refreshAllSections()
        }
        .onAppear {
            print("🎯 Section \(section.displayName) appeared with \(items.count) items")
        }
    }
    
    private func itemsList(items: [ListenLaterItem], section: ListenLaterItemType) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    ListenLaterItemRowView(
                        item: item,
                        onTap: {
                            navigateToProfile(item: item)
                        },
                        onRemove: {
                            Task {
                                await listenLaterService.removeItem(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
    
    private var listenLaterLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func emptyStateView(for section: ListenLaterItemType) -> some View {
        VStack(spacing: 24) {
            Image(systemName: section.icon)
                .font(.system(size: 60))
                .foregroundColor(section.color.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No \(section.displayName) Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Add \(section.displayName.lowercased()) you want to listen to later")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showAddToListenLaterSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add \(section.displayName)")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(section.color)
                    .clipShape(Capsule())
                    .shadow(color: section.color.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // Debug button - temporary
                Button(action: {
                    print("🔧 Debug: Force refresh Listen Later")
                    listenLaterService.refreshAllSections()
                }) {
                    Text("🔄 Refresh")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var purplePlusButton: some View {
        Button(action: {
            showAddToListenLaterSheet = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100) // Account for tab bar
    }
    
    private func navigateToProfile(item: ListenLaterItem) {
        switch item.itemType {
        case .song, .album:
            let trendingItem = TrendingItem(
                title: item.title,
                subtitle: item.artistName,
                artworkUrl: item.artworkUrl,
                logCount: item.totalRatings,
                averageRating: item.averageRating,
                itemType: item.itemType.rawValue,
                itemId: item.itemId
            )
            selectedMusicItem = MusicSearchResult(
                id: item.itemId,
                title: item.title,
                artistName: item.artistName,
                albumName: item.albumName ?? "",
                artworkURL: item.artworkUrl,
                itemType: item.itemType.rawValue,
                popularity: 0
            )
        case .artist:
            selectedArtistName = item.artistName
            showArtistProfile = true
        }
    }
    
    private var floatingAddButton: some View {
        Button(action: {
            showAddToListenLaterSheet = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.purple)
                .clipShape(Circle())
                .shadow(radius: 8)
        }
    }
    
    // MARK: - Social Score Section
    
    private func socialScoreSection(socialScore: Double, totalRatings: Int, badges: [String]) -> some View {
        VStack(spacing: 12) {
            // Main Score Display
            HStack(spacing: 16) {
                // Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: socialScore / 10.0)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", socialScore))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("/10")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Score Details
                VStack(alignment: .leading, spacing: 4) {
                    Text("Social Score")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(totalRatings) rating\(totalRatings == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    // Score Quality Indicator
                    HStack(spacing: 4) {
                        Image(systemName: scoreQualityIcon(socialScore))
                            .font(.system(size: 12))
                            .foregroundColor(scoreQualityColor(socialScore))
                        
                        Text(scoreQualityText(socialScore))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(scoreQualityColor(socialScore))
                    }
                }
                
                Spacer()
            }
            
            // Recent Badges (if any)
            if !badges.isEmpty {
                HStack(spacing: 8) {
                    Text("Recent Badges:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        ForEach(Array(badges.prefix(3)), id: \.self) { badgeId in
                            if let badge = SocialScore.SocialBadge.availableBadges.first(where: { $0.id == badgeId }) {
                                Image(systemName: badge.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        if badges.count > 3 {
                            Text("+\(badges.count - 3)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // View My Ratings Button (only for current user)
            if isCurrentUser {
                NavigationLink(destination: MyRatingsView()) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.star")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("View My Ratings")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Social Score Helper Functions
    
    private func scoreQualityIcon(_ score: Double) -> String {
        switch score {
        case 8.5...10.0: return "star.fill"
        case 7.0..<8.5: return "star.circle.fill"
        case 5.0..<7.0: return "star.circle"
        default: return "star"
        }
    }
    
    private func scoreQualityColor(_ score: Double) -> Color {
        switch score {
        case 8.5...10.0: return .orange
        case 7.0..<8.5: return .blue
        case 5.0..<7.0: return .yellow
        default: return .gray
        }
    }
    
    private func scoreQualityText(_ score: Double) -> String {
        switch score {
        case 8.5...10.0: return "Excellent"
        case 7.0..<8.5: return "Great"
        case 5.0..<7.0: return "Good"
        default: return "Building"
        }
    }
}

// MARK: - Stat Detail List View
struct StatDetailListView: View {
    let category: StatCategory
    let logs: [MusicLog]
    let userLists: [MusicList]
    let listCoverImages: [String: URL]
    let userReposts: [Repost]
    let repostedLogs: [MusicLog]
    let profile: UserProfile?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMusicItem: MusicSearchResult? = nil
    @State private var selectedPinnedLog: MusicLog? = nil
    @State private var selectedList: MusicList? = nil
    @State private var selectedArtistName: String? = nil
    @State private var showArtistProfile = false
    @State private var selectedArtistForLogs: String? = nil
    @State private var showArtistLogs = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Use log cards for logs, songs, albums, and reposts
                    if category == .logs || category == .songs || category == .albums || category == .reposts {
                        ForEach(logsToDisplay, id: \.id) { log in
                            PopularLogRow(log: log, reposterNames: nil)
                                .padding(.horizontal, 16)
                        }
                    } else {
                        // Use old format for artists and lists
                        ForEach(filteredItems, id: \.id) { item in
                            if category == .artists {
                                StatDetailCard(
                                    item: item,
                                    category: category,
                                    onArtistNameTap: {
                                        selectedArtistName = item.title
                                        showArtistProfile = true
                                    },
                                    onArtistPFPTap: {
                                        selectedArtistName = item.title
                                        showArtistProfile = true
                                    },
                                    onCardTap: {
                                        selectedArtistForLogs = item.title
                                        showArtistLogs = true
                                    }
                                )
                            } else if category == .lists {
                                StatDetailCard(
                                    item: item,
                                    category: category,
                                    listCoverImages: listCoverImages,
                                    onCardTap: {
                                        handleCardTap(item: item)
                                    }
                                )
                            } else {
                                StatDetailCard(
                                    item: item,
                                    category: category,
                                    listCoverImages: listCoverImages,
                                    onCardTap: {
                                        handleCardTap(item: item)
                                    }
                                )
                                }
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.large)
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
        .fullScreenCover(item: $selectedMusicItem) { musicItem in
            MusicProfileView(musicItem: musicItem, pinnedLog: selectedPinnedLog)
        }
        .fullScreenCover(item: $selectedList) { list in
            ListDetailView(list: list)
        }
        .fullScreenCover(isPresented: $showArtistProfile) {
            if let artistName = selectedArtistName {
                ArtistProfileView(artistName: artistName)
                    .environmentObject(NavigationCoordinator())
            }
        }
        .sheet(isPresented: $showArtistLogs) {
            if let artistName = selectedArtistForLogs {
                ArtistLogListView(
                    artistName: artistName,
                    logs: logs.filter { logContainsArtist($0, artistName: artistName) }
                )
            }
        }
    }
    
    // Get the logs to display based on category
    private var logsToDisplay: [MusicLog] {
        switch category {
        case .logs:
            return logs.sorted { $0.dateLogged > $1.dateLogged }
        case .songs:
            // Group by song ID and take the most recent log for each
            let grouped = Dictionary(grouping: logs.filter { $0.itemType == "song" }) { $0.itemId }
            return grouped.compactMap { $0.value.max(by: { $0.dateLogged < $1.dateLogged }) }
                .sorted { $0.dateLogged > $1.dateLogged }
        case .albums:
            // Group by album ID and take the most recent log for each
            let grouped = Dictionary(grouping: logs.filter { $0.itemType == "album" }) { $0.itemId }
            return grouped.compactMap { $0.value.max(by: { $0.dateLogged < $1.dateLogged }) }
                .sorted { $0.dateLogged > $1.dateLogged }
        case .reposts:
            return repostedLogs
        default:
            return []
        }
    }
    
    // Handle card tap based on category
    private func handleCardTap(item: StatDetailItem) {
        switch category {
        case .lists:
            // For lists, find and show the list detail
            if let list = userLists.first(where: { $0.id == item.id }) {
                selectedList = list
            }
        default:
            // For logs, songs, albums, artists, reposts - navigate to music profile with highlighted log
            if let log = logs.first(where: { $0.id == item.id || $0.itemId == item.id }) {
                // Found a matching log by ID or itemId
                selectedPinnedLog = log
            } else {
                // For aggregated items (songs, albums, artists), find any log with matching itemId or artist name
                if let log = logs.first(where: { 
                    $0.itemId == item.id || logContainsArtist($0, artistName: item.title)
                }) {
                    selectedPinnedLog = log
                } else {
                    selectedPinnedLog = nil
                }
            }
            
            selectedMusicItem = MusicSearchResult(
                id: item.id,
                title: item.title,
                artistName: item.subtitle,
                albumName: item.itemType == "album" ? item.title : "",
                artworkURL: item.artworkUrl,
                itemType: item.itemType,
                popularity: 0
            )
        }
    }
    
    // Filter items based on category
    private var filteredItems: [StatDetailItem] {
        switch category {
        case .logs:
            return logs.map { log in
                StatDetailItem(
                    id: log.id,
                    title: log.title,
                    subtitle: log.artistName,
                    artworkUrl: log.artworkUrl,
                    itemType: log.itemType,
                    rating: log.rating,
                    dateLogged: log.dateLogged,
                    hasReview: log.review != nil && !(log.review?.isEmpty ?? true)
                )
            }
        case .songs:
            let uniqueSongs = Dictionary(grouping: logs.filter { $0.itemType == "song" }) { $0.itemId }
            return uniqueSongs.compactMap { (_, logs) in
                guard let firstLog = logs.first else { return nil }
                return StatDetailItem(
                    id: firstLog.itemId,
                    title: firstLog.title,
                    subtitle: firstLog.artistName,
                    artworkUrl: firstLog.artworkUrl,
                    itemType: "song",
                    rating: logs.compactMap { $0.rating }.first,
                    dateLogged: logs.map { $0.dateLogged }.max() ?? firstLog.dateLogged,
                    hasReview: logs.contains { $0.review != nil && !($0.review?.isEmpty ?? true) }
                )
            }.sorted { $0.dateLogged > $1.dateLogged }
        case .artists:
            var artistLogs: [String: [MusicLog]] = [:]
            var displayNames: [String: String] = [:]
            
            for log in logs {
                let artists = artistNamesForLog(log)
                for artist in artists {
                    let key = ArtistNameParser.normalizedKey(artist)
                    guard !key.isEmpty else { continue }
                    artistLogs[key, default: []].append(log)
                    if displayNames[key] == nil {
                        displayNames[key] = artist
                    }
                }
            }
            
            let artistItemsWithCounts: [(item: StatDetailItem, count: Int)] = artistLogs.compactMap { key, artistLogs in
                let displayName = displayNames[key] ?? key
                let sortedLogs = artistLogs.sorted { $0.dateLogged > $1.dateLogged }
                let mostRecentRating = sortedLogs.first(where: { $0.rating != nil })?.rating
                let mostRecentDate = artistLogs.map { $0.dateLogged }.max() ?? Date()
                let logCount = artistLogs.count
                let subtitle = logCount == 1 ? "1 log" : "\(logCount) logs"
                let hasReview = artistLogs.contains { $0.review != nil && !($0.review?.isEmpty ?? true) }
                
                let item = StatDetailItem(
                    id: key,
                    title: displayName,
                    subtitle: subtitle,
                    artworkUrl: nil,
                    itemType: "artist",
                    rating: mostRecentRating,
                    dateLogged: mostRecentDate,
                    hasReview: hasReview
                )
                
                return (item, logCount)
            }
            
            return artistItemsWithCounts
                .sorted { lhs, rhs in
                    if lhs.count != rhs.count {
                        return lhs.count > rhs.count
                    }
                    return lhs.item.title.localizedCaseInsensitiveCompare(rhs.item.title) == .orderedAscending
                }
                .map { $0.item }
        case .albums:
            let uniqueAlbums = Dictionary(grouping: logs.filter { $0.itemType == "album" }) { $0.itemId }
            return uniqueAlbums.compactMap { (_, logs) in
                guard let firstLog = logs.first else { return nil }
                return StatDetailItem(
                    id: firstLog.itemId,
                    title: firstLog.title,
                    subtitle: firstLog.artistName,
                    artworkUrl: firstLog.artworkUrl,
                    itemType: "album",
                    rating: logs.compactMap { $0.rating }.first,
                    dateLogged: logs.map { $0.dateLogged }.max() ?? firstLog.dateLogged,
                    hasReview: logs.contains { $0.review != nil && !($0.review?.isEmpty ?? true) }
                )
            }.sorted { $0.dateLogged > $1.dateLogged }
        case .reposts:
            // Use the repostedLogs array which contains the full log objects
            return repostedLogs.enumerated().compactMap { (index, log) in
                let repost = index < userReposts.count ? userReposts[index] : nil
                return StatDetailItem(
                    id: log.id,
                    title: log.title,
                    subtitle: log.artistName,
                    artworkUrl: log.artworkUrl,
                    itemType: log.itemType,
                    rating: log.rating,
                    dateLogged: repost?.createdAt ?? log.dateLogged,
                    hasReview: log.review != nil && !(log.review?.isEmpty ?? true)
                )
            }
        case .lists:
            return userLists.map { list in
                StatDetailItem(
                    id: list.id,
                    title: list.title,
                    subtitle: "\(list.items.count) songs",
                    artworkUrl: nil, // MusicList doesn't store artwork URLs directly
                    itemType: "list",
                    rating: nil,
                    dateLogged: list.createdAt,
                    hasReview: false
                )
            }.sorted { $0.dateLogged > $1.dateLogged }
        }
    }
}

// MARK: - Stat Detail Item Model
struct StatDetailItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let artworkUrl: String?
    let itemType: String
    let rating: Double?
    let dateLogged: Date
    let hasReview: Bool
}

// MARK: - Stat Detail Card
struct StatDetailCard: View {
    let item: StatDetailItem
    let category: StatCategory
    var listCoverImages: [String: URL] = [:]
    var onArtistNameTap: (() -> Void)? = nil
    var onArtistPFPTap: (() -> Void)? = nil
    var onCardTap: (() -> Void)? = nil
    @State private var resolvedArtworkURL: String? = nil
    @State private var isFetchingArtistArtwork = false
    
    var body: some View {
        let artworkURLToUse = resolvedArtworkURL ?? item.artworkUrl
                            HStack(spacing: 16) {
            // Artwork - clickable for artists
            Group {
                if category == .lists,
                   let coverURL = listCoverImages[item.id] {
                    CachedAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        artworkPlaceholder
                    }
                } else if let artworkUrl = artworkURLToUse,
                          let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        artworkPlaceholder
                    }
                } else {
                    artworkPlaceholder
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(item.itemType == "artist" ? 30 : 8)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .onTapGesture {
                if item.itemType == "artist" {
                    onArtistPFPTap?()
                }
            }
                                
                                // Content
            VStack(alignment: .leading, spacing: 6) {
                // Artist name - purple and clickable for artists
                if item.itemType == "artist" {
                    Button(action: {
                        onArtistNameTap?()
                    }) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.purple)
                            .lineLimit(1)
                    }
                } else {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                }
                
                // Subtitle with rating - tappable for artists (card body)
                HStack(spacing: 6) {
                Text(item.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .default))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                
                    // Rating with stars if available
                    if let rating = item.rating {
                        StarRatingDisplayView(
                            rating: rating,
                            starSize: 10,
                            spacing: 1
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if item.itemType == "artist" {
                        onCardTap?()
                    }
                }
                
                HStack(spacing: 8) {
                    // Review indicator
                    if item.hasReview {
                        HStack(spacing: 2) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 10, weight: .medium))
                            Text("Review")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                Spacer()
                    
                    // Date
                    Text(RelativeTimeFormatter.shared.string(for: item.dateLogged))
                        .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if item.itemType == "artist" {
                        onCardTap?()
                    }
                }
            }
            
            Spacer()
            
            // Navigation arrow - tappable for artists (card body)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                .contentShape(Rectangle())
                .onTapGesture {
                    if item.itemType == "artist" {
                        onCardTap?()
                    }
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray6), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // For non-artists, trigger card tap
            // For artists, this will only fire if name/PFP/subtitle/date/chevron don't consume the tap
            if item.itemType != "artist" {
                onCardTap?()
            }
        }
        .onAppear {
            if resolvedArtworkURL == nil {
                resolvedArtworkURL = item.artworkUrl
            }
        }
        .task {
            await fetchArtistArtworkIfNeeded()
        }
    }
    
    // Artwork placeholder
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: item.itemType == "artist" ? 30 : 8)
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: iconForItemType(item.itemType))
                    .font(.system(size: 20))
                    .foregroundColor(.gray.opacity(0.6))
            )
    }
    
    // Helper function for item type icons
    private func iconForItemType(_ itemType: String) -> String {
        switch itemType {
        case "song": return "music.note"
        case "artist": return "person.wave.2"
        case "album": return "opticaldisc"
        case "list": return "list.bullet.rectangle"
        default: return "music.note"
        }
    }
    
    private func fetchArtistArtworkIfNeeded() async {
        guard item.itemType == "artist" else { return }
        
        if let cached = await ArtistArtworkURLCache.shared.url(for: item.title) {
            await MainActor.run {
                resolvedArtworkURL = cached
            }
            return
        }
        
        if isFetchingArtistArtwork {
            return
        }
        
        await MainActor.run {
            isFetchingArtistArtwork = true
        }
        
        do {
            var request = MusicCatalogSearchRequest(term: item.title, types: [MusicKit.Artist.self])
            request.limit = 5
            let response = try await request.response()
            let matchedArtist = response.artists.first { artist in
                artist.name.caseInsensitiveCompare(item.title) == .orderedSame
            } ?? response.artists.first
            
            if let artworkURL = matchedArtist?.artwork?.url(width: 400, height: 400)?.absoluteString {
                await ArtistArtworkURLCache.shared.store(url: artworkURL, for: item.title)
                await MainActor.run {
                    resolvedArtworkURL = artworkURL
                }
            }
        } catch {
            print("❌ Failed to fetch artist artwork for \(item.title): \(error.localizedDescription)")
        }
        
        await MainActor.run {
            isFetchingArtistArtwork = false
        }
    }
    
}

// Cache artist artwork URLs to prevent repeated MusicKit lookups
actor ArtistArtworkURLCache {
    static let shared = ArtistArtworkURLCache()
    private var cache: [String: String] = [:]
    
    func url(for artistName: String) -> String? {
        cache[artistName.lowercased()]
    }
    
    func store(url: String, for artistName: String) {
        cache[artistName.lowercased()] = url
    }
}

// MARK: - Artist Helper Functions

private func artistNamesForLog(_ log: MusicLog) -> [String] {
    let parsed = ArtistNameParser.splitArtists(from: log.artistName)
    if parsed.isEmpty {
        let trimmed = log.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
    }
    return parsed
}

private func logContainsArtist(_ log: MusicLog, artistName: String) -> Bool {
    let targetKey = ArtistNameParser.normalizedKey(artistName)
    guard !targetKey.isEmpty else { return false }
    return artistNamesForLog(log).contains { ArtistNameParser.normalizedKey($0) == targetKey }
}

// MARK: - Listen Later Item Row View
struct ListenLaterItemRowView: View {
    let item: ListenLaterItem
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var showRemoveConfirmation = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 16) {
                // Artwork with enhanced styling
                AsyncImage(url: URL(string: item.artworkUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [item.itemType.color.opacity(0.4), item.itemType.color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: item.itemType.icon)
                                .font(.title2)
                                .foregroundColor(item.itemType.color)
                        )
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: item.itemType.color.opacity(0.2), radius: 3, x: 0, y: 2)
                
                // Content with improved typography
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if item.itemType != .artist {
                        Text(item.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Enhanced rating display
                    HStack(spacing: 8) {
                        if let averageRating = item.averageRating, averageRating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", averageRating))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.1))
                            .clipShape(Capsule())
                            
                            Text("(\(item.totalRatings) ratings)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No ratings yet")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Remove button with better styling
                Button(action: {
                    showRemoveConfirmation = true
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: isPressed ? 1 : 4, x: 0, y: isPressed ? 1 : 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .confirmationDialog(
            "Remove from Listen Later",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onRemove()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove \"\(item.title)\" from your Listen Later list?")
        }
    }
}
// MARK: - Pinned Music Card With Press State

struct PinnedMusicCardView: View {
    let item: PinnedItem
    let index: Int
    let type: PinnedType
    let showRanking: Bool
    let onTap: () -> Void
    let onArtistTap: (String) -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Artwork
            ZStack(alignment: .topTrailing) {
                Button(action: onTap) {
                    Group {
                        if let artworkUrl = item.artworkUrl, let url = URL(string: artworkUrl) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                pinnedPlaceholder
                            }
                        } else {
                            pinnedPlaceholder
                        }
                    }
                    .frame(width: 120, height: 120)
                    .cornerRadius(type == .artist ? 60 : 12)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: type == .artist ? 60 : 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if showRanking {
                    rankingBadge
                }
            }
            
            // Title
            VStack(alignment: .leading, spacing: 4) {
                Button(action: onTap) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(width: 120, alignment: .leading)
                }
                .buttonStyle(.plain)
                
                // Artist name (for songs and albums)
                if type != .artist && !item.artistName.isEmpty {
                    Button(action: { onArtistTap(item.artistName) }) {
                        Text(item.artistName)
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .frame(width: 120, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 120, alignment: .leading)
        }
        .frame(width: 120, height: type == .artist ? 160 : 180)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray6), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var pinnedPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: type == .artist ? "person.fill" : "music.note")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var rankingBadge: some View {
        Text("#\(index)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.purple.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
            .offset(x: -8, y: 8)
    }
}

// MARK: - Stats Card With Press State

struct StatsCardView: View {
    let stat: UserProfileView.UserStat
    let onTap: () -> Void
    let formatNumber: (Int) -> String
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [stat.color.opacity(0.15), stat.color.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: stat.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(stat.color)
                }
                
                // Number and label
                VStack(spacing: 4) {
                    Text(formatNumber(stat.count))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text(stat.label)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(stat.color.opacity(0.1), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Genre Legend Row With Press State

struct GenreLegendRow: View {
    let genre: UserProfileView.GenreData
    let onTap: () -> Void
    let genreColor: (String) -> Color
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                Circle()
                    .fill(genreColor(genre.name))
                    .frame(width: 12, height: 12)
                    .shadow(color: genreColor(genre.name).opacity(0.3), radius: 2, x: 0, y: 1)
                
                // Genre name
                Text(genre.name.capitalized)
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Percentage and count
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(genre.percentage))%")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("\(genre.count) logs")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                }
                
                // Subtle chevron to indicate it's clickable
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(genreColor(genre.name).opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Artist Log List View
struct ArtistLogListView: View {
    let artistName: String
    let logs: [MusicLog]
    @Environment(\.dismiss) private var dismiss
    
    private var sortedLogs: [MusicLog] {
        logs.sorted { $0.dateLogged > $1.dateLogged }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sortedLogs, id: \.id) { log in
                        PopularLogRow(log: log, reposterNames: nil)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle(artistName)
            .navigationBarTitleDisplayMode(.large)
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
    }
}

