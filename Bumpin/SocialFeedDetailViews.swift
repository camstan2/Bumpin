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
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if interval < 604800 { // Less than 7 days
            let days = Int(interval / 86400)
            return "\(days)d"
        } else if interval < 2592000 { // Less than 30 days
            let weeks = Int(interval / 604800)
            return "\(weeks)w"
        } else {
            let months = Int(interval / 2592000)
            return "\(months)mo"
        }
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
            .navigationTitle("Trending with Friends")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear {
                if itemsState.isEmpty { itemsState = initialItems }
                if lastCursorDate == nil { lastCursorDate = Date() }
            }
            .onScrollNearBottom(perform: loadMore)
        }
        .navigationViewStyle(.stack)
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
                    let avg = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
                    let normalizedAvg = TrendingItem.normalizedAverage(optional: avg)
                    return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: normalizedAvg, itemType: "song", itemId: itemId)
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
        .navigationViewStyle(.stack)
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
        // 🎯 Phase 3: Group by universalTrackId for cross-platform aggregation
        let grouped = Dictionary(grouping: logs) { log in
            log.universalTrackId ?? log.itemId // Fallback to itemId for old logs
        }
        return grouped.compactMap { (trackId, logs) in
            guard let first = logs.first else { return nil }
            let ratings = logs.compactMap { $0.rating }
            let avg = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            let normalizedAvg = TrendingItem.normalizedAverage(optional: avg)
            return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: normalizedAvg, itemType: "song", itemId: trackId)
        }
    }
    private func calculateTrendingAlbums(from logs: [MusicLog]) -> [TrendingItem] {
        // 🎯 Phase 3: Group by universalTrackId for cross-platform aggregation
        let grouped = Dictionary(grouping: logs) { log in
            log.universalTrackId ?? log.itemId // Fallback to itemId for old logs
        }
        return grouped.compactMap { (trackId, logs) in
            guard let first = logs.first else { return nil }
            let ratings = logs.compactMap { $0.rating }
            let avg = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            let normalizedAvg = TrendingItem.normalizedAverage(optional: avg)
            return TrendingItem(title: first.title, subtitle: first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: normalizedAvg, itemType: "album", itemId: trackId)
        }
    }
    private func calculateTrendingArtists(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.artistName }
        return grouped.compactMap { (artist, logs) in
            let ratings = logs.compactMap { $0.rating }
            let avg = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
            let normalizedAvg = TrendingItem.normalizedAverage(optional: avg)
            return TrendingItem(title: artist, subtitle: nil, artworkUrl: logs.first?.artworkUrl, logCount: logs.count, averageRating: normalizedAvg, itemType: "artist", itemId: artist)
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
        .navigationViewStyle(.stack)
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
                    let avg = ratings.isEmpty ? nil : ratings.reduce(0.0, +) / Double(ratings.count)
                    let normalizedAvg = TrendingItem.normalizedAverage(optional: avg)
                    return TrendingItem(title: first.title, subtitle: first.itemType == "artist" ? nil : first.artistName, artworkUrl: first.artworkUrl, logCount: logs.count, averageRating: normalizedAvg, itemType: first.itemType, itemId: first.itemId)
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
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        HStack(spacing: 12) {
            artworkView
            itemInfoView
            Spacer()
            trendingIndicator
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Use the same navigation pattern as the main trending sections
            navigationCoordinator.navigateToMusicProfile(item)
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
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    @State private var selectedReportLog: MusicLog?
    
    // MARK: - Subviews
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
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
    }
    
    @ViewBuilder
    private var reviewsSection: some View {
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
                                    Button {
                                        selectedReportLog = log
                                        showReportSheet = true
                                    } label: {
                                        Label("Report", systemImage: "flag")
                                    }
                                }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var repostSection: some View {
        HStack {
            Button(action: { toggleItemRepost() }) {
                Label(hasReposted ? "Unrepost" : "Repost", systemImage: "arrow.2.squarepath")
            }
            .buttonStyle(.bordered)
            .tint(.purple)
            Spacer()
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    Divider()
                    reviewsSection
                    repostSection
                }
                .padding()
            }
            .sheet(isPresented: $showReportSheet) {
                if let log = selectedReportLog {
                    ReportContentView(
                        contentId: log.id,
                        contentType: .musicReview,
                        reportedUserId: log.userId,
                        reportedUsername: "user",
                        contentPreview: log.review
                    )
                }
            }
            .sheet(isPresented: $showBlockSheet) {
                if let log = selectedReportLog {
                    BlockUserView(
                        userId: log.userId,
                        username: "user",
                        profilePictureUrl: log.artworkUrl
                    )
                }
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
        .navigationViewStyle(.stack)
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
        .navigationViewStyle(.stack)
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
                        StarRatingDisplayView(rating: rating, starSize: 10, spacing: 2)
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
                Button {
                    Task { _ = await ReportsService.shared.report(target: .log(logId: log.id), reason: "inappropriate") }
                } label: { Label("Report", systemImage: "flag") }
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
        .fullScreenCover(isPresented: $showingComments) {
            if let log = activity.musicLog { UnifiedLogCommentsView(log: log) }
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
        .fullScreenCover(isPresented: $showProfile) {
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
            .navigationViewStyle(.stack)
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
    @State private var selectedSong: MusicSearchResult?
    
    var body: some View {
        VStack(spacing: 8) {
            // Profile picture and username - tappable to view user profile
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
                }
            }
            .buttonStyle(PressableRowStyle())
            
            // Song and artist - clickable to view song profile
                if let song = user.nowPlayingSong, let artist = user.nowPlayingArtist {
                Button(action: {
                    AnalyticsService.shared.logTap(category: "friends_now_playing_song", id: "\(song)_\(artist)")
                    // Search for the song to get proper track ID
                    Task {
                        let searchResults = await UnifiedMusicSearchService.shared.search(query: "\(song) \(artist)", limit: 1)
                        if let firstSong = searchResults.songs.first {
                            await MainActor.run {
                                selectedSong = firstSong
                            }
                        } else {
                            print("⚠️ Could not find song in Apple Music: \(song) by \(artist)")
                            // Fallback: create a basic MusicSearchResult from the available info
                            await MainActor.run {
                                selectedSong = MusicSearchResult(
                                    id: UUID().uuidString,
                                    title: song,
                                    artistName: artist,
                                    albumName: "",
                                    artworkURL: user.nowPlayingAlbumArt,
                                    itemType: "song",
                                    popularity: 0
                                )
                            }
                        }
                    }
                }) {
                    Text("\(song) — \(artist)")
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: 140)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowOffset)
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
            .navigationViewStyle(.stack)
        }
        .fullScreenCover(item: $selectedSong) { musicItem in
            MusicProfileView(musicItem: musicItem, pinnedLog: nil)
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
                FriendsNowPlayingListRow(user: user)
            }
            .navigationTitle("Listening now")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Friends Now Playing: List Row
private struct FriendsNowPlayingListRow: View {
    let user: UserProfile
    @State private var showUserProfile = false
    @State private var selectedSong: MusicSearchResult?
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture and username - clickable to user profile
            Button(action: {
                AnalyticsService.shared.logTap(category: "friends_now_playing_list", id: user.uid)
                showUserProfile = true
            }) {
                HStack(spacing: 12) {
                    if let url = user.profilePictureUrl.flatMap(URL.init(string:)) {
                        CachedAsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 40, height: 40).clipShape(Circle())
                    } else { Circle().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 40) }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(user.displayName).font(.subheadline).fontWeight(.semibold)
                            if user.isVerified == true { Image(systemName: "checkmark.seal.fill").foregroundColor(.blue).font(.caption2) }
                        }
                        
                        // Show placeholder if not playing
                        if user.nowPlayingSong == nil || user.nowPlayingArtist == nil {
                            Text("Not playing").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Song and artist - clickable to song profile (only if playing)
                        if let song = user.nowPlayingSong, let artist = user.nowPlayingArtist {
                Button(action: {
                    AnalyticsService.shared.logTap(category: "friends_now_playing_list_song", id: "\(song)_\(artist)")
                    // Search for the song to get proper track ID
                    Task {
                        let searchResults = await UnifiedMusicSearchService.shared.search(query: "\(song) \(artist)", limit: 1)
                        if let firstSong = searchResults.songs.first {
                            await MainActor.run {
                                selectedSong = firstSong
                            }
                        } else {
                            print("⚠️ Could not find song in Apple Music: \(song) by \(artist)")
                            // Fallback: create a basic MusicSearchResult from the available info
                            await MainActor.run {
                                selectedSong = MusicSearchResult(
                                    id: UUID().uuidString,
                                    title: song,
                                    artistName: artist,
                                    albumName: "",
                                    artworkURL: user.nowPlayingAlbumArt,
                                    itemType: "song",
                                    popularity: 0
                                )
                            }
                        }
                    }
                }) {
                    Text("\(song) — \(artist)")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
                        }
            
                    Spacer()
                }
        .fullScreenCover(isPresented: $showUserProfile) {
            NavigationView {
                UserProfileView(userId: user.uid)
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
            .navigationViewStyle(.stack)
        }
        .fullScreenCover(item: $selectedSong) { musicItem in
            MusicProfileView(musicItem: musicItem, pinnedLog: nil)
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
        .navigationViewStyle(.stack)
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
            .navigationTitle("Community Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { if logs.isEmpty { logs = initialLogs; lastDateCursor = Date() } }
            .onScrollNearBottom(perform: loadMore)
        }
        .navigationViewStyle(.stack)
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
                // Use new engagement scoring service
                let more = EngagementScoringService.shared.sortByEngagement(fetched)
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
        .navigationViewStyle(.stack)
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
    @State private var resolvedAppleMusicId: String? = nil
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    
    // New engagement state
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var hasThumbsDown: Bool = false
    @State private var thumbsDownCount: Int = 0
    @State private var hasReposted: Bool = false
    @State private var repostCount: Int = 0
    @State private var showReposters = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Artwork → item profile
                Button(action: {
                    Task { await resolveAppleMusicIdAndShowDetail() }
                }) {
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
                    Button(action: {
                        Task { await resolveAppleMusicIdAndShowDetail() }
                    }) {
                        Text(log.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }.buttonStyle(.plain)
                    if !log.artistName.isEmpty {
                        Button(action: {
                            Task { await resolveAppleMusicIdAndShowDetail() }
                        }) {
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
                            StarRatingDisplayView(
                                rating: rating,
                                starSize: 10,
                                spacing: 1
                            )
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
            Task { await resolveAppleMusicIdAndShowDetail() }
        }
        .fullScreenCover(isPresented: $showDetail) {
            let itemIdToUse = resolvedAppleMusicId ?? log.itemId
            let result = MusicSearchResult(id: itemIdToUse, title: log.title, artistName: log.artistName, albumName: "", artworkURL: log.artworkUrl, itemType: log.itemType, popularity: 0)
            MusicProfileView(musicItem: result, pinnedLog: log)
        }
        .fullScreenCover(isPresented: $showUserProfile) {
            // Show simplified profile (overview only, with back button) when opened from log cards
            UserProfileView(userId: log.userId, showFullProfile: false)
        }
        .fullScreenCover(isPresented: $showingComments) {
            UnifiedLogCommentsView(log: log)
        }
        .onAppear {
            AnalyticsService.shared.logImpression(category: "popular_row", id: log.id)
            if userProfile == nil {
                Task { await fetchUser() }
            }
            
            // Load engagement state from cache or Firestore
            if let currentUserId = Auth.auth().currentUser?.uid {
                Task {
                    let engagement = await LogEngagementCache.shared.getEngagement(logId: log.id, userId: currentUserId)
                    await MainActor.run {
                        isLiked = engagement.isLiked
                        hasThumbsDown = engagement.hasThumbsDown
                        hasReposted = engagement.hasReposted
                    }
                }
            }
            
            likeCount = log.likeCount ?? 0
            repostCount = log.repostCount ?? 0
        }
        .contextMenu {
            Button {
                showReportSheet = true
            } label: { Label("Report", systemImage: "flag") }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentId: log.id,
                contentType: .musicReview,
                reportedUserId: log.userId,
                reportedUsername: "user",
                contentPreview: log.review
            )
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockUserView(
                userId: log.userId,
                username: "user",
                profilePictureUrl: log.artworkUrl
            )
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
                    async let setLike = likeRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    async let updateCount = db.collection("logs").document(log.id).updateData([
                        "likeCount": FieldValue.increment(Int64(1))
                    ])
                    
                    try await (setLike, updateCount)
                    
                    // Create notification in background
                    Task.detached(priority: .utility) {
                        await NotificationService.shared.createLikeNotification(
                            logId: log.id,
                            logOwnerId: log.userId,
                            log: log
                        )
                    }
                    
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
    
    private func fetchUser() async {
        do {
            let snap = try await Firestore.firestore().collection("users").document(log.userId).getDocument()
            if let profile = try? snap.data(as: UserProfile.self) {
                await MainActor.run { self.userProfile = profile }
            }
        } catch { }
    }
    
    private func resolveAppleMusicIdAndShowDetail() async {
        // First, check if this log is already from Apple Music
        if let platform = log.musicPlatform, platform.lowercased().contains("apple") {
            // Already Apple Music, use itemId directly
            print("✅ Log is from Apple Music, using itemId directly: \(log.itemId)")
            await MainActor.run {
                resolvedAppleMusicId = log.itemId
                showDetail = true
            }
            return
        }
        
        // Check if we have a universalTrackId that we can resolve
        if let universalId = log.universalTrackId {
            print("🔍 Resolving universal track ID to Apple Music ID: \(universalId)")
            
            // Fetch the universal track
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                UniversalTrack.findById(universalId) { universalTrack in
                    if let track = universalTrack, let appleMusicId = track.appleMusicId {
                        print("✅ Found Apple Music ID from universal track: \(appleMusicId)")
                        Task { @MainActor in
                            self.resolvedAppleMusicId = appleMusicId
                            self.showDetail = true
                            continuation.resume()
                        }
                    } else {
                        print("⚠️ No Apple Music ID found in universal track, falling back to log.itemId")
                        Task { @MainActor in
                            self.resolvedAppleMusicId = log.itemId
                            self.showDetail = true
                            continuation.resume()
                        }
                    }
                }
            }
        } else {
            // No universal track ID, use itemId as fallback
            print("⚠️ No universal track ID or platform info, using log.itemId as fallback: \(log.itemId)")
            await MainActor.run {
                resolvedAppleMusicId = log.itemId
                showDetail = true
            }
        }
    }

    private func updateRatingInline(_ newValue: Double) {
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
    
    // New engagement state
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var hasThumbsDown: Bool = false
    @State private var thumbsDownCount: Int = 0
    @State private var hasReposted: Bool = false
    @State private var repostCount: Int = 0
    @State private var showActivity = false
    
    // Optimistic update helpers
    @State private var likeTask: Task<Void, Never>?
    @State private var repostTask: Task<Void, Never>?
    @State private var thumbsDownTask: Task<Void, Never>?
    @State private var isProcessingLike = false
    @State private var isProcessingRepost = false
    @State private var isProcessingThumbsDown = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Like button
            Button(action: { toggleLike() }) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .symbolEffect(.bounce, value: isLiked)
                    Text("\(likeCount)")
                        .contentTransition(.numericText())
                }
            }
            .foregroundColor(isLiked ? .red : .secondary)
            .scaleEffect(isLiked ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
            .buttonStyle(PlainButtonStyle())
            
            // Comment button
            Button(action: { 
                LogEngagementHaptics.comment()
                onComments() 
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                    Text("\(log.commentCount ?? 0)")
                }
            }
            .foregroundColor(.secondary)
            .buttonStyle(PlainButtonStyle())
            
            // Thumbs down button
            Button(action: { toggleThumbsDown() }) {
                HStack(spacing: 4) {
                    Image(systemName: hasThumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .symbolEffect(.bounce, value: hasThumbsDown)
                    if thumbsDownCount > 0 {
                        Text("\(thumbsDownCount)")
                            .contentTransition(.numericText())
                    }
                }
            }
            .foregroundColor(.secondary)
            .scaleEffect(hasThumbsDown ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasThumbsDown)
            .buttonStyle(PlainButtonStyle())
            
            // Repost button
            Button(action: { handleRepost() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .foregroundColor(hasReposted ? .green : .secondary)
                        .symbolEffect(.bounce, value: hasReposted)
                    if repostCount > 0 {
                        Text("\(repostCount)")
                            .contentTransition(.numericText())
                    }
                }
            }
            .foregroundColor(.secondary)
            .scaleEffect(hasReposted ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasReposted)
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
        .onAppear {
            loadEngagement()
        }
        .fullScreenCover(isPresented: $showActivity) {
            LogActivityView(logId: log.id, log: log)
        }
    }
    
    private func loadEngagement() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        likeCount = log.likeCount ?? 0
        repostCount = log.repostCount ?? 0
        thumbsDownCount = log.thumbsDownCount ?? 0
        
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
        guard let currentUserId = Auth.auth().currentUser?.uid,
              !isProcessingLike else { return }
        
        isProcessingLike = true
        
        // Save previous state for rollback
        let previousLikedState = isLiked
        let previousCount = likeCount
        
        // ✨ OPTIMISTIC UPDATE: Update UI IMMEDIATELY
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        
        // Update cache immediately
        LogEngagementCache.shared.updateEngagement(logId: log.id, isLiked: isLiked)
        
        // Haptic feedback (instant)
        if isLiked {
            LogEngagementHaptics.like()
        } else {
            LogEngagementHaptics.unlike()
        }
        
        print("🔍 [EngagementBar] toggleLike - optimistic update: \(isLiked)")
        
        // Cancel any pending like request
        likeTask?.cancel()
        
        // Network request in background (non-blocking)
        likeTask = Task(priority: .userInitiated) {
            // Small debounce delay
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            
            guard !Task.isCancelled else { 
                await MainActor.run { isProcessingLike = false }
                return 
            }
            
            do {
                let db = Firestore.firestore()
                let likeRef = db.collection("logs").document(log.id).collection("likes").document(currentUserId)
                
                if previousLikedState {
                    // Was liked, now unlike
                    print("🔍 [EngagementBar] Syncing unlike to server...")
                    try await likeRef.delete()
                    try await db.collection("logs").document(log.id).updateData([
                        "likeCount": FieldValue.increment(Int64(-1))
                    ])
                } else {
                    // Was not liked, now like
                    print("🔍 [EngagementBar] Syncing like to server...")
                    async let setLike = likeRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    async let updateCount = db.collection("logs").document(log.id).updateData([
                        "likeCount": FieldValue.increment(Int64(1))
                    ])
                    
                    try await (setLike, updateCount)
                    
                    // Create notification in background (lowest priority)
                    Task.detached(priority: .utility) {
                        await NotificationService.shared.createLikeNotification(
                            logId: log.id,
                            logOwnerId: log.userId,
                            log: log
                        )
                    }
                }
                
                print("✅ [EngagementBar] Like synced successfully")
                
                await MainActor.run {
                    isProcessingLike = false
                }
                
            } catch {
                // ⚠️ Network failed - ROLLBACK to previous state
                print("❌ [EngagementBar] Like sync failed, rolling back: \(error)")
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isLiked = previousLikedState
                        likeCount = previousCount
                    }
                    LogEngagementCache.shared.updateEngagement(logId: log.id, isLiked: previousLikedState)
                    isProcessingLike = false
                }
            }
        }
    }
    
    private func toggleThumbsDown() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              !isProcessingThumbsDown else { return }
        
        isProcessingThumbsDown = true
        
        // Save previous state for rollback
        let previousState = hasThumbsDown
        let previousCount = thumbsDownCount
        
        // ✨ OPTIMISTIC UPDATE: Update UI IMMEDIATELY
        hasThumbsDown.toggle()
        thumbsDownCount += hasThumbsDown ? 1 : -1
        if thumbsDownCount < 0 { thumbsDownCount = 0 }
        
        // Update cache immediately
        LogEngagementCache.shared.updateEngagement(logId: log.id, hasThumbsDown: hasThumbsDown)
        
        // Haptic feedback (instant)
        LogEngagementHaptics.thumbsDown()
        
        print("🔍 [EngagementBar] toggleThumbsDown - optimistic update: \(hasThumbsDown)")
        
        // Cancel any pending request
        thumbsDownTask?.cancel()
        
        // Network request in background
        thumbsDownTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            guard !Task.isCancelled else {
                await MainActor.run { isProcessingThumbsDown = false }
                return
            }
            
            do {
                let db = Firestore.firestore()
                let thumbsDownRef = db.collection("logs").document(log.id).collection("thumbsDown").document(currentUserId)
                
                if previousState {
                    // Was thumbs down, now remove
                    print("🔍 [EngagementBar] Syncing thumbs down removal...")
                    try await thumbsDownRef.delete()
                    try await db.collection("logs").document(log.id).updateData([
                        "thumbsDownCount": FieldValue.increment(Int64(-1))
                    ])
                } else {
                    // Was not thumbs down, now add
                    print("🔍 [EngagementBar] Syncing thumbs down add...")
                    async let setThumbsDown = thumbsDownRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    async let updateCount = db.collection("logs").document(log.id).updateData([
                        "thumbsDownCount": FieldValue.increment(Int64(1))
                    ])
                    
                    try await (setThumbsDown, updateCount)
                    
                    // Create notification in background
                    Task.detached(priority: .utility) {
                        await NotificationService.shared.createDislikeNotification(
                            logId: log.id,
                            logOwnerId: log.userId,
                            log: log
                        )
                    }
                }
                
                print("✅ [EngagementBar] Thumbs down synced successfully")
                
                await MainActor.run {
                    isProcessingThumbsDown = false
                }
                
            } catch {
                // ⚠️ ROLLBACK
                print("❌ [EngagementBar] Thumbs down sync failed, rolling back: \(error)")
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasThumbsDown = previousState
                        thumbsDownCount = previousCount
                    }
                    LogEngagementCache.shared.updateEngagement(logId: log.id, hasThumbsDown: previousState)
                    isProcessingThumbsDown = false
                }
            }
        }
    }
    
    private func handleRepost() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              !isProcessingRepost else { return }
        
        isProcessingRepost = true
        
        // Save previous state for rollback
        let previousRepostedState = hasReposted
        let previousCount = repostCount
        
        // ✨ OPTIMISTIC UPDATE: Update UI IMMEDIATELY
        hasReposted.toggle()
        repostCount += hasReposted ? 1 : -1
        
        // Update cache immediately
        LogEngagementCache.shared.updateEngagement(logId: log.id, hasReposted: hasReposted)
        
        // Haptic feedback (instant)
        if hasReposted {
            LogEngagementHaptics.repost()
        } else {
            LogEngagementHaptics.unrepost()
        }
        
        print("🔍 [EngagementBar] handleRepost - optimistic update: hasReposted=\(hasReposted), count=\(repostCount)")
        
        // Cancel any pending request
        repostTask?.cancel()
        
        // Network request in background
        repostTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            guard !Task.isCancelled else {
                await MainActor.run { isProcessingRepost = false }
                return
            }
            
            do {
                let db = Firestore.firestore()
                let repostRef = db.collection("logs").document(log.id).collection("reposts").document(currentUserId)
                
                if previousRepostedState {
                    // Was reposted, now remove
                    print("🔍 [EngagementBar] Syncing repost removal...")
                    try await repostRef.delete()
                    try await db.collection("logs").document(log.id).updateData([
                        "repostCount": FieldValue.increment(Int64(-1))
                    ])
                } else {
                    // Was not reposted, now add
                    print("🔍 [EngagementBar] Syncing repost add...")
                    async let setRepost = repostRef.setData([
                        "userId": currentUserId,
                        "timestamp": FieldValue.serverTimestamp()
                    ])
                    async let updateCount = db.collection("logs").document(log.id).updateData([
                        "repostCount": FieldValue.increment(Int64(1))
                    ])
                    
                    try await (setRepost, updateCount)
                    
                    // Create notification in background
                    Task.detached(priority: .utility) {
                        await NotificationService.shared.createRepostNotification(
                            logId: log.id,
                            logOwnerId: log.userId,
                            log: log
                        )
                    }
                }
                
                print("✅ [EngagementBar] Repost synced successfully")
                
                await MainActor.run {
                    isProcessingRepost = false
                }
                
            } catch {
                // ⚠️ ROLLBACK
                print("❌ [EngagementBar] Repost sync failed, rolling back: \(error)")
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasReposted = previousRepostedState
                        repostCount = previousCount
                    }
                    LogEngagementCache.shared.updateEngagement(logId: log.id, hasReposted: previousRepostedState)
                    isProcessingRepost = false
                }
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
        .navigationViewStyle(.stack)
    }
    private func load() {
        isLoading = true
        ReviewComment.fetchCommentsForLog(logId: log.id, limit: 50) { list, _ in
            self.comments = list ?? []
            self.isLoading = false
        }
    }
    private func post() {
        Task {
            guard let context = await ReviewComment.currentUserContext() else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            let comment = ReviewComment(
                logId: log.id,
                userId: context.userId,
                username: context.username,
                userProfilePictureUrl: context.profilePictureUrl,
                text: trimmed
            )
            ReviewComment.addComment(comment) { _ in
                AnalyticsService.shared.logComments(action: "post", contentId: log.id)
                load()
                text = ""
            }
        }
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
    @State private var isPressed = false  // DESIGN ENHANCEMENT: Press state
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
                            StarRatingDisplayView(
                                rating: rating,
                                starSize: 10,
                                spacing: 1
                            )
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
        // DESIGN ENHANCEMENT: Press state micro-interaction
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onTapGesture { showDetail = true }
        .fullScreenCover(isPresented: $showDetail) {
            let result = MusicSearchResult(id: log.itemId, title: log.title, artistName: log.artistName, albumName: "", artworkURL: log.artworkUrl, itemType: log.itemType, popularity: 0)
            MusicProfileView(musicItem: result, pinnedLog: log)
        }
        .fullScreenCover(isPresented: $showUserProfile) {
            // Show simplified profile (overview only, with back button) when opened from log cards
            UserProfileView(userId: log.userId, showFullProfile: false)
        }
        .onAppear { if userProfile == nil { Task { await fetchUser() } } }
        .contextMenu {
            Button(role: .destructive) { Task { _ = await ReportsService.shared.report(target: .log(logId: log.id), reason: "inappropriate") } } label: { Label("Report", systemImage: "flag") }
        }
        .fullScreenCover(isPresented: $showingComments) { UnifiedLogCommentsView(log: log) }
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
        .navigationViewStyle(.stack)
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
        .navigationViewStyle(.stack)
    }
}

