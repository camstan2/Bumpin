import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Service class for managing social scoring system
@MainActor
class SocialScoringService: ObservableObject {
    static let shared = SocialScoringService()
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var pendingRatingPrompts: [RatingPrompt] = []
    @Published var userSocialScore: SocialScore?
    @Published var isLoading = false
    
    private init() {
        setupCurrentUserListener()
    }
    
    // MARK: - User Listener Setup
    
    private func setupCurrentUserListener() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen for pending rating prompts
        db.collection("ratingPrompts")
            .whereField("promptedUserId", isEqualTo: currentUserId)
            .whereField("isCompleted", isEqualTo: false)
            .whereField("isSkipped", isEqualTo: false)
            .whereField("expiresAt", isGreaterThan: Date())
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching rating prompts: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self.pendingRatingPrompts = documents.compactMap { document in
                        try? document.data(as: RatingPrompt.self)
                    }
                }
            }
        
        // Listen for user's social score
        db.collection("socialScores")
            .document(currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching social score: \(error)")
                    return
                }
                
                Task { @MainActor in
                    if let document = snapshot, document.exists {
                        self.userSocialScore = try? document.data(as: SocialScore.self)
                    } else {
                        // Create initial social score for user
                        self.createInitialSocialScore(for: currentUserId)
                    }
                }
            }
    }
    
    // MARK: - Interaction Tracking
    
    /// Start tracking a social interaction
    func startInteraction(
        participantIds: [String],
        interactionType: SocialInteraction.InteractionType,
        context: SocialInteraction.InteractionContext
    ) async throws -> String {
        
        let interaction = SocialInteraction(
            participantIds: participantIds,
            interactionType: interactionType,
            context: context
        )
        
        try await db.collection("socialInteractions")
            .document(interaction.id)
            .setData(from: interaction)
        
        // Create mutual rating visibility tracker
        let visibility = MutualRatingVisibility(
            interactionId: interaction.id,
            participantIds: participantIds
        )
        
        try await db.collection("mutualRatingVisibility")
            .document(interaction.id)
            .setData(from: visibility)
        
        return interaction.id
    }
    
    /// End an interaction and create rating prompts
    func endInteraction(
        interactionId: String,
        endTime: Date = Date()
    ) async throws {
        
        // Update interaction with end time
        let interactionRef = db.collection("socialInteractions").document(interactionId)
        
        try await interactionRef.updateData([
            "endTime": endTime,
            "duration": endTime.timeIntervalSince(Date()) // This will be negative, but we'll fix it
        ])
        
        // Get the interaction to create rating prompts
        let interactionDoc = try await interactionRef.getDocument()
        guard let interaction = try? interactionDoc.data(as: SocialInteraction.self),
              interaction.isRatingEligible else {
            return
        }
        
        // Calculate actual duration
        let duration = endTime.timeIntervalSince(interaction.startTime)
        try await interactionRef.updateData(["duration": duration])
        
        // Create rating prompts for eligible participants
        try await createRatingPrompts(for: interaction)
    }
    
    // MARK: - Rating Prompt Creation
    
    private func createRatingPrompts(for interaction: SocialInteraction) async throws {
        let friendService = FriendshipService.shared
        var eligiblePairs: [(String, String)] = []
        
        // Filter out friend pairs and create eligible rating pairs
        for i in 0..<interaction.participantIds.count {
            for j in (i+1)..<interaction.participantIds.count {
                let user1 = interaction.participantIds[i]
                let user2 = interaction.participantIds[j]
                
                // Check if users are friends (skip if they are)
                let areFriends = await friendService.checkFriendship(between: user1, and: user2)
                if !areFriends {
                    eligiblePairs.append((user1, user2))
                }
            }
        }
        
        // For 2v2 situations, randomly select one pair
        if interaction.context.groupSize == 4 && eligiblePairs.count > 1 {
            eligiblePairs = [eligiblePairs.randomElement()!]
        }
        
        // Create rating prompts for each eligible pair
        let batch = db.batch()
        
        for (user1, user2) in eligiblePairs {
            // Create prompt for user1 to rate user2
            let prompt1 = RatingPrompt(
                interactionId: interaction.id,
                promptedUserId: user1,
                targetUserId: user2,
                interactionType: interaction.interactionType,
                interactionContext: generateContextDescription(for: interaction)
            )
            
            // Create prompt for user2 to rate user1
            let prompt2 = RatingPrompt(
                interactionId: interaction.id,
                promptedUserId: user2,
                targetUserId: user1,
                interactionType: interaction.interactionType,
                interactionContext: generateContextDescription(for: interaction)
            )
            
            let promptRef1 = db.collection("ratingPrompts").document(prompt1.id)
            let promptRef2 = db.collection("ratingPrompts").document(prompt2.id)
            
            try batch.setData(from: prompt1, forDocument: promptRef1)
            try batch.setData(from: prompt2, forDocument: promptRef2)
        }
        
        try await batch.commit()
    }
    
    private func generateContextDescription(for interaction: SocialInteraction) -> String {
        switch interaction.interactionType {
        case .discussion:
            if let topic = interaction.context.topic {
                return "Discussion about \(topic)"
            }
            return "Group discussion"
        case .party:
            return "Music party with \(interaction.context.groupSize) people"
        case .randomChat:
            return "Random chat"
        }
    }
    
    // MARK: - Rating Submission
    
    /// Submit a social rating for another user
    func submitRating(
        for promptId: String,
        rating: Int,
        comment: String? = nil
    ) async throws {
        
        guard let prompt = pendingRatingPrompts.first(where: { $0.id == promptId }) else {
            throw SocialScoringError.promptNotFound
        }
        
        guard rating >= 1 && rating <= 10 else {
            throw SocialScoringError.invalidRating
        }
        
        // Create the social rating
        let socialRating = SocialRating(
            interactionId: prompt.interactionId,
            raterId: prompt.promptedUserId,
            ratedUserId: prompt.targetUserId,
            rating: rating,
            comment: comment
        )
        
        // Use a batch to update everything atomically
        let batch = db.batch()
        
        // Save the rating
        let ratingRef = db.collection("socialRatings").document(socialRating.id)
        try batch.setData(from: socialRating, forDocument: ratingRef)
        
        // Mark prompt as completed
        let promptRef = db.collection("ratingPrompts").document(promptId)
        batch.updateData([
            "isCompleted": true,
            "isShown": true
        ], forDocument: promptRef)
        
        // Update mutual visibility
        try await updateMutualVisibility(for: prompt, rated: true)
        
        // Update the rated user's social score
        try await updateUserSocialScore(userId: prompt.targetUserId, newRating: rating)
        
        try await batch.commit()
        
        // Update local state
        await MainActor.run {
            pendingRatingPrompts.removeAll { $0.id == promptId }
        }
    }
    
    /// Skip a rating prompt
    func skipRating(for promptId: String) async throws {
        let promptRef = db.collection("ratingPrompts").document(promptId)
        
        try await promptRef.updateData([
            "isSkipped": true,
            "isShown": true
        ])
        
        // Update mutual visibility
        if let prompt = pendingRatingPrompts.first(where: { $0.id == promptId }) {
            try await updateMutualVisibility(for: prompt, rated: false)
        }
        
        // Update local state
        await MainActor.run {
            pendingRatingPrompts.removeAll { $0.id == promptId }
        }
    }
    
    // MARK: - Social Score Management
    
    private func createInitialSocialScore(for userId: String) {
        let initialScore = SocialScore(userId: userId)
        
        Task {
            do {
                try await db.collection("socialScores")
                    .document(userId)
                    .setData(from: initialScore)
                
                await MainActor.run {
                    self.userSocialScore = initialScore
                }
            } catch {
                print("Error creating initial social score: \(error)")
            }
        }
    }
    
    private func updateUserSocialScore(userId: String, newRating: Int) async throws {
        let scoreRef = db.collection("socialScores").document(userId)
        
        // Get current score or create new one
        let scoreDoc = try await scoreRef.getDocument()
        var socialScore: SocialScore
        
        if scoreDoc.exists {
            socialScore = try scoreDoc.data(as: SocialScore.self)
        } else {
            socialScore = SocialScore(userId: userId)
        }
        
        // Update the score
        socialScore.updateScore(with: newRating)
        
        // Save updated score
        try await scoreRef.setData(from: socialScore)
        
        // Update user profile with basic score info
        try await updateUserProfileSocialData(userId: userId, socialScore: socialScore)
    }
    
    private func updateUserProfileSocialData(userId: String, socialScore: SocialScore) async throws {
        let userRef = db.collection("users").document(userId)
        
        try await userRef.updateData([
            "socialScore": socialScore.overallScore,
            "totalSocialRatings": socialScore.totalRatings,
            "socialBadges": socialScore.badges.map { $0.id },
            "socialScoreLastUpdated": Date()
        ])
    }
    
    // MARK: - Mutual Visibility Management
    
    private func updateMutualVisibility(for prompt: RatingPrompt, rated: Bool) async throws {
        let visibilityRef = db.collection("mutualRatingVisibility").document(prompt.interactionId)
        
        // This would need more complex logic to update the specific user pair
        // For now, we'll implement a simpler version
        try await visibilityRef.updateData([
            "lastUpdated": Date()
        ])
    }
    
    // MARK: - Rating Visibility Check
    
    /// Check if a user can see another user's rating for a specific interaction
    func canSeeRating(
        interactionId: String,
        requestingUserId: String,
        ratedUserId: String
    ) async throws -> Bool {
        
        // Check if the requesting user has rated the other user
        let ratingId = "\(interactionId)_\(requestingUserId)_\(ratedUserId)"
        let ratingDoc = try await db.collection("socialRatings").document(ratingId).getDocument()
        
        return ratingDoc.exists
    }
    
    /// Get a user's rating for another user in a specific interaction (if visible)
    func getRating(
        interactionId: String,
        raterId: String,
        ratedUserId: String,
        requestingUserId: String
    ) async throws -> SocialRating? {
        
        // Check visibility first
        let canSee = try await canSeeRating(
            interactionId: interactionId,
            requestingUserId: requestingUserId,
            ratedUserId: raterId
        )
        
        guard canSee else { return nil }
        
        let ratingId = "\(interactionId)_\(raterId)_\(ratedUserId)"
        let ratingDoc = try await db.collection("socialRatings").document(ratingId).getDocument()
        
        return try? ratingDoc.data(as: SocialRating.self)
    }
}

