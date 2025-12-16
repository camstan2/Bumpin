import Foundation
import FirebaseFirestore
import FirebaseAuth

enum UsernameDirectoryError: Error {
    case usernameTaken
}

final class UsernameDirectoryService {
    static let shared = UsernameDirectoryService()
    
    private let db = Firestore.firestore()
    private init() {}
    
    func createUserProfile(userId: String,
                           username: String,
                           email: String,
                           userData: [String: Any],
                           completion: @escaping (Error?) -> Void) {
        let lower = username.lowercased()
        let userRef = db.collection("users").document(userId)
        let usernameRef = db.collection("usernameDirectory").document(lower)
        
        db.runTransaction({ transaction, errorPointer in
            do {
                let usernameDoc = try transaction.getDocument(usernameRef)
                if usernameDoc.exists {
                    errorPointer?.pointee = NSError(domain: "UsernameDirectoryError", code: 1, userInfo: nil)
                    return [:]
                }
            } catch {
                errorPointer?.pointee = error as NSError
                return [:]
            }
            
            transaction.setData(userData, forDocument: userRef)
            transaction.setData([
                "userId": userId,
                "username": username,
                "username_lower": lower,
                "email": email,
                "createdAt": FieldValue.serverTimestamp()
            ], forDocument: usernameRef)
            return [:]
        }, completion: { _, error in
            if let nsError = error as NSError?, nsError.domain == "UsernameDirectoryError" {
                completion(UsernameDirectoryError.usernameTaken)
            } else {
                completion(error)
            }
        })
    }
    
    func ensureEntry(for user: User) {
        let userId = user.uid
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { snapshot, error in
            guard error == nil,
                  let data = snapshot?.data(),
                  let username = data["username"] as? String else {
                return
            }
            
            let lower = (data["username_lower"] as? String) ?? username.lowercased()
            let directoryRef = self.db.collection("usernameDirectory").document(lower)
            
            directoryRef.getDocument { directorySnapshot, _ in
                guard directorySnapshot?.exists != true else { return }
                let email = data["email"] as? String ?? user.email ?? ""
                
                directoryRef.setData([
                    "userId": userId,
                    "username": username,
                    "username_lower": lower,
                    "email": email,
                    "createdAt": FieldValue.serverTimestamp()
                ])
            }
        }
    }
    
    func backfillDirectoryIfNeeded() {
        let key = "username_directory_backfilled_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        
        db.collection("users").getDocuments { snapshot, error in
            guard error == nil, let documents = snapshot?.documents else {
                print("⚠️ Failed to backfill username directory: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let group = DispatchGroup()
            
            for doc in documents {
                guard let username = doc.data()["username"] as? String,
                      !username.isEmpty else { continue }
                
                let lower = (doc.data()["username_lower"] as? String) ?? username.lowercased()
                let email = doc.data()["email"] as? String ?? ""
                let ref = self.db.collection("usernameDirectory").document(lower)
                
                group.enter()
                ref.setData([
                    "userId": doc.documentID,
                    "username": username,
                    "username_lower": lower,
                    "email": email,
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true) { _ in
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                UserDefaults.standard.set(true, forKey: key)
                print("✅ Username directory backfill completed")
            }
        }
    }
}


