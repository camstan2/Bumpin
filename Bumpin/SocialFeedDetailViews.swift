import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Pressable Row Button Style
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Shared Relative Time Formatter
final class RelativeTimeFormatter {
    static let shared = RelativeTimeFormatter()
    private init() {}
    func string(for date: Date) -> String {
        let now = Date()
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago" }
        let hours = minutes / 60
        if hours < 24 { return hours == 1 ? "1 hour ago" : "\(hours) hours ago" }
        let days = hours / 24
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        if days == 7 { return "One week ago" }
        let calendar = Calendar.current
        let yearOfDate = calendar.component(.year, from: date)
        let yearNow = calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.doesRelativeDateFormatting = false
        formatter.dateFormat = yearOfDate == yearNow ? "MMMM d" : "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Near-bottom scroll detector
fileprivate struct ScrollNearBottomModifier: ViewModifier {
    let threshold: CGFloat
    let onNearBottom: () -> Void
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {}
                        .onChange(of: proxy.frame(in: .global).maxY) { _ in
                            let screenHeight = UIScreen.main.bounds.height
                            if proxy.frame(in: .global).maxY < screenHeight + threshold {
                                onNearBottom()
                            }
                        }
                }
            )
    }
}

// MARK: - Friends Popular See All (endless)
struct FriendsPopularDetailView: View {
    let initialItems: [TrendingItem]
    @Environment(\.dismiss) private var dismiss
    @State private var itemsState: [TrendingItem] = []
    @State private var isLoadingMore = false
    @State private var lastCursorDate: Date? = nil
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(itemsState.enumerated()), id: \.element.id) { idx, item in
                    TrendingDetailRow(item: item, itemType: .song, rank: idx + 1)
                }
                if isLoadingMore { HStack { Spacer(); ProgressView(); Spacer() } }
            }
            .navigationTitle("Popular with Friends")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear {
                if itemsState.isEmpty { itemsState = initialItems }
                if lastCursorDate == nil { lastCursorDate = Date() }
            }
            .onScrollNearBottom(perform: loadMore)
        }
    }
    private func loadMore() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            do {
                let db = Firestore.firestore()
                // Pull more recent logs before cursor, then aggregate by itemId
                var q: Query = db.collection("logs").order(by: "dateLogged", descending: true)
                if let cursor = lastCursorDate { q = q.whereField("dateLogged", isLessThan: cursor) }
                let snap = try await q.limit(to: 200).getDocuments()
                let logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }.filter { $0.itemType == "song" && ($0.isPublic ?? true) }
                lastCursorDate = logs.last?.dateLogged ?? lastCursorDate
                let grouped = Dictionary(grouping: logs) { $0.itemId }
                let more = grouped.compactMap { (itemId, logs) -> TrendingItem? in
                    guard let first = logs.first else { return nil }
                    let ratings = logs.compactMap { $0.rating }
                    let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                    return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "song", itemId: itemId)
                }
                var existing = Dictionary(uniqueKeysWithValues: itemsState.map { ($0.itemId, $0) })
                for m in more { existing[m.itemId] = m }
                itemsState = Array(existing.values)
                itemsState.sort { $0.logCount > $1.logCount }
                isLoadingMore = false
            } catch {
                isLoadingMore = false
            }
        }
    }
}

fileprivate extension View {
    func onScrollNearBottom(threshold: CGFloat = 200, perform: @escaping () -> Void) -> some View {
        modifier(ScrollNearBottomModifier(threshold: threshold, onNearBottom: perform))
    }
}

// MARK: - Trending Detail View
struct TrendingDetailView: View {
    let items: [TrendingItem]
    let title: String
    let itemType: TrendingItemType
    @Environment(\.dismiss) private var dismiss
    @State private var itemsState: [TrendingItem] = []
    @State private var isLoadingMore = false
    @State private var lastDateCursor: Date? = nil
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(itemsState.enumerated()), id: \.element.id) { index, item in
                    TrendingDetailRow(item: item, itemType: itemType, rank: index + 1)
                }
                if isLoadingMore { HStack { Spacer(); ProgressView(); Spacer() } }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if itemsState.isEmpty { itemsState = items }
                if lastDateCursor == nil { lastDateCursor = Date() }
            }
            .onScrollNearBottom(perform: loadMore)
        }
    }

    private func loadMore() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            do {
                let db = Firestore.firestore()
                var query: Query = db.collection("logs").order(by: "dateLogged", descending: true)
                if let cursor = lastDateCursor { query = query.whereField("dateLogged", isLessThan: cursor) }
                switch itemType {
                case .song:
                    query = query.whereField("itemType", isEqualTo: "song")
                case .album:
                    query = query.whereField("itemType", isEqualTo: "album")
                case .artist:
                    break
                }
                let snapshot = try await query.limit(to: 200).getDocuments()
                let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                self.lastDateCursor = logs.last?.dateLogged ?? self.lastDateCursor
                let more: [TrendingItem]
                switch itemType {
                case .song:
                    more = calculateTrendingSongs(from: logs)
                case .album:
                    more = calculateTrendingAlbums(from: logs)
                case .artist:
                    more = calculateTrendingArtists(from: logs)
                }
                // Merge unique by id
                var existing = Dictionary(uniqueKeysWithValues: itemsState.map { ($0.itemId, $0) })
                for m in more { existing[m.itemId] = m }
                itemsState = Array(existing.values)
                // Sort by simple score similar to view model
                itemsState.sort { $0.logCount > $1.logCount }
                isLoadingMore = false
            } catch {
                isLoadingMore = false
            }
        }
    }

    // Local helpers replicate view model logic for aggregation
    private func calculateTrendingSongs(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.itemId }
        return grouped.compactMap { (itemId, logs) in
            guard let first = logs.first else { return nil }
            let ratings = logs.compactMap { $0.rating }
            let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
            return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "song", itemId: itemId)
        }
    }
    private func calculateTrendingAlbums(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.itemId }
        return grouped.compactMap { (itemId, logs) in
            guard let first = logs.first else { return nil }
            let ratings = logs.compactMap { $0.rating }
            let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
            return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "album", itemId: itemId)
        }
    }
    private func calculateTrendingArtists(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.artistName }
        return grouped.compactMap { (artist, logs) in
            let ratings = logs.compactMap { $0.rating }
            let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
            return TrendingItem(title: artist, subtitle: nil, artworkUrl: logs.first?.artworkUrl, logCount: logs.count, averageRating: avg, itemType: "artist", itemId: artist)
        }
    }
}

