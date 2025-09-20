import SwiftUI
import Charts
import FirebaseFirestore

// MARK: - Data Models

struct RatingDistributionData: Identifiable, Codable {
    let id: String
    let starRating: Int // 1-5 stars
    let count: Int
    let percentage: Double
    
    init(starRating: Int, count: Int, totalRatings: Int) {
        self.id = UUID().uuidString
        self.starRating = max(1, min(5, starRating)) // Clamp between 1 and 5
        self.count = max(0, count) // Ensure non-negative
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
    
    private let starColors: [Color] = [
        .red,      // 1 star
        .orange,   // 2 stars
        .yellow,   // 3 stars
        .green,    // 4 stars
        .blue      // 5 stars
    ]
    
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
    }
    
    // MARK: - Rating Bars View (Letterboxd Style)
    
    private var ratingBarsView: some View {
        VStack(spacing: 6) {
            ForEach(ratingData.sorted(by: { $0.starRating > $1.starRating })) { rating in
                RatingBarRow(
                    rating: rating,
                    maxCount: ratingData.map(\.count).max() ?? 1,
                    color: starColors[rating.starRating - 1]
                )
            }
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
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.title3)
                .foregroundColor(.gray)
            Text("No ratings yet")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Be the first to rate this \(itemType)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
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
            // For artists, fetch all logs where artistName matches, then filter for ratings in app
            let query = db.collection("logs")
                .whereField("artistName", isEqualTo: itemTitle)
            
            let snapshot = try await query.getDocuments()
            logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
        } else {
            // For songs and albums, fetch logs by itemId, then filter for ratings in app
            let query = db.collection("logs")
                .whereField("itemId", isEqualTo: itemId)
            
            let snapshot = try await query.getDocuments()
            logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
        }
        
        // Filter for logs with ratings in the app to avoid needing composite index
        return logs.filter { $0.rating != nil && $0.rating! > 0 }
    }
    
    private func calculateRatingDistribution(from logs: [MusicLog]) -> [RatingDistributionData] {
        var ratingCounts: [Int: Int] = [:]
        
        // Count ratings for each star level
        for log in logs {
            if let rating = log.rating, rating > 0 && rating <= 5 {
                ratingCounts[rating, default: 0] += 1
            }
        }
        
        let totalCount = logs.count
        
        // Create distribution data for all star levels (1-5)
        var distributionData: [RatingDistributionData] = []
        for star in 1...5 {
            let count = ratingCounts[star] ?? 0
            distributionData.append(RatingDistributionData(
                starRating: star,
                count: count,
                totalRatings: totalCount
            ))
        }
        
        return distributionData
    }
    
    private func calculateStats(from logs: [MusicLog]) {
        totalRatings = logs.count
        
        if totalRatings > 0 {
            let totalStars = logs.compactMap { $0.rating }.reduce(0, +)
            averageRating = Double(totalStars) / Double(totalRatings)
        } else {
            averageRating = 0.0
        }
    }
}

// MARK: - Rating Bar Row Component

struct RatingBarRow: View {
    let rating: RatingDistributionData
    let maxCount: Int
    let color: Color
    
    private var barWidth: CGFloat {
        guard maxCount > 0, rating.count >= 0 else { return 0 }
        let width = CGFloat(rating.count) / CGFloat(maxCount)
        return min(max(width, 0), 1) // Clamp between 0 and 1
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Star rating label
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating.starRating ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundColor(star <= rating.starRating ? color : .gray.opacity(0.3))
                }
            }
            .frame(width: 80, alignment: .leading)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Filled bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * barWidth, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: barWidth)
                }
            }
            .frame(height: 8)
            
            // Count and percentage
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(rating.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(Int(rating.percentage))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 35, alignment: .trailing)
        }
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
