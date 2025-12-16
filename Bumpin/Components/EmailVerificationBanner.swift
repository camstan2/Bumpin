import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Email Verification Banner

struct EmailVerificationBanner: View {
    @StateObject private var viewModel = EmailVerificationViewModel()
    @State private var isExpanded = true
    
    var body: some View {
        if viewModel.shouldShowBanner {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge")
                        .font(.title3)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verify Your Email")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if isExpanded {
                            Text("Check your inbox for a verification link")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isExpanded {
                        if viewModel.isResending {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button(action: {
                                viewModel.resendVerificationEmail()
                            }) {
                                Text("Resend")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange)
                                    .cornerRadius(8)
                            }
                            .disabled(viewModel.cooldownRemaining > 0)
                            .opacity(viewModel.cooldownRemaining > 0 ? 0.5 : 1.0)
                        }
                    }
                    
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                
                if isExpanded && viewModel.cooldownRemaining > 0 {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Wait \(viewModel.cooldownRemaining)s before resending")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                }
                
                if let message = viewModel.statusMessage {
                    HStack {
                        Image(systemName: viewModel.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(viewModel.isSuccess ? .green : .red)
                            .font(.caption)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(viewModel.isSuccess ? .green : .red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(viewModel.isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                }
            }
            .onAppear {
                viewModel.startMonitoring()
            }
        }
    }
}

// MARK: - Email Verification View Model

@MainActor
class EmailVerificationViewModel: ObservableObject {
    @Published var shouldShowBanner = false
    @Published var isResending = false
    @Published var statusMessage: String?
    @Published var isSuccess = false
    @Published var cooldownRemaining = 0
    
    private var monitoringTimer: Timer?
    private var cooldownTimer: Timer?
    private var messageTimer: Timer?
    
    init() {
        checkVerificationStatus()
    }
    
    deinit {
        monitoringTimer?.invalidate()
        cooldownTimer?.invalidate()
        messageTimer?.invalidate()
    }
    
    func startMonitoring() {
        // Check every 5 seconds if user has verified their email
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkVerificationStatus()
            }
        }
    }
    
    func checkVerificationStatus() {
        guard let user = Auth.auth().currentUser else {
            shouldShowBanner = false
            return
        }
        
        // Reload user to get latest email verification status
        user.reload { [weak self] error in
            Task { @MainActor in
                if let self = self {
                    self.shouldShowBanner = !(user.isEmailVerified)
                    
                    // If verified, stop monitoring
                    if user.isEmailVerified {
                        self.monitoringTimer?.invalidate()
                        self.updateFirestoreVerificationStatus(verified: true)
                    }
                }
            }
        }
    }
    
    func resendVerificationEmail() {
        guard let user = Auth.auth().currentUser else { return }
        guard cooldownRemaining == 0 else { return }
        
        isResending = true
        statusMessage = nil
        
        user.sendEmailVerification { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.isResending = false
                
                if let error = error {
                    self.statusMessage = "Failed to send email: \(error.localizedDescription)"
                    self.isSuccess = false
                } else {
                    self.statusMessage = "✓ Verification email sent! Check your inbox."
                    self.isSuccess = true
                    self.startCooldown()
                }
                
                // Clear message after 5 seconds
                self.messageTimer?.invalidate()
                self.messageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.statusMessage = nil
                    }
                }
            }
        }
    }
    
    private func startCooldown() {
        cooldownRemaining = 60 // 60 second cooldown
        
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                if self.cooldownRemaining > 0 {
                    self.cooldownRemaining -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
    
    private func updateFirestoreVerificationStatus(verified: Bool) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "emailVerified": verified
        ]) { error in
            if let error = error {
                print("❌ Error updating email verification status: \(error.localizedDescription)")
            } else {
                print("✅ Email verification status updated in Firestore")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        EmailVerificationBanner()
        Spacer()
    }
}