// MARK: - Combined Trending Detail (mixed item types)
struct CombinedTrendingDetailView: View {
    let items: [TrendingItem]
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var itemsState: [TrendingItem] = []
    @State private var isLoadingMore = false
    @State private var lastDateCursor: Date? = nil

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(itemsState.enumerated()), id: \.element.id) { index, item in
                    TrendingDetailRow(item: item, itemType: mapType(item.itemType), rank: index + 1)
                }
                if isLoadingMore { HStack { Spacer(); ProgressView(); Spacer() } }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear {
                if itemsState.isEmpty { itemsState = items }
                if lastDateCursor == nil { lastDateCursor = Date() }
            }
            .onScrollNearBottom(perform: loadMore)
        }
    }

    private func loadMore() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            do {
                let db = Firestore.firestore()
                var query: Query = db.collection("logs").order(by: "dateLogged", descending: true)
                if let cursor = lastDateCursor { query = query.whereField("dateLogged", isLessThan: cursor) }
                let snapshot = try await query.limit(to: 300).getDocuments()
                let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                self.lastDateCursor = logs.last?.dateLogged ?? self.lastDateCursor
                // Aggregate by (type,id)
                let grouped = Dictionary(grouping: logs.filter { ["song","album","artist"].contains($0.itemType) }) { ($0.itemType + "|" + $0.itemId) }
                let more: [TrendingItem] = grouped.compactMap { (_, logs) in
                    guard let first = logs.first else { return nil }
                    let ratings = logs.compactMap { $0.rating }
                    let avg = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                    return TrendingItem(title: first.title, subtitle: first.itemType == "artist" ? nil : first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: avg, itemType: first.itemType, itemId: first.itemId)
                }
                // Merge unique by (type,id)
                var existing = Dictionary(uniqueKeysWithValues: itemsState.map { (($0.itemType + "|" + $0.itemId), $0) })
                for m in more { existing[m.itemType + "|" + m.itemId] = m }
                itemsState = Array(existing.values)
                itemsState.sort { $0.logCount > $1.logCount }
                isLoadingMore = false
            } catch {
                isLoadingMore = false
            }
        }
    }

    private func mapType(_ raw: String) -> TrendingItemType {
        switch raw { case "album": return .album; case "artist": return .artist; default: return .song }
    }
}

// MARK: - Trending Detail Row
struct TrendingDetailRow: View {
    let item: TrendingItem
    let itemType: TrendingItemType
    let rank: Int
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 12) {
            artworkView
            itemInfoView
            Spacer()
            trendingIndicator
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            TrendingItemDetailView(item: item, itemType: itemType)
        }
    }
    
    private var artworkView: some View {
        Group {
            if let artworkUrl = item.artworkUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    private var itemInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            statsView
        }
    }
    
    private var statsView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "music.note.list")
                    .font(.caption2)
                Text("\(item.logCount) logs")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            
            if let averageRating = item.averageRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", averageRating))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var trendingIndicator: some View {
        VStack {
            Image(systemName: "flame.fill")
                .font(.caption)
                .foregroundColor(.orange)
            Text("#\(rank)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Trending Item Detail View
struct TrendingItemDetailView: View {
    let item: TrendingItem
    let itemType: TrendingItemType
    @Environment(\.dismiss) private var dismiss
    @State private var relatedLogs: [MusicLog] = []
    @State private var isLoading = false
    @State private var hasReposted = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        // Large artwork
                        if let artworkUrl = item.artworkUrl, let url = URL(string: artworkUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 200, height: 200)
                            .cornerRadius(12)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 200, height: 200)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        // Title and subtitle
                        VStack(spacing: 4) {
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Stats
                        HStack(spacing: 24) {
                            VStack {
                                Text("\(item.logCount)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("Logs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let averageRating = item.averageRating {
                                VStack {
                                    Text(String(format: "%.1f", averageRating))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Text("Rating")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Recent reviews
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Reviews")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if relatedLogs.isEmpty {
                            Text("No reviews yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(relatedLogs.prefix(10)) { log in
                                    if log.review != nil && !log.review!.isEmpty {
                                        EnhancedReviewView(log: log, showFullDetails: false)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    Task { _ = await ReportsService.shared.report(target: .log(logId: log.id), reason: "inappropriate") }
                                                } label: { Label("Report", systemImage: "flag") }
                                                Button("Hide user") {
                                                    Task { _ = await UserPreferencesService.shared.hideUser(log.userId) }
                                                }
                                            }
                                    }
                                }
                            }
                        }
                    }

                    // Repost item action (song/album/artist)
                    HStack {
                        Button(action: { toggleItemRepost() }) {
                            Label(hasReposted ? "Unrepost" : "Repost", systemImage: "arrow.2.squarepath")
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        Spacer()
                    }
                }
                .padding()
            }
            .navigationTitle(itemType.rawValue.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadRelatedLogs()
        }
    }
    
    private func loadRelatedLogs() {
        isLoading = true
        
        Task {
            await loadRelatedLogsAsync()
        }
    }
    
    @MainActor
    private func loadRelatedLogsAsync() async {
        do {
            let db = Firestore.firestore()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            let snapshot: QuerySnapshot
            
            switch itemType {
            case .song, .album:
                snapshot = try await db.collection("logs")
                    .whereField("itemId", isEqualTo: item.itemId)
                    .whereField("dateLogged", isGreaterThan: yesterday)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 20)
                    .getDocuments()
            case .artist:
                snapshot = try await db.collection("logs")
                    .whereField("artistName", isEqualTo: item.title)
                    .whereField("dateLogged", isGreaterThan: yesterday)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 20)
                    .getDocuments()
            }
            
            let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            
            self.relatedLogs = logs.filter { $0.review != nil && !$0.review!.isEmpty }
            self.isLoading = false
        } catch {
            print("Error loading related logs: \(error)")
            self.isLoading = false
        }
    }

    private func toggleItemRepost() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Repost.hasReposted(userId: uid, itemId: item.itemId, itemType: itemType.rawValue) { exists in
            hasReposted = exists
            if exists {
                Repost.remove(forUser: uid, itemId: item.itemId, itemType: itemType.rawValue) { _ in hasReposted = false }
                AnalyticsService.shared.logEngagement(action: "unrepost_item", contentType: itemType.rawValue, contentId: item.itemId, logId: item.itemId)
            } else {
                Repost.add(Repost(itemId: item.itemId, itemType: itemType.rawValue, userId: uid)) { _ in hasReposted = true }
                AnalyticsService.shared.logEngagement(action: "repost_item", contentType: itemType.rawValue, contentId: item.itemId, logId: item.itemId)
            }
        }
    }
}

