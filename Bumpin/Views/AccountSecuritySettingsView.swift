import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AccountSecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showChangePassword = false
    @State private var showDeleteAccount = false
    @State private var userEmail: String = ""
    @StateObject private var emailVerificationVM = EmailVerificationViewModel()
    
    var body: some View {
        List {
            // Email Section
            Section(header: Text("Account Information")) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(userEmail)
                            .font(.body)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // Email Verification Section
            if emailVerificationVM.shouldShowBanner {
                Section(header: Text("Email Verification")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "envelope.badge")
                                .foregroundColor(.orange)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Verify Your Email")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("Check your inbox for a verification link")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if emailVerificationVM.isResending {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button(action: {
                                    emailVerificationVM.resendVerificationEmail()
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
                                .disabled(emailVerificationVM.cooldownRemaining > 0)
                                .opacity(emailVerificationVM.cooldownRemaining > 0 ? 0.5 : 1.0)
                            }
                        }
                        
                        if emailVerificationVM.cooldownRemaining > 0 {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Wait \(emailVerificationVM.cooldownRemaining)s before resending")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let message = emailVerificationVM.statusMessage {
                            HStack {
                                Image(systemName: emailVerificationVM.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(emailVerificationVM.isSuccess ? .green : .red)
                                    .font(.caption)
                                
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(emailVerificationVM.isSuccess ? .green : .red)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Password Section
            Section(header: Text("Security")) {
                Button(action: { showChangePassword = true }) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Change Password")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("Update your account password")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Delete Account Section
            Section(
                header: Text("Danger Zone"),
                footer: Text("Deleting your account is permanent and cannot be undone. All your data will be permanently deleted.")
            ) {
                Button(action: { showDeleteAccount = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Account")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Text("Permanently delete your account")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Account & Security")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            userEmail = Auth.auth().currentUser?.email ?? "No email"
            emailVerificationVM.startMonitoring()
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView()
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Password")) {
                    SecureField("Enter current password", text: $currentPassword)
                        .textContentType(.password)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("New Password")) {
                    SecureField("Enter new password", text: $newPassword)
                        .textContentType(.newPassword)
                        .autocapitalization(.none)
                    
                    SecureField("Confirm new password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .autocapitalization(.none)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: { Task { await changePassword() } }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Change Password")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your password has been changed successfully.")
            }
        }
    }
    
    private func changePassword() async {
        errorMessage = nil
        
        // Validation
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match"
            return
        }
        
        guard newPassword.count >= 6 else {
            errorMessage = "New password must be at least 6 characters"
            return
        }
        
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "User not found"
            return
        }
        
        isLoading = true
        
        do {
            // Re-authenticate user
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            
            // Update password
            try await user.updatePassword(to: newPassword)
            
            await MainActor.run {
                isLoading = false
                showSuccess = true
            }
            
            print("✅ Password changed successfully")
        } catch let error as NSError {
            await MainActor.run {
                isLoading = false
                
                switch error.code {
                case AuthErrorCode.wrongPassword.rawValue:
                    errorMessage = "Current password is incorrect"
                case AuthErrorCode.weakPassword.rawValue:
                    errorMessage = "New password is too weak"
                case AuthErrorCode.requiresRecentLogin.rawValue:
                    errorMessage = "Please sign in again and try"
                default:
                    errorMessage = "Error: \(error.localizedDescription)"
                }
            }
            
            print("❌ Password change failed: \(error)")
        }
    }
}

// MARK: - Delete Account View

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password: String = ""
    @State private var confirmationText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showFinalConfirmation: Bool = false
    
    private let requiredText = "DELETE"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("⚠️ Warning")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This action cannot be undone!")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("Deleting your account will:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Permanently delete all your music logs", systemImage: "checkmark.circle.fill")
                            Label("Remove all your ratings and reviews", systemImage: "checkmark.circle.fill")
                            Label("Delete your profile and account data", systemImage: "checkmark.circle.fill")
                            Label("Remove you from all conversations", systemImage: "checkmark.circle.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Confirmation")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type \"\(requiredText)\" to confirm:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Type DELETE", text: $confirmationText)
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                    }
                    
                    SecureField("Enter your password", text: $password)
                        .textContentType(.password)
                        .autocapitalization(.none)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: { showFinalConfirmation = true }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Delete My Account")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading || password.isEmpty || confirmationText != requiredText)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Final Confirmation", isPresented: $showFinalConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Forever", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("Are you absolutely sure? This cannot be undone and all your data will be permanently deleted.")
            }
        }
    }
    
    private func deleteAccount() async {
        errorMessage = nil
        
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            errorMessage = "User not found"
            return
        }
        
        isLoading = true
        
        do {
            // Re-authenticate user
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            
            // Delete Firestore data
            try await Firestore.firestore()
                .collection("users")
                .document(user.uid)
                .delete()
            
            // Delete user account
            try await user.delete()
            
            print("✅ Account deleted successfully")
            
            // User will be automatically signed out and redirected to login
        } catch let error as NSError {
            await MainActor.run {
                isLoading = false
                
                switch error.code {
                case AuthErrorCode.wrongPassword.rawValue:
                    errorMessage = "Password is incorrect"
                case AuthErrorCode.requiresRecentLogin.rawValue:
                    errorMessage = "Please sign in again and try"
                default:
                    errorMessage = "Error: \(error.localizedDescription)"
                }
            }
            
            print("❌ Account deletion failed: \(error)")
        }
    }
}

