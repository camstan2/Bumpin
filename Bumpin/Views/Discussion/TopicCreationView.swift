import SwiftUI

struct TopicCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TopicCreationViewModel()
    @State private var selectedCategory: TopicCategory = .music
    @State private var topicName = ""
    @State private var topicDescription = ""
    @State private var showingSimilarTopics = false
    @State private var similarTopics: [AITopicManager.SimilarityResult] = []
    
    var body: some View {
        NavigationView {
            Form {
                // Category Selection
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TopicCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Topic Name
                Section(header: Text("Topic Name")) {
                    TextField("Enter topic name", text: $topicName)
                        .onChange(of: topicName) { _ in
                            viewModel.checkForSimilarTopics(name: topicName, category: selectedCategory)
                        }
                }
                
                // Topic Description
                Section(header: Text("Description (Optional)")) {
                    TextField("Describe your topic", text: $topicDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Similar Topics Warning
                if !viewModel.similarTopics.isEmpty {
                    Section(header: Text("Similar Topics Found")) {
                        ForEach(viewModel.similarTopics, id: \.topic.id) { result in
                            SimilarTopicRow(result: result) {
                                // Handle joining existing topic
                                dismiss()
                            }
                        }
                    }
                }
                
                // AI Suggestions
                if viewModel.isGeneratingSuggestions {
                    Section(header: Text("AI Suggestions")) {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Generating suggestions...")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !viewModel.aiSuggestions.isEmpty {
                    Section(header: Text("AI Suggestions")) {
                        ForEach(viewModel.aiSuggestions, id: \.self) { suggestion in
                            Button(action: {
                                topicName = suggestion
                            }) {
                                HStack {
                                    Text(suggestion)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await viewModel.createTopic(
                                name: topicName,
                                category: selectedCategory,
                                description: topicDescription.isEmpty ? nil : topicDescription
                            )
                        }
                    }
                    .disabled(topicName.isEmpty || viewModel.isCreating)
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Topic Created", isPresented: $viewModel.showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your topic has been created successfully!")
            }
        }
    }
}

struct SimilarTopicRow: View {
    let result: AITopicManager.SimilarityResult
    let onJoin: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.topic.name)
                    .font(.headline)
                Spacer()
                Text("\(Int(result.similarityScore * 100))% similar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !result.matchingFeatures.isEmpty {
                Text("Matching: \(result.matchingFeatures.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Join Discussion") {
                    onJoin()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Spacer()
                
                Text(result.suggestedActionText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

extension AITopicManager.SimilarityResult {
    var suggestedActionText: String {
        switch suggestedAction {
        case .join:
            return "Consider joining"
        case .merge:
            return "Very similar"
        case .keepSeparate:
            return "Different enough"
        case .suggestAlternative(let message):
            return message
        }
    }
}

// MARK: - View Model

@MainActor
class TopicCreationViewModel: ObservableObject {
    @Published var similarTopics: [AITopicManager.SimilarityResult] = []
    @Published var aiSuggestions: [String] = []
    @Published var isGeneratingSuggestions = false
    @Published var isCreating = false
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var errorMessage = ""
    
    private let topicService = TopicService.shared
    private let aiManager = AITopicManager.shared
    
    func checkForSimilarTopics(name: String, category: TopicCategory) {
        guard !name.isEmpty else {
            similarTopics = []
            return
        }
        
        Task {
            do {
                let proposedTopic = ProposedTopic(
                    name: name,
                    category: category,
                    description: nil,
                    tags: [],
                    createdBy: ""
                )
                
                let results = try await aiManager.findSimilarTopics(to: proposedTopic)
                await MainActor.run {
                    self.similarTopics = results
                }
            } catch {
                // Handle error silently for now
                print("Error checking similar topics: \(error)")
            }
        }
    }
    
    func generateAISuggestions(description: String, category: DiscussionCategory) {
        guard !description.isEmpty else { return }
        
        isGeneratingSuggestions = true
        
        Task {
            do {
                let suggestions = try await aiManager.suggestTopicName(description, category: category)
                await MainActor.run {
                    self.aiSuggestions = suggestions
                    self.isGeneratingSuggestions = false
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingSuggestions = false
                    self.errorMessage = "Failed to generate suggestions: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    func createTopic(name: String, category: TopicCategory, description: String?) async {
        isCreating = true
        
        do {
            // First check moderation
            let moderationResult = try await aiManager.moderateTopic(name, description)
            
            if !moderationResult.approved {
                await MainActor.run {
                    self.errorMessage = "Topic not approved: \(moderationResult.reason)"
                    self.showingError = true
                    self.isCreating = false
                }
                return
            }
            
            // Create the topic
            _ = try await topicService.createTopic(
                name: name,
                category: category,
                description: description
            )
            
            await MainActor.run {
                self.showingSuccess = true
                self.isCreating = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showingError = true
                self.isCreating = false
            }
        }
    }
}
