import SwiftUI

struct TrendingGamesView: View {
    @StateObject private var gameService = GameService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: GameCategory = .all
    @State private var refreshing = false
    @State private var showingSpectatorView = false
    @State private var selectedGameSession: GameSession?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Category Filter
                categoryFilter
                
                // Games List
                gamesList
            }
            .navigationTitle("Trending Games")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingSpectatorView) {
            if let session = selectedGameSession {
                SpectatorGameView(gameSession: session) {
                    showingSpectatorView = false
                    selectedGameSession = nil
                }
            }
        }
        .onAppear {
            Task {
                await loadTrendingGames()
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Games")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Watch popular games in progress")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Refresh Button
                Button(action: {
                    Task {
                        await refreshTrendingGames()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(refreshing)
            }
            .padding(.horizontal)
            
            // Stats Row
            TrendingStatsView(
                totalGames: filteredGames.count,
                totalSpectators: filteredGames.reduce(0) { $0 + $1.spectatorCount },
                mostPopularGame: mostPopularGame
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(GameCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        count: getGamesCount(for: category)
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var gamesList: some View {
        Group {
            if gameService.isLoading && !refreshing {
                LoadingGamesView()
            } else if filteredGames.isEmpty {
                EmptyTrendingGamesView(category: selectedCategory)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredGames, id: \.id) { gameSession in
                            TrendingGameCard(gameSession: gameSession) {
                                selectedGameSession = gameSession
                                showingSpectatorView = true
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await refreshTrendingGames()
                }
            }
        }
    }
    
    private var filteredGames: [GameSession] {
        let allGames = gameService.trendingGames + gameService.availableGames.filter { $0.isGameActive }
        
        switch selectedCategory {
        case .all:
            return allGames.sorted { $0.trendingScore > $1.trendingScore }
        case .imposter:
            return allGames.filter { $0.gameType == .imposter }.sorted { $0.trendingScore > $1.trendingScore }
        case .friends:
            return gameService.friendsGames.filter { $0.isGameActive }
        case .celebrity:
            return allGames.filter { $0.isHighlighted }.sorted { $0.spectatorCount > $1.spectatorCount }
        }
    }
    
    private var mostPopularGame: GameSession? {
        return filteredGames.max { $0.spectatorCount < $1.spectatorCount }
    }
    
    private func getGamesCount(for category: GameCategory) -> Int {
        switch category {
        case .all:
            return gameService.trendingGames.count + gameService.availableGames.filter { $0.isGameActive }.count
        case .imposter:
            return (gameService.trendingGames + gameService.availableGames).filter { $0.gameType == .imposter }.count
        case .friends:
            return gameService.friendsGames.filter { $0.isGameActive }.count
        case .celebrity:
            return (gameService.trendingGames + gameService.availableGames).filter { $0.isHighlighted }.count
        }
    }
    
    private func loadTrendingGames() async {
        await gameService.fetchTrendingGames()
        await gameService.fetchAvailableGames()
        await gameService.fetchFriendsGames()
    }
    
    private func refreshTrendingGames() async {
        refreshing = true
        await loadTrendingGames()
        refreshing = false
    }
}

// MARK: - Game Category

enum GameCategory: String, CaseIterable {
    case all = "all"
    case imposter = "imposter"
    case friends = "friends"
    case celebrity = "celebrity"
    
    var displayName: String {
        switch self {
        case .all: return "All Games"
        case .imposter: return "Imposter"
        case .friends: return "Friends"
        case .celebrity: return "Celebrity"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "gamecontroller.fill"
        case .imposter: return "person.fill.questionmark"
        case .friends: return "person.2.fill"
        case .celebrity: return "star.fill"
        }
    }
}

// MARK: - Trending Stats View

struct TrendingStatsView: View {
    let totalGames: Int
    let totalSpectators: Int
    let mostPopularGame: GameSession?
    
    var body: some View {
        HStack(spacing: 20) {
            StatTile(
                title: "Live Games",
                value: "\(totalGames)",
                icon: "play.circle.fill",
                color: .green
            )
            
            StatTile(
                title: "Spectators",
                value: "\(totalSpectators)",
                icon: "eye.fill",
                color: .orange
            )
            
            if let popular = mostPopularGame {
                StatTile(
                    title: "Most Popular",
                    value: popular.gameType.displayName,
                    icon: "star.fill",
                    color: .yellow
                )
            }
        }
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let category: GameCategory
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.caption)
                
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.blue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Trending Game Card

struct TrendingGameCard: View {
    let gameSession: GameSession
    let onSpectate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: gameSession.gameType.iconName)
                            .font(.title3)
                            .foregroundColor(.blue)
                        
                        Text(gameSession.topicChat.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        if gameSession.isHighlighted {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text("by \(gameSession.topicChat.hostName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                GameStatusBadge(status: gameSession.gameStatus)
            }
            
            // Game Info
            HStack(spacing: 16) {
                GameInfoItem(
                    icon: "person.2.fill",
                    value: "\(gameSession.activePlayerCount)",
                    label: "Players",
                    color: .green
                )
                
                GameInfoItem(
                    icon: "eye.fill",
                    value: "\(gameSession.spectatorCount)",
                    label: "Watching",
                    color: .orange
                )
                
                if let duration = gameSession.gameDuration {
                    GameInfoItem(
                        icon: "clock.fill",
                        value: formatDuration(duration),
                        label: "Duration",
                        color: .blue
                    )
                }
                
                Spacer()
            }
            
            // Trending Score (if significant)
            if gameSession.trendingScore > 10 {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("Trending")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Text("Score: \(Int(gameSession.trendingScore))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Action Button
            Button(action: onSpectate) {
                HStack {
                    Image(systemName: "eye.fill")
                        .font(.subheadline)
                    
                    Text("Watch Game")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)m"
    }
}

// MARK: - Game Info Item

struct GameInfoItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Game Status Badge

struct GameStatusBadge: View {
    let status: GameStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Loading Games View

struct LoadingGamesView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading trending games...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty Trending Games View

struct EmptyTrendingGamesView: View {
    let category: GameCategory
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: category.iconName)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No \(category.displayName) Available")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyMessage: String {
        switch category {
        case .all:
            return "No games are currently in progress. Start a new game or check back later!"
        case .imposter:
            return "No Imposter games are currently active. Why not start one?"
        case .friends:
            return "None of your friends are currently playing games."
        case .celebrity:
            return "No celebrity or highlighted games are currently active."
        }
    }
}

// MARK: - Extensions

extension GameStatus {
    var displayName: String {
        switch self {
        case .waiting: return "Waiting"
        case .starting: return "Starting"
        case .inProgress: return "Live"
        case .paused: return "Paused"
        case .finished: return "Finished"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .waiting: return .orange
        case .starting: return .blue
        case .inProgress: return .green
        case .paused: return .yellow
        case .finished: return .gray
        case .cancelled: return .red
        }
    }
}

#Preview {
    TrendingGamesView()
}
