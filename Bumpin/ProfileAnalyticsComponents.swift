import SwiftUI
import Charts

// MARK: - Enhanced Analytics Cards

struct EnhancedRatingDistributionView: View {
    let itemId: String
    let itemType: String
    let itemTitle: String
    
    @State private var ratingData: [RatingDistributionData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var totalRatings = 0
    @State private var averageRating: Double = 0.0
    
    private let starColors: [Color] = [
        ProfileDesignSystem.Colors.error,      // 1 star
        Color.orange,                          // 2 stars  
        Color.yellow,                          // 3 stars
        ProfileDesignSystem.Colors.success,    // 4 stars
        ProfileDesignSystem.Colors.info        // 5 stars
    ]
    
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
            Task { await loadRatingDistribution() }
        }
    }
    
    private var ratingBarsView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            ForEach(ratingData.sorted(by: { $0.starRating > $1.starRating })) { rating in
                EnhancedRatingBarRow(
                    rating: rating,
                    maxCount: ratingData.map(\.count).max() ?? 1,
                    color: starColors[rating.starRating - 1]
                )
            }
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
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            Image(systemName: "star.circle")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            Text("No ratings yet")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
            Text("Be the first to rate this \(itemType)")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Data Loading (reuse from RatingDistributionView)
    @MainActor
    private func loadRatingDistribution() async {
        isLoading = true
        errorMessage = nil
        
        // This will reuse the same logic from RatingDistributionView
        // For now, create mock data to demonstrate the UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.ratingData = [
                RatingDistributionData(starRating: 5, count: 45, totalRatings: 100),
                RatingDistributionData(starRating: 4, count: 30, totalRatings: 100),
                RatingDistributionData(starRating: 3, count: 15, totalRatings: 100),
                RatingDistributionData(starRating: 2, count: 7, totalRatings: 100),
                RatingDistributionData(starRating: 1, count: 3, totalRatings: 100)
            ]
            self.totalRatings = 100
            self.averageRating = 4.1
            self.isLoading = false
        }
    }
}

// MARK: - Enhanced Rating Bar Row

struct EnhancedRatingBarRow: View {
    let rating: RatingDistributionData
    let maxCount: Int
    let color: Color
    
    private var barWidth: CGFloat {
        guard maxCount > 0, rating.count >= 0 else { return 0 }
        let width = CGFloat(rating.count) / CGFloat(maxCount)
        return min(max(width, 0), 1)
    }
    
    var body: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.md) {
            // Star rating display
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating.starRating ? "star.fill" : "star")
                        .font(ProfileDesignSystem.Typography.captionMedium)
                        .foregroundColor(star <= rating.starRating ? color : ProfileDesignSystem.Colors.ratingInactive)
                }
            }
            .frame(width: 80, alignment: .leading)
            
            // Progress bar with enhanced styling
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ProfileDesignSystem.Colors.surface)
                        .frame(height: 12)
                    
                    // Filled portion
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * barWidth, height: 12)
                        .animation(.easeInOut(duration: 0.6), value: barWidth)
                }
            }
            .frame(height: 12)
            
            // Count and percentage
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(rating.count)")
                    .font(ProfileDesignSystem.Typography.captionLarge)
                    .fontWeight(.bold)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                Text("\(Int(rating.percentage))%")
                    .font(ProfileDesignSystem.Typography.captionSmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
            }
            .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Enhanced Popularity Graph Card

struct EnhancedPopularityGraphView: View {
    let itemId: String
    let itemType: String
    let itemTitle: String
    
