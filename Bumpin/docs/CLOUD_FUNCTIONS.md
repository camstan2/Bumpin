# Cloud Functions (Presence TTL cleanup)

Suggested Node.js (TypeScript) function to clean stale listeners:

```ts
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

export const cleanupStaleListeners = functions.pubsub
  .schedule('every 5 minutes')
  .timeZone('UTC')
  .onRun(async () => {
    const db = admin.firestore();
    const cutoff = Date.now() - 60_000; // 60s TTL
    const sessions = await db.collection('liveDJSessions').get();
    for (const sess of sessions.docs) {
      const listeners = await db.collection('liveDJSessions').doc(sess.id).collection('listeners').get();
      const batch = db.batch();
      listeners.docs.forEach((doc) => {
        const ts = doc.data().lastSeenAt as FirebaseFirestore.Timestamp | undefined;
        const lastSeen = ts ? ts.toDate().getTime() : 0;
        if (lastSeen < cutoff) {
          batch.update(doc.ref, { isActive: false });
        }
      });
      await batch.commit();
      const active = (await db.collection('liveDJSessions').doc(sess.id).collection('listeners').where('isActive', '==', true).get()).size;
      await db.collection('liveDJSessions').doc(sess.id).update({ listenerCount: active });
    }
    return null;
  });
```

Notes:
- Deploy with `firebase deploy --only functions:cleanupStaleListeners`.
- Make sure service account has Firestore access.
- Consider a per-session trigger to avoid scanning all sessions if your scale grows.
