Firestore Rules Tests

Prereqs:
- Node 18+

Install deps:
```
npm ci
```

Run tests:
```
npm test
```

What’s covered:
- Users can create their own pending speakerRequests
- Only host/co-hosts can approve/delete speakerRequests
- Co-hosts can update party documents; others cannot

Notes:
- Uses @firebase/rules-unit-testing and Vitest.
- Rules are loaded from firestore.rules in this folder.


## Firestore Indexes (Social)

Create these composite indexes to ensure the social tab is snappy:

1) logs: itemType + dateLogged desc
- Collection: logs
- Fields: itemType Asc, dateLogged Desc

2) logs: genres arrayContains + dateLogged desc
- Collection: logs
- Fields: genres Array contains, dateLogged Desc

3) logs: userId in + dateLogged desc
- Collection: logs
- Fields: userId (in), dateLogged Desc
- Note: Firestore will prompt a direct index link when this runs; accept to create.

4) logs/{logId}/comments: createdAt desc
- Single-field index is sufficient. If using collection group queries, enable collection group indexing for `comments`.

5) users: showNowPlaying == true
- Single-field equality index (automatic).

If a query errors with an index suggestion, follow the error link to auto-create the exact index.


## Firestore Indexes (Trending Topics)

Create this composite index for the trending topics queries used by the Discussion tab and the admin screen:

- Collection: `trendingTopics`
- Fields (in order):
  - `category` Asc
  - `isActive` Asc
  - `popularity` Desc
  - `priority` Desc

Alternatively, add a `firestore.indexes.json` and deploy:

```
{
  "indexes": [
    {
      "collectionGroup": "trendingTopics",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" },
        { "fieldPath": "popularity", "order": "DESCENDING" },
        { "fieldPath": "priority", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

Then:

```
firebase deploy --only firestore:indexes
```

## Admin Claims

Trending topics writes require admin privileges. Set a custom claim for your user UID with the Firebase Admin SDK and then sign out/in on the device:

```js
// Node.js example
const admin = require('firebase-admin');
admin.initializeApp();
await admin.auth().setCustomUserClaims('<YOUR_UID>', { admin: true });
```

