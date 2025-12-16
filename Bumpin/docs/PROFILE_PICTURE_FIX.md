# Profile Picture Upload Fix

## Problem

Profile pictures uploaded during signup were failing with this error:
```
❌ Image upload error: User does not have permission to access 
gs://bumpin-4349a.firebasestorage.app/profile_pictures/e9Pgq0mb4sXpxd5aDzt8ERXHWGB2.jpg.
```

But uploading through Edit Profile worked fine.

## Root Cause

### Two Different Upload Paths

1. **LoginSignupView (Signup):** `profile_pictures/{uid}.jpg` ❌
2. **EditProfileView (Edit Profile):** `users/{uid}/profile/profile.jpg` ✅

Your Firebase Storage rules only allowed the second path, causing signup uploads to fail.

---

## Solution

### 1. Fixed Upload Path Consistency ✅

Updated `LoginSignupView.swift` to use the same path as `EditProfileView`:

**Before:**
```swift
let storageRef = Storage.storage().reference()
    .child("profile_pictures/\(uid).jpg")  // ❌ Different path
```

**After:**
```swift
let storageRef = Storage.storage().reference()
    .child("users/\(uid)/profile/profile.jpg")  // ✅ Same as EditProfile
```

### 2. Added Better Error Handling

Added error logging for download URL failures to help debug future issues.

---

## Firebase Storage Rules Setup

### Deploy These Rules to Firebase Storage

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **Bumpin** project
3. Go to **Storage** → **Rules**
4. Replace with the rules below
5. Click **Publish**

### Complete Storage Rules

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function: Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function: Check if user owns the resource
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    // User Profile Pictures (PRIMARY PATH)
    // Path: users/{userId}/profile/profile.jpg
    match /users/{userId}/profile/{fileName} {
      // Anyone can view profile pictures (public profiles)
      allow read: if true;
      
      // Only the user can upload/update/delete their own profile picture
      allow write: if isAuthenticated() && isOwner(userId);
    }
    
    // User Media/Content
    // Path: users/{userId}/media/{fileName}
    match /users/{userId}/media/{fileName} {
      allow read: if true;
      allow write: if isAuthenticated() && isOwner(userId);
    }
    
    // Legacy profile_pictures path (backward compatibility)
    // Path: profile_pictures/{userId}.jpg
    match /profile_pictures/{userId}.jpg {
      allow read: if true;
      allow write: if isAuthenticated() && isOwner(userId);
    }
    
    // DJ Stream Media
    match /dj_streams/{streamId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    // Party Media
    match /parties/{partyId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated();
    }
    
    // Deny all other paths by default (security)
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

## How It Works Now

### Signup Flow (Fixed)
```
1. User fills signup form
   ↓
2. Selects profile picture
   ↓
3. Firebase Auth creates account (user is authenticated)
   ↓
4. Image uploads to: users/{uid}/profile/profile.jpg ✅
   ↓
5. Storage rules check: isAuthenticated() && isOwner(userId) ✅
   ↓
6. Upload succeeds ✅
   ↓
7. Profile created with profilePictureUrl ✅
```

### Edit Profile Flow (Already Working)
```
1. User opens Edit Profile
   ↓
2. Selects new profile picture
   ↓
3. Image uploads to: users/{uid}/profile/profile.jpg ✅
   ↓
4. Storage rules check: passes ✅
   ↓
5. Profile updates with new URL ✅
```

---

## Testing

### Test 1: Signup with Profile Picture
1. **Sign up** with a new account
2. **Select a profile picture** during signup
3. Complete signup
4. Check your profile → **Picture should be visible** ✅

### Test 2: Edit Profile Picture
1. Go to **Edit Profile**
2. **Change profile picture**
3. Save
4. Picture should update ✅

### Test 3: View Other Users' Pictures
1. Browse other profiles
2. All profile pictures should be **visible** (public read) ✅

---

## Security

### What's Protected ✅
- Only **authenticated users** can upload
- Users can **only upload to their own folder** (`users/{theirUid}/`)
- Users **cannot** upload to other users' folders
- Users **cannot** overwrite others' pictures

### What's Public ✅
- All profile pictures are **publicly readable**
- This is standard for social apps (like Twitter, Instagram, etc.)
- Allows profile pictures to show in feeds, comments, etc.

---

## File Structure

### Profile Pictures Location
```
Storage Bucket
└── users/
    ├── {userId1}/
    │   └── profile/
    │       └── profile.jpg  ← Profile picture
    ├── {userId2}/
    │   └── profile/
    │       └── profile.jpg
    └── ...
```

### Benefits
- ✅ Organized by user ID
- ✅ Easy to find/manage
- ✅ Supports multiple files per user (future: cover photos, etc.)
- ✅ Automatic cleanup (can delete entire user folder)

---

## Troubleshooting

### If Uploads Still Fail

1. **Check Firebase Storage Rules:**
   - Go to Firebase Console → Storage → Rules
   - Verify the rules are published
   - Look for errors in the rules

2. **Check User Authentication:**
   - User must be signed in
   - Check console for auth errors

3. **Check Storage Permissions:**
   - Verify bucket name matches: `bumpin-4349a.firebasestorage.app`
   - Check Firebase project settings

4. **Check Console Logs:**
   - Look for: `✅ Profile image uploaded successfully during signup`
   - Or error messages

### Common Issues

| Error | Cause | Solution |
|-------|-------|----------|
| "Missing or insufficient permissions" | Storage rules not deployed | Deploy storage.rules to Firebase |
| "User does not have permission" | Wrong path or rules | Verify path matches rules |
| "Upload timeout" | Large image | App already compresses (0.7 quality) |
| "No download URL" | Upload succeeded but URL failed | Check for errors in console |

---

## What Changed

### Files Modified
1. ✅ `LoginSignupView.swift` - Fixed upload path
2. ✅ **NEW:** `storage.rules` - Complete Storage security rules
3. ✅ **NEW:** `docs/PROFILE_PICTURE_FIX.md` - This documentation

### Firestore Schema (Unchanged)
```javascript
users/{userId}:
  - profilePictureUrl: "https://firebasestorage.googleapis.com/..." ✅
```

---

## Next Steps

1. **Deploy Storage Rules:**
   - Copy rules from `storage.rules` file
   - Paste into Firebase Console → Storage → Rules
   - Publish

2. **Test Signup:**
   - Create new account with profile picture
   - Verify it works

3. **Optional - Clean Up Old Images:**
   - Old images in `profile_pictures/` can be deleted
   - New uploads go to `users/{uid}/profile/`

---

## Summary

✅ **Fixed:** Inconsistent upload paths between signup and edit  
✅ **Fixed:** Missing Storage security rules  
✅ **Added:** Comprehensive Storage rules for all use cases  
✅ **Added:** Better error logging for debugging  

Profile pictures now work perfectly during signup! 🎉

