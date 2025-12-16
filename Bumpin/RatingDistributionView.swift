import SwiftUI
import Charts
import FirebaseFirestore

// MARK: - Data Models

struct RatingDistributionData: Identifiable, Codable {
    let id: String
    let bucketRange: String // e.g., "1.0-1.4", "1.5-1.9", etc.
    let lowerBound: Double  // e.g., 1.0, 1.5, etc.
    let upperBound: Double  // e.g., 1.4, 1.9, etc.
    let count: Int
    let percentage: Double
    
    init(lowerBound: Double, upperBound: Double, count: Int, totalRatings: Int) {
        self.id = UUID().uuidString
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        
        // Format range string
        if lowerBound.truncatingRemainder(dividingBy: 1.0) == 0 {
            self.bucketRange = String(format: "%.0f-%.1f★", lowerBound, upperBound)
        } else {
            self.bucketRange = String(format: "%.1f-%.1f★", lowerBound, upperBound)
        }
        
        self.count = max(0, count)
        self.percentage = totalRatings > 0 ? (Double(max(0, count)) / Double(max(1, totalRatings))) * 100 : 0
    }
}

// MARK: - Rating Distribution View

struct RatingDistributionView: View {
    let itemId: String
    let itemType: String // "song", "album", "artist"
    let itemTitle: String
    
    @State private var ratingData: [RatingDistributionData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var totalRatings = 0
    @State private var averageRating: Double = 0.0
    @State private var ratingLogs: [MusicLog] = []
    @State private var selectedBucket: RatingDistributionData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Rating Distribution")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if totalRatings > 0 {
                    Text("\(totalRatings) ratings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(errorMessage)
            } else if ratingData.isEmpty || totalRatings == 0 {
                emptyView
            } else {
                ratingBarsView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .onAppear {
            Task { await loadRatingDistribution() }
        }
        .sheet(item: $selectedBucket) { bucket in
            let bucketLogs = logsForBucket(bucket, in: ratingLogs)
            RatingBucketDetailView(
                bucket: bucket,
                logs: bucketLogs,
                title: bucket.bucketRange,
                subtitle: "\(bucketLogs.count) logs • \(itemTitle)"
            )
        }
    }
    
    // MARK: - Rating Bars View (Letterboxd Style)
    
    private var ratingBarsView: some View {
        VStack(spacing: 8) {
            ForEach(ratingData.sorted(by: { $0.lowerBound > $1.lowerBound })) { bucket in
                RatingBarRow(
                    bucket: bucket,
                    maxCount: ratingData.map(\.count).max() ?? 1,
                    color: colorForBucket(bucket),
                    onTap: {
                        selectedBucket = bucket
                    }
                )
            }
        }
    }
    
    // MARK: - Rating Bar Row Component
    
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
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 20)
                        
