import Foundation
import FirebaseFirestore
import MusicKit

/// Encapsulates Firestore + MusicKit work for the social feed so view models stay lean.
final class SocialFeedService {
    static let shared = SocialFeedService()
    
    private let db = Firestore.firestore()
    private let calendar = Calendar.current
    
    private init() {}
    
    struct CreatorSpotlightEntry {
        let user: UserProfile
        let recentLogs: [MusicLog]
    }
    
    // MARK: - Trending Fetchers
    
    func fetchTrendingSongs() async throws -> [TrendingItem] {
        let timeWindow = getAdaptiveTrendingTimeWindow()
        let logs = try await fetchLogs(
            queryBuilder: {
                db.collection("logs")
                    .whereField("itemType", isEqualTo: "song")
                    .whereField("dateLogged", isGreaterThan: timeWindow)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
            },
            fallbackBuilder: {
                db.collection("logs")
                    .whereField("itemType", isEqualTo: "song")
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
            },
            timeWindow: timeWindow
        )
        
        var items = calculateTrendingSongs(from: logs.filter { ($0.isPublic ?? true) })
        items = await enrichWithOverallRatings(items, itemType: "song")
        return items
    }
    
    func fetchTrendingArtists() async throws -> [TrendingItem] {
        let timeWindow = getAdaptiveTrendingTimeWindow()
        let logs = try await fetchLogs(
            queryBuilder: {
                db.collection("logs")
                    .whereField("dateLogged", isGreaterThan: timeWindow)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 400)
            },
            fallbackBuilder: {
                db.collection("logs")
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 400)
            },
            timeWindow: timeWindow
        )
        var items = calculateTrendingArtists(from: logs)
        items = await enrichArtistsWithArtwork(items)
        items = await enrichArtistsWithOverallRatings(items)
        return items
    }
    
    func fetchTrendingAlbums() async throws -> [TrendingItem] {
        let timeWindow = getAdaptiveTrendingTimeWindow()
        let logs = try await fetchLogs(
            queryBuilder: {
                db.collection("logs")
                    .whereField("itemType", isEqualTo: "album")
                    .whereField("dateLogged", isGreaterThan: timeWindow)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
            },
            fallbackBuilder: {
                db.collection("logs")
                    .whereField("itemType", isEqualTo: "album")
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 200)
            },
            timeWindow: timeWindow
        )
        var items = calculateTrendingAlbums(from: logs.filter { ($0.isPublic ?? true) })
        items = await enrichWithOverallRatings(items, itemType: "album")
        return items
    }
    
    // MARK: - Friends Popular Fetchers
    
    func fetchFriendsPopularSongs(for userId: String) async throws -> [TrendingItem] {
        let logs = try await fetchFriendLogs(
            for: userId,
            allowedTypes: Set(["song"]),
            perBatchLimit: 200
        )
        let items = buildFriendSongItems(from: logs)
        return await enrichWithOverallRatings(items, itemType: "song")
    }
    
    func fetchFriendsPopularCombined(for userId: String) async throws -> [TrendingItem] {
        let logs = try await fetchFriendLogs(
            for: userId,
            allowedTypes: Set(["song", "album", "artist"]),
            perBatchLimit: 300
        )
        var items = buildFriendCombinedItems(from: logs)
        items = await enrichWithOverallRatingsMixed(items)
        return items
    }
    
    func fetchGenreFriendsPopularSongs(for userId: String, genre: String) async throws -> [TrendingItem] {
        let logs = try await fetchFriendLogs(
            for: userId,
            allowedTypes: Set(["song"]),
            perBatchLimit: 200,
            genre: genre
        )
        let items = buildFriendSongItems(from: logs)
        return await enrichWithOverallRatings(items, itemType: "song")
    }
    
    func fetchGenreFriendsPopularCombined(for userId: String, genre: String) async throws -> [TrendingItem] {
        let logs = try await fetchFriendLogs(
            for: userId,
            allowedTypes: Set(["song", "album", "artist"]),
            perBatchLimit: 300,
            genre: genre
        )
        let items = buildFriendCombinedItems(from: logs, preserveFriendAverages: false)
        return await enrichWithOverallRatingsMixed(items)
    }
    
    func fetchMutualFriendIds(for userId: String) async throws -> [String] {
        let (following, followers) = try await fetchFollowingAndFollowers(for: userId)
        let mutuals = Set(following).intersection(Set(followers))
        return Array(mutuals)
    }
    
    func fetchFriendsActivity(for userId: String) async throws -> [FriendActivity] {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let userData = try? userDoc.data(as: UserProfile.self),
              let following = userData.following,
              !following.isEmpty else {
            return []
        }
        
        let timeWindow = getAdaptiveTrendingTimeWindow()
        var allLogs: [MusicLog] = []
        for batch in following.chunked(into: 10) {
            do {
                let snapshot = try await db.collection("logs")
                    .whereField("userId", in: batch)
                    .whereField("dateLogged", isGreaterThan: timeWindow)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 100)
                    .getDocuments()
                let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                allLogs.append(contentsOf: logs)
            } catch {
                let snapshot = try await db.collection("logs")
                    .whereField("userId", in: batch)
                    .order(by: "dateLogged", descending: true)
                    .limit(to: 100)
                    .getDocuments()
                let logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                    .filter { $0.dateLogged >= timeWindow }
                allLogs.append(contentsOf: logs)
            }
        }
        
        let userProfiles = try await fetchUserProfiles(for: following)
        let profilesDict = Dictionary(uniqueKeysWithValues: userProfiles.map { ($0.uid, $0) })
        
        let activities = allLogs.compactMap { log -> FriendActivity? in
            guard let userProfile = profilesDict[log.userId] else { return nil }
            return FriendActivity(
                userId: log.userId,
                username: userProfile.username,
                userProfilePictureUrl: userProfile.profilePictureUrl,
                songTitle: log.title,
                artistName: log.artistName,
                artworkUrl: log.artworkUrl,
                rating: log.rating,
                loggedAt: log.dateLogged,
                musicLog: log
            )
        }
        .sorted { activity1, activity2 in
            let rating1 = activity1.rating ?? 0
            let rating2 = activity2.rating ?? 0
            if rating1 > 0 && rating2 > 0, rating1 != rating2 {
                return rating1 > rating2
            } else if rating1 > 0 && rating2 == 0 {
                return true
            } else if rating1 == 0 && rating2 > 0 {
                return false
            }
            return activity1.loggedAt > activity2.loggedAt
        }
        
        return activities
    }
    
    func fetchNowPlayingFriends(for userId: String, freshnessWindowMinutes: Int = 5) async throws -> [UserProfile] {
        let mutuals = try await fetchMutualFriendIds(for: userId)
        guard !mutuals.isEmpty else { return [] }
        var results: [UserProfile] = []
        for batch in mutuals.chunked(into: 10) {
            let snap = try await db.collection("users")
                .whereField("uid", in: batch)
                .getDocuments()
            let users = snap.documents.compactMap { try? $0.data(as: UserProfile.self) }
            results.append(contentsOf: users.filter { $0.showNowPlaying == true })
        }
        let cutoff = Date().addingTimeInterval(-Double(freshnessWindowMinutes) * 60)
        return results.filter { profile in
            guard let updatedAt = profile.nowPlayingUpdatedAt else { return false }
            return updatedAt > cutoff
        }
    }
    
    func fetchNowPlayingCreators(limit: Int = 40) async throws -> [UserProfile] {
        let snap = try await db.collection("users")
            .whereField("showNowPlaying", isEqualTo: true)
            .limit(to: limit)
            .getDocuments()
        let users = snap.documents.compactMap { try? $0.data(as: UserProfile.self) }
        return users.filter { ($0.isVerified ?? false) || (($0.roles ?? []).contains("creator") || ($0.roles ?? []).contains("dj")) }
    }
    
    func fetchWeeklyPopularLogs(before cursorDate: Date?) async throws -> [MusicLog] {
        let threshold = getAdaptiveTrendingTimeWindow()
        var query: Query = db.collection("logs").order(by: "dateLogged", descending: true)
        if let cursor = cursorDate {
            query = query.whereField("dateLogged", isLessThan: cursor)
        }
        let snap = try await query.limit(to: 400).getDocuments()
        var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
        logs = logs.filter { $0.dateLogged >= threshold && ($0.isPublic ?? true) }
        return logs
    }
    
    func fetchGenreWeeklyPopularLogs(for genre: String, before cursorDate: Date?) async throws -> [MusicLog] {
        let threshold = getAdaptiveTrendingTimeWindow()
        var query: Query = db.collection("logs")
            .whereField("genres", arrayContains: genre)
            .order(by: "dateLogged", descending: true)
        if let cursor = cursorDate {
            query = query.whereField("dateLogged", isLessThan: cursor)
        }
        let snap = try await query.limit(to: 400).getDocuments()
        var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
        logs = logs.filter { $0.dateLogged >= threshold && ($0.isPublic ?? true) }
        return logs
    }
    
    func fetchGenreLogs(for genre: String, limit: Int) async throws -> [MusicLog] {
        let timeWindow = getAdaptiveTrendingTimeWindow()
        do {
            let ordered = try await db.collection("logs")
                .whereField("genres", arrayContains: genre)
                .whereField("dateLogged", isGreaterThan: timeWindow)
                .order(by: "dateLogged", descending: true)
                .limit(to: limit)
                .getDocuments()
            return ordered.documents.compactMap { try? $0.data(as: MusicLog.self) }
        } catch {
            let fallback = try await db.collection("logs")
                .whereField("genres", arrayContains: genre)
                .order(by: "dateLogged", descending: true)
                .limit(to: limit)
                .getDocuments()
            return fallback.documents.compactMap { try? $0.data(as: MusicLog.self) }
                .filter { $0.dateLogged >= timeWindow }
        }
    }
    
    func fetchCreatorSpotlightEntries(limit: Int,
                                      after lastDocument: DocumentSnapshot?) async throws -> (entries: [CreatorSpotlightEntry], lastDocument: DocumentSnapshot?) {
        var query: Query = db.collection("users")
            .whereField("isVerified", isEqualTo: true)
            .order(by: "createdAt", descending: true)
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        let snap = try await query.limit(to: limit).getDocuments()
        let users = snap.documents.compactMap { try? $0.data(as: UserProfile.self) }
        var entries: [CreatorSpotlightEntry] = []
        try await withThrowingTaskGroup(of: CreatorSpotlightEntry.self) { group in
            for user in users {
                group.addTask {
                    let logSnap = try await self.db.collection("logs")
                        .whereField("userId", isEqualTo: user.uid)
                        .order(by: "dateLogged", descending: true)
                        .limit(to: 3)
                        .getDocuments()
                    let recent = logSnap.documents.compactMap { try? $0.data(as: MusicLog.self) }
                    return CreatorSpotlightEntry(user: user, recentLogs: recent)
                }
            }
            for try await entry in group {
                entries.append(entry)
            }
        }
        return (entries, snap.documents.last)
    }
    
    func fetchCreatorLogs(for userIds: [String], type: String, before date: Date?) async throws -> [MusicLog] {
        guard !userIds.isEmpty else { return [] }
        var collected: [MusicLog] = []
        for batch in userIds.chunked(into: 10) {
            var query: Query = db.collection("logs")
                .whereField("userId", in: batch)
                .order(by: "dateLogged", descending: true)
            if type != "artist" {
                query = query.whereField("itemType", isEqualTo: type)
            }
            let snap = try await query.limit(to: 120).getDocuments()
            var logs = snap.documents.compactMap { try? $0.data(as: MusicLog.self) }
            if let cutoff = date {
                logs = logs.filter { $0.dateLogged < cutoff }
            }
            collected.append(contentsOf: logs)
        }
        return collected
    }
    
    func fetchLatestLog() async throws -> MusicLog? {
        let snap = try await db.collection("logs")
            .order(by: "dateLogged", descending: true)
            .limit(to: 1)
            .getDocuments()
        return snap.documents.first.flatMap { try? $0.data(as: MusicLog.self) }
    }
    
    func attachTopLogListener(_ onChange: @escaping (Result<MusicLog?, Error>) -> Void) -> ListenerRegistration {
        db.collection("logs")
            .order(by: "dateLogged", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onChange(.failure(error))
                    return
                }
                let latest = snapshot?.documents.first.flatMap { try? $0.data(as: MusicLog.self) }
                onChange(.success(latest))
            }
    }
    
    // MARK: - Public Helpers

    func enrichWithOverallRatings(_ items: [TrendingItem], itemType: String) async -> [TrendingItem] {
        guard !items.isEmpty else { return [] }
        var enriched = items
        
        await withTaskGroup(of: (Int, MusicProfileSummary?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    let summary = await MusicProfileSummaryService.shared.summary(for: item, itemType: itemType)
                    return (index, summary)
                }
            }
            
            for await (index, summary) in group {
                guard let summary,
                      let average = summary.averageRating,
                      summary.totalRatings > 0 else {
                    print("ℹ️ [Ratings] \(items[index].title) has no cached ratings; leaving \"Not rated yet\"")
                    continue
                }
                enriched[index] = enriched[index].withAverageRating(average, totalRatings: summary.totalRatings)
            }
        }
        
        return enriched
    }
    
    func enrichWithOverallRatingsMixed(_ items: [TrendingItem]) async -> [TrendingItem] {
        guard !items.isEmpty else { return [] }
        let songItems = items.filter { $0.itemType == "song" }
        let albumItems = items.filter { $0.itemType == "album" }
        
        async let enrichedSongs = enrichWithOverallRatings(songItems, itemType: "song")
        async let enrichedAlbums = enrichWithOverallRatings(albumItems, itemType: "album")
        let combined = (await enrichedSongs) + (await enrichedAlbums)
        
        // Keep original ordering by mapping back
        let lookup = Dictionary(uniqueKeysWithValues: combined.map { ($0.id, $0) })
        return items.map { lookup[$0.id] ?? $0 }
    }
    
    // MARK: - Private Helpers
    
    
    private func fetchLogs(queryBuilder: () -> Query,
                           fallbackBuilder: () -> Query,
                           timeWindow: Date) async throws -> [MusicLog] {
        do {
            let ordered = try await queryBuilder().getDocuments()
            return ordered.documents.compactMap { try? $0.data(as: MusicLog.self) }
        } catch {
            let fallback = try await fallbackBuilder().getDocuments()
            return fallback.documents.compactMap { try? $0.data(as: MusicLog.self) }
                .filter { $0.dateLogged >= timeWindow }
        }
    }
    
    private func fetchFriendLogs(for userId: String,
                                 allowedTypes: Set<String>,
                                 perBatchLimit: Int,
                                 genre: String? = nil) async throws -> [MusicLog] {
        let friendIds = try await eligibleFriendIds(for: userId)
        guard !friendIds.isEmpty else { return [] }
        let timeWindow = getAdaptiveTrendingTimeWindow()
        var all: [MusicLog] = []
        for batch in friendIds.chunked(into: 10) {
            let snapshot = try await db.collection("logs")
                .whereField("userId", in: batch)
                .order(by: "dateLogged", descending: true)
                .limit(to: perBatchLimit)
                .getDocuments()
            var logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            logs = logs.filter { allowedTypes.contains($0.itemType) && $0.dateLogged >= timeWindow && (($0.isPublic ?? true) == true) }
            if let genre = genre?.lowercased() {
                logs = logs.filter { log in
                    guard let genres = log.genres?.map({ $0.lowercased() }) else { return false }
                    return genres.contains(genre)
                }
            }
            all.append(contentsOf: logs)
        }
        return all
    }
    
    private func buildFriendSongItems(from logs: [MusicLog]) -> [TrendingItem] {
        guard !logs.isEmpty else { return [] }
        let grouped = Dictionary(grouping: logs) { canonicalSongId(for: $0) }
        let entries: [(TrendingItem, [MusicLog])] = grouped.compactMap { (key, logs) in
            guard let displayLog = preferredDisplayLog(from: logs) else { return nil }
            let appleId = appleMusicId(from: logs) ?? displayLog.itemId
            let item = TrendingItem(
                title: displayLog.title,
                subtitle: displayLog.artistName,
                artworkUrl: displayLog.artworkUrl,
                logCount: logs.count,
                averageRating: nil, // Will be set by enrichWithOverallRatings
                itemType: "song",
                itemId: key,
                appleMusicId: appleId
            )
            return (item, logs)
        }
        return entries
        .sorted { lhs, rhs in
                let lScore = PopularityService.scoreFriendsPopular(logs: lhs.1)
                let rScore = PopularityService.scoreFriendsPopular(logs: rhs.1)
                return lScore > rScore
        }
            .map { $0.0 }
    }
    
    private func buildFriendCombinedItems(from logs: [MusicLog], preserveFriendAverages: Bool = false) -> [TrendingItem] {
        guard !logs.isEmpty else { return [] }
        let grouped = Dictionary(grouping: logs) { groupingKey(for: $0) }
        let entries: [(TrendingItem, [MusicLog])] = grouped.compactMap { (key, logs) in
            guard let displayLog = preferredDisplayLog(from: logs) else { return nil }
            let appleId = appleMusicId(from: logs)
            let item = TrendingItem(
                title: displayLog.title,
                subtitle: displayLog.itemType == "artist" ? nil : displayLog.artistName,
                artworkUrl: displayLog.artworkUrl,
                logCount: logs.count,
                averageRating: nil, // Will be set by enrichWithOverallRatingsMixed
                itemType: displayLog.itemType,
                itemId: key,
                appleMusicId: (displayLog.itemType == "artist") ? nil : (appleId ?? displayLog.itemId)
            )
            return (item, logs)
        }
        return entries
        .sorted { lhs, rhs in
                let lScore = PopularityService.scoreFriendsPopular(logs: lhs.1)
                let rScore = PopularityService.scoreFriendsPopular(logs: rhs.1)
                return lScore > rScore
        }
            .map { $0.0 }
    }
    
    private func calculateTrendingSongs(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.universalTrackId ?? $0.itemId }
        return grouped.compactMap { (trackId, logs) in
            guard let first = logs.first else { return nil }
            let appleMusicLog = logs.first { $0.musicPlatform?.lowercased().contains("apple") == true }
            let appleMusicId = appleMusicLog?.itemId ?? first.itemId
            let item = TrendingItem(
                title: first.title,
                subtitle: first.artistName,
                artworkUrl: first.artworkUrl,
                logCount: logs.count,
                averageRating: nil,
                itemType: "song",
                itemId: trackId,
                appleMusicId: appleMusicId
            )
            return meetsTrendingThreshold(item: item) ? item : nil
        }
        .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) >
                  calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
    }
    
    private func calculateTrendingArtists(from logs: [MusicLog]) -> [TrendingItem] {
        var artistLogs: [String: [MusicLog]] = [:]
        var artistDisplayNames: [String: String] = [:]
        
        for log in logs {
            let parsed = splitArtistString(log.artistName)
            let artists = parsed.isEmpty ? [log.artistName] : parsed
            
            for artist in artists {
                let key = ArtistNameParser.normalizedKey(artist)
                guard !key.isEmpty else { continue }
                artistLogs[key, default: []].append(log)
                if artistDisplayNames[key] == nil {
                    artistDisplayNames[key] = artist.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return artistLogs.compactMap { (artistKey, logs) in
            guard let firstLog = logs.first else { return nil }
            let displayName = artistDisplayNames[artistKey] ?? firstLog.artistName
            let item = TrendingItem(
                title: displayName,
                subtitle: nil,
                artworkUrl: nil,
                logCount: logs.count,
                averageRating: nil,
                itemType: "artist",
                itemId: artistKey
            )
            return meetsTrendingThreshold(item: item) ? item : nil
        }
        .sorted { $0.logCount > $1.logCount }
    }
    
    private func calculateTrendingAlbums(from logs: [MusicLog]) -> [TrendingItem] {
        let grouped = Dictionary(grouping: logs) { $0.universalTrackId ?? $0.itemId }
        return grouped.compactMap { (trackId, logs) in
            guard let first = logs.first else { return nil }
            let appleMusicLog = logs.first { $0.musicPlatform?.lowercased().contains("apple") == true }
            let appleMusicId = appleMusicLog?.itemId ?? first.itemId
            let item = TrendingItem(
                title: first.title,
                subtitle: first.artistName,
                artworkUrl: first.artworkUrl,
                logCount: logs.count,
                averageRating: nil,
                itemType: "album",
                itemId: trackId,
                appleMusicId: appleMusicId
            )
            return meetsTrendingThreshold(item: item) ? item : nil
        }
        .sorted { calculateTrendingScore(item: $0, logs: grouped[$0.itemId] ?? []) >
                  calculateTrendingScore(item: $1, logs: grouped[$1.itemId] ?? []) }
    }
    
    func enrichArtistsWithArtwork(_ items: [TrendingItem]) async -> [TrendingItem] {
        var enriched: [TrendingItem] = []
        for item in items {
            guard item.itemType == "artist", item.artworkUrl == nil else {
                enriched.append(item); continue
            }
            do {
                var request = MusicCatalogSearchRequest(term: item.title, types: [MusicKit.Artist.self])
                request.limit = 5
                let response = try await request.response()
                if let artist = findBestArtistMatch(from: response.artists, targetName: item.title),
                   let artworkURL = artist.artwork?.url(width: 512, height: 512)?.absoluteString {
                    enriched.append(item.withArtwork(artworkURL))
                } else {
                    enriched.append(item)
                }
            } catch {
                enriched.append(item)
            }
        }
        return enriched
    }
    
    private func enrichArtistsWithOverallRatings(_ items: [TrendingItem]) async -> [TrendingItem] {
        var enriched: [TrendingItem] = []
        for item in items {
            do {
                let snapshot = try await db.collection("logs")
                    .whereField("artistName", isEqualTo: item.title)
                    .getDocuments()
                let allLogs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
                let ratedLogs = allLogs.filter { ($0.rating ?? 0) > 0 }
                guard !ratedLogs.isEmpty else {
                    enriched.append(item); continue
                }
                let avg = Double(ratedLogs.compactMap { $0.rating }.reduce(0, +)) / Double(ratedLogs.count)
                enriched.append(item.withAverageRating(avg))
            } catch {
                enriched.append(item)
            }
        }
        return enriched
    }
    
    private func splitArtistString(_ artistName: String) -> [String] {
        let parsed = ArtistNameParser.splitArtists(from: artistName)
        if parsed.isEmpty {
            let trimmed = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        return parsed
    }
    
    private func findBestArtistMatch(from artists: MusicItemCollection<MusicKit.Artist>, targetName: String) -> MusicKit.Artist? {
        let lower = targetName.lowercased()
        if let exact = artists.first(where: { $0.name.lowercased() == lower }) { return exact }
        if let prefix = artists.first(where: { $0.name.lowercased().hasPrefix(lower) }) { return prefix }
        return artists.first
    }
    
    private func meetsTrendingThreshold(item: TrendingItem) -> Bool {
        item.logCount >= 2
    }
    
    private func calculateTrendingScore(item: TrendingItem, logs: [MusicLog]) -> Double {
        let rating = item.averageRating ?? 3.0
        let recentBoost = logs.compactMap { log in
            let hours = Date().timeIntervalSince(log.dateLogged) / 3600.0
            return max(0, 48 - hours)
        }.reduce(0, +) / Double(max(1, logs.count))
        return Double(item.logCount) * 0.7 + rating * 1.5 + recentBoost * 0.2
    }
    
    private func canonicalId(for log: MusicLog) -> String {
        switch log.itemType {
        case "song":
            return canonicalSongId(for: log)
        case "album":
            return canonicalAlbumId(for: log)
        case "artist":
            return canonicalArtistId(for: log)
        default:
            return log.itemId
        }
    }
    
    private func canonicalSongId(for log: MusicLog) -> String {
        if let universal = log.universalTrackId, !universal.isEmpty {
            return universal
        }
        if !log.itemId.isEmpty {
            return log.itemId
        }
        let title = log.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let artist = log.artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "song|\(title)|\(artist)"
    }
    
    private func canonicalAlbumId(for log: MusicLog) -> String {
        if let universal = log.universalTrackId, !universal.isEmpty {
            return universal
        }
        if !log.itemId.isEmpty {
            return log.itemId
        }
        let title = log.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let artist = log.artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "album|\(title)|\(artist)"
    }
    
    private func canonicalArtistId(for log: MusicLog) -> String {
        let normalized = ArtistNameParser.normalizedKey(log.artistName)
        if !normalized.isEmpty {
            return normalized
        }
        if !log.itemId.isEmpty {
            return log.itemId
        }
        return log.artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private func groupingKey(for log: MusicLog) -> String {
        groupingKey(itemType: log.itemType, itemId: canonicalId(for: log))
    }
    
    private func groupingKey(itemType: String, itemId: String) -> String {
        "\(itemType)|\(itemId)"
    }
    
    private func preferredDisplayLog(from logs: [MusicLog]) -> MusicLog? {
        logs.first(where: { isAppleLog($0) }) ?? logs.first
    }
    
    private func appleMusicId(from logs: [MusicLog]) -> String? {
        logs.first(where: { isAppleLog($0) })?.itemId
    }
    
    private func isAppleLog(_ log: MusicLog) -> Bool {
        log.musicPlatform?.lowercased().contains("apple") == true
    }
    
    private func ratingLookupKeys(for item: TrendingItem) -> [String] {
        var keys: [String] = []
        
        // Add appleMusicId if available
        if let appleId = item.appleMusicId, !appleId.isEmpty {
            keys.append(appleId)
        }
        
        // Handle itemId (which might have "itemType|" prefix from groupingKey)
        if !item.itemId.isEmpty {
            // If itemId contains the grouping key format "itemType|actualId", extract just the actualId
            if item.itemId.contains("|"), let actualId = item.itemId.split(separator: "|").last {
                let strippedId = String(actualId)
                if !keys.contains(strippedId) {
                    keys.append(strippedId)
                }
            }
            // Also add the full itemId as-is for fallback
            if !keys.contains(item.itemId) {
                keys.append(item.itemId)
            }
        }
        
        return keys
    }
    
    private func getAdaptiveTrendingTimeWindow() -> Date {
        let now = Date()
        guard let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now) else { return now }
        return threeDaysAgo
    }
    
    private func fetchFollowingAndFollowers(for uid: String) async throws -> (following: [String], followers: [String]) {
        async let followingSnapshot = db.collection("users").document(uid).collection("following").getDocuments()
        async let followersSnapshot = db.collection("users").document(uid).collection("followers").getDocuments()
        let (followingDocs, followersDocs) = try await (followingSnapshot, followersSnapshot)
        var followingIds = followingDocs.documents.map { $0.documentID }
        var followerIds = followersDocs.documents.map { $0.documentID }
        
        // Fallback to legacy array fields if subcollections have not been populated yet
        if followingIds.isEmpty || followerIds.isEmpty {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            if let profile = try? userDoc.data(as: UserProfile.self) {
                if followingIds.isEmpty, let inlineFollowing = profile.following {
                    followingIds = inlineFollowing
                }
                if followerIds.isEmpty, let inlineFollowers = profile.followers {
                    followerIds = inlineFollowers
                }
            } else if let raw = userDoc.data() {
                if followingIds.isEmpty, let inlineFollowing = raw["following"] as? [String] {
                    followingIds = inlineFollowing
                }
                if followerIds.isEmpty, let inlineFollowers = raw["followers"] as? [String] {
                    followerIds = inlineFollowers
                }
            }
        }
        
        return (following: followingIds, followers: followerIds)
    }

    private func eligibleFriendIds(for userId: String) async throws -> [String] {
        let (following, _) = try await fetchFollowingAndFollowers(for: userId)
        return Array(Set(following))
    }
    
    private func fetchUserProfiles(for userIds: [String]) async throws -> [UserProfile] {
        let batches = userIds.chunked(into: 10)
        var profiles: [UserProfile] = []
        for batch in batches {
            let snapshot = try await db.collection("users")
                .whereField("uid", in: batch)
                .getDocuments()
            let batchProfiles = snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
            profiles.append(contentsOf: batchProfiles)
        }
        return profiles
    }

}

// MARK: - TrendingItem convenience
private extension TrendingItem {
    func withAverageRating(_ rating: Double) -> TrendingItem {
        let normalized = TrendingItem.normalizedAverage(from: rating)
        return TrendingItem(id: id,
                            title: title,
                            subtitle: subtitle,
                            artworkUrl: artworkUrl,
                            logCount: logCount,
                            averageRating: normalized,
                            itemType: itemType,
                            itemId: itemId,
                            appleMusicId: appleMusicId)
    }
    
    func withArtwork(_ artwork: String) -> TrendingItem {
        TrendingItem(id: id,
                     title: title,
                     subtitle: subtitle,
                     artworkUrl: artwork,
                     logCount: logCount,
                     averageRating: averageRating,
                     itemType: itemType,
                     itemId: itemId,
                     appleMusicId: appleMusicId)
    }
}

