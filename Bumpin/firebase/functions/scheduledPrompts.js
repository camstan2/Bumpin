/**
 * Firebase Cloud Functions for Daily Prompt Automation
 * 
 * These functions handle automatic activation and deactivation of daily prompts
 * based on their scheduled dates and expiration times.
 * 
 * DEPLOYMENT:
 * 1. Navigate to firebase/functions directory
 * 2. Run: npm install
 * 3. Run: firebase deploy --only functions
 * 
 * TESTING:
 * - Test locally: firebase emulators:start --only functions
 * - Trigger manually: gcloud scheduler jobs run dailyPromptScheduler
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Scheduled function that runs every 15 minutes to check for prompts to activate/deactivate
 * 
 * Cloud Scheduler will trigger this function automatically.
 * Configure in Firebase Console: Functions > Schedule
 */
exports.checkScheduledPrompts = functions.pubsub
  .schedule('every 15 minutes')
  .timeZone('America/New_York') // Set to your timezone
  .onRun(async (context) => {
    console.log('⏰ Running scheduled prompt check...');
    
    try {
      // Run both operations in parallel
      await Promise.all([
        activateScheduledPrompts(),
        deactivateExpiredPrompts()
      ]);
      
      console.log('✅ Scheduled prompt check completed successfully');
      return null;
    } catch (error) {
      console.error('❌ Error in scheduled prompt check:', error);
      throw error;
    }
  });

/**
 * Activate prompts that have reached their scheduled time
 */
async function activateScheduledPrompts() {
  console.log('🔍 Checking for scheduled prompts to activate...');
  
  const now = admin.firestore.Timestamp.now();
  
  try {
    // Query for prompts that should be activated
    const snapshot = await db.collection('dailyPrompts')
      .where('isActive', '==', false)
      .where('isArchived', '==', false)
      .where('date', '<=', now)
      .where('expiresAt', '>', now)
      .get();
    
    if (snapshot.empty) {
      console.log('   ℹ️  No scheduled prompts to activate');
      return;
    }
    
    console.log(`   Found ${snapshot.size} prompt(s) ready to activate`);
    
    // Sort by date to get the most recent one
    const prompts = [];
    snapshot.forEach(doc => {
      prompts.push({
        id: doc.id,
        date: doc.data().date,
        title: doc.data().title
      });
    });
    
    // Sort by date (most recent first)
    prompts.sort((a, b) => b.date.toMillis() - a.date.toMillis());
    
    if (prompts.length === 0) {
      console.log('   ⚠️  No valid prompts found after sorting');
      return;
    }
    
    const promptToActivate = prompts[0];
    console.log(`   🎯 Activating prompt: ${promptToActivate.id} - "${promptToActivate.title}"`);
    
    // Use a batch to ensure atomic operations
    const batch = db.batch();
    
    // First, deactivate all currently active prompts
    const activeSnapshot = await db.collection('dailyPrompts')
      .where('isActive', '==', true)
      .get();
    
    console.log(`   ⏸️  Deactivating ${activeSnapshot.size} currently active prompt(s)`);
    
    activeSnapshot.forEach(doc => {
      batch.update(doc.ref, { isActive: false });
    });
    
    // Activate the scheduled prompt
    const promptRef = db.collection('dailyPrompts').doc(promptToActivate.id);
    batch.update(promptRef, {
      isActive: true,
      date: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Commit the batch
    await batch.commit();
    
    console.log(`   ✅ Successfully activated prompt: ${promptToActivate.id}`);
    
    // Optional: Send notifications to users
    // await sendPromptNotification(promptToActivate);
    
  } catch (error) {
    console.error('   ❌ Error activating scheduled prompts:', error);
    throw error;
  }
}

/**
 * Deactivate prompts that have expired
 */
async function deactivateExpiredPrompts() {
  console.log('🔍 Checking for expired prompts to deactivate...');
  
  const now = admin.firestore.Timestamp.now();
  
  try {
    // Query for active prompts that have expired
    const snapshot = await db.collection('dailyPrompts')
      .where('isActive', '==', true)
      .where('expiresAt', '<', now)
      .get();
    
    if (snapshot.empty) {
      console.log('   ℹ️  No expired prompts to deactivate');
      return;
    }
    
    console.log(`   Found ${snapshot.size} expired prompt(s) to deactivate`);
    
    // Use a batch for efficiency
    const batch = db.batch();
    
    snapshot.forEach(doc => {
      console.log(`   ⏸️  Deactivating expired prompt: ${doc.id}`);
      batch.update(doc.ref, { isActive: false });
    });
    
    // Commit the batch
    await batch.commit();
    
    console.log(`   ✅ Successfully deactivated ${snapshot.size} expired prompt(s)`);
    
  } catch (error) {
    console.error('   ❌ Error deactivating expired prompts:', error);
    throw error;
  }
}

/**
 * Optional: Manual trigger for testing
 * Call this function manually from Firebase Console for testing
 */
exports.manualCheckPrompts = functions.https.onCall(async (data, context) => {
  // Require admin authentication
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can manually trigger prompt checks'
    );
  }
  
  console.log('🔧 Manual prompt check triggered by:', context.auth.uid);
  
  try {
    await Promise.all([
      activateScheduledPrompts(),
      deactivateExpiredPrompts()
    ]);
    
    return { success: true, message: 'Prompt check completed successfully' };
  } catch (error) {
    console.error('❌ Error in manual prompt check:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Optional: Send push notifications when a new prompt is activated
 */
async function sendPromptNotification(prompt) {
  console.log('📢 Sending notification for new prompt:', prompt.title);
  
  // TODO: Implement push notification logic
  // Example using FCM:
  // const message = {
  //   notification: {
  //     title: '🎵 New Daily Prompt!',
  //     body: prompt.title
  //   },
  //   topic: 'daily_prompts'
  // };
  // 
  // await admin.messaging().send(message);
}

/**
 * Firestore trigger: When a prompt is created with immediate activation
 * This ensures immediate activation without waiting for the scheduled check
 */
exports.onPromptCreated = functions.firestore
  .document('dailyPrompts/{promptId}')
  .onCreate(async (snapshot, context) => {
    const prompt = snapshot.data();
    const promptId = context.params.promptId;
    
    // If prompt is set to be active immediately, ensure no other prompts are active
    if (prompt.isActive) {
      console.log(`🆕 New active prompt created: ${promptId} - "${prompt.title}"`);
      
      try {
        // Deactivate all other active prompts
        const activeSnapshot = await db.collection('dailyPrompts')
          .where('isActive', '==', true)
          .get();
        
        const batch = db.batch();
        let deactivatedCount = 0;
        
        activeSnapshot.forEach(doc => {
          if (doc.id !== promptId) {
            batch.update(doc.ref, { isActive: false });
            deactivatedCount++;
          }
        });
        
        if (deactivatedCount > 0) {
          await batch.commit();
          console.log(`   ⏸️  Deactivated ${deactivatedCount} other active prompt(s)`);
        }
        
      } catch (error) {
        console.error('   ❌ Error ensuring single active prompt:', error);
      }
    }
  });

/**
 * HTTP endpoint for manual testing (remove in production)
 */
exports.testPromptScheduler = functions.https.onRequest(async (req, res) => {
  try {
    await Promise.all([
      activateScheduledPrompts(),
      deactivateExpiredPrompts()
    ]);
    
    res.status(200).send({
      success: true,
      message: 'Prompt scheduler test completed'
    });
  } catch (error) {
    console.error('Error in test:', error);
    res.status(500).send({
      success: false,
      error: error.message
    });
  }
});

