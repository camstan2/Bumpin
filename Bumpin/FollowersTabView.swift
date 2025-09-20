import SwiftUI
import FirebaseAuth
import FirebaseFirestore

final class FollowersFeedViewModel: ObservableObject {
    enum Section: String, CaseIterable { case friends = "Friends", following = "Following", trending = "Trending" }
    enum Ordering: String { case blended, mostRecent }

    @Published var selectedSection: Section = .friends
    @Published var ordering: Ordering = (UserDefaults.standard.string(forKey: "followersOrdering").flatMap { Ordering(rawValue: $0) }) ?? .blended
    @Published var isLoadingInitial = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    @Published var friendsLogs: [MusicLog] = []
    @Published var followingLogs: [MusicLog] = []
    @Published var trendingLogs: [MusicLog] = []
    @Published var repostersByLogId: [String: [String]] = [:]

    private let db = Firestore.firestore()
    private let calendar = Calendar.current
    private var friendsOldestDate: Date? = nil
    private var followingOldestDate: Date? = nil
    private var trendingOldestDate: Date? = nil
    // Track affinity sets for scoring
    private var mutualIds: Set<String> = []
    private var followingOnlyIds: Set<String> = []

    func load() async {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "feed.mockData") {
            await MainActor.run { self.isLoadingInitial = true; self.errorMessage = nil }
            // Generate mock data for Friends, Following, and Trending
            let friends = Self.generateMockLogs(count: 12, userPrefix: "friend", hoursBack: 36)
            let followingOnly = Self.generateMockLogs(count: 16, userPrefix: "follow", hoursBack: 48)
            let combined = friends + followingOnly
            let trending = scoreAndSortLogs(combined)
            await MainActor.run {
                self.friendsLogs = self.applyOrdering(friends)
                self.followingLogs = self.applyOrdering(followingOnly)
                self.trendingLogs = trending
                // Mock some repost attributions
                var attrib: [String: [String]] = [:]
                for (idx, log) in self.followingLogs.enumerated() where idx % 4 == 0 {
                    attrib[log.id] = ["alex", "sam"].prefix(Int.random(in: 1...2)).map { $0 }
                }
                for (idx, log) in self.friendsLogs.enumerated() where idx % 5 == 0 {
                    attrib[log.id, default: []].append("jordan")
                }
                self.repostersByLogId = attrib
                self.friendsOldestDate = self.friendsLogs.last?.dateLogged
                self.followingOldestDate = self.followingLogs.last?.dateLogged
                self.trendingOldestDate = self.trendingLogs.last?.dateLogged
                self.isLoadingInitial = false
            }
            return
        }
        #endif
        guard let uid = Auth.auth().currentUser?.uid else { return }
        await MainActor.run { self.isLoadingInitial = true; self.errorMessage = nil }
        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let data = userDoc.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Set(followingIds).intersection(Set(followerIds))
            let followingOnly = Set(followingIds).subtracting(mutuals)
            self.mutualIds = mutuals
            self.followingOnlyIds = followingOnly

            // Hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds

            async let friendsFetch: [MusicLog] = fetchLogs(for: Array(mutuals.filter { !hidden.contains($0) }))
            async let followingFetch: [MusicLog] = fetchLogs(for: Array(followingOnly.filter { !hidden.contains($0) }))
            let (friends, followingLogs) = try await (friendsFetch, followingFetch)

            let trending = scoreAndSortLogs(friends + followingLogs)

