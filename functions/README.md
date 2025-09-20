Setup

1) Node 20 and Firebase CLI installed.
2) From functions/:
   - Copy env: set LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET as runtime env or use `firebase functions:config:set livekit.url=... livekit.key=... livekit.secret=...`.
   - Install deps: `npm install`
   - Build: `npm run build`
   - Emulate: `npm run serve`

Endpoints (region us-central1)
- POST /api/dj/live/create {title, artworkURL?}  (Auth: Firebase ID token)
- POST /api/livekit/token {sessionId, role:"publisher"|"listener"}  (Auth)
- POST /api/dj/live/stop {sessionId}  (Auth)
- POST /api/webhooks/livekit (LiveKit webhook target)

Firestore
- liveDJSessions/{sessionId}: hostId, roomName, title, artworkURL, isLive, listenerCount, createdAt, startedAt, endedAt, visibility

