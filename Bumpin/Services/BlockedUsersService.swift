import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Manages blocked users functionality
@MainActor
class BlockedUsersService: ObservableObject {
    static let shared = BlockedUsersService()
    
    @Published var blockedUsers: [BlockedUser] = []
    @Published var isLoading: Bool = false
    
    private let db = Firestore.firestore()
    
    struct BlockedUser: Identifiable {
        let id: String // User ID
        let displayName: String
        let profilePictureURL: String?
        let blockedAt: Date
    }
    
    private init() {
        Task {
            await loadBlockedUsers()
        }
    }
    
    // MARK: - Load Blocked Users
    
    func loadBlockedUsers() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data(),
                  let blockedUserIds = data["blockedUsers"] as? [String] else {
                await MainActor.run {
                    self.blockedUsers = []
                }
                return
            }
            
            // Fetch user details for blocked users
            var users: [BlockedUser] = []
            
            for userId in blockedUserIds {
                do {
                    let userDoc = try await db.collection("users").document(userId).getDocument()
                    if let userData = userDoc.data() {
                        let blockedUser = BlockedUser(
                            id: userId,
                            displayName: userData["displayName"] as? String ?? "Unknown User",
                            profilePictureURL: userData["profilePictureURL"] as? String,
                            blockedAt: (userData["blockedAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                        users.append(blockedUser)
                    }
                } catch {
                    print("❌ Error fetching blocked user \(userId): \(error)")
                }
            }
            
            await MainActor.run {
                self.blockedUsers = users.sorted { $0.blockedAt > $1.blockedAt }
            }
            
            print("✅ Loaded \(users.count) blocked users")
        } catch {
            print("❌ Error loading blocked users: \(error)")
        }
    }
    
    // MARK: - Block User
    
    func blockUser(_ userId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(uid).updateData([
                "blockedUsers": FieldValue.arrayUnion([userId])
            ])
            
            print("✅ Blocked user: \(userId)")
            await loadBlockedUsers()
        } catch {
            print("❌ Error blocking user: \(error)")
        }
    }
    
    // MARK: - Unblock User
    
    func unblockUser(_ userId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(uid).updateData([
                "blockedUsers": FieldValue.arrayRemove([userId])
            ])
            
            print("✅ Unblocked user: \(userId)")
            await loadBlockedUsers()
        } catch {
            print("❌ Error unblocking user: \(error)")
        }
    }
    
    // MARK: - Check if User is Blocked
    
    func isUserBlocked(_ userId: String) -> Bool {
        return blockedUsers.contains { $0.id == userId }
    }
}

