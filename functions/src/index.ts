import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { runTrendingUpdateOnce } from './trendingScheduler';
import { runWeeklyMatchmaking } from './matchmakingScheduler';
import express = require('express');
import { AccessToken } from 'livekit-server-sdk';

admin.initializeApp();
const db = admin.firestore();

// Config via env (set with: firebase functions:config:set livekit.url=... livekit.key=... livekit.secret=...)
const livekitURL = process.env.LIVEKIT_URL || functions.config().livekit?.url;
const livekitKey = process.env.LIVEKIT_API_KEY || functions.config().livekit?.key;
const livekitSecret = process.env.LIVEKIT_API_SECRET || functions.config().livekit?.secret;

if (!livekitURL || !livekitKey || !livekitSecret) {
  // Log once at cold start
  console.warn('LiveKit configuration missing. Set LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET.');
}

async function authenticate(req: functions.https.Request): Promise<admin.auth.DecodedIdToken> {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : undefined;
  if (!token) { throw new functions.https.HttpsError('unauthenticated', 'Missing Authorization'); }
  try {
    return await admin.auth().verifyIdToken(token);
  } catch {
    throw new functions.https.HttpsError('unauthenticated', 'Invalid token');
  }
}

function roomNameFor(sessionId: string): string {
  return `dj_${sessionId}`;
}

const app = express();
app.use(express.json());

// Create session doc; client supplies title/artwork; server assigns room
app.post('/dj/live/create', async (req, res) => {
  try {
    const user = await authenticate(req as any);
    const { title, artworkURL, visibility = 'public' } = req.body || {};
    if (!title) return res.status(400).json({ error: 'title required' });

    const docRef = db.collection('liveDJSessions').doc();
    const sessionId = docRef.id;
    const data = {
      hostId: user.uid,
      roomName: roomNameFor(sessionId),
      title,
      artworkURL: artworkURL || '',
      isLive: false,
      listenerCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      visibility,
      startedAt: null,
      endedAt: null
    };
    await docRef.set(data, { merge: true });
    return res.json({ sessionId, roomName: data.roomName });
  } catch (e: any) {
    console.error(e);
    return res.status(500).json({ error: e.message || 'internal' });
  }
});

// Issue LiveKit token for room + role
app.post('/livekit/token', async (req, res) => {
  try {
    const user = await authenticate(req as any);
    const { sessionId, role } = req.body || {};
    if (!sessionId || !role) return res.status(400).json({ error: 'sessionId and role required' });

    const doc = await db.collection('liveDJSessions').doc(sessionId).get();
    if (!doc.exists) return res.status(404).json({ error: 'session not found' });
    const s = doc.data() as any;

    // Role authorization: host can publish; others subscribe unless promoted
    const isHost = s.hostId === user.uid;
    if (role === 'publisher' && !isHost) {
      return res.status(403).json({ error: 'publish not allowed' });
    }

    const at = new AccessToken(livekitKey!, livekitSecret!, {
      identity: user.uid,
      ttl: 60 * 5, // 5 minutes
    });
    at.addGrant({
      room: s.roomName,
      roomJoin: true,
      canPublish: role === 'publisher',
      canSubscribe: true,
      canPublishData: true,
    });
    const token = await at.toJwt();
    return res.json({ token, url: livekitURL, roomName: s.roomName });
  } catch (e: any) {
    console.error(e);
    return res.status(500).json({ error: e.message || 'internal' });
  }
});

// End session
app.post('/dj/live/stop', async (req, res) => {
  try {
    const user = await authenticate(req as any);
    const { sessionId } = req.body || {};
    if (!sessionId) return res.status(400).json({ error: 'sessionId required' });
    const ref = db.collection('liveDJSessions').doc(sessionId);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ error: 'not found' });
    const s = doc.data() as any;
    if (s.hostId !== user.uid) return res.status(403).json({ error: 'forbidden' });
    await ref.update({ isLive: false, endedAt: admin.firestore.FieldValue.serverTimestamp() });
    return res.json({ ok: true });
  } catch (e: any) {
    console.error(e);
    return res.status(500).json({ error: e.message || 'internal' });
  }
});

// LiveKit webhooks
app.post('/webhooks/livekit', async (req, res) => {
  try {
    const event = req.body;
    // Optionally verify signature header from LiveKit if configured
    const type = event?.event;
    const roomName: string | undefined = event?.room?.name;
    if (!type || !roomName) { return res.status(200).end(); }

    const snap = await db.collection('liveDJSessions').where('roomName', '==', roomName).limit(1).get();
    if (snap.empty) return res.status(200).end();
    const ref = snap.docs[0].ref;

    if (type === 'room_started') {
      await ref.update({ isLive: true, startedAt: admin.firestore.FieldValue.serverTimestamp() });
    } else if (type === 'room_finished') {
      await ref.update({ isLive: false, endedAt: admin.firestore.FieldValue.serverTimestamp(), listenerCount: 0 });
    } else if (type === 'participant_joined' || type === 'participant_left') {
      // If LiveKit sends participant totals, prefer that. Otherwise, approximate by counting active clients if you track them.
      const count = event?.num_participants as number | undefined;
      if (typeof count === 'number') {
        await ref.update({ listenerCount: Math.max(0, count - 1) }); // minus host if desired
      }
    }
    return res.status(200).end();
  } catch (e) {
    console.error(e);
    return res.status(200).end(); // Avoid retries
  }
});

export const api = functions.region('us-central1').https.onRequest(app);

// Hourly scheduled job to update trending topics using Reddit signals
export const trendingScheduler = functions.pubsub
  .schedule('every 60 minutes')
  .timeZone('Etc/UTC')
  .onRun(async () => {
    console.log('⏰ trendingScheduler started');
    await runTrendingUpdateOnce();
    console.log('✅ trendingScheduler finished');
  });

// Weekly matchmaking scheduler - runs every Thursday at 1:00 PM EST
export const weeklyMusicMatchmaking = functions.pubsub
  .schedule('0 13 * * 4') // Cron: 1:00 PM every Thursday (0-based hours)
  .timeZone('America/New_York') // Eastern Time
  .onRun(async (context) => {
    console.log('🎵 Weekly music matchmaking started');
    
    try {
      await runWeeklyMatchmaking();
      console.log('✅ Weekly music matchmaking completed successfully');
    } catch (error) {
      console.error('❌ Weekly music matchmaking failed:', error);
      
      // Log error to Firestore for admin monitoring
      await db.collection('systemLogs').add({
        type: 'matchmaking_error',
        error: error instanceof Error ? error.message : String(error),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        context: 'weeklyMusicMatchmaking'
      });
      
      throw error; // Re-throw to mark function as failed
    }
  });

// Manual trigger for testing matchmaking (admin only)
export const triggerMatchmaking = functions.https.onCall(async (data, context) => {
  // Verify admin authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }
  
  try {
    // Check if user is admin
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();
    
    if (!userData?.isAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    
    console.log(`🔧 Manual matchmaking triggered by admin: ${context.auth.uid}`);
    await runWeeklyMatchmaking();
    
    return { success: true, message: 'Matchmaking completed successfully' };
    
  } catch (error) {
    console.error('❌ Manual matchmaking failed:', error);
    throw new functions.https.HttpsError('internal', error instanceof Error ? error.message : 'Unknown error');
  }
});

