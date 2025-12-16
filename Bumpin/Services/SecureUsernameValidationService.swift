// SECURE Username Validation Service
import FirebaseFirestore

class SecureUsernameValidationService {
    private let db = Firestore.firestore()
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let lowercasedUsername = username.lowercased()
        
        // ✅ SECURE: Query username availability
        let snapshot = try await db.collection("users")
            .whereField("username_lower", isEqualTo: lowercasedUsername)
            .limit(to: 1)
            .getDocuments()
        
        return snapshot.documents.isEmpty
    }
    
    func getEmailFromUsername(_ username: String) async throws -> String? {
        let lowercasedUsername = username.lowercased()
        
        // ✅ SECURE: Query email by username for login
        let snapshot = try await db.collection("users")
            .whereField("username_lower", isEqualTo: lowercasedUsername)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first,
              let email = document.data()["email"] as? String else {
            return nil
        }
        
        return email
    }
}
