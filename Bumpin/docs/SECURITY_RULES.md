# Firestore Security Rules (Phase 4.3)

Lock down admin-only writes for `config/*` and protect `users/{uid}.isAdmin` from being set by non-admins.

## Rules snippet

Copy the following to Firestore rules (Firebase Console → Firestore Database → Rules) and publish:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() {
      return request.auth != null;
    }

    function isAdmin() {
      return signedIn() &&
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }

    // Publicly readable app configuration; writes restricted to admins
    match /config/{docId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // User profiles
    match /users/{uid} {
      // Allow authenticated reads of profiles (tighten if needed)
      allow read: if signedIn();
      // Allow users to create/update their own profile
      allow create, update: if signedIn() && request.auth.uid == uid && !elevatesToAdmin();
      allow delete: if isAdmin();

      function elevatesToAdmin() {
        return (
          // Prevent setting isAdmin to true unless current user is already admin
          request.resource.data.diff(resource.data).affectedKeys().hasAny(['isAdmin']) &&
          (
            (request.resource.data.isAdmin == true && !isAdmin()) ||
            (resource.data.isAdmin == true && !isAdmin())
          )
        );
      }
    }

    // Live DJ Sessions
    match /liveDJSessions/{sessionId} {
      allow read: if true;
      // Only the DJ (creator) can write updates to the session document
      allow write: if signedIn() && request.resource.data.djId == request.auth.uid;
    }

    // Parties and Voice Chat
    match /parties/{partyId} {
      allow read: if true; // adjust if parties can be private
      allow update, delete: if signedIn() && (resource.data.hostId == request.auth.uid || (resource.data.coHostIds != null && request.auth.uid in resource.data.coHostIds));
      allow create: if signedIn();

      // Speaker Requests subcollection
      match /speakerRequests/{requestId} {
        allow read: if signedIn();
        // Any signed-in user can create a pending request for themselves
        allow create: if signedIn() && request.resource.data.userId == request.auth.uid && request.resource.data.status == 'pending';
        // Only host or co-hosts can update status to approved/declined
        allow update: if signedIn() && (
          get(/databases/$(database)/documents/parties/$(partyId)).data.hostId == request.auth.uid ||
          (get(/databases/$(database)/documents/parties/$(partyId)).data.coHostIds != null && request.auth.uid in get(/databases/$(database)/documents/parties/$(partyId)).data.coHostIds)
        );
        // Host/co-hosts may delete processed requests
        allow delete: if signedIn() && (
          get(/databases/$(database)/documents/parties/$(partyId)).data.hostId == request.auth.uid ||
          (get(/databases/$(database)/documents/parties/$(partyId)).data.coHostIds != null && request.auth.uid in get(/databases/$(database)/documents/parties/$(partyId)).data.coHostIds)
        );
      }
    }
    match /liveDJSessions/{sessionId}/listeners/{userId} {
      allow read: if signedIn();
      // A listener can only create/update their own presence document
      allow create, update: if signedIn() && request.auth.uid == userId;
      allow delete: if signedIn() && (request.auth.uid == userId);
    }

    // Add additional collection guards here as needed
  }
}
```

Notes:
- `config/*` becomes admin-write-only; reads remain public for client tuning.
- Regular users can update their own `users/{uid}` doc but cannot set `isAdmin`.
- Adjust `users` read policy to public or friends-only as your app evolves.

### Live DJ Sessions notes
- Prefer updating `listenerCount` via Cloud Functions to prevent spoofing (aggregate from listeners subcollection).
- Server job (Cloud Function/cron) should mark listeners inactive if `lastSeenAt` is older than 60 seconds and/or prune stale docs.