            // Include reposted logs from people you follow/friends
            let hiddenSet = hidden
            let mutualsSet = Set(mutuals)
            let followingOnlySet = Set(followingOnly)
            let repostResult = try await loadReposts(mutuals: mutualsSet, followingOnly: followingOnlySet, hidden: hiddenSet)
            await MainActor.run {
                self.friendsLogs = self.applyOrdering(friends)
                self.followingLogs = self.applyOrdering(followingLogs)
                // Merge reposted logs
                if !repostResult.friends.isEmpty {
                    self.friendsLogs = self.applyOrdering(self.mergeUnique(existing: self.friendsLogs, new: repostResult.friends))
                }
                if !repostResult.following.isEmpty {
                    self.followingLogs = self.applyOrdering(self.mergeUnique(existing: self.followingLogs, new: repostResult.following))
                }
                self.trendingLogs = trending
                // Attribution map
                self.repostersByLogId = repostResult.attribution
                self.friendsOldestDate = self.friendsLogs.last?.dateLogged
                self.followingOldestDate = self.followingLogs.last?.dateLogged
                self.trendingOldestDate = self.trendingLogs.last?.dateLogged
                self.isLoadingInitial = false
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription; self.isLoadingInitial = false }
        }
    }

    private func fetchLogs(for userIds: [String], before: Date? = nil) async throws -> [MusicLog] {
        guard !userIds.isEmpty else { return [] }
        var all: [MusicLog] = []
        for batch in userIds.chunked(into: 10) {
            let snap = try await db.collection("logs")
                .whereField("userId", in: batch)
                .order(by: "dateLogged", descending: true)
                .limit(to: 150)
                .getDocuments()
            var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            if let cutoff = before { logs = logs.filter { $0.dateLogged < cutoff } }
            all.append(contentsOf: logs)
        }
        // Deduplicate by id
        var map: [String: MusicLog] = [:]
        for l in all { map[l.id] = l }
        return Array(map.values)
    }

    private func scoreAndSortLogs(_ logs: [MusicLog]) -> [MusicLog] {
        let cfg = ScoringConfig.shared
        func score(_ log: MusicLog) -> Double {
            // Engagement component
            let helpful = Double(log.helpfulCount ?? 0)
            let comments = Double(log.commentCount ?? 0)
            let rating = Double(log.rating ?? 0)
            let unhelpful = Double(log.unhelpfulCount ?? 0)
            let reposts = Double((repostersByLogId[log.id]?.count ?? 0))
            let engagement = max(0.0,
                helpful * cfg.helpfulWeight +
                comments * cfg.commentsWeight +
                rating * cfg.ratingWeight -
                unhelpful * cfg.unhelpfulPenalty +
                reposts * cfg.repostWeight
            )

            // Recency (exponential decay, multiplicative)
            let ageHours = Date().timeIntervalSince(log.dateLogged) / 3600.0
            let recencyFactor = pow(exp(-ageHours / cfg.decayHours), cfg.recencyWeightMultiplier)

            // Affinity boost (mutuals > following-only)
            let affinityBoost: Double = {
                if mutualIds.contains(log.userId) { return 1.0 + cfg.mutualBoost }
                if followingOnlyIds.contains(log.userId) { return 1.0 + cfg.followingBoost }
                return 1.0
            }()

            // Final blended score (multiplicative mix)
            return engagement * recencyFactor * affinityBoost
        }
        return logs.sorted { score($0) > score($1) }
    }

    private func applyOrdering(_ logs: [MusicLog]) -> [MusicLog] {
        switch ordering {
        case .mostRecent:
            return logs.sorted { $0.dateLogged > $1.dateLogged }
        case .blended:
            return scoreAndSortLogs(logs)
        }
    }

    // Public helper to reapply current ordering to in-memory arrays
    func reapplyOrderingInPlace() {
        friendsLogs = applyOrdering(friendsLogs)
        followingLogs = applyOrdering(followingLogs)
        trendingLogs = applyOrdering(trendingLogs)
    }

    @MainActor
    func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            // Hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let userDoc = try await db.collection("users").document(Auth.auth().currentUser?.uid ?? "").getDocument()
            let data = userDoc.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Set(followingIds).intersection(Set(followerIds))
            let followingOnly = Set(followingIds).subtracting(mutuals)

            switch selectedSection {
            case .friends:
                let more = try await fetchLogs(for: Array(mutuals.filter { !hidden.contains($0) }), before: friendsOldestDate)
                let merged = mergeUnique(existing: friendsLogs, new: more)
                friendsLogs = applyOrdering(merged)
                friendsOldestDate = friendsLogs.last?.dateLogged ?? friendsOldestDate
            case .following:
                let more = try await fetchLogs(for: Array(followingOnly.filter { !hidden.contains($0) }), before: followingOldestDate)
                let merged = mergeUnique(existing: followingLogs, new: more)
                followingLogs = applyOrdering(merged)
                followingOldestDate = followingLogs.last?.dateLogged ?? followingOldestDate
            case .trending:
                let all = try await fetchLogs(for: Array(mutuals.union(followingOnly).filter { !hidden.contains($0) }), before: trendingOldestDate)
                let merged = mergeUnique(existing: trendingLogs, new: all)
                trendingLogs = scoreAndSortLogs(merged)
                trendingOldestDate = trendingLogs.last?.dateLogged ?? trendingOldestDate
            }
        } catch {
            // ignore
        }
    }

    private func mergeUnique(existing: [MusicLog], new: [MusicLog]) -> [MusicLog] {
        var map: [String: MusicLog] = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for l in new { map[l.id] = l }
        return Array(map.values)
    }

    // Load reposted logs from people you follow/friends using collectionGroup("reposts")
    private func loadReposts(mutuals: Set<String>, followingOnly: Set<String>, hidden: Set<String>) async throws -> (friends: [MusicLog], following: [MusicLog], attribution: [String: [String]]) {
        let db = Firestore.firestore()
        var attribution: [String: [String]] = [:]
        var friendLogIds: Set<String> = []
        var followingLogIds: Set<String> = []

        func processBatch(_ batch: [String]) async throws {
            let snap = try await db.collectionGroup("reposts")
                .whereField("userId", in: batch)
                .limit(to: 200)
                .getDocuments()
            for doc in snap.documents {
                if let repost = try? doc.data(as: Repost.self), let logId = repost.logId {
                    if hidden.contains(repost.userId) { continue }
                    if mutuals.contains(repost.userId) { friendLogIds.insert(logId) }
                    if followingOnly.contains(repost.userId) { followingLogIds.insert(logId) }
                    attribution[logId, default: []].append(repost.userId)
                }
            }
        }

        let unionIds = Array(mutuals.union(followingOnly))
        for batch in unionIds.chunked(into: 10) {
            try await processBatch(batch)
        }

        // Fetch logs by collected ids
        func fetchLogs(by ids: Set<String>) async throws -> [MusicLog] {
            guard !ids.isEmpty else { return [] }
            var result: [MusicLog] = []
            for batch in Array(ids).chunked(into: 10) {
                let snap = try await db.collection("logs").whereField(FieldPath.documentID(), in: batch).getDocuments()
                let logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                result.append(contentsOf: logs)
            }
            return result
        }

        let friendsLogs = try await fetchLogs(by: friendLogIds)
        let followingLogs = try await fetchLogs(by: followingLogIds)
        return (friends: friendsLogs, following: followingLogs, attribution: attribution)
    }
}