                        // Filled portion with gradient
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * barWidth, height: 20)
                            .animation(.easeInOut(duration: 0.6), value: barWidth)
                    }
                }
                .frame(height: 20)
                
                // Count
                Text("\(bucket.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 40, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
        }
    }
    
    // MARK: - Color Helper
    
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
            return .purple
        }
    }
    
    // MARK: - Loading and Error States
    
    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading ratings...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundColor(.orange)
            Text("Error loading ratings")
                .font(.subheadline)
                .fontWeight(.medium)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 14) {
            // Enhanced icon with background circle
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "star.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray, .gray.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 6) {
                Text("No Ratings Yet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Be the first to rate this \(itemType)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadRatingDistribution() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🎯 Loading rating distribution for \(itemType): \(itemTitle) (ID: \(itemId))")
            let logs = try await fetchRatingsForItem()
            print("📊 Found \(logs.count) logs with ratings")
            let distributionData = calculateRatingDistribution(from: logs)
            ratingData = distributionData
            calculateStats(from: logs)
            ratingLogs = logs
            print("✅ Rating distribution loaded successfully")
        } catch {
            print("❌ Error loading rating distribution: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            ratingData = []
        }
        
        isLoading = false
    }
    
    private func fetchRatingsForItem() async throws -> [MusicLog] {
        let db = Firestore.firestore()
        var logs: [MusicLog] = []
        
        if itemType == "artist" {
            let normalized = ArtistNameParser.normalizedKey(itemTitle)
            let tokenSnapshot = try await db.collection("logs")
                .whereField("artistTokens", arrayContains: normalized)
                .getDocuments()
            logs = tokenSnapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            
            if logs.isEmpty {
                let fallbackSnapshot = try await db.collection("logs")
                    .whereField("artistName", isEqualTo: itemTitle)
                    .getDocuments()
                logs = fallbackSnapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            }
            
            await ensureArtistTokensIfNeeded(for: logs)
        } else {
            // For songs and albums, fetch logs by itemId, then filter for ratings in app
            let query = db.collection("logs")
                .whereField("itemId", isEqualTo: itemId)
            
            let snapshot = try await query.getDocuments()
            logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            
            await ensureArtistTokensIfNeeded(for: logs)
        }
        
        // Filter for logs with ratings in the app to avoid needing composite index
        return logs.filter { $0.rating != nil && $0.rating! > 0 }
    }
    
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
    
    private func calculateStats(from logs: [MusicLog]) {
        totalRatings = logs.count
        
        if totalRatings > 0 {
            let totalStars = logs.compactMap { $0.rating }.reduce(0.0, +)
            let average = totalStars / Double(totalRatings)
            averageRating = (average * 10).rounded() / 10
        } else {
            averageRating = 0.0
        }
    }

@MainActor
private func ensureArtistTokensIfNeeded(for logs: [MusicLog]) async {
    let db = Firestore.firestore()
    for log in logs where (log.artistTokens?.isEmpty ?? true) {
        let tokens = ArtistNameParser.tokens(from: log.artistName)
        guard !tokens.isEmpty else { continue }
        do {
            try await db.collection("logs").document(log.id).updateData([
                "artistTokens": tokens
            ])
        } catch {
            print("⚠️ Failed to backfill artist tokens for log \(log.id): \(error.localizedDescription)")
        }
    }
}
}

// MARK: - Shared Helpers

func logsForBucket(_ bucket: RatingDistributionData, in logs: [MusicLog]) -> [MusicLog] {
    let lower = bucket.lowerBound
    let upper = bucket.upperBound
    let filteredLogs = logs.filter { log in
        guard let rating = log.rating else { return false }
        // Allow slight floating point tolerance
        return rating >= lower - 0.001 && rating <= upper + 0.001
    }
    
    // Sort by engagement: likes + commentCount + helpfulCount (best effort), fall back to date.
    return filteredLogs.sorted { lhs, rhs in
        let lhsScore = (lhs.likeCount ?? 0)
            + (lhs.commentCount ?? 0)
            + (lhs.helpfulCount ?? 0)
        let rhsScore = (rhs.likeCount ?? 0)
            + (rhs.commentCount ?? 0)
            + (rhs.helpfulCount ?? 0)
        
        if lhsScore == rhsScore {
            return lhs.dateLogged > rhs.dateLogged
        }
        return lhsScore > rhsScore
    }
}

struct RatingBucketDetailView: View {
    let bucket: RatingDistributionData
    let logs: [MusicLog]
    let title: String
    var subtitle: String? = nil
    var emptyMessage: String = "No logs in this range yet."
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
            Text(title)
                    .font(.headline)
                    .padding(.top, 8)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 12)
            
            Divider()
            
            if logs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(.secondary)
                    Text(emptyMessage)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(logs) { log in
                            PopularLogRow(log: log, reposterNames: nil)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

#Preview {
    VStack(spacing: 20) {
        RatingDistributionView(
            itemId: "sample-id",
            itemType: "song",
            itemTitle: "Sample Song"
        )
        
        RatingDistributionView(
            itemId: "sample-artist-id",
            itemType: "artist",
            itemTitle: "Sample Artist"
        )
    }
    .padding()
}
