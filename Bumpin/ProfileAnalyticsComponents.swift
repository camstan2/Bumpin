import SwiftUI
import Charts
import FirebaseFirestore
import FirebaseAuth

// MARK: - Enhanced Analytics Cards

struct EnhancedRatingDistributionView: View {
    let itemId: String
    let universalTrackId: String? // Optional universal track ID for cross-platform queries
    let itemType: String
    let itemTitle: String
    
    @State private var ratingData: [RatingDistributionData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var totalRatings = 0
    @State private var averageRating: Double = 0.0
    @State private var hasLoadedOnce = false // Prevent repeated loads
    @State private var ratingLogs: [MusicLog] = []
    @State private var selectedBucket: RatingDistributionData?
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            // Section header
            ProfileSectionHeader(
                title: "Rating Distribution",
                subtitle: totalRatings > 0 ? "\(totalRatings) total ratings" : nil,
                icon: "chart.bar.fill"
            )
            
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
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
        .onAppear {
            // Only load once to prevent lag
            if !hasLoadedOnce {
                hasLoadedOnce = true
                Task { await loadRatingDistribution() }
            }
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
    
    private var ratingBarsView: some View {
        VStack(spacing: 8) {
            ForEach(ratingData.sorted(by: { $0.lowerBound > $1.lowerBound })) { bucket in
                EnhancedRatingBarRow(
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
    
    // MARK: - Color Helper
    
    private func colorForBucket(_ bucket: RatingDistributionData) -> Color {
        let midPoint = (bucket.lowerBound + bucket.upperBound) / 2.0
        
        switch midPoint {
        case 0..<1.75:
            return ProfileDesignSystem.Colors.error
        case 1.75..<2.75:
            return .orange
        case 2.75..<3.75:
            return .yellow
        case 3.75..<4.5:
            return ProfileDesignSystem.Colors.success
        default:
            return ProfileDesignSystem.Colors.primary
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading rating data...")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.warning)
            Text("Unable to load ratings")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
            Text(message)
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 100)
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
                            colors: [ProfileDesignSystem.Colors.textTertiary, ProfileDesignSystem.Colors.textTertiary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 6) {
                Text("No Ratings Yet")
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Be the first to rate this \(itemType)")
                    .font(ProfileDesignSystem.Typography.captionLarge)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Data Loading
    private let db = Firestore.firestore()
    
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
        var logs: [MusicLog] = []
        
        if itemType == "artist" {
            // For artists, fetch all logs where artistName matches
            let query = db.collection("logs")
                .whereField("artistName", isEqualTo: itemTitle)
            
            let snapshot = try await query.getDocuments()
            logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
        } else {
            // For songs and albums, prefer universal track ID if available
            if let universalId = universalTrackId {
                print("🎯 Fetching ratings by universalTrackId: \(universalId)")
                let query = db.collection("logs")
                    .whereField("universalTrackId", isEqualTo: universalId)
                
                let snapshot = try await query.getDocuments()
                logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            } else {
                // Fallback to itemId for old logs without universal track ID
                print("⚠️ Fetching ratings by itemId (fallback): \(itemId)")
                let query = db.collection("logs")
                    .whereField("itemId", isEqualTo: itemId)
                
                let snapshot = try await query.getDocuments()
                logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            }
        }
        
        // Filter for logs with ratings
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
        let ratingsOnly = logs.compactMap { $0.rating }
        
        if ratingsOnly.isEmpty {
            averageRating = 0.0
            totalRatings = 0
        } else {
            averageRating = ratingsOnly.reduce(0.0, +) / Double(ratingsOnly.count)
            totalRatings = ratingsOnly.count
        }
    }
}

// MARK: - Enhanced Rating Bar Row

struct EnhancedRatingBarRow: View {
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
        HStack(spacing: ProfileDesignSystem.Spacing.md) {
            // Rating label
            Text(bucket.bucketRange)
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .frame(width: 80, alignment: .leading)
            
            // Progress bar with enhanced styling
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ProfileDesignSystem.Colors.surface)
                        .frame(height: 20)
                    
                    // Filled portion
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
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                .frame(width: 40, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Enhanced Popularity Graph Card

struct EnhancedPopularityGraphView: View {
    let itemId: String
    let universalTrackId: String? // Optional universal track ID for cross-platform queries
    let itemType: String
    let itemTitle: String
    
    @State private var selectedTimeRange: PopularityTimeRange = .month
    @State private var dataPoints: [PopularityDataPoint] = []
    @State private var isLoading = false
    @State private var totalLogs = 0
    @State private var peakCount = 0
    @State private var peakDate: Date?
    @State private var hasLoadedOnce = false // Prevent repeated loads
    
    // Cached X-axis values to prevent recalculation on every render
    @State private var cachedXAxisValues: [Date] = []
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            // Section header
            ProfileSectionHeader(
                title: "Popularity Over Time",
                subtitle: totalLogs > 0 ? "\(totalLogs) total logs" : nil,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            // Time range selector
            timeRangeSelector
            
            if isLoading {
                loadingView
            } else if dataPoints.isEmpty {
                emptyView
            } else {
                VStack(spacing: ProfileDesignSystem.Spacing.md) {
                    // Stats cards
                    statsCardsView
                    
                    // Chart
                    enhancedChartView
                }
            }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
        .onAppear {
            // Only load once to prevent lag
            if !hasLoadedOnce {
                hasLoadedOnce = true
                loadMockData()
            }
        }
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.sm) {
            ForEach(PopularityTimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedTimeRange = range
                    // Recalculate from cached data instead of reloading
                    Task {
                        await loadPopularityData()
                    }
                }) {
                    Text(range.rawValue)
                        .font(ProfileDesignSystem.Typography.captionLarge)
                        .fontWeight(.medium)
                        .padding(.horizontal, ProfileDesignSystem.Spacing.md)
                        .padding(.vertical, ProfileDesignSystem.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(selectedTimeRange == range ? ProfileDesignSystem.Colors.primary.opacity(0.2) : ProfileDesignSystem.Colors.surface)
                        )
                        .foregroundColor(selectedTimeRange == range ? ProfileDesignSystem.Colors.primary : ProfileDesignSystem.Colors.textSecondary)
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTimeRange)
            }
        }
    }
    
    private var statsCardsView: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.md) {
            ProfileQuickStat(
                icon: "chart.bar.fill",
                value: "\(totalLogs)",
                label: "Total Logs",
                color: ProfileDesignSystem.Colors.info
            )
            
            ProfileQuickStat(
                icon: "arrow.up.circle.fill",
                value: "\(peakCount)",
                label: "Peak Day",
                color: ProfileDesignSystem.Colors.success
            )
            
            if let peakDate = peakDate {
                ProfileQuickStat(
                    icon: "calendar.circle.fill",
                    value: formatPeakDate(peakDate),
                    label: "Peak Date",
                    color: ProfileDesignSystem.Colors.primary
                )
            }
        }
    }
    
    private var enhancedChartView: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Logs", point.logCount)
            )
            .foregroundStyle(ProfileDesignSystem.Colors.primary.gradient)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Logs", point.logCount)
            )
            .foregroundStyle(ProfileDesignSystem.Colors.primary.opacity(0.1).gradient)
            
            PointMark(
                x: .value("Date", point.date),
                y: .value("Logs", point.logCount)
            )
            .foregroundStyle(ProfileDesignSystem.Colors.primary)
            .symbolSize(40)
        }
        .frame(height: 180)
        .chartXAxis {
            AxisMarks(values: cachedXAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(ProfileDesignSystem.Colors.textTertiary.opacity(0.3))
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatSmartDate(date))
                            .font(ProfileDesignSystem.Typography.captionSmall)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(ProfileDesignSystem.Colors.textTertiary.opacity(0.2))
                AxisTick()
                AxisValueLabel {
                    if let count = value.as(Int.self) {
                        Text("\(count)")
                            .font(ProfileDesignSystem.Typography.captionSmall)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
    }
    
    // Calculate X-axis dates once (called after data loads)
    private func calculateXAxisValues() -> [Date] {
        guard !dataPoints.isEmpty else { return [] }
        
        let sortedPoints = dataPoints.sorted { $0.date < $1.date }
        guard let firstDate = sortedPoints.first?.date,
              let lastDate = sortedPoints.last?.date else {
            return []
        }
        
        // Only return first and last dates
        return [firstDate, lastDate]
    }
    
    private func formatSmartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "EEE" // Mon, Tue, Wed
        case .month:
            formatter.dateFormat = "MMM d" // Jan 1, Jan 15
        case .threeMonths:
            formatter.dateFormat = "MMM d" // Jan 1, Feb 15
        case .year, .allTime:
            formatter.dateFormat = "MMM" // Jan, Feb, Mar
        }
        
        return formatter.string(from: date)
    }
    
    private var loadingView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading popularity data...")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 14) {
            // Enhanced icon with background circle
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ProfileDesignSystem.Colors.textTertiary, ProfileDesignSystem.Colors.textTertiary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 6) {
                Text("No Activity Yet")
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Logs will appear here once users\nstart rating this \(itemType)")
                    .font(ProfileDesignSystem.Typography.captionLarge)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatPeakDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Real Data Loading
    private let db = Firestore.firestore()
    
    private func loadMockData() {
        Task {
            await loadPopularityData()
        }
    }
    
    @MainActor
    private func loadPopularityData() async {
        isLoading = true
        
        do {
            print("🎯 Loading popularity data for \(itemType): \(itemTitle) (ID: \(itemId))")
            let logs = try await fetchLogsForItem()
            print("📊 Found \(logs.count) total logs")
            
            let points = calculateDataPoints(from: logs)
            dataPoints = points
            
            totalLogs = logs.count
            let maxPoint = points.max { $0.logCount < $1.logCount }
            peakCount = maxPoint?.logCount ?? 0
            peakDate = maxPoint?.date
            
            // Cache X-axis values once
            cachedXAxisValues = calculateXAxisValues()
            
            print("✅ Popularity data loaded successfully")
        } catch {
            print("❌ Error loading popularity data: \(error.localizedDescription)")
            dataPoints = []
            cachedXAxisValues = []
        }
        
        isLoading = false
    }
    
    private func fetchLogsForItem() async throws -> [MusicLog] {
        var logs: [MusicLog] = []
        
        if itemType == "artist" {
            // For artists, fetch all logs where artistName matches
            let query = db.collection("logs")
                .whereField("artistName", isEqualTo: itemTitle)
            
            let snapshot = try await query.getDocuments()
            logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
        } else {
            // For songs and albums, prefer universal track ID if available
            if let universalId = universalTrackId {
                print("🎯 Fetching logs by universalTrackId: \(universalId)")
                let query = db.collection("logs")
                    .whereField("universalTrackId", isEqualTo: universalId)
                
                let snapshot = try await query.getDocuments()
                logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            } else {
                // Fallback to itemId for old logs without universal track ID
                print("⚠️ Fetching logs by itemId (fallback): \(itemId)")
                let query = db.collection("logs")
                    .whereField("itemId", isEqualTo: itemId)
                
                let snapshot = try await query.getDocuments()
                logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
            }
        }
        
        return logs
    }
    
    private func calculateDataPoints(from logs: [MusicLog]) -> [PopularityDataPoint] {
        guard !logs.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Determine date range based on selected time range
        var startDate: Date
        switch selectedTimeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        case .threeMonths:
            startDate = calendar.date(byAdding: .day, value: -90, to: today) ?? today
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: today) ?? today
        case .allTime:
            // Find earliest log date
            startDate = logs.map { $0.dateLogged }.min() ?? today
        }
        
