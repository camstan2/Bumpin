import Foundation

// MARK: - Shared Models for Social Feed

// TrendingItem moved to SocialFeedViewModel.swift

struct FriendProfile: Identifiable {
    let id: String
    let displayName: String
    let profileImageUrl: String?
    let loggedAt: Date
}
