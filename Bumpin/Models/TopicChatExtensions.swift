import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - TopicChat Extensions for New Topic System

extension TopicChat {
    /// Creates a new TopicChat from a DiscussionTopic
    static func fromDiscussionTopic(_ topic: DiscussionTopic, hostId: String, hostName: String) -> TopicChat {
        let topicChat = TopicChat(
            title: topic.name,
            description: topic.description ?? "Discussion about \(topic.name)",
            category: topic.category,
            hostId: hostId,
            hostName: hostName
        )
        
        // Set topic-specific metadata
        var updatedChat = topicChat
        updatedChat.primaryTopic = topic.name
        updatedChat.topicKeywords = topic.tags
        updatedChat.currentDiscussion = topic.name
        
        return updatedChat
    }
    
    /// Updates the chat with a new DiscussionTopic
    mutating func updateWithDiscussionTopic(_ topic: DiscussionTopic) {
        self.title = topic.name
        self.description = topic.description ?? "Discussion about \(topic.name)"
        self.category = topic.category
        self.primaryTopic = topic.name
        self.topicKeywords = topic.tags
        self.currentDiscussion = topic.name
    }
    
    /// Converts this TopicChat to a DiscussionTopic reference
    func toDiscussionTopicReference() -> DiscussionTopicReference? {
        guard let primaryTopic = primaryTopic else { return nil }
        
        return DiscussionTopicReference(
            topicId: id, // Using chat ID as topic reference
            topicName: primaryTopic,
            category: category.toDiscussionCategory(),
            description: description
        )
    }
}

// MARK: - Category Conversion Extensions

extension DiscussionCategory {
    /// Converts DiscussionCategory to TopicCategory
    func toTopicCategory() -> TopicCategory {
        switch self {
        case .music: return .music
        case .sports: return .sports
        case .movies: return .movies
        case .tv: return .movies // Map TV to movies category
        case .politics: return .politics
        case .technology: return .science
        case .gaming: return .gaming
        case .books: return .education
        case .food: return .food
        case .travel: return .lifestyle
        case .fashion: return .lifestyle
        case .art: return .arts
        case .science: return .science
        case .business: return .business
        case .other: return .trending
        }
    }
}

extension TopicCategory {
    /// Converts TopicCategory to DiscussionCategory
    func toDiscussionCategory() -> DiscussionCategory {
        switch self {
        case .trending: return .other
        case .movies: return .movies
        case .tv: return .tv
        case .sports: return .sports
        case .gaming: return .gaming
        case .music: return .music
        case .entertainment: return .other
        case .politics: return .politics
        case .business: return .business
        case .arts: return .art
        case .art: return .art
        case .food: return .food
        case .lifestyle: return .other
        case .education: return .books
        case .science: return .science
        case .technology: return .technology
        case .books: return .books
        case .travel: return .travel
        case .fashion: return .fashion
        case .worldNews: return .politics
        case .health: return .other
        case .automotive: return .other
        case .other: return .other
        }
    }
}

// MARK: - Discussion Topic Reference Model

struct DiscussionTopicReference: Codable, Identifiable {
    let id: String
    let topicId: String
    let topicName: String
    let category: DiscussionCategory
    let description: String?
    let createdAt: Date
    
    init(topicId: String, topicName: String, category: DiscussionCategory, description: String?) {
        self.id = topicId
        self.topicId = topicId
        self.topicName = topicName
        self.category = category
        self.description = description
        self.createdAt = Date()
    }
}

// MARK: - Topic Chat Service Extensions

extension TopicService {
    /// Creates a new discussion chat from a topic
    func createDiscussionFromTopic(_ topic: DiscussionTopic, hostId: String, hostName: String) async throws -> TopicChat {
        let topicChat = TopicChat.fromDiscussionTopic(topic, hostId: hostId, hostName: hostName)
        
        // Update topic stats
        try await updateTopicStats(topicId: topic.id, incrementDiscussion: true)
        
        return topicChat
    }
    
    /// Finds existing discussions for a topic
    func findDiscussionsForTopic(_ topic: DiscussionTopic) async throws -> [TopicChat] {
        // This would query the topicChats collection for chats with matching primaryTopic
        // For now, returning empty array - you'll need to implement this based on your Firestore structure
        return []
    }
}