// MARK: - Friends Activity Detail View
struct FriendsActivityDetailView: View {
    let activity: [FriendActivity]
    @Environment(\.dismiss) private var dismiss
    @State private var itemsState: [FriendActivity] = []
    @State private var isLoadingMore = false
    @State private var lastDateCursor: Date? = nil
    @State private var followingIds: [String] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(itemsState) { item in
                    FriendActivityDetailRow(activity: item)
                }
                if isLoadingMore { HStack { Spacer(); ProgressView(); Spacer() } }
            }
            .navigationTitle("Friends Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if itemsState.isEmpty { itemsState = activity }
                if lastDateCursor == nil { lastDateCursor = activity.last?.loggedAt ?? Date() }
                if followingIds.isEmpty { Task { await loadFollowingIds() } }
            }
            .onScrollNearBottom(perform: loadMore)
        }
    }

    private func loadFollowingIds() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let db = Firestore.firestore()
            if let profile = try? await db.collection("users").document(uid).getDocument().data(as: UserProfile.self) {
                self.followingIds = profile.following ?? []
            }
        }
    }

    private func loadMore() {
        guard !isLoadingMore, !followingIds.isEmpty else { return }
        isLoadingMore = true
        Task {
            do {
                let db = Firestore.firestore()
                let batches = followingIds.chunked(into: 10)
                var newLogs: [MusicLog] = []
                for batch in batches {
                    var q: Query = db.collection("logs")
                        .whereField("userId", in: batch)
                        .order(by: "dateLogged", descending: true)
                    if let cursor = lastDateCursor { q = q.whereField("dateLogged", isLessThan: cursor) }
                    let snap = try await q.limit(to: 50).getDocuments()
                    let logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                    newLogs.append(contentsOf: logs)
                }
                // Map to activities (we reuse usernames present in itemsState to avoid extra fetches)
                let profileById: [String: String] = Dictionary(uniqueKeysWithValues: itemsState.map { ($0.userId, $0.username) })
                let newActs: [FriendActivity] = newLogs.map { log in
                    let username = profileById[log.userId] ?? "user"
                    return FriendActivity(userId: log.userId, username: username, userProfilePictureUrl: nil, songTitle: log.title, artistName: log.artistName, artworkUrl: log.artworkUrl, rating: log.rating, loggedAt: log.dateLogged, musicLog: log)
                }.sorted { $0.loggedAt > $1.loggedAt }
                self.itemsState.append(contentsOf: newActs)
                self.lastDateCursor = self.itemsState.last?.loggedAt ?? self.lastDateCursor
                isLoadingMore = false
            } catch {
                isLoadingMore = false
            }
        }
    }
}

// MARK: - Friend Activity Detail Row
struct FriendActivityDetailRow: View {
    let activity: FriendActivity
    @State private var showingReview = false
    @State private var showingComments = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Song artwork
            if let artworkUrl = activity.artworkUrl, let url = URL(string: artworkUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Song title
                Text(activity.songTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                // Artist name
                Text(activity.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // User info and rating
                HStack(spacing: 8) {
                    // User profile picture
                    if let profileUrl = activity.userProfilePictureUrl, let url = URL(string: profileUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(String(activity.username.prefix(1)).uppercased())
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Username
                    Text("@\(activity.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Rating stars
                    if let rating = activity.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(star <= rating ? .yellow : .gray)
                            }
                        }
                    }
                }
                
                // Time ago
                Text(RelativeTimeFormatter.shared.string(for: activity.loggedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingReview = true
        }
        .fullScreenCover(isPresented: $showingReview) {
            if let log = activity.musicLog {
                let result = MusicSearchResult(id: log.itemId, title: log.title, artistName: log.artistName, albumName: "", artworkURL: log.artworkUrl, itemType: log.itemType, popularity: 0)
                MusicProfileView(musicItem: result, pinnedLog: log)
            }
        }
        .contextMenu {
            if let log = activity.musicLog {
                Button(role: .destructive) {
                    Task { _ = await ReportsService.shared.report(target: .log(logId: log.id), reason: "inappropriate") }
                } label: { Label("Report", systemImage: "flag") }
            }
            Button("Hide user") {
                Task { _ = await UserPreferencesService.shared.hideUser(activity.userId) }
            }
        }
        .overlay(
            Group {
                if let log = activity.musicLog {
                    VStack { Spacer(); EngagementBar(log: log, onComments: { showingComments = true }) }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                }
            }, alignment: .bottomLeading
        )
        .sheet(isPresented: $showingComments) {
            if let log = activity.musicLog { CommentsSheet(log: log) }
        }
    }
    
}

#Preview {
    TrendingDetailView(
        items: [
            TrendingItem(title: "Sample Song", subtitle: "Sample Artist", artworkUrl: nil, logCount: 15, averageRating: 4.2, itemType: "song", itemId: "123")
        ],
        title: "Trending Songs",
        itemType: .song
    )
} 

// MARK: - Creator Spotlight Views
struct CreatorSpotlightSection: View {
    let items: [CreatorSpotlight]
    let isLoading: Bool
    let onSeeAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Creators are listening to…")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button("See All") { onSeeAll() }
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
            if isLoading {
                HStack { ForEach(0..<4, id: \.self) { _ in CreatorCardSkeleton() }; Spacer() }
            } else if items.isEmpty {
                Text("No creator activity yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                            CreatorSpotlightCard(spotlight: item, parallaxCoordSpace: "creatorHS")
                                .opacity(0.0)
                                .onAppear { withAnimation(.easeInOut(duration: 0.18).delay(Double(min(idx, 6)) * 0.03)) { } }
                        }
                    }
                }
                .coordinateSpace(name: "creatorHS")
            }
        }
    }
}

private struct CreatorCardSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            Circle().fill(Color.gray.opacity(0.3)).frame(width: 56, height: 56)
            RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 80, height: 10)
            RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 100, height: 10)
        }
        .redacted(reason: .placeholder)
    }
}

private struct CreatorSpotlightCard: View {
    let spotlight: CreatorSpotlight
    var parallaxCoordSpace: String? = nil
    @State private var showLog = false
    @State private var showAllPosts = false
    @State private var showProfile = false
    
