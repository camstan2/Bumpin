import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Enhanced Friends Logs Section

struct EnhancedFriendsLogsSection: View {
    let itemId: String
    let itemType: String
    let itemTitle: String
    let musicItem: MusicSearchResult? // Optional for backwards compatibility
    
    @State private var friendsLogs: [MusicLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showFriendsActivitySeeAll = false

    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            // Section header
            ProfileSectionHeader(
                title: "Follower Activity",
                subtitle: friendsLogs.isEmpty ? "No follower activity yet" : "\(friendsLogs.count) follower logs",
                icon: "person.2.fill",
                action: friendsLogs.count > 3 ? { showFriendsActivitySeeAll = true } : nil,
                actionTitle: friendsLogs.count > 3 ? "View All" : nil
            )
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if friendsLogs.isEmpty {
                emptyView
            } else {
                friendsLogsContent
            }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
        .onAppear {
            Task { await loadFriendsLogs() }
        }
        .fullScreenCover(isPresented: $showFriendsActivitySeeAll) {
            if let musicItem = musicItem {
                FriendsActivitySeeAllView(musicItem: musicItem)
            }
        }
    }
    
    private var friendsLogsContent: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            ForEach(Array(friendsLogs.prefix(3))) { log in
                FriendLogRow(log: log)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading follower activity...")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.warning)
            Text("Unable to load follower activity")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
            Text(message)
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            Image(systemName: "person.2.circle")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            Text("No follower activity")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
            Text("Your followers haven't logged this \(itemType) yet")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadFriendsLogs() async {
        isLoading = true
        errorMessage = nil
        
        guard let currentUserId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        do {
            let db = Firestore.firestore()
            
            // Get follower IDs from subcollection (people who follow the user)
            let followersSnapshot = try await db.collection("users")
                .document(currentUserId)
                .collection("followers")
                .getDocuments()
            
            var followerIds = followersSnapshot.documents.map { $0.documentID }
            
            // Fallback: If subcollection is empty, try legacy array (backward compatibility)
            if followerIds.isEmpty {
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
                if let userData = userDoc.data(),
                   let arrayIds = userData["followers"] as? [String], !arrayIds.isEmpty {
                    followerIds = arrayIds
                }
            }
            
            guard !followerIds.isEmpty else {
                friendsLogs = []
                isLoading = false
                return
            }
            
            // Fetch logs from followers (batch by 10 due to Firestore 'in' limit)
            var allLogs: [MusicLog] = []
            let chunks = followerIds.chunked(into: 10)
            
            for chunk in chunks {
                var snapshot: QuerySnapshot
                
                if itemType == "artist" {
                    // For artists, fetch direct artist logs (itemType == "artist" and artistName/itemId matches)
                    snapshot = try await db.collection("logs")
                        .whereField("itemType", isEqualTo: "artist")
                        .whereField("userId", in: chunk)
                        .whereField("isPublic", isEqualTo: true)
                        .getDocuments()
                    
                    let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                    // Filter for logs where the artist name matches and is visible
                    let filteredLogs = logs.filter { log in
                        let matchesArtist = log.artistName.caseInsensitiveCompare(itemTitle) == .orderedSame
                        let isVisible = log.isPublic ?? true
                        return matchesArtist && isVisible
                    }
                    allLogs.append(contentsOf: filteredLogs)
                } else {
                    // For songs/albums, query by itemId
                    snapshot = try await db.collection("logs")
                    .whereField("itemId", isEqualTo: itemId)
                    .whereField("userId", in: chunk)
                    .whereField("isPublic", isEqualTo: true)
                    .getDocuments()
                
                let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                allLogs.append(contentsOf: logs)
                }
            }
            
            // Sort by engagement score and take top 3 for preview
            let sortedLogs = EngagementScoringService.shared.sortByEngagement(allLogs)
            friendsLogs = Array(sortedLogs.prefix(10)) // Load more than 3 for accurate sorting
            
            print("📊 Found \(friendsLogs.count) follower logs sorted by engagement")
        } catch {
            print("❌ Error loading follower logs: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            friendsLogs = []
        }
        
        isLoading = false
    }
}

// MARK: - Friend Log Row Component

struct FriendLogRow: View {
    let log: MusicLog
    @State private var showingComments = false
    @State private var userProfile: UserProfile?
        @State private var isLiked: Bool = false
        @State private var likeCount: Int = 0
        @State private var hasThumbsDown: Bool = false
        @State private var hasReposted: Bool = false
        @State private var repostCount: Int = 0
        @State private var showActivity = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // User avatar (show actual profile picture when available)
                if let urlString = userProfile?.profilePictureUrl,
                   let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .overlay(
                                Text(String(userProfile?.username.prefix(1) ?? "U").uppercased())
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            )
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(userProfile?.username.prefix(1) ?? "U").uppercased())
                                .font(.caption)
                                .foregroundColor(.purple)
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Username and rating
                    HStack(spacing: 8) {
                        Text(userProfile?.username ?? "User")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if let rating = log.rating, rating > 0 {
                            StarRatingDisplayView(
                                rating: rating,
                                starSize: 10,
                                spacing: 1,
                                showNumber: false
                            )
                        }
                        
                        Spacer()
                        
                        Text(RelativeTimeFormatter.shared.string(for: log.dateLogged))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Review text
                    if let review = log.review, !review.isEmpty {
                        Text(review)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    // Engagement
                    HStack(spacing: 12) {
                        // Like button
                        Button(action: { toggleLike() }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                Text("\(likeCount)")
                            }
                        }
                        .foregroundColor(isLiked ? .red : .secondary)
                        .buttonStyle(PlainButtonStyle())
                        
                        // Comment count (not a button, opens via card tap)
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                            Text("\(log.commentCount ?? 0)")
                        }
                        .foregroundColor(.secondary)
                        
                        // Thumbs down button
                        Button(action: { toggleThumbsDown() }) {
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
                        Button(action: { handleRepost() }) {
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
                        Button(action: { showActivity = true }) {
                            Text("Activity")
                                .font(.system(size: 10.5))
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            showingComments = true
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            loadUserProfile()
            loadEngagement()
        }
        .fullScreenCover(isPresented: $showingComments) {
            UnifiedLogCommentsView(log: log)
        }
        .fullScreenCover(isPresented: $showActivity) {
            LogActivityView(logId: log.id, log: log)
        }
    }
    
    private func loadUserProfile() {
        guard userProfile == nil else { return }
        
        Task {
            let db = Firestore.firestore()
            do {
                let doc = try await db.collection("users").document(log.userId).getDocument()
                if let profile = try? doc.data(as: UserProfile.self) {
                    await MainActor.run {
                        self.userProfile = profile
                    }
                }
            } catch {
                print("❌ Error loading user profile: \(error)")
            }
        }
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
    VStack(spacing: 20) {
        EnhancedFriendsLogsSection(
            itemId: "sample-id",
            itemType: "song",
            itemTitle: "Sample Song",
            musicItem: MusicSearchResult(
                id: "sample-id",
                title: "Sample Song",
                artistName: "Sample Artist",
                albumName: "",
                artworkURL: nil,
                itemType: "song",
                popularity: 100
            )
        )
    }
    .padding()
}