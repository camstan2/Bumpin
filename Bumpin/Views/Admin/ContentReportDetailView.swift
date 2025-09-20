import SwiftUI
import FirebaseFirestore

struct ContentReportDetailView: View {
    let report: ReportingService.ContentReport
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reportingService = ReportingService.shared
    @State private var selectedAction: ReportAction = .noAction
    @State private var adminNotes = ""
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var contentDetails: String = ""
    @State private var reportedUserInfo: UserProfile?
    @State private var reporterUserInfo: UserProfile?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Report Header
                    reportHeader
                    
                    // Content Details
                    contentDetailsSection
                    
                    // User Information
                    userInformationSection
                    
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
                        Text("Report resolved successfully")
                            .foregroundColor(.green)
                            .padding()
                    }
                }
                .padding()
                .padding(.bottom, 100) // Space for action button
            }
            .navigationTitle("Content Report")
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
                    Text("Content Type:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(report.contentType.displayName)
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
        }
    }
    
    private var contentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reported Content")
                .font(.headline)
                .fontWeight(.bold)
            
            if !contentDetails.isEmpty {
                Text(contentDetails)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            } else {
                Text("Loading content...")
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
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
            Text("User Information")
                .font(.headline)
                .fontWeight(.bold)
            
            // Reported User
            VStack(alignment: .leading, spacing: 8) {
                Text("Reported User:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    if let userInfo = reportedUserInfo {
                        if let profileUrl = userInfo.profilePictureUrl, let url = URL(string: profileUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(userInfo.username.prefix(1)).uppercased())
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("@\(userInfo.username)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if !userInfo.displayName.isEmpty {
                                Text(userInfo.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("@\(report.reportedUsername)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Reporter (anonymous to protect privacy)
            VStack(alignment: .leading, spacing: 8) {
                Text("Reporter:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Reporter ID: \(report.reporterUserId.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    private var actionSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Admin Action")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(ReportAction.allCases, id: \.self) { action in
                    ActionSelectionCard(
                        action: action,
                        isSelected: selectedAction == action
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
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadAdditionalData() {
        // Load the actual content being reported
        Task {
            // This would fetch the actual content from the appropriate collection
            // For now, using placeholder
            await MainActor.run {
                contentDetails = "Content details would be loaded here..."
            }
        }
        
        // Load user profiles
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
        }
    }
    
    private func resolveReport() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            let success = await reportingService.resolveReport(
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
                    errorMessage = "Failed to resolve report. Please try again."
                }
            }
        }
    }
}

struct ActionSelectionCard: View {
    let action: ReportAction
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
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
                    .fill(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension ReportAction: CaseIterable {
    public static var allCases: [ReportAction] = [
        .noAction,
        .userWarned,
        .contentRemoved,
        .userMuted,
        .userBanned
    ]
    
    var displayName: String {
        switch self {
        case .noAction: return "No Action Required"
        case .userWarned: return "Warn User"
        case .contentRemoved: return "Remove Content"
        case .userMuted: return "Mute User"
        case .userBanned: return "Ban User"
        }
    }
    
    var description: String {
        switch self {
        case .noAction: return "Report is not valid or doesn't require action"
        case .userWarned: return "Send a warning to the user about their behavior"
        case .contentRemoved: return "Remove the reported content from the platform"
        case .userMuted: return "Temporarily restrict user's ability to post content"
        case .userBanned: return "Permanently ban the user from the platform"
        }
    }
}

#Preview {
    ContentReportDetailView(
        report: ReportingService.ContentReport(
            id: "test-report",
            contentId: "test-content",
            contentType: .musicReview,
            reporterUserId: "reporter-123",
            reportedUserId: "reported-456",
            reportedUsername: "testuser",
            reason: .inappropriateContent,
            additionalDetails: "This content contains inappropriate language",
            timestamp: Date().addingTimeInterval(-3600),
            status: .pending
        )
    ) {
        // onComplete
    }
}