    var body: some View {
        Button(action: {
            AnalyticsService.shared.logTap(category: "creator_spotlight", id: spotlight.userId)
            showLog = true
        }) {
            VStack(spacing: 8) {
                // Avatar + verified badge
                ZStack(alignment: .bottomTrailing) {
                    if let urlString = spotlight.profilePictureUrl, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        Circle().fill(Color.gray.opacity(0.3))
                            .frame(width: 56, height: 56)
                            .overlay(Text(String(spotlight.username.prefix(1)).uppercased()).foregroundColor(.white))
                    }
                    if spotlight.isVerified {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.blue).background(Color.white.clipShape(Circle())).offset(x: 4, y: 4).font(.caption)
                    }
                }
                Text(spotlight.displayName ?? spotlight.username)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if spotlight.recentLogs.isEmpty {
                    Text("No recent posts")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 2) {
                        ForEach(spotlight.recentLogs.prefix(2)) { log in
                            Text("\(log.title) — \(log.artistName)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(width: 140)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowOffset)
        }
        .buttonStyle(PressableRowStyle())
        .contextMenu {
            Button("View profile") { showProfile = true }
        }
        .fullScreenCover(isPresented: $showLog) {
            if let log = spotlight.latestLog {
                let result = MusicSearchResult(id: log.itemId, title: log.title, artistName: log.artistName, albumName: "", artworkURL: log.artworkUrl, itemType: log.itemType, popularity: 0)
                MusicProfileView(musicItem: result, pinnedLog: log)
            }
        }
        .sheet(isPresented: $showProfile) {
            UserProfileView(userId: spotlight.userId)
        }
        .contextMenu {
            Button("View posts") { showAllPosts = true }
            Button(role: .destructive) {
                Task { _ = await ReportsService.shared.report(target: .user(userId: spotlight.userId), reason: "inappropriate") }
            } label: { Label("Report user", systemImage: "flag") }
            Button("Hide user") {
                Task { _ = await UserPreferencesService.shared.hideUser(spotlight.userId) }
            }
        }
        .sheet(isPresented: $showAllPosts) {
            CreatorLogsListView(userId: spotlight.userId, displayName: spotlight.displayName ?? spotlight.username)
        }
        .onAppear { AnalyticsService.shared.logImpression(category: "creator_spotlight", id: spotlight.userId) }
    }
}

// MARK: - Explore: Now Playing Card
struct NowPlayingCreatorCard: View {
    let user: UserProfile
    @State private var showProfile = false
    @State private var showPosts = false
    var body: some View {
        Button(action: {
            AnalyticsService.shared.logTap(category: "explore_now_playing", id: user.uid)
            showProfile = true
        }) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if let url = user.profilePictureUrl.flatMap(URL.init(string:)) {
                        CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 56, height: 56).clipShape(Circle())
                    } else { Circle().fill(Color.gray.opacity(0.3)).frame(width: 56, height: 56) }
                    if user.isVerified == true { Image(systemName: "checkmark.seal.fill").foregroundColor(.blue).background(Color.white.clipShape(Circle())).offset(x: 4, y: 4).font(.caption) }
                }
                Text(user.displayName).font(.caption).fontWeight(.medium).lineLimit(1)
                if let roles = user.roles, !roles.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(roles.prefix(2), id: \.self) { role in
                            Text(role.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(role.lowercased() == "dj" ? Color.green.opacity(0.15) : Color.purple.opacity(0.15))
                                .foregroundColor(role.lowercased() == "dj" ? .green : .purple)
                                .clipShape(Capsule())
                        }
                    }
                }
                if let song = user.nowPlayingSong, let artist = user.nowPlayingArtist {
                    Text("\(song) — \(artist)").font(.caption2).foregroundColor(.secondary).lineLimit(2).multilineTextAlignment(.center)
                }
            }
            .frame(width: 140)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowOffset)
        }
        .buttonStyle(PressableRowStyle())
        .contextMenu {
            Button("View profile") { showProfile = true }
            Button("View posts") { showPosts = true }
        }
        .fullScreenCover(isPresented: $showProfile) { 
            NavigationView {
                UserProfileView(userId: user.uid)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                showProfile = false
                            }
                            .foregroundColor(.purple)
                        }
                    }
            }
        }
        .sheet(isPresented: $showPosts) {
            CreatorLogsListView(userId: user.uid, displayName: user.displayName)
        }
        .onAppear {
            AnalyticsService.shared.logImpression(category: "explore_now_playing", id: user.uid)
        }
    }
}

// MARK: - Now Playing: Friends
struct NowPlayingFriendCard: View {
    let user: UserProfile
    @State private var showProfile = false
    var body: some View {
        Button(action: {
            AnalyticsService.shared.logTap(category: "friends_now_playing", id: user.uid)
            showProfile = true
        }) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    if let url = user.profilePictureUrl.flatMap(URL.init(string:)) {
                        CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 56, height: 56).clipShape(Circle())
                    } else { Circle().fill(Color.gray.opacity(0.3)).frame(width: 56, height: 56) }
                    if user.isVerified == true { Image(systemName: "checkmark.seal.fill").foregroundColor(.blue).background(Color.white.clipShape(Circle())).offset(x: 4, y: 4).font(.caption) }
                }
                Text(user.displayName).font(.caption).fontWeight(.medium).lineLimit(1)
                if let song = user.nowPlayingSong, let artist = user.nowPlayingArtist {
                    Text("\(song) — \(artist)").font(.caption2).foregroundColor(.secondary).lineLimit(2).multilineTextAlignment(.center)
                }
            }
            .frame(width: 140)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowOffset)
        }
        .buttonStyle(PressableRowStyle())
        .fullScreenCover(isPresented: $showProfile) { 
            NavigationView {
                UserProfileView(userId: user.uid)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") {
                                showProfile = false
                            }
                            .foregroundColor(.purple)
                        }
                    }
            }
        }
        .onAppear { AnalyticsService.shared.logImpression(category: "friends_now_playing", id: user.uid) }
    }
}

