import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Mention Models

struct MentionSuggestion: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let profilePictureUrl: String?
    let category: SuggestionCategory
    
    enum SuggestionCategory: Int, Comparable {
        case friend = 0
        case follower = 1
        case commenter = 2
        
        static func < (lhs: SuggestionCategory, rhs: SuggestionCategory) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
}

struct MentionNotification: Codable {
    let id: String
    let mentionedUserId: String
    let mentionerUserId: String
    let mentionerUsername: String
    let mentionerProfilePicture: String?
    let contentType: String // "comment", "reply", "log_caption"
    let contentId: String // logId or commentId
    let logId: String
    let logTitle: String?
    let logArtist: String?
    let timestamp: Date
    var isRead: Bool
    
    init(mentionedUserId: String, mentionerUserId: String, mentionerUsername: String, mentionerProfilePicture: String?, contentType: String, contentId: String, logId: String, logTitle: String?, logArtist: String?) {
        self.id = UUID().uuidString
        self.mentionedUserId = mentionedUserId
        self.mentionerUserId = mentionerUserId
        self.mentionerUsername = mentionerUsername
        self.mentionerProfilePicture = mentionerProfilePicture
        self.contentType = contentType
        self.contentId = contentId
        self.logId = logId
        self.logTitle = logTitle
        self.logArtist = logArtist
        self.timestamp = Date()
        self.isRead = false
    }
}

// MARK: - Mention Service

@MainActor
class MentionService: ObservableObject {
    static let shared = MentionService()
    
    private init() {}
    
    // MARK: - Get Mention Suggestions
    
    /// Get mention suggestions based on query
    /// Priority: Friends → Followers → Commenters on log
    func getSuggestions(query: String, logId: String?, currentUserId: String) async -> [MentionSuggestion] {
        var suggestions: [MentionSuggestion] = []
        
        // Get friends
        let friends = await getFriends(query: query, userId: currentUserId)
        suggestions.append(contentsOf: friends)
        
        // Get followers (excluding friends)
        let friendIds = Set(friends.map { $0.id })
        let followers = await getFollowers(query: query, userId: currentUserId, excludeIds: friendIds)
        suggestions.append(contentsOf: followers)
        
        // Get commenters on this log (excluding friends and followers)
        if let logId = logId {
            let existingIds = Set(suggestions.map { $0.id })
            let commenters = await getCommenters(query: query, logId: logId, excludeIds: existingIds)
            suggestions.append(contentsOf: commenters)
        }
        
        return suggestions
    }
    
    // MARK: - Private Helper Methods
    
    private func getFriends(query: String, userId: String) async -> [MentionSuggestion] {
        let db = Firestore.firestore()
        
        do {
            // Get user's following list
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let following = userDoc.data()?["following"] as? [String] else {
                return []
            }
            
            // Get user's followers list
            let followers = userDoc.data()?["followers"] as? [String] ?? []
            
            // Friends are users who are both following and followers
            let friendIds = Set(following).intersection(Set(followers))
            
            if friendIds.isEmpty {
                return []
            }
            
            // Fetch friend profiles
            var suggestions: [MentionSuggestion] = []
            
            for friendId in friendIds {
                let friendDoc = try await db.collection("users").document(friendId).getDocument()
                guard let data = friendDoc.data(),
                      let username = data["username"] as? String else {
                    continue
                }
                
                // Filter by query
                if !query.isEmpty && !username.lowercased().contains(query.lowercased()) {
                    continue
                }
                
                let displayName = data["displayName"] as? String ?? username
                let profilePictureUrl = data["profilePictureUrl"] as? String
                
                suggestions.append(MentionSuggestion(
                    id: friendId,
                    username: username,
                    displayName: displayName,
                    profilePictureUrl: profilePictureUrl,
                    category: .friend
                ))
            }
            
            return suggestions
            
        } catch {
            print("❌ Error fetching friends: \(error)")
            return []
        }
    }
    
