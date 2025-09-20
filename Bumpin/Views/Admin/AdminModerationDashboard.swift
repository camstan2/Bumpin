import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AdminModerationDashboard: View {
    @StateObject private var reportingService = ReportingService.shared
    @StateObject private var contentModerationService = ContentModerationService.shared
    @State private var contentReports: [ReportingService.ContentReport] = []
    @State private var userReports: [UserReport] = []
    @State private var isLoading = false
    @State private var selectedTab = 0
    @State private var selectedReport: ReportingService.ContentReport?
    @State private var selectedUserReport: UserReport?
    @State private var showReportDetail = false
    @State private var showUserReportDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Admin Header
                adminHeader
                
                // Tab Selector
                Picker("Report Type", selection: $selectedTab) {
                    Text("Content Reports (\(contentReports.count))").tag(0)
                    Text("User Reports (\(userReports.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                if isLoading {
                    ProgressView("Loading reports...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedTab) {
                        contentReportsView.tag(0)
                        userReportsView.tag(1)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Moderation Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadReports()
            }
            .refreshable {
                loadReports()
            }
            .sheet(isPresented: $showReportDetail, content: {
                if let report = selectedReport {
                    ContentReportDetailView(report: report) {
                        loadReports()
                    }
                }
            })
            .sheet(isPresented: $showUserReportDetail, content: {
                if let report = selectedUserReport {
                    UserReportDetailView(report: report) {
                        loadReports()
                    }
                }
            })
        }
    }
    
    private var adminHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Admin Moderation")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("24-hour response commitment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Priority indicator
                if hasPriorityReports {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text("Priority")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Quick stats
            HStack(spacing: 20) {
                StatCard(
                    title: "Pending",
                    value: "\(contentReports.count + userReports.count)",
                    color: .orange
                )
                
                StatCard(
                    title: "Urgent",
                    value: "\(urgentReportsCount)",
                    color: .red
                )
                
                StatCard(
                    title: "Response Time",
                    value: "< 24h",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var contentReportsView: some View {
        List {
            if contentReports.isEmpty {
                Text("No pending content reports")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(contentReports) { report in
                    ContentReportRow(report: report) {
                        selectedReport = report
                        showReportDetail = true
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var userReportsView: some View {
        List {
            if userReports.isEmpty {
                Text("No pending user reports")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(userReports) { report in
                    UserReportRow(report: report) {
                        selectedUserReport = report
                        showUserReportDetail = true
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var hasPriorityReports: Bool {
        let now = Date()
        let priorityThreshold = now.addingTimeInterval(-6 * 3600) // 6 hours ago
        
        return contentReports.contains { $0.timestamp < priorityThreshold } ||
               userReports.contains { $0.timestamp < priorityThreshold }
    }
    
    private var urgentReportsCount: Int {
        let now = Date()
        let urgentThreshold = now.addingTimeInterval(-12 * 3600) // 12 hours ago
        
        let urgentContent = contentReports.filter { $0.timestamp < urgentThreshold }.count
        let urgentUsers = userReports.filter { $0.timestamp < urgentThreshold }.count
        
        return urgentContent + urgentUsers
    }
    
    private func loadReports() {
        isLoading = true
        
        Task {
            async let contentReportsTask = reportingService.getPendingReports()
            async let userReportsTask = reportingService.getPendingUserReports()
            
            let (fetchedContentReports, fetchedUserReports) = await (contentReportsTask, userReportsTask)
            
            await MainActor.run {
                self.contentReports = fetchedContentReports
                self.userReports = fetchedUserReports
                self.isLoading = false
            }
        }
    }
}

struct StatCard: View {
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
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct ContentReportRow: View {
    let report: ReportingService.ContentReport
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Priority indicator
                    if isUrgent {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    } else if isPriority {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(report.contentType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(timeAgoString(from: report.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Reason: \(report.reason.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Reported user: @\(report.reportedUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let preview = contentPreview {
                    Text(preview)
                        .font(.caption)
                        .lineLimit(2)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                }
                
                HStack {
                    Label("High Priority", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .opacity(isUrgent ? 1 : 0)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isUrgent ? Color.red : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isUrgent: Bool {
        let now = Date()
        let urgentThreshold = now.addingTimeInterval(-12 * 3600) // 12 hours
        return report.timestamp < urgentThreshold
    }
    
    private var isPriority: Bool {
        let now = Date()
        let priorityThreshold = now.addingTimeInterval(-6 * 3600) // 6 hours
        return report.timestamp < priorityThreshold
    }
    
    private var contentPreview: String? {
        // This would need to be fetched from the actual content
        // For now, return a placeholder
        return "Content preview would be shown here..."
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct UserReportRow: View {
    let report: UserReport
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Priority indicator
                    if isUrgent {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    } else if isPriority {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text("User Report")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(timeAgoString(from: report.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Reason: \(report.reason.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Reported user: @\(report.reportedUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let details = report.additionalDetails, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .lineLimit(2)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                }
                
                HStack {
                    Label("High Priority", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .opacity(isUrgent ? 1 : 0)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isUrgent ? Color.red : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isUrgent: Bool {
        let now = Date()
        let urgentThreshold = now.addingTimeInterval(-12 * 3600) // 12 hours
        return report.timestamp < urgentThreshold
    }
    
    private var isPriority: Bool {
        let now = Date()
        let priorityThreshold = now.addingTimeInterval(-6 * 3600) // 6 hours
        return report.timestamp < priorityThreshold
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    AdminModerationDashboard()
}
