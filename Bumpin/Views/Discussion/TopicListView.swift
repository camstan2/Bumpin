import SwiftUI

struct TopicListView: View {
    let category: TopicCategory
    let onTopicSelected: (DiscussionTopic) -> Void
    
    @StateObject private var viewModel = TopicListViewModel()
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedSortOption: TopicSortOption = .trending
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Topics List
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        // Trending Section
                        if !viewModel.trendingTopics.isEmpty {
                            Section(header: trendingHeader) {
                                ForEach(viewModel.trendingTopics) { topic in
                                    TopicRow(topic: topic, isTrending: true) {
                                        onTopicSelected(topic)
                                    }
                                }
                            }
                        }
                        
                        // All Topics Section
                        Section(header: allTopicsHeader) {
                            ForEach(viewModel.filteredTopics) { topic in
                                TopicRow(topic: topic, isTrending: false) {
                                    onTopicSelected(topic)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                TopicFilterView(
                    selectedSort: $selectedSortOption,
                    onApply: {
                        viewModel.sortTopics(by: selectedSortOption)
                        showingFilters = false
                    }
                )
            }
            .onAppear {
                viewModel.loadTopics(for: category)
            }
            .refreshable {
                await viewModel.refreshTopics()
            }
        }
    }
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search topics...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { newValue in
                        viewModel.searchTopics(query: newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Quick Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Trending",
                        isSelected: selectedSortOption == .trending,
                        action: { selectedSortOption = .trending }
                    )
                    
                    FilterChip(
                        title: "Newest",
                        isSelected: selectedSortOption == .newest,
                        action: { selectedSortOption = .newest }
                    )
                    
                    FilterChip(
                        title: "Most Active",
                        isSelected: selectedSortOption == .mostActive,
                        action: { selectedSortOption = .mostActive }
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var trendingHeader: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text("Trending")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var allTopicsHeader: some View {
        HStack {
            Image(systemName: "list.bullet")
                .foregroundColor(.blue)
            Text("All Topics")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct TopicRow: View {
    let topic: DiscussionTopic
    let isTrending: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if let description = topic.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if isTrending {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Trending")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Text("\(topic.activeDiscussions) active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Tags
                if !topic.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(topic.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // Stats
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.caption)
                        Text("\(topic.totalDiscussions)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(timeAgoString(from: topic.lastActivity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct TopicFilterView: View {
    @Binding var selectedSort: TopicSortOption
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sort By")) {
                    ForEach(TopicSortOption.allCases, id: \.self) { option in
                        HStack {
                            Text(option.displayName)
                            Spacer()
                            if selectedSort == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSort = option
                        }
                    }
                }
            }
            .navigationTitle("Filter Topics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                    }
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class TopicListViewModel: ObservableObject {
    @Published var topics: [DiscussionTopic] = []
    @Published var trendingTopics: [DiscussionTopic] = []
    @Published var filteredTopics: [DiscussionTopic] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let topicService = TopicService.shared
    private var currentCategory: TopicCategory?
    
    func loadTopics(for category: TopicCategory) {
        currentCategory = category
        isLoading = true
        
        Task {
            do {
                let (allTopics, trending) = try await (
                    topicService.getTopics(for: category),
                    topicService.getTrendingTopics()
                )
                
                await MainActor.run {
                    self.topics = allTopics
                    self.trendingTopics = trending.filter { $0.category == category }
                    self.filteredTopics = allTopics
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
    
    func refreshTopics() async {
        guard let category = currentCategory else { return }
        loadTopics(for: category)
    }
    
    func searchTopics(query: String) {
        if query.isEmpty {
            filteredTopics = topics
        } else {
            filteredTopics = topics.filter { topic in
                topic.name.localizedCaseInsensitiveContains(query) ||
                topic.description?.localizedCaseInsensitiveContains(query) == true ||
                topic.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
    }
    
    func sortTopics(by sortOption: TopicSortOption) {
        filteredTopics = filteredTopics.sorted { topic1, topic2 in
            switch sortOption {
            case .trending:
                return topic1.trendingScore > topic2.trendingScore
            case .newest:
                return topic1.createdAt > topic2.createdAt
            case .mostActive:
                return topic1.activeDiscussions > topic2.activeDiscussions
            case .alphabetical:
                return topic1.name < topic2.name
            }
        }
    }
}
