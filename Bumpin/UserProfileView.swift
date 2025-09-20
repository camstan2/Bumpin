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
    let id = UUID()
    let genre: String
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

struct UserProfileView: View {
    let userId: String?
    @State private var profile: UserProfile?
    @State private var logs: [MusicLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLog: MusicLog?
    @State private var selectedTab: ProfileTab = .diary
    @State private var logToEdit: MusicLog?
    @State private var showingLogMusicView = false
    @State private var userLists: [MusicList] = []
    @State private var isLoadingLists = false
    @State private var showCreateListSheet = false
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
    @State private var showEditPinnedLists = false
    @State private var showReorderPinnedLists = false
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
    @State private var showRankingForLists = true
    
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
    
    // Reposts state
    @State private var userReposts: [Repost] = []
    @State private var isLoadingReposts = false

    // Removed duplicate View extension that caused invalid redeclaration at file scope.
    
    @StateObject var viewModel: UserProfileViewModel = UserProfileViewModel()
    @EnvironmentObject var nowPlayingManager: NowPlayingManager
    @Namespace private var pinnedBadgeNS
    
    enum ProfileTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case diary = "Diary"
        case lists = "Lists"
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
                    self.fetchProfileAndLogs()
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
                    self.fetchProfileAndLogs()
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
                    self.fetchProfileAndLogs()
                }
            }
        }
    }
    
    private func updatePinnedLists(_ updatedItems: [PinnedItem]) {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "pinnedLists": updatedItems.map { item in
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
                print("❌ Error updating pinned lists: \(error.localizedDescription)")
            } else {
                print("✅ Successfully updated pinned lists")
                DispatchQueue.main.async {
                    self.fetchProfileAndLogs()
                }
            }
        }
    }
    
    // MARK: - Fetch User Reposts
    private func fetchUserReposts() {
        guard let userId = userId ?? Auth.auth().currentUser?.uid else { return }
        
        isLoadingReposts = true
        
        let db = Firestore.firestore()
        
        // Query both item reposts and log reposts
        let itemRepostsQuery = db.collectionGroup("reposts")
            .whereField("userId", isEqualTo: userId)
        
        itemRepostsQuery.getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoadingReposts = false
                
                if let error = error {
                    print("❌ Error fetching user reposts: \(error)")
                    return
                }
                
                let reposts = snapshot?.documents.compactMap { try? $0.data(as: Repost.self) } ?? []
                self.userReposts = reposts.sorted { $0.createdAt > $1.createdAt }
                print("✅ Fetched \(reposts.count) reposts for user")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Move buttons up to align with existing blue "More" button
                HStack {
                    Spacer()
                    
                    // Settings button in top right
                    if isCurrentUser {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                if isCurrentUser {
                    // Tabs for current user - moved up to use extra space
                    Picker("Section", selection: $selectedTab) {
                        ForEach(ProfileTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Tab Content
                    Group {
                        switch selectedTab {
                        case .overview:
                            overviewTab
                        case .diary:
                            diaryTab
                                .onAppear {
                                    // Refresh logs when diary tab is viewed
                                    if logs.isEmpty {
                                        fetchProfileAndLogs()
                                    }
                                }
                        case .lists:
                            listsTab
                        case .listenLater:
                            listenLaterTab
                        }
                    }
                } else {
                    // Only show overview for other users, no tab bar
                    overviewTab
                }
                Spacer()
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchProfileAndLogs()
                fetchUserReposts()
                // Initialize Listen Later service early
                listenLaterService.loadAllSections()
                
                // Listen for Listen Later updates
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ListenLaterItemAdded"),
                    object: nil,
                    queue: .main
                ) { _ in
                    print("🔔 Received Listen Later item added notification")
                    listenLaterService.refreshAllSections()
                }
            }
            .sheet(item: $selectedLog, onDismiss: { selectedLog = nil }) { log in
                LogDetailView(log: log, onEdit: {
                    if isCurrentUser {
                        logToEdit = log
                    }
                })
            }
            .sheet(item: $selectedConversation, onDismiss: { selectedConversation = nil }) { convo in
                ConversationView(conversation: convo, onDismiss: {
                    selectedConversation = nil
                })
            }
                .sheet(item: $logToEdit) { log in
            EditLogView(log: log) {
                            // Refresh logs after editing
                            fetchProfileAndLogs()
                        }
                }
        .sheet(isPresented: $showGenreCorrection, onDismiss: { logToCorrectGenre = nil }) {
            if let log = logToCorrectGenre {
                GenreCorrectionView(log: log) {
                    // Refresh logs after genre correction
                    fetchProfileAndLogs()
                }
            }
        }
        .sheet(item: Binding<GenreDetailItem?>(
            get: { selectedGenreForDetail.map { GenreDetailItem(genre: $0) } },
            set: { selectedGenreForDetail = $0?.genre }
        )) { item in
            GenreDetailView(genre: item.genre, userLogs: logs)
            }
            .fullScreenCover(isPresented: $showingLogMusicView, onDismiss: { showingLogMusicView = false }) {
                DiaryMainSearchView()
                    .onDisappear {
                        // Refresh logs after adding new log
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            fetchProfileAndLogs()
                        }
                    }
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
            .sheet(isPresented: $showCreateListSheet) {
                CreateListView(onListCreated: {
                    fetchLists()
                })
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
        .sheet(isPresented: $showDiaryLogDetail) {
            if let log = selectedDiaryLogDetail {
                NavigationView { EnhancedReviewView(log: log, showFullDetails: true).padding() }
            }
        }
        .sheet(item: $selectedStatCategory) { category in
            StatDetailListView(
                category: category,
                logs: logs,
                userLists: userLists,
                userReposts: userReposts,
                profile: profile
            )
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(userProfileVM: viewModel)
                .environmentObject(nowPlayingManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAddToListenLaterSheet) {
            AddToListenLaterView(
                selectedSection: selectedListenLaterSection,
                listenLaterService: ListenLaterService.shared
            )
        }
        .sheet(isPresented: $showEditPinnedSongs) {
            EditPinnedItemsView(
                title: "Edit Pinned Songs",
                currentItems: profile?.pinnedSongs ?? [],
                itemType: .song,
                onSave: { updatedItems in
                    updatePinnedSongs(updatedItems)
                }
            )
        }
        .sheet(isPresented: $showEditPinnedArtists) {
            EditPinnedItemsView(
                title: "Edit Pinned Artists",
                currentItems: profile?.pinnedArtists ?? [],
                itemType: .artist,
                onSave: { updatedItems in
                    updatePinnedArtists(updatedItems)
                }
            )
        }
        .sheet(isPresented: $showEditPinnedAlbums) {
            EditPinnedItemsView(
                title: "Edit Pinned Albums",
                currentItems: profile?.pinnedAlbums ?? [],
                itemType: .album,
                onSave: { updatedItems in
                    updatePinnedAlbums(updatedItems)
                }
            )
        }
        .sheet(isPresented: $showEditPinnedLists) {
            EditPinnedListsView(
                title: "Edit Pinned Lists",
                currentLists: (profile?.pinnedLists ?? []).map { item in
                    PinnedList(
                        id: item.id,
                        name: item.title,
                        description: nil,
                        coverImageUrl: item.artworkURL
                    )
                },
                onSave: { updatedLists in
                    let updatedItems = updatedLists.map { list in
                        PinnedItem(
                            id: list.id,
                            title: list.name,
                            artistName: "",
                            albumName: nil,
                            artworkURL: list.coverImageUrl,
                            itemType: "list"
                        )
                    }
                    updatePinnedLists(updatedItems)
                }
            )
        }


    }

    private struct DiaryLogCard: View {
        let log: MusicLog
        let onTap: () -> Void
        let onEdit: (() -> Void)?
        let onDelete: (() -> Void)?
        let onCorrectGenre: (() -> Void)?
        let isCurrentUser: Bool
        @State private var userProfile: UserProfile? = nil
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    // Album artwork
                    Group {
                        if let artwork = log.artworkUrl, let url = URL(string: artwork) {
                            CachedAsyncImage(url: url) { image in 
                                image.resizable().scaledToFill() 
                            } placeholder: { 
                                Color.gray.opacity(0.3) 
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 64, height: 64)
                    .cornerRadius(10)
                    
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
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { s in
                                        Image(systemName: s <= rating ? "star.fill" : "star")
                                            .foregroundColor(s <= rating ? .yellow : .gray)
                                            .font(.caption2)
                                    }
                                }
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
                    Text(review)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .padding(.horizontal, 2)
                }
                
                // Engagement bar (simplified)
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsdown")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
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
            .onAppear {
                if userProfile == nil {
                    Task { await fetchUser() }
                }
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
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundColor(star <= rating ? .yellow : .gray)
                            }
                        }
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
        ZStack(alignment: .bottomTrailing) {
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
                }
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).padding()
                }
                if logs.isEmpty && !isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No music logs yet.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if isCurrentUser {
                            Button("Log Your First Song") {
                                showingLogMusicView = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                            ScrollView {
                        if diaryViewFormat == .list {
                            LazyVStack(spacing: 12) {
                                ForEach(sortedAndFilteredLogs) { log in
                                                                        DiaryLogCard(
                                        log: log, 
                                        onTap: {
                                        navigateToMusicProfile(log: log)
                                        },
                                        onEdit: isCurrentUser ? {
                                            logToEdit = log
                                        } : nil,
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
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                                ForEach(sortedAndFilteredLogs) { log in
                                                                        DiaryGridCard(
                                        log: log, 
                                        onTap: {
                                        navigateToMusicProfile(log: log)
                                        },
                                        onEdit: isCurrentUser ? {
                                            logToEdit = log
                                        } : nil,
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
                    }
                    .refreshable { fetchProfileAndLogs() }
                }
            }
            
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
    }

    // Sorted and filtered logs
    // Sorted logs (genre filtering removed)
    private var sortedAndFilteredLogs: [MusicLog] {
        return logs.sorted { log1, log2 in
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
                // For now, use rating as proxy for popularity
                // In the future, this could use actual engagement metrics
                let rating1 = log1.rating ?? 0
                let rating2 = log2.rating ?? 0
                if rating1 == rating2 {
                    return log1.dateLogged > log2.dateLogged
                }
                return rating1 > rating2
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
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No lists yet.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if isCurrentUser {
                            Button("Create Your First List") {
                                showCreateListSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(userLists) { list in
                                Button(action: { selectedList = list }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .center, spacing: 12) {
                                            ZStack {
                                                if let url = list.coverImageUrl.flatMap(URL.init(string:)) {
                                                    CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color(.systemGray6) }
                                                        .frame(width: 56, height: 56)
                                                        .cornerRadius(12)
                                                } else {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color(.systemGray6))
                                                        .frame(width: 56, height: 56)
                                                    Image(systemName: "music.note.list")
                                                        .font(.system(size: 28))
                                                        .foregroundColor(.purple)
                                                }
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(list.title)
                                                        .font(.headline)
                                                        .foregroundColor(.primary)
                                                    if let desc = list.description, !desc.isEmpty {
                                                        Text(desc)
                                                            .font(.subheadline)
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                    Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    }
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
                                        if !list.items.isEmpty {
                                            HStack(spacing: 8) {
                                                ForEach(list.items.prefix(3), id: \.self) { item in
                                                    ZStack {
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(Color(.systemGray5))
                                                            .frame(width: 32, height: 32)
                                                        Text(item.prefix(2))
                                                            .font(.caption2)
                                                            .foregroundColor(.purple)
                                                    }
                                                }
                                                if list.items.count > 3 {
                                                    Text("+")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(.systemBackground))
                                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
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
        .sheet(item: $selectedList) { list in
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
        .sheet(isPresented: $showEditListSheet) {
            if let list = listToEdit {
                EditListView(list: list, onListUpdated: {
                    fetchLists()
                })
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
                } else {
                    print("[DEBUG] No lists fetched or error: \(error?.localizedDescription ?? "none")")
                    userLists = []
                }
            }
        }
    }
    
    private func fetchProfileAndLogs() {
        let uid = userId ?? Auth.auth().currentUser?.uid
        guard let uid else {
            errorMessage = "You must be logged in to view this profile."
            return
        }
        isLoading = true
        errorMessage = nil
        // Fetch profile
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
                    
                    if let profile = try? Firestore.Decoder().decode(UserProfile.self, from: data) {
                        print("🎵 PINNED_ITEMS: ✅ Profile fetched successfully - pinnedSongs count: \(profile.pinnedSongs?.count ?? 0)")
                        self.profile = profile
                    } else {
                        print("🎵 PINNED_ITEMS: ❌ Failed to decode profile - trying manual decode")
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
            }
            // Fetch logs
            MusicLog.fetchLogsForUser(userId: uid) { logs, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        // Don't show Firestore index errors in UI - they should be handled in Firebase console
                        if !error.localizedDescription.contains("index") && !error.localizedDescription.contains("create_composite") {
                            self.errorMessage = error.localizedDescription
                        } else {
                            print("⚠️ Firestore index needed: \(error.localizedDescription)")
                        }
                    } else {
                        self.logs = logs ?? []
                    }
                    // Fetch lists after logs
                    fetchLists()
                }
            }
        }
    }
    


    private var overviewTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: - Profile Header Section
                profileHeaderSection
                
                // MARK: - Recent Diary Section
                recentDiarySection
                
                // MARK: - Pinned Songs Section
                pinnedSongsSection
                
                // MARK: - Pinned Artists Section
                pinnedArtistsSection
                
                // MARK: - Pinned Albums Section
                pinnedAlbumsSection
                
                // MARK: - Pinned Lists Section
                pinnedListsSection
                
                // MARK: - Rating Distribution Section
                ratingDistributionSection
                
                // MARK: - Genre Chart Section
                genreChartSection
                
                // MARK: - Stats Section
                statsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Extra padding for tab bar
        }
    }
    
    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
                    VStack(spacing: 20) {
            if let profile = profile {
                // Profile Picture with enhanced styling
                profilePictureView(profile: profile)
                
                // Name and Username with improved typography
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
                
                // Bio with enhanced styling
                if let bio = profile.bio, !bio.isEmpty {
                                Text(bio)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .lineSpacing(2)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
                
                // Social Score Display
                if let socialScore = profile.socialScore, let totalRatings = profile.totalSocialRatings, totalRatings > 0 {
                    socialScoreSection(socialScore: socialScore, totalRatings: totalRatings, badges: profile.socialBadges ?? [])
                }
                
                // Enhanced Followers and Following with better visual hierarchy
                HStack(spacing: 40) {
                    VStack(spacing: 6) {
                        Text("\(formatNumber(profile.followers?.count ?? 0))")
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(.primary)
                        
                        Text("Followers")
                            .font(.system(size: 14, weight: .medium, design: .default))
                                            .foregroundColor(.secondary)
                                    }
                    .onTapGesture {
                        // TODO: Navigate to followers list
                        print("Navigate to followers")
                    }
                    
                    // Divider
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1, height: 40)
                    
                    VStack(spacing: 6) {
                        Text("\(formatNumber(profile.following?.count ?? 0))")
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(.primary)
                        
                        Text("Following")
                            .font(.system(size: 14, weight: .medium, design: .default))
                                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        // TODO: Navigate to following list
                        print("Navigate to following")
                    }
                }
                .padding(.vertical, 8)
                
                // Enhanced Edit Profile Button or Follow/Message buttons
                        if isCurrentUser {
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
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(22)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(BumpinPrimaryButtonStyle())
                    .padding(.horizontal, 24)
                        } else {
                    // Follow and Message buttons for other users
                            HStack(spacing: 12) {
                                Button(action: {
                                    if let userId = userId {
                                        viewModel.toggleFollow(userId: userId)
                                    }
                                }) {
                            HStack(spacing: 6) {
                                    if viewModel.isFollowActionLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        .tint(.white)
                                    } else {
                                    Image(systemName: viewModel.isFollowing ? "person.badge.minus" : "person.badge.plus")
                                        .font(.system(size: 14, weight: .medium))
                                        Text(viewModel.isFollowing ? "Following" : "Follow")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                viewModel.isFollowing ? 
                                LinearGradient(colors: [Color(.systemGray3), Color(.systemGray3)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.purple, Color.purple.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(22)
                            .shadow(color: (viewModel.isFollowing ? Color.gray : Color.purple).opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .disabled(viewModel.isFollowActionLoading)
                        .buttonStyle(BumpinPrimaryButtonStyle())
                        
                                Button(action: {
                                    guard let target = userId else { return }
                                    DirectMessageService.shared.getOrCreateConversation(with: target) { convo, _ in
                                        if let convo = convo {
                                            DispatchQueue.main.async { self.selectedConversation = convo }
                                        }
                                    }
                                }) {
                            HStack(spacing: 6) {
                                Image(systemName: "message")
                                    .font(.system(size: 14, weight: .medium))
                                    Text("Message")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                                        .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(22)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(BumpinButtonStyle())
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                // Loading state
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 20)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 16)
                    }
                }
            }
        }
    }
    
    // MARK: - Profile Picture View
    private func profilePictureView(profile: UserProfile) -> some View {
        Group {
            if let url = profile.profilePictureUrl, let imageUrl = URL(string: url) {
                CachedAsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.4))
                        )
                }
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
            } else {
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
                print("🎯 UserProfileView: State set atomically")
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
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.4))
                        }
                    }
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
        let cardContent = VStack(alignment: .leading, spacing: 14) {
            pinnedMusicCardArtwork(item: item, index: index, type: type, showRanking: showRanking)
            pinnedMusicCardTitle(item: item, type: type)
        }
        
        return cardContent
            .frame(width: 120, height: type == .artist ? 160 : 180) // Increased height for songs/albums
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
    
    // Pinned list placeholder (when no cover art available)
    private var listPlaceholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(.purple)
                    
                    Text("List")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.purple.opacity(0.8))
                }
            )
    }
    
    // List cover view with artwork or placeholder
    private func listCoverView(for item: PinnedItem, from userLists: [MusicList]) -> some View {
        let currentList = userLists.first(where: { $0.id == item.id })
        
        return Group {
            if let list = currentList,
               let coverUrl = list.coverImageUrl,
               !coverUrl.isEmpty,
               let url = URL(string: coverUrl) {
                // Show actual cover art
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    listPlaceholderView
                }
                .frame(width: 120, height: 120)
                .cornerRadius(12)
            } else {
                // Fallback to gradient placeholder
                listPlaceholderView
            }
        }
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray6), lineWidth: 1)
        )
    }
    
    // Pinned list card (different from music cards)
    private func pinnedListCard(item: PinnedItem, index: Int, showRanking: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // List Cover with ranking badge
            ZStack(alignment: .topTrailing) {
                Button(action: {
                    // Navigate to list detail
                    if let list = userLists.first(where: { $0.id == item.id }) {
                        selectedList = list
                    }
                    AnalyticsService.shared.logTap(category: "pinned_list", id: item.id)
                }) {
                    listCoverView(for: item, from: userLists)
                }
                .buttonStyle(BumpinButtonStyle())
                
                // Ranking badge
                if showRanking {
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
            
            // List Title with song count
            VStack(alignment: .leading, spacing: 4) {
                Button(action: {
                    // Navigate to list detail
                    if let list = userLists.first(where: { $0.id == item.id }) {
                        selectedList = list
                    }
                    AnalyticsService.shared.logTap(category: "pinned_list_title", id: item.id)
                }) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                                            .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(width: 120, alignment: .leading)
                }
                .buttonStyle(.plain)
                
                // Show list count if available
                if let list = userLists.first(where: { $0.id == item.id }) {
                    Text("\(list.items.count) songs")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(width: 120, alignment: .leading)
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
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray6), lineWidth: 1)
        )
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
    
    // MARK: - Pinned Lists Section
    private var pinnedListsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            pinnedSectionHeader(
                title: "Pinned Lists",
                icon: "list.bullet.rectangle",
                onEdit: isCurrentUser ? { showEditPinnedLists = true } : nil,
                showRankingToggle: isCurrentUser ? $showRankingForLists : nil
            )
            
            // Scrollable Content
            if let profile = profile, let pinnedLists = profile.pinnedLists, !pinnedLists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(pinnedLists.enumerated()), id: \.element.id) { index, item in
                            pinnedListCard(
                                item: item,
                                index: index + 1,
                                showRanking: showRankingForLists
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                    } else {
                pinnedEmptyState(
                    type: .song, // Using song as placeholder since lists aren't in PinnedType
                    icon: "list.bullet.rectangle",
                    title: "No pinned lists",
                    subtitle: isCurrentUser ? "Pin your favorite lists to showcase them" : "No lists pinned yet",
                    buttonTitle: "Pin Lists",
                    onAdd: isCurrentUser ? { showEditPinnedLists = true } : nil
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
        
        return VStack(spacing: 6) {
            ForEach(ratingData.sorted(by: { $0.starRating > $1.starRating })) { rating in
                RatingBarRow(
                    rating: rating,
                    maxCount: ratingData.map(\.count).max() ?? 1,
                    color: starColor(for: rating.starRating)
                )
            }
        }
        .padding(.horizontal, 4)
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
        var ratingCounts: [Int: Int] = [:]
        
        // Count ratings for each star level
        for log in logs {
            if let rating = log.rating, rating > 0 && rating <= 5 {
                ratingCounts[rating, default: 0] += 1
            }
        }
        
        let totalCount = logs.count
        
        // Create distribution data for all star levels (1-5)
        var distributionData: [RatingDistributionData] = []
        for star in 1...5 {
            let count = ratingCounts[star] ?? 0
            distributionData.append(RatingDistributionData(
                starRating: star,
                count: count,
                totalRatings: totalCount
            ))
        }
        
        return distributionData
    }
    
    private func starColor(for rating: Int) -> Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
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
                Button(action: {
                    selectedGenreForDetail = genre.name
                    print("🎯 Opening genre detail for: \(genre.name)")
                }) {
                    HStack(spacing: 12) {
                        // Color indicator
                        Circle()
                            .fill(genreColor(for: genre.name))
                            .frame(width: 12, height: 12)
                            .shadow(color: genreColor(for: genre.name).opacity(0.3), radius: 2, x: 0, y: 1)
                        
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
                            .stroke(genreColor(for: genre.name).opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .animation(nil, value: selectedGenreForDetail) // Disable button animations
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
        Button(action: {
            // Navigate to filtered view for this stat category
            selectedStatCategory = stat.statCategory
            AnalyticsService.shared.logTap(category: "profile_stat", id: stat.category)
        }) {
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
        .buttonStyle(BumpinButtonStyle())
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
        
        for log in songLogs {
            // Use the primaryGenre from our AI classification system
            let genre: String
            if let primaryGenre = log.primaryGenre {
                // Use AI-classified genre (single genre per log)
                genre = primaryGenre
                print("🤖 Using AI-classified genre: \(log.title) by \(log.artistName) → \(genre)")
            } else {
                // Fallback for older logs without AI classification
                genre = classifyGenreFallback(title: log.title, artist: log.artistName)
                print("🔄 Fallback classification: \(log.title) by \(log.artistName) → \(genre)")
            }
            
            genreCounts[genre, default: 0] += 1
        }
        
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
                loadingView
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
    
    private var loadingView: some View {
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
    let userReposts: [Repost]
    let profile: UserProfile?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredItems, id: \.id) { item in
                        StatDetailCard(item: item, category: category)
                    }
                }
                .padding(.horizontal, 16)
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
            let uniqueArtists = Dictionary(grouping: logs) { $0.artistName }
            return uniqueArtists.compactMap { (artistName, logs) in
                return StatDetailItem(
                    id: artistName,
                    title: artistName,
                    subtitle: "\(logs.count) logs",
                    artworkUrl: logs.first?.artworkUrl,
                    itemType: "artist",
                    rating: nil,
                    dateLogged: logs.map { $0.dateLogged }.max() ?? Date(),
                    hasReview: false
                )
            }.sorted { $0.dateLogged > $1.dateLogged }
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
            return userReposts.compactMap { repost in
                // For log reposts, find the original log
                if let logId = repost.logId {
                    if let originalLog = logs.first(where: { $0.id == logId }) {
                        return StatDetailItem(
                            id: repost.id,
                            title: originalLog.title,
                            subtitle: originalLog.artistName,
                            artworkUrl: originalLog.artworkUrl,
                            itemType: originalLog.itemType,
                            rating: originalLog.rating,
                            dateLogged: repost.createdAt,
                            hasReview: originalLog.review != nil && !(originalLog.review?.isEmpty ?? true)
                        )
                    }
                }
                
                // For item reposts, create a basic entry
                if let itemId = repost.itemId, let itemType = repost.itemType {
                    return StatDetailItem(
                        id: repost.id,
                        title: "Reposted \(itemType.capitalized)",
                        subtitle: "Item ID: \(itemId)",
                        artworkUrl: nil,
                        itemType: itemType,
                        rating: nil,
                        dateLogged: repost.createdAt,
                        hasReview: false
                    )
                }
                
                return nil
            }.sorted { $0.dateLogged > $1.dateLogged }
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
    let rating: Int?
    let dateLogged: Date
    let hasReview: Bool
}

// MARK: - Stat Detail Card
struct StatDetailCard: View {
    let item: StatDetailItem
    let category: StatCategory
    
    var body: some View {
                            HStack(spacing: 16) {
                                // Artwork
            Group {
                if let artworkUrl = item.artworkUrl, let url = URL(string: artworkUrl) {
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
                                
                                // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(item.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .default))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Rating if available
                    if let rating = item.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.4))
                            }
                        }
                    }
                    
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
            }
            
            Spacer()
            
            // Navigation arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
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
