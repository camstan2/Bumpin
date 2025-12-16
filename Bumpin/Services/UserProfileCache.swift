import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Singleton cache for user profiles to avoid redundant Firestore queries
class UserProfileCache {
    static let shared = UserProfileCache()
    
    private var cache: [String: UserProfile] = [:]
    private var pendingRequests: [String: [CheckedContinuation<UserProfile?, Never>]] = [:]
    private let queue = DispatchQueue(label: "com.bumpin.userProfileCache", attributes: .concurrent)
    
    private init() {}
    
    /// Get user profile from cache or fetch from Firestore
    func getProfile(userId: String) async -> UserProfile? {
        // Check cache first
        if let cached = queue.sync(execute: { cache[userId] }) {
            return cached
        }
        
        // Check if there's already a pending request for this user
        return await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                // Double-check cache after acquiring write lock
                if let cached = self.cache[userId] {
                    continuation.resume(returning: cached)
                    return
                }
                
                // Check if there's a pending request
                if self.pendingRequests[userId] != nil {
                    // Add to pending list
                    self.pendingRequests[userId]?.append(continuation)
                    return
                }
                
                // Start new request
                self.pendingRequests[userId] = [continuation]
                
                // Fetch from Firestore
                Task {
                    let db = Firestore.firestore()
                    do {
                        let doc = try await db.collection("users").document(userId).getDocument()
                        let profile = try? doc.data(as: UserProfile.self)
                        
                        await self.queue.async(flags: .barrier) {
                            // Cache the result (even if nil, to avoid repeated failed lookups)
                            if let profile = profile {
                                self.cache[userId] = profile
                            }
                            
                            // Resolve all pending continuations
                            let pending = self.pendingRequests[userId] ?? []
                            self.pendingRequests[userId] = nil
                            
                            for cont in pending {
                                cont.resume(returning: profile)
                            }
                        }
                    } catch {
                        await self.queue.async(flags: .barrier) {
                            let pending = self.pendingRequests[userId] ?? []
                            self.pendingRequests[userId] = nil
                            
                            for cont in pending {
                                cont.resume(returning: nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Batch fetch multiple user profiles
    func getProfiles(userIds: [String]) async -> [String: UserProfile] {
        var results: [String: UserProfile] = [:]
        
        // Use TaskGroup for concurrent fetching
        await withTaskGroup(of: (String, UserProfile?).self) { group in
            for userId in userIds {
                group.addTask {
                    let profile = await self.getProfile(userId: userId)
                    return (userId, profile)
                }
            }
            
            for await (userId, profile) in group {
                if let profile = profile {
                    results[userId] = profile
                }
            }
        }
        
        return results
    }
    
    /// Clear cache (useful for memory management)
    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    /// Clear specific user from cache (useful when profile is updated)
    func invalidate(userId: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: userId)
        }
    }
}

