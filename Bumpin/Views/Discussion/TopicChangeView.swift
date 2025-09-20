import SwiftUI

struct TopicChangeView: View {
    @State private var selectedCategory: TopicCategory
    @State private var selectedTopic: String?
    
    let currentCategory: TopicCategory
    let currentTopic: String
    let onSave: (TopicCategory, String) -> Void
    let onCancel: () -> Void
    
    @State private var showingTopicSelection = false
    @State private var showingTopicError = false
    
    init(currentCategory: TopicCategory, currentTopic: String, onSave: @escaping (TopicCategory, String) -> Void, onCancel: @escaping () -> Void) {
        self.currentCategory = currentCategory
        self.currentTopic = currentTopic
        self.onSave = onSave
        self.onCancel = onCancel
        self._selectedCategory = State(initialValue: currentCategory)
        self._selectedTopic = State(initialValue: currentTopic)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    categorySelectionSection
                    topicInputSection
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(selectedTopic?.isEmpty != false)
                }
            }
        }
        .alert("Please enter a topic", isPresented: $showingTopicError) {
            Button("OK") { }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Change Discussion Topic")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Update the topic for this discussion. All participants will be notified of the change.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("1. Choose a category:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(TopicCategory.allCases, id: \.self) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func categoryButton(for category: TopicCategory) -> some View {
        Button {
            selectedCategory = category
            showingTopicError = false
        } label: {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(selectedCategory == category ? .white : category.color)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedCategory == category ? .white : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(
                selectedCategory == category 
                    ? category.color 
                    : Color(.systemGray6)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var topicInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("2. Enter topic name:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter topic name", text: Binding(
                    get: { selectedTopic ?? "" },
                    set: { selectedTopic = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                
                Text("Example: \"Marvel Phase 5 Movies\", \"NBA Trade Rumors\", \"New Album Reviews\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }
    
    private func saveChanges() {
        guard let topic = selectedTopic, !topic.isEmpty else {
            showingTopicError = true
            return
        }
        
        onSave(selectedCategory, topic)
    }
}