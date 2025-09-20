//
//  DiscussionMessage.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import Foundation
import FirebaseFirestore

struct DiscussionMessage: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let userId: String
    let userName: String
    let timestamp: Date
    let chatId: String
    var reactions: [MessageReaction]? = nil
    
    init(id: String, text: String, userId: String, userName: String, timestamp: Date, chatId: String) {
        self.id = id
        self.text = text
        self.userId = userId
        self.userName = userName
        self.timestamp = timestamp
        self.chatId = chatId
    }
    
    // Initialize from Firestore document
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let id = data["id"] as? String,
              let text = data["text"] as? String,
              let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let chatId = data["chatId"] as? String else {
            return nil
        }
        
        // Handle timestamp (could be Timestamp or nil for serverTimestamp)
        let timestamp: Date
        if let firestoreTimestamp = data["timestamp"] as? Timestamp {
            timestamp = firestoreTimestamp.dateValue()
        } else {
            // Fallback for messages that haven't been processed by server yet
            timestamp = Date()
        }
        
        self.id = id
        self.text = text
        self.userId = userId
        self.userName = userName
        self.timestamp = timestamp
        self.chatId = chatId
    }
}
