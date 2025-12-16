import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Banner that appears above a log card when friends/following have reposted it
struct RepostBanner: View {
    let logId: String
    let currentUserId: String
    
    @State private var reposters: [ReposterData] = []
    @State private var isLoading = true
    
    var body: some View {
        if !reposters.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "arrow.2.squarepath")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text(repostText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(.systemGray6).opacity(0.5))
        }
    }
    
    private var repostText: String {
        guard !reposters.isEmpty else { return "" }
        
        let names = reposters.prefix(3).compactMap { $0.username }
        
        if names.count == 1 {
            return "\(names[0]) reposted"
        } else if names.count == 2 {
            return "\(names[0]) and \(names[1]) reposted"
        } else if names.count >= 3 {
            let othersCount = reposters.count - 2
            if othersCount > 0 {
                return "\(names[0]), \(names[1]), and \(othersCount) \(othersCount == 1 ? "other" : "others") reposted"
            } else {
                return "\(names[0]), \(names[1]), and \(names[2]) reposted"
            }
        }
        
        return ""
    }
    
    // MARK: - Data Loading
    
    func loadFriendReposters(friendIds: [String], followingIds: [String]) async {
        let db = Firestore.firestore()
        
        do {
            // Get all reposts for this log
            let snapshot = try await db.collection("logs")
                .document(logId)
                .collection("reposts")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            var friendReposters: [ReposterData] = []
            let allFriendIds = Set(friendIds + followingIds)
            
            for doc in snapshot.documents {
                guard let userId = doc.data()["userId"] as? String,
                      userId != currentUserId, // Don't show current user
                      allFriendIds.contains(userId) else {
                    continue
                }
                
                // Fetch user profile from cache
                if let profile = await UserProfileCache.shared.getProfile(userId: userId) {
                    friendReposters.append(ReposterData(
                        userId: userId,
                        username: profile.username
                    ))
                }
                
                // Limit to showing first 10 friends who reposted
                if friendReposters.count >= 10 {
                    break
                }
            }
            
            await MainActor.run {
                self.reposters = friendReposters
                self.isLoading = false
            }
            
        } catch {
            print("❌ Error loading friend reposters: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct ReposterData: Identifiable {
    let id = UUID()
    let userId: String
    let username: String
}

// MARK: - View Extension for Easy Integration

extension View {
    /// Adds a repost banner above the view if friends have reposted the log
    func repostBanner(
        logId: String,
        friendIds: [String],
        followingIds: [String]
    ) -> some View {
        VStack(spacing: 0) {
            if let currentUserId = Auth.auth().currentUser?.uid {
                RepostBannerContainer(
                    logId: logId,
                    currentUserId: currentUserId,
                    friendIds: friendIds,
                    followingIds: followingIds
                )
            }
            
            self
        }
    }
}

/// Container that manages loading state
private struct RepostBannerContainer: View {
    let logId: String
    let currentUserId: String
    let friendIds: [String]
    let followingIds: [String]
    
    @State private var banner: RepostBanner?
    
    var body: some View {
        Group {
            if let banner = banner {
                banner
            }
        }
        .task {
            let newBanner = RepostBanner(logId: logId, currentUserId: currentUserId)
            await newBanner.loadFriendReposters(friendIds: friendIds, followingIds: followingIds)
            self.banner = newBanner
        }
    }
}