// MARK: - Friends Now Playing: See All
struct FriendsNowPlayingListView: View {
    let users: [UserProfile]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List(users, id: \.uid) { user in
                HStack(spacing: 12) {
                    if let url = user.profilePictureUrl.flatMap(URL.init(string:)) {
                        CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 40, height: 40).clipShape(Circle())
                    } else { Circle().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 40) }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(user.displayName).font(.subheadline).fontWeight(.semibold)
                            if user.isVerified == true { Image(systemName: "checkmark.seal.fill").foregroundColor(.blue) }
                        }
                        if let song = user.nowPlayingSong, let artist = user.nowPlayingArtist {
                            Text("\(song) — \(artist)").font(.caption).foregroundColor(.secondary).lineLimit(1)
                        } else {
                            Text("Not playing").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("Listening now")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Explore: Creator Logs Section
struct ExploreCreatorLogsSection: View {
    let title: String
    let logs: [MusicLog]
    let isLoading: Bool
    let onLoadMore: () -> Void
    let onSeeAll: () -> Void
    let visibleCount: Int
    let onSeeMore: () -> Void
    let onSeeLess: () -> Void
    var onVisible: ((String) -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline).fontWeight(.semibold)
                Spacer()
                Button(action: {
                    AnalyticsService.shared.logTap(category: "explore_see_all", id: title)
                    onSeeAll()
                }) {
                    HStack(spacing: 4) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                    }
                }.font(.subheadline).foregroundColor(.purple)
            }
            if isLoading && logs.isEmpty {
                VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in PopularLogSkeleton() } }
            } else if logs.isEmpty {
                Text("No posts yet").font(.subheadline).foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(logs.prefix(visibleCount)) { log in
                        PopularLogRow(log: log, reposterNames: nil)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .id(log.id)
                            .onAppear {
                                if log.id == logs.suffix(2).first?.id { onLoadMore() }
                                onVisible?(log.id)
                                AnalyticsService.shared.logImpression(category: "explore_row", id: log.id)
                            }
                    }
                    HStack(spacing: 12) {
                        if logs.count > visibleCount {
                            Button("See more") { onSeeMore() }
                        }
                        if visibleCount > 10 {
                            Button("See less") { onSeeLess() }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Explore: Creator Logs See-All
struct ExploreCreatorLogsListView: View {
    let title: String
    let logs: [MusicLog]
    let loadMore: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List(logs) { log in
                PopularLogRow(log: log, reposterNames: nil)
                    .onAppear {
                        if log.id == logs.suffix(2).first?.id { loadMore() }
                    }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .refreshable { loadMore() }
        }
    }
}

// MARK: - Weekly Popular Logs (See All)
struct WeeklyPopularListView: View {
    let initialLogs: [MusicLog]
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [MusicLog] = []
    @State private var isLoading = false
    @State private var lastDateCursor: Date? = nil

    var body: some View {
        NavigationView {
            List {
                ForEach(logs) { log in
                    PopularLogRow(log: log, reposterNames: nil)
                }
                if isLoading { HStack { Spacer(); ProgressView(); Spacer() } }
            }
            .navigationTitle("Popular This Week")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { if logs.isEmpty { logs = initialLogs; lastDateCursor = Date() } }
            .onScrollNearBottom(perform: loadMore)
        }
    }

    private func loadMore() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                let db = Firestore.firestore()
                var query: Query = db.collection("logs").order(by: "dateLogged", descending: true)
                if let cursor = lastDateCursor { query = query.whereField("dateLogged", isLessThan: cursor) }
                let snap = try await query.limit(to: 200).getDocuments()
                let fetched = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                self.lastDateCursor = fetched.last?.dateLogged ?? self.lastDateCursor
                let cfg = ScoringConfig.shared
                func score(_ log: MusicLog) -> Double {
                    let likes = Double(log.isLiked == true ? 1 : 0)
                    let helpful = Double(log.helpfulCount ?? 0)
                    let unhelpful = Double(log.unhelpfulCount ?? 0)
                    let comments = Double(log.commentCount ?? 0)
                    let rating = Double(log.rating ?? 0)
                    return helpful * cfg.helpfulWeight + comments * cfg.commentsWeight + likes * cfg.likesWeight + rating * cfg.ratingWeight - unhelpful * cfg.unhelpfulPenalty
                }
                let more = fetched.sorted { score($0) > score($1) }
                self.logs.append(contentsOf: more.prefix(20))
                isLoading = false
            } catch {
                isLoading = false
            }
        }
    }
}

struct CreatorLogsListView: View {
    let userId: String
    let displayName: String
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [MusicLog] = []
    @State private var isLoading = false
    @State private var lastDoc: DocumentSnapshot? = nil
    @State private var reachedEnd = false

    var body: some View {
        NavigationView {
            List {
                ForEach(logs) { log in
            if let review = log.review, !review.isEmpty {
                EnhancedReviewView(log: log, showFullDetails: false)
                    } else {
                        HStack(spacing: 12) {
                    if let artwork = log.artworkUrl, let url = URL(string: artwork) {
                        CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                                .frame(width: 48, height: 48).cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(width: 48, height: 48)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.title).font(.subheadline).fontWeight(.medium).lineLimit(1)
                                Text(log.artistName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                }
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if !reachedEnd {
                    Button("Load more") { loadMore() }
                }
            }
            .navigationTitle("\(displayName)'s posts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { if logs.isEmpty { loadInitial() } }
        }
    }

    private func loadInitial() {
        isLoading = true
        Task {
            do {
                let db = Firestore.firestore()
                let snap = try await db.collection("logs")
                    .whereField("userId", isEqualTo: userId)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 20)
                    .getDocuments()
                let fetched = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                self.logs = fetched
                self.lastDoc = snap.documents.last
                self.reachedEnd = fetched.isEmpty
                self.isLoading = false
            } catch {
                self.isLoading = false
            }
        }
    }

    private func loadMore() {
        guard !isLoading, !reachedEnd, let last = lastDoc else { return }
        isLoading = true
        Task {
            do {
                let db = Firestore.firestore()
                let snap = try await db.collection("logs")
                    .whereField("userId", isEqualTo: userId)
                    .order(by: "dateLogged", descending: true)
                    .start(afterDocument: last)
                    .limit(to: 20)
                    .getDocuments()
                let fetched = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                self.logs.append(contentsOf: fetched)
                self.lastDoc = snap.documents.last
                self.reachedEnd = fetched.isEmpty
                self.isLoading = false
            } catch {
                self.isLoading = false
            }
        }
    }
}

// Popular Logs Section removed per redesign

private struct PopularLogSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 140, height: 10)
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3)).frame(width: 100, height: 8)
            }
            Spacer()
        }
        .redacted(reason: .placeholder)
        .shimmer()
    }
}

