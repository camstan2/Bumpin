import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class FriendsPopularService: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    
    // Fetch friends who have logged a specific item
    func fetchFriendsForItem(itemId: String, itemType: String, completion: @escaping ([FriendProfile]?) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ FriendsPopularService: No current user")
            completion(nil)
            return
        }
        
        print("🔍 FriendsPopularService: Fetching friends for itemId: \(itemId), itemType: \(itemType)")
        
        isLoading = true
        
        // First get the current user's friends/following list
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data() else {
                print("❌ FriendsPopularService: No user data found for user \(currentUserId), error: \(error?.localizedDescription ?? "none")")
                self?.isLoading = false
                completion(nil)
                return
            }
            
            // ✅ Get ALL friends (following OR followers) for broader visibility
            // Original logic: let mutualFriends = Array(Set(following).intersection(Set(followers)))
            // New logic: Show anyone who follows you OR you follow
            let following = data["following"] as? [String] ?? []
            let followers = data["followers"] as? [String] ?? []
            let allFriends = Array(Set(following + followers))
            
            print("📊 FriendsPopularService Debug:")
            print("   Following count: \(following.count)")
            print("   Followers count: \(followers.count)")
            print("   All friends count (following + followers): \(allFriends.count)")
            
            guard !allFriends.isEmpty else {
                print("❌ FriendsPopularService: No friends found for user \(currentUserId)")
                self.isLoading = false
                completion(nil)
                return
            }
            
            print("✅ FriendsPopularService: User has \(allFriends.count) friends")
            print("   Friend IDs (first 3): \(allFriends.prefix(3))")
            
            // 🎯 Phase 3: Query for logs of this item by friends using universalTrackId for cross-platform aggregation
            var query: Query = self.db.collection("logs")
                .whereField("userId", in: allFriends)
                .limit(to: 10)

            if itemType == "artist" {
                // For artist rails, match artist name in logs (songs/albums by that artist)
                // NOTE: If you later add a normalized lowercased field, switch to that for case-insensitive matching
                query = query.whereField("artistName", isEqualTo: itemId)
            } else {
                // For songs/albums, try universalTrackId first, then fallback to itemId
                // Note: This is a simplified approach. For full cross-platform support,
                // we should query both and merge results
                query = query.whereField("universalTrackId", isEqualTo: itemId)
            }

            print("🔍 FriendsPopularService: Querying logs for itemId=\(itemId), itemType=\(itemType), userId in \(allFriends.count) friends (using universalTrackId)")
            
            query.getDocuments { [weak self] snapshot, error in
                // If universalTrackId query returns no results and itemType is not artist, fallback to itemId
                if (snapshot?.documents.isEmpty ?? true) && itemType != "artist" {
                    print("⚠️ FriendsPopularService: No results with universalTrackId, falling back to itemId")
                    
                    let fallbackQuery = self?.db.collection("logs")
                        .whereField("userId", in: allFriends)
                        .whereField("itemId", isEqualTo: itemId)
                        .limit(to: 10)
                    
                    fallbackQuery?.getDocuments { snapshot, error in
                        self?.processFriendsQueryResults(snapshot: snapshot, error: error, itemId: itemId, completion: completion)
                    }
                    return
                }
                
                self?.processFriendsQueryResults(snapshot: snapshot, error: error, itemId: itemId, completion: completion)
            }
        }
    }
    
    // Helper method to process query results
    private func processFriendsQueryResults(snapshot: QuerySnapshot?, error: Error?, itemId: String, completion: @escaping ([FriendProfile]?) -> Void) {
        self.isLoading = false
                
        if let error = error {
            print("❌ FriendsPopularService: Error fetching logs: \(error.localizedDescription)")
            self.error = error
            completion(nil)
            return
        }
        
        guard let documents = snapshot?.documents else {
            print("⚠️ FriendsPopularService: No documents in snapshot")
            completion([])
            return
        }
        
        print("✅ FriendsPopularService: Found \(documents.count) logs from friends for itemId=\(itemId)")
        
        // Extract user IDs from logs – exclude the current user
        let currentUid = Auth.auth().currentUser?.uid
        print("🔍 Current user ID: \(currentUid ?? "nil")")
        
        let allUserIds = documents.compactMap { doc -> String? in
            doc.data()["userId"] as? String
        }
        print("🔍 All user IDs from logs: \(allUserIds)")
        
        let userIds = documents.compactMap { doc -> String? in
            guard let uid = doc.data()["userId"] as? String else { return nil }
            if uid == currentUid {
                print("   ⚠️ Filtering out current user: \(uid)")
                return nil
            }
            return uid
        }
        
        print("🔍 FriendsPopularService: Extracted \(userIds.count) FRIEND user IDs (after filtering current user): \(userIds)")
        
        if userIds.isEmpty {
            print("⚠️ FriendsPopularService: No FRIEND user IDs found (only current user or no logs)")
            completion([])
            return
        }
        
        // Fetch user profiles for these friends
        self.fetchUserProfiles(userIds: userIds) { profiles in
            print("✅ FriendsPopularService: Fetched \(profiles?.count ?? 0) user profiles")
            if let profiles = profiles, !profiles.isEmpty {
                print("   Friend names: \(profiles.map { $0.displayName }.joined(separator: ", "))")
                print("   Profile image URLs: \(profiles.map { $0.profileImageUrl ?? "nil" }.joined(separator: ", "))")
            } else {
                print("   ⚠️ No profiles returned from fetchUserProfiles")
            }
            
            // Sort by most recent log
            let sortedProfiles = profiles?.sorted { profile1, profile2 in
                let log1 = documents.first { $0.data()["userId"] as? String == profile1.id }
                let log2 = documents.first { $0.data()["userId"] as? String == profile2.id }
                
                let date1 = log1?.data()["createdAt"] as? Timestamp ?? Timestamp()
                let date2 = log2?.data()["createdAt"] as? Timestamp ?? Timestamp()
                
                return date1.dateValue() > date2.dateValue()
            }
            
            print("🎯 FriendsPopularService: FINAL result for itemId=\(itemId): \(sortedProfiles?.count ?? 0) friends")
            if let sorted = sortedProfiles, !sorted.isEmpty {
                for (index, profile) in sorted.enumerated() {
                    print("   Friend \(index + 1): \(profile.displayName) (hasImage: \(profile.profileImageUrl != nil))")
                }
            } else {
                print("   ⚠️ FINAL result is EMPTY - no friends will be shown")
            }
            
            completion(sortedProfiles)
        }
    }
    
    // Fetch user profiles for given user IDs
    private func fetchUserProfiles(userIds: [String], completion: @escaping ([FriendProfile]?) -> Void) {
        let chunks = userIds.chunked(into: 10) // Firestore 'in' query limit
        var allProfiles: [FriendProfile] = []
        let group = DispatchGroup()
        
        for chunk in chunks {
            group.enter()
            
            db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let documents = snapshot?.documents {
                        let profiles = documents.compactMap { doc -> FriendProfile? in
                            let data = doc.data()
                            return FriendProfile(
                                id: doc.documentID,
                                displayName: data["displayName"] as? String ?? "Unknown User",
                                profileImageUrl: data["profileImageUrl"] as? String,
                                loggedAt: Date() // We'll get the actual log date from the logs query
                            )
                        }
                        allProfiles.append(contentsOf: profiles)
                    }
                }
        }
        
        group.notify(queue: .main) {
            completion(allProfiles)
        }
    }
    
    // Batch fetch friends for multiple items (for performance)
    func fetchFriendsForItems(items: [(id: String, type: String)], completion: @escaping ([String: [FriendProfile]]) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion([:])
            return
        }
        
        isLoading = true
        
        // Get user's mutual friends list
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data() else {
                self?.isLoading = false
                completion([:])
                return
            }
            
            // ✅ Get ALL friends (following OR followers) for broader visibility
            let following = data["following"] as? [String] ?? []
            let followers = data["followers"] as? [String] ?? []
            let allFriends = Array(Set(following + followers))
            
            guard !allFriends.isEmpty else {
                self.isLoading = false
                completion([:])
                return
            }
            
            var results: [String: [FriendProfile]] = [:]
            let group = DispatchGroup()
            
            for item in items {
                group.enter()
                
                self.fetchFriendsForItem(itemId: item.id, itemType: item.type) { profiles in
                    results[item.id] = profiles ?? []
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.isLoading = false
                completion(results)
            }
        }
    }
}

// chunked(into:) extension defined elsewhere in the project

#Preview {
    VStack {
        Text("Friends Popular Service")
            .font(.headline)
        Text("This service fetches friend data for popular items")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
}
