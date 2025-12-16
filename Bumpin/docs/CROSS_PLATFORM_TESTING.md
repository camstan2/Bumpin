# Cross-Platform Testing Guide

## Overview
This guide covers testing the cross-platform music tracking implementation that ensures Apple Music and Spotify users see the same ratings, comments, and trending data.

## Prerequisites
- Access to both Apple Music and Spotify accounts
- Admin access to the app
- At least 2 test devices or accounts

## Phase 5: Testing & Validation

### Automated Tests

Navigate to **Settings > Admin Tools > Cross-Platform Tests** and run the automated test suite.

**Tests Included:**
1. ✅ **Universal Track Creation** - Verifies same song from different platforms gets same universal ID
2. ✅ **Platform Detection** - Confirms platform field is correctly set on search results
3. ✅ **Log Query by Universal Track ID** - Tests Firestore query functionality
4. ✅ **Trending Aggregation Logic** - Validates logs are grouped by universalTrackId
5. ✅ **Migration Service** - Checks migration service is accessible

### Manual Test Scenarios

#### Test 1: Search Consistency
**Objective:** Verify same song appears in search results for both platforms

**Steps:**
1. Log in with Apple Music account
2. Search for "Blinding Lights" by The Weeknd
3. Note the song ID and details
4. Log in with Spotify account on different device
5. Search for "Blinding Lights" by The Weeknd
6. Verify same song appears

**Expected Result:** Both platforms show identical song with same title and artist

---

#### Test 2: Cross-Platform Log Aggregation
**Objective:** Verify logs from different platforms appear together

**Steps:**
1. **Device A (Apple Music):**
   - Search for "Blinding Lights"
   - Create a log with 5-star rating
   - Add review: "Apple Music Test"

2. **Device B (Spotify):**
   - Search for "Blinding Lights"
   - Create a log with 4-star rating
   - Add review: "Spotify Test"

3. **Verification (Either Device):**
   - Navigate to "Blinding Lights" profile view
   - Check "Community Logs" section

**Expected Result:** 
- Profile shows both logs (5-star from Apple Music + 4-star from Spotify)
- Average rating reflects both platforms
- Both reviews are visible

---

#### Test 3: Trending Aggregation
**Objective:** Verify trending songs aggregate data from both platforms

**Steps:**
1. Create 10 logs for "Song A" using Apple Music accounts
2. Create 5 logs for "Song A" using Spotify accounts
3. Navigate to Social Feed > Trending
4. Find "Song A" in trending list

**Expected Result:**
- "Song A" shows 15 total logs (not split by platform)
- Trending score reflects all 15 logs
- Average rating includes all platforms

---

#### Test 4: Migration Verification
**Objective:** Ensure existing logs are properly migrated

**Steps:**
1. Navigate to **Settings > Admin Tools > Universal Track Migration**
2. Tap "Check Status"
3. Note the number of logs needing migration
4. Tap "Run Migration" and confirm
5. Wait for migration to complete
6. Check the results:
   - Successful updates
   - Failed updates
   - Skipped logs

**Expected Result:**
- All logs successfully updated
- No failed updates
- Migration completes without errors

---

#### Test 5: Friends Activity Cross-Platform
**Objective:** Verify friends' activity shows regardless of platform

**Setup:**
- User A: Apple Music
- User B: Spotify
- Users are following each other

**Steps:**
1. **User A (Apple Music):**
   - Log "Test Song 1" with 5 stars

2. **User B (Spotify):**
   - Check Social Feed > Friends Activity
   - Look for User A's recent log

**Expected Result:**
- User B sees User A's log even though they use different platforms
- Log displays correctly with artwork and rating

---

#### Test 6: Profile View Cross-Platform Comments
**Objective:** Verify comments and interactions work across platforms

**Steps:**
1. **User A (Apple Music):**
   - Log "Popular Song" with review
   - Add comment: "This is great!"

2. **User B (Spotify):**
   - Find same song and view profile
   - Like User A's review
   - Add comment: "I agree!"

3. **User A (Apple Music):**
   - Return to song profile
   - Check comments

**Expected Result:**
- User A sees User B's comment
- Like count increased
- Both users see same data

---

### Database Validation

**Check Firestore directly:**

1. Open Firebase Console
2. Navigate to Firestore Database
3. Select "logs" collection
4. Pick a random log document
5. Verify these fields exist:
   - `universalTrackId`: String (e.g., "universal-theweeknd-blindinglights-abc123")
   - `musicPlatform`: String ("apple_music" or "spotify")
   - `platformMatchingConfidence`: Number (1.0)

**Query Test:**
```
Collection: logs
Where: universalTrackId == "universal-theweeknd-blindinglights-abc123"
```
Should return logs from BOTH Apple Music and Spotify users

---

### Performance Testing

**Test:** Load Social Feed with 100+ logs
- **Expected:** Feed loads within 2-3 seconds
- **Expected:** No duplicate songs in trending
- **Expected:** Smooth scrolling

**Test:** Search with 50+ results
- **Expected:** Results appear within 1-2 seconds
- **Expected:** Platform correctly labeled on each result

---

## Troubleshooting

### Issue: Logs not aggregating
**Solution:** Run migration from Settings > Admin Tools > Universal Track Migration

### Issue: Different songs appear for Apple Music vs Spotify
**Solution:** Check TrackMatchingService fuzzy matching threshold. Songs with very different titles/spellings may not match.

### Issue: Platform field is null
**Solution:** Ensure Phase 1 changes are deployed. New logs should automatically include platform.

### Issue: Trending shows duplicates
**Solution:** Verify Phase 3 changes are in place. Check that trending calculations group by `universalTrackId` not `itemId`.

---

## Success Criteria

✅ All automated tests pass  
✅ Same song from different platforms has same universal ID  
✅ Logs aggregate correctly in profile views  
✅ Trending reflects combined platform data  
✅ Friends activity shows across platforms  
✅ Migration completes successfully  
✅ No performance degradation  

---

## Rollback Plan

If critical issues are found:

1. **Revert Query Changes:**
   - Change profile queries back to `itemId` in `MusicProfileViews.swift`
   - Revert trending aggregation to group by `itemId`

2. **Keep Data:**
   - Don't delete `universalTrackId` fields (they won't hurt)
   - Migration can be re-run later

3. **Deploy Hotfix:**
   - Push reverted code
   - Monitor for stability

---

## Next Steps After Testing

Once all tests pass:

1. ✅ Deploy to production
2. ✅ Run migration on production database
3. ✅ Monitor Firestore usage (may increase slightly)
4. ✅ Add Firestore indexes (Phase 6)
5. ✅ Monitor user feedback
6. ✅ Document for team

---

## Contact

For issues or questions, contact the development team.

Last Updated: October 26, 2025

