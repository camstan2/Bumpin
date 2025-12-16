import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
// import GoogleSignIn // ⚠️ UNCOMMENT AFTER INSTALLING Google Sign-In SDK via SPM

// MARK: - Google Sign In Service
// ⚠️ THIS SERVICE REQUIRES GoogleSignIn SDK TO BE INSTALLED
// Install via: File → Add Package Dependencies → https://github.com/google/GoogleSignIn-iOS

@MainActor
class GoogleSignInService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Public Methods
    
    func signIn(completion: @escaping (Result<User, Error>) -> Void) {
        // ⚠️ TEMPORARILY DISABLED - Install GoogleSignIn SDK first
        let error = NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In SDK not installed. Please install via Swift Package Manager."])
        errorMessage = "Google Sign In not available"
        completion(.failure(error))
        
        /* UNCOMMENT AFTER INSTALLING GoogleSignIn SDK:
        
        // Get the client ID from Firebase
        guard let clientID = Auth.auth().app?.options.clientID else {
            let error = NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing client ID"])
            errorMessage = "Google Sign In not configured"
            completion(.failure(error))
            return
        }
        
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            let error = NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
            errorMessage = "Unable to present sign in"
            completion(.failure(error))
            return
        }
        
        // Create Google Sign In configuration
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        isLoading = true
        
        // Start the sign in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                if let error = error {
                    // Don't show error if user cancelled
                    let nsError = error as NSError
                    if nsError.code == -5 { // GIDSignInErrorCode.canceled
                        print("⚠️ Google Sign In cancelled by user")
                        return
                    }
                    
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    let error = NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing ID token"])
                    self.errorMessage = "Unable to get user information"
                    completion(.failure(error))
                    return
                }
                
                let accessToken = user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                
                // Sign in with Firebase
                self.signInWithFirebase(credential: credential, user: user, completion: completion)
            }
        }
        
        */ // END OF COMMENTED CODE
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        // GIDSignIn.sharedInstance.signOut() // UNCOMMENT after SDK installed
    }
    
    // MARK: - Private Methods
    
    /* UNCOMMENT AFTER INSTALLING GoogleSignIn SDK:
    
    private func signInWithFirebase(credential: AuthCredential, user: GIDGoogleUser, completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    let error = NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
                    self.errorMessage = "User not found"
                    completion(.failure(error))
                    return
                }
                
                // Check if this is a new user
                let isNewUser = authResult?.additionalUserInfo?.isNewUser ?? false
                
                if isNewUser {
                    // Create user profile in Firestore
                    self.createUserProfile(
                        firebaseUser: firebaseUser,
                        googleUser: user
                    )
                }
                
                completion(.success(firebaseUser))
            }
        }
    }
    
    private func createUserProfile(firebaseUser: User, googleUser: GIDGoogleUser) {
        let profile = googleUser.profile
        let displayName = profile?.name ?? googleUser.profile?.email ?? "Google User"
        let email = profile?.email ?? ""
        let photoURL = profile?.imageURL(withDimension: 400)?.absoluteString
        
        let baseUsername = email.components(separatedBy: "@").first?.lowercased() ?? String(firebaseUser.uid.prefix(8))
        attemptCreateGoogleProfile(user: firebaseUser,
                                   email: email,
                                   displayName: displayName,
                                   photoURL: photoURL,
                                   baseUsername: baseUsername,
                                   attempt: 0)
    }
    
    private func attemptCreateGoogleProfile(user: User,
                                            email: String,
                                            displayName: String,
                                            photoURL: String?,
                                            baseUsername: String,
                                            attempt: Int) {
        let suffix = attempt == 0 ? "" : "\(Int.random(in: 100...999))"
        let candidate = (baseUsername + suffix).lowercased()
        let userData: [String: Any] = [
            "uid": user.uid,
            "email": email,
            "username": candidate,
            "username_lower": candidate,
            "displayName": displayName,
            "displayName_lower": displayName.lowercased(),
            "bio": NSNull(),
            "profilePictureUrl": photoURL ?? NSNull(),
            "createdAt": FieldValue.serverTimestamp(),
            "followers": [],
            "following": [],
            "isVerified": false,
            "roles": [],
            "emailVerified": true,
            "authProvider": "google",
            "termsAcceptedAt": FieldValue.serverTimestamp(),
            "termsVersion": "1.0"
        ]
        
        UsernameDirectoryService.shared.createUserProfile(userId: user.uid,
                                                          username: candidate,
                                                          email: email,
                                                          userData: userData) { error in
            if let directoryError = error as? UsernameDirectoryError,
               directoryError == .usernameTaken,
               attempt < 5 {
                self.attemptCreateGoogleProfile(user: user,
                                                email: email,
                                                displayName: displayName,
                                                photoURL: photoURL,
                                                baseUsername: baseUsername,
                                                attempt: attempt + 1)
            } else if let error = error {
                print("❌ Error creating user profile: \(error.localizedDescription)")
            } else {
                print("✅ User profile created successfully")
            }
        }
    }
    
    */ // END OF COMMENTED CODE
}

// MARK: - SwiftUI Button Wrapper

struct SignInWithGoogleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Using SF Symbol instead of custom logo
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.red)
                
                Text("Continue with Google")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

