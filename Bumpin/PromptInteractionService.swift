import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Prompt Interaction Service

@MainActor
class PromptInteractionService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var responseLikes: [String: [PromptResponseLike]] = [:] // responseId -> likes
    @Published var responseComments: [String: [PromptResponseComment]] = [:] // responseId -> comments
    @Published var userLikedResponses: Set<String> = [] // responseIds user has liked
    @Published var commentLikes: [String: [PromptResponseCommentLike]] = [:] // commentId -> likes
    @Published var userLikedComments: Set<String> = [] // commentIds user has liked
    
    // Loading states
    @Published var isLoadingLikes = false
    @Published var isLoadingComments = false
    @Published var isSubmittingLike = false
    @Published var isSubmittingComment = false
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var listeners: [String: ListenerRegistration] = [:]
    
    // MARK: - Initialization
    
    init() {
        setupAuthListener()
    }
    
    deinit {
        // Remove listeners directly without Task to avoid retain cycle
        for (_, listener) in listeners {
            listener.remove()
        }
        listeners.removeAll()
        cancellables.removeAll()
    }
    
    private func setupAuthListener() {
        NotificationCenter.default.publisher(for: .AuthStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadUserLikedContent()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Liked Content
    
    private func loadUserLikedContent() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            userLikedResponses.removeAll()
            userLikedComments.removeAll()
            return
        }
        
        await loadUserLikedResponses(userId: userId)
        await loadUserLikedComments(userId: userId)
    }
    
    private func loadUserLikedResponses(userId: String) async {
        do {
            let snapshot = try await db.collection("promptResponseLikes")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let likedResponseIds = snapshot.documents.compactMap { doc in
                doc.data()["responseId"] as? String
            }
            
            userLikedResponses = Set(likedResponseIds)
            
        } catch {
            handleError(error)
        }
    }
    
    private func loadUserLikedComments(userId: String) async {
        do {
            let snapshot = try await db.collection("promptResponseCommentLikes")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let likedCommentIds = snapshot.documents.compactMap { doc in
                doc.data()["commentId"] as? String
            }
            
            userLikedComments = Set(likedCommentIds)
            
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Response Likes
    
    func loadLikesForResponse(_ responseId: String) async {
        isLoadingLikes = true
        defer { isLoadingLikes = false }
        
        // Stop existing listener
        listeners["likes_\(responseId)"]?.remove()
        
        // Set up real-time listener
        listeners["likes_\(responseId)"] = db.collection("promptResponseLikes")
            .whereField("responseId", isEqualTo: responseId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.handleError(error)
                        return
                    }
                    
                    let likes = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: PromptResponseLike.self)
                    } ?? []
                    
                    self?.responseLikes[responseId] = likes
                }
            }
    }
    
    func toggleLikeResponse(_ responseId: String, promptId: String) async -> Bool {
        guard let user = Auth.auth().currentUser else {
            handleError(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return false
        }
        
        isSubmittingLike = true
        defer { isSubmittingLike = false }
        
        let isCurrentlyLiked = userLikedResponses.contains(responseId)
        
        do {
            if isCurrentlyLiked {
                // Unlike
                try await PromptResponseLike.deleteLike(responseId: responseId, userId: user.uid)
                userLikedResponses.remove(responseId)
                
                // Update local count
                if var likes = responseLikes[responseId] {
                    likes.removeAll { $0.userId == user.uid }
                    responseLikes[responseId] = likes
                }
                
                // Track analytics
                AnalyticsService.shared.logEvent("prompt_response_unliked", parameters: [
                    "response_id": responseId,
                    "prompt_id": promptId
                ])
                
            } else {
                // Like
                let userProfile = try await fetchUserProfile(userId: user.uid)
                
                let like = PromptResponseLike(
                    responseId: responseId,
                    promptId: promptId,
                    userId: user.uid,
                    username: userProfile?.username ?? "Anonymous"
                )
                
                try await PromptResponseLike.createLike(like)
                userLikedResponses.insert(responseId)
                
                // Update local state
                if responseLikes[responseId] == nil {
                    responseLikes[responseId] = []
                }
                responseLikes[responseId]?.insert(like, at: 0)
                
                // Post notification
                NotificationCenter.default.post(
                    name: .promptResponseLiked,
                    object: nil,
                    userInfo: ["like": like]
                )
                
                // Track analytics
                AnalyticsService.shared.logEvent("prompt_response_liked", parameters: [
                    "response_id": responseId,
                    "prompt_id": promptId
                ])
            }
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    // MARK: - Response Comments
    
    func loadCommentsForResponse(_ responseId: String) async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        
        // Stop existing listener
        listeners["comments_\(responseId)"]?.remove()
        
        // Set up real-time listener
        listeners["comments_\(responseId)"] = db.collection("promptResponseComments")
            .whereField("responseId", isEqualTo: responseId)
            .whereField("isHidden", isEqualTo: false)
            .order(by: "createdAt", descending: false) // Chronological order
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.handleError(error)
                        return
                    }
                    
                    let comments = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: PromptResponseComment.self)
                    } ?? []
                    
                    self?.responseComments[responseId] = comments
                }
            }
    }
    
    func addComment(
        to responseId: String,
        promptId: String,
        text: String,
        replyToCommentId: String? = nil,
        replyToUsername: String? = nil
    ) async -> Bool {
        
        guard let user = Auth.auth().currentUser else {
            handleError(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return false
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(NSError(domain: "ValidationError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Comment cannot be empty"]))
            return false
        }
        
        isSubmittingComment = true
        defer { isSubmittingComment = false }
        
        do {
            let userProfile = try await fetchUserProfile(userId: user.uid)
            
            let comment = PromptResponseComment(
                responseId: responseId,
                promptId: promptId,
                userId: user.uid,
                username: userProfile?.username ?? "Anonymous",
                userProfilePictureUrl: userProfile?.profilePictureUrl,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                replyToCommentId: replyToCommentId,
                replyToUsername: replyToUsername
            )
            
            try await PromptResponseComment.createComment(comment)
            
            // Update local state
            if responseComments[responseId] == nil {
                responseComments[responseId] = []
            }
            responseComments[responseId]?.append(comment)
            
            // Post notification
            NotificationCenter.default.post(
                name: .promptResponseCommented,
                object: nil,
                userInfo: ["comment": comment]
            )
            
            // Track analytics
            AnalyticsService.shared.logEvent("prompt_response_commented", parameters: [
                "response_id": responseId,
                "prompt_id": promptId,
                "is_reply": replyToCommentId != nil,
                "comment_length": text.count
            ])
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func deleteComment(_ commentId: String, responseId: String) async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        
        // Check if user owns the comment
        guard let comment = responseComments[responseId]?.first(where: { $0.id == commentId }),
              comment.userId == user.uid else {
            handleError(NSError(domain: "AuthError", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot delete this comment"]))
            return false
        }
        
        do {
            try await PromptResponseComment.deleteComment(commentId: commentId, responseId: responseId)
            
            // Update local state
            responseComments[responseId]?.removeAll { $0.id == commentId }
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    // MARK: - Comment Likes
    
    func loadLikesForComment(_ commentId: String) async {
        // Set up real-time listener for comment likes
        listeners["comment_likes_\(commentId)"] = db.collection("promptResponseCommentLikes")
            .whereField("commentId", isEqualTo: commentId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        self?.handleError(error)
                        return
                    }
                    
                    let likes = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: PromptResponseCommentLike.self)
                    } ?? []
                    
                    self?.commentLikes[commentId] = likes
                }
            }
    }
    
    func toggleLikeComment(_ commentId: String, responseId: String) async -> Bool {
        guard let user = Auth.auth().currentUser else {
            handleError(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return false
        }
        
        let isCurrentlyLiked = userLikedComments.contains(commentId)
        
        do {
            if isCurrentlyLiked {
                // Unlike
                try await PromptResponseCommentLike.deleteCommentLike(commentId: commentId, userId: user.uid)
                userLikedComments.remove(commentId)
                
                // Update local count
                if var likes = commentLikes[commentId] {
                    likes.removeAll { $0.userId == user.uid }
                    commentLikes[commentId] = likes
                }
                
            } else {
                // Like
                let like = PromptResponseCommentLike(
                    commentId: commentId,
                    responseId: responseId,
                    userId: user.uid
                )
                
                try await PromptResponseCommentLike.createCommentLike(like)
                userLikedComments.insert(commentId)
                
                // Update local state
                if commentLikes[commentId] == nil {
                    commentLikes[commentId] = []
                }
                commentLikes[commentId]?.insert(like, at: 0)
                
                // Post notification
                NotificationCenter.default.post(
                    name: .promptResponseCommentLiked,
                    object: nil,
                    userInfo: ["like": like]
                )
            }
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    // MARK: - Bulk Operations
    
    func loadAllInteractionsForResponses(_ responseIds: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for responseId in responseIds {
                group.addTask {
                    await self.loadLikesForResponse(responseId)
                }
                group.addTask {
                    await self.loadCommentsForResponse(responseId)
                }
            }
        }
    }
    
    func preloadInteractionsForPrompt(_ promptId: String, responses: [PromptResponse]) async {
        let responseIds = responses.map { $0.id }
        await loadAllInteractionsForResponses(responseIds)
    }
    
    // MARK: - Helper Methods
    
    private func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return try? snapshot.data(as: UserProfile.self)
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        
        print("❌ PromptInteractionService Error: \(error)")
        AnalyticsService.shared.logError(error: error, context: "prompt_interaction_service_error")
    }
    
    private func stopAllListeners() {
        for (_, listener) in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
    
    func stopListenersForResponse(_ responseId: String) {
        listeners["likes_\(responseId)"]?.remove()
        listeners["comments_\(responseId)"]?.remove()
        listeners.removeValue(forKey: "likes_\(responseId)")
        listeners.removeValue(forKey: "comments_\(responseId)")
        
        // Clean up local data
        responseLikes.removeValue(forKey: responseId)
        responseComments.removeValue(forKey: responseId)
    }
    
    // MARK: - Computed Properties
    
    func getLikeCount(for responseId: String) -> Int {
        return responseLikes[responseId]?.count ?? 0
    }
    
    func getCommentCount(for responseId: String) -> Int {
        return responseComments[responseId]?.count ?? 0
    }
    
    func isResponseLiked(_ responseId: String) -> Bool {
        return userLikedResponses.contains(responseId)
    }
    
    func isCommentLiked(_ commentId: String) -> Bool {
        return userLikedComments.contains(commentId)
    }
    
    func getCommentLikeCount(for commentId: String) -> Int {
        return commentLikes[commentId]?.count ?? 0
    }
    
    func getTopLikers(for responseId: String, limit: Int = 3) -> [PromptResponseLike] {
        return Array((responseLikes[responseId] ?? []).prefix(limit))
    }
    
    func getReplies(to commentId: String, in responseId: String) -> [PromptResponseComment] {
        return responseComments[responseId]?.filter { $0.replyToCommentId == commentId } ?? []
    }
    
    func getTopLevelComments(for responseId: String) -> [PromptResponseComment] {
        return responseComments[responseId]?.filter { $0.replyToCommentId == nil } ?? []
    }
}

// MARK: - Moderation Extensions

extension PromptInteractionService {
    
    func reportResponse(_ responseId: String, reason: String) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        do {
            let report: [String: Any] = [
                "responseId": responseId,
                "reporterId": userId,
                "reason": reason,
                "createdAt": FieldValue.serverTimestamp(),
                "status": "pending"
            ]
            
            try await db.collection("promptResponseReports").addDocument(data: report)
            
            // Track analytics
            AnalyticsService.shared.logEvent("prompt_response_reported", parameters: [
                "response_id": responseId,
                "reason": reason
            ])
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
    
    func reportComment(_ commentId: String, reason: String) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        
        do {
            let report: [String: Any] = [
                "commentId": commentId,
                "reporterId": userId,
                "reason": reason,
                "createdAt": FieldValue.serverTimestamp(),
                "status": "pending"
            ]
            
            try await db.collection("promptCommentReports").addDocument(data: report)
            
            return true
            
        } catch {
            handleError(error)
            return false
        }
    }
}

// MARK: - Analytics Extensions

extension PromptInteractionService {
    
    func trackResponseViewed(_ responseId: String, promptId: String) {
        AnalyticsService.shared.logEvent("prompt_response_viewed", parameters: [
            "response_id": responseId,
            "prompt_id": promptId
        ])
    }
    
    func trackResponseShared(_ responseId: String, promptId: String, method: String) {
        AnalyticsService.shared.logEvent("prompt_response_shared", parameters: [
            "response_id": responseId,
            "prompt_id": promptId,
            "share_method": method
        ])
    }
}
