//
//  MessageReaction.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import FirebaseFirestore

// MARK: - Message Reaction Models

struct MessageReaction: Identifiable, Codable, Equatable {
    let id: String
    let messageId: String
    let emoji: String
    let userId: String
    let username: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, messageId: String, emoji: String, userId: String, username: String, timestamp: Date = Date()) {
        self.id = id
        self.messageId = messageId
        self.emoji = emoji
        self.userId = userId
        self.username = username
        self.timestamp = timestamp
    }
    
    static func == (lhs: MessageReaction, rhs: MessageReaction) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Reaction Summary for UI

struct ReactionSummary: Identifiable, Equatable {
    let id: String
    let emoji: String
    let count: Int
    let userIds: [String]
    let hasCurrentUser: Bool
    
    init(emoji: String, reactions: [MessageReaction], currentUserId: String) {
        self.id = emoji
        self.emoji = emoji
        self.count = reactions.count
        self.userIds = reactions.map { $0.userId }
        self.hasCurrentUser = reactions.contains { $0.userId == currentUserId }
    }
    
    static func == (lhs: ReactionSummary, rhs: ReactionSummary) -> Bool {
        lhs.id == rhs.id && lhs.count == rhs.count && lhs.hasCurrentUser == rhs.hasCurrentUser
    }
}

// MARK: - Popular Reaction Emojis

struct PopularReactions {
    static let emojis = ["😂", "❤️", "👍", "👎", "😮", "😢", "😡", "🔥", "💯", "👏", "🙌", "🤔"]
    
    static func getPopularEmojis() -> [String] {
        return emojis
    }
}

// MARK: - Reaction Service Protocol

protocol ReactionServiceProtocol {
    func addReaction(messageId: String, emoji: String) async -> Bool
    func removeReaction(messageId: String, emoji: String) async -> Bool
    func getReactions(for messageId: String) async -> [MessageReaction]
    func getReactionSummaries(for messageId: String, currentUserId: String) async -> [ReactionSummary]
}

// MARK: - Reaction Extensions for Message Models

extension MessageReaction {
    // Firestore conversion helpers
    func toFirestoreData() -> [String: Any] {
        return [
            "id": id,
            "messageId": messageId,
            "emoji": emoji,
            "userId": userId,
            "username": username,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
    
    init?(from document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let id = data["id"] as? String,
              let messageId = data["messageId"] as? String,
              let emoji = data["emoji"] as? String,
              let userId = data["userId"] as? String,
              let username = data["username"] as? String else {
            return nil
        }
        
        let timestamp: Date
        if let firestoreTimestamp = data["timestamp"] as? Timestamp {
            timestamp = firestoreTimestamp.dateValue()
        } else {
            timestamp = Date()
        }
        
        self.id = id
        self.messageId = messageId
        self.emoji = emoji
        self.userId = userId
        self.username = username
        self.timestamp = timestamp
    }
}
