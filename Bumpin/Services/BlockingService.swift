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
    
    init() {
        setupBlockedUsersListener()
    }
    
    deinit {
        blockedUsersListener?.remove()
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
        
        // Check if already blocked
        if blockedUsers.contains(userId) {
            print("❌ User is already blocked")
            return false
        }
        
        let blockRecord = BlockRecord(
            id: UUID().uuidString,
            blockerUserId: currentUserId,
            blockedUserId: userId,
            blockedUsername: username,
            reason: reason,
            timestamp: Date()
        )
        
        do {
            // Add to blocks collection
            try await db.collection("userBlocks").document(blockRecord.id).setData(from: blockRecord)
            
            // Update user's blocked list
            try await db.collection("users").document(currentUserId).updateData([
                "blockedUsers": FieldValue.arrayUnion([userId])
            ])
            
            // Update blocked user's blockedBy list
            try await db.collection("users").document(userId).updateData([
                "blockedBy": FieldValue.arrayUnion([currentUserId])
            ])
            
            // Update local state
            blockedUsers.insert(userId)
            
            // Log analytics
            AnalyticsService.shared.logEvent("user_blocked", parameters: [
                "blocked_user_id": userId,
                "reason": reason?.rawValue ?? "none"
            ])
            
            print("✅ User blocked successfully")
            return true
            
        } catch {
            print("❌ Failed to block user: \(error)")
            return false
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen to current user's document for blocked users list
        blockedUsersListener = db.collection("users").document(currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data() else { return }
                
                DispatchQueue.main.async {
                    // Update blocked users
                    if let blockedUserIds = data["blockedUsers"] as? [String] {
                        self.blockedUsers = Set(blockedUserIds)
                    }
                    
                    // Update users who blocked me
                    if let blockedByIds = data["blockedBy"] as? [String] {
                        self.usersWhoBlockedMe = Set(blockedByIds)
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
