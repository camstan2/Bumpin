import SwiftUI

struct AdminDailyPromptsView: View {
    @StateObject private var adminService = PromptAdminService()
    @State private var selectedTab: AdminTab = .overview
    @State private var showCreatePrompt = false
    @State private var showPromptTemplates = false
    @State private var showAnalytics = false
    
    enum AdminTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case active = "Active"
        case scheduled = "Scheduled"
        case monthlyScheduler = "Monthly Scheduler"
        case history = "History"
        case moderation = "Moderation"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .active: return "bolt.fill"
            case .scheduled: return "calendar"
            case .monthlyScheduler: return "calendar.badge.plus"
            case .history: return "clock.fill"
            case .moderation: return "shield.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Admin header
                adminHeader
                
                // Tab selector
                tabSelector
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .active:
                            activePromptContent
                        case .scheduled:
                            scheduledPromptsContent
                        case .monthlyScheduler:
                            monthlySchedulerContent
                        case .history:
                            promptHistoryContent
                        case .moderation:
                            moderationContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Daily Prompts Admin")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showCreatePrompt = true }) {
                            Label("Create Prompt", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showPromptTemplates = true }) {
                            Label("Manage Templates", systemImage: "doc.text")
                        }
                        
                        Button(action: { showAnalytics = true }) {
                            Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            Task { await adminService.loadAllData() }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreatePrompt) {
            CreatePromptView(adminService: adminService)
        }
        .sheet(isPresented: $showPromptTemplates) {
            PromptTemplatesView(adminService: adminService)
        }
        .sheet(isPresented: $showAnalytics) {
            PromptAnalyticsView(adminService: adminService)
        }
        .onAppear {
            Task { await adminService.loadAllData() }
        }
    }
    
    // MARK: - Admin Header
    
    private var adminHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Prompts")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Admin Dashboard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Quick stats
                HStack(spacing: 20) {
                    StatBadge(
                        value: "\(adminService.allPrompts.count)",
                        label: "Total",
                        color: .blue
                    )
                    
                    StatBadge(
                        value: "\(adminService.scheduledPrompts.count)",
                        label: "Scheduled",
                        color: .orange
                    )
                    
                    StatBadge(
                        value: "\(adminService.archivedPrompts.count)",
                        label: "Archived",
                        color: .gray
                    )
                }
            }
            
            // Active prompt status
            if let activePrompt = adminService.activePrompt {
                ActivePromptBanner(prompt: activePrompt)
            } else {
                NoActivePromptBanner {
                    showCreatePrompt = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(AdminTab.allCases) { tab in
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
                    .frame(minWidth: 100)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 20) {
            // Quick actions
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                QuickActionCard(
                    title: "Create Prompt",
                    subtitle: "New daily prompt",
                    icon: "plus.circle.fill",
                    color: .green
                ) {
                    showCreatePrompt = true
                }
                
                QuickActionCard(
                    title: "Smart Generate",
                    subtitle: "AI-powered prompt",
                    icon: "sparkles",
                    color: .purple
                ) {
                    createSmartPrompt()
                }
                
                QuickActionCard(
                    title: "View Analytics",
                    subtitle: "Engagement metrics",
                    icon: "chart.bar.fill",
                    color: .blue
                ) {
                    showAnalytics = true
                }
                
                QuickActionCard(
                    title: "Manage Templates",
                    subtitle: "Prompt templates",
                    icon: "doc.text.fill",
                    color: .orange
                ) {
                    showPromptTemplates = true
                }
            }
            
            // Recent activity
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Prompts")
                    .font(.headline)
                    .fontWeight(.bold)
                
                ForEach(Array(adminService.recentPrompts.prefix(5)), id: \.id) { prompt in
                    AdminPromptRow(prompt: prompt, adminService: adminService)
                }
                
                if adminService.recentPrompts.isEmpty {
                    Text("No recent prompts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
        }
    }
    
    // MARK: - Active Prompt Content
    
    private var activePromptContent: some View {
        VStack(spacing: 20) {
            if let activePrompt = adminService.activePrompt {
                ActivePromptDetails(prompt: activePrompt, adminService: adminService)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "bolt.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No Active Prompt")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Create or activate a prompt to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Create Prompt") {
                        showCreatePrompt = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Scheduled Prompts Content
    
    private var scheduledPromptsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Scheduled Prompts")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Schedule New") {
                    showCreatePrompt = true
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            if adminService.scheduledPrompts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("No Scheduled Prompts")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Schedule prompts to activate automatically")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                ForEach(adminService.scheduledPrompts, id: \.id) { prompt in
                    ScheduledPromptRow(prompt: prompt, adminService: adminService)
                }
            }
        }
    }
    
    // MARK: - Prompt History Content
    
    private var promptHistoryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prompt History")
                .font(.headline)
                .fontWeight(.bold)
            
            ForEach(adminService.allPrompts.filter { !$0.isActive }, id: \.id) { prompt in
                AdminPromptRow(prompt: prompt, adminService: adminService)
            }
            
            if adminService.allPrompts.filter({ !$0.isActive }).isEmpty {
                Text("No historical prompts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
    }
    
    // MARK: - Monthly Scheduler Content
    
    private var monthlySchedulerContent: some View {
        MonthlyPromptScheduler(adminService: adminService)
    }
    
    // MARK: - Moderation Content
    
    private var moderationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Moderation")
                .font(.headline)
                .fontWeight(.bold)
            
            // Moderation stats
            HStack(spacing: 20) {
                AdminStatCard(
                    title: "Reported",
                    value: "0", // Would need to implement reporting system
                    color: .red
                )
                
                AdminStatCard(
                    title: "Hidden",
                    value: "0", // Would need to track hidden responses
                    color: .orange
                )
                
                AdminStatCard(
                    title: "Active",
                    value: "\(adminService.allPrompts.filter { $0.isActive }.count)",
                    color: .green
                )
            }
            
            Text("Moderation tools will be available here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 20)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSmartPrompt() {
        if let template = adminService.generateSmartPrompt() {
            Task {
                await adminService.createPromptFromTemplate(template, scheduledDate: Date().addingTimeInterval(3600))
            }
        }
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct ActivePromptBanner: View {
    let prompt: DailyPrompt
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ACTIVE PROMPT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text(prompt.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(prompt.totalResponses)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct NoActivePromptBanner: View {
    let onCreateTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("NO ACTIVE PROMPT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("Create or activate a prompt")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Create") {
                onCreateTap()
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .foregroundColor(.orange)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AdminPromptRow: View {
    let prompt: DailyPrompt
    let adminService: PromptAdminService
    
    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: prompt.category)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(dateFormatter.string(from: prompt.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(prompt.totalResponses) responses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if prompt.isActive {
                Text("ACTIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            } else if prompt.isArchived {
                Text("ARCHIVED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Additional Views (Stubs for now)

struct CreatePromptView: View {
    let adminService: PromptAdminService
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: PromptCategory = .mood
    @State private var scheduledDate: Date = Date()
    @State private var activateImmediately: Bool = false
    @State private var showDatePicker: Bool = false
    
    // UI state
    @State private var isCreating: Bool = false
    @State private var showPreview: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    createPromptHeader
                    
                    // Form sections
                    VStack(spacing: 20) {
                        promptBasicsSection
                        categorySection
                        schedulingSection
                        previewSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
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
                    Button("Create") {
                        createPrompt()
                    }
                    .disabled(title.isEmpty || isCreating)
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            PromptPreviewView(
                title: title,
                description: description.isEmpty ? nil : description,
                category: selectedCategory,
                scheduledDate: scheduledDate
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Header
    
    private var createPromptHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple)
            
            Text("Create Daily Prompt")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Design a music prompt that will inspire your community to share and discover new songs")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Prompt Basics Section
    
    private var promptBasicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Prompt Details", icon: "text.bubble")
            
            VStack(alignment: .leading, spacing: 12) {
                // Title field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("What's your go-to song for...", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.subheadline)
                }
                
                // Description field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (Optional)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("Add context or instructions for your prompt", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.subheadline)
                        .lineLimit(3...6)
                }
                
                // Character count
                HStack {
                    Spacer()
                    Text("\(title.count)/100")
                        .font(.caption)
                        .foregroundColor(title.count > 100 ? .red : .secondary)
                }
            }
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Category", icon: "tag")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PromptCategory.allCases, id: \.self) { category in
                    CategorySelectionCard(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    // MARK: - Scheduling Section
    
    private var schedulingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Scheduling", icon: "calendar")
            
            VStack(spacing: 12) {
                // Activate immediately toggle
                Toggle(isOn: $activateImmediately) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activate Immediately")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Make this the active prompt right now")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .purple))
                
                if !activateImmediately {
                    // Scheduled date picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scheduled Date")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Button(action: { showDatePicker.toggle() }) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.purple)
                                
                                Text(dateFormatter.string(from: scheduledDate))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.tertiarySystemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.separator), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if showDatePicker {
                            DatePicker(
                                "Select Date",
                                selection: $scheduledDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(WheelDatePickerStyle())
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Preview", icon: "eye")
            
            Button(action: { showPreview = true }) {
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.blue)
                    
                    Text("Preview Your Prompt")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(title.isEmpty)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createPrompt() {
        guard !title.isEmpty else { return }
        
        isCreating = true
        
        Task {
            let success = await adminService.createPrompt(
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
                } else {
                    errorMessage = "Failed to create prompt. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct PromptTemplatesView: View {
    let adminService: PromptAdminService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Text("Prompt Templates Interface")
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
    }
}

struct PromptAnalyticsView: View {
    let adminService: PromptAdminService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Text("Analytics Dashboard")
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
    }
}

struct ActivePromptDetails: View {
    let prompt: DailyPrompt
    let adminService: PromptAdminService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Prompt Details")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Implementation coming soon...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct ScheduledPromptRow: View {
    let prompt: DailyPrompt
    let adminService: PromptAdminService
    
    var body: some View {
        AdminPromptRow(prompt: prompt, adminService: adminService)
    }
}

struct AdminStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
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

// MARK: - Monthly Prompt Scheduler

struct MonthlyPromptScheduler: View {
    let adminService: PromptAdminService
    @State private var selectedMonth = Date()
    @State private var monthlyPrompts: [Date: DailyPrompt] = [:]
    @State private var availableTemplates: [PromptTemplate] = []
    @State private var isGeneratingMonth = false
    @State private var showTemplateSelector = false
    @State private var selectedDate: Date?
    @State private var showBulkActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with month selector
            monthHeader
            
            // Action buttons
            actionButtons
            
            // Calendar grid
            monthlyCalendarGrid
            
            // Bulk actions
            if showBulkActions {
                bulkActionsSection
            }
        }
        .sheet(isPresented: $showTemplateSelector) {
            if let date = selectedDate {
                TemplateSelectionSheet(
                    date: date,
                    availableTemplates: availableTemplates,
                    adminService: adminService
                ) { template, scheduledDate in
                    schedulePromptFromTemplate(template, for: scheduledDate)
                }
            }
        }
        .onAppear {
            loadMonthlyData()
            loadAvailableTemplates()
        }
        .onChange(of: selectedMonth) { _, _ in
            loadMonthlyData()
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Prompt Scheduler")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Schedule daily prompts for the entire month ahead")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Month selector
            HStack {
                Button(action: { changeMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                Text(monthFormatter.string(from: selectedMonth))
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { changeMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { generateEntireMonth() }) {
                HStack(spacing: 6) {
                    if isGeneratingMonth {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("Auto-Generate Month")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .clipShape(Capsule())
            }
            .disabled(isGeneratingMonth)
            
            Spacer()
            
            Button(action: { showBulkActions.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: showBulkActions ? "checkmark" : "list.bullet")
                    Text("Bulk Actions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Monthly Calendar Grid
    
    private var monthlyCalendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            // Day headers
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(height: 30)
            }
            
            // Calendar days
            ForEach(daysInMonth, id: \.self) { date in
                if let date = date {
                    DayCell(
                        date: date,
                        prompt: monthlyPrompts[date],
                        isToday: Calendar.current.isDateInToday(date),
                        isPast: date < Date()
                    ) {
                        selectedDate = date
                        showTemplateSelector = true
                    }
                } else {
                    Color.clear
                        .frame(height: 60)
                }
            }
        }
    }
    
    // MARK: - Bulk Actions Section
    
    private var bulkActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bulk Actions")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack(spacing: 12) {
                Button("Clear Month") {
                    clearEntireMonth()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .clipShape(Capsule())
                
                Button("Fill Empty Days") {
                    fillEmptyDays()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .clipShape(Capsule())
                
                Button("Copy from Last Month") {
                    copyFromLastMonth()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .clipShape(Capsule())
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .top
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadMonthlyData() {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        let endOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
        
        // Filter existing prompts for this month
        monthlyPrompts = Dictionary(uniqueKeysWithValues: 
            adminService.allPrompts
                .filter { prompt in
                    prompt.date >= startOfMonth && prompt.date < endOfMonth
                }
                .map { prompt in
                    let dayKey = calendar.startOfDay(for: prompt.date)
                    return (dayKey, prompt)
                }
        )
    }
    
    private func loadAvailableTemplates() {
        availableTemplates = adminService.promptTemplates
    }
    
    private func changeMonth(_ direction: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: direction, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
    
    private func generateEntireMonth() {
        isGeneratingMonth = true
        
        Task {
            let calendar = Calendar.current
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
            let endOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
            
            var currentDate = startOfMonth
            var createdCount = 0
            
            while currentDate < endOfMonth {
                // Skip if prompt already exists for this day
                let dayKey = calendar.startOfDay(for: currentDate)
                if monthlyPrompts[dayKey] == nil {
                    // Generate a smart prompt for this day
                    if let template = adminService.generateSmartPrompt() {
                        let success = await adminService.createPromptFromTemplate(template, scheduledDate: currentDate)
                        if success {
                            createdCount += 1
                        }
                    }
                }
                
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            await MainActor.run {
                isGeneratingMonth = false
                loadMonthlyData() // Refresh the view
            }
        }
    }
    
    private func schedulePromptFromTemplate(_ template: PromptTemplate, for date: Date) {
        Task {
            let success = await adminService.createPromptFromTemplate(template, scheduledDate: date)
            if success {
                await MainActor.run {
                    loadMonthlyData()
                }
            }
        }
    }
    
    private func clearEntireMonth() {
        // Implementation for clearing all prompts in the month
        Task {
            for (_, prompt) in monthlyPrompts {
                await adminService.deletePrompt(prompt.id)
            }
            await MainActor.run {
                loadMonthlyData()
            }
        }
    }
    
    private func fillEmptyDays() {
        // Fill empty days with smart-generated prompts
        Task {
            let calendar = Calendar.current
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
            let endOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.end ?? selectedMonth
            
            var currentDate = startOfMonth
            
            while currentDate < endOfMonth {
                let dayKey = calendar.startOfDay(for: currentDate)
                if monthlyPrompts[dayKey] == nil {
                    if let template = adminService.generateSmartPrompt() {
                        await adminService.createPromptFromTemplate(template, scheduledDate: currentDate)
                    }
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            await MainActor.run {
                loadMonthlyData()
            }
        }
    }
    
    private func copyFromLastMonth() {
        // Implementation for copying prompts from the previous month
        // This would need more complex logic to adapt the prompts
    }
    
    private var daysInMonth: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        let range = calendar.range(of: .day, in: .month, for: selectedMonth) ?? 1..<32
        
        // Get the weekday of the first day of the month (1 = Sunday, 7 = Saturday)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        
        var days: [Date?] = []
        
        // Add empty cells for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add all days of the month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let prompt: DailyPrompt?
    let isToday: Bool
    let isPast: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(isPast ? .secondary : .primary)
                
                if let prompt = prompt {
                    Circle()
                        .fill(prompt.isActive ? Color.green : Color.purple)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? Color.purple.opacity(0.1) : Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? Color.purple : Color.clear, lineWidth: 1)
                    )
            )
        }
        .disabled(isPast && prompt == nil)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Template Selection Sheet

struct TemplateSelectionSheet: View {
    let date: Date
    let availableTemplates: [PromptTemplate]
    let adminService: PromptAdminService
    let onSelection: (PromptTemplate, Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: PromptTemplate?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select a Template for \(dateFormatter.string(from: date))")) {
                    ForEach(availableTemplates, id: \.id) { template in
                        TemplateRow(template: template, isSelected: selectedTemplate?.id == template.id) {
                            selectedTemplate = template
                        }
                    }
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schedule") {
                        if let template = selectedTemplate {
                            onSelection(template, date)
                            dismiss()
                        }
                    }
                    .disabled(selectedTemplate == nil)
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: PromptTemplate
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                CategoryBadge(category: template.category)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Components for Create Prompt

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.purple)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

struct CategorySelectionCard: View {
    let category: PromptCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color : category.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(category.color, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PromptPreviewView: View {
    let title: String
    let description: String?
    let category: PromptCategory
    let scheduledDate: Date
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview header
                    VStack(spacing: 12) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        Text("Prompt Preview")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("This is how your prompt will appear to users")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Mock prompt card
                    VStack(alignment: .leading, spacing: 16) {
                        // Category badge and response count
                        HStack {
                            CategoryBadge(category: category)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption)
                                Text("0")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        // Prompt title and description
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            if let description = description {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        
                        // Mock action button
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Share Your Song")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple)
                            )
                        }
                        .disabled(true)
                        
                        // Scheduled date info
                        if scheduledDate > Date() {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                Text("Scheduled for \(dateFormatter.string(from: scheduledDate))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    AdminDailyPromptsView()
}
