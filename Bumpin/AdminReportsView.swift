import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AdminReportsView: View {
    enum ReportTab: String, CaseIterable, Identifiable {
        case reviews = "Reviews"
        case comments = "Comments"
        case users = "Users"
        var id: String { rawValue }
    }
    
    @State private var selectedTab: ReportTab = .reviews
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var contentReports: [ReportingService.ContentReport] = []
    @State private var userReports: [UserReport] = []
    @State private var selectedContentReport: ReportingService.ContentReport?
    @State private var selectedUserReport: UserReport?
    
    private let reportingService = ReportingService.shared
    
    // Filtered reports by type
    private var reviewReports: [ReportingService.ContentReport] {
        contentReports.filter { $0.contentType == .musicReview }
    }
    
    private var commentReports: [ReportingService.ContentReport] {
        contentReports.filter { $0.contentType == .comment }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Report Tab", selection: $selectedTab) {
                ForEach(ReportTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            content(for: selectedTab)
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadReports() }
        .refreshable { await loadReports() }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $selectedContentReport) { report in
            AdminReportDetailView(report: report) {
                // on resolved
                contentReports.removeAll { $0.id == report.id }
            }
        }
        .sheet(item: $selectedUserReport) { report in
            AdminUserReportDetailView(report: report) {
                // on resolved
                userReports.removeAll { $0.id == report.id }
            }
        }
    }
    
    @ViewBuilder
    private func content(for tab: ReportTab) -> some View {
        switch tab {
        case .reviews:
            reportList(
                isLoading: isLoading,
                reports: reviewReports.map { AnyReport.content($0) },
                onSelect: { report in
                    if case let .content(r) = report { selectedContentReport = r }
                },
                emptyMessage: "No pending review reports"
            )
        case .comments:
            reportList(
                isLoading: isLoading,
                reports: commentReports.map { AnyReport.content($0) },
                onSelect: { report in
                    if case let .content(r) = report { selectedContentReport = r }
                },
                emptyMessage: "No pending comment reports"
            )
        case .users:
            reportList(
                isLoading: isLoading,
                reports: userReports.map { AnyReport.user($0) },
                onSelect: { report in
                    if case let .user(r) = report { selectedUserReport = r }
                },
                emptyMessage: "No pending user reports"
            )
        }
    }
    
    @ViewBuilder
    private func reportList(
        isLoading: Bool,
        reports: [AnyReport],
        onSelect: @escaping (AnyReport) -> Void,
        emptyMessage: String
    ) -> some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
        } else if reports.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "flag")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(reports) { report in
                    Button {
                        onSelect(report)
                    } label: {
                        ReportRow(report: report)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
    
    private func loadReports() async {
        guard let _ = Auth.auth().currentUser else {
            await MainActor.run {
                errorMessage = "Not authenticated"
                showErrorAlert = true
            }
            return
        }
        await MainActor.run {
            isLoading = true
        }
        async let contentTask = reportingService.getPendingReports()
        async let userTask = reportingService.getPendingUserReports()
        let content = await contentTask
        let users = await userTask
        await MainActor.run {
            self.contentReports = content
            self.userReports = users
            self.isLoading = false
        }
    }
}

// MARK: - Models for UI
private enum AnyReport: Identifiable {
    case content(ReportingService.ContentReport)
    case user(UserReport)
    
    var id: String {
        switch self {
        case .content(let r): return r.id
        case .user(let r): return r.id
        }
    }
    
    var title: String {
        switch self {
        case .content(let r): return r.contentType.displayName
        case .user: return "User Report"
        }
    }
    
    var subtitle: String {
        switch self {
        case .content(let r): return "Reason: \(r.reason.displayName)"
        case .user(let r): return "Reason: \(r.reason.displayName)"
        }
    }
    
    var reportedUsername: String {
        switch self {
        case .content(let r): return r.reportedUsername
        case .user(let r): return r.reportedUsername
        }
    }
    
    var timestamp: Date {
        switch self {
        case .content(let r): return r.timestamp
        case .user(let r): return r.timestamp
        }
    }
}

// MARK: - Row
private struct ReportRow: View {
    let report: AnyReport
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flag.fill")
                .foregroundColor(.red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(.headline)
                Text(report.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("@\(report.reportedUsername)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(report.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}
