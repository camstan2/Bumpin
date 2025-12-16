import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Blocking Service

@MainActor
class BlockingService: ObservableObject {
    static let shared = BlockingService()
    
    private let db = Firestore.firestore()
    @Published var blockedUsers: Set<String> = []
    @Published var usersWhoBlockedMe: Set<String> = []
    
    private var blockedUsersListener: ListenerRegistration?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentListenerUserId: String?
    
    init() {
        setupAuthStateListener()
        setupBlockedUsersListener()
    }
    
    deinit {
        blockedUsersListener?.remove()
        if let authListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }
    
    /// Listen for auth state changes and refresh the listener when user changes
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let newUserId = user?.uid
                
                // Only refresh if the user actually changed
                if self.currentListenerUserId != newUserId {
                    print("🔄 [BlockingService] Auth state changed, refreshing listener for user: \(newUserId ?? "nil")")
                    self.refreshListener()
                }
            }
        }
    }
    
    /// Refresh the listener - call this when user logs in/out
    func refreshListener() {
        // Remove old listener
        blockedUsersListener?.remove()
        blockedUsersListener = nil
        
        // Clear current data
        blockedUsers.removeAll()
        usersWhoBlockedMe.removeAll()
        currentListenerUserId = nil
        
        // Setup new listener for current user
        setupBlockedUsersListener()
    }
    
    // MARK: - Block/Unblock Users
    
    func blockUser(userId: String, username: String, reason: BlockReason? = nil) async -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated")
            return false
        }
        
        // Prevent self-blocking
        if currentUserId == userId {
            print("❌ Cannot block yourself")
            return false
        }
        
        // If already blocked locally, still return success (idempotent operation)
        if blockedUsers.contains(userId) {
            print("ℹ️ User is already blocked locally - returning success")
            return true
        }
        
        let blockRecord = BlockRecord(
            id: UUID().uuidString,
            blockerUserId: currentUserId,
            blockedUserId: userId,
            blockedUsername: username,
            reason: reason,
            timestamp: Date()
        )
        
        // MARK: - Core blocking operations (must succeed)
        do {
            // Add to blocks collection
            try await db.collection("userBlocks").document(blockRecord.id).setData(from: blockRecord)
            print("✅ Added block record to userBlocks collection")
            
            // Update user's blocked list - THIS is the core operation
            try await db.collection("users").document(currentUserId).updateData([
                "blockedUsers": FieldValue.arrayUnion([userId])
            ])
            print("✅ Updated current user's blockedUsers array")
            
            // Update local state immediately after core operations succeed
            blockedUsers.insert(userId)
            
        } catch {
            print("❌ Failed core block operation: \(error)")
            return false
        }
        
        // MARK: - Secondary operations (best effort, don't fail the block)
        
        // Update blocked user's blockedBy list (may fail due to permissions, that's OK)
        do {
            try await db.collection("users").document(userId).updateData([
                "blockedBy": FieldValue.arrayUnion([currentUserId])
            ])
            print("✅ Updated blocked user's blockedBy array")
        } catch {
            print("⚠️ Could not update blockedBy on other user (non-fatal): \(error)")
        }
        
        // Automatically unfollow both ways (best effort)
        await unfollowBothWays(currentUserId: currentUserId, blockedUserId: userId)
        
        // Log analytics
        AnalyticsService.shared.logEvent("user_blocked", parameters: [
            "blocked_user_id": userId,
            "reason": reason?.rawValue ?? "none"
        ])
        
        print("✅ User blocked successfully")
        return true
    }
    
    /// Remove follow relationships in both directions when blocking
    private func unfollowBothWays(currentUserId: String, blockedUserId: String) async {
        do {
            // 1. Remove blockedUser from currentUser's following list
            try await db.collection("users").document(currentUserId).updateData([
                "following": FieldValue.arrayRemove([blockedUserId])
            ])
            
            // 2. Remove currentUser from blockedUser's followers list
            try await db.collection("users").document(blockedUserId).updateData([
                "followers": FieldValue.arrayRemove([currentUserId])
            ])
            
            // 3. Remove currentUser from blockedUser's following list (reverse direction)
            try await db.collection("users").document(blockedUserId).updateData([
                "following": FieldValue.arrayRemove([currentUserId])
            ])
            
            // 4. Remove blockedUser from currentUser's followers list (reverse direction)
            try await db.collection("users").document(currentUserId).updateData([
                "followers": FieldValue.arrayRemove([blockedUserId])
            ])
            
            // 5. Also delete from the subcollections if they exist
            // Delete from currentUser's following subcollection
            try? await db.collection("users").document(currentUserId)
                .collection("following").document(blockedUserId).delete()
            
            // Delete from blockedUser's followers subcollection
            try? await db.collection("users").document(blockedUserId)
                .collection("followers").document(currentUserId).delete()
            
            // Delete from blockedUser's following subcollection
            try? await db.collection("users").document(blockedUserId)
                .collection("following").document(currentUserId).delete()
            
            // Delete from currentUser's followers subcollection
            try? await db.collection("users").document(currentUserId)
                .collection("followers").document(blockedUserId).delete()
            
            print("✅ Unfollowed both ways after blocking")
            
        } catch {
            print("⚠️ Error unfollowing during block (non-fatal): \(error)")
            // Don't fail the block operation if unfollow fails
        }
    }
    
    func unblockUser(userId: String) async -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated")
            return false
        }
        
        // Check if actually blocked
        if !blockedUsers.contains(userId) {
            print("❌ User is not blocked")
            return false
        }
        
        do {
            // Remove from user's blocked list
            try await db.collection("users").document(currentUserId).updateData([
                "blockedUsers": FieldValue.arrayRemove([userId])
            ])
            
            // Remove from blocked user's blockedBy list
            try await db.collection("users").document(userId).updateData([
                "blockedBy": FieldValue.arrayRemove([currentUserId])
            ])
            
            // Find and delete the block record
            let blockQuery = db.collection("userBlocks")
                .whereField("blockerUserId", isEqualTo: currentUserId)
                .whereField("blockedUserId", isEqualTo: userId)
            
            let snapshot = try await blockQuery.getDocuments()
            for document in snapshot.documents {
                try await document.reference.delete()
            }
            
            // Update local state
            blockedUsers.remove(userId)
            
            // Log analytics
            AnalyticsService.shared.logEvent("user_unblocked", parameters: [
                "unblocked_user_id": userId
            ])
            
            print("✅ User unblocked successfully")
            return true
            
        } catch {
            print("❌ Failed to unblock user: \(error)")
            return false
        }
    }
    
    // MARK: - Check Block Status
    
    func isUserBlocked(_ userId: String) -> Bool {
        return blockedUsers.contains(userId)
    }
    
    func hasUserBlockedMe(_ userId: String) -> Bool {
        return usersWhoBlockedMe.contains(userId)
    }
    
    /// More reliable check that verifies against the authoritative source (the other user's blockedUsers array)
    /// Use this when you need to be certain about block status and can afford an async call
    func hasUserBlockedMeAsync(_ userId: String) async -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        
        // First check local cache for quick response
        if !usersWhoBlockedMe.contains(userId) {
            return false
        }
        
        // Verify against the authoritative source: the other user's blockedUsers array
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let blockedUsers = userDoc.data()?["blockedUsers"] as? [String] ?? []
            
            let actuallyBlocked = blockedUsers.contains(currentUserId)
            
            // If our cache says we're blocked but the source says we're not, repair the cache
            if !actuallyBlocked && usersWhoBlockedMe.contains(userId) {
                print("⚠️ [BlockingService] Stale blockedBy data detected - repairing for user: \(userId)")
                
                // Remove stale entry from current user's blockedBy array
                try? await db.collection("users").document(currentUserId).updateData([
                    "blockedBy": FieldValue.arrayRemove([userId])
                ])
                
                // Update local state
                await MainActor.run {
                    self.usersWhoBlockedMe.remove(userId)
                }
                
                print("✅ [BlockingService] Repaired stale blockedBy entry")
            }
            
            return actuallyBlocked
        } catch {
            print("❌ [BlockingService] Error verifying block status: \(error)")
            // Fall back to cached value on error
            return usersWhoBlockedMe.contains(userId)
        }
    }
    
    func canInteractWithUser(_ userId: String) -> Bool {
        return !isUserBlocked(userId) && !hasUserBlockedMe(userId)
    }
    
    // MARK: - Get Blocked Users
    
    func getBlockedUsers() async -> [BlockedUserInfo] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }
        
        do {
            let snapshot = try await db.collection("userBlocks")
                .whereField("blockerUserId", isEqualTo: currentUserId)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            var blockedUserInfos: [BlockedUserInfo] = []
            
            for document in snapshot.documents {
                if let blockRecord = try? document.data(as: BlockRecord.self) {
                    // Fetch user profile info
                    let userDoc = try await db.collection("users").document(blockRecord.blockedUserId).getDocument()
                    let userData = userDoc.data() ?? [:]
                    
                    let blockedUserInfo = BlockedUserInfo(
                        userId: blockRecord.blockedUserId,
                        username: blockRecord.blockedUsername,
                        profilePictureUrl: userData["profilePictureUrl"] as? String,
                        reason: blockRecord.reason,
                        blockedAt: blockRecord.timestamp
                    )
                    
                    blockedUserInfos.append(blockedUserInfo)
                }
            }
            
            return blockedUserInfos
            
        } catch {
            print("❌ Failed to fetch blocked users: \(error)")
            return []
        }
    }
    
    // MARK: - Content Filtering
    
    func filterBlockedContent<T: Identifiable>(content: [T], getUserId: (T) -> String) -> [T] {
        return content.filter { item in
            let userId = getUserId(item)
            return canInteractWithUser(userId)
        }
    }
    
    func filterBlockedUsers(userIds: [String]) -> [String] {
        return userIds.filter { canInteractWithUser($0) }
    }
    
    // MARK: - Real-time Listeners
    
    private func setupBlockedUsersListener() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("⚠️ [BlockingService] No authenticated user, skipping listener setup")
            return
        }
        
        // Track which user we're listening for
        currentListenerUserId = currentUserId
        print("🔄 [BlockingService] Setting up listener for user: \(currentUserId)")
        
        // Listen to current user's document for blocked users list
        blockedUsersListener = db.collection("users").document(currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [BlockingService] Listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data() else {
                    print("⚠️ [BlockingService] No data in user document")
                    return
                }
                
                DispatchQueue.main.async {
                    // Update blocked users
                    if let blockedUserIds = data["blockedUsers"] as? [String] {
                        self.blockedUsers = Set(blockedUserIds)
                        print("✅ [BlockingService] Loaded \(blockedUserIds.count) blocked users")
                    } else {
                        self.blockedUsers = []
                    }
                    
                    // Update users who blocked me
                    if let blockedByIds = data["blockedBy"] as? [String] {
                        self.usersWhoBlockedMe = Set(blockedByIds)
                        print("✅ [BlockingService] Loaded \(blockedByIds.count) users who blocked me")
                    } else {
                        self.usersWhoBlockedMe = []
                    }
                }
            }
    }
    
    // MARK: - Bulk Operations
    
    func blockMultipleUsers(userIds: [String], reason: BlockReason) async -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        for userId in userIds {
            let success = await blockUser(userId: userId, username: "User", reason: reason)
            results[userId] = success
        }
        
        return results
    }
    
    func unblockMultipleUsers(userIds: [String]) async -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        for userId in userIds {
            let success = await unblockUser(userId: userId)
            results[userId] = success
        }
        
        return results
    }
}

