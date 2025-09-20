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
            completion(nil)
            return
        }
        
        isLoading = true
        
        // First get the current user's friends/following list
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let following = data["following"] as? [String],
                  !following.isEmpty else {
                self?.isLoading = false
                completion(nil)
                return
            }
            
            // Query for logs of this item by friends
            let logsQuery = self.db.collection("musicLogs")
                .whereField("itemId", isEqualTo: itemId)
                .whereField("itemType", isEqualTo: itemType)
                .whereField("userId", in: following)
                .order(by: "createdAt", descending: true)
                .limit(to: 10)
            
            logsQuery.getDocuments { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error
                    completion(nil)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                // Extract user IDs from logs
                let userIds = documents.compactMap { doc -> String? in
                    return doc.data()["userId"] as? String
                }
                
                if userIds.isEmpty {
                    completion([])
                    return
                }
                
                // Fetch user profiles for these friends
                self?.fetchUserProfiles(userIds: userIds) { profiles in
                    // Sort by most recent log
                    let sortedProfiles = profiles?.sorted { profile1, profile2 in
                        let log1 = documents.first { $0.data()["userId"] as? String == profile1.id }
                        let log2 = documents.first { $0.data()["userId"] as? String == profile2.id }
                        
                        let date1 = log1?.data()["createdAt"] as? Timestamp ?? Timestamp()
                        let date2 = log2?.data()["createdAt"] as? Timestamp ?? Timestamp()
                        
                        return date1.dateValue() > date2.dateValue()
                    }
                    
                    completion(sortedProfiles)
                }
            }
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
        
        // Get user's friends list
        db.collection("users").document(currentUserId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  let following = data["following"] as? [String],
                  !following.isEmpty else {
                self?.isLoading = false
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
