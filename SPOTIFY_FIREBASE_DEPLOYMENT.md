# 🚀 Spotify Firebase Functions Deployment Guide

## Overview
This guide will help you deploy the secure Spotify authentication Cloud Functions to Firebase.

---

## ✅ STEP 1: Set Spotify Credentials in Firebase

You need to configure your Spotify Client ID and Secret as environment variables in Firebase Functions.

### Commands to Run:

Open Terminal and navigate to your project directory:

```bash
cd /Users/camstanley/Desktop/Bumpin
```

Then set the Spotify credentials:

```bash
firebase functions:config:set spotify.client_id="1aef1115860843efa62b56eeb45735c1"

firebase functions:config:set spotify.client_secret="251f18cdb80445a593681a3b17c37418"
```

### Verify Configuration:

```bash
firebase functions:config:get
```

You should see:
```json
{
  "spotify": {
    "client_id": "1aef1115860843efa62b56eeb45735c1",
    "client_secret": "251f18cdb80445a593681a3b17c37418"
  }
}
```

---

## ✅ STEP 2: Build and Deploy Functions

### Build TypeScript:

```bash
cd /Users/camstanley/Desktop/Bumpin/functions
npm run build
```

### Deploy to Firebase:

```bash
firebase deploy --only functions
```

This will deploy:
- `getSpotifyClientToken` - For app search/browse
- `exchangeSpotifyCode` - For user OAuth
- `refreshSpotifyToken` - For token refresh
- `getSpotifyAuthUrl` - For OAuth URL generation

### Expected Output:

```
✔  functions: Finished running predeploy script.
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (X.XX KB) for uploading
✔  functions: functions folder uploaded successfully
i  functions: creating Node.js 20 function getSpotifyClientToken(us-central1)...
i  functions: creating Node.js 20 function exchangeSpotifyCode(us-central1)...
i  functions: creating Node.js 20 function refreshSpotifyToken(us-central1)...
i  functions: creating Node.js 20 function getSpotifyAuthUrl(us-central1)...
✔  functions[getSpotifyClientToken(us-central1)]: Successful create operation.
✔  functions[exchangeSpotifyCode(us-central1)]: Successful create operation.
✔  functions[refreshSpotifyToken(us-central1)]: Successful create operation.
✔  functions[getSpotifyAuthUrl(us-central1)]: Successful create operation.

✔  Deploy complete!
```

---

## ✅ STEP 3: Test the Deployment

### Test from Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **Bumpin** project
3. Go to **Functions** in the left sidebar
4. You should see your 4 new Spotify functions listed

### Test from iOS App:

1. Build and run your iOS app in Xcode
2. Try searching for music (uses `getSpotifyClientToken`)
3. Check console logs for:
   - `🔑 Starting Spotify authentication via Firebase Functions...`
   - `✅ Spotify authentication successful via Firebase Functions`

---

## ✅ STEP 4: Monitor Function Logs

### View Logs in Firebase Console:

1. Go to **Functions** → Select a function → **Logs** tab
2. You should see logs like:
   - `✅ Spotify client token generated successfully`
   - `✅ Spotify code exchanged for user: [userId]`

### View Logs in Terminal:

```bash
firebase functions:log
```

---

## 🔒 STEP 5: Verify Security

### Check 1: No Secrets in iOS Code

Search your iOS codebase for the old secret:

```bash
cd /Users/camstanley/Desktop/Bumpin/Bumpin
grep -r "251f18cdb80445a593681a3b17c37418" . --exclude-dir=.git
```

**Expected Result**: Only found in commented-out code (marked with `*/`)

### Check 2: Firebase Functions Are Authenticated

All functions check for `context.auth` - unauthenticated requests will fail with:
```
"unauthenticated": "Must be authenticated"
```

### Check 3: Test Without Authentication

Try calling a function without being logged in - it should fail.

---

## ⚠️ TROUBLESHOOTING

### Issue: "Spotify not configured" Error

**Problem**: Firebase environment variables not set

**Solution**: Run Step 1 again and verify with `firebase functions:config:get`

### Issue: "UNAUTHENTICATED" Error in iOS App

**Problem**: User not logged into Firebase

**Solution**: Make sure user is authenticated with Firebase Auth before calling Spotify functions

### Issue: Deployment Fails

**Problem**: TypeScript compilation errors or missing dependencies

**Solution**:
```bash
cd /Users/camstanley/Desktop/Bumpin/functions
rm -rf node_modules
npm install
npm run build
```

### Issue: Functions Not Appearing in Console

**Problem**: Deployment might have failed silently

**Solution**: Check deployment logs and redeploy:
```bash
firebase deploy --only functions --force
```

---

## 🎉 SUCCESS CHECKLIST

- [ ] Firebase environment variables set (`firebase functions:config:get`)
- [ ] Functions deployed successfully (see 4 new functions in Firebase Console)
- [ ] iOS app can search Spotify music (check console logs)
- [ ] No hardcoded secrets in iOS code (grep search returns nothing)
- [ ] Function logs show successful token generation

---

## 🔄 NEXT STEPS (RECOMMENDED)

### 1. Rotate Spotify Secret (Security Best Practice)

Even though the secret is now secure, it was previously in your source code. Rotate it:

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Find your Bumpin app
3. Click **Show Client Secret**
4. Click **Rotate Secret** (generates new one)
5. Update Firebase config:
   ```bash
   firebase functions:config:set spotify.client_secret="NEW_SECRET_HERE"
   firebase deploy --only functions
   ```

### 2. Enable Function Security Rules

In Firebase Console → Functions → Settings:
- Enable VPC egress for stricter network control
- Set up monitoring alerts for failed function calls
- Enable Cloud Armor for DDoS protection (optional)

### 3. Monitor Usage & Costs

Check Firebase Console → Usage tab to monitor:
- Function invocations
- Network egress
- Ensure you stay within free tier limits

---

## 📊 EXPECTED COSTS

With your current implementation:

- **Free Tier**: 2M invocations/month, 400K GB-sec, 200K CPU-sec
- **Your Usage**: ~1 token request per user per hour
- **Estimate**: Even with 1000 daily active users, you'll stay in free tier

---

## 🆘 NEED HELP?

If you encounter issues:

1. Check Firebase Functions logs: `firebase functions:log`
2. Check iOS console logs in Xcode
3. Verify Firebase environment: `firebase functions:config:get`
4. Check Firebase Console Functions tab for errors

---

**Last Updated**: November 29, 2025
**Firebase Functions Version**: v1 (Node.js 20)

