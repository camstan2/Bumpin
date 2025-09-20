import SwiftUI

struct TopicSelectionView: View {
    @Binding var selectedCategory: TopicCategory
    @Binding var selectedTopic: DiscussionTopic?
    let onSave: (TopicCategory, DiscussionTopic?) -> Void
    let onCancel: () -> Void
    
    @State private var showingTopicCreation = false
    @State private var showingTopicSearch = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Selection
                categorySelectionView
                
                // Topic Selection
                if selectedTopic == nil {
                    topicSelectionView
                } else {
                    selectedTopicView
                }
            }
            .navigationTitle("Select Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedCategory, selectedTopic)
                    }
                    .disabled(selectedTopic == nil)
                }
            }
        }
        .sheet(isPresented: $showingTopicCreation) {
            TopicCreationView()
        }
        .sheet(isPresented: $showingTopicSearch) {
            TopicSearchView { topic in
                selectedTopic = topic
                showingTopicSearch = false
            }
        }
    }
    
    private var categorySelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TopicCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            action: {
                                selectedCategory = category
                                selectedTopic = nil // Reset topic when category changes
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
    }
    
    private var topicSelectionView: some View {
        VStack(spacing: 0) {
            // Header with search and create buttons
            HStack {
                Text("Topics in \(selectedCategory.displayName)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { showingTopicSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.purple)
                    }
                    
                    Button(action: { showingTopicCreation = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Topics List
            TopicListView(
                category: selectedCategory,
                onTopicSelected: { topic in
                    selectedTopic = topic
                }
            )
        }
    }
    
    private var selectedTopicView: some View {
        VStack(spacing: 20) {
            // Selected Topic Display
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text("Topic Selected")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: selectedCategory.icon)
                            .foregroundColor(.purple)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedTopic?.name ?? "")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("from \(selectedCategory.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if let description = selectedTopic?.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Topic Stats
                    HStack(spacing: 20) {
                        StatItem(
                            icon: "message",
                            value: "\(selectedTopic?.activeDiscussions ?? 0)",
                            label: "Active"
                        )
                        
                        StatItem(
                            icon: "person.2",
                            value: "\(selectedTopic?.totalDiscussions ?? 0)",
                            label: "Total"
                        )
                        
                        if selectedTopic?.isTrending == true {
                            StatItem(
                                icon: "flame.fill",
                                value: "Trending",
                                label: "Status"
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Change Topic Button
            Button("Change Topic") {
                selectedTopic = nil
            }
            .font(.subheadline)
            .foregroundColor(.purple)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

struct CategoryChip: View {
    let category: TopicCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.purple : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .font(.caption)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TopicSelectionView(
        selectedCategory: .constant(.music),
        selectedTopic: .constant(nil),
        onSave: { _, _ in },
        onCancel: { }
    )
}