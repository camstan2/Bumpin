import SwiftUI

struct ReportButton: View {
    let contentId: String
    let contentType: ReportableContentType
    let reportedUserId: String
    let reportedUsername: String
    let contentPreview: String?
    
    @State private var showReportSheet = false
    
    var body: some View {
        Button(action: {
            showReportSheet = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.caption)
                Text("Report")
                    .font(.caption)
            }
            .foregroundColor(.red)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentId: contentId,
                contentType: contentType,
                reportedUserId: reportedUserId,
                reportedUsername: reportedUsername,
                contentPreview: contentPreview
            )
        }
    }
}

struct ReportMenuButton: View {
    let contentId: String
    let contentType: ReportableContentType
    let reportedUserId: String
    let reportedUsername: String
    let contentPreview: String?
    
    @State private var showReportSheet = false
    @State private var showBlockSheet = false
    
    var body: some View {
        Group {
            Button(action: {
                showReportSheet = true
            }) {
                Label("Report", systemImage: "flag")
            }
            
            Button(action: {
                showBlockSheet = true
            }) {
                Label("Block User", systemImage: "hand.raised")
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentView(
                contentId: contentId,
                contentType: contentType,
                reportedUserId: reportedUserId,
                reportedUsername: reportedUsername,
                contentPreview: contentPreview
            )
        }
        .sheet(isPresented: $showBlockSheet) {
            BlockUserView(
                userId: reportedUserId,
                username: reportedUsername,
                profilePictureUrl: nil
            )
        }
    }
}

// MARK: - Report User View

struct ReportUserView: View {
    let userId: String
    let username: String
    let relatedContentId: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: UserReportReason = .abusiveBehavior
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("Report User")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Report @\(username) for violating community guidelines")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Reason Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Why are you reporting this user?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(UserReportReason.allCases, id: \.self) { reason in
                                UserReportReasonCard(
                                    reason: reason,
                                    isSelected: selectedReason == reason
                                ) {
                                    selectedReason = reason
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Additional Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional Details (Optional)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextEditor(text: $additionalDetails)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Error/Success Messages
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    if showSuccess {
                        Text("User reported successfully")
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                Button(action: submitReport) {
                    HStack {
                        if isSubmitting {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Report")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red)
                    .cornerRadius(25)
                }
                .disabled(isSubmitting || showSuccess)
                .padding()
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            let success = await ReportingService.shared.reportUser(
                userId: userId,
                username: username,
                reason: selectedReason,
                additionalDetails: additionalDetails.isEmpty ? nil : additionalDetails,
                relatedContentId: relatedContentId
            )
            
            await MainActor.run {
                isSubmitting = false
                
                if success {
                    showSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                } else {
                    errorMessage = "Failed to submit report. Please try again."
                }
            }
        }
    }
}

struct UserReportReasonCard: View {
    let reason: UserReportReason
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(reason.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .red : .gray)
                    .font(.title2)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.red.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReportUserButton: View {
    let userId: String
    let username: String
    let relatedContentId: String?
    
    @State private var showReportSheet = false
    
    var body: some View {
        Button(action: {
            showReportSheet = true
        }) {
            Label("Report User", systemImage: "person.crop.circle.badge.exclamationmark")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportUserView(
                userId: userId,
                username: username,
                relatedContentId: relatedContentId
            )
        }
    }
}

#Preview {
    ReportButton(
        contentId: "test-id",
        contentType: .musicReview,
        reportedUserId: "user-123",
        reportedUsername: "testuser",
        contentPreview: "Sample content"
    )
}
