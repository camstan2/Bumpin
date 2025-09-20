import SwiftUI
import Charts
import FirebaseFirestore

// MARK: - Data Models

struct PopularityDataPoint: Identifiable, Codable {
    let id: String
    let date: Date
    let logCount: Int
    let period: String // "day", "week", "month"
    
    init(date: Date, logCount: Int, period: String) {
        self.id = UUID().uuidString
        self.date = date
        self.logCount = logCount
        self.period = period
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        switch period {
        case "day":
            formatter.dateFormat = "MMM d"
        case "week":
            formatter.dateFormat = "MMM d"
        case "month":
            formatter.dateFormat = "MMM yyyy"
        default:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
}

enum PopularityTimeRange: String, CaseIterable {
    case week = "7 days"
    case month = "30 days"
    case threeMonths = "3 months"
    case year = "1 year"
    case allTime = "All time"
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        case .allTime: return Int.max
        }
    }
    
    var groupingPeriod: String {
        switch self {
        case .week: return "day"
        case .month: return "day"
        case .threeMonths: return "week"
        case .year: return "month"
        case .allTime: return "month"
        }
    }
}

// MARK: - Popularity Graph View

struct PopularityGraphView: View {
    let itemId: String
    let itemType: String // "song", "album", "artist"
    let itemTitle: String
    
    @State private var dataPoints: [PopularityDataPoint] = []
    @State private var selectedTimeRange: PopularityTimeRange = .month
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var totalLogs = 0
    @State private var peakCount = 0
    @State private var peakDate: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Popularity Over Time")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if !dataPoints.isEmpty {
                    HStack(spacing: 16) {
                        PopularityStatCard(title: "Total Logs", value: "\(totalLogs)", color: .blue, icon: "chart.bar")
                        PopularityStatCard(title: "Peak Day", value: "\(peakCount)", color: .green, icon: "arrow.up.circle")
                        if let peakDate = peakDate {
                            PopularityStatCard(title: "Peak Date", value: formatPeakDate(peakDate), color: .purple, icon: "calendar")
                        }
                    }
                }
            }
            
            // Time range selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PopularityTimeRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedTimeRange = range
                            Task { await loadPopularityData() }
                        }) {
                            Text(range.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedTimeRange == range ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                )
                                .foregroundColor(selectedTimeRange == range ? .blue : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // Chart or loading/error state
            if isLoading {
                chartLoadingView
            } else if let errorMessage = errorMessage {
                chartErrorView(errorMessage)
            } else if dataPoints.isEmpty {
                chartEmptyView
            } else {
                chartView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .onAppear {
            Task { await loadPopularityData() }
        }
    }
    
    // MARK: - Chart Views
    
    private var chartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Logs per \(selectedTimeRange.groupingPeriod.capitalized)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Logs", point.logCount)
                )
                .foregroundStyle(Color.blue.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Logs", point.logCount)
                )
                .foregroundStyle(Color.blue.opacity(0.1).gradient)
                
                // Add point markers for better visibility
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Logs", point.logCount)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(30)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: getXAxisStride())) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatXAxisLabel(date))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let count = value.as(Int.self) {
                            Text("\(count)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...(dataPoints.map(\.logCount).max() ?? 1))
        }
    }
    
    private var chartLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading popularity data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private func chartErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            Text("Error loading data")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private var chartEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(.gray)
            Text("No data available")
                .font(.headline)
            Text("No logs found for this time period")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Functions
    
    private func getXAxisStride() -> Calendar.Component {
        switch selectedTimeRange {
        case .week: return .day
        case .month: return .day
        case .threeMonths: return .weekOfYear
        case .year: return .month
        case .allTime: return .month
        }
    }
    
    private func formatXAxisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedTimeRange {
        case .week, .month:
            formatter.dateFormat = "MMM d"
        case .threeMonths:
            formatter.dateFormat = "MMM d"
        case .year, .allTime:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }
    
    private func formatPeakDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadPopularityData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let logs = try await fetchLogsForItem()
            let groupedData = groupLogsByTimePeriod(logs)
            dataPoints = groupedData
            calculateStats()
        } catch {
            errorMessage = error.localizedDescription
            dataPoints = []
        }
        
        isLoading = false
    }
    
    private func fetchLogsForItem() async throws -> [MusicLog] {
        let db = Firestore.firestore()
        var logs: [MusicLog] = []
        
        if itemType == "artist" {
            // For artists, fetch all logs where artistName matches
            var query = db.collection("logs").whereField("artistName", isEqualTo: itemTitle)
            
            // Add date filtering for non-allTime ranges
            if selectedTimeRange != .allTime {
                let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
                query = query.whereField("dateLogged", isGreaterThanOrEqualTo: startDate)
            }
            
            let snapshot = try await query.getDocuments()
            logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
        } else {
            // For songs and albums, fetch logs by itemId
            var query = db.collection("logs").whereField("itemId", isEqualTo: itemId)
            
            // Add date filtering for non-allTime ranges
            if selectedTimeRange != .allTime {
                let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
                query = query.whereField("dateLogged", isGreaterThanOrEqualTo: startDate)
            }
            
            let snapshot = try await query.getDocuments()
            logs = snapshot.documents.compactMap { try? $0.data(as: MusicLog.self) }
        }
        
        return logs
    }
    
    private func groupLogsByTimePeriod(_ logs: [MusicLog]) -> [PopularityDataPoint] {
        let calendar = Calendar.current
        let groupingPeriod = selectedTimeRange.groupingPeriod
        
        // Group logs by time period
        var groupedLogs: [Date: Int] = [:]
        
        for log in logs {
            let groupDate: Date
            
            switch groupingPeriod {
            case "day":
                groupDate = calendar.startOfDay(for: log.dateLogged)
            case "week":
                groupDate = calendar.dateInterval(of: .weekOfYear, for: log.dateLogged)?.start ?? log.dateLogged
            case "month":
                groupDate = calendar.dateInterval(of: .month, for: log.dateLogged)?.start ?? log.dateLogged
            default:
                groupDate = calendar.startOfDay(for: log.dateLogged)
            }
            
            groupedLogs[groupDate, default: 0] += 1
        }
        
        // Convert to data points and fill gaps
        let sortedDates = groupedLogs.keys.sorted()
        guard let startDate = sortedDates.first, let endDate = sortedDates.last else {
            return []
        }
        
        var dataPoints: [PopularityDataPoint] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let count = groupedLogs[currentDate] ?? 0
            dataPoints.append(PopularityDataPoint(
                date: currentDate,
                logCount: count,
                period: groupingPeriod
            ))
            
            // Move to next period
            switch groupingPeriod {
            case "day":
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            case "week":
                currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            case "month":
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            default:
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
        }
        
        return dataPoints
    }
    
    private func calculateStats() {
        totalLogs = dataPoints.reduce(0) { $0 + $1.logCount }
        let maxPoint = dataPoints.max { $0.logCount < $1.logCount }
        peakCount = maxPoint?.logCount ?? 0
        peakDate = maxPoint?.date
    }
}

// MARK: - Popularity Stat Card Component

private struct PopularityStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    PopularityGraphView(
        itemId: "sample-id",
        itemType: "song",
        itemTitle: "Sample Song"
    )
    .padding()
}