        // Group logs by date
        var logsByDate: [Date: Int] = [:]
        for log in logs {
            let logDate = log.dateLogged
            
            // Only include logs within the selected time range
            guard logDate >= startDate else { continue }
            
            // Normalize to start of day
            let normalizedDate = calendar.startOfDay(for: logDate)
            logsByDate[normalizedDate, default: 0] += 1
        }
        
        // Create data points for each day in range
        var points: [PopularityDataPoint] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let endDate = calendar.startOfDay(for: today)
        
        while currentDate <= endDate {
            let count = logsByDate[currentDate] ?? 0
            points.append(PopularityDataPoint(date: currentDate, logCount: count, period: "day"))
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        
        return points
    }
}

// MARK: - Enhanced Social Section

struct EnhancedSocialSection: View {
    let musicItem: MusicSearchResult // Added to support navigation
    let logs: [MusicLog] // Changed from comments to logs
    let onViewAllLogs: () -> Void // Navigation to see all
    
    @State private var selectedLog: MusicLog?
    @State private var showCommunitySeeAll = false
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            // Section header
            ProfileSectionHeader(
                title: "Community",
                subtitle: logs.isEmpty ? "No logs yet" : "\(logs.count) logs",
                icon: "bubble.left.and.bubble.right.fill",
                action: logs.count > 3 ? { showCommunitySeeAll = true } : nil,
                actionTitle: logs.count > 3 ? "View All" : nil
            )
            
