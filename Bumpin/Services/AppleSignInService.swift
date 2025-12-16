import Foundation
import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

// MARK: - Apple Sign In Service

@MainActor
class AppleSignInService: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentNonce: String?
    private var completionHandler: ((Result<User, Error>) -> Void)?
    
    // MARK: - Public Methods
    
    func signIn(presentationAnchor: ASPresentationAnchor, completion: @escaping (Result<User, Error>) -> Void) {
        self.completionHandler = completion
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to fetch identity token"
            completionHandler?(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])))
            return
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        isLoading = true
        
        // Sign in with Firebase
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.completionHandler?(.failure(error))
                    return
                }
                
                guard let user = authResult?.user else {
                    let error = NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])
                    self.errorMessage = "User not found"
                    self.completionHandler?(.failure(error))
                    return
                }
                
                // Check if this is a new user
                let isNewUser = authResult?.additionalUserInfo?.isNewUser ?? false
                
                if isNewUser {
                    // Create user profile in Firestore
                    self.createUserProfile(
                        user: user,
                        fullName: appleIDCredential.fullName,
                        email: appleIDCredential.email
                    )
                }
                
                self.completionHandler?(.success(user))
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        
        let authError = error as NSError
        
        // Don't show error if user cancelled
        if authError.code == ASAuthorizationError.canceled.rawValue {
            print("⚠️ Apple Sign In cancelled by user")
            return
        }
        
        errorMessage = error.localizedDescription
        completionHandler?(.failure(error))
    }
    
    private func createUserProfile(user: User, fullName: PersonNameComponents?, email: String?) {
        // Get display name from Apple or use email
        var displayName = ""
        if let fullName = fullName {
            let firstName = fullName.givenName ?? ""
            let lastName = fullName.familyName ?? ""
            displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        }
        
        if displayName.isEmpty {
            displayName = email?.components(separatedBy: "@").first ?? "Apple User"
        }
        
        let baseUsername = email?.components(separatedBy: "@").first ?? String(user.uid.prefix(8))
        attemptCreateUserProfile(user: user,
                                 email: email ?? "",
                                 displayName: displayName,
                                 baseUsername: baseUsername.lowercased(),
                                 attempt: 0)
    }
    
    private func attemptCreateUserProfile(user: User,
                                          email: String,
                                          displayName: String,
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
            "profilePictureUrl": NSNull(),
            "createdAt": FieldValue.serverTimestamp(),
            "followers": [],
            "following": [],
            "isVerified": false,
            "roles": [],
            "emailVerified": true,
            "authProvider": "apple",
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
                self.attemptCreateUserProfile(user: user,
                                              email: email,
                                              displayName: displayName,
                                              baseUsername: baseUsername,
                                              attempt: attempt + 1)
            } else if let error = error {
                print("❌ Error creating user profile: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create your profile. Please try again."
                    self.isLoading = false
                }
            } else {
                print("✅ User profile created successfully")
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}

// MARK: - SwiftUI Button Wrapper

struct SignInWithAppleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("Continue with Apple")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .cornerRadius(12)
        }
    }
}

