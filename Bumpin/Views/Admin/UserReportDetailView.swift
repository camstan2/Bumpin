import SwiftUI
import FirebaseFirestore

struct UserReportDetailView: View {
    let report: UserReport
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportingService = ReportingService.shared
    @State private var selectedAction: UserReportAction = .noAction
    @State private var adminNotes = ""
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var reportedUserInfo: UserProfile?
    @State private var userViolationHistory: [ContentViolation] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Report Header
                    reportHeader
                    
                    // User Information
                    userInformationSection
                    
                    // Violation History
                    violationHistorySection
                    
                    // Action Selection
                    actionSelectionSection
                    
                    // Admin Notes
                    adminNotesSection
                    
                    // Error/Success Messages
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    if showSuccess {
                        Text("User report resolved successfully")
                            .foregroundColor(.green)
                            .padding()
                    }
                }
                .padding()
                .padding(.bottom, 100) // Space for action button
            }
            .navigationTitle("User Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                actionButton
            }
            .onAppear {
                loadAdditionalData()
            }
        }
    }
    
    private var reportHeader: some View {
        VStack(spacing: 16) {
            // Priority indicator
            HStack {
                if isUrgent {
                    Label("URGENT - Over 12 hours old", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                } else if isPriority {
                    Label("Priority - Over 6 hours old", systemImage: "clock.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            
            // Report info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Report ID:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(report.id.prefix(8) + "...")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Text("Reason:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(report.reason.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Text("Reported:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(timeAgoString(from: report.timestamp))
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Additional details if provided
            if let additionalDetails = report.additionalDetails, !additionalDetails.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reporter's Additional Details:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(additionalDetails)
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var userInformationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reported User")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                // Profile Picture
                if let userInfo = reportedUserInfo {
                    if let profileUrl = userInfo.profilePictureUrl, let url = URL(string: profileUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(String(userInfo.username.prefix(1)).uppercased())
                                    .font(.title)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("@\(userInfo.username)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(userInfo.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let joinedAt = userInfo.createdAt {
                            Text("Joined \(joinedAt, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // User stats
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reports")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(userInfo.reportCount ?? 0)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(userInfo.reportCount ?? 0 > 0 ? .red : .primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Violations")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(userInfo.violationCount ?? 0)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(userInfo.violationCount ?? 0 > 0 ? .red : .primary)
                            }
                        }
                    }
                } else {
                    Text("Loading user information...")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var violationHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Violation History")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(userViolationHistory.count) violations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if userViolationHistory.isEmpty {
                Text("No previous violations")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(userViolationHistory.prefix(5), id: \.id) { violation in
                        ViolationRow(violation: violation)
                    }
                    
                    if userViolationHistory.count > 5 {
                        Text("+ \(userViolationHistory.count - 5) more violations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    private var actionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Admin Action")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(UserReportAction.allCases, id: \.self) { action in
                    UserActionSelectionCard(
                        action: action,
                        isSelected: selectedAction == action,
                        isRecommended: recommendedAction == action
                    ) {
                        selectedAction = action
                    }
                }
            }
        }
    }
    
    private var adminNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin Notes")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Internal notes about this decision (optional)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $adminNotes)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    private var actionButton: some View {
        Button(action: resolveReport) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(isProcessing ? "Processing..." : "Resolve Report")
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [.green, .green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isProcessing || showSuccess)
        .padding(.horizontal)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [Color.clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
        )
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
    
    private var recommendedAction: UserReportAction {
        let violationCount = reportedUserInfo?.violationCount ?? 0
        let reportCount = reportedUserInfo?.reportCount ?? 0
        
        if violationCount >= 5 || reportCount >= 3 {
            return .userBanned
        } else if violationCount >= 3 || reportCount >= 2 {
            return .userMuted
        } else if violationCount >= 1 {
            return .userWarned
        } else {
            return .noAction
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadAdditionalData() {
        Task {
            let db = Firestore.firestore()
            
            // Load reported user info
            do {
                let reportedUserDoc = try await db.collection("users").document(report.reportedUserId).getDocument()
                if let userData = try? reportedUserDoc.data(as: UserProfile.self) {
                    await MainActor.run {
                        self.reportedUserInfo = userData
                    }
                }
            } catch {
                print("Failed to load reported user info: \(error)")
            }
            
            // Load violation history
            do {
                let violationsSnapshot = try await db.collection("contentViolations")
                    .whereField("userId", isEqualTo: report.reportedUserId)
                    .order(by: "timestamp", descending: true)
                    .limit(to: 10)
                    .getDocuments()
                
                let violations = violationsSnapshot.documents.compactMap { try? $0.data(as: ContentViolation.self) }
                
                await MainActor.run {
                    self.userViolationHistory = violations
                }
            } catch {
                print("Failed to load violation history: \(error)")
            }
        }
    }
    
    private func resolveReport() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            let success = await reportingService.resolveUserReport(
                reportId: report.id,
                action: selectedAction,
                adminNotes: adminNotes.isEmpty ? nil : adminNotes
            )
            
            await MainActor.run {
                isProcessing = false
                
                if success {
                    showSuccess = true
                    onComplete()
                    
                    // Auto-dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                } else {
                    errorMessage = "Failed to resolve user report. Please try again."
                }
            }
        }
    }
}

struct ViolationRow: View {
    let violation: ContentViolation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(violation.violationType)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(violation.contentType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(violation.severity.rawValue.capitalized)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(severityColor(violation.severity))
                
                Text(timeAgoString(from: violation.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func severityColor(_ severity: ViolationSeverity) -> Color {
        switch severity {
        case .none: return .gray
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct UserActionSelectionCard: View {
    let action: UserReportAction
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(action.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(action.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .font(.title2)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.1) : (isRecommended ? Color.blue.opacity(0.05) : Color(.systemGray6)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.green.opacity(0.3) : (isRecommended ? Color.blue.opacity(0.2) : Color.clear),
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension UserReportAction: CaseIterable {
    public static var allCases: [UserReportAction] = [
        .noAction,
        .userWarned,
        .userMuted,
        .accountSuspended,
        .userBanned
    ]
    
    var displayName: String {
        switch self {
        case .noAction: return "No Action Required"
        case .userWarned: return "Warn User"
        case .userMuted: return "Mute User"
        case .accountSuspended: return "Suspend Account"
        case .userBanned: return "Ban User"
        }
    }
    
    var description: String {
        switch self {
        case .noAction: return "Report is not valid or doesn't require action"
        case .userWarned: return "Send a warning to the user about their behavior"
        case .userMuted: return "Temporarily restrict user's ability to post content"
        case .accountSuspended: return "Temporarily suspend the user's account"
        case .userBanned: return "Permanently ban the user from the platform"
        }
    }
}

#Preview {
    UserReportDetailView(
        report: UserReport(
            id: "test-report",
            reporterUserId: "reporter-123",
            reportedUserId: "reported-456",
            reportedUsername: "testuser",
            reason: .harassment,
            additionalDetails: "This user has been harassing other users",
            relatedContentId: nil,
            timestamp: Date().addingTimeInterval(-3600),
            status: .pending
        )
    ) {
        // onComplete
    }
}
