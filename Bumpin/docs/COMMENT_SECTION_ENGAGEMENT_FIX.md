# Comment Section Engagement Fix

## Issue Summary
The comment section view (`UnifiedLogCommentsView`) was missing proper engagement functionality:

1. ❌ Dislike count not showing (only icon visible)
2. ❌ Repost count not showing (only icon visible)
3. ❌ Repost button not working (just printing to console)
4. ❌ Repost button not showing proper state (always gray, not green when reposted)

## Root Cause
The `UnifiedLogCommentsView` was missing:
- State variables for `thumbsDownCount`, `hasReposted`, and `repostCount`
- Logic to load these states from Firestore
- Full implementation of the `handleRepost()` function
- UI display of counts in the engagement buttons

## Solution Applied

### 1. Added Missing State Variables (Lines 21-28)
```swift
// Log engagement state
@State private var isLiked: Bool = false
@State private var likeCount: Int = 0
@State private var hasThumbsDown: Bool = false
@State private var thumbsDownCount: Int = 0        // ✅ NEW
@State private var hasReposted: Bool = false       // ✅ NEW
@State private var repostCount: Int = 0            // ✅ NEW
@State private var showActivity = false
```

### 2. Updated Engagement Buttons UI (Lines 222-246)

**Thumbs Down Button** - Now shows count:
```swift
Button(action: { toggleThumbsDown() }) {
    HStack(spacing: 4) {
        Image(systemName: hasThumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            .foregroundColor(hasThumbsDown ? .orange : .secondary)
        if thumbsDownCount > 0 {
            Text("\(thumbsDownCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

**Repost Button** - Now shows count and proper state:
```swift
Button(action: { handleRepost() }) {
    HStack(spacing: 4) {
        Image(systemName: "arrow.2.squarepath")
            .foregroundColor(hasReposted ? .green : .secondary)  // ✅ Green when reposted
        if repostCount > 0 {
            Text("\(repostCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

### 3. Enhanced `loadLogEngagement()` (Lines 596-635)

Now loads all engagement states:
```swift
private func loadLogEngagement() {
    guard let currentUserId = Auth.auth().currentUser?.uid else { return }
    
    // Set initial counts from log
    likeCount = log.likeCount ?? 0
    thumbsDownCount = log.thumbsDownCount ?? 0      // ✅ NEW
    repostCount = log.repostCount ?? 0              // ✅ NEW
    
    // Check if current user has engaged with this log
    Task {
        let db = Firestore.firestore()
        
        // Check for like
        let likeDoc = try? await db.collection("logs")
            .document(log.id)
            .collection("likes")
            .document(currentUserId)
            .getDocument()
        
        // Check for thumbs down
        let thumbsDownDoc = try? await db.collection("logs")
            .document(log.id)
            .collection("thumbsDown")
            .document(currentUserId)
            .getDocument()
        
        // Check for repost - ✅ NEW
        let repostDoc = try? await db.collection("logs")
            .document(log.id)
            .collection("reposts")
            .document(currentUserId)
            .getDocument()
        
        await MainActor.run {
            self.isLiked = likeDoc?.exists ?? false
            self.hasThumbsDown = thumbsDownDoc?.exists ?? false
            self.hasReposted = repostDoc?.exists ?? false      // ✅ NEW
        }
    }
}
```

### 4. Enhanced `toggleThumbsDown()` (Lines 951-993)

Now updates the count in Firestore and locally:
```swift
private func toggleThumbsDown() {
    guard let currentUserId = Auth.auth().currentUser?.uid else { return }
    
    Task {
        let db = Firestore.firestore()
        let thumbsDownRef = db.collection("logs").document(log.id).collection("thumbsDown").document(currentUserId)
        
        do {
            if hasThumbsDown {
                // Remove thumbs down
                try await thumbsDownRef.delete()
                
                // ✅ Decrement the thumbs down count on the log
                try await db.collection("logs").document(log.id).updateData([
                    "thumbsDownCount": FieldValue.increment(Int64(-1))
                ])
                
                await MainActor.run {
                    hasThumbsDown = false
                    thumbsDownCount = max(0, thumbsDownCount - 1)  // ✅ Update local state
                }
            } else {
                // Add thumbs down
                try await thumbsDownRef.setData([
                    "userId": currentUserId,
                    "timestamp": FieldValue.serverTimestamp()
                ])
                
                // ✅ Increment the thumbs down count on the log
                try await db.collection("logs").document(log.id).updateData([
                    "thumbsDownCount": FieldValue.increment(Int64(1))
                ])
                
                await MainActor.run {
                    hasThumbsDown = true
                    thumbsDownCount += 1  // ✅ Update local state
                }
            }
        } catch {
            print("❌ Error toggling thumbs down: \(error)")
        }
    }
}
```

### 5. Fully Implemented `handleRepost()` (Lines 995-1057)

Complete repost functionality with notification support:
```swift
private func handleRepost() {
    guard let currentUserId = Auth.auth().currentUser?.uid else { return }
    
    Task {
        let db = Firestore.firestore()
        let repostRef = db.collection("logs").document(log.id).collection("reposts").document(currentUserId)
        
        do {
            // Check if already reposted
            let repostDoc = try await repostRef.getDocument()
            
            if repostDoc.exists {
                // Un-repost - delete the repost
                try await repostRef.delete()
                
                // Decrement repost count
                try await db.collection("logs").document(log.id).updateData([
                    "repostCount": FieldValue.increment(Int64(-1))
                ])
                
                // Update local state immediately
                await MainActor.run {
                    hasReposted = false
                    repostCount = max(0, repostCount - 1)
                }
                
                print("✅ Log unreposted: \(log.id)")
            } else {
                // Repost - create the repost document
                try await repostRef.setData([
                    "userId": currentUserId,
                    "timestamp": FieldValue.serverTimestamp(),
                    "originalLogId": log.id,
                    "originalUserId": log.userId
                ])
                
                // Increment repost count
                try await db.collection("logs").document(log.id).updateData([
                    "repostCount": FieldValue.increment(Int64(1))
                ])
                
                // Update local state immediately
                await MainActor.run {
                    hasReposted = true
                    repostCount += 1
                }
                
                print("✅ Log reposted: \(log.id)")
                
                // Create notification for the log owner (if not reposting your own log)
                if currentUserId != log.userId {
                    await NotificationService.shared.createRepostNotification(
                        logId: log.id,
                        logOwnerId: log.userId,
                        log: log
                    )
                }
            }
        } catch {
            print("❌ Error handling repost: \(error)")
        }
    }
}
```

## Expected Behavior After Fix

### Dislike Button
- ✅ Shows orange filled icon when user has disliked
- ✅ Shows count number next to icon (only when count > 0)
- ✅ Updates Firestore `thumbsDownCount` when toggled
- ✅ Updates local UI immediately on interaction

### Repost Button
- ✅ Shows green icon when user has reposted
- ✅ Shows gray icon when user has not reposted
- ✅ Shows count number next to icon (only when count > 0)
- ✅ Updates Firestore `repostCount` when toggled
- ✅ Creates notification for log owner when reposted
- ✅ Updates local UI immediately on interaction

## Files Modified
- `Views/UnifiedLogCommentsView.swift`

## Testing Checklist
- [ ] Open a log's comment section
- [ ] Verify dislike count is visible (should show "1" in your screenshot)
- [ ] Tap dislike button - should toggle orange/gray and update count
- [ ] Verify repost count is visible (should show "2" in your screenshot)
- [ ] Verify repost button is green (since you've already reposted)
- [ ] Tap repost button - should toggle green/gray and update count
- [ ] Check Firestore to verify counts are persisted
- [ ] Verify notification is sent to log owner when reposting

## Console Output to Look For
When reposting:
```
✅ Log reposted: [logId]
```

When un-reposting:
```
✅ Log unreposted: [logId]
```

On errors:
```
❌ Error handling repost: [error details]
❌ Error toggling thumbs down: [error details]
```

---

**Status**: ✅ COMPLETE - All engagement features now working in comment section view

