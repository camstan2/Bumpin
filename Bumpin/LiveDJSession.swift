import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Live DJ Session Model

struct LiveDJSession: Identifiable, Codable {
    var id: String
    var djId: String
    var djUsername: String
    var djProfilePictureUrl: String?
    var title: String
    var description: String?
    var status: DJStreamStatus
    var currentTrack: CurrentTrack?
    var listenerCount: Int
    var chatEnabled: Bool
    var createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var genre: String?
    var tags: [String]
    var isPrivate: Bool
    var maxListeners: Int?
    var mutedUserIds: [String]?
    var bannedUserIds: [String]?
    
    init(id: String = UUID().uuidString, djId: String, djUsername: String, djProfilePictureUrl: String? = nil, title: String, description: String? = nil, status: DJStreamStatus = .scheduled, currentTrack: CurrentTrack? = nil, listenerCount: Int = 0, chatEnabled: Bool = true, createdAt: Date = Date(), startedAt: Date? = nil, endedAt: Date? = nil, genre: String? = nil, tags: [String] = [], isPrivate: Bool = false, maxListeners: Int? = nil, mutedUserIds: [String]? = nil, bannedUserIds: [String]? = nil) {
        self.id = id
        self.djId = djId
        self.djUsername = djUsername
        self.djProfilePictureUrl = djProfilePictureUrl
        self.title = title
        self.description = description
        self.status = status
        self.currentTrack = currentTrack
        self.listenerCount = listenerCount
        self.chatEnabled = chatEnabled
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.genre = genre
        self.tags = tags
        self.isPrivate = isPrivate
        self.maxListeners = maxListeners
        self.mutedUserIds = mutedUserIds
        self.bannedUserIds = bannedUserIds
    }
}

// MARK: - DJ Stream Status

enum DJStreamStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case live = "live"
    case paused = "paused"
    case ended = "ended"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .live: return "🔴 Live"
        case .paused: return "⏸️ Paused"
        case .ended: return "Ended"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .scheduled: return "blue"
        case .live: return "red"
        case .paused: return "orange"
        case .ended: return "gray"
        case .cancelled: return "gray"
        }
    }
}

// MARK: - Current Track Model

struct CurrentTrack: Codable {
    var trackId: String
    var title: String
    var artistName: String
    var albumName: String?
    var artworkUrl: String?
    var startedAt: Date
    var duration: TimeInterval?
    
    init(trackId: String, title: String, artistName: String, albumName: String? = nil, artworkUrl: String? = nil, startedAt: Date = Date(), duration: TimeInterval? = nil) {
        self.trackId = trackId
        self.title = title
        self.artistName = artistName
        self.albumName = albumName
        self.artworkUrl = artworkUrl
        self.startedAt = startedAt
        self.duration = duration
    }
}

// MARK: - Chat Message Model

struct DJChatMessage: Identifiable, Codable {
    var id: String
    var sessionId: String
    var userId: String
    var username: String
    var userProfilePictureUrl: String?
    var message: String
    var messageType: MessageType
    var timestamp: Date
    var isFromDJ: Bool
    
    init(id: String = UUID().uuidString, sessionId: String, userId: String, username: String, userProfilePictureUrl: String? = nil, message: String, messageType: MessageType = .text, timestamp: Date = Date(), isFromDJ: Bool = false) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.username = username
        self.userProfilePictureUrl = userProfilePictureUrl
        self.message = message
        self.messageType = messageType
        self.timestamp = timestamp
        self.isFromDJ = isFromDJ
    }
    
    enum MessageType: String, Codable {
        case text = "text"
        case trackRequest = "track_request"
        case reaction = "reaction"
        case system = "system"
    }
}

// MARK: - Listener Model

struct DJSessionListener: Identifiable, Codable {
    var id: String
    var sessionId: String
    var userId: String
    var username: String
    var userProfilePictureUrl: String?
    var joinedAt: Date
    var isActive: Bool
    var lastSeenAt: Date?
    
    init(id: String = UUID().uuidString, sessionId: String, userId: String, username: String, userProfilePictureUrl: String? = nil, joinedAt: Date = Date(), isActive: Bool = true, lastSeenAt: Date? = Date()) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.username = username
        self.userProfilePictureUrl = userProfilePictureUrl
        self.joinedAt = joinedAt
        self.isActive = isActive
        self.lastSeenAt = lastSeenAt
    }
}

// MARK: - Firestore Extensions

extension LiveDJSession {
    
    // MARK: - Create Session
    static func createSession(_ session: LiveDJSession) async throws {
        let db = Firestore.firestore()
        
        try await db.collection("liveDJSessions").document(session.id).setData(from: session)
    }
    
