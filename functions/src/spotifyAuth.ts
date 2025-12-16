import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import * as https from 'https';

// Spotify Configuration
// These will be set via: firebase functions:config:set spotify.client_id="..." spotify.client_secret="..."
const getSpotifyConfig = () => {
  const clientId = process.env.SPOTIFY_CLIENT_ID || functions.config().spotify?.client_id;
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET || functions.config().spotify?.client_secret;
  
  if (!clientId || !clientSecret) {
    console.error('❌ Spotify configuration missing. Set via firebase functions:config:set');
    throw new functions.https.HttpsError('failed-precondition', 'Spotify not configured');
  }
  
  return { clientId, clientSecret };
};

const SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token';
const SPOTIFY_ACCOUNTS_URL = 'https://accounts.spotify.com';

// Helper to authenticate user from request
async function authenticate(context: functions.https.CallableContext): Promise<string> {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }
  return context.auth.uid;
}

// Helper to make Spotify token requests
async function makeSpotifyTokenRequest(body: string, config: { clientId: string; clientSecret: string }): Promise<any> {
  const credentials = Buffer.from(`${config.clientId}:${config.clientSecret}`).toString('base64');
  
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'accounts.spotify.com',
      path: '/api/token',
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode !== 200) {
          console.error('❌ Spotify API Error:', res.statusCode, data);
          reject(new functions.https.HttpsError('internal', `Spotify API error: ${res.statusCode}`));
        } else {
          resolve(JSON.parse(data));
        }
      });
    });

    req.on('error', (error) => {
      console.error('❌ Spotify API Request Error:', error);
      reject(new functions.https.HttpsError('internal', 'Failed to connect to Spotify'));
    });

    req.write(body);
    req.end();
  });
}

/**
 * Get Spotify Client Credentials Token
 * Used for: Search, Browse, Public Data
 * Rate Limit: Per-user basis via Firestore cache
 */
export const getSpotifyClientToken = functions.https.onCall(async (data, context) => {
  try {
    // Authenticate user
    await authenticate(context);
    
    const config = getSpotifyConfig();
    
    // Make token request
    const tokenData = await makeSpotifyTokenRequest(
      'grant_type=client_credentials',
      config
    );
    
    console.log('✅ Spotify client token generated successfully');
    
    return {
      accessToken: tokenData.access_token,
      expiresIn: tokenData.expires_in,
      tokenType: tokenData.token_type,
    };
    
  } catch (error) {
    console.error('❌ getSpotifyClientToken error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to get Spotify token');
  }
});

/**
 * Exchange Spotify Authorization Code for Tokens
 * Used for: User Authentication Flow
 * Called after user grants permission via Spotify OAuth
 */
export const exchangeSpotifyCode = functions.https.onCall(async (data, context) => {
  try {
    // Authenticate user
    const userId = await authenticate(context);
    
    const { code, redirectUri } = data;
    
    if (!code || !redirectUri) {
      throw new functions.https.HttpsError('invalid-argument', 'code and redirectUri required');
    }
    
    const config = getSpotifyConfig();
    
    // Exchange code for tokens
    const tokenData = await makeSpotifyTokenRequest(
      `grant_type=authorization_code&code=${encodeURIComponent(code)}&redirect_uri=${encodeURIComponent(redirectUri)}`,
      config
    );
    
    // Store refresh token securely in Firestore (user's private document)
    const db = admin.firestore();
    await db.collection('users').doc(userId).collection('private').doc('spotify').set({
      refreshToken: tokenData.refresh_token,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    console.log(`✅ Spotify code exchanged for user: ${userId}`);
    
    return {
      accessToken: tokenData.access_token,
      expiresIn: tokenData.expires_in,
      refreshToken: tokenData.refresh_token, // Return once, app stores it
      tokenType: tokenData.token_type,
      scope: tokenData.scope,
    };
    
  } catch (error) {
    console.error('❌ exchangeSpotifyCode error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to exchange Spotify code');
  }
});

/**
 * Refresh Spotify User Access Token
 * Used for: Renewing expired user tokens
 * Uses refresh token stored in Firestore
 */
export const refreshSpotifyToken = functions.https.onCall(async (data, context) => {
  try {
    // Authenticate user
    const userId = await authenticate(context);
    
    const { refreshToken } = data;
    
    if (!refreshToken) {
      throw new functions.https.HttpsError('invalid-argument', 'refreshToken required');
    }
    
    const config = getSpotifyConfig();
    
    // Refresh the token
    const tokenData = await makeSpotifyTokenRequest(
      `grant_type=refresh_token&refresh_token=${encodeURIComponent(refreshToken)}`,
      config
    );
    
    console.log(`✅ Spotify token refreshed for user: ${userId}`);
    
    return {
      accessToken: tokenData.access_token,
      expiresIn: tokenData.expires_in,
      tokenType: tokenData.token_type,
      scope: tokenData.scope,
    };
    
  } catch (error) {
    console.error('❌ refreshSpotifyToken error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to refresh Spotify token');
  }
});

/**
 * Get Spotify Authorization URL
 * Returns the URL to redirect user to for Spotify OAuth
 */
export const getSpotifyAuthUrl = functions.https.onCall(async (data, context) => {
  try {
    // Authenticate user
    await authenticate(context);
    
    const { redirectUri, state, scopes } = data;
    
    if (!redirectUri) {
      throw new functions.https.HttpsError('invalid-argument', 'redirectUri required');
    }
    
    const config = getSpotifyConfig();
    
    const scopeString = scopes?.join(' ') || 'user-read-private user-read-email user-library-read playlist-read-private';
    
    const params = new URLSearchParams({
      client_id: config.clientId,
      response_type: 'code',
      redirect_uri: redirectUri,
      scope: scopeString,
      ...(state && { state }),
    });
    
    const authUrl = `${SPOTIFY_ACCOUNTS_URL}/authorize?${params.toString()}`;
    
    console.log('✅ Spotify auth URL generated');
    
    return { authUrl };
    
  } catch (error) {
    console.error('❌ getSpotifyAuthUrl error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', 'Failed to generate auth URL');
  }
});

