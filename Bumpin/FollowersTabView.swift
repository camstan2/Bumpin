import SwiftUI
import FirebaseAuth
import FirebaseFirestore

final class FollowersFeedViewModel: ObservableObject {
    enum Section: String, CaseIterable { case following = "Following", trending = "Trending" }
    enum Ordering: String { case blended, mostRecent }

    @Published var selectedSection: Section = .following
    @Published var ordering: Ordering = (UserDefaults.standard.string(forKey: "followersOrdering").flatMap { Ordering(rawValue: $0) }) ?? .blended
    @Published var isLoadingInitial = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    @Published var followingLogs: [MusicLog] = []
    @Published var trendingLogs: [MusicLog] = []
    @Published var repostersByLogId: [String: [String]] = [:]

    private let db = Firestore.firestore()
    private let calendar = Calendar.current
    private var followingOldestDate: Date? = nil
    private var trendingOldestDate: Date? = nil
    private var followingHasMore: Bool = true
    private var trendingHasMore: Bool = true
    // Track affinity sets for scoring
    private var followingIds: Set<String> = []

    func load() async {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "feed.mockData") {
            await MainActor.run { self.isLoadingInitial = true; self.errorMessage = nil }
            // Generate mock data for Following and Trending
            let following = Self.generateMockLogs(count: 20, userPrefix: "follow", hoursBack: 48)
            let trending = scoreAndSortLogs(following)
            await MainActor.run {
                self.followingLogs = self.applyOrdering(following)
                self.trendingLogs = trending
                // Mock some repost attributions
                var attrib: [String: [String]] = [:]
                for (idx, log) in self.followingLogs.enumerated() where idx % 4 == 0 {
                    attrib[log.id] = ["alex", "sam"].prefix(Int.random(in: 1...2)).map { $0 }
                }
                self.repostersByLogId = attrib
                self.followingOldestDate = self.followingLogs.last?.dateLogged
                self.trendingOldestDate = self.trendingLogs.last?.dateLogged
                self.isLoadingInitial = false
            }
            return
        }
        #endif
        guard !isLoadingInitial else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        await MainActor.run { self.isLoadingInitial = true; self.errorMessage = nil }
        do {
            // Fetch following IDs from subcollection instead of array field
            print("🔍 [FollowersFeed] Fetching following for uid: \(uid)")
            let followingSnapshot = try await db.collection("users").document(uid).collection("following").getDocuments()
            let followingIdsList = followingSnapshot.documents.map { $0.documentID }
            print("✅ [FollowersFeed] Found \(followingIdsList.count) following: \(followingIdsList)")
            let followingSet = Set(followingIdsList)
            self.followingIds = followingSet
            self.followingHasMore = true
            self.trendingHasMore = true

            // Hidden users
            await UserPreferencesService.shared.loadHiddenUsers()
            let hidden = UserPreferencesService.shared.hiddenUserIds
            let filteredFollowing = Array(followingSet.filter { !hidden.contains($0) })

            print("🔍 [FollowersFeed] Fetching logs for following users...")
            async let followingLogsTask = fetchLogs(for: filteredFollowing)
            async let trendingLogsTask = fetchGlobalTrendingLogs(hidden: hidden)
            async let repostsTask = loadReposts(following: followingSet, hidden: hidden)

            let followingLogs = try await followingLogsTask
            print("✅ [FollowersFeed] Found \(followingLogs.count) logs from following")
            let globalTrendingSource = try await trendingLogsTask
            let repostResult = try await repostsTask

            let trendingMinDate = globalTrendingSource.map { $0.dateLogged }.min()
            let trending = scoreAndSortLogs(globalTrendingSource, applyAffinity: false)
            followingHasMore = !filteredFollowing.isEmpty
            trendingHasMore = globalTrendingSource.count >= 400

            await MainActor.run {
                var orderedFollowing = self.applyOrdering(followingLogs)
                if !repostResult.logs.isEmpty {
                    orderedFollowing = self.applyOrdering(self.mergeUnique(existing: orderedFollowing, new: repostResult.logs))
                }
                self.followingLogs = orderedFollowing
                self.trendingLogs = trending
                self.repostersByLogId = repostResult.attribution
                self.followingOldestDate = orderedFollowing.map { $0.dateLogged }.min()
                self.trendingOldestDate = trendingMinDate
                self.isLoadingInitial = false
                print("✅ [FollowersFeed] Load complete - Following: \(self.followingLogs.count), Trending: \(self.trendingLogs.count)")
            }
        } catch {
            print("❌ [FollowersFeed] Load failed: \(error.localizedDescription)")
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
    
    private func fetchGlobalTrendingLogs(before: Date? = nil, hidden: Set<String>) async throws -> [MusicLog] {
        let now = Date()
        let seventyTwoHoursAgo = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        var query: Query = db.collection("logs")
            .whereField("dateLogged", isGreaterThan: seventyTwoHoursAgo)
            .order(by: "dateLogged", descending: true)
        if let cutoff = before {
            query = query.whereField("dateLogged", isLessThan: cutoff)
        }
        let snapshot = try await query.limit(to: 400).getDocuments()
        var logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
        logs = logs.filter { ($0.isPublic ?? true) && !hidden.contains($0.userId) }
        return logs
    }

    private func scoreAndSortLogs(_ logs: [MusicLog], applyAffinity: Bool = true) -> [MusicLog] {
        // Use new engagement scoring service
        let baseSorted = EngagementScoringService.shared.sortByEngagement(logs)
        
        // Apply affinity boost for following relationships
        let cfg = ScoringConfig.shared
        return baseSorted.sorted { log1, log2 in
            let score1 = EngagementScoringService.shared.calculateScore(for: log1)
            let score2 = EngagementScoringService.shared.calculateScore(for: log2)
            
            // Recency factor (exponential decay, multiplicative)
            let ageHours1 = Date().timeIntervalSince(log1.dateLogged) / 3600.0
            let recencyFactor1 = pow(exp(-ageHours1 / cfg.decayHours), cfg.recencyWeightMultiplier)
            
            let ageHours2 = Date().timeIntervalSince(log2.dateLogged) / 3600.0
            let recencyFactor2 = pow(exp(-ageHours2 / cfg.decayHours), cfg.recencyWeightMultiplier)
            
            // Affinity boost for following users
            let affinityBoost1: Double = (applyAffinity && followingIds.contains(log1.userId)) ? 1.0 + cfg.followingBoost : 1.0
            let affinityBoost2: Double = (applyAffinity && followingIds.contains(log2.userId)) ? 1.0 + cfg.followingBoost : 1.0
            
            // Final blended score (multiplicative mix)
            let final1 = score1 * recencyFactor1 * affinityBoost1
            let final2 = score2 * recencyFactor2 * affinityBoost2
            
            return final1 > final2
        }
    }

    private func applyOrdering(_ logs: [MusicLog]) -> [MusicLog] {
        switch ordering {
        case .mostRecent:
            return logs.sorted { $0.dateLogged > $1.dateLogged }
        case .blended:
            return scoreAndSortLogs(logs, applyAffinity: true)
        }
    }
    
    // Public helper to reapply current ordering to in-memory arrays
    func reapplyOrderingInPlace() {
        followingLogs = applyOrdering(followingLogs)
        trendingLogs = scoreAndSortLogs(trendingLogs, applyAffinity: false)
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
            let uid = Auth.auth().currentUser?.uid ?? ""
            let followingSnapshot = try await db.collection("users").document(uid).collection("following").getDocuments()
            let following = Set(followingSnapshot.documents.map { $0.documentID })

            switch selectedSection {
            case .following:
                guard followingHasMore else { return }
                let more = try await fetchLogs(for: Array(following.filter { !hidden.contains($0) }), before: followingOldestDate)
                if more.isEmpty {
                    followingHasMore = false
                    return
                }
                let merged = mergeUnique(existing: followingLogs, new: more)
                let ordered = applyOrdering(merged)
                followingLogs = ordered
                followingOldestDate = ordered.map { $0.dateLogged }.min() ?? followingOldestDate
            case .trending:
                guard trendingHasMore else { return }
                let more = try await fetchGlobalTrendingLogs(before: trendingOldestDate, hidden: hidden)
                if more.isEmpty {
                    trendingHasMore = false
                    return
                }
                let merged = mergeUnique(existing: trendingLogs, new: more)
                trendingLogs = scoreAndSortLogs(merged, applyAffinity: false)
                trendingOldestDate = merged.map { $0.dateLogged }.min() ?? trendingOldestDate
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

    // Load reposted logs from people you follow using collectionGroup("reposts")
    private func loadReposts(following: Set<String>, hidden: Set<String>) async throws -> (logs: [MusicLog], attribution: [String: [String]]) {
        let db = Firestore.firestore()
        var attribution: [String: [String]] = [:]
        var logIds: Set<String> = []

        func processBatch(_ batch: [String]) async throws {
            let snap = try await db.collectionGroup("reposts")
                .whereField("userId", in: batch)
                .limit(to: 200)
                .getDocuments()
            for doc in snap.documents {
                if let repost = try? doc.data(as: Repost.self), let logId = repost.logId {
                    if hidden.contains(repost.userId) { continue }
                    if following.contains(repost.userId) { logIds.insert(logId) }
                    attribution[logId, default: []].append(repost.userId)
                }
            }
        }

        let unionIds = Array(following)
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

        let logs = try await fetchLogs(by: logIds)
        return (logs: logs, attribution: attribution)
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
            let rating = [3.0,4.0,5.0,4.0,5.0,3.0,4.0,5.0,5.0,4.0][i % 10]
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
    @State private var loggedImpressions: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // DESIGN ENHANCEMENT: Custom tab bar matching main filter tabs
            HStack(spacing: 6) {
                ForEach(FollowersFeedViewModel.Section.allCases, id: \.rawValue) { section in
                    Button(action: {
                        vm.selectedSection = section
                    }) {
                        Text(section.rawValue)
                            .font(.caption)
                            .fontWeight(vm.selectedSection == section ? .bold : .regular)
                            .foregroundColor(vm.selectedSection == section ? .purple : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(vm.selectedSection == section ? Color.purple.opacity(0.12) : Color(.systemGray6))
                            )
                            .overlay(
                                // Bottom indicator line for selected state
                                VStack {
                                    Spacer()
                                    if vm.selectedSection == section {
                                        Rectangle()
                                            .fill(Color.purple)
                                            .frame(height: 3)
                                            .cornerRadius(1.5)
                                            .padding(.horizontal, 8)
                                    }
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
                            // DESIGN ENHANCEMENT: Increased spacing for better visual hierarchy
                            LazyVStack(spacing: 16) {
                                ForEach(logs, id: \.id) { log in
                                    FollowersLogRow(log: log, reposterNames: reposterNamesFor(log))
                                        .id(log.id)
                                        .onTapGesture { showingDetail = log }
                                        .onAppear {
                                            if log.id == logs.suffix(2).first?.id {
                                                Task { await vm.loadMore() }
                                            }
                                            let impressionKey = "\(vm.selectedSection.rawValue)#\(log.id)"
                                            if !loggedImpressions.contains(impressionKey) {
                                                loggedImpressions.insert(impressionKey)
                                                AnalyticsService.shared.logImpression(category: "followers_row_\(vm.selectedSection.rawValue.lowercased())", id: log.id)
                                            }
                                            UserDefaults.standard.set(log.id, forKey: "followersAnchor_\(vm.selectedSection.rawValue)")
                                        }
                                }
                            }
                        }
                        .id(vm.selectedSection)
                        .transaction { $0.disablesAnimations = true }
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
        case .following: return "No recent posts from people you follow"
        case .trending: return "No trending posts right now"
        }
    }

    private func emptySubtitle() -> String {
        switch vm.selectedSection {
        case .following: return "Follow people to see their posts here."
        case .trending: return "Engagement is quiet—check back soon."
        }
    }

    private func currentLogs() -> [MusicLog] {
        switch vm.selectedSection {
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


