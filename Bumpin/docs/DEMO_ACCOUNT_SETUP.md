# Demo Account Setup for App Store Review

## What Apple Needs

Apple reviewers need:
1. **Demo account credentials** (username/email + password) in App Store Connect
2. **Pre-populated content** on that account so they can test:
   - Flagging/reporting content (logs, comments, chat messages)
   - Blocking users
   - Viewing reported content

## Step 1: Create Demo Account in Firebase

1. **Create a test user account** in your app (or via Firebase Console):
   - Email: `demo@bumpin.app` (or similar)
   - Password: `DemoReview2024!` (or similar - make it secure but easy to type)
   - Username: `DemoUser` or `ReviewAccount`

2. **Note the User ID** from Firebase Console (you'll need this for pre-populating content)

## Step 2: Pre-Populate Content

You need to add content to Firestore that reviewers can test flagging/blocking on. Here's what to create:

### A. Music Logs/Reviews (for flagging)
- Create 2-3 music logs in the `logs` collection
- Make them from the demo account
- Include song info, ratings, and review text

### B. Comments (for flagging)
- Create 2-3 comments in the `comments` collection
- These should be comments on the logs you created above
- Make them from the demo account

### C. Chat Messages (for flagging)
- Create 1-2 chat messages in the `chatMessages` collection
- These can be direct messages from the demo account

### D. Other Test Users (for blocking)
- Create 1-2 additional test user accounts
- These will be the users that reviewers can block
- Give them simple usernames like `TestUser1`, `TestUser2`

### E. User Profile (for flagging username/bio)
- Make sure the demo account has:
  - A username set
  - A bio/description

## Step 3: Add Credentials to App Store Connect

1. **Go to App Store Connect**
2. **Navigate to your app** → **App Information** (or **App Review Information**)
3. **Find "App Review Information" section**
4. **Enter:**
   - **Username/Email:** `demo@bumpin.app` (or whatever you created)
   - **Password:** `DemoReview2024!` (or whatever you set)
   - **Notes (optional):** "Demo account includes pre-populated content for testing flagging and blocking features. Please test reporting logs, comments, and blocking users."

## Step 4: Manual Content Creation (Option A - Recommended)

**Easiest way:** Use your app manually to create the content:

1. **Log into the demo account** on a test device
2. **Create 2-3 music logs** (search for songs, add ratings/reviews)
3. **Add comments** to those logs
4. **Create a profile** with username and bio
5. **Create 1-2 test user accounts** and have them interact with the demo account's content

## Step 5: Automated Script (Option B - Advanced)

If you want to automate this, you can create a Firebase script or use the Firebase Console to manually add documents. Here's the structure:

### Example Log Document:
```json
{
  "userId": "DEMO_USER_ID_HERE",
  "songId": "some-song-id",
  "songName": "Test Song",
  "artistName": "Test Artist",
  "rating": 5,
  "review": "This is a test review for App Store review purposes",
  "timestamp": "2024-12-03T00:00:00Z"
}
```

### Example Comment Document:
```json
{
  "userId": "DEMO_USER_ID_HERE",
  "logId": "LOG_ID_FROM_ABOVE",
  "text": "This is a test comment for review purposes",
  "timestamp": "2024-12-03T00:00:00Z"
}
```

## What Reviewers Will Test

Reviewers will:
1. Log into the demo account
2. Navigate to the Social feed
3. Find content (logs, comments) and test the **report/flag** feature
4. Find other users and test the **block** feature
5. Verify that reporting works and content can be flagged

## Quick Checklist

- [ ] Demo account created in Firebase
- [ ] Demo account has username and bio
- [ ] 2-3 music logs created from demo account
- [ ] 2-3 comments created on those logs
- [ ] 1-2 other test user accounts created (for blocking)
- [ ] Credentials added to App Store Connect "App Review Information"
- [ ] Notes added explaining the pre-populated content

## Important Notes

- **Don't use real user data** - create test content specifically for review
- **Make content obviously test content** - reviewers should know it's demo data
- **Keep credentials simple** - reviewers need to type them, so avoid special characters if possible
- **Test the account yourself** - log in and verify all features work before submitting