#if DEBUG
private extension FollowersFeedViewModel {
    static func generateMockLogs(count: Int, userPrefix: String, hoursBack: Int) -> [MusicLog] {
        let sampleTitles = [
            ("Heatwave", "Glass Animals"),
            ("Blinding Lights", "The Weeknd"),
            ("Levitating", "Dua Lipa"),
            ("good 4 u", "Olivia Rodrigo"),
            ("As It Was", "Harry Styles"),
            ("Kill Bill", "SZA"),
            ("Anti-Hero", "Taylor Swift"),
            ("About Damn Time", "Lizzo"),
            ("Stay", "The Kid LAROI"),
            ("Despacito", "Luis Fonsi")
        ]
        var logs: [MusicLog] = []
        for i in 0..<count {
            let pick = sampleTitles[i % sampleTitles.count]
            let rating = [3,4,5,4,5,3,4,5,5,4][i % 10]
            let hoursOffset = Int.random(in: 1...max(2, hoursBack))
            let log = MusicLog(
                id: "mock_\(userPrefix)_log_\(i)",
                userId: "mock_\(userPrefix)_user_\(i % 6)",
                itemId: "mock_song_\(i)",
                itemType: "song",
                title: pick.0,
                artistName: pick.1,
                artworkUrl: nil,
                dateLogged: Calendar.current.date(byAdding: .hour, value: -hoursOffset, to: Date()) ?? Date(),
                rating: rating,
                review: i % 3 == 0 ? "Loved the chorus and production." : nil,
                notes: nil,
                commentCount: Int.random(in: 0...6),
                helpfulCount: Int.random(in: 0...12),
                unhelpfulCount: Int.random(in: 0...2),
                reviewPhotos: nil,
                isLiked: Bool.random(),
                thumbsUp: nil,
                thumbsDown: nil,
                isPublic: true
            )
            logs.append(log)
        }
        return logs
    }
}
#endif

struct FollowersTabView: View {
    @StateObject private var vm = FollowersFeedViewModel()
    @State private var showingDetail: MusicLog?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Professional subsection selector (always blended mode)
            VStack(spacing: 12) {
                Picker("Feed Section", selection: $vm.selectedSection) {
                    ForEach(FollowersFeedViewModel.Section.allCases, id: \.rawValue) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 4)
            }
            .onAppear {
                // Set to blended mode and keep it there
                vm.ordering = .blended
            }

