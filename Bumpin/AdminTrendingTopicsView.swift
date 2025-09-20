import SwiftUI
import FirebaseAuth

struct AdminTrendingTopicsView: View {
    @StateObject private var trendingService = TrendingTopicsService.shared
    @State private var selectedCategory: TopicCategory = .trending
    @State private var showingAddTopic = false
    @State private var showingBulkActions = false
    
    // Add topic form
    @State private var newTopicTitle = ""
    @State private var newTopicDescription = ""
    @State private var newTopicKeywords = ""
    @State private var newTopicPriority = 5
    @State private var newTopicExpires = false
    @State private var newTopicExpiryDate = Date().addingTimeInterval(7 * 24 * 3600) // 7 days
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Picker
                categoryPicker
                
                // Topics List
                if trendingService.isLoading {
                    loadingView
                } else {
                    topicsListView
                }
            }
            .navigationTitle("Trending Topics Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Topic") {
                            showingAddTopic = true
                        }
                        
                        Button("Bulk Actions") {
                            showingBulkActions = true
                        }
                        
                        Button("Refresh All") {
                            Task {
                                await trendingService.refreshAllTopics()
                            }
                        }
                        
                        Button("Update Metrics") {
                            Task {
                                await trendingService.updateAllTopicMetrics()
                            }
                        }
                        
                        Divider()
                        
                        Button("Seed Sample Data") {
                            Task {
                                await TrendingTopicsSeedData.shared.seedAllCategories()
                                await trendingService.refreshAllTopics()
                            }
                        }
                        
                        Button("Run AI Detection") {
                            Task {
                                await TrendingTopicsUpdateService.shared.runFullUpdate()
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTopic) {
            addTopicSheet
        }
        .onAppear {
            trendingService.startListening(to: selectedCategory)
        }
        .onDisappear {
            trendingService.removeAllListeners()
        }
    }
    
    // MARK: - Category Picker
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TopicCategory.allCases, id: \.rawValue) { category in
                    Button(action: {
                        selectedCategory = category
                        trendingService.stopListening(to: selectedCategory)
                        trendingService.startListening(to: category)
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(selectedCategory == category ? category.color : Color(.systemGray6))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: category.icon)
                                    .font(.title2)
                                    .foregroundColor(selectedCategory == category ? .white : category.color)
                            }
                            
                            Text(category.displayName)
                                .font(.caption2)
                                .fontWeight(selectedCategory == category ? .semibold : .regular)
                                .foregroundColor(selectedCategory == category ? category.color : .secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Topics List
    
    private var topicsListView: some View {
        List {
            let topics = trendingService.trendingTopicsByCategory[selectedCategory] ?? []
            
            if topics.isEmpty {
                emptyStateView
            } else {
                ForEach(topics) { topic in
                    TopicAdminRow(topic: topic) { updatedTopic in
                        // Handle topic updates
                        Task {
                            if updatedTopic.isActive != topic.isActive {
                                await trendingService.toggleTopicActive(topicId: topic.id, isActive: updatedTopic.isActive)
                            }
                            if updatedTopic.priority != topic.priority {
                                await trendingService.updateTopicPriority(topicId: topic.id, priority: updatedTopic.priority)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await trendingService.refreshAllTopics()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedCategory.icon)
                .font(.system(size: 40))
                .foregroundColor(selectedCategory.color)
            
            Text("No Trending Topics")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Add some trending topics for \(selectedCategory.displayName) to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Topic") {
                showingAddTopic = true
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedCategory.color)
        }
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading trending topics...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Add Topic Sheet
    
    private var addTopicSheet: some View {
        NavigationView {
            Form {
                Section("Topic Details") {
                    TextField("Topic Title", text: $newTopicTitle)
                    TextField("Description (Optional)", text: $newTopicDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TopicCategory.allCases, id: \.rawValue) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    
                    HStack {
                        Text("Priority")
                        Spacer()
                        Picker("Priority", selection: $newTopicPriority) {
                            ForEach(1...10, id: \.self) { priority in
                                Text("\(priority)").tag(priority)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Section("Keywords") {
                    TextField("Keywords (comma separated)", text: $newTopicKeywords)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Expiration") {
                    Toggle("Set Expiration", isOn: $newTopicExpires)
                    
                    if newTopicExpires {
                        DatePicker("Expires At", selection: $newTopicExpiryDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Add Trending Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        clearForm()
                        showingAddTopic = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            await addTopic()
                        }
                    }
                    .disabled(newTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addTopic() async {
        let keywords = newTopicKeywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        
        let success = await trendingService.addManualTopic(
            category: selectedCategory,
            title: newTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newTopicDescription.isEmpty ? nil : newTopicDescription,
            keywords: keywords,
            priority: newTopicPriority,
            expiresAt: newTopicExpires ? newTopicExpiryDate : nil
        )
        
        if success {
            clearForm()
            showingAddTopic = false
        }
    }
    
    private func clearForm() {
        newTopicTitle = ""
        newTopicDescription = ""
        newTopicKeywords = ""
        newTopicPriority = 5
        newTopicExpires = false
        newTopicExpiryDate = Date().addingTimeInterval(7 * 24 * 3600)
    }
}

// MARK: - Topic Admin Row

struct TopicAdminRow: View {
    let topic: TrendingTopic
    let onUpdate: (TrendingTopic) -> Void
    
    @State private var isActive: Bool
    @State private var priority: Int
    @State private var showingDetails = false
    
    init(topic: TrendingTopic, onUpdate: @escaping (TrendingTopic) -> Void) {
        self.topic = topic
        self.onUpdate = onUpdate
        self._isActive = State(initialValue: topic.isActive)
        self._priority = State(initialValue: topic.priority)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and source
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        // Source badge
                        Text(topic.source.displayName)
                            .font(.caption2)
                            .foregroundColor(topic.source.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(topic.source.color.opacity(0.2))
                            .cornerRadius(4)
                        
                        // Verified badge
                        if topic.isVerified {
                            Text("Verified")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Popularity score
                        Text("\(Int(topic.popularity * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Active toggle
                Toggle("Active", isOn: $isActive)
                    .labelsHidden()
                    .onChange(of: isActive) { _, newValue in
                        var updatedTopic = topic
                        updatedTopic.isActive = newValue
                        onUpdate(updatedTopic)
                    }
            }
            
            // Stats
            HStack(spacing: 16) {
                StatChip(icon: "text.bubble.fill", value: "\(topic.discussionCount)", label: "Discussions")
                StatChip(icon: "person.2.fill", value: "\(topic.participantCount)", label: "Participants")
                
                Spacer()
                
                // Priority picker
                HStack(spacing: 4) {
                    Text("Priority:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(1...10, id: \.self) { p in
                            Text("\(p)").tag(p)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: priority) { _, newValue in
                        var updatedTopic = topic
                        updatedTopic.priority = newValue
                        onUpdate(updatedTopic)
                    }
                }
            }
            
            // Description if available
            if let description = topic.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Keywords
            if !topic.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(topic.keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption2)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.vertical, 8)
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            AdminTopicDetailView(topic: topic)
        }
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Admin Topic Detail View

struct AdminTopicDetailView: View {
    let topic: TrendingTopic
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(topic.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let description = topic.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        // Metadata
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Category:")
                                    .fontWeight(.medium)
                                Text(topic.category.displayName)
                                    .foregroundColor(topic.category.color)
                            }
                            
                            HStack {
                                Text("Source:")
                                    .fontWeight(.medium)
                                Text(topic.source.displayName)
                                    .foregroundColor(topic.source.color)
                            }
                            
                            HStack {
                                Text("Created:")
                                    .fontWeight(.medium)
                                Text(topic.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundColor(.secondary)
                            }
                            
                            if let lastActivity = topic.lastActivity {
                                HStack {
                                    Text("Last Activity:")
                                        .fontWeight(.medium)
                                    Text(lastActivity.formatted(date: .abbreviated, time: .shortened))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Statistics")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            TopicAdminStatCard(title: "Discussions", value: "\(topic.discussionCount)", color: .blue)
                            TopicAdminStatCard(title: "Participants", value: "\(topic.participantCount)", color: .green)
                            TopicAdminStatCard(title: "Messages", value: "\(topic.messageCount)", color: .orange)
                            TopicAdminStatCard(title: "Popularity", value: "\(Int(topic.popularity * 100))%", color: .purple)
                        }
                    }
                    
                    // Keywords
                    if !topic.keywords.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Keywords")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(topic.keywords, id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    Spacer()
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
        }
    }
}

// MARK: - Stat Card

struct TopicAdminStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    AdminTrendingTopicsView()
}
