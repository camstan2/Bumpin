import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Simplified Admin Prompts View

struct SimplifiedAdminPromptsView: View {
    @StateObject private var viewModel = SimplifiedAdminViewModel()
    @State private var showCreatePrompt = false
    @State private var selectedTab: AdminTabType = .active
    
    enum AdminTabType: String, CaseIterable {
        case active = "Active"
        case scheduled = "Scheduled"
        case history = "History"
        
        var icon: String {
            switch self {
            case .active: return "bolt.fill"
            case .scheduled: return "calendar"
            case .history: return "clock.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                statsHeader
                
                // Tab Selector
                tabSelector
                
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .active:
                            activePromptSection
                        case .scheduled:
                            scheduledPromptsSection
                        case .history:
                            historySection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .refreshable {
                    await viewModel.refreshData()
                }
            }
            .navigationTitle("Daily Prompts Admin")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Manual check button for testing
                        Button(action: {
                            Task { await viewModel.refreshData() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: { showCreatePrompt = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreatePrompt) {
            SimplifiedCreatePromptView(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.loadAllData()
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack(spacing: 20) {
            AdminPromptStatCard(
                title: "Active",
                value: viewModel.activePrompt != nil ? "1" : "0",
                color: .green
            )
            
            AdminPromptStatCard(
                title: "Scheduled",
                value: "\(viewModel.scheduledPrompts.count)",
                color: .orange
            )
            
            AdminPromptStatCard(
                title: "Total",
                value: "\(viewModel.allPrompts.count)",
                color: .blue
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AdminTabType.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(selectedTab == tab ? .purple : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.purple : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Active Prompt Section
    
    private var activePromptSection: some View {
        VStack(spacing: 16) {
            if let activePrompt = viewModel.activePrompt {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Currently Active")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    
                    PromptCard(
                        prompt: activePrompt,
                        showActivateButton: false,
                        onActivate: {},
                        onDeactivate: {
                            Task {
                                await viewModel.deactivatePrompt(activePrompt.id)
                            }
                        },
                        onDelete: {
                            Task {
                                await viewModel.deletePrompt(activePrompt.id)
                            }
                        }
                    )
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No Active Prompt")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Activate a scheduled prompt or create a new one")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { showCreatePrompt = true }) {
                        Text("Create Prompt")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
    }
    
    // MARK: - Scheduled Prompts Section
    
    private var scheduledPromptsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Scheduled Prompts")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(viewModel.scheduledPrompts.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.scheduledPrompts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No Scheduled Prompts")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Create prompts for future dates")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.scheduledPrompts, id: \.id) { prompt in
                    PromptCard(
                        prompt: prompt,
                        showActivateButton: true,
                        onActivate: {
                            Task {
                                await viewModel.activatePrompt(prompt.id)
                            }
                        },
                        onDeactivate: {},
                        onDelete: {
                            Task {
                                await viewModel.deletePrompt(prompt.id)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Past Prompts")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(viewModel.pastPrompts.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.pastPrompts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No Past Prompts")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.pastPrompts, id: \.id) { prompt in
                    PromptCard(
                        prompt: prompt,
                        showActivateButton: false,
                        onActivate: {},
                        onDeactivate: {},
                        onDelete: {
                            Task {
                                await viewModel.deletePrompt(prompt.id)
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Admin Prompt Stat Card Component

struct AdminPromptStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Prompt Card Component

struct PromptCard: View {
    let prompt: DailyPrompt
    let showActivateButton: Bool
    let onActivate: () -> Void
    let onDeactivate: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with category and actions
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: prompt.category.icon)
                        .foregroundColor(prompt.category.color)
                    Text(prompt.category.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(prompt.category.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(prompt.category.color.opacity(0.1))
                .clipShape(Capsule())
                
                Spacer()
                
                Menu {
                    if prompt.isActive {
                        Button(role: .destructive, action: onDeactivate) {
                            Label("Deactivate", systemImage: "pause.fill")
                        }
                    }
                    
                    Button(role: .destructive, action: { showDeleteConfirm = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            
            // Title
            Text(prompt.title)
                .font(.headline)
                .fontWeight(.bold)
            
            // Description
            if let description = prompt.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Metadata
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(formatDate(prompt.date))
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                    Text("\(prompt.totalResponses)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            // Activate button (if applicable)
            if showActivateButton {
                Button(action: onActivate) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Activate Now")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
        )
        .alert("Delete Prompt?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Simplified Create Prompt View

struct SimplifiedCreatePromptView: View {
    let viewModel: SimplifiedAdminViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: PromptCategory = .mood
    @State private var activateImmediately: Bool = true
    @State private var scheduledDate: Date = Date()
    @State private var isCreating: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Prompt Title", text: $title)
                        .font(.body)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                        .font(.body)
                } header: {
                    Text("Prompt Details")
                }
                
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PromptCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                } header: {
                    Text("Category")
                }
                
                Section {
                    Toggle("Activate Immediately", isOn: $activateImmediately)
                    
                    if !activateImmediately {
                        DatePicker(
                            "Schedule For",
                            selection: $scheduledDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text("Activation")
                } footer: {
                    if activateImmediately {
                        Text("The prompt will be live immediately and visible to all users")
                    } else {
                        Text("The prompt will be scheduled and must be activated manually")
                    }
                }
            }
            .navigationTitle("Create Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createPrompt) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createPrompt() {
        isCreating = true
        Task {
            let success = await viewModel.createPrompt(
                title: title,
                description: description.isEmpty ? nil : description,
                category: selectedCategory,
                scheduledDate: activateImmediately ? nil : scheduledDate,
                activateImmediately: activateImmediately
            )
            
            await MainActor.run {
                isCreating = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Simplified Admin View Model

@MainActor
class SimplifiedAdminViewModel: ObservableObject {
    @Published var allPrompts: [DailyPrompt] = []
    @Published var activePrompt: DailyPrompt?
    @Published var scheduledPrompts: [DailyPrompt] = []
    @Published var pastPrompts: [DailyPrompt] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // MARK: - Load Data
    
    func loadAllData() async {
        print("🔄 [SimplifiedAdmin] Loading all prompts from Firestore...")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Add timeout to prevent long hangs
            let snapshot = try await withTimeout(seconds: 10) {
                try await self.db.collection("dailyPrompts")
                    .order(by: "date", descending: true)
                    .limit(to: 100)
                    .getDocuments()
            }
            
            let prompts = snapshot.documents.compactMap { doc -> DailyPrompt? in
                try? doc.data(as: DailyPrompt.self)
            }
            
            print("📊 [SimplifiedAdmin] Loaded \(prompts.count) total prompts")
            
            // Update all prompts
            allPrompts = prompts
            
            // Find active prompt
            activePrompt = prompts.first { $0.isActive && !$0.isArchived }
            print("✅ [SimplifiedAdmin] Active prompt: \(activePrompt?.title ?? "none")")
            
            // Filter scheduled prompts (not active, not archived, future or present date)
            scheduledPrompts = prompts.filter { !$0.isActive && !$0.isArchived }
                .sorted { $0.date < $1.date }
            print("📅 [SimplifiedAdmin] Scheduled prompts: \(scheduledPrompts.count)")
            
            // Filter past prompts (archived or past expiration date)
            pastPrompts = prompts.filter { $0.isArchived || ($0.expiresAt < Date() && !$0.isActive) }
            print("🕐 [SimplifiedAdmin] Past prompts: \(pastPrompts.count)")
            
        } catch {
            print("❌ [SimplifiedAdmin] Error loading prompts: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    struct TimeoutError: Error {
        var localizedDescription: String {
            return "Operation timed out"
        }
    }
    
    func refreshData() async {
        await loadAllData()
    }
    
    // MARK: - Create Prompt
    
    func createPrompt(
        title: String,
        description: String?,
        category: PromptCategory,
        scheduledDate: Date?,
        activateImmediately: Bool
    ) async -> Bool {
        let startTime = Date()
        print("📝 [SimplifiedAdmin] Creating prompt: '\(title)' at \(startTime)")
        print("   Activate immediately: \(activateImmediately)")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ [SimplifiedAdmin] No authenticated user")
            return false
        }
        
        do {
            // Calculate expiration (24 hours from activation)
            let activationDate = scheduledDate ?? Date()
            let expirationDate = Calendar.current.date(byAdding: .day, value: 1, to: activationDate) ?? activationDate.addingTimeInterval(86400)
            
            var prompt = DailyPrompt(
                title: title,
                description: description,
                category: category,
                createdBy: userId,
                expiresAt: expirationDate
            )
            
            if activateImmediately {
                // Deactivate existing prompts first (if any)
                let deactivateStart = Date()
                print("⏸️ [SimplifiedAdmin] Checking for active prompts to deactivate...")
                
                if let currentActive = activePrompt {
                    print("   📍 Found active prompt in local state: \(currentActive.id)")
                    do {
                        try await withTimeout(seconds: 3) {
                            try await self.db.collection("dailyPrompts")
                                .document(currentActive.id)
                                .updateData(["isActive": false])
                        }
                        print("   ✅ Deactivated: \(currentActive.title)")
                    } catch {
                        print("   ⚠️ Deactivation failed (continuing anyway): \(error.localizedDescription)")
                        // Continue anyway - Firestore rules will ensure only one active prompt
                    }
                } else {
                    print("   ℹ️ No active prompt in local state - skipping deactivation")
                }
                
                print("   ⏱️ Deactivation step took: \(Date().timeIntervalSince(deactivateStart))s")
                prompt.isActive = true
                print("✅ [SimplifiedAdmin] Prompt will be active")
            } else {
                prompt.date = scheduledDate ?? Date()
                prompt.isActive = false
                print("📅 [SimplifiedAdmin] Prompt scheduled for \(prompt.date)")
            }
            
            // Save to Firestore
            let saveStart = Date()
            print("💾 [SimplifiedAdmin] Saving to Firestore...")
            try await db.collection("dailyPrompts").document(prompt.id).setData(from: prompt)
            print("   ⏱️ Save took: \(Date().timeIntervalSince(saveStart))s")
            print("✅ [SimplifiedAdmin] Prompt saved with ID: \(prompt.id)")
            print("   isActive: \(prompt.isActive)")
            
            // Update local state immediately without full reload
            await updateLocalStateAfterCreate(prompt)
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("🎉 [SimplifiedAdmin] Prompt created successfully!")
            print("   ⏱️ Total time: \(totalTime)s")
            return true
            
        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            print("❌ [SimplifiedAdmin] Error creating prompt: \(error.localizedDescription)")
            print("   ⏱️ Failed after: \(totalTime)s")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    private func updateLocalStateAfterCreate(_ prompt: DailyPrompt) async {
        // Insert into allPrompts at the beginning
        allPrompts.insert(prompt, at: 0)
        
        if prompt.isActive {
            // Set as active prompt
            activePrompt = prompt
            // Remove from scheduled
            scheduledPrompts.removeAll { $0.isActive }
            print("✅ [SimplifiedAdmin] Updated local state - prompt is active")
        } else if !prompt.isArchived {
            // Add to scheduled
            scheduledPrompts.insert(prompt, at: 0)
            scheduledPrompts.sort { $0.date < $1.date }
            print("✅ [SimplifiedAdmin] Updated local state - prompt is scheduled")
        }
    }
    
    // MARK: - Activate Prompt
    
    func activatePrompt(_ promptId: String) async {
        print("⚡ [SimplifiedAdmin] Activating prompt: \(promptId)")
        
        do {
            // Deactivate current active prompt if any (with timeout and graceful failure)
            if let currentActive = activePrompt {
                print("   📍 Deactivating current active prompt: \(currentActive.id)")
                do {
                    try await withTimeout(seconds: 3) {
                        try await self.db.collection("dailyPrompts")
                            .document(currentActive.id)
                            .updateData(["isActive": false])
                    }
                    print("   ✅ Deactivated previous prompt")
                } catch {
                    print("   ⚠️ Deactivation failed (continuing anyway): \(error.localizedDescription)")
                }
            }
            
            // Activate this prompt
            try await db.collection("dailyPrompts").document(promptId).updateData([
                "isActive": true,
                "date": FieldValue.serverTimestamp()
            ])
            
            print("✅ [SimplifiedAdmin] Prompt activated in Firestore")
            
            // Update local state immediately
            await updateLocalStateAfterActivation(promptId)
            
        } catch {
            print("❌ [SimplifiedAdmin] Error activating prompt: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func updateLocalStateAfterActivation(_ promptId: String) async {
        // Find and update the prompt in allPrompts
        if let index = allPrompts.firstIndex(where: { $0.id == promptId }) {
            allPrompts[index].isActive = true
            allPrompts[index].date = Date()
            
            // Set as active prompt
            activePrompt = allPrompts[index]
            
            // Remove from scheduled
            scheduledPrompts.removeAll { $0.id == promptId }
            
            print("✅ [SimplifiedAdmin] Local state updated - prompt is now active")
        }
    }
    
    // MARK: - Deactivate Prompt
    
    func deactivatePrompt(_ promptId: String) async {
        print("⏸️ [SimplifiedAdmin] Deactivating prompt: \(promptId)")
        
        do {
            try await db.collection("dailyPrompts").document(promptId).updateData([
                "isActive": false
            ])
            
            print("✅ [SimplifiedAdmin] Prompt deactivated")
            
            // Update local state immediately
            await updateLocalStateAfterDeactivation(promptId)
            
        } catch {
            print("❌ [SimplifiedAdmin] Error deactivating prompt: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func updateLocalStateAfterDeactivation(_ promptId: String) async {
        // Find and update the prompt in allPrompts
        if let index = allPrompts.firstIndex(where: { $0.id == promptId }) {
            allPrompts[index].isActive = false
            
            // Clear active prompt if this was it
            if activePrompt?.id == promptId {
                activePrompt = nil
            }
            
            // Add back to scheduled if not archived
            if !allPrompts[index].isArchived {
                scheduledPrompts.insert(allPrompts[index], at: 0)
                scheduledPrompts.sort { $0.date < $1.date }
            }
            
            print("✅ [SimplifiedAdmin] Local state updated - prompt is now inactive")
        }
    }
    
    private func deactivateAllPrompts() async {
        print("⏸️ [SimplifiedAdmin] Deactivating all prompts...")
        let startTime = Date()
        
        do {
            // Optimization: If we know the active prompt from local state, just deactivate that one
            if let activePrompt = activePrompt {
                print("   📍 Found active prompt in local state: \(activePrompt.id)")
                
                // Add timeout to prevent hanging
                try await withTimeout(seconds: 5) {
                    try await self.db.collection("dailyPrompts").document(activePrompt.id).updateData([
                        "isActive": false
                    ])
                }
                
                print("   ✅ Deactivated prompt: \(activePrompt.title)")
            } else {
                // Fallback: Query for any active prompts (shouldn't happen often)
                print("   🔍 No local active prompt, querying Firestore...")
                
                let activePrompts = try await withTimeout(seconds: 5) {
                    try await self.db.collection("dailyPrompts")
                        .whereField("isActive", isEqualTo: true)
                        .getDocuments()
                }
                
                if !activePrompts.documents.isEmpty {
                    let batch = db.batch()
                    for doc in activePrompts.documents {
                        batch.updateData(["isActive": false], forDocument: doc.reference)
                    }
                    
                    try await withTimeout(seconds: 5) {
                        try await batch.commit()
                    }
                    
                    print("   ✅ Deactivated \(activePrompts.documents.count) prompt(s) via batch")
                } else {
                    print("   ℹ️ No active prompts found")
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ [SimplifiedAdmin] All prompts deactivated in \(duration)s")
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ [SimplifiedAdmin] Error deactivating prompts after \(duration)s: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Delete Prompt
    
    func deletePrompt(_ promptId: String) async {
        print("🗑️ [SimplifiedAdmin] Deleting prompt: \(promptId)")
        
        do {
            try await db.collection("dailyPrompts").document(promptId).delete()
            print("✅ [SimplifiedAdmin] Prompt deleted")
            
            // Update local state immediately
            await updateLocalStateAfterDeletion(promptId)
            
        } catch {
            print("❌ [SimplifiedAdmin] Error deleting prompt: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func updateLocalStateAfterDeletion(_ promptId: String) async {
        // Remove from all arrays
        allPrompts.removeAll { $0.id == promptId }
        scheduledPrompts.removeAll { $0.id == promptId }
        pastPrompts.removeAll { $0.id == promptId }
        
        // Clear active prompt if this was it
        if activePrompt?.id == promptId {
            activePrompt = nil
        }
        
        print("✅ [SimplifiedAdmin] Local state updated - prompt removed")
    }
}

