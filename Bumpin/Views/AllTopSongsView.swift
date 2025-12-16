import SwiftUI
import FirebaseAuth

struct AllTopSongsView: View {
    let prompt: DailyPrompt
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header info
                        headerSection
                        
                        // Song list
                        if let leaderboard = coordinator.getCurrentLeaderboard() {
                            if leaderboard.songRankings.isEmpty {
                                emptyStateView
                            } else {
                                songListSection(leaderboard: leaderboard)
                            }
                        } else {
                            loadingView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Top Songs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CategoryBadge(category: prompt.category)
                Spacer()
                Text(responseCountText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(prompt.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let description = prompt.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.top, 8)
        }
        .padding(.top, 8)
    }
    
    private var responseCountText: String {
        let total = coordinator.getCurrentLeaderboard()?.totalResponses ?? prompt.totalResponses
        let label = total == 1 ? "response" : "responses"
        return "\(total) \(label)"
    }
    
    // MARK: - Song List Section
    
    private func songListSection(leaderboard: PromptLeaderboard) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(leaderboard.songRankings.enumerated()), id: \.element.id) { index, ranking in
                TopSongCard(
                    ranking: ranking,
                    rank: index + 1,
                    onTap: {
                        // Navigate to song profile
                        navigationCoordinator.navigateToMusicProfile(
                            TrendingItem(
                                title: ranking.songTitle,
                                subtitle: ranking.artistName,
                                artworkUrl: ranking.artworkUrl,
                                logCount: ranking.voteCount,
                                averageRating: nil,
                                itemType: "song",
                                itemId: ranking.id
                            )
                        )
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Songs Yet")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Be the first to submit a response!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ForEach(0..<10, id: \.self) { _ in
                SongCardSkeleton()
            }
        }
    }
}

// MARK: - Top Song Card

struct TopSongCard: View {
    let ranking: SongRanking
    let rank: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 44, height: 44)
                    
                    Text("#\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Artwork
                if let artworkUrl = ranking.artworkUrl, let url = URL(string: artworkUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        )
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(ranking.songTitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(ranking.artistName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Stats
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.caption2)
                            Text("\(ranking.voteCount)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.purple)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                                .font(.caption2)
                            Text("\(Int(ranking.percentage))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.primary.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .purple
        }
    }
}

// MARK: - Song Card Skeleton

struct SongCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 12)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    AllTopSongsView(
        prompt: DailyPrompt(
            title: "Test Prompt",
            description: "Test description",
            category: .genre,
            createdBy: "admin",
            expiresAt: Date().addingTimeInterval(86400)
        ),
        coordinator: DailyPromptCoordinator()
    )
    .environmentObject(NavigationCoordinator())
}

