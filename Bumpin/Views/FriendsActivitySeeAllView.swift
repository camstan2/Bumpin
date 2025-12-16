import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Friends Activity See All View

struct FriendsActivitySeeAllView: View {
    let musicItem: MusicSearchResult
    @Environment(\.dismiss) private var dismiss
    
    @State private var logs: [MusicLog] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMoreLogs = true
    @State private var lastDocument: DocumentSnapshot?
    @State private var selectedLog: MusicLog?
    @State private var showLogDetail = false
    @State private var followerIds: [String] = []
    @State private var universalTrackId: String? // Store universal track ID for queries
    
    // Batch-loaded data
    @State private var userProfiles: [String: UserProfile] = [:]
    @State private var engagementData: [String: LogEngagementCache.EngagementData] = [:]
    
    private let initialLoadCount = 20
    private let loadMoreCount = 10
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading && logs.isEmpty {
                    loadingView
                } else if logs.isEmpty {
                    emptyStateView
                } else {
                    logsListView
                }
            }
            .navigationTitle("Follower Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                            .font(.title3)
                    }
                }
            }
            .refreshable {
                await refreshLogs()
            }
            .onAppear {
                if logs.isEmpty {
                    Task {
                        await fetchUniversalTrackId()
                        await loadFollowerIds()
                        await loadInitialLogs()
                    }
                }
            }
            .fullScreenCover(item: $selectedLog) { log in
                UnifiedLogCommentsView(log: log)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Artwork
            if let artworkUrl = musicItem.artworkURL, let url = URL(string: artworkUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 120, height: 120)
                .cornerRadius(musicItem.itemType == "song" ? 8 : 60)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            
            // Title and Artist
            VStack(spacing: 4) {
                Text(musicItem.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(musicItem.artistName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Stats
            HStack(spacing: 16) {
                StatPill(icon: "person.2.fill", value: "\(logs.count)", label: "followers")
                
                if let avgRating = calculateAverageRating() {
                    StatPill(icon: "star.fill", value: String(format: "%.1f", avgRating), label: "avg")
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Logs List View
    
    private var logsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                    .padding(.vertical, 8)
                
                // Logs
                ForEach(logs) { log in
                    EnhancedLogCard(
                        log: log,
                        userProfile: userProfiles[log.userId],
                        engagement: engagementData[log.id]
                    ) {
                        selectedLog = log
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onAppear {
                        // Load more when reaching second-to-last item
                        if log.id == logs[max(0, logs.count - 2)].id {
                            Task { await loadMoreLogs() }
                        }
                    }
                    
                    Divider()
                        .padding(.leading, 16)
                }
                
                // Loading more indicator
                if isLoadingMore {
                    ProgressView()
                        .padding()
                }
                
                // End of results indicator
                if !hasMoreLogs && !logs.isEmpty {
                    Text("No more logs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading follower activity...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Header (show even when empty)
            headerView
            
            Divider()
            
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No Follower Activity")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("None of your followers have logged this \(musicItem.itemType) yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Data Loading
    
    private func fetchUniversalTrackId() async {
        let platform = musicItem.platform ?? "apple_music"
        
        // Use TrackMatchingService to get universal track ID (same as main profile view)
        let track: UniversalTrack
        if platform == "apple_music" {
            track = await TrackMatchingService.shared.getUniversalTrack(
                title: musicItem.title,
                artist: musicItem.artistName,
                albumName: musicItem.albumName,
                appleMusicId: musicItem.id
            )
        } else {
            track = await TrackMatchingService.shared.getUniversalTrack(
                title: musicItem.title,
                artist: musicItem.artistName,
                albumName: musicItem.albumName,
                spotifyId: musicItem.id
            )
        }
        
        await MainActor.run {
            self.universalTrackId = track.id
        }
        print("🎯 Found universal track ID: \(track.id) for \(musicItem.title) by \(musicItem.artistName)")
    }
    
    private func loadFollowerIds() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        do {
            // Get follower IDs from subcollection (people who follow the user)
            let followersSnapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("followers")
                .getDocuments()
            
            var followerIds = followersSnapshot.documents.map { $0.documentID }
            
            // Fallback: If subcollection is empty, try user document array (backward compatibility)
            if followerIds.isEmpty {
                let userDoc = try await db.collection("users").document(currentUserId).getDocument()
                if let userData = userDoc.data(),
                   let arrayIds = userData["followers"] as? [String], !arrayIds.isEmpty {
                    followerIds = arrayIds
                }
            }
            
            await MainActor.run {
                self.followerIds = followerIds
            }
            
        } catch {
            print("❌ Error loading follower IDs: \(error.localizedDescription)")
        }
    }
    
    private func loadInitialLogs() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        // Get follower IDs (people who follow the user)
        guard !followerIds.isEmpty else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            // Firestore 'in' queries are limited to 10 items, so we need to batch
            let batchedLogs = try await withThrowingTaskGroup(of: [MusicLog].self) { group in
                var allLogs: [MusicLog] = []
                
                // Split follower IDs into chunks of 10
                let chunks = followerIds.chunked(into: 10)
                
                for chunk in chunks {
                    group.addTask {
                        let query: Query
                        if let universalId = self.universalTrackId {
                            query = db.collection("logs")
                                .whereField("universalTrackId", isEqualTo: universalId)
                                .whereField("userId", in: chunk)
                                .whereField("isPublic", isEqualTo: true)
                                .limit(to: self.initialLoadCount)
                        } else {
                            query = db.collection("logs")
                                .whereField("itemId", isEqualTo: self.musicItem.id)
                                .whereField("userId", in: chunk)
                                .whereField("isPublic", isEqualTo: true)
                                .limit(to: self.initialLoadCount)
                        }
                        
                        let snapshot = try await query.getDocuments()
                        return snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                    }
                }
                
                for try await logs in group {
                    allLogs.append(contentsOf: logs)
                }
                
                return allLogs
            }
            
            // Remove duplicates and sort by engagement
            let uniqueLogs = Array(Set(batchedLogs.map { $0.id })).compactMap { id in
                batchedLogs.first { $0.id == id }
            }
            let sortedLogs = EngagementScoringService.shared.sortByEngagement(uniqueLogs)

            // Batch load user profiles and engagement data (mirror Community view)
            let userIds = Array(Set(sortedLogs.map { $0.userId }))
            let logIds = sortedLogs.map { $0.id }

            async let profiles = UserProfileCache.shared.getProfiles(userIds: userIds)

            let engagement: [String: LogEngagementCache.EngagementData]
            if let currentUserId = Auth.auth().currentUser?.uid {
                engagement = await LogEngagementCache.shared.getEngagements(logIds: logIds, userId: currentUserId)
            } else {
                engagement = [:]
            }

            let loadedProfiles = await profiles
            
            await MainActor.run {
                self.logs = Array(sortedLogs.prefix(initialLoadCount))
                self.userProfiles = loadedProfiles
                self.engagementData = engagement
                self.hasMoreLogs = sortedLogs.count >= initialLoadCount
                self.isLoading = false
            }
            
        } catch {
            print("❌ Error loading logs: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadMoreLogs() async {
        guard !isLoadingMore && hasMoreLogs else { return }
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        // Get follower IDs (people who follow the user)
        guard !followerIds.isEmpty else {
            await MainActor.run {
                self.isLoadingMore = false
            }
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            // Load more logs in batches
            let batchedLogs = try await withThrowingTaskGroup(of: [MusicLog].self) { group in
                var allLogs: [MusicLog] = []
                
                let chunks = followerIds.chunked(into: 10)
                
                for chunk in chunks {
                    group.addTask {
                        let query: Query
                        if let universalId = self.universalTrackId {
                            query = db.collection("logs")
                                .whereField("universalTrackId", isEqualTo: universalId)
                                .whereField("userId", in: chunk)
                                .whereField("isPublic", isEqualTo: true)
                                .limit(to: self.loadMoreCount)
                        } else {
                            query = db.collection("logs")
                                .whereField("itemId", isEqualTo: self.musicItem.id)
                                .whereField("userId", in: chunk)
                                .whereField("isPublic", isEqualTo: true)
                                .limit(to: self.loadMoreCount)
                        }
                        
                        let snapshot = try await query.getDocuments()
                        return snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                    }
                }
                
                for try await logs in group {
                    allLogs.append(contentsOf: logs)
                }
                
                return allLogs
            }
            
            // Remove duplicates and already loaded logs
            let existingIds = Set(logs.map { $0.id })
            let newLogs = batchedLogs.filter { !existingIds.contains($0.id) }
            let sortedNewLogs = EngagementScoringService.shared.sortByEngagement(newLogs)

            // Batch load new user profiles and engagement data (mirror Community view)
            let userIds = Array(Set(sortedNewLogs.map { $0.userId }))
            let logIds = sortedNewLogs.map { $0.id }

            async let profiles = UserProfileCache.shared.getProfiles(userIds: userIds)

            let engagement: [String: LogEngagementCache.EngagementData]
            if let currentUserId = Auth.auth().currentUser?.uid {
                engagement = await LogEngagementCache.shared.getEngagements(logIds: logIds, userId: currentUserId)
            } else {
                engagement = [:]
            }

            let loadedProfiles = await profiles
            
            await MainActor.run {
                self.logs.append(contentsOf: Array(sortedNewLogs.prefix(loadMoreCount)))
                // Re-sort entire list to maintain proper order
                self.logs = EngagementScoringService.shared.sortByEngagement(self.logs)

                // Merge new profiles and engagement data
                self.userProfiles.merge(loadedProfiles) { _, new in new }
                self.engagementData.merge(engagement) { _, new in new }
                self.hasMoreLogs = sortedNewLogs.count >= loadMoreCount
                self.isLoadingMore = false
            }
            
        } catch {
            print("❌ Error loading more logs: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingMore = false
            }
        }
    }
    
    private func refreshLogs() async {
        hasMoreLogs = true
        await fetchUniversalTrackId()
        await loadFollowerIds()
        await loadInitialLogs()
    }
    
    // MARK: - Helper Functions
    
    private func calculateAverageRating() -> Double? {
        let ratingsWithValues = logs.compactMap { $0.rating }
        guard !ratingsWithValues.isEmpty else { return nil }
        let sum = ratingsWithValues.reduce(0, +)
        return sum / Double(ratingsWithValues.count)
    }
}

// MARK: - Stat Pill Component (shared with Community)

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Enhanced Log Card (shared with Community)

private struct EnhancedLogCard: View {
    let log: MusicLog
    let userProfile: UserProfile?
    let engagement: LogEngagementCache.EngagementData?
    let onTapCard: () -> Void
    
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var hasThumbsDown: Bool = false
    @State private var thumbsDownCount: Int = 0
    @State private var hasReposted: Bool = false
    @State private var repostCount: Int = 0
    @State private var showActivity = false
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    @State private var showUserProfile = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack(spacing: 12) {
                // Avatar
                if let profileUrl = userProfile?.profilePictureUrl, let url = URL(string: profileUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(userProfile?.username.prefix(1) ?? "U").uppercased())
                                .font(.headline)
                                .foregroundColor(.purple)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(userProfile?.username ?? "User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        // Star rating
                        if let rating = log.rating {
                            StarRatingDisplayView(
                                rating: rating,
                                starSize: 12,
                                spacing: 1
                            )
                        }
                        
                        Spacer()
                        
                        // Time ago
                        Text(timeAgoString(from: log.dateLogged))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTapCard()
            }
            
            // Review text
            if let review = log.review, !review.isEmpty {
                Text(review)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(nil) // Show full review
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapCard()
                    }
            }
            
            // Engagement bar (aligned with community layout)
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
                    .font(.caption)
                    .foregroundColor(isLiked ? .red : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Comments button
                Button(action: { 
                    LogEngagementHaptics.comment()
                    onTapCard() 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text("\(log.commentCount ?? 0)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Thumbs down button (shows total)
                Button(action: { 
                    LogEngagementHaptics.thumbsDown()
                    toggleThumbsDown() 
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: hasThumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        if thumbsDownCount > 0 {
                            Text("\(thumbsDownCount)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
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
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
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
        }
        .contextMenu {
            Button {
                showReportSheet = true
            } label: {
                Label("Report", systemImage: "flag")
            }
        }
        .onAppear {
            // Use cached engagement data
            likeCount = log.likeCount ?? 0
            repostCount = log.repostCount ?? 0
            thumbsDownCount = log.thumbsDownCount ?? 0
            isLiked = engagement?.isLiked ?? false
            hasThumbsDown = engagement?.hasThumbsDown ?? false
            hasReposted = engagement?.hasReposted ?? false
        }
        .fullScreenCover(isPresented: $showActivity) {
            LogActivityView(logId: log.id, log: log)
        }
        .fullScreenCover(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView(userId: log.userId)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                showUserProfile = false
                            }
                            .foregroundColor(.purple)
                        }
                    }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentId: log.id,
                contentType: .musicReview,
                reportedUserId: log.userId,
                reportedUsername: userProfile?.username ?? "user",
                contentPreview: log.review
            )
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockUserView(
                userId: log.userId,
                username: userProfile?.username ?? "user",
                profilePictureUrl: userProfile?.profilePictureUrl
            )
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y"
        } else if let months = components.month, months > 0 {
            return "\(months)mo"
        } else if let days = components.day, days > 0 {
            return "\(days)d"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        } else {
            return "now"
        }
    }
    
    private func toggleLike() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let db = Firestore.firestore()
            let likeRef = db.collection("logs").document(log.id).collection("likes").document(currentUserId)
            
            do {
                if isLiked {
                    // Unlike
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
                    // Like
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
                        thumbsDownCount = max(0, thumbsDownCount - 1)
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
                        thumbsDownCount += 1
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
                    // Remove repost
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
                    // Add repost
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
                print("❌ Error handling repost: \(error)")
            }
        }
    }
}

#Preview {
    FriendsActivitySeeAllView(
        musicItem: MusicSearchResult(
            id: "sample-id",
            title: "EVIL JORDAN",
            artistName: "Sample Artist",
            albumName: "Sample Album",
            artworkURL: nil,
            itemType: "song",
            popularity: 100
        )
    )
}

