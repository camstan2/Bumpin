import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Match History View

struct MatchHistoryView: View {
    @StateObject private var viewModel = MatchHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMatch: WeeklyMatch?
    @State private var showingMatchDetail = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.matches.isEmpty {
                    emptyStateView
                } else {
                    matchListView
                }
            }
            .navigationTitle("Match History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadMatches()
            }
            .sheet(item: $selectedMatch) { match in
                MatchDetailView(match: match)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your matches...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.house")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Matches Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your matches will appear here after you're matched with someone who shares your music taste.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Next matching: This Thursday at 1 PM")
                .font(.caption)
                .foregroundColor(.purple)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Match List View
    
    private var matchListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.groupedMatches.keys.sorted(by: >), id: \.self) { week in
                    if let matches = viewModel.groupedMatches[week] {
                        weekSection(week: week, matches: matches)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.refreshMatches()
        }
    }
    
    // MARK: - Week Section
    
    private func weekSection(week: String, matches: [WeeklyMatch]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(formatWeekTitle(week))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(matches.count) match\(matches.count == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            ForEach(matches, id: \.id) { match in
                MatchHistoryCard(match: match) {
                    selectedMatch = match
                    showingMatchDetail = true
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Methods
    
    private func formatWeekTitle(_ week: String) -> String {
        // Convert "2024-W12" to "Week of March 18, 2024"
        let components = week.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let weekNumber = Int(String(components[1]).dropFirst()) else {
            return week
        }
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.weekOfYear = weekNumber
        dateComponents.year = year
        
        if let date = calendar.date(from: dateComponents) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return "Week of \(formatter.string(from: date))"
        }
        
        return week
    }
}

// MARK: - Match History Card

struct MatchHistoryCard: View {
    let match: WeeklyMatch
    let onTap: () -> Void
    @State private var matchedUser: UserProfile?
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Profile Image
                AsyncImage(url: URL(string: matchedUser?.profilePictureUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .overlay(
                            Text(matchedUser?.displayName.prefix(1).uppercased() ?? "?")
                                .font(.headline)
                                .foregroundColor(.purple)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                // Match Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(matchedUser?.displayName ?? "Loading...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Similarity Score
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(match.similarityScore * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            Text("match")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Shared Artists
                    if !match.sharedArtists.isEmpty {
                        Text("Shared: \(match.sharedArtists.prefix(3).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Status and Date
                    HStack {
                        statusIndicator
                        
                        Spacer()
                        
                        Text(match.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadMatchedUser()
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        if match.matchSuccess == true {
            return .green
        } else if match.userResponded {
            return .orange
        } else if match.botMessageSent {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var statusText: String {
        if match.matchSuccess == true {
            return "Connected"
        } else if match.userResponded {
            return "Responded"
        } else if match.botMessageSent {
            return "Matched"
        } else {
            return "Processing"
        }
    }
    
    private func loadMatchedUser() {
        guard matchedUser == nil else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(match.matchedUserId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error loading matched user: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                self.matchedUser = try? snapshot?.data(as: UserProfile.self)
            }
        }
    }
}

// MARK: - Match Detail View

struct MatchDetailView: View {
    let match: WeeklyMatch
    @Environment(\.dismiss) private var dismiss
    @State private var matchedUser: UserProfile?
    @State private var showingUserProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Similarity Breakdown
                    similaritySection
                    
                    // Shared Interests
                    sharedInterestsSection
                    
                    // Actions
                    actionsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Match Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadMatchedUser()
            }
            .sheet(isPresented: $showingUserProfile) {
                if let user = matchedUser {
                    UserProfileView(userId: user.uid)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: URL(string: matchedUser?.profilePictureUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .overlay(
                        Text(matchedUser?.displayName.prefix(1).uppercased() ?? "?")
                            .font(.largeTitle)
                            .foregroundColor(.purple)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            VStack(spacing: 8) {
                Text(matchedUser?.displayName ?? "Loading...")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("@\(matchedUser?.username ?? "")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Similarity Score
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .foregroundColor(.purple)
                    Text("\(Int(match.similarityScore * 100))% music compatibility")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Similarity Section
    
    private var similaritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why you matched")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ProgressBar(
                    title: "Overall Compatibility",
                    value: match.similarityScore,
                    color: .purple
                )
                
                // Additional metrics would go here if available
                // For now, we'll show a breakdown based on the overall score
                ProgressBar(
                    title: "Shared Artists",
                    value: min(1.0, Double(match.sharedArtists.count) / 5.0),
                    color: .blue
                )
                
                ProgressBar(
                    title: "Genre Compatibility",
                    value: min(1.0, Double(match.sharedGenres.count) / 3.0),
                    color: .green
                )
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Shared Interests Section
    
    private var sharedInterestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What you have in common")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !match.sharedArtists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shared Artists")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(match.sharedArtists, id: \.self) { artist in
                            Text(artist)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            if !match.sharedGenres.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shared Genres")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(match.sharedGenres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: { showingUserProfile = true }) {
                HStack {
                    Image(systemName: "person.circle")
                    Text("View Profile")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.purple)
                .cornerRadius(12)
            }
            
            Button(action: startConversation) {
                HStack {
                    Image(systemName: "message.circle")
                    Text("Send Message")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadMatchedUser() {
        guard matchedUser == nil else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(match.matchedUserId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error loading matched user: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                self.matchedUser = try? snapshot?.data(as: UserProfile.self)
            }
        }
    }
    
    private func startConversation() {
        // TODO: Navigate to DM conversation with the matched user
        // This would integrate with your existing DirectMessage system
        print("Starting conversation with \(match.matchedUserId)")
    }
}

// MARK: - Progress Bar Component

struct ProgressBar: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * value, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Preview

#Preview {
    MatchHistoryView()
}
