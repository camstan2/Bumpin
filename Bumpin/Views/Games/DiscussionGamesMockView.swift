import SwiftUI

// MARK: - Discussion Games Mock View
// This view shows how the Discussion screen looks with active games

struct DiscussionGamesMockView: View {
    @State private var selectedTab: Tab = .games
    
    enum Tab {
        case topics, randomChat, games
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with segmented picker
                VStack(spacing: 16) {
                    HStack {
                        Picker("View", selection: $selectedTab) {
                            Text("Topics").tag(Tab.topics)
                            Text("Random Chat").tag(Tab.randomChat)
                            Text("Games").tag(Tab.games)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                
                // Games Content
                if selectedTab == .games {
                    gamesView
                }
            }
            .navigationTitle("Discussion")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var gamesView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Header section with game stats
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Social Games")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Play interactive games with friends and others")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Game stats row
                    HStack(spacing: 20) {
                        mockGameStatTile(title: "Active Games", value: "12")
                        mockGameStatTile(title: "In Queue", value: "0")
                        mockGameStatTile(title: "Trending", value: "8")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color(.systemBackground))
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Quick Actions")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        // Create Game Button
                        mockActionButton(
                            icon: "plus.circle.fill",
                            title: "Create Game",
                            color: .purple
                        )
                        
                        // Join Queue Button
                        mockActionButton(
                            icon: "person.2.fill",
                            title: "Join Queue",
                            color: .blue
                        )
                        
                        // Create Group Button
                        mockActionButton(
                            icon: "person.2.circle",
                            title: "Create Group",
                            color: .blue
                        )
                        
                        // Group Invites Button (with notification)
                        mockActionButtonWithBadge(
                            icon: "envelope.fill",
                            title: "Invites",
                            color: .orange,
                            badgeCount: 2
                        )
                    }
                    .padding(.horizontal)
                }
                
                // Friends' Games Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                            
                            Text("Friends Playing")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Button("See All") {
                            // Action
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            mockFriendGameCard(
                                friendName: "Sarah",
                                gameType: "Imposter",
                                playerCount: 4,
                                spectatorCount: 12,
                                isLive: true
                            )
                            
                            mockFriendGameCard(
                                friendName: "Mike",
                                gameType: "Imposter",
                                playerCount: 6,
                                spectatorCount: 8,
                                isLive: true
                            )
                            
                            mockFriendGameCard(
                                friendName: "Alex",
                                gameType: "Imposter",
                                playerCount: 3,
                                spectatorCount: 24,
                                isLive: true
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Trending Games Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                            
                            Text("Trending Games")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        Button("View All") {
                            // Action
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            mockTrendingGameCard(
                                title: "Celebrity Showdown",
                                host: "Emma Stone",
                                playerCount: 8,
                                spectatorCount: 156,
                                isHot: true,
                                isCelebrity: true
                            )
                            
                            mockTrendingGameCard(
                                title: "Friday Night Fun",
                                host: "Jake_23",
                                playerCount: 5,
                                spectatorCount: 89,
                                isHot: true,
                                isCelebrity: false
                            )
                            
                            mockTrendingGameCard(
                                title: "Imposter Masters",
                                host: "GamePro",
                                playerCount: 7,
                                spectatorCount: 67,
                                isHot: false,
                                isCelebrity: false
                            )
                            
                            mockTrendingGameCard(
                                title: "Late Night Gaming",
                                host: "NightOwl",
                                playerCount: 4,
                                spectatorCount: 43,
                                isHot: false,
                                isCelebrity: false
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Available Games Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "gamecontroller")
                                .font(.title3)
                                .foregroundColor(.blue)
                            
                            Text("Available Games")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        mockAvailableGameRow(
                            title: "Quick Imposter Game",
                            host: "PlayerOne",
                            playerCount: 2,
                            maxPlayers: 6,
                            status: "Waiting"
                        )
                        
                        mockAvailableGameRow(
                            title: "Chill Gaming Session",
                            host: "ChillGamer",
                            playerCount: 1,
                            maxPlayers: 4,
                            status: "Waiting"
                        )
                        
                        mockAvailableGameRow(
                            title: "Competitive Match",
                            host: "ProGamer99",
                            playerCount: 3,
                            maxPlayers: 8,
                            status: "Starting"
                        )
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Mock Components
    
    private func mockGameStatTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline).fontWeight(.bold)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }
    
    private func mockActionButton(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func mockActionButtonWithBadge(icon: String, title: String, color: Color, badgeCount: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                Circle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("\(badgeCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .offset(x: 12, y: -12)
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func mockFriendGameCard(friendName: String, gameType: String, playerCount: Int, spectatorCount: Int, isLive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(String(friendName.prefix(1)))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(friendName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(gameType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isLive {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        
                        Text("LIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("\(playerCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(spectatorCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
            
            Text("Tap to join")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
        .frame(width: 160)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func mockTrendingGameCard(title: String, host: String, playerCount: Int, spectatorCount: Int, isHot: Bool, isCelebrity: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill.questionmark")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        if isCelebrity {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text("by \(host)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("\(playerCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("\(spectatorCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if isHot {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        
                        Text("Hot")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Text("Tap to watch")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
        .frame(width: 160)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func mockAvailableGameRow(title: String, host: String, playerCount: Int, maxPlayers: Int, status: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill.questionmark")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("by \(host)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("\(playerCount)/\(maxPlayers)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Text(status)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(status == "Starting" ? .orange : .blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((status == "Starting" ? Color.orange : Color.blue).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    DiscussionGamesMockView()
}
