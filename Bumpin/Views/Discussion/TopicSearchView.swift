import SwiftUI

struct TopicSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TopicSearchViewModel()
    let onTopicSelected: (DiscussionTopic) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Results
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.isSearching {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            searchResults
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Search Topics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search topics...", text: $viewModel.searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    Task {
                        await viewModel.performSearch()
                    }
                }
            
            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    private var searchResults: some View {
        Group {
            if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                emptyStateView
            } else if viewModel.searchResults.isEmpty {
                initialStateView
            } else {
                resultsList
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No topics found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try searching with different keywords or create a new topic")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create New Topic") {
                // This would open the topic creation view
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var initialStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Search Topics")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Find existing topics or discover new discussions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Recent searches
            if !viewModel.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Searches")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ForEach(viewModel.recentSearches, id: \.self) { search in
                        Button(action: {
                            viewModel.searchQuery = search
                            Task {
                                await viewModel.performSearch()
                            }
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text(search)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.searchResults) { topic in
                TopicSearchResultRow(topic: topic) {
                    onTopicSelected(topic)
                    dismiss()
                }
            }
        }
    }
}

struct TopicSearchResultRow: View {
    let topic: DiscussionTopic
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category Icon
                Image(systemName: topic.category.icon)
                    .font(.title2)
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                
                // Topic Info
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
                    
                    HStack {
                        Text(topic.category.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "message")
                                    .font(.caption)
                                Text("\(topic.activeDiscussions)")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            
                            if topic.isTrending {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption)
                                    Text("Trending")
                                        .font(.caption)
                                }
                                .foregroundColor(.orange)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - View Model

@MainActor
class TopicSearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [DiscussionTopic] = []
    @Published var isSearching = false
    @Published var recentSearches: [String] = []
    
    private let topicService = TopicService.shared
    private var searchTask: Task<Void, Never>?
    
    init() {
        loadRecentSearches()
    }
    
    func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchTask?.cancel()
        
        searchTask = Task {
            do {
                let results = try await topicService.searchTopics(query: searchQuery)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchResults = results
                        self.isSearching = false
                        self.addToRecentSearches(self.searchQuery)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchResults = []
                        self.isSearching = false
                    }
                }
            }
        }
    }
    
    private func addToRecentSearches(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        recentSearches.removeAll { $0 == trimmedQuery }
        recentSearches.insert(trimmedQuery, at: 0)
        
        // Keep only last 5 searches
        if recentSearches.count > 5 {
            recentSearches = Array(recentSearches.prefix(5))
        }
        
        saveRecentSearches()
    }
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: "recentTopicSearches"),
           let searches = try? JSONDecoder().decode([String].self, from: data) {
            recentSearches = searches
        }
    }
    
    private func saveRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: "recentTopicSearches")
        }
    }
}

#Preview {
    TopicSearchView { topic in
        print("Selected topic: \(topic.name)")
    }
}
