import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Cache for log engagement data (likes, thumbs down)
class LogEngagementCache {
    static let shared = LogEngagementCache()
    
    struct EngagementData {
        var isLiked: Bool
        var hasThumbsDown: Bool
        var hasReposted: Bool
    }
    
    private var cache: [String: EngagementData] = [:] // Key: logId
    private let queue = DispatchQueue(label: "com.bumpin.logEngagementCache", attributes: .concurrent)
    
    private init() {}
    
    /// Get engagement data for a single log
    func getEngagement(logId: String, userId: String) async -> EngagementData {
        // Check cache first
        if let cached = queue.sync(execute: { cache[logId] }) {
            return cached
        }
        
        // Fetch from Firestore
        let db = Firestore.firestore()
        
        async let likeDoc = try? db.collection("logs")
            .document(logId)
            .collection("likes")
            .document(userId)
            .getDocument()
        
        async let thumbsDownDoc = try? db.collection("logs")
            .document(logId)
            .collection("thumbsDown")
            .document(userId)
            .getDocument()
        
        async let repostDoc = try? db.collection("logs")
            .document(logId)
            .collection("reposts")
            .document(userId)
            .getDocument()
        
        let (like, thumbsDown, repost) = await (likeDoc, thumbsDownDoc, repostDoc)
        
        let engagement = EngagementData(
            isLiked: like?.exists ?? false,
            hasThumbsDown: thumbsDown?.exists ?? false,
            hasReposted: repost?.exists ?? false
        )
        
        // Cache the result
        queue.async(flags: .barrier) {
            self.cache[logId] = engagement
        }
        
        return engagement
    }
    
    /// Batch fetch engagement data for multiple logs
    func getEngagements(logIds: [String], userId: String) async -> [String: EngagementData] {
        var results: [String: EngagementData] = [:]
        
        // Check cache first
        let uncachedLogIds = logIds.filter { logId in
            queue.sync { cache[logId] == nil }
        }
        
        // Return cached results immediately
        for logId in logIds {
            if let cached = queue.sync(execute: { cache[logId] }) {
                results[logId] = cached
            }
        }
        
        // Fetch uncached in batches
        guard !uncachedLogIds.isEmpty else {
            return results
        }
        
        let db = Firestore.firestore()
        
        // Batch fetch likes, thumbs down, and reposts
        await withTaskGroup(of: (String, EngagementData).self) { group in
            for logId in uncachedLogIds {
                group.addTask {
                    async let likeDoc = try? db.collection("logs")
                        .document(logId)
                        .collection("likes")
                        .document(userId)
                        .getDocument()
                    
                    async let thumbsDownDoc = try? db.collection("logs")
                        .document(logId)
                        .collection("thumbsDown")
                        .document(userId)
                        .getDocument()
                    
                    async let repostDoc = try? db.collection("logs")
                        .document(logId)
                        .collection("reposts")
                        .document(userId)
                        .getDocument()
                    
                    let (like, thumbsDown, repost) = await (likeDoc, thumbsDownDoc, repostDoc)
                    
                    let engagement = EngagementData(
                        isLiked: like?.exists ?? false,
                        hasThumbsDown: thumbsDown?.exists ?? false,
                        hasReposted: repost?.exists ?? false
                    )
                    
                    return (logId, engagement)
                }
            }
            
            for await (logId, engagement) in group {
                results[logId] = engagement
                
                // Cache the result
                queue.async(flags: .barrier) {
                    self.cache[logId] = engagement
                }
            }
        }
        
        return results
    }
    
    /// Update cache when user toggles engagement
    func updateEngagement(logId: String, isLiked: Bool? = nil, hasThumbsDown: Bool? = nil, hasReposted: Bool? = nil) {
        queue.async(flags: .barrier) {
            var current = self.cache[logId] ?? EngagementData(isLiked: false, hasThumbsDown: false, hasReposted: false)
            
            if let isLiked = isLiked {
                current.isLiked = isLiked
            }
            if let hasThumbsDown = hasThumbsDown {
                current.hasThumbsDown = hasThumbsDown
            }
            if let hasReposted = hasReposted {
                current.hasReposted = hasReposted
            }
            
            self.cache[logId] = current
        }
    }
    
    /// Clear cache
    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    /// Invalidate specific log
    func invalidate(logId: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: logId)
        }
    }
}

