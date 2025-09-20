import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AdminState: ObservableObject {
    @Published private(set) var isAdmin: Bool = false

    private var listener: ListenerRegistration?

    func start() {
        listener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else {
            isAdmin = false
            return
        }
        listener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let data = snap?.data() else { self?.isAdmin = false; return }
                    self?.isAdmin = (data["isAdmin"] as? Bool) == true
                }
            }
    }

    func stop() {
        listener?.remove(); listener = nil; isAdmin = false
    }
}


