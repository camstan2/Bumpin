import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// View for users to see all ratings they've received (only visible ones)
struct MyRatingsView: View {
    @StateObject private var viewModel = MyRatingsViewModel()
    @State private var selectedFilter: RatingFilter = .all
    @State private var showFilterSheet = false
    
    enum RatingFilter: String, CaseIterable, Identifiable {
        case all = "All Ratings"
        case recent = "Recent (30 days)"
        case high = "High Ratings (8+)"
        case withComments = "With Comments"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .all: return "star.fill"
            case .recent: return "clock.fill"
            case .high: return "star.circle.fill"
            case .withComments: return "text.bubble.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats
                headerSection
                
                // Filter bar
                filterBar
                
                // Ratings list
                ratingsContent
            }
            .navigationTitle("My Ratings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await viewModel.loadMyRatings()
                }
            }
            .refreshable {
                await viewModel.loadMyRatings()
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            filterSheet
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Overall stats
            HStack(spacing: 20) {
                MyRatingsStatCard(
                    title: "Overall Score",
                    value: String(format: "%.1f", viewModel.overallScore),
                    subtitle: "/10",
                    color: .blue,
                    icon: "star.fill"
                )
                
                MyRatingsStatCard(
                    title: "Total Ratings",
                    value: "\(viewModel.totalRatings)",
                    subtitle: "received",
                    color: .green,
                    icon: "person.2.fill"
                )
                
                MyRatingsStatCard(
                    title: "Visible",
                    value: "\(viewModel.visibleRatings)",
                    subtitle: "unlocked",
                    color: .orange,
                    icon: "eye.fill"
                )
            }
            
            // Recent trend
            if viewModel.recentTrend != 0 {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.recentTrend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(viewModel.recentTrend > 0 ? .green : .red)
                    
                    Text(viewModel.recentTrend > 0 ? "Improving" : "Declining")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewModel.recentTrend > 0 ? .green : .red)
                    
                    Text("over last 10 ratings")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack {
            Button(action: { showFilterSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: selectedFilter.icon)
                        .font(.system(size: 14))
                    
                    Text(selectedFilter.rawValue)
                        .font(.system(size: 16, weight: .medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            
            Spacer()
            
            // Sort toggle
            Button(action: { viewModel.toggleSortOrder() }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12))
                    
                    Text(viewModel.sortAscending ? "Oldest" : "Newest")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    // MARK: - Ratings Content
    
    private var ratingsContent: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.filteredRatings.isEmpty {
                emptyStateView
            } else {
                ratingsListView
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading your ratings...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No ratings to show")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Ratings will appear here after you rate others back")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Call to action
            VStack(spacing: 12) {
                Text("💡 Tip: Rate others to unlock their ratings of you!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button(action: {
                    // TODO: Navigate to discussions or parties
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                        Text("Join a Discussion")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    private var ratingsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredRatings) { rating in
                    RatingCard(rating: rating, userProfile: viewModel.userProfiles[rating.raterId])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Filter Sheet
    
    private var filterSheet: some View {
        NavigationView {
            List {
                ForEach(RatingFilter.allCases) { filter in
                    Button(action: {
                        selectedFilter = filter
                        viewModel.applyFilter(filter)
                        showFilterSheet = false
                    }) {
                        HStack {
                            Image(systemName: filter.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text(filter.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Ratings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFilterSheet = false
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct MyRatingsStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct RatingCard: View {
    let rating: SocialRating
    let userProfile: UserProfile?
    @State private var showFullComment = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user info and rating
            HStack(spacing: 12) {
                // Profile picture
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                    )
                
                // User details
                VStack(alignment: .leading, spacing: 2) {
                    Text(userProfile?.displayName ?? "Unknown User")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("@\(userProfile?.username ?? "unknown")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Rating display
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ratingColor(rating.rating))
                        
                        Text("\(rating.rating)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ratingColor(rating.rating))
                        
                        Text("/10")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(ratingQuality(rating.rating))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ratingColor(rating.rating))
                }
            }
            
            // Interaction context
            HStack(spacing: 8) {
                Image(systemName: interactionIcon(rating.interactionType))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(interactionDescription(rating.interactionType, rating.interactionContext))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDate(rating.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Comment (if provided)
            if let comment = rating.comment, !comment.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Text("Comment:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                    
                    Text(comment)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary)
                        .lineLimit(showFullComment ? nil : 3)
                    
                    if comment.count > 150 {
                        Button(action: { showFullComment.toggle() }) {
                            Text(showFullComment ? "Show less" : "Show more")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.05))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Functions
    
    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 9...10: return .green
        case 7...8: return .blue
        case 5...6: return .orange
        default: return .red
        }
    }
    
    private func ratingQuality(_ rating: Int) -> String {
        switch rating {
        case 9...10: return "Excellent"
        case 7...8: return "Great"
        case 5...6: return "Good"
        case 3...4: return "Fair"
        default: return "Poor"
        }
    }
    
    private func interactionIcon(_ type: SocialInteraction.InteractionType) -> String {
        switch type {
        case .discussion: return "bubble.left.and.bubble.right.fill"
        case .party: return "music.note.house.fill"
        case .randomChat: return "person.2.fill"
        }
    }
    
    private func interactionDescription(_ type: SocialInteraction.InteractionType, _ context: String?) -> String {
        let baseDescription = type.displayName
        if let context = context, !context.isEmpty {
            return "\(baseDescription) • \(context)"
        }
        return baseDescription
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

// MARK: - View Model

@MainActor
class MyRatingsViewModel: ObservableObject {
    @Published var allRatings: [SocialRating] = []
    @Published var filteredRatings: [SocialRating] = []
    @Published var userProfiles: [String: UserProfile] = [:]
    @Published var isLoading = false
    @Published var sortAscending = false
    
    // Stats
    @Published var overallScore: Double = 0.0
    @Published var totalRatings: Int = 0
    @Published var visibleRatings: Int = 0
    @Published var recentTrend: Double = 0.0
    
    private let db = Firestore.firestore()
    
    func loadMyRatings() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        do {
            // Load all visible ratings for current user
            let ratingsSnapshot = try await db.collection("socialRatings")
                .whereField("ratedUserId", isEqualTo: currentUserId)
                .whereField("isVisible", isEqualTo: true)
                .order(by: "createdAt", descending: !sortAscending)
                .getDocuments()
            
            let ratings = try ratingsSnapshot.documents.compactMap { doc in
                try doc.data(as: SocialRating.self)
            }
            
            allRatings = ratings
            filteredRatings = ratings
            
            // Load user profiles for raters
            let raterIds = Array(Set(ratings.map { $0.raterId }))
            await loadUserProfiles(userIds: raterIds)
            
            // Calculate stats
            calculateStats()
            
        } catch {
            print("Error loading ratings: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadUserProfiles(userIds: [String]) async {
        for userId in userIds {
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let user = try? userDoc.data(as: UserProfile.self) {
                    userProfiles[userId] = user
                }
            } catch {
                print("Error loading user profile for \(userId): \(error)")
            }
        }
    }
    
    private func calculateStats() {
        totalRatings = allRatings.count
        visibleRatings = allRatings.count // All loaded ratings are visible
        
        if !allRatings.isEmpty {
            overallScore = Double(allRatings.map { $0.rating }.reduce(0, +)) / Double(allRatings.count)
            
            // Calculate recent trend (last 10 vs previous 10)
            if allRatings.count >= 20 {
                let sortedRatings = allRatings.sorted { $0.createdAt > $1.createdAt }
                let recent10 = Array(sortedRatings.prefix(10))
                let previous10 = Array(sortedRatings.dropFirst(10).prefix(10))
                
                let recentAvg = Double(recent10.map { $0.rating }.reduce(0, +)) / 10.0
                let previousAvg = Double(previous10.map { $0.rating }.reduce(0, +)) / 10.0
                
                recentTrend = recentAvg - previousAvg
            }
        }
    }
    
    func applyFilter(_ filter: MyRatingsView.RatingFilter) {
        switch filter {
        case .all:
            filteredRatings = allRatings
        case .recent:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            filteredRatings = allRatings.filter { $0.createdAt >= thirtyDaysAgo }
        case .high:
            filteredRatings = allRatings.filter { $0.rating >= 8 }
        case .withComments:
            filteredRatings = allRatings.filter { $0.comment != nil && !$0.comment!.isEmpty }
        }
    }
    
    func toggleSortOrder() {
        sortAscending.toggle()
        filteredRatings = filteredRatings.sorted { rating1, rating2 in
            sortAscending ? rating1.createdAt < rating2.createdAt : rating1.createdAt > rating2.createdAt
        }
    }
}

// MARK: - Preview

#Preview {
    MyRatingsView()
}
