import SwiftUI

struct ReportContentView: View {
    let contentId: String
    let contentType: ReportableContentType
    let reportedUserId: String
    let reportedUsername: String
    let contentPreview: String?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: ReportReason = .inappropriateContent
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
                        Image(systemName: "exclamationmark.shield")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("Report \(contentType.displayName)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Help us keep Bumpin safe by reporting content that violates our community guidelines")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // Content Preview
                    if let preview = contentPreview {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reported Content")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("By: @\(reportedUsername)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(preview)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .lineLimit(5)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Reason Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Why are you reporting this?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(ReportReason.allCases, id: \.self) { reason in
                                ReportReasonCard(
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
                        
                        Text("Provide any additional context that might help us understand the issue")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $additionalDetails)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // Warning
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Important")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        
                        Text("False reports may result in action against your account. Only report content that genuinely violates our community guidelines.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Success Message
                    if showSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Report submitted successfully. We'll review it within 24 hours.")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100) // Space for button
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                // Submit Button
                Button(action: submitReport) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
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
                    .background(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isSubmitting || showSuccess)
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
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            let success = await ReportingService.shared.reportContent(
                contentId: contentId,
                contentType: contentType,
                reportedUserId: reportedUserId,
                reportedUsername: reportedUsername,
                reason: selectedReason,
                additionalDetails: additionalDetails.isEmpty ? nil : additionalDetails
            )
            
            await MainActor.run {
                isSubmitting = false
                
                if success {
                    showSuccess = true
                    
                    // Auto-dismiss after showing success
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

struct ReportReasonCard: View {
    let reason: ReportReason
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
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
                
                Text(reason.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
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
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    ReportContentView(
        contentId: "test-id",
        contentType: .musicReview,
        reportedUserId: "user-123",
        reportedUsername: "testuser",
        contentPreview: "This is a sample review that might contain inappropriate content that needs to be reported."
    )
}
