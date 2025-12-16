import SwiftUI
import FirebaseFirestore

struct AdminReportDetailView: View {
    let report: ReportingService.ContentReport
    var onResolved: () -> Void
    
    @State private var adminNotes: String = ""
    @State private var selectedAction: ReportAction = .noAction
    @State private var isSubmitting = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var reportedContentText: String? = nil
    @State private var isLoadingContent = true
    
    private let reportingService = ReportingService.shared
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Reported Content Section
                Section(header: Text("Reported Content")) {
                    if isLoadingContent {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else if let contentText = reportedContentText, !contentText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(contentText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    } else {
                        Text("Content not available or has been deleted")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                // MARK: - Report Details Section
                Section(header: Text("Report Details")) {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(report.contentType.displayName)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Reason")
                        Spacer()
                        Text(report.reason.displayName)
                            .foregroundColor(.purple)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("Reported user")
                        Spacer()
                        Text("@\(report.reportedUsername)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Reporter ID")
                        Spacer()
                        Text(report.reporterUserId.prefix(12) + "...")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    HStack {
                        Text("Timestamp")
                        Spacer()
                        Text(report.timestamp, style: .relative)
                            .foregroundColor(.secondary)
                    }
                    
                    if let additionalDetails = report.additionalDetails, !additionalDetails.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Additional Details")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(additionalDetails)
                                .font(.body)
                        }
                    }
                }
                
                // MARK: - Action Section
                Section(header: Text("Action")) {
                    Picker("Action", selection: $selectedAction) {
                        ForEach(ReportAction.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Admin notes (optional)", text: $adminNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // MARK: - Resolve Button
                Section {
                    Button {
                        Task { await resolve() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Resolve Report")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting)
                    .foregroundColor(.white)
                    .listRowBackground(Color.purple)
                }
            }
            .navigationTitle(report.contentType == .comment ? "Comment Report" : "Review Report")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadReportedContent()
            }
        }
    }
    
    // MARK: - Load Reported Content
    private func loadReportedContent() async {
        await MainActor.run { isLoadingContent = true }
        
        do {
            var text: String? = nil
            
            switch report.contentType {
            case .musicReview:
                // Fetch the log/review
                let logDoc = try await db.collection("logs").document(report.contentId).getDocument()
                if let data = logDoc.data() {
                    text = data["reviewText"] as? String ?? data["review"] as? String
                }
                
            case .comment:
                // Comments are stored in logs/{logId}/comments/{commentId}
                // The contentId might be in format "logId_commentId" or just the commentId
                // We need to search for it
                text = await fetchCommentText(contentId: report.contentId)
                
            case .chatMessage:
                let messageDoc = try await db.collection("chatMessages").document(report.contentId).getDocument()
                if let data = messageDoc.data() {
                    text = data["text"] as? String ?? data["message"] as? String
                }
                
            case .userBio:
                let userDoc = try await db.collection("users").document(report.contentId).getDocument()
                if let data = userDoc.data() {
                    text = data["bio"] as? String
                }
                
            case .username:
                let userDoc = try await db.collection("users").document(report.contentId).getDocument()
                if let data = userDoc.data() {
                    text = data["displayName"] as? String ?? data["username"] as? String
                }
                
            case .partyName:
                let partyDoc = try await db.collection("parties").document(report.contentId).getDocument()
                if let data = partyDoc.data() {
                    text = data["name"] as? String
                }
                
            case .topicName, .topicDescription:
                let topicDoc = try await db.collection("topics").document(report.contentId).getDocument()
                if let data = topicDoc.data() {
                    if report.contentType == .topicName {
                        text = data["name"] as? String
                    } else {
                        text = data["description"] as? String
                    }
                }
            }
            
            await MainActor.run {
                self.reportedContentText = text
                self.isLoadingContent = false
            }
        } catch {
            print("❌ Failed to load reported content: \(error)")
            await MainActor.run {
                self.reportedContentText = nil
                self.isLoadingContent = false
            }
        }
    }
    
    // MARK: - Fetch Comment Text
    private func fetchCommentText(contentId: String) async -> String? {
        // Try parsing contentId as "logId_commentId"
        if contentId.contains("_") {
            let parts = contentId.split(separator: "_")
            if parts.count >= 2 {
                let logId = String(parts[0])
                let commentId = String(parts[1])
                
                do {
                    let commentDoc = try await db.collection("logs")
                        .document(logId)
                        .collection("comments")
                        .document(commentId)
                        .getDocument()
                    
                    if let data = commentDoc.data() {
                        return data["text"] as? String ?? data["content"] as? String
                    }
                } catch {
                    print("⚠️ Failed to fetch comment with logId_commentId format: \(error)")
                }
            }
        }
        
        // Fallback: Search all logs for this comment
        do {
            let logsSnapshot = try await db.collection("logs").limit(to: 100).getDocuments()
            
            for logDoc in logsSnapshot.documents {
                let commentDoc = try? await db.collection("logs")
                    .document(logDoc.documentID)
                    .collection("comments")
                    .document(contentId)
                    .getDocument()
                
                if let commentDoc = commentDoc, commentDoc.exists, let data = commentDoc.data() {
                    return data["text"] as? String ?? data["content"] as? String
                }
            }
        } catch {
            print("⚠️ Failed to search for comment: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Resolve
    private func resolve() async {
        await MainActor.run { isSubmitting = true }
        let success = await reportingService.resolveReport(
            reportId: report.id,
            action: selectedAction,
            adminNotes: adminNotes.isEmpty ? nil : adminNotes
        )
        await MainActor.run {
            isSubmitting = false
            if success {
                onResolved()
            } else {
                errorMessage = "Failed to resolve report."
                showErrorAlert = true
            }
        }
    }
}

