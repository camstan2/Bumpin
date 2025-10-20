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
        guard let _ = Auth.auth().currentUser else {
            print("🔍 TermsAcceptanceManager.requiresTermsAcceptance: No user, returning false")
            return false
        }
        // Don't show terms screen if we're still checking
        if isCheckingTerms {
            print("🔍 TermsAcceptanceManager.requiresTermsAcceptance: Still checking, returning false")
            return false
        }
        let result = !hasAcceptedTerms
        print("🔍 TermsAcceptanceManager.requiresTermsAcceptance: hasAcceptedTerms=\(hasAcceptedTerms), returning \(result)")
        return result
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
        print("🔍 TermsAcceptanceManager: Starting terms check...")
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ TermsAcceptanceManager: No user logged in")
            hasAcceptedTerms = false
            isCheckingTerms = false
            isLoading = false
            return
        }
        
        print("🔍 TermsAcceptanceManager: Checking terms for user: \(userId)")
        
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            
            print("🔍 TermsAcceptanceManager: Firestore document fetched, exists: \(snapshot.exists)")
            
            if let data = snapshot.data() {
                print("🔍 TermsAcceptanceManager: Document data keys: \(data.keys.joined(separator: ", "))")
                
                if let termsAcceptedAt = data["termsAcceptedAt"] {
                    hasAcceptedTerms = true
                    print("✅ TermsAcceptanceManager: User HAS accepted terms at: \(termsAcceptedAt)")
                } else {
                    hasAcceptedTerms = false
                    print("⚠️ TermsAcceptanceManager: User has NOT accepted terms (field missing)")
                }
            } else {
                hasAcceptedTerms = false
                print("⚠️ TermsAcceptanceManager: User document has no data")
            }
        } catch {
            print("❌ TermsAcceptanceManager: Error checking terms: \(error.localizedDescription)")
            // On error, assume not accepted to be safe
            hasAcceptedTerms = false
        }
        
        isCheckingTerms = false
        isLoading = false
        print("🔍 TermsAcceptanceManager: Check complete. hasAcceptedTerms: \(hasAcceptedTerms), isCheckingTerms: \(isCheckingTerms)")
    }
}
