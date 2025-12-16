# Daily Prompts Firestore Rules

Add these rules to your Firestore security rules to enable daily prompts functionality.

## Rules to Add

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ... your existing rules ...
    
    // Daily Prompts - Admins can write, users can read
    match /dailyPrompts/{promptId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // TODO: Add admin check
    }
    
    // Prompt Responses - Users can create their own, everyone can read public ones
    match /promptResponses/{responseId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null 
                    && request.resource.data.userId == request.auth.uid
                    && request.resource.data.promptId is string
                    && request.resource.data.songId is string;
      allow update: if request.auth != null 
                    && resource.data.userId == request.auth.uid;
      allow delete: if request.auth != null 
                    && resource.data.userId == request.auth.uid;
    }
    
    // Prompt Leaderboards - Auto-updated, users can read
    match /promptLeaderboards/{promptId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // Allow writes for now (should be server-side ideally)
    }
    
    // User Prompt Stats - Users can read/write their own
    match /userPromptStats/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && userId == request.auth.uid;
    }
    
    // Prompt Templates - Admins can write, users can read
    match /promptTemplates/{templateId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null; // TODO: Add admin check
    }
  }
}
```

## How to Deploy

### Option 1: Firebase Console (Recommended for Quick Fix)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Firestore Database** → **Rules**
4. Add the rules above to your existing rules
5. Click **Publish**

### Option 2: Firebase CLI

```bash
# Edit your firestore.rules file and add the rules above
firebase deploy --only firestore:rules
```

## Testing

After deploying the rules:

1. Go to the Daily Prompt tab
2. Try submitting a song response
3. It should work without permission errors

## Important Notes

- The current rules allow any authenticated user to write to these collections
- For production, you should add proper admin checks for `dailyPrompts` and `promptTemplates`
- Consider making `promptLeaderboards` server-side only using Cloud Functions
- The rules currently allow users to update their own responses and stats

