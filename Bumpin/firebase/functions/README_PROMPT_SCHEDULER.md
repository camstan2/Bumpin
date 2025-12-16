# Daily Prompt Scheduler - Setup Guide

This guide explains how to set up automatic daily prompt scheduling using Firebase Cloud Functions.

## Overview

The prompt scheduler automatically:
- ✅ Activates scheduled prompts when their scheduled time arrives
- ✅ Deactivates expired prompts (after 24 hours)
- ✅ Ensures only one prompt is active at a time
- ✅ Runs every 15 minutes via Cloud Scheduler

## Prerequisites

1. Firebase CLI installed: `npm install -g firebase-tools`
2. Firebase project with Blaze plan (required for Cloud Functions)
3. Admin access to your Firebase project

## Setup Instructions

### 1. Initialize Firebase Functions (if not already done)

```bash
cd /Users/camstanley/Desktop/Bumpin/Bumpin/firebase/functions
npm install
```

### 2. Install Required Dependencies

```bash
npm install firebase-functions@latest firebase-admin@latest
```

### 3. Configure the Functions

The functions are already configured in `scheduledPrompts.js`. You may want to adjust:

- **Timezone**: Line 28 - Change `'America/New_York'` to your timezone
- **Schedule Interval**: Line 27 - Change `'every 15 minutes'` to your preference
  - Options: `'every 5 minutes'`, `'every hour'`, `'0 */2 * * *'` (cron format)

### 4. Add Functions to index.js

Add this line to your `firebase/functions/index.js`:

```javascript
exports.prompts = require('./scheduledPrompts');
```

Or if you want to export them directly:

```javascript
const {
  checkScheduledPrompts,
  manualCheckPrompts,
  onPromptCreated,
  testPromptScheduler
} = require('./scheduledPrompts');

exports.checkScheduledPrompts = checkScheduledPrompts;
exports.manualCheckPrompts = manualCheckPrompts;
exports.onPromptCreated = onPromptCreated;
exports.testPromptScheduler = testPromptScheduler;
```

### 5. Deploy the Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:checkScheduledPrompts,functions:onPromptCreated
```

### 6. Verify Cloud Scheduler

After deployment, verify the scheduler is set up:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **Cloud Scheduler**
3. You should see a job named `firebase-schedule-checkScheduledPrompts-[region]`
4. Verify it's enabled and set to run every 15 minutes

## Testing

### Manual Testing via Cloud Console

1. Go to Firebase Console > Functions
2. Find `checkScheduledPrompts` function
3. Click "Test" to manually trigger it
4. Check the logs for output

### Manual Testing via HTTP Endpoint

```bash
# Test the HTTP endpoint (development only)
curl https://[YOUR-REGION]-[YOUR-PROJECT-ID].cloudfunctions.net/testPromptScheduler
```

### Manual Testing via Admin Function Call

```javascript
// In your admin code (requires admin privileges)
const manualCheck = firebase.functions().httpsCallable('manualCheckPrompts');
await manualCheck();
```

### Testing Locally

```bash
# Start the Firebase emulator
firebase emulators:start --only functions

# In another terminal, trigger the function
curl http://localhost:5001/[YOUR-PROJECT-ID]/us-central1/testPromptScheduler
```

## How It Works

### Scheduled Check (Every 15 minutes)

```
┌─────────────────────────────────────────┐
│  Cloud Scheduler triggers every 15 min  │
└───────────────┬─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│  checkScheduledPrompts() function       │
└───────────────┬─────────────────────────┘
                │
        ┌───────┴───────┐
        ▼               ▼
┌──────────────┐  ┌──────────────┐
│  Activate    │  │  Deactivate  │
│  Scheduled   │  │  Expired     │
│  Prompts     │  │  Prompts     │
└──────────────┘  └──────────────┘
```

### Activation Logic

1. Query prompts where:
   - `isActive == false`
   - `isArchived == false`
   - `date <= now` (scheduled time has passed)
   - `expiresAt > now` (not yet expired)

2. If multiple prompts match, select the most recent

3. Deactivate all currently active prompts

4. Activate the selected prompt

### Expiration Logic

1. Query prompts where:
   - `isActive == true`
   - `expiresAt < now` (past expiration)

2. Deactivate all matched prompts

## Firestore Indexes

The functions require these composite indexes:

```
Collection: dailyPrompts
- isActive (Ascending)
- isArchived (Ascending)
- date (Descending)

Collection: dailyPrompts
- isActive (Ascending)
- expiresAt (Ascending)
```

Firebase will automatically create these when you first deploy. Check logs for index creation URLs.

## Client-Side Fallback

The app also includes client-side checks in `BGRefreshManager.swift` that run when:
- App comes to foreground
- Background refresh task runs (every 15 minutes)
- Admin manually triggers via refresh button

This provides redundancy if Cloud Functions are unavailable.

## Monitoring

### View Logs

```bash
# View recent logs
firebase functions:log

# Follow logs in real-time
firebase functions:log --follow

# Filter by function
firebase functions:log --only checkScheduledPrompts
```

### Check Scheduler Status

```bash
gcloud scheduler jobs describe firebase-schedule-checkScheduledPrompts-[region] \
  --location=[region]
```

### Manually Trigger Scheduler

```bash
gcloud scheduler jobs run firebase-schedule-checkScheduledPrompts-[region] \
  --location=[region]
```

## Troubleshooting

### Functions Not Deploying

```bash
# Clear cache and redeploy
rm -rf node_modules
npm install
firebase deploy --only functions --force
```

### Scheduler Not Running

1. Check Cloud Scheduler in Google Cloud Console
2. Ensure billing is enabled (Blaze plan required)
3. Verify the scheduler job is enabled
4. Check function logs for errors

### Prompts Not Activating

1. Check Firestore rules allow function writes
2. Verify prompt dates are in correct format (Timestamp)
3. Check function logs: `firebase functions:log`
4. Manually trigger: Use refresh button in admin view

### Permissions Errors

Ensure service account has permissions:
```bash
gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member=serviceAccount:[SERVICE_ACCOUNT] \
  --role=roles/datastore.user
```

## Cost Considerations

- Cloud Scheduler: ~$0.10/month (first 3 jobs free)
- Cloud Functions: Free tier includes 2M invocations/month
- At every 15 minutes: ~3,000 invocations/month (well within free tier)

## Security

### Admin-Only Operations

The `manualCheckPrompts` function requires admin authentication:

```javascript
// Set admin claim
admin.auth().setCustomUserClaims(uid, { admin: true });
```

### Firestore Rules

Ensure prompts collection has proper rules:

```javascript
match /dailyPrompts/{promptId} {
  // Users can read active prompts
  allow read: if request.auth != null && 
                 resource.data.isActive == true;
  
  // Only admins or Cloud Functions can write
  allow write: if request.auth.token.admin == true ||
                  request.auth.uid == null; // Cloud Functions
}
```

## Support

For issues or questions:
1. Check Firebase Console > Functions logs
2. Check Cloud Scheduler job status
3. Test manually using the admin refresh button
4. Review Firestore indexes

## Alternative: Manual Scheduling

If you prefer not to use Cloud Functions, you can:
1. Manually activate prompts via the admin panel
2. Use the client-side `BGRefreshManager` (limited reliability)
3. Set up a cron job on your own server to call Firebase Admin SDK