            if vm.isLoadingInitial {
                ProgressView()
            } else if let err = vm.errorMessage {
                Text(err).foregroundColor(.red)
            } else {
                let logs = currentLogs()
                if logs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: vm.selectedSection == .trending ? "flame.fill" : "person.2")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text(emptyTitle())
                            .font(.headline)
                        Text(emptySubtitle())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        if vm.isLoadingInitial {
                            ProgressView()
                        } else {
                            Button("Reload") { Task { await vm.load() } }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(logs, id: \.id) { log in
                                    FollowersLogRow(log: log, reposterNames: reposterNamesFor(log))
                                        .id(log.id)
                                        .onTapGesture { showingDetail = log }
                                        .onAppear {
                                            if log.id == logs.suffix(2).first?.id {
                                                Task { await vm.loadMore() }
                                            }
                                            AnalyticsService.shared.logImpression(category: "followers_row_\(vm.selectedSection.rawValue.lowercased())", id: log.id)
                                            UserDefaults.standard.set(log.id, forKey: "followersAnchor_\(vm.selectedSection.rawValue)")
                                        }
                                }
                            }
                        }
                        .refreshable { await vm.load() }
                        .onAppear {
                            if let anchor = UserDefaults.standard.string(forKey: "followersAnchor_\(vm.selectedSection.rawValue)") {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation { proxy.scrollTo(anchor, anchor: .top) }
                                }
                            }
                        }
                        .onChange(of: vm.selectedSection) { newValue in
                            if let anchor = UserDefaults.standard.string(forKey: "followersAnchor_\(newValue.rawValue)") {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation { proxy.scrollTo(anchor, anchor: .top) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .onAppear {
            if let saved = UserDefaults.standard.string(forKey: "followersSelectedSection"), let sec = FollowersFeedViewModel.Section(rawValue: saved) {
                vm.selectedSection = sec
            }
            Task { await vm.load() }
        }
        .onChange(of: vm.ordering) { newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "followersOrdering")
            // Reapply ordering instantly
            vm.reapplyOrderingInPlace()
        }
        .onChange(of: vm.selectedSection) { newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "followersSelectedSection")
            AnalyticsService.shared.logTap(category: "followers_chip", id: newValue.rawValue)
        }
        .fullScreenCover(item: $showingDetail) { log in
            let result = MusicSearchResult(id: log.itemId, title: log.title, artistName: log.artistName, albumName: "", artworkURL: log.artworkUrl, itemType: log.itemType, popularity: 0)
            MusicProfileView(musicItem: result, pinnedLog: log)
        }
    }
    
    private func emptyTitle() -> String {
        switch vm.selectedSection {
        case .friends: return "No recent posts from friends"
        case .following: return "No recent posts from people you follow"
        case .trending: return "No trending posts right now"
        }
    }

    private func emptySubtitle() -> String {
        switch vm.selectedSection {
        case .friends: return "Invite friends or follow people you know to see their posts here."
        case .following: return "Try switching to Most recent or check back later."
        case .trending: return "Engagement is quiet—check back soon."
        }
    }

    private func currentLogs() -> [MusicLog] {
        switch vm.selectedSection {
        case .friends: return vm.friendsLogs
        case .following: return vm.followingLogs
        case .trending: return vm.trendingLogs
        }
    }

    private func reposterNamesFor(_ log: MusicLog) -> [String]? {
        // In DEBUG with mock data, synthesize a couple of names for variety
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "feed.mockData") {
            let seed = abs(log.id.hashValue)
            if seed % 3 == 0 {
                let candidates = ["alex", "sam", "jordan", "taylor", "morgan", "casey"]
                let count = (seed % 3) + 1
                return Array((0..<count).map { candidates[(seed + $0) % candidates.count] })
            }
            return nil
        }
        #endif
        // For real data, we would resolve userIds to usernames. Here we return userIds for now.
        var names: [String]? = nil
        Repost.fetchReposters(logId: log.id, itemId: nil) { ids in
            names = ids // TODO: map to usernames if needed
        }
        return names
    }
}

private struct FollowersSectionChips: View {
    @Binding var selected: FollowersFeedViewModel.Section
    var body: some View {
        HStack(spacing: 8) {
            ForEach(FollowersFeedViewModel.Section.allCases, id: \.rawValue) { sec in
                Button(action: { selected = sec }) {
                    Text(sec.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected == sec ? Color.purple.opacity(0.15) : Color.gray.opacity(0.15))
                        .foregroundColor(selected == sec ? .purple : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// No longer used (kept for reference); the chip layout is restored above

// Simple chunk helper
// Uses existing chunked(into:) defined elsewhere in the project