// MARK: - Error Types

enum SocialScoringError: Error, LocalizedError {
    case promptNotFound
    case invalidRating
    case userNotAuthenticated
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .promptNotFound:
            return "Rating prompt not found"
        case .invalidRating:
            return "Rating must be between 1 and 10"
        case .userNotAuthenticated:
            return "User must be authenticated"
        case .insufficientPermissions:
            return "Insufficient permissions for this action"
        }
    }
}

// MARK: - Helper Extensions

extension SocialScoringService {
    /// Get formatted social score for display
    func getFormattedScore(for userId: String) async -> String {
        do {
            let scoreDoc = try await db.collection("socialScores").document(userId).getDocument()
            if let score = try? scoreDoc.data(as: SocialScore.self) {
                return String(format: "%.1f", score.overallScore)
            }
        } catch {
            print("Error fetching score: \(error)")
        }
        return "N/A"
    }
    
    /// Check if user has any social badges
    func hasBadges(userId: String) async -> Bool {
        do {
            let scoreDoc = try await db.collection("socialScores").document(userId).getDocument()
            if let score = try? scoreDoc.data(as: SocialScore.self) {
                return !score.badges.isEmpty
            }
        } catch {
            print("Error checking badges: \(error)")
        }
        return false
    }
}

// MARK: - Friendship Service Placeholder

/// Placeholder for friendship checking - this should be implemented based on your existing friendship system
class FriendshipService {
    static let shared = FriendshipService()
    
    func checkFriendship(between user1: String, and user2: String) async -> Bool {
        // This should check your existing friendship/following system
        // For now, return false to enable all rating prompts
        return false
    }
}
