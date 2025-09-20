import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class TermsAcceptanceManager: ObservableObject {
    @Published var hasAcceptedTerms: Bool = false
    @Published var isLoading: Bool = false
    
    private let db = Firestore.firestore()
    
    init() {
        checkTermsAcceptance()
    }
    
    func requiresTermsAcceptance() -> Bool {
        guard let _ = Auth.auth().currentUser else { return false }
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
            isLoading = false
            return true
        } catch {
            print("❌ Failed to record terms acceptance: \(error)")
            isLoading = false
            return false
        }
    }
    
    private func checkTermsAcceptance() {
        guard let userId = Auth.auth().currentUser?.uid else {
            hasAcceptedTerms = false
            return
        }
        
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                if let data = snapshot?.data(),
                   let _ = data["termsAcceptedAt"] {
                    self?.hasAcceptedTerms = true
                } else {
                    self?.hasAcceptedTerms = false
                }
            }
        }
    }
}