    @State private var selectedTimeRange: PopularityTimeRange = .month
    @State private var dataPoints: [PopularityDataPoint] = []
    @State private var isLoading = false
    @State private var totalLogs = 0
    @State private var peakCount = 0
    @State private var peakDate: Date?
    
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
            loadMockData() // For demonstration
        }
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.sm) {
            ForEach(PopularityTimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedTimeRange = range
                    loadMockData()
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
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(ProfileDesignSystem.Colors.textTertiary)
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatDate(date))
                            .font(ProfileDesignSystem.Typography.captionSmall)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(ProfileDesignSystem.Colors.textTertiary)
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
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(ProfileDesignSystem.Typography.headlineSmall)
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            Text("No popularity data")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
            Text("Data will appear as users log this \(itemType)")
                .font(ProfileDesignSystem.Typography.captionLarge)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
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
    
    private func loadMockData() {
        // Mock data for demonstration
        let calendar = Calendar.current
        let today = Date()
        
        dataPoints = (0..<30).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return nil }
            let count = Int.random(in: 0...10)
            return PopularityDataPoint(date: date, logCount: count, period: "day")
        }.reversed()
        
        totalLogs = dataPoints.reduce(0) { $0 + $1.logCount }
        let maxPoint = dataPoints.max { $0.logCount < $1.logCount }
        peakCount = maxPoint?.logCount ?? 0
        peakDate = maxPoint?.date
    }
}

// MARK: - Enhanced Social Section

struct EnhancedSocialSection: View {
    let comments: [MusicComment]
    let userRatings: [String: Int] // User ID to rating mapping
    let onLoadMoreComments: () -> Void
    let onAddComment: () -> Void
    let onCommentLike: (MusicComment) -> Void
    let onCommentRepost: (MusicComment) -> Void
    let onCommentReply: (MusicComment) -> Void
    let onCommentThumbsDown: (MusicComment) -> Void
    
    var body: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            // Section header
            ProfileSectionHeader(
                title: "Community",
                subtitle: comments.isEmpty ? "No comments yet" : "\(comments.count) comments",
                icon: "bubble.left.and.bubble.right.fill",
                action: comments.count > 3 ? onLoadMoreComments : nil,
                actionTitle: comments.count > 3 ? "View All" : nil
            )
            
            if comments.isEmpty {
                emptyCommentsView
            } else {
                commentsPreview
            }
            
            // Add comment button
            addCommentButton
        }
        .padding(ProfileDesignSystem.Spacing.cardPadding)
        .profileCard()
    }
    
    private var emptyCommentsView: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            Image(systemName: "bubble.left.circle")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
            
            Text("No comments yet")
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text("Share your thoughts about this song")
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
    
    private var commentsPreview: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            ForEach(Array(comments.prefix(3))) { comment in
                EnhancedCommentRow(
                    comment: comment,
                    userRating: userRatings[comment.userId],
                    onLike: { onCommentLike(comment) },
                    onRepost: { onCommentRepost(comment) },
                    onReply: { onCommentReply(comment) },
                    onThumbsDown: { onCommentThumbsDown(comment) }
                )
            }
        }
    }
    
    private var addCommentButton: some View {
        Button(action: onAddComment) {
            HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                Image(systemName: "plus.bubble.fill")
                Text("Add Comment")
            }
            .font(ProfileDesignSystem.Typography.bodyMedium)
            .fontWeight(.semibold)
            .foregroundColor(ProfileDesignSystem.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding(ProfileDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                    .stroke(ProfileDesignSystem.Colors.primary, lineWidth: 1.5)
            )
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: ProfileDesignSystem.Spacing.md) {
                // User avatar
                Circle()
                    .fill(ProfileDesignSystem.Colors.surface)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(comment.username.prefix(1)).uppercased())
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .fontWeight(.bold)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    )
                
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
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            EnhancedRatingDistributionView(
                itemId: "sample-id",
                itemType: "song",
                itemTitle: "Sample Song"
            )
            
            EnhancedPopularityGraphView(
                itemId: "sample-id",
                itemType: "song",
                itemTitle: "Sample Song"
            )
            
            EnhancedSocialSection(
                comments: [],
                userRatings: [:],
                onLoadMoreComments: {},
                onAddComment: {},
                onCommentLike: { _ in },
                onCommentRepost: { _ in },
                onCommentReply: { _ in },
                onCommentThumbsDown: { _ in }
            )
        }
        .padding()
    }
}
