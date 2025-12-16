import SwiftUI
import FirebaseAuth

struct AllTopResponsesView: View {
    let prompt: DailyPrompt
    let coordinator: DailyPromptCoordinator
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var responses: [PromptResponse] = []
    @State private var isLoading = true
    @State private var selectedResponse: PromptResponse?
    @State private var showResponseDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header info
                        headerSection
                        
                        // Response list
                        if isLoading {
                            loadingView
                        } else if responses.isEmpty {
                            emptyStateView
                        } else {
                            responseListSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Top Responses")
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
            .sheet(isPresented: $showResponseDetail) {
                if let response = selectedResponse {
                    PromptResponseDetailView(response: response, coordinator: coordinator)
                        .environmentObject(navigationCoordinator)
                }
            }
        }
        .task {
            await loadTopResponses()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CategoryBadge(category: prompt.category)
                Spacer()
                Text("\(responses.count) responses")
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
    
    // MARK: - Response List Section
    
    private var responseListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(responses.enumerated()), id: \.element.id) { index, response in
                VStack(spacing: 0) {
                    // Rank badge
                    HStack {
                        HStack(spacing: 6) {
                            Text("#\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(rankColor(for: index + 1))
                            
                            if index < 3 {
                                Image(systemName: index == 0 ? "crown.fill" : "medal.fill")
                                    .font(.caption2)
                                    .foregroundColor(rankColor(for: index + 1))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemBackground))
                    }
                    
                    // Response card
                    PromptResponseCard(
                        response: response,
                        coordinator: coordinator,
                        showUserInfo: true,
                        onTap: {
                            selectedResponse = response
                            showResponseDetail = true
                        }
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.primary.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Responses Yet")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Be the first to share your thoughts!")
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
                ResponseCardSkeleton()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadTopResponses() async {
        isLoading = true
        defer { isLoading = false }
        
        // Fetch all responses for this prompt
        let allResponses = await coordinator.promptService.fetchResponsesForPrompt(prompt.id, limit: 200)
        
        // Sort by engagement (likes + comments)
        let sortedResponses = allResponses.sorted { response1, response2 in
            let engagement1 = response1.likeCount + response1.commentCount
            let engagement2 = response2.likeCount + response2.commentCount
            
            // If engagement is equal, sort by likes
            if engagement1 == engagement2 {
                return response1.likeCount > response2.likeCount
            }
            
            return engagement1 > engagement2
        }
        
        await MainActor.run {
            responses = sortedResponses
        }
    }
    
    // MARK: - Helper Functions
    
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .purple
        }
    }
}

#Preview {
    AllTopResponsesView(
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