            if logs.isEmpty {
                emptyLogsView
            } else {
                logsPreview
            }
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
        .fullScreenCover(isPresented: $showCommunitySeeAll) {
            CommunitySeeAllView(musicItem: musicItem)
        }
        .fullScreenCover(item: $selectedLog) { log in
            UnifiedLogCommentsView(log: log)
        }
    }
    
    private var emptyLogsView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            Image(systemName: "music.note.list")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            
            Text("No logs yet")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text("Be the first to log this \(musicItem.itemType)!")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(ProfileDesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                .fill(ProfileDesignSystem.Colors.surface)
        )
    }
    
    private var logsPreview: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            ForEach(Array(logs.prefix(3))) { log in
                CommunityLogCard(log: log)
                    .onTapGesture {
                        selectedLog = log
                    }
            }
        }
    }
}

// MARK: - Community Log Card

private struct CommunityLogCard: View {
    let log: MusicLog
    @State private var userProfile: UserProfile?
        @State private var isLiked: Bool = false
        @State private var likeCount: Int = 0
        @State private var hasThumbsDown: Bool = false
        @State private var hasReposted: Bool = false
        @State private var repostCount: Int = 0
        @State private var showActivity = false
        @State private var showReportSheet = false
        @State private var showBlockSheet = false
        @State private var showUserProfile = false
    
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
        .contextMenu {
            Button {
                showReportSheet = true
            } label: {
                Label("Report", systemImage: "flag")
            }
        }
        .onAppear {
            loadUserProfile()
            loadEngagement()
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
        
        print("🔍 [CommunityLogCard] toggleThumbsDown called - current state: \(hasThumbsDown)")
        
        Task {
            let db = Firestore.firestore()
            let thumbsDownRef = db.collection("logs").document(log.id).collection("thumbsDown").document(currentUserId)
            
            do {
                if hasThumbsDown {
                    print("🔍 [CommunityLogCard] Deleting thumbs down...")
                    try await thumbsDownRef.delete()
                    
                    // ✅ Decrement the thumbs down count
                    try await db.collection("logs").document(log.id).updateData([
                        "thumbsDownCount": FieldValue.increment(Int64(-1))
                    ])
                    
                    await MainActor.run {
                        hasThumbsDown = false
                        print("✅ [CommunityLogCard] Thumbs down removed - new state: \(hasThumbsDown)")
                        LogEngagementCache.shared.updateEngagement(logId: log.id, hasThumbsDown: false)
                    }
                } else {
                    print("🔍 [CommunityLogCard] Adding thumbs down...")
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
                        print("✅ [CommunityLogCard] Thumbs down added - new state: \(hasThumbsDown)")
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
        
        print("🔍 [CommunityLogCard] handleRepost called - current state: hasReposted=\(hasReposted), count=\(repostCount)")
        
        Task {
            let db = Firestore.firestore()
            let repostRef = db.collection("logs").document(log.id).collection("reposts").document(currentUserId)
            
            do {
                if hasReposted {
                    print("🔍 [CommunityLogCard] Deleting repost...")
                    try await repostRef.delete()
                    try await db.collection("logs").document(log.id).updateData([
                        "repostCount": FieldValue.increment(Int64(-1))
                    ])
                    
                    await MainActor.run {
                        hasReposted = false
                        repostCount = max(0, repostCount - 1)
                        print("✅ [CommunityLogCard] Repost removed - new state: hasReposted=\(hasReposted), count=\(repostCount)")
                        LogEngagementCache.shared.updateEngagement(logId: log.id, hasReposted: false)
                    }
                } else {
                    print("🔍 [CommunityLogCard] Adding repost...")
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
                        print("✅ [CommunityLogCard] Repost added - new state: hasReposted=\(hasReposted), count=\(repostCount)")
                        LogEngagementCache.shared.updateEngagement(logId: log.id, hasReposted: true)
                    }
                }
            } catch {
                print("❌ Error handling repost: \(error)")
            }
        }
    }
}

// MARK: - Enhanced Comment Row

struct EnhancedCommentRow: View {
    let comment: MusicComment
    let userRating: Int? // Star rating this user gave
    let onLike: () -> Void
    let onRepost: () -> Void
    let onReply: () -> Void
    let onThumbsDown: () -> Void
    
    @State private var userProfileImage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: ProfileDesignSystem.Spacing.md) {
                // User avatar (use profile image if available)
                if let urlString = userProfileImage ?? comment.userProfileImage,
                   let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(ProfileDesignSystem.Colors.surface)
                            .overlay(
                                Text(String(comment.username.prefix(1)).uppercased())
                                    .font(ProfileDesignSystem.Typography.captionLarge)
                                    .fontWeight(.bold)
                                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                            )
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(ProfileDesignSystem.Colors.surface)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(comment.username.prefix(1)).uppercased())
                                .font(ProfileDesignSystem.Typography.captionLarge)
                                .fontWeight(.bold)
                                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                        )
                }
                
                VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.xs) {
                    // Username, rating, and timestamp
                    HStack(alignment: .center, spacing: ProfileDesignSystem.Spacing.sm) {
                        Text(comment.username)
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                        
                        // User's star rating for this item
                        if let rating = userRating, rating > 0 {
                            HStack(spacing: 1) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 8))
                                        .foregroundColor(star <= rating ? ProfileDesignSystem.Colors.ratingGold : ProfileDesignSystem.Colors.ratingInactive)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ProfileDesignSystem.Colors.ratingGold.opacity(0.1))
                            )
                        }
                        
                        Spacer()
                        
                        Text(comment.timestamp, style: .relative)
                            .font(ProfileDesignSystem.Typography.captionSmall)
                            .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                    }
                    
                    // Comment text
                    Text(comment.comment)
                        .font(ProfileDesignSystem.Typography.bodySmall)
                        .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Engagement actions
            HStack(spacing: ProfileDesignSystem.Spacing.lg) {
                // Like button
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.userLiked == true ? "heart.fill" : "heart")
                        if comment.likes > 0 {
                            Text("\(comment.likes)")
                        }
                    }
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(comment.userLiked == true ? ProfileDesignSystem.Colors.error : ProfileDesignSystem.Colors.textSecondary)
                }
                
                // Repost button
                Button(action: onRepost) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                        // Note: Would need to track repost count from logs
                        Text("Repost")
                    }
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                }
                
                // Reply button
                Button(action: onReply) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        if comment.replies.count > 0 {
                            Text("\(comment.replies.count)")
                        } else {
                            Text("Reply")
                        }
                    }
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                }
                
                // Thumbs down button
                Button(action: onThumbsDown) {
                    HStack(spacing: 4) {
                        Image(systemName: comment.userDisliked == true ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        if comment.dislikes > 0 {
                            Text("\(comment.dislikes)")
                        }
                    }
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(comment.userDisliked == true ? ProfileDesignSystem.Colors.warning : ProfileDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.leading, 48) // Align with comment text
        }
        .padding(ProfileDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                .fill(ProfileDesignSystem.Colors.surface)
        )
        .onAppear {
            if comment.userProfileImage == nil && userProfileImage == nil {
                loadUserProfileImage()
            }
        }
    }
    
    private func loadUserProfileImage() {
        guard userProfileImage == nil else { return }
        
        Task {
            let db = Firestore.firestore()
            do {
                let doc = try await db.collection("users").document(comment.userId).getDocument()
                if let profile = try? doc.data(as: UserProfile.self),
                   let imageUrl = profile.profilePictureUrl {
                    await MainActor.run {
                        self.userProfileImage = imageUrl
                    }
                }
            } catch {
                print("❌ Error loading user profile image for comment: \(error)")
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            EnhancedRatingDistributionView(
                itemId: "sample-id",
                universalTrackId: nil,
                itemType: "song",
                itemTitle: "Sample Song"
            )
            
            EnhancedPopularityGraphView(
                itemId: "sample-id",
                universalTrackId: nil,
                itemType: "song",
                itemTitle: "Sample Song"
            )
            
            EnhancedSocialSection(
                musicItem: MusicSearchResult(
                    id: "sample-id",
                    title: "Sample Song",
                    artistName: "Sample Artist",
                    albumName: "",
                    artworkURL: nil,
                    itemType: "song",
                    popularity: 100
                ),
                logs: [],
                onViewAllLogs: {}
            )
        }
        .padding()
    }
}
