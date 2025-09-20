import Foundation
import FirebaseFirestore
import FirebaseAuth

final class UserPreferencesService {
    static let shared = UserPreferencesService()
    private init() {}
    private let db = Firestore.firestore()
    private(set) var hiddenUserIds: Set<String> = []

    func loadHiddenUsers() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            if let arr = snap.data()? ["hiddenUsers"] as? [String] {
                hiddenUserIds = Set(arr)
            } else {
                hiddenUserIds = []
            }
        } catch {
            hiddenUserIds = []
        }
    }

    @discardableResult
    func hideUser(_ userId: String) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid, userId != uid else { return false }
        do {
            try await db.collection("users").document(uid).updateData([
                "hiddenUsers": FieldValue.arrayUnion([userId])
            ])
            hiddenUserIds.insert(userId)
            return true
        } catch {
            // If field doesn't exist, set it
            do {
                try await db.collection("users").document(uid).setData(["hiddenUsers": [userId]], merge: true)
                hiddenUserIds.insert(userId)
                return true
            } catch {
                return false
            }
        }
    }

    @discardableResult
    func unhideUser(_ userId: String) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        do {
            try await db.collection("users").document(uid).updateData([
                "hiddenUsers": FieldValue.arrayRemove([userId])
            ])
            hiddenUserIds.remove(userId)
            return true
        } catch {
            // If missing doc/field, treat as success locally
            hiddenUserIds.remove(userId)
            return false
        }
    }
}


