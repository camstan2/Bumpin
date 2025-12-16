import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Username Validation Service

class UsernameValidationService {
    static let shared = UsernameValidationService()
    private let db = Firestore.firestore()
    
    // Reserved usernames that users cannot register
    private let reservedUsernames = [
        "admin", "administrator", "mod", "moderator", "bumpin", "support",
        "help", "official", "team", "staff", "root", "system", "null",
        "undefined", "anonymous", "guest", "user", "account", "settings",
        "profile", "home", "discover", "search", "notifications", "messages",
        "login", "signup", "signout", "logout", "api", "www", "app"
    ]
    
    private init() {}
    
    // MARK: - Validation Methods
    
    /// Check if username format is valid
    func isValidFormat(_ username: String) -> Bool {
        // Length check: 3-20 characters
        guard username.count >= 3 && username.count <= 20 else {
            return false
        }
        
        // Format check: alphanumeric and underscores only
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        
        return usernamePredicate.evaluate(with: username)
    }
    
    /// Get validation error message for format
    func formatValidationError(_ username: String) -> String? {
        if username.isEmpty {
            return "Username is required"
        }
        
        if username.count < 3 {
            return "Username must be at least 3 characters"
        }
        
        if username.count > 20 {
            return "Username must be 20 characters or less"
        }
        
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        
        if !usernamePredicate.evaluate(with: username) {
            return "Username can only contain letters, numbers, and underscores"
        }
        
        return nil
    }
    
    /// Check if username is reserved
    func isReserved(_ username: String) -> Bool {
        return reservedUsernames.contains(username.lowercased())
    }
    
    /// Check if username is available by querying Firestore (public rules allow limited unauth queries)
    func checkAvailability(_ username: String) async throws -> Bool {
        let lowercasedUsername = username.lowercased()
        // Reserved
        if isReserved(lowercasedUsername) { return false }
        
        let snapshot = try await db.collection("usernameDirectory")
            .document(lowercasedUsername)
            .getDocument()
        return snapshot.exists == false
    }
    
    /// Comprehensive validation with detailed result
    func validate(_ username: String) async -> UsernameValidationResult {
        // Format validation
        if let formatError = formatValidationError(username) {
            return .invalid(formatError)
        }
        
        // Reserved check
        if isReserved(username) {
            return .invalid("This username is reserved")
        }
        
        // Availability check
        do {
            let isAvailable = try await checkAvailability(username)
            if isAvailable {
                return .valid
            } else {
                return .invalid("Username is already taken")
            }
        } catch {
            print("❌ Username validation error: \(error.localizedDescription)")
            return .error("Could not verify username availability")
        }
    }
    
    // MARK: - Username to Email Lookup
    
    /// Get email address from username (for login purposes)
    func getEmailFromUsername(_ username: String) async throws -> String? {
        let lowercasedUsername = username.lowercased()
        
        let document = try await db.collection("usernameDirectory")
            .document(lowercasedUsername)
            .getDocument()
        
        guard let data = document.data(),
              let email = data["email"] as? String else {
            return nil
        }
        
        return email
    }
}

// MARK: - Validation Result

enum UsernameValidationResult {
    case valid
    case invalid(String)
    case error(String)
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message), .error(let message):
            return message
        }
    }
}

// MARK: - Username Validation State (for SwiftUI)

@MainActor
class UsernameValidationState: ObservableObject {
    @Published var username: String = ""
    @Published var validationResult: UsernameValidationResult?
    @Published var isValidating: Bool = false
    
    private var validationTask: Task<Void, Never>?
    
    func validateUsername(_ username: String) {
        self.username = username
        
        // Cancel previous validation
        validationTask?.cancel()
        
        // Reset state
        validationResult = nil
        
        // Don't validate if username is too short
        guard username.count >= 3 else {
            return
        }
        
        isValidating = true
        
        // Debounce validation (wait 500ms after user stops typing)
        validationTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            guard !Task.isCancelled else { return }
            
            let result = await UsernameValidationService.shared.validate(username)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.validationResult = result
                self.isValidating = false
            }
        }
    }
    
    func reset() {
        validationTask?.cancel()
        username = ""
        validationResult = nil
        isValidating = false
    }
}

