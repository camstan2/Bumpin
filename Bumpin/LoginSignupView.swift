//
//  LoginSignupView.swift
//  Bumpin
//
//  Enhanced with Phase 1 security features
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct LoginSignupView: View {
    // MARK: - State Variables
    
    @State private var isSignupMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    
    // Field-specific errors
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    
    // Password visibility
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    // Terms acceptance
    @State private var acceptedTerms = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    
    // Forgot password
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false
    
    // Username validation
    @StateObject private var usernameValidation = UsernameValidationState()
    
    // Social login services
    @StateObject private var appleSignInService = AppleSignInService()
    @StateObject private var googleSignInService = GoogleSignInService()
    
    // Focus state
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword, username, displayName, bio
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo/Title
                    headerSection
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Email field
                        emailField
                        
                        // Password field
                        passwordField
                        
                        // Confirm password (signup only)
                        if isSignupMode {
                            confirmPasswordField
                            
                            // Password strength indicator
                            if !password.isEmpty {
                                PasswordStrengthIndicator(password: password)
                                    .padding(.horizontal, 4)
                            }
                            
                            // Username field
                            usernameField
                            
                            // Display name field
                            displayNameField
                            
                            // Profile picture picker
                            profilePictureSection
                            
                            // Bio field
                            bioField
                            
                            // Terms acceptance
                            termsAcceptanceSection
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Action button
                    actionButton
                    
                    // MARK: - Social Login (Hidden for now - code preserved for future use)
                    // Uncomment these lines to re-enable Apple & Google sign-in
                    /*
                    // Social login divider
                    socialLoginDivider
                    
                    // Social login buttons
                    socialLoginButtons
                    */
                    
                    // Forgot password (login only)
                    if !isSignupMode {
                        Button(action: { showForgotPassword = true }) {
                            Text("Forgot Password?")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Toggle mode button
                    toggleModeButton
                }
                .padding(.vertical, 40)
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside input fields
                hideKeyboard()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
            }
            .sheet(isPresented: $showTermsSheet) {
                WebViewSheet(url: Bundle.main.url(forResource: "terms-of-service", withExtension: "html")!, title: "Terms of Service")
            }
            .sheet(isPresented: $showPrivacySheet) {
                WebViewSheet(url: Bundle.main.url(forResource: "privacy-policy", withExtension: "html")!, title: "Privacy Policy")
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView(isPresented: $showForgotPassword, email: $resetEmail, showSuccess: $showResetSuccess)
            }
            .alert("Password Reset Email Sent", isPresented: $showResetSuccess) {
                Button("OK") { }
            } message: {
                Text("Check your email for instructions to reset your password.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text(isSignupMode ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            
            Text(isSignupMode ? "Join the music community" : "Log in to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusNextField() }
                    .onChange(of: email) { _ in
                        emailError = nil
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(emailError != nil ? Color.red : Color.clear, lineWidth: 1)
            )
            
            if let error = emailError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                if showPassword {
                    TextField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)
                        .submitLabel(isSignupMode ? .next : .go)
                        .onSubmit {
                            if isSignupMode {
                                focusNextField()
                            } else {
                                handleAuth()
                            }
                        }
                        .onChange(of: password) { _ in
                            passwordError = nil
                        }
                } else {
                    SecureField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .password)
                        .submitLabel(isSignupMode ? .next : .go)
                        .onSubmit {
                            if isSignupMode {
                                focusNextField()
                            } else {
                                handleAuth()
                            }
                        }
                        .onChange(of: password) { _ in
                            passwordError = nil
                        }
                }
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(passwordError != nil ? Color.red : Color.clear, lineWidth: 1)
            )
            
            if let error = passwordError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                if showConfirmPassword {
                    TextField("Confirm Password", text: $confirmPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.next)
                        .onSubmit { focusNextField() }
                        .onChange(of: confirmPassword) { _ in
                            confirmPasswordError = nil
                        }
                } else {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.next)
                        .onSubmit { focusNextField() }
                        .onChange(of: confirmPassword) { _ in
                            confirmPasswordError = nil
                        }
                }
                
                Button(action: { showConfirmPassword.toggle() }) {
                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(confirmPasswordError != nil ? Color.red : Color.clear, lineWidth: 1)
            )
            
            // Password match indicator
            if !confirmPassword.isEmpty && confirmPasswordError == nil {
                HStack(spacing: 4) {
                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(passwordsMatch ? .green : .red)
                        .font(.caption)
                    
                    Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                        .font(.caption)
                        .foregroundColor(passwordsMatch ? .green : .red)
                }
                .padding(.horizontal, 4)
            }
            
            if let error = confirmPasswordError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "at")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onChange(of: username) { newValue in
                        usernameValidation.validateUsername(newValue)
                    }
                    .onSubmit { focusNextField() }
                
                // Validation indicator
                if usernameValidation.isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if let result = usernameValidation.validationResult {
                    Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.isValid ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Validation message
            if let result = usernameValidation.validationResult, !result.isValid {
                if let errorMessage = result.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                }
            } else if username.count >= 3 && usernameValidation.validationResult?.isValid == true {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Username is available!")
                        .foregroundColor(.green)
                }
                .font(.caption)
                .padding(.horizontal, 4)
            }
            
            // Helper text
            if username.isEmpty {
                Text("3-20 characters, letters, numbers, and underscores only")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                        TextField("Display Name", text: $displayName)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.next)
                    .onSubmit { focusNextField() }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Text("This is how your name will appear to others")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }
    
    private var profilePictureSection: some View {
        VStack(spacing: 12) {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.purple, lineWidth: 3))
                    .shadow(radius: 4)
                            } else {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(
                                Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 40))
                                    .foregroundColor(.purple.opacity(0.5))
                    )
            }
            
            Button(action: { showImagePicker = true }) {
                HStack {
                    Image(systemName: profileImage == nil ? "photo" : "arrow.triangle.2.circlepath")
                    Text(profileImage == nil ? "Add Profile Picture" : "Change Picture")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            Text("Optional")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var bioField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                    .padding(.top, 12)
                
                TextField("Bio (optional)", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .bio)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Text("Tell others about your music taste")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
    }
    
    private var termsAcceptanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $acceptedTerms) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("I agree to the Terms and Privacy Policy")
                        .font(.subheadline)
                    
                    HStack(spacing: 16) {
                        Button(action: { showTermsSheet = true }) {
                            Text("Terms of Service")
                            .font(.caption)
                                .foregroundColor(.purple)
                                .underline()
                        }
                        
                        Button(action: { showPrivacySheet = true }) {
                            Text("Privacy Policy")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .underline()
                        }
                    }
                }
            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.horizontal, 4)
        }
    }
    
    private var actionButton: some View {
                Button(action: handleAuth) {
            HStack(spacing: 10) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    if !loadingMessage.isEmpty {
                        Text(loadingMessage)
                            .fontWeight(.semibold)
                    }
                } else {
                    Text(isSignupMode ? "Create Account" : "Log In")
                        .fontWeight(.semibold)
                }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            .background(isFormValid ? Color.purple : Color.gray)
                    .cornerRadius(12)
                }
        .disabled(!isFormValid || isLoading)
        .padding(.horizontal, 24)
    }
    
    private var toggleModeButton: some View {
        Button(action: {
            withAnimation {
                isSignupMode.toggle()
                errorMessage = nil
                clearFields()
            }
        }) {
            HStack(spacing: 4) {
                Text(isSignupMode ? "Already have an account?" : "Don't have an account?")
                    .foregroundColor(.secondary)
                Text(isSignupMode ? "Log In" : "Sign Up")
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
    }
    
    // MARK: - Social Login UI
    
    private var socialLoginDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    
    private var socialLoginButtons: some View {
        VStack(spacing: 12) {
            // Apple Sign In
            SignInWithAppleButton {
                handleAppleSignIn()
            }
            .disabled(isLoading || appleSignInService.isLoading || googleSignInService.isLoading)
            .opacity((isLoading || appleSignInService.isLoading || googleSignInService.isLoading) ? 0.6 : 1.0)
            
            // Google Sign In
            SignInWithGoogleButton {
                handleGoogleSignIn()
            }
            .disabled(isLoading || appleSignInService.isLoading || googleSignInService.isLoading)
            .opacity((isLoading || appleSignInService.isLoading || googleSignInService.isLoading) ? 0.6 : 1.0)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        if isSignupMode {
            return !email.isEmpty &&
                   !password.isEmpty &&
                   !confirmPassword.isEmpty &&
                   passwordsMatch &&
                   PasswordValidator.isValid(password) &&
                   !username.isEmpty &&
                   username.count >= 3 &&
                   usernameValidation.validationResult?.isValid == true &&
                   !displayName.isEmpty &&
                   acceptedTerms
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private var passwordsMatch: Bool {
        return password == confirmPassword
    }
    
    // MARK: - Actions
    
    private func focusNextField() {
        switch focusedField {
        case .email:
            focusedField = .password
        case .password:
            if isSignupMode {
                focusedField = .confirmPassword
            }
        case .confirmPassword:
            focusedField = .username
        case .username:
            focusedField = .displayName
        case .displayName:
            focusedField = .bio
        case .bio:
            focusedField = nil
        case .none:
            break
        }
    }
    
    private func clearFields() {
        password = ""
        confirmPassword = ""
        username = ""
        displayName = ""
        bio = ""
        profileImage = nil
        acceptedTerms = false
        usernameValidation.reset()
        
        // Clear field errors
        emailError = nil
        passwordError = nil
        confirmPasswordError = nil
    }
    
    private func handleAuth() {
        errorMessage = nil
        focusedField = nil // Dismiss keyboard
        
        if isSignupMode {
            // Validate password strength
            if let passwordError = PasswordValidator.validationError(password) {
                errorMessage = passwordError
                return
            }
            
            // Validate passwords match
            if !passwordsMatch {
                errorMessage = "Passwords don't match"
                return
            }
            
            // Validate username
            if usernameValidation.validationResult?.isValid != true {
                errorMessage = "Please choose a valid username"
                return
            }
            
            // Validate terms acceptance
            if !acceptedTerms {
                errorMessage = "Please accept the Terms and Privacy Policy"
                return
            }
            
            signUp()
        } else {
            logIn()
        }
    }
    
    private func signUp() {
        isLoading = true
        loadingMessage = "Creating account..."
        
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    isLoading = false
                loadingMessage = ""
                
                let nsError = error as NSError
                switch nsError.code {
                case AuthErrorCode.emailAlreadyInUse.rawValue:
                    emailError = "This email is already registered"
                    errorMessage = "This email is already registered. Try logging in instead."
                case AuthErrorCode.invalidEmail.rawValue:
                    emailError = "Invalid email format"
                    errorMessage = "Please enter a valid email address"
                default:
                    errorMessage = formatFirebaseError(error)
                }
                } else if let user = result?.user {
                loadingMessage = "Sending verification email..."
                
                // Send email verification
                user.sendEmailVerification { error in
                    if let error = error {
                        print("❌ Email verification error: \(error.localizedDescription)")
                    }
                }
                
                // Update display name
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    changeRequest.commitChanges { _ in }
                
                // Upload profile image if provided
                    if let image = profileImage {
                    loadingMessage = "Uploading profile picture..."
                        uploadProfileImage(image, for: user.uid) { url in
                        loadingMessage = "Saving profile..."
                            saveUserProfile(user: user, profileImageUrl: url)
                        }
                    } else {
                    loadingMessage = "Saving profile..."
                        saveUserProfile(user: user, profileImageUrl: nil)
                    }
                }
            }
    }
    
    private func logIn() {
        isLoading = true
        loadingMessage = "Signing in..."
        
        // Determine if input is email or username
        let isEmail = email.contains("@")
        
        if isEmail {
            // Direct login with email
            signInWithEmail(email: email, password: password)
        } else {
            // Username provided - need to look up email first
            loadingMessage = "Looking up account..."
            
            Task {
                do {
                    // Look up email from username
                    guard let foundEmail = try await UsernameValidationService.shared.getEmailFromUsername(email) else {
                        await MainActor.run {
                            isLoading = false
                            loadingMessage = ""
                            emailError = "Username not found"
                            errorMessage = "No account found with this username."
                        }
                        return
                    }
                    
                    // Sign in with found email
                    await MainActor.run {
                        loadingMessage = "Signing in..."
                        signInWithEmail(email: foundEmail, password: password)
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        loadingMessage = ""
                        errorMessage = "Unable to connect. Please try again."
                    }
                }
            }
        }
    }
    
    private func signInWithEmail(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            loadingMessage = ""
            
            if let error = error {
                let nsError = error as NSError
                switch nsError.code {
                case AuthErrorCode.wrongPassword.rawValue:
                    passwordError = "Incorrect password"
                    errorMessage = "Incorrect password. Please try again."
                case AuthErrorCode.userNotFound.rawValue:
                    emailError = "Account not found"
                    errorMessage = "No account found with this email or username."
                case AuthErrorCode.invalidEmail.rawValue:
                    emailError = "Invalid format"
                    errorMessage = "Please enter a valid email or username"
                default:
                    errorMessage = formatFirebaseError(error)
                }
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage, for uid: String, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(nil)
            return
        }
        
        // Use same path as EditProfileView for consistency
        let storageRef = Storage.storage().reference()
            .child("users/\(uid)/profile/profile.jpg")
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Image upload error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Download URL error: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    print("✅ Profile image uploaded successfully during signup")
                    completion(url?.absoluteString)
                }
            }
        }
    }
    
    private func saveUserProfile(user: User, profileImageUrl: String?) {
        let db = Firestore.firestore()
        
        let lowerUsername = username.lowercased()
        db.collection("users")
            .whereField("username_lower", isEqualTo: lowerUsername)
            .getDocuments { snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        isLoading = false
                        loadingMessage = ""
                        errorMessage = "Failed to verify username: \(error.localizedDescription)"
                    }
                    user.delete { _ in }
                    return
                }
                
                if let docs = snapshot?.documents, docs.contains(where: { $0.documentID != user.uid }) {
                    DispatchQueue.main.async {
                        isLoading = false
                        loadingMessage = ""
                        errorMessage = "That username is already taken."
                        usernameValidation.validationResult = .invalid("Username is already taken")
                    }
                    user.delete { _ in }
                    return
                }
                
                let userData: [String: Any] = [
                    "uid": user.uid,
                    "email": user.email ?? "",
                    "username": username,
                    "username_lower": lowerUsername,
                    "displayName": displayName,
                    "displayName_lower": displayName.lowercased(),
                    "bio": bio.isEmpty ? NSNull() : bio,
                    "profilePictureUrl": profileImageUrl ?? NSNull(),
                    "createdAt": FieldValue.serverTimestamp(),
                    "followers": [],
                    "following": [],
                    "isVerified": false,
                    "roles": [],
                    "emailVerified": false,
                    "termsAcceptedAt": FieldValue.serverTimestamp(),
                    "termsVersion": "1.0"
                ]
                
                UsernameDirectoryService.shared.createUserProfile(userId: user.uid,
                                                                  username: username,
                                                                  email: user.email ?? "",
                                                                  userData: userData) { error in
                    DispatchQueue.main.async {
                        isLoading = false
                        loadingMessage = ""
                        
                        if let directoryError = error as? UsernameDirectoryError,
                           directoryError == .usernameTaken {
                            errorMessage = "That username was just taken. Please choose another."
                            usernameValidation.validationResult = .invalid("Username is already taken")
                            user.delete { deleteError in
                                if let deleteError = deleteError {
                                    print("⚠️ Failed to delete incomplete account: \(deleteError.localizedDescription)")
                                }
                            }
                        } else if let error = error {
                            errorMessage = "Failed to save profile: \(error.localizedDescription)"
                            user.delete { deleteError in
                                if let deleteError = deleteError {
                                    print("⚠️ Failed to delete incomplete account: \(deleteError.localizedDescription)")
                                }
                            }
                        } else {
                            print("✅ User profile created with terms acceptance")
                        }
                    }
                }
            }
    }
    
    private func formatFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email is already registered. Try logging in instead."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Please enter a valid email address."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password is too weak. Please use a stronger password."
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please try again."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email. Please sign up."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many attempts. Please try again later."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection."
        default:
            return error.localizedDescription
        }
    }
    
    // MARK: - Social Login Handlers
    
    private func handleAppleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            errorMessage = "Unable to present sign in"
            return
        }
        
        appleSignInService.signIn(presentationAnchor: window) { result in
            Task { @MainActor in
                switch result {
                case .success(let user):
                    print("✅ Apple Sign In successful: \(user.uid)")
                    // User will be automatically logged in via Firebase Auth state change
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleGoogleSignIn() {
        googleSignInService.signIn { result in
            Task { @MainActor in
                switch result {
                case .success(let user):
                    print("✅ Google Sign In successful: \(user.uid)")
                    // User will be automatically logged in via Firebase Auth state change
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(configuration.isOn ? .purple : .secondary)
                
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Binding var isPresented: Bool
    @Binding var email: String
    @Binding var showSuccess: Bool
    
    @State private var resetEmail: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                    .padding(.top, 40)
                
                Text("Reset Password")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Enter your email address and we'll send you instructions to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                TextField("Email", text: $resetEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Button(action: sendResetEmail) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Send Reset Link")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(resetEmail.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(resetEmail.isEmpty || isLoading)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            resetEmail = email
        }
    }
    
    private func sendResetEmail() {
        errorMessage = nil
        isLoading = true
        
        Auth.auth().sendPasswordReset(withEmail: resetEmail) { error in
            isLoading = false
            
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                email = resetEmail
                isPresented = false
                showSuccess = true
            }
        }
    }
}

// MARK: - WebView Sheet

struct WebViewSheet: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            WebView(url: url)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - WebView (UIKit Wrapper)

import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#Preview {
    LoginSignupView()
} 
