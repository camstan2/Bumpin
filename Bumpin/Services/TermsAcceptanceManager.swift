import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class TermsAcceptanceManager: ObservableObject {
    @Published var hasAcceptedTerms: Bool = false
    @Published var isLoading: Bool = true // Start as loading
    @Published var isCheckingTerms: Bool = true // Track if we're still checking
    
    private let db = Firestore.firestore()
    
    init() {
        Task {
            await checkTermsAcceptance()
        }
    }
    
    func requiresTermsAcceptance() -> Bool {
        guard let _ = Auth.auth().currentUser else { return false }
        // Don't show terms screen if we're still checking
        if isCheckingTerms {
            return false
        }
        return !hasAcceptedTerms
    }
    
    func acceptTerms() async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            return false
        }
        
        isLoading = true
        
        do {
            try await db.collection("users").document(userId).updateData([
                "termsAcceptedAt": FieldValue.serverTimestamp(),
                "termsVersion": "1.0"
            ])
            
            hasAcceptedTerms = true
            isCheckingTerms = false
            isLoading = false
            print("✅ Terms acceptance recorded successfully")
            return true
        } catch {
            print("❌ Failed to record terms acceptance: \(error)")
            isLoading = false
            return false
        }
    }
    
    private func checkTermsAcceptance() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            hasAcceptedTerms = false
            isCheckingTerms = false
            isLoading = false
            return
        }
        
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            
            if let data = snapshot.data(),
               let _ = data["termsAcceptedAt"] {
                hasAcceptedTerms = true
                print("✅ User has accepted terms")
            } else {
                hasAcceptedTerms = false
                print("⚠️ User has NOT accepted terms")
            }
        } catch {
            print("❌ Error checking terms acceptance: \(error)")
            // On error, assume not accepted to be safe
            hasAcceptedTerms = false
        }
        
        isCheckingTerms = false
        isLoading = false
    }
}