struct PopularLogRow: View {
    let log: MusicLog
    var reposterNames: [String]? = nil
    @State private var showDetail = false
    @State private var userProfile: UserProfile? = nil
    @State private var showUserProfile = false
    @State private var showingComments = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Artwork → item profile
                Button(action: { showDetail = true }) {
                    Group {
                        if let artwork = log.artworkUrl, let url = URL(string: artwork) {
                            CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 64, height: 64)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    // Title and artist → item profile
                    Button(action: { showDetail = true }) {
                        Text(log.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }.buttonStyle(.plain)
                    if !log.artistName.isEmpty {
                        Button(action: { showDetail = true }) {
                            Text(log.artistName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }.buttonStyle(.plain)
                    }
                    // Username + rating + privacy → user profile
                    HStack(spacing: 8) {
                        Button(action: { showUserProfile = true }) {
                            HStack(spacing: 6) {
                                if let urlString = userProfile?.profilePictureUrl, let url = URL(string: urlString) {
                                    CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                                        .frame(width: 18, height: 18)
                                        .clipShape(Circle())
                                } else {
                                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 18, height: 18)
                                }
                                Text("@\(userProfile?.username ?? "user")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }.buttonStyle(.plain)
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
                            HStack(spacing: 4) { Image(systemName: "lock.fill").font(.caption2); Text("Private").font(.caption2) }
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.2)).cornerRadius(6)
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
            // Repost attribution
            if let names = reposterNames, !names.isEmpty {
                let display: String = {
                    if names.count == 1 { return "Reposted by @\(names[0])" }
                    if names.count == 2 { return "Reposted by @\(names[0]) and @\(names[1])" }
                    return "Reposted by @\(names[0]), @\(names[1]) and \(names.count - 2) others"
                }()
                Text(display)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            // Comment snippet or fallback
            if let review = log.review, !review.isEmpty {
                ReviewSnippetView(text: review, limit: 180)
            }
            EngagementBar(log: log, onComments: { showingComments = true })
            FriendsCommentsPreview(log: log, maxCount: 2)
            FriendsCommentsMoreInline(log: log)
            FriendsCommentsMoreInline(log: log)
        }
        .padding(12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            AnalyticsService.shared.logTap(category: "popular_row", id: log.id)
            showDetail = true
        }
        .fullScreenCover(isPresented: $showDetail) {
            let result = MusicSearchResult(id: log.itemId, title: log.title, artistName: log.artistName, albumName: "", artworkURL: log.artworkUrl, itemType: log.itemType, popularity: 0)
            MusicProfileView(musicItem: result, pinnedLog: log)
        }
        .sheet(isPresented: $showUserProfile) {
            UserProfileView(userId: log.userId)
        }
        .sheet(isPresented: $showingComments) {
            CommentsSheet(log: log)
        }
        .onAppear {
            AnalyticsService.shared.logImpression(category: "popular_row", id: log.id)
            if userProfile == nil {
                Task { await fetchUser() }
            }
        }
        .contextMenu {
            Button {
                NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: log.userId)
            } label: { Label("View Profile", systemImage: "person.crop.circle") }
            Button("Hide user") {
                Task { _ = await UserPreferencesService.shared.hideUser(log.userId) }
            }
            Button(role: .destructive) {
                Task { _ = await ReportsService.shared.report(target: .log(logId: log.id), reason: "inappropriate") }
            } label: { Label("Report", systemImage: "flag") }
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

    private func updateRatingInline(_ newValue: Int) {
        guard Auth.auth().currentUser?.uid == log.userId else { return }
        var updated = log
        updated.rating = newValue
        MusicLog.updateLog(updated) { _ in }
    }
}

// MARK: - Engagement Bar
struct EngagementBar: View {
    @State var log: MusicLog
    var onComments: () -> Void
    @State private var likeAnimating = false
    @State private var friendLikerProfiles: [UserProfile] = []
    var body: some View {
        HStack(spacing: 18) {
            Button(action: { toggleLike() }) {
                HStack(spacing: 4) {
                    Image(systemName: log.isLiked == true ? "heart.fill" : "heart")
                        .foregroundColor(log.isLiked == true ? .red : .secondary)
                        .scaleEffect(likeAnimating ? 1.2 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: likeAnimating)
                    Text("\(log.isLiked == true ? 1 : 0)").foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            // Friend likers (mutuals) avatar preview
            if !friendLikerProfiles.isEmpty {
                HStack(spacing: -8) {
                    ForEach(friendLikerProfiles.prefix(3), id: \.uid) { profile in
                        if let urlStr = profile.profilePictureUrl, let url = URL(string: urlStr) {
                            CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                                .frame(width: 18, height: 18)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        } else {
                            Circle()
                                .fill(Color.purple.opacity(0.25))
                                .frame(width: 18, height: 18)
                                .overlay(Text(String((profile.username ?? "").prefix(1)).uppercased()).font(.caption2).foregroundColor(.purple))
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        }
                    }
                }
                .padding(.leading, 2)
                .accessibilityLabel("Friends who liked")
            } else if UserDefaults.standard.bool(forKey: "feed.mockData") {
                // Mock fallback: always render 2–3 sample avatars in DEBUG mock to visualize the UI
                let names = ["alex", "sam", "jordan", "taylor", "morgan", "casey"]
                let count = 2 + (abs(log.id.hashValue) % 2) // 2 or 3
                HStack(spacing: -8) {
                    ForEach(0..<count, id: \.self) { idx in
                        let initial = String(names[(idx + 1) % names.count].prefix(1)).uppercased()
                        Circle()
                            .fill(Color.purple.opacity(0.25))
                            .frame(width: 18, height: 18)
                            .overlay(Text(initial).font(.caption2).foregroundColor(.purple))
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    }
                }
                .padding(.leading, 2)
            }
            Button(action: { onComments() }) {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble"); Text("\(log.commentCount ?? 0)")
                }.foregroundColor(.secondary)
            }.buttonStyle(.plain)
            Button(action: { vote(false) }) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsdown"); Text("\(log.unhelpfulCount ?? 0)")
                }.foregroundColor(.secondary)
            }.buttonStyle(.plain)
            Button(action: { toggleRepost() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath").foregroundColor(.secondary)
                    Text("Repost").foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            Spacer()
        }
        .font(.caption)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { toggleLike() }
        .onAppear { loadFriendLikerProfiles() }
    }
    private func toggleLike() {
        log.isLiked = !(log.isLiked ?? false)
        likeAnimating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { likeAnimating = false }
        MusicLog.updateLog(log) { _ in }
        AnalyticsService.shared.logEngagement(action: log.isLiked == true ? "like" : "unlike", contentType: "music_log", contentId: log.id, logId: log.id)
    }
    private func vote(_ helpful: Bool) {
        ReviewHelpfulVote.updateVote(logId: log.id, userId: log.userId, isHelpful: helpful) { _ in }
        AnalyticsService.shared.logEngagement(action: helpful ? "thumbs_up" : "thumbs_down", contentType: "music_log", contentId: log.id, logId: log.id)
    }
    private func toggleRepost() {
        guard let current = Auth.auth().currentUser?.uid else { return }
        Repost.hasReposted(userId: current, logId: log.id) { exists in
            if exists {
                Repost.remove(forUser: current, logId: log.id) { _ in }
                AnalyticsService.shared.logEngagement(action: "unrepost", contentType: "music_log", contentId: log.id, logId: log.id)
            } else {
                Repost.add(Repost(logId: log.id, userId: current)) { _ in }
                AnalyticsService.shared.logEngagement(action: "repost", contentType: "music_log", contentId: log.id, logId: log.id)
            }
        }
    }

    private func loadFriendLikerProfiles() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Set(followingIds).intersection(Set(followerIds))
            UserLike.getItemLikes(itemId: log.id, itemType: .review) { likes, _ in
                let likes = (likes ?? []).filter { mutuals.contains($0.userId) }
                let topIds = Array(likes.sorted { $0.createdAt > $1.createdAt }.prefix(3)).map { $0.userId }
                if topIds.isEmpty { return }
                // Fetch minimal profiles
                var results: [UserProfile] = []
                let group = DispatchGroup()
                for id in topIds {
                    group.enter()
                    db.collection("users").document(id).getDocument { doc, _ in
                        defer { group.leave() }
                        if let p = try? doc?.data(as: UserProfile.self) { results.append(p) }
                    }
                }
                group.notify(queue: .main) { self.friendLikerProfiles = results }
            }
        }
    }
}

// MARK: - Comments Sheet
struct CommentsSheet: View {
    let log: MusicLog
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [ReviewComment] = []
    @State private var text: String = ""
    @State private var isLoading = false
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List(comments) { c in
                    HStack(spacing: 8) {
                        if let url = c.userProfilePictureUrl.flatMap(URL.init(string:)) {
                            CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                                .frame(width: 28, height: 28).clipShape(Circle())
                        } else { Circle().fill(Color.gray.opacity(0.3)).frame(width: 28, height: 28) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.username).font(.caption).foregroundColor(.secondary)
                            Text(c.text).font(.subheadline)
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField("Add a comment", text: $text).textFieldStyle(.roundedBorder)
                    Button("Send") { post() }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { AnalyticsService.shared.logComments(action: "open", contentId: log.id); load() }
        }
    }
    private func load() {
        isLoading = true
        ReviewComment.fetchCommentsForLog(logId: log.id, limit: 50) { list, _ in
            self.comments = list ?? []
            self.isLoading = false
        }
    }
    private func post() {
        let uid = Auth.auth().currentUser?.uid ?? ""
        let comment = ReviewComment(logId: log.id, userId: uid, username: userProfileName(), userProfilePictureUrl: nil, text: text)
        ReviewComment.addComment(comment) { _ in AnalyticsService.shared.logComments(action: "post", contentId: log.id); load(); text = "" }
    }
    private func userProfileName() -> String { Auth.auth().currentUser?.email ?? "you" }
}

// MARK: - Friends' Comments Preview (up to N)
struct FriendsCommentsPreview: View {
    let log: MusicLog
    var maxCount: Int = 2
    var alwaysShowMock: Bool = false
    @State private var friendIds: [String] = []
    @State private var comments: [ReviewComment] = []
    @State private var hasLoaded = false
    @State private var totalFriendComments: Int = 0
    
    var body: some View {
        Group {
            if !comments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(comments.prefix(maxCount)) { c in
                        HStack(alignment: .top, spacing: 8) {
                            if let url = c.userProfilePictureUrl.flatMap(URL.init(string:)) {
                                CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                                    .frame(width: 18, height: 18)
                                    .clipShape(Circle())
                            } else {
                                Circle().fill(Color.gray.opacity(0.3)).frame(width: 18, height: 18)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(c.username)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(c.text)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .onAppear { if !hasLoaded { hasLoaded = true; Task { await load() } } }
    }
    
    private func loadMockIfEnabled() {
        let mockOn = UserDefaults.standard.bool(forKey: "feed.mockData") || alwaysShowMock
        guard mockOn else { return }
        let seed = abs(log.id.hashValue) % 100
        let friendNames = ["alex", "sam", "jordan", "taylor", "morgan", "casey"]
        let desired = max(2, min(3, maxCount))
        let count = alwaysShowMock ? desired : ((seed % 2) + 1)
        comments = (0..<count).map { idx in
            ReviewComment(logId: log.id, userId: "friend_\(idx)", username: friendNames[(seed + idx) % friendNames.count], userProfilePictureUrl: nil, text: idx == 0 ? "So good! Been looping this." : (idx == 1 ? "Underrated pick." : "This grows on you."))
        }
        totalFriendComments = comments.count
    }
    
    @MainActor
    private func load() async {
        loadMockIfEnabled()
        if !comments.isEmpty { return }
        do {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let data = userDoc.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Array(Set(followingIds).intersection(Set(followerIds)))
            self.friendIds = mutuals
            ReviewComment.fetchCommentsForLog(logId: log.id, limit: 50) { list, _ in
                let all = list ?? []
                let filtered = all.filter { friendIds.contains($0.userId) }
                // Fallback: if no friend comments, show recent comments from anyone
                let preferred = filtered.isEmpty ? all : filtered
                self.totalFriendComments = filtered.count
                self.comments = Array(preferred.prefix(maxCount))
            }
        } catch {
        }
    }
}

// MARK: - Inline 'View all friend comments' CTA
private struct FriendsCommentsMoreInline: View {
    let log: MusicLog
    @State private var totalFriendComments: Int = 0
    @State private var hasLoaded = false
    @State private var showingAll = false
    var body: some View {
        Group {
            if totalFriendComments > 2 {
                Button(action: { showingAll = true }) {
                    Text("View all friend comments (\(totalFriendComments))")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingAll) { CommentsSheet(log: log) }
            }
        }
        .onAppear { if !hasLoaded { hasLoaded = true; loadCount() } }
    }
    private func loadCount() {
        if UserDefaults.standard.bool(forKey: "feed.mockData") {
            let seed = abs(log.id.hashValue) % 100
            if seed % 3 == 0 { totalFriendComments = (seed % 2) + 3 }
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let following = (data["following"] as? [String]) ?? []
            let followers = (data["followers"] as? [String]) ?? []
            let mutuals = Set(following).intersection(Set(followers))
            ReviewComment.fetchCommentsForLog(logId: log.id, limit: 50) { list, _ in
                let count = (list ?? []).filter { mutuals.contains($0.userId) }.count
                self.totalFriendComments = count
            }
        }
    }
}

// MARK: - Followers Log Row (vertical, with cover art and comment)
struct FollowersLogRow: View {
    let log: MusicLog
    @State private var showDetail = false
    @State private var userProfile: UserProfile? = nil
    @State private var showUserProfile = false
    @State private var showingComments = false
    var reposterNames: [String]? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Artwork → item profile
                Button(action: { showDetail = true }) {
                    Group {
                        if let artwork = log.artworkUrl, let url = URL(string: artwork) {
                            CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: 64, height: 64)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    // Title and artist → item profile
                    Button(action: { showDetail = true }) {
                        Text(log.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }.buttonStyle(.plain)
                    if !log.artistName.isEmpty {
                        Button(action: { showDetail = true }) {
                            Text(log.artistName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }.buttonStyle(.plain)
                    }
                    // Username (with avatar) → user profile + rating + privacy
                    HStack(spacing: 8) {
                        Button(action: { showUserProfile = true }) {
                            HStack(spacing: 6) {
                                if let url = userProfile?.profilePictureUrl.flatMap(URL.init(string:)) {
                                    CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                                        .frame(width: 18, height: 18)
                                        .clipShape(Circle())
                                } else {
                                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 18, height: 18)
                                }
                                Text("@\(userProfile?.username ?? "user")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }.buttonStyle(.plain)
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
                            HStack(spacing: 4) { Image(systemName: "lock.fill").font(.caption2); Text("Private").font(.caption2) }
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.gray.opacity(0.2)).cornerRadius(6)
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
            // Repost attribution
            if let names = reposterNames, !names.isEmpty {
                let display: String = {
                    if names.count == 1 { return "Reposted by @\(names[0])" }
                    if names.count == 2 { return "Reposted by @\(names[0]) and @\(names[1])" }
                    return "Reposted by @\(names[0]), @\(names[1]) and \(names.count - 2) others"
                }()
                Text(display)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            // Comment snippet or fallback
            if let review = log.review, !review.isEmpty {
                ReviewSnippetView(text: review, limit: 200)
            }
            EngagementBar(log: log, onComments: { showingComments = true })
            FriendsCommentsPreview(log: log, maxCount: 2)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .onTapGesture { showDetail = true }
        .fullScreenCover(isPresented: $showDetail) {
            let result = MusicSearchResult(id: log.itemId, title: log.title, artistName: log.artistName, albumName: "", artworkURL: log.artworkUrl, itemType: log.itemType, popularity: 0)
            MusicProfileView(musicItem: result, pinnedLog: log)
        }
        .sheet(isPresented: $showUserProfile) {
            UserProfileView(userId: log.userId)
        }
        .onAppear { if userProfile == nil { Task { await fetchUser() } } }
        .contextMenu {
            Button {
                NotificationCenter.default.post(name: NSNotification.Name("OpenUserProfile"), object: log.userId)
            } label: { Label("View Profile", systemImage: "person.crop.circle") }
            Button("Hide user") { Task { _ = await UserPreferencesService.shared.hideUser(log.userId) } }
            Button(role: .destructive) { Task { _ = await ReportsService.shared.report(target: .log(logId: log.id), reason: "inappropriate") } } label: { Label("Report", systemImage: "flag") }
        }
        .sheet(isPresented: $showingComments) { CommentsSheet(log: log) }
    }
    private func fetchUser() async {
        do {
            let snap = try await Firestore.firestore().collection("users").document(log.userId).getDocument()
            if let profile = try? snap.data(as: UserProfile.self) {
                await MainActor.run { self.userProfile = profile }
            }
        } catch {}
    }
}

// MARK: - Genre Logs See-All (paged list)
struct GenreLogsListView: View {
    let genre: String
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [MusicLog] = []
    @State private var lastDoc: DocumentSnapshot? = nil
    @State private var isLoading = false
    @State private var reachedEnd = false
    
    var body: some View {
        NavigationView {
            List(logs) { log in
                PopularLogRow(log: log, reposterNames: nil)
                    .onAppear {
                        if log.id == logs.suffix(2).first?.id { loadMore() }
                    }
            }
            .navigationTitle("\(genre.capitalized) Logs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .overlay {
                if isLoading && logs.isEmpty { ProgressView().scaleEffect(1.2) }
            }
        }
        .onAppear { Task { await loadInitial() } }
    }
    
    private func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            // Hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let snap = try await Firestore.firestore().collection("logs")
                .whereField("genres", arrayContains: genre)
                .order(by: "dateLogged", descending: true)
                .limit(to: 30)
                .getDocuments()
            var fetched = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            fetched.removeAll { hidden.contains($0.userId) }
            self.logs = fetched
            self.lastDoc = snap.documents.last
            self.reachedEnd = fetched.isEmpty
            self.isLoading = false
        } catch {
            self.isLoading = false
        }
    }
    
    private func loadMore() {
        guard !isLoading, !reachedEnd, let last = lastDoc else { return }
        isLoading = true
        Task {
            do {
                await UserPreferencesService.shared.loadHiddenUsers()
                let hidden = UserPreferencesService.shared.hiddenUserIds
                let snap = try await Firestore.firestore().collection("logs")
                    .whereField("genres", arrayContains: genre)
                    .order(by: "dateLogged", descending: true)
                    .start(afterDocument: last)
                    .limit(to: 30)
                    .getDocuments()
                var fetched = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                fetched.removeAll { hidden.contains($0.userId) }
                self.logs.append(contentsOf: fetched)
                self.lastDoc = snap.documents.last
                self.reachedEnd = fetched.isEmpty
                self.isLoading = false
            } catch {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Review Snippet
struct ReviewSnippetView: View {
    let text: String
    let limit: Int
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(expanded ? text : String(text.prefix(limit)))
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if text.count > limit {
                Button(expanded ? "See less" : "See more") { expanded.toggle() }
                    .font(.caption)
                    .foregroundColor(.purple)
            }
        }
    }
}

// MARK: - Item Metadata
private struct ItemMetadataView: View {
    let log: MusicLog
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if log.itemType == "artist" {
                HStack(spacing: 6) {
                    TypeBadge(type: log.itemType)
                    LabelValueRow(label: "Artist", value: log.artistName.isEmpty ? log.title : log.artistName)
                }
            } else if log.itemType == "album" {
                HStack(spacing: 6) {
                    TypeBadge(type: log.itemType)
                    LabelValueRow(label: "Album", value: log.title)
                }
                LabelValueRow(label: "Artist", value: log.artistName)
            } else {
                HStack(spacing: 6) {
                    TypeBadge(type: log.itemType)
                    LabelValueRow(label: "Song", value: log.title)
                }
                LabelValueRow(label: "Artist", value: log.artistName)
            }
        }
    }
}

private struct TypeBadge: View {
    let type: String
    var body: some View {
        let fg: Color = {
            switch type.lowercased() {
            case "song": return .green
            case "artist": return .purple
            case "album": return .blue
            default: return .gray
            }
        }()
        Text(type.capitalized)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fg.opacity(0.15))
            .foregroundColor(fg)
            .clipShape(Capsule())
    }
}

private struct LabelValueRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(label):")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

// Popular See-All removed per redesign

// MARK: - Creators List (See All)
struct CreatorsListView: View {
    let items: [CreatorSpotlight]
    let loadMore: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items) { creator in
                    HStack(spacing: 12) {
                        if let urlString = creator.profilePictureUrl, let url = URL(string: urlString) {
                                CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 40, height: 40).clipShape(Circle())
                        } else {
                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 40)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(creator.displayName ?? creator.username).font(.subheadline).fontWeight(.semibold)
                                if creator.isVerified { Image(systemName: "checkmark.seal.fill").foregroundColor(.blue) }
                            }
                            if let log = creator.latestLog {
                                Text("Latest: \(log.title) — \(log.artistName)").font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { _ = await ReportsService.shared.report(target: .user(userId: creator.userId), reason: "inappropriate") }
                        } label: { Label("Report user", systemImage: "flag") }
                        Button("Hide user") {
                            Task { _ = await UserPreferencesService.shared.hideUser(creator.userId) }
                        }
                    }
                }
                Button("Load more") { loadMore() }
            }
            .navigationTitle("Creators")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