    private func getFollowers(query: String, userId: String, excludeIds: Set<String>) async -> [MentionSuggestion] {
        let db = Firestore.firestore()
        
        do {
            // Get user's followers list
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let followers = userDoc.data()?["followers"] as? [String] else {
                return []
            }
            
            // Filter out friends
            let followerIds = Set(followers).subtracting(excludeIds)
            
            if followerIds.isEmpty {
                return []
            }
            
            // Fetch follower profiles
            var suggestions: [MentionSuggestion] = []
            
            for followerId in followerIds {
                let followerDoc = try await db.collection("users").document(followerId).getDocument()
                guard let data = followerDoc.data(),
                      let username = data["username"] as? String else {
                    continue
                }
                
                // Filter by query
                if !query.isEmpty && !username.lowercased().contains(query.lowercased()) {
                    continue
                }
                
                let displayName = data["displayName"] as? String ?? username
                let profilePictureUrl = data["profilePictureUrl"] as? String
                
                suggestions.append(MentionSuggestion(
                    id: followerId,
                    username: username,
                    displayName: displayName,
                    profilePictureUrl: profilePictureUrl,
                    category: .follower
                ))
            }
            
            return suggestions
            
        } catch {
            print("❌ Error fetching followers: \(error)")
            return []
        }
    }
    
    private func getCommenters(query: String, logId: String, excludeIds: Set<String>) async -> [MentionSuggestion] {
        let db = Firestore.firestore()
        
        do {
            // Get all comments on this log
            let commentsSnapshot = try await db.collection("logs")
                .document(logId)
                .collection("comments")
                .getDocuments()
            
            // Extract unique commenter user IDs
            var commenterIds = Set<String>()
            for doc in commentsSnapshot.documents {
                if let userId = doc.data()["userId"] as? String,
                   !excludeIds.contains(userId) {
                    commenterIds.insert(userId)
                }
            }
            
            if commenterIds.isEmpty {
                return []
            }
            
            // Fetch commenter profiles
            var suggestions: [MentionSuggestion] = []
            
            for commenterId in commenterIds {
                let commenterDoc = try await db.collection("users").document(commenterId).getDocument()
                guard let data = commenterDoc.data(),
                      let username = data["username"] as? String else {
                    continue
                }
                
                // Filter by query
                if !query.isEmpty && !username.lowercased().contains(query.lowercased()) {
                    continue
                }
                
                let displayName = data["displayName"] as? String ?? username
                let profilePictureUrl = data["profilePictureUrl"] as? String
                
                suggestions.append(MentionSuggestion(
                    id: commenterId,
                    username: username,
                    displayName: displayName,
                    profilePictureUrl: profilePictureUrl,
                    category: .commenter
                ))
            }
            
            return suggestions
            
        } catch {
            print("❌ Error fetching commenters: \(error)")
            return []
        }
    }
    
    // MARK: - Extract Mentions from Text
    
    /// Extract all @mentions from text
    func extractMentions(from text: String) -> [String] {
        let pattern = "@([a-zA-Z0-9_]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }
    
    /// Get user IDs for mentioned usernames
    func getUserIds(forUsernames usernames: [String]) async -> [String: String] {
        let db = Firestore.firestore()
        var usernameToIdMap: [String: String] = [:]
        
        for username in usernames {
            do {
                let snapshot = try await db.collection("users")
                    .whereField("username", isEqualTo: username)
                    .limit(to: 1)
                    .getDocuments()
                
                if let doc = snapshot.documents.first {
                    usernameToIdMap[username] = doc.documentID
                }
            } catch {
                print("❌ Error fetching user ID for @\(username): \(error)")
            }
        }
        
        return usernameToIdMap
    }
    
    // MARK: - Send Mention Notifications
    
    /// Send notifications to all mentioned users
    func sendMentionNotifications(
        text: String,
        contentType: String,
        contentId: String,
        logId: String,
        logTitle: String?,
        logArtist: String?,
        mentionerUserId: String,
        mentionerUsername: String,
        mentionerProfilePicture: String?
    ) async {
        // Extract mentions
        let mentionedUsernames = extractMentions(from: text)
        
        guard !mentionedUsernames.isEmpty else {
            return
        }
        
        // Get user IDs for mentioned usernames
        let usernameToIdMap = await getUserIds(forUsernames: mentionedUsernames)
        
        // Get log data for notification
        let db = Firestore.firestore()
        guard let logDoc = try? await db.collection("logs").document(logId).getDocument(),
              let log = try? logDoc.data(as: MusicLog.self) else {
            print("❌ Could not fetch log for mention notification")
            return
        }
        
        // Send notification to each mentioned user using NotificationService
        for (username, userId) in usernameToIdMap {
            // Don't notify if user mentions themselves
            if userId == mentionerUserId {
                continue
            }
            
            await NotificationService.shared.createMentionNotification(
                mentionedUserId: userId,
                contentType: contentType,
                contentId: contentId,
                logId: logId,
                log: log,
                mentionText: text
            )
            
            print("✅ Sent mention notification to @\(username)")
        }
    }
}

