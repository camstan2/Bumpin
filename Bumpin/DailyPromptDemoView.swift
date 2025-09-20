import SwiftUI

struct DailyPromptDemoView: View {
    @State private var selectedDemo: DemoMode = .notResponded
    @State private var showResponseSubmission = false
    @State private var showLeaderboard = false
    @State private var showResponseDetail = false
    @State private var selectedResponse: PromptResponse?
    
    enum DemoMode: String, CaseIterable, Identifiable {
        case notResponded = "Gated (No Response)"
        case hasResponded = "Unlocked (Responded)"
        case leaderboardView = "Leaderboard View"
        case responseFlow = "Response Flow"
        
        var id: String { rawValue }
    }
    
    @StateObject private var coordinatorNotResponded = DailyPromptCoordinator()
    @StateObject private var coordinatorResponded = DailyPromptCoordinator()
    
    var coordinator: DailyPromptCoordinator {
        switch selectedDemo {
        case .notResponded, .responseFlow:
            return coordinatorNotResponded
        case .hasResponded, .leaderboardView:
            return coordinatorResponded
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Demo mode selector
                demoModeSelector
                
                // Demo content
                Group {
                    switch selectedDemo {
                    case .notResponded:
                        notRespondedDemo
                    case .hasResponded:
                        hasRespondedDemo
                    case .leaderboardView:
                        leaderboardDemo
                    case .responseFlow:
                        responseFlowDemo
                    }
                }
            }
            .navigationTitle("Daily Prompts Demo")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showResponseSubmission) {
            mockResponseSubmissionView
        }
        .sheet(isPresented: $showLeaderboard) {
            mockLeaderboardView
        }
        .sheet(isPresented: $showResponseDetail) {
            if let response = selectedResponse {
                mockResponseDetailView(response)
            }
        }
        .onAppear {
            setupMockData()
        }
    }
    
    // MARK: - Demo Mode Selector
    
    private var demoModeSelector: some View {
        VStack(spacing: 12) {
            Text("Daily Prompts Feature Demo")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("Experience the complete Daily Prompts feature")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DemoMode.allCases) { mode in
                        Button(action: {
                            selectedDemo = mode
                        }) {
                            Text(mode.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedDemo == mode ? Color.purple : Color.gray.opacity(0.2))
                                )
                                .foregroundColor(selectedDemo == mode ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 16)
        .background(Color(.secondarySystemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Demo Views
    
    private var notRespondedDemo: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Demo description
                demoDescription(
                    title: "New Daily Prompt - Gated Access",
                    description: "Users must submit a response to immediately unlock community results, rankings, and popular songs. Submit to see everything right away!"
                )
                
                // Current prompt section (not responded)
                currentPromptSection(hasResponded: false)
                
                // Gated community section
                gatedCommunitySection
                
                // Gated rankings section
                gatedRankingsSection
                
                // Stats section
                userStatsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
    
    private var hasRespondedDemo: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Demo description
                demoDescription(
                    title: "After Responding - Immediate Access",
                    description: "Instantly after submitting, users see their daily ranking, most popular songs, community responses, and friends' choices. Everything unlocks immediately!"
                )
                
                // Current prompt section (responded)
                currentPromptSection(hasResponded: true)
                
                // User's ranking display
                userRankingSection
                
                // User's response
                userResponseSection
                
                // Community responses with interactions
                communityResponsesSection
                
                // Most popular songs section
                mostPopularSongsSection
                
                // Friends responses section
                friendsResponsesSection
                
                // Leaderboard preview
                leaderboardPreviewSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
    
    private var leaderboardDemo: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Demo description
                demoDescription(
                    title: "Community Leaderboard",
                    description: "Real-time rankings show the most popular songs for each prompt, with vote counts and sample users who chose each song."
                )
                
                // Leaderboard content
                leaderboardContent
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
    
    private var responseFlowDemo: some View {
        VStack(spacing: 24) {
            // Demo description
            demoDescription(
                title: "Response Submission Flow",
                description: "Users can select a song, add an explanation, and choose privacy settings before submitting their response."
            )
            
            Button("Try Response Flow") {
                showResponseSubmission = true
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    // MARK: - Component Sections
    
    private func currentPromptSection(hasResponded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category badge and response count
            HStack {
                CategoryBadge(category: DailyPromptMockData.mockPrompt.category)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(DailyPromptMockData.mockPrompt.totalResponses)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.secondary)
            }
            
            // Prompt title and description
            VStack(alignment: .leading, spacing: 8) {
                Text(DailyPromptMockData.mockPrompt.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text(DailyPromptMockData.mockPrompt.description ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            // Time remaining until 12PM EST refresh
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                    Text("18h 23m until new prompt")
                }
                .font(.caption)
                .foregroundColor(.orange)
                
                Text("Next prompt: Tomorrow 12:00 PM EST")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Action button
            if hasResponded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You've responded!")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Button(action: {
                    if selectedDemo == .responseFlow {
                        showResponseSubmission = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                        Text("Pick Your Song")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var userResponseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Response")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("Submitted 2h ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Mock user's response
            HStack(spacing: 16) {
                // Album artwork
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.orange.opacity(0.7), Color.red.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    )
                
                // Song details
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vacation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Dirty Heads")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Sound of Change")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // User's explanation
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                Text("This song literally has 'vacation' in the title and it perfectly captures that laid-back, carefree feeling I want when I'm getting away from it all!")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            
            // Engagement stats for user's response
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Text("12")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("3")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Ranked #8 in leaderboard")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var communityResponsesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Community Responses")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("See All") {
                    showLeaderboard = true
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(DailyPromptMockData.mockResponses.prefix(3)), id: \.id) { response in
                    mockResponseCard(response)
                }
            }
        }
    }
    
    private var userStatsSection: some View {
        HStack(spacing: 20) {
            PromptStatCard(
                title: "Streak",
                value: "\(DailyPromptMockData.mockUserStats.currentStreak)",
                subtitle: "days",
                color: .orange,
                icon: "flame.fill"
            )
            
            PromptStatCard(
                title: "Total",
                value: "\(DailyPromptMockData.mockUserStats.totalResponses)",
                subtitle: "responses",
                color: .purple,
                icon: "music.note"
            )
            
            PromptStatCard(
                title: "Best",
                value: "\(DailyPromptMockData.mockUserStats.longestStreak)",
                subtitle: "days",
                color: .green,
                icon: "crown.fill"
            )
        }
    }
    
    private var leaderboardPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Songs")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Full Leaderboard") {
                    showLeaderboard = true
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(DailyPromptMockData.mockLeaderboard.songRankings.prefix(3).enumerated()), id: \.element.id) { index, ranking in
                    leaderboardRowPreview(ranking: ranking, rank: index + 1)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var leaderboardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(spacing: 12) {
                CategoryBadge(category: DailyPromptMockData.mockPrompt.category)
                
                Text(DailyPromptMockData.mockPrompt.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(DailyPromptMockData.mockPrompt.description ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("47")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("Responses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("23")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("Songs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("8")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Genres")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            
            // Full leaderboard
            Text("Song Rankings")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(DailyPromptMockData.mockLeaderboard.songRankings.enumerated()), id: \.element.id) { index, ranking in
                    leaderboardSongRow(ranking: ranking, rank: index + 1)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func demoDescription(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func mockResponseCard(_ response: PromptResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(response.username.prefix(1)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(response.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("2h ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Song info
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(response.songTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(response.artistName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let albumName = response.albumName {
                        Text(albumName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            
            // Explanation
            if let explanation = response.explanation {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Engagement row
            HStack(spacing: 20) {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Text("\(response.likeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    selectedResponse = response
                    showResponseDetail = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(response.commentCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("Responded 2h ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onTapGesture {
            selectedResponse = response
            showResponseDetail = true
        }
    }
    
    private func leaderboardRowPreview(ranking: SongRanking, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.songTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(ranking.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ranking.voteCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("\(Int(ranking.percentage))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private func leaderboardSongRow(ranking: SongRanking, rank: Int) -> some View {
        HStack(spacing: 16) {
            // Rank indicator
            ZStack {
                Circle()
                    .fill(rankColor(rank))
                    .frame(width: 32, height: 32)
                
                if rank <= 3 {
                    Image(systemName: rankIcon(rank))
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Text("\(rank)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            // Song artwork placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.8))
                )
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.songTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(ranking.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Sample users
                HStack(spacing: 4) {
                    ForEach(Array(ranking.sampleUsers.prefix(3)), id: \.id) { user in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(String(user.username.prefix(1)))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    if ranking.sampleUsers.count > 3 {
                        Text("+\(ranking.sampleUsers.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Vote stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(ranking.voteCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("\(Int(ranking.percentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(ranking.voteCount == 1 ? "vote" : "votes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Mock Sheet Views
    
    private var mockResponseSubmissionView: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Prompt display
                    VStack(alignment: .leading, spacing: 12) {
                        CategoryBadge(category: DailyPromptMockData.mockPrompt.category)
                        
                        Text(DailyPromptMockData.mockPrompt.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(DailyPromptMockData.mockPrompt.description ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                            Text("18h 23m remaining")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    
                    // Song selection demo
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose Your Song")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Button(action: {}) {
                            VStack(spacing: 12) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 32))
                                    .foregroundColor(.purple)
                                
                                Text("Select a Song")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                
                                Text("Choose the perfect song that matches this prompt")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    )
                            )
                        }
                    }
                    
                    // Demo explanation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why This Song? (Optional)")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Share why this song perfectly captures the prompt...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.tertiarySystemBackground))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Your Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showResponseSubmission = false
                    }
                }
            }
        }
    }
    
    private var mockLeaderboardView: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    leaderboardContent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        showLeaderboard = false
                    }
                }
            }
        }
    }
    
    private func mockResponseDetailView(_ response: PromptResponse) -> some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    mockResponseCard(response)
                    
                    // Comments section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Comments")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("\(response.commentCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let comments = DailyPromptMockData.mockComments[response.songId + "_response"] {
                            LazyVStack(spacing: 12) {
                                ForEach(comments, id: \.id) { comment in
                                    mockCommentRow(comment)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .navigationTitle("Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showResponseDetail = false
                    }
                }
            }
        }
    }
    
    private func mockCommentRow(_ comment: PromptResponseComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(comment.username.prefix(1)))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("1h ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text(comment.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("3")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    // MARK: - Setup Functions
    
    private func setupMockData() {
        DailyPromptMockData.configureMockData(for: coordinatorNotResponded, userHasResponded: false)
        DailyPromptMockData.configureMockData(for: coordinatorResponded, userHasResponded: true)
    }
    
    // MARK: - Helper Functions
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .brown
        default: return .purple
        }
    }
    
    private func rankIcon(_ rank: Int) -> String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
    
    // MARK: - User Ranking Section
    
    private var userRankingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("Your Daily Ranking")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 20) {
                // Ranking number
                VStack(spacing: 8) {
                    Text("#7")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                    
                    Text("out of 1,247")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.green)
                        Text("Submitted early")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("15 likes on your choice")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Popular pick!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Most Popular Songs Section
    
    private var mostPopularSongsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("Most Popular Songs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button("See All") {
                    // Show all popular songs
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            VStack(spacing: 12) {
                ForEach(1...5, id: \.self) { index in
                    HStack(spacing: 12) {
                        // Ranking number
                        Text("\(index)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        // Mock album artwork
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.purple)
                            )
                        
                        // Song info
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mock Song \(index)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Mock Artist")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Vote count
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(156 - (index * 20))")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                            Text("votes")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Gated Access Sections
    
    private var gatedCommunitySection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("Community Responses")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text("Submit your response to unlock")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("See what songs the community chose and engage with their responses")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Submit Response") {
                    showResponseSubmission = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(.horizontal, 16)
    }
    
    private var gatedRankingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("Today's Rankings & Popular Songs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text("Submit to unlock immediately")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Your ranking and most popular songs will appear right after you submit your response")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Submit Response") {
                    showResponseSubmission = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Friends Responses Section
    
    private var friendsResponsesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("Friends & Following")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button("See All") {
                    // Show all friends responses
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            VStack(spacing: 12) {
                ForEach(1...4, id: \.self) { index in
                    HStack(spacing: 12) {
                        // Friend profile picture
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("\(["A", "B", "C", "D"][index-1])")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            )
                        
                        // Friend info and song choice
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("@friend\(index)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                if index == 1 {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                // Mini album art
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.caption2)
                                            .foregroundColor(.purple)
                                    )
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Friend's Song Choice \(index)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("Artist Name")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Interaction buttons
                        HStack(spacing: 8) {
                            Button(action: {}) {
                                Image(systemName: "heart")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "bubble.left")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    DailyPromptDemoView()
}
