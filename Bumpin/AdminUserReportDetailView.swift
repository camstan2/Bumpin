import SwiftUI

struct AdminUserReportDetailView: View {
    let report: UserReport
    var onResolved: () -> Void
    
    @State private var adminNotes: String = ""
    @State private var selectedAction: UserReportAction = .noAction
    @State private var isSubmitting = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    private let reportingService = ReportingService.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Report")) {
                    HStack {
                        Text("Reason")
                        Spacer()
                        Text(report.reason.displayName)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Reported user")
                        Spacer()
                        Text("@\(report.reportedUsername)")
                            .foregroundColor(.secondary)
                    }
                    if let relatedContentId = report.relatedContentId, !relatedContentId.isEmpty {
                        HStack {
                            Text("Related content")
                            Spacer()
                            Text(relatedContentId)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("Reporter")
                        Spacer()
                        Text(report.reporterUserId)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Timestamp")
                        Spacer()
                        Text(report.timestamp, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Action")) {
                    Picker("Action", selection: $selectedAction) {
                        ForEach(UserReportAction.allCases, id: \.self) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Admin notes (optional)", text: $adminNotes, axis: .vertical)
                }
                
                Section {
                    Button {
                        Task { await resolve() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Resolve")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSubmitting)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("User Report")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func resolve() async {
        await MainActor.run { isSubmitting = true }
        let success = await reportingService.resolveUserReport(reportId: report.id, action: selectedAction, adminNotes: adminNotes.isEmpty ? nil : adminNotes)
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

