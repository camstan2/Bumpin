//
//  TopicChat.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import FirebaseFirestore
import SwiftUI


struct TopicParticipant: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let profileImageUrl: String?
    let isHost: Bool
    
    init(id: String, name: String, profileImageUrl: String? = nil, isHost: Bool = false) {
        self.id = id
        self.name = name
        self.profileImageUrl = profileImageUrl
        self.isHost = isHost
    }
}

struct TopicChat: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var description: String
    var category: TopicCategory
    var hostId: String
    var hostName: String
    var createdAt: Date
    var participants: [TopicParticipant]
    var isActive: Bool
    var currentDiscussion: String?
    var trendingScore: Double?
    var isVerified: Bool
    var followerCount: Int?
    var voiceChatEnabled: Bool
    var voiceChatActive: Bool
    var speakers: [String]
    var listeners: [String]
    var maxSpeakers: Int
    var tags: [String]
    var connectionState: DiscussionConnectionState
    var globallyMutedUsers: [String] // Users muted by host for everyone
    var kickedUsers: [String] // Users kicked from discussion
    
    // Topic metadata for filtering/browsing
    var primaryTopic: String? // canonical topic (e.g., "Marvel Phase 5")
    var topicKeywords: [String] // searchable tokens/slugs (lowercased)
    
    // Discussion settings (matching party settings)
    var admissionMode: String // "open", "invite", "friends", "followers"
    var speakingPermissionMode: String // "everyone", "approval"
    var friendsAutoSpeaker: Bool
    var locationSharingEnabled: Bool
    var isPublic: Bool
    var latitude: Double?
    var longitude: Double?
    var maxDistance: Double // Maximum distance in meters for discovery
    
    init(title: String, description: String, category: TopicCategory, hostId: String, hostName: String, isVerified: Bool = false, followerCount: Int? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
        self.category = category
        self.hostId = hostId
        self.hostName = hostName
        self.createdAt = Date()
        self.participants = [TopicParticipant(id: hostId, name: hostName, isHost: true)]
        self.isActive = true
        self.currentDiscussion = nil
        self.trendingScore = nil
        self.isVerified = isVerified
        self.followerCount = followerCount
        self.voiceChatEnabled = true
        self.voiceChatActive = false
        self.speakers = []
        self.listeners = []
        self.maxSpeakers = 10
        self.tags = []
        self.connectionState = .active
        self.globallyMutedUsers = []
        self.kickedUsers = []
        
        // Topic metadata defaults
        self.primaryTopic = nil
        self.topicKeywords = []
        
        // Initialize discussion settings with defaults
        self.admissionMode = "open"
        self.speakingPermissionMode = "everyone"
        self.friendsAutoSpeaker = false
        self.locationSharingEnabled = true
        self.isPublic = false
        self.latitude = nil
        self.longitude = nil
        self.maxDistance = 402.336 // 0.25 miles in meters
    }
}



// MARK: - Firestore Extensions
extension TopicChat {
    static func fromFirestore(_ document: DocumentSnapshot) -> TopicChat? {
        guard let data = document.data() else { return nil }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return try JSONDecoder().decode(TopicChat.self, from: jsonData)
        } catch {
            print("Error decoding TopicChat: \(error)")
            return nil
        }
    }
    
    func toFirestore() -> [String: Any] {
        let participantArray: [[String: Any]] = participants.map { [
            "id": $0.id,
            "name": $0.name,
            "isHost": $0.isHost
        ] }
        
        return [
            "id": id,
            "title": title,
            "description": description,
            "category": category.rawValue,
            "hostId": hostId,
            "hostName": hostName,
            "createdAt": FieldValue.serverTimestamp(),
            "participants": participantArray,
            "isActive": isActive,
            "currentDiscussion": currentDiscussion ?? NSNull(),
            "trendingScore": trendingScore ?? NSNull(),
            "isVerified": isVerified,
            "followerCount": followerCount ?? NSNull(),
            "voiceChatEnabled": voiceChatEnabled,
            "voiceChatActive": voiceChatActive,
            "speakers": speakers,
            "listeners": listeners,
            "maxSpeakers": maxSpeakers,
            "tags": tags,
            "connectionState": connectionState.rawValue,
            "globallyMutedUsers": globallyMutedUsers,
            "kickedUsers": kickedUsers,
            // topic metadata
            "primaryTopic": primaryTopic ?? NSNull(),
            "topicKeywords": topicKeywords,
            // settings
            "admissionMode": admissionMode,
            "speakingPermissionMode": speakingPermissionMode,
            "friendsAutoSpeaker": friendsAutoSpeaker,
            "locationSharingEnabled": locationSharingEnabled,
            "isPublic": isPublic,
            "latitude": latitude ?? NSNull(),
            "longitude": longitude ?? NSNull(),
            "maxDistance": maxDistance
        ]
    }
}
