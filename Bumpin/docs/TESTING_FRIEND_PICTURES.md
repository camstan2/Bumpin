# Friend Profile Pictures - Testing Guide

## Quick Test Summary

### What Was Fixed
1. ✅ **Mock data** no longer appears in production builds
2. ✅ **Current user filtering** prevents your own logs from showing your picture
3. ✅ **Comprehensive logging** traces the entire data flow
4. ✅ **Empty state handling** ensures no "U" placeholders appear

### Expected Behavior

#### ❌ NO Profile Circle When:
- Only you logged the item
- No friends logged the item
- Item has zero logs

#### ✅ Profile Circle Appears When:
- At least one friend (not you) logged the item
- Shows their actual profile picture
- Shows up to 3 friends maximum

## Step-by-Step Testing

### Test 1: Only Current User Logged
**Setup**:
- Log in as User 1
- User 1 logs "Gangstas" by Pop Smoke
- No other users have logged this song

**Steps**:
1. Open app as User 1
2. Go to Social tab → All section
3. Look at "Gangstas" card in Trending Songs

**Expected Result**:
- ❌ No profile picture circle in top-right corner
- Console shows:
  ```
  ⚠️ Filtering out current user: [user1_id]
  ⚠️ No FRIEND user IDs found (only current user or no logs)
  ⚠️ NO FRIENDS - circle will NOT be shown
  ```

### Test 2: Friend Logged the Item
**Setup**:
- User 1 and User 2 are friends (mutual follow)
- Both log "Hot (feat. Gunna)"
- Log in as User 1

**Steps**:
1. Open app as User 1
2. Go to Social tab → All section
3. Look at "Hot (feat. Gunna)" in Trending Songs

**Expected Result**:
- ✅ One profile picture in top-right corner
- Shows User 2's profile picture (or purple "U 2" if no image)
- Console shows:
  ```
  Extracted 1 FRIEND user IDs (after filtering current user): [user2_id]
  Fetched 1 user profiles
  Friend names: User 2
  Friend 1: User 2 (hasImage: true/false)
  ```

### Test 3: Multiple Friends Logged
**Setup**:
- User 1, User 2, User 3, User 4 all friends
- All log the same song
- Log in as User 1

**Expected Result**:
- ✅ Shows 3 profile pictures (up to max of 3)
- Shows User 2, User 3, User 4 (not User 1)
- Pictures overlap slightly
- If more than 3, doesn't show "+1" badge (that's not implemented)

### Test 4: Production Build (No Mock Data)
**Setup**:
- Build in **Release** configuration
- No friends have logged any items

**Steps**:
1. Build with Release configuration
2. Run on device or simulator
3. Navigate to Social → Trending

**Expected Result**:
- ❌ No profile circles anywhere
- NO "U" placeholders with "Alice", "Bob", "Charlie"
- Console shows:
  ```
  ℹ️ No friend data found for any items (no friends have logged these items)
  ```
- Does NOT show "adding mock data for testing"

## Console Output Reference

### Healthy Output (Friend Found)
```
🔍 FriendsPopularService: Fetching friends for itemId: ITEM_123, itemType: song
📊 FriendsPopularService Debug:
   Following count: 5
   Followers count: 3
   All friends count (following + followers): 6
✅ FriendsPopularService: User has 6 friends
🔍 FriendsPopularService: Querying logs for itemId=ITEM_123, itemType=song, userId in 6 friends
✅ FriendsPopularService: Found 2 logs from friends for itemId=ITEM_123
🔍 Current user ID: user1_abc123
🔍 All user IDs from logs: ["user1_abc123", "user2_def456"]
   ⚠️ Filtering out current user: user1_abc123
🔍 FriendsPopularService: Extracted 1 FRIEND user IDs (after filtering current user): ["user2_def456"]
✅ FriendsPopularService: Fetched 1 user profiles
   Friend names: User 2
   Profile image URLs: https://example.com/image.jpg
🎯 FriendsPopularService: FINAL result for itemId=ITEM_123: 1 friends
   Friend 1: User 2 (hasImage: true)
🎨 [EnhancedTrendingCard] 'Song Title' (itemId: ITEM_123)
   showFriendPictures: true
   friends count: 1
   friend names: User 2
   friend has image: [true]
```

### Healthy Output (No Friends, Current User Only)
```
🔍 FriendsPopularService: Fetching friends for itemId: ITEM_456, itemType: song
✅ FriendsPopularService: Found 1 logs from friends for itemId=ITEM_456
🔍 Current user ID: user1_abc123
🔍 All user IDs from logs: ["user1_abc123"]
   ⚠️ Filtering out current user: user1_abc123
🔍 FriendsPopularService: Extracted 0 FRIEND user IDs (after filtering current user): []
⚠️ FriendsPopularService: No FRIEND user IDs found (only current user or no logs)
🎨 [EnhancedTrendingCard] 'Song Title' (itemId: ITEM_456)
   showFriendPictures: true
   friends count: 0
   ⚠️ NO FRIENDS - circle will NOT be shown
```

### Problem Output (Mock Data - DEBUG Only)
```
✅ [SocialFeedViewModel] Loaded friend data for 0 items
📝 No real friend data found, adding mock data for testing (DEBUG only)
```
⚠️ This should ONLY appear in DEBUG builds!

### Problem Output (Mock Data in Production)
```
✅ [SocialFeedViewModel] Loaded friend data for 0 items
📝 No real friend data found, adding mock data for testing (DEBUG only)
```
❌ If you see this in a RELEASE build, the fix didn't work!

## Troubleshooting

### Issue: Still seeing "U" placeholders everywhere

**Check**:
1. Are you in a DEBUG build? Mock data is allowed in DEBUG
2. Check console for "adding mock data for testing"
3. If in RELEASE and seeing this → the `#if DEBUG` didn't compile correctly

**Fix**:
- Clean build folder (Cmd+Shift+K)
- Delete derived data
- Rebuild in Release configuration

### Issue: No profile pictures even when friends logged

**Check**:
1. Console shows "Extracted X FRIEND user IDs" where X > 0?
2. Console shows "Fetched X user profiles" where X > 0?
3. Are User 1 and User 2 actually friends? (mutual follow)

**Debug**:
- Check `allFriends` count in console
- Verify both users are in following/followers arrays
- Verify logs have correct `userId` field

### Issue: Seeing own profile picture

**Check**:
- Console should show "Filtering out current user: [your_id]"
- If not, the current user filter isn't working

**Debug**:
- Verify `Auth.auth().currentUser?.uid` matches log's `userId`
- Check if logs have correct `userId` field

## Build Configurations

### DEBUG Build (Xcode default)
- Mock data WILL be added if no real friends
- This is expected and OK for development
- Good for testing UI with placeholder data

### RELEASE Build (Production)
- Mock data will NOT be added
- Only real friend data appears
- No "U" placeholders
- This is what users will see

To switch:
1. Product → Scheme → Edit Scheme
2. Run → Build Configuration → Debug/Release

## Success Checklist

Before marking this as complete:

- [ ] Test 1: Only current user logged → NO circle ✅
- [ ] Test 2: Friend logged → Shows friend's picture ✅
- [ ] Test 3: No friends logged → NO circle ✅
- [ ] Test 4: Release build → No mock data ✅
- [ ] Console logging shows correct filtering ✅
- [ ] No "U" placeholders in production ✅