// MARK: - Data Models

struct BlockRecord: Codable, Identifiable {
    let id: String
    let blockerUserId: String
    let blockedUserId: String
    let blockedUsername: String
    let reason: BlockReason?
    let timestamp: Date
}

struct BlockedUserInfo: Identifiable {
    let id = UUID()
    let userId: String
    let username: String
    let profilePictureUrl: String?
    let reason: BlockReason?
    let blockedAt: Date
}

enum BlockReason: String, Codable, CaseIterable {
    case harassment = "harassment"
    case spam = "spam"
    case inappropriateContent = "inappropriate_content"
    case hateSpeech = "hate_speech"
    case impersonation = "impersonation"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .harassment: return "Harassment"
        case .spam: return "Spam"
        case .inappropriateContent: return "Inappropriate Content"
        case .hateSpeech: return "Hate Speech"
        case .impersonation: return "Impersonation"
        case .other: return "Other"
        }
    }
    
    var description: String {
        switch self {
        case .harassment: return "User is harassing or bullying others"
        case .spam: return "User is sending spam or promotional content"
        case .inappropriateContent: return "User is sharing inappropriate content"
        case .hateSpeech: return "User is using hate speech"
        case .impersonation: return "User is impersonating someone else"
        case .other: return "Other reason"
        }
    }
}

// MARK: - Extensions for Content Filtering

extension BlockingService {
    
    /// Filter music logs to exclude blocked users
    func filterMusicLogs(_ logs: [MusicLog]) -> [MusicLog] {
        return filterBlockedContent(content: logs) { $0.userId }
    }
    
    /// Filter chat messages to exclude blocked users
    func filterChatMessages(_ messages: [DJChatMessage]) -> [DJChatMessage] {
        return filterBlockedContent(content: messages) { $0.userId }
    }
    
    /// Filter comments to exclude blocked users
    func filterComments(_ comments: [ReviewComment]) -> [ReviewComment] {
        return filterBlockedContent(content: comments) { $0.userId }
    }
    
    /// Filter party participants to exclude blocked users
    func filterPartyParticipants(_ participants: [PartyParticipant]) -> [PartyParticipant] {
        return filterBlockedContent(content: participants) { $0.id }
    }
}
