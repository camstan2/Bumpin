import SwiftUI

struct TopicDetailView: View {
    let topic: DiscussionTopic
    @StateObject private var viewModel: TopicDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(topic: DiscussionTopic) {
        self.topic = topic
        self._viewModel = StateObject(wrappedValue: TopicDetailViewModel(topic: topic))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Topic Header
                topicHeader
                
                // Stats Section
                statsSection
                
                // Active Discussions
                if !viewModel.activeDiscussions.isEmpty {
                    activeDiscussionsSection
                }
                
                // Topic Description
                if let description = topic.description, !description.isEmpty {
                    descriptionSection(description)
                }
                
                // Tags
                if !topic.tags.isEmpty {
                    tagsSection
                }
                
                // Action Buttons
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Topic Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.loadTopicDetails()
        }
    }
    
    private var topicHeader: some View {
        VStack(spacing: 16) {
            // Category and Icon
            HStack {
                Image(systemName: topic.category.icon)
                    .font(.title)
                    .foregroundColor(.purple)
                    .frame(width: 48, height: 48)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if topic.isTrending {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("Trending")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            
            // Topic Name
            Text(topic.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                TopicStatCard(
                    icon: "message",
                    value: "\(topic.activeDiscussions)",
                    label: "Active Discussions",
                    color: .blue
                )
                
                TopicStatCard(
                    icon: "person.2",
                    value: "\(topic.totalDiscussions)",
                    label: "Total Discussions",
                    color: .green
                )
                
                TopicStatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: String(format: "%.1f", topic.trendingScore),
                    label: "Trending Score",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var activeDiscussionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Discussions")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.activeDiscussions) { discussion in
                    DiscussionRow(discussion: discussion) {
                        // Handle joining discussion
                        viewModel.joinDiscussion(discussion)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80))
            ], spacing: 8) {
                ForEach(topic.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                viewModel.createNewDiscussion()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Start New Discussion")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            if !viewModel.activeDiscussions.isEmpty {
                Button(action: {
                    viewModel.joinRandomDiscussion()
                }) {
                    HStack {
                        Image(systemName: "person.2.circle.fill")
                        Text("Join Random Discussion")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
        }
    }
}

struct TopicStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DiscussionRow: View {
    let discussion: TopicChat
    let onJoin: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Discussion Icon
            Image(systemName: "message.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
            
            // Discussion Info
            VStack(alignment: .leading, spacing: 4) {
                Text(discussion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(discussion.participants.count) participants")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Join Button
            Button("Join") {
                onJoin()
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
class TopicDetailViewModel: ObservableObject {
    @Published var activeDiscussions: [TopicChat] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let topic: DiscussionTopic
    private let topicService = TopicService.shared
    
    init(topic: DiscussionTopic) {
        self.topic = topic
    }
    
    func loadTopicDetails() {
        isLoading = true
        
        Task {
            do {
                // Load active discussions for this topic
                let discussions = try await topicService.findDiscussionsForTopic(topic)
                
                await MainActor.run {
                    self.activeDiscussions = discussions
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func createNewDiscussion() {
        // This would create a new discussion for this topic
        // Implementation depends on your discussion creation flow
    }
    
    func joinRandomDiscussion() {
        // This would join a random active discussion for this topic
        guard let randomDiscussion = activeDiscussions.randomElement() else { return }
        joinDiscussion(randomDiscussion)
    }
    
    func joinDiscussion(_ discussion: TopicChat) {
        // This would join the specific discussion
        // Implementation depends on your discussion joining flow
    }
}

#Preview {
    NavigationView {
        TopicDetailView(topic: DiscussionTopic(
            name: "Best Albums of 2024",
            category: .music,
            createdBy: "user123",
            description: "Share your favorite albums released this year and discover new music!"
        ))
    }
}
