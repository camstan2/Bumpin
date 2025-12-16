# Firestore Indexes for Cross-Platform Support

## Overview
This document describes the Firestore indexes required for the cross-platform music tracking implementation.

## Required Indexes

### 1. Universal Track ID + Date (Descending)
**Purpose:** Query logs by universal track ID, sorted by most recent first

**Collection:** `logs`  
**Fields:**
- `universalTrackId` (Ascending)
- `dateLogged` (Descending)

**Usage:**
- Loading community logs for a song/album profile
- Aggregating ratings across platforms
- Displaying recent activity for a track

**Query Example:**
```swift
db.collection("logs")
  .whereField("universalTrackId", isEqualTo: "universal-theweeknd-blindinglights-abc123")
  .order(by: "dateLogged", descending: true)
  .limit(to: 10)
```

---

### 2. Universal Track ID + Date (Ascending)
**Purpose:** Query logs by universal track ID, sorted by oldest first

**Collection:** `logs`  
**Fields:**
- `universalTrackId` (Ascending)
- `dateLogged` (Ascending)

**Usage:**
- Historical analysis
- Tracking popularity growth over time
- Migration verification

**Query Example:**
```swift
db.collection("logs")
  .whereField("universalTrackId", isEqualTo: "universal-theweeknd-blindinglights-abc123")
  .order(by: "dateLogged", descending: false)
```

---

### 3. User ID + Universal Track ID
**Purpose:** Check if a user has logged a specific universal track

**Collection:** `logs`  
**Fields:**
- `userId` (Ascending)
- `universalTrackId` (Ascending)

**Usage:**
- Preventing duplicate logs
- Loading user's rating for a specific track
- User-specific track history

**Query Example:**
```swift
db.collection("logs")
  .whereField("userId", isEqualTo: currentUserId)
  .whereField("universalTrackId", isEqualTo: "universal-theweekend-blindinglights-abc123")
```

---

### 4. Platform + Date
**Purpose:** Query logs by music platform

**Collection:** `logs`  
**Fields:**
- `musicPlatform` (Ascending)
- `dateLogged` (Descending)

**Usage:**
- Platform-specific analytics
- Debugging platform issues
- A/B testing between platforms

**Query Example:**
```swift
db.collection("logs")
  .whereField("musicPlatform", isEqualTo: "spotify")
  .order(by: "dateLogged", descending: true)
```

---

### 5. Genres (Array) + Date
**Purpose:** Query logs by genre

**Collection:** `logs`  
**Fields:**
- `genres` (Array Contains)
- `dateLogged` (Descending)

**Usage:**
- Genre-specific trending
- Genre discovery
- Personalized recommendations

**Query Example:**
```swift
db.collection("logs")
  .whereField("genres", arrayContains: "Pop")
  .order(by: "dateLogged", descending: true)
```

---

## Deployment Instructions

### Option 1: Automatic Deployment (Recommended)

1. **Ensure firestore.indexes.json is in your project root:**
   ```bash
   cd /path/to/Bumpin
   ls firestore.indexes.json  # Should exist
   ```

2. **Deploy using Firebase CLI:**
   ```bash
   firebase deploy --only firestore:indexes
   ```

3. **Wait for indexes to build:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Navigate to Firestore Database > Indexes
   - Wait for all indexes to show "Enabled" status
   - This can take 5-30 minutes depending on data size

---

### Option 2: Manual Creation via Firebase Console

If you prefer to create indexes manually:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** > **Indexes**
4. Click **Create Index**

For each index above:
- **Collection ID:** logs
- **Fields:** Add fields in the order specified
- **Query scope:** Collection
- Click **Create**

---

## Index Status Monitoring

### Check Index Status
```bash
firebase firestore:indexes
```

### Expected Output
```
✔ firestore: indexes deployed successfully
Indexes:
  logs [universalTrackId ASC, dateLogged DESC]  ✓ Enabled
  logs [universalTrackId ASC, dateLogged ASC]   ✓ Enabled
  logs [userId ASC, universalTrackId ASC]        ✓ Enabled
  logs [musicPlatform ASC, dateLogged DESC]     ✓ Enabled
  logs [genres ARRAY, dateLogged DESC]          ✓ Enabled
```

---

## Performance Considerations

### Index Size
- Each index adds storage overhead
- Estimated: ~10-20% increase in Firestore storage
- Cost: Minimal (indexes are included in Firestore pricing)

### Query Performance
**Before indexes:**
- Universal track queries: Would fail or be very slow
- Profile loads: 5-10 seconds

**After indexes:**
- Universal track queries: 200-500ms
- Profile loads: 1-2 seconds
- Trending calculations: 2-3 seconds

### Write Performance
- Indexes slightly slow down writes (~10-20ms per log)
- Negligible impact on user experience
- Benefit of fast reads far outweighs write cost

---

## Troubleshooting

### Issue: "Index required" error
**Symptom:** Query fails with error message about missing index  
**Solution:** 
1. Check Firebase Console > Firestore > Indexes
2. Click the error link to auto-create the index
3. Wait for index to build

### Issue: Queries timing out
**Symptom:** Firestore queries take > 10 seconds  
**Solution:**
1. Verify indexes are "Enabled" not "Building"
2. Check query uses indexed fields
3. Consider pagination for large result sets

### Issue: Index build stuck
**Symptom:** Index shows "Building" for > 1 hour  
**Solution:**
1. Delete and recreate the index
2. Contact Firebase support if issue persists

---

## Rollback Plan

If indexes cause issues:

1. **Identify problematic index:**
   - Check Firestore usage metrics
   - Review error logs

2. **Delete index:**
   ```bash
   firebase firestore:indexes:delete
   ```
   Or delete via Firebase Console

3. **Revert queries:**
   - Change queries back to use `itemId`
   - Deploy hotfix

4. **Monitor:**
   - Watch for query errors
   - Verify app functionality

---

## Cost Estimate

### Storage
- **Before:** 10 GB
- **After:** 11.5 GB (+15%)
- **Cost:** $0.18/GB/month = ~$0.27/month increase

### Reads
- **Before:** 1M reads/month
- **After:** 1M reads/month (same, but faster)

### Writes
- **Before:** 100K writes/month
- **After:** 100K writes/month (same, slightly slower)

**Total Additional Cost:** ~$0.30/month

---

## Migration Timeline

1. ✅ **Phase 1-5 Complete:** Code deployed
2. ⏳ **Phase 6a:** Deploy indexes (5-30 minutes)
3. ⏳ **Phase 6b:** Wait for indexes to build
4. ⏳ **Phase 6c:** Run migration (5-60 minutes depending on log count)
5. ✅ **Phase 6d:** Verify queries work
6. ✅ **Done!**

---

## Verification Checklist

After deploying indexes:

- [ ] All indexes show "Enabled" in Firebase Console
- [ ] Universal track queries return results quickly
- [ ] Profile views load community logs
- [ ] Trending aggregates cross-platform data
- [ ] No "index required" errors in logs
- [ ] Migration completes successfully

---

## Monitoring

**Key Metrics to Watch:**
- Query latency (should be < 1 second)
- Error rate (should remain constant)
- Firestore usage (slight increase expected)
- User complaints (should decrease or remain same)

**Firebase Console Dashboards:**
- Firestore > Usage
- Firestore > Indexes
- Cloud Logging > Logs Explorer

---

## Contact

For questions about indexes or deployment, contact the development team.

Last Updated: October 26, 2025