    // MARK: - Update Session
    static func updateSession(_ session: LiveDJSession, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        do {
            try db.collection("liveDJSessions").document(session.id).setData(from: session, merge: true) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    // MARK: - Update Session Status
    static func updateStatus(sessionId: String, status: DJStreamStatus) async throws {
        let db = Firestore.firestore()
        
        var updateData: [String: Any] = ["status": status.rawValue]
        
        if status == .ended {
            updateData["endedAt"] = Date()
        } else if status == .live {
            updateData["startedAt"] = Date()
        }
        
        try await db.collection("liveDJSessions").document(sessionId).updateData(updateData)
    }
    
    // MARK: - Fetch Session
    static func fetchSession(sessionId: String, completion: @escaping (LiveDJSession?, Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("liveDJSessions").document(sessionId).getDocument { document, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let document = document, document.exists else {
                completion(nil, NSError(domain: "FirestoreError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Session not found"]))
                return
            }
            
            do {
                let session = try document.data(as: LiveDJSession.self)
                completion(session, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    // MARK: - Fetch Live Sessions
    static func fetchLiveSessions(completion: @escaping ([LiveDJSession], Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("liveDJSessions")
            .whereField("status", isEqualTo: DJStreamStatus.live.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    completion([], error)
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    completion([], nil)
                    return
                }
                
                let sessions = documents.compactMap { document in
                    try? document.data(as: LiveDJSession.self)
                }
                
                completion(sessions, nil)
            }
    }
    
    // MARK: - End Session
    static func endSession(sessionId: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("liveDJSessions").document(sessionId).updateData([
            "status": DJStreamStatus.ended.rawValue,
            "endedAt": Date()
        ]) { error in
            completion(error)
        }
    }
    
    // MARK: - Update Listener Count
    static func updateListenerCount(sessionId: String, count: Int, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("liveDJSessions").document(sessionId).updateData([
            "listenerCount": count
        ]) { error in
            completion(error)
        }
    }
    
    // MARK: - Update Current Track
    static func updateCurrentTrack(sessionId: String, track: CurrentTrack?, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        let trackData: Any
        if let track = track {
            do {
                trackData = try track.toDictionary()
            } catch {
                completion(error)
                return
            }
        } else {
            trackData = NSNull()
        }
        
        db.collection("liveDJSessions").document(sessionId).updateData([
            "currentTrack": trackData
        ]) { error in
            completion(error)
        }
    }
}

// MARK: - Chat Message Extensions

extension DJChatMessage {
    
    // MARK: - Create Chat Message
    static func create(_ message: DJChatMessage) async throws {
        let db = Firestore.firestore()
        
        try await db.collection("liveDJSessions")
            .document(message.sessionId)
            .collection("chatMessages")
            .document(message.id)
            .setData(from: message)
    }
    
    // MARK: - Send Message (subcollection path)
    static func sendMessage(_ message: DJChatMessage, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        do {
            try db.collection("liveDJSessions")
                .document(message.sessionId)
                .collection("chatMessages")
                .document(message.id)
                .setData(from: message) { error in
                    completion(error)
                }
        } catch {
            completion(error)
        }
    }
    
    // MARK: - Fetch Messages
    static func fetchMessages(for sessionId: String, limit: Int = 50, completion: @escaping ([DJChatMessage]?, Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("liveDJSessions")
            .document(sessionId)
            .collection("chatMessages")
            .order(by: "timestamp", descending: false)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let messages = snapshot?.documents.compactMap { document in
                    try? document.data(as: DJChatMessage.self)
                } ?? []
                
                completion(messages, nil)
            }
    }
    
    // MARK: - Real-time Message Listener
    static func listenToMessages(for sessionId: String, completion: @escaping ([DJChatMessage]) -> Void) -> ListenerRegistration {
        let db = Firestore.firestore()
        
        return db.collection("liveDJSessions")
            .document(sessionId)
            .collection("chatMessages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                
                let messages = documents.compactMap { document in
                    try? document.data(as: DJChatMessage.self)
                }
                
                completion(messages)
            }
    }
}

// MARK: - DJSessionListener Extensions

extension DJSessionListener {
    
    // MARK: - Create Listener
    static func create(_ listener: DJSessionListener) async throws {
        let db = Firestore.firestore()
        
        try await db.collection("liveDJSessions")
            .document(listener.sessionId)
            .collection("listeners")
            .document(listener.userId)
            .setData(from: listener)
    }
    
    // MARK: - Remove Listener
    static func remove(sessionId: String, userId: String) async throws {
        let db = Firestore.firestore()
        
        try await db.collection("liveDJSessions")
            .document(sessionId)
            .collection("listeners")
            .document(userId)
            .delete()
    }
    
    // MARK: - Join Session
    static func joinSession(_ listener: DJSessionListener, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        do {
            try db.collection("djSessionListeners").document(listener.id).setData(from: listener) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    // MARK: - Leave Session
    static func leaveSession(listenerId: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("djSessionListeners").document(listenerId).updateData([
            "isActive": false
        ]) { error in
            completion(error)
        }
    }
    
    // MARK: - Fetch Active Listeners
    static func fetchActiveListeners(for sessionId: String, completion: @escaping ([DJSessionListener]?, Error?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("djSessionListeners")
            .whereField("sessionId", isEqualTo: sessionId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "joinedAt", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let listeners = snapshot?.documents.compactMap { document in
                    try? document.data(as: DJSessionListener.self)
                } ?? []
                
                completion(listeners, nil)
            }
    }
}

// MARK: - Helper Extensions

extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "EncodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert to dictionary"])
        }
        return dictionary
    }
} 