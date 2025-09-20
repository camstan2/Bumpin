import * as admin from 'firebase-admin';

const db = admin.firestore();

// Types for matchmaking data structures
interface UserProfile {
  uid: string;
  email: string;
  username: string;
  displayName: string;
  matchmakingOptIn?: boolean;
  matchmakingGender?: string;
  matchmakingPreferredGender?: string;
  matchmakingLastActive?: admin.firestore.Timestamp;
}

interface MusicLog {
  id: string;
  userId: string;
  itemId: string;
  itemType: string;
  title: string;
  artistName: string;
  dateLogged: admin.firestore.Timestamp;
  rating?: number;
  primaryGenre?: string;
  appleMusicGenres?: string[];
  isPublic?: boolean;
}

interface WeeklyMatch {
  id: string;
  userId: string;
  matchedUserId: string;
  week: string;
  timestamp: admin.firestore.Timestamp;
  similarityScore: number;
  sharedArtists: string[];
  sharedGenres: string[];
  botMessageSent: boolean;
  userResponded: boolean;
  matchSuccess?: boolean;
}

interface UserMusicProfile {
  userId: string;
  logs: MusicLog[];
  artistFrequency: Record<string, number>;
  genreFrequency: Record<string, number>;
  averageRating: number;
  totalLogs: number;
  topArtists: string[];
  topGenres: string[];
  musicDiversity: number;
}

interface MatchmakingStats {
  week: string;
  totalEligibleUsers: number;
  totalMatches: number;
  averageSimilarityScore: number;
  responseRate: number;
  successRate: number;
  topSharedArtists: string[];
  topSharedGenres: string[];
  processingTime: number;
  timestamp: admin.firestore.Timestamp;
}

// Bot configuration
const BOT_USER_ID = 'matchmaking_bot_system';
const BOT_USERNAME = 'Bumpin Matchmaker';
const BOT_DISPLAY_NAME = '🎵 Bumpin Matchmaker';

/**
 * Main function to execute weekly matchmaking
 */
export async function runWeeklyMatchmaking(): Promise<void> {
  console.log('🎵 Starting weekly music matchmaking process...');
  
  const startTime = Date.now();
  const currentWeek = getCurrentWeekId();
  
  try {
    // Step 1: Get eligible users
    console.log('📊 Step 1: Getting eligible users...');
    const eligibleUsers = await getEligibleUsers();
    console.log(`Found ${eligibleUsers.count} eligible users for matchmaking`);
    
    if (eligibleUsers.count < 2) {
      console.log('⚠️ Not enough users for matchmaking (minimum 2 required)');
      return;
    }
    
    // Step 2: Load music profiles for eligible users
    console.log('🎼 Step 2: Loading music profiles...');
    const musicProfiles = await loadMusicProfiles(eligibleUsers.users);
    console.log(`Loaded ${Object.keys(musicProfiles).length} music profiles`);
    
    // Step 3: Generate compatible pairs based on gender preferences
    console.log('💑 Step 3: Filtering by gender preferences...');
    const compatiblePairs = filterByGenderPreferences(eligibleUsers.users);
    console.log(`Created ${compatiblePairs.length} potential gender-compatible pairs`);
    
    // Step 4: Calculate music similarities
    console.log('🎯 Step 4: Calculating music similarities...');
    const similarityResults = await calculateSimilaritiesForPairs(compatiblePairs, musicProfiles);
    console.log(`Calculated ${similarityResults.length} similarity scores`);
    
    // Step 5: Apply matching algorithm
    console.log('✨ Step 5: Applying matching algorithm...');
    const matches = await applyMatchingAlgorithm(similarityResults, currentWeek);
    console.log(`Generated ${matches.length} final matches`);
    
    // Step 6: Send bot messages
    console.log('🤖 Step 6: Sending matchmaking messages...');
    await sendMatchingMessages(matches, eligibleUsers.users);
    
    // Step 7: Generate and save statistics
    console.log('📈 Step 7: Generating statistics...');
    const processingTime = (Date.now() - startTime) / 1000;
    const stats = generateWeeklyStats(matches, eligibleUsers.count, processingTime, currentWeek);
    await saveWeeklyStats(stats);
    
    console.log(`✅ Weekly matchmaking complete! Generated ${matches.length / 2} unique matches in ${processingTime.toFixed(1)}s`);
    
  } catch (error) {
    console.error('❌ Weekly matchmaking failed:', error);
    throw error;
  }
}

/**
 * Get users who are eligible for matchmaking
 */
async function getEligibleUsers(): Promise<{ users: UserProfile[], count: number }> {
  const query = db.collection('users')
    .where('matchmakingOptIn', '==', true);
  
  const snapshot = await query.get();
  const users: UserProfile[] = [];
  
  for (const doc of snapshot.docs) {
    const userData = doc.data() as UserProfile;
    
    // Check if user has recent activity and sufficient music logs
    const hasRecentActivity = await checkUserHasRecentMusicActivity(userData.uid);
    const hasEnoughLogs = await checkUserHasMinimumLogs(userData.uid, 10);
    
    if (hasRecentActivity && hasEnoughLogs) {
      users.push(userData);
    }
  }
  
  return { users, count: users.length };
}

/**
 * Check if user has recent music activity (last 30 days)
 */
async function checkUserHasRecentMusicActivity(userId: string): Promise<boolean> {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const query = db.collection('logs')
    .where('userId', '==', userId)
    .where('dateLogged', '>', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .limit(1);
  
  const snapshot = await query.get();
  return !snapshot.empty;
}

/**
 * Check if user has minimum number of music logs
 */
async function checkUserHasMinimumLogs(userId: string, minimum: number): Promise<boolean> {
  const query = db.collection('logs')
    .where('userId', '==', userId)
    .limit(minimum);
  
  const snapshot = await query.get();
  return snapshot.docs.length >= minimum;
}

/**
 * Load music profiles for a list of users
 */
async function loadMusicProfiles(users: UserProfile[]): Promise<Record<string, UserMusicProfile>> {
  const profiles: Record<string, UserMusicProfile> = {};
  
  // Process users in batches to avoid overwhelming Firestore
  const batchSize = 10;
  for (let i = 0; i < users.length; i += batchSize) {
    const batch = users.slice(i, i + batchSize);
    
    await Promise.all(batch.map(async (user) => {
      const profile = await getUserMusicProfile(user.uid);
      if (profile) {
        profiles[user.uid] = profile;
      }
    }));
  }
  
  return profiles;
}

/**
 * Get music profile for a specific user
 */
async function getUserMusicProfile(userId: string): Promise<UserMusicProfile | null> {
  try {
    const query = db.collection('logs')
      .where('userId', '==', userId)
      .where('isPublic', 'in', [true, null]) // Only public logs for matchmaking
      .orderBy('dateLogged', 'desc')
      .limit(200); // Limit for performance
    
    const snapshot = await query.get();
    const logs: MusicLog[] = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    } as MusicLog));
    
    if (logs.length === 0) {
      return null;
    }
    
    return createUserMusicProfile(userId, logs);
    
  } catch (error) {
    console.error(`Error loading music profile for ${userId}:`, error);
    return null;
  }
}

/**
 * Create a user music profile from their logs
 */
function createUserMusicProfile(userId: string, logs: MusicLog[]): UserMusicProfile {
  // Calculate artist frequency
  const artistFreq: Record<string, number> = {};
  for (const log of logs) {
    artistFreq[log.artistName] = (artistFreq[log.artistName] || 0) + 1;
  }
  
  // Calculate genre frequency
  const genreFreq: Record<string, number> = {};
  for (const log of logs) {
    if (log.primaryGenre) {
      genreFreq[log.primaryGenre] = (genreFreq[log.primaryGenre] || 0) + 1;
    }
    if (log.appleMusicGenres) {
      for (const genre of log.appleMusicGenres) {
        genreFreq[genre] = (genreFreq[genre] || 0) + 1;
      }
    }
  }
  
  // Calculate average rating
  const ratingsOnly = logs.filter(log => log.rating !== undefined).map(log => log.rating!);
  const averageRating = ratingsOnly.length > 0 ? ratingsOnly.reduce((a, b) => a + b, 0) / ratingsOnly.length : 0;
  
  // Get top artists and genres
  const topArtists = Object.entries(artistFreq)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 10)
    .map(([artist]) => artist);
  
  const topGenres = Object.entries(genreFreq)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 5)
    .map(([genre]) => genre);
  
  // Calculate music diversity (simplified Shannon diversity)
  const musicDiversity = calculateDiversityIndex(artistFreq);
  
  return {
    userId,
    logs,
    artistFrequency: artistFreq,
    genreFrequency: genreFreq,
    averageRating,
    totalLogs: logs.length,
    topArtists,
    topGenres,
    musicDiversity
  };
}

/**
 * Calculate Shannon diversity index
 */
function calculateDiversityIndex(frequency: Record<string, number>): number {
  const total = Object.values(frequency).reduce((a, b) => a + b, 0);
  if (total === 0) return 0;
  
  let diversity = 0;
  for (const count of Object.values(frequency)) {
    const proportion = count / total;
    if (proportion > 0) {
      diversity -= proportion * Math.log2(proportion);
    }
  }
  
  // Normalize to 0-1 range
  const maxDiversity = Math.log2(Object.keys(frequency).length);
  return maxDiversity > 0 ? diversity / maxDiversity : 0;
}

/**
 * Filter users into compatible pairs based on gender preferences
 */
function filterByGenderPreferences(users: UserProfile[]): Array<[UserProfile, UserProfile]> {
  const compatiblePairs: Array<[UserProfile, UserProfile]> = [];
  
  for (let i = 0; i < users.length; i++) {
    for (let j = i + 1; j < users.length; j++) {
      const user1 = users[i];
      const user2 = users[j];
      
      if (areGenderCompatible(user1, user2)) {
        compatiblePairs.push([user1, user2]);
      }
    }
  }
  
  return compatiblePairs;
}

/**
 * Check if two users are gender compatible
 */
function areGenderCompatible(user1: UserProfile, user2: UserProfile): boolean {
  const user1Gender = user1.matchmakingGender || 'any';
  const user2Gender = user2.matchmakingGender || 'any';
  const user1Preference = user1.matchmakingPreferredGender || 'any';
  const user2Preference = user2.matchmakingPreferredGender || 'any';
  
  const user1Compatible = user1Preference === 'any' || user1Preference === user2Gender;
  const user2Compatible = user2Preference === 'any' || user2Preference === user1Gender;
  
  return user1Compatible && user2Compatible;
}

/**
 * Calculate music similarities for pairs
 */
async function calculateSimilaritiesForPairs(
  pairs: Array<[UserProfile, UserProfile]>, 
  musicProfiles: Record<string, UserMusicProfile>
): Promise<Array<{ pair: [UserProfile, UserProfile], similarity: number, sharedArtists: string[], sharedGenres: string[] }>> {
  const results: Array<{ pair: [UserProfile, UserProfile], similarity: number, sharedArtists: string[], sharedGenres: string[] }> = [];
  
  for (const pair of pairs) {
    const [user1, user2] = pair;
    const profile1 = musicProfiles[user1.uid];
    const profile2 = musicProfiles[user2.uid];
    
    if (profile1 && profile2) {
      const similarity = calculateMusicSimilarity(profile1, profile2);
      const sharedArtists = findSharedArtists(profile1, profile2);
      const sharedGenres = findSharedGenres(profile1, profile2);
      
      results.push({
        pair,
        similarity: similarity.overallScore,
        sharedArtists,
        sharedGenres
      });
    }
  }
  
  return results;
}

/**
 * Calculate music similarity between two profiles
 */
function calculateMusicSimilarity(profile1: UserMusicProfile, profile2: UserMusicProfile): { overallScore: number } {
  // Artist similarity (Jaccard coefficient)
  const artists1 = new Set(profile1.topArtists);
  const artists2 = new Set(profile2.topArtists);
  const artistIntersection = new Set([...artists1].filter(x => artists2.has(x)));
  const artistUnion = new Set([...artists1, ...artists2]);
  const artistSimilarity = artistUnion.size > 0 ? artistIntersection.size / artistUnion.size : 0;
  
  // Genre similarity
  const genres1 = new Set(profile1.topGenres);
  const genres2 = new Set(profile2.topGenres);
  const genreIntersection = new Set([...genres1].filter(x => genres2.has(x)));
  const genreUnion = new Set([...genres1, ...genres2]);
  const genreSimilarity = genreUnion.size > 0 ? genreIntersection.size / genreUnion.size : 0;
  
  // Rating correlation (simplified)
  const ratingDiff = Math.abs(profile1.averageRating - profile2.averageRating);
  const ratingCorrelation = Math.max(0, 1 - (ratingDiff / 4)); // Max diff is 4 (5-1)
  
  // Discovery potential
  const uniqueArtists = artistUnion.size - artistIntersection.size;
  const totalArtists = artistUnion.size;
  const discoveryPotential = totalArtists > 0 ? uniqueArtists / totalArtists : 0;
  
  // Weighted overall score
  const overallScore = (artistSimilarity * 0.4) + 
                      (genreSimilarity * 0.3) + 
                      (ratingCorrelation * 0.2) + 
                      (discoveryPotential * 0.1);
  
  return { overallScore };
}

/**
 * Find shared artists between two profiles
 */
function findSharedArtists(profile1: UserMusicProfile, profile2: UserMusicProfile): string[] {
  const artists1 = new Set(profile1.topArtists);
  const artists2 = new Set(profile2.topArtists);
  return [...artists1].filter(artist => artists2.has(artist));
}

/**
 * Find shared genres between two profiles
 */
function findSharedGenres(profile1: UserMusicProfile, profile2: UserMusicProfile): string[] {
  const genres1 = new Set(profile1.topGenres);
  const genres2 = new Set(profile2.topGenres);
  return [...genres1].filter(genre => genres2.has(genre));
}

/**
 * Apply matching algorithm to select final matches
 */
async function applyMatchingAlgorithm(
  similarityResults: Array<{ pair: [UserProfile, UserProfile], similarity: number, sharedArtists: string[], sharedGenres: string[] }>,
  week: string
): Promise<WeeklyMatch[]> {
  // Filter by minimum similarity threshold
  const qualifyingPairs = similarityResults.filter(result => result.similarity >= 0.6);
  
  // Sort by similarity score (highest first)
  const sortedPairs = qualifyingPairs.sort((a, b) => b.similarity - a.similarity);
  
  // Get previous matches to avoid duplicates
  const previousMatches = await getPreviousMatches(8); // 8-week cooldown
  const previousMatchPairs = new Set(previousMatches.map(match => `${match.userId}_${match.matchedUserId}`));
  
  // Apply match selection algorithm
  const finalMatches: WeeklyMatch[] = [];
  const matchedUserIds = new Set<string>();
  
  for (const result of sortedPairs) {
    const [user1, user2] = result.pair;
    
    // Skip if either user is already matched this week
    if (matchedUserIds.has(user1.uid) || matchedUserIds.has(user2.uid)) {
      continue;
    }
    
    // Skip if they've been matched recently
    const pairKey1 = `${user1.uid}_${user2.uid}`;
    const pairKey2 = `${user2.uid}_${user1.uid}`;
    if (previousMatchPairs.has(pairKey1) || previousMatchPairs.has(pairKey2)) {
      continue;
    }
    
    // Create matches for both users
    const match1: WeeklyMatch = {
      id: `${user1.uid}_${user2.uid}_${week}`,
      userId: user1.uid,
      matchedUserId: user2.uid,
      week,
      timestamp: admin.firestore.Timestamp.now(),
      similarityScore: result.similarity,
      sharedArtists: result.sharedArtists,
      sharedGenres: result.sharedGenres,
      botMessageSent: false,
      userResponded: false
    };
    
    const match2: WeeklyMatch = {
      id: `${user2.uid}_${user1.uid}_${week}`,
      userId: user2.uid,
      matchedUserId: user1.uid,
      week,
      timestamp: admin.firestore.Timestamp.now(),
      similarityScore: result.similarity,
      sharedArtists: result.sharedArtists,
      sharedGenres: result.sharedGenres,
      botMessageSent: false,
      userResponded: false
    };
    
    finalMatches.push(match1, match2);
    matchedUserIds.add(user1.uid);
    matchedUserIds.add(user2.uid);
  }
  
  // Save matches to database
  const batch = db.batch();
  for (const match of finalMatches) {
    const docRef = db.collection('weeklyMatches').doc(match.id);
    batch.set(docRef, match);
  }
  await batch.commit();
  
  return finalMatches;
}

/**
 * Get previous matches within specified weeks
 */
async function getPreviousMatches(weeks: number): Promise<WeeklyMatch[]> {
  const weeksAgo = new Date();
  weeksAgo.setDate(weeksAgo.getDate() - (weeks * 7));
  
  const query = db.collection('weeklyMatches')
    .where('timestamp', '>', admin.firestore.Timestamp.fromDate(weeksAgo));
  
  const snapshot = await query.get();
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as WeeklyMatch));
}

/**
 * Send matchmaking messages to users
 */
async function sendMatchingMessages(matches: WeeklyMatch[], users: UserProfile[]): Promise<void> {
  // Create user lookup map
  const userMap = new Map(users.map(user => [user.uid, user]));
  
  // Get unique matches (each pair is stored twice)
  const uniqueMatches = matches.filter((match, index, array) => 
    array.findIndex(m => m.userId === match.userId) === index
  );
  
  const batch = db.batch();
  
  for (const match of uniqueMatches) {
    const matchedUser = userMap.get(match.matchedUserId);
    if (!matchedUser) continue;
    
    try {
      // Create or get bot conversation
      const conversationId = await getOrCreateBotConversation(match.userId);
      
      // Generate personalized message
      const message = generateMatchMessage(matchedUser, match.sharedArtists);
      
      // Create bot message
      const messageId = db.collection('conversations').doc().id;
      const botMessage = {
        id: messageId,
        conversationId,
        senderId: BOT_USER_ID,
        text: message,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isSystem: true,
        messageType: 'bot_matchmaking',
        readBy: [BOT_USER_ID],
        matchmakingData: {
          matchedUserId: match.matchedUserId,
          matchedUsername: matchedUser.username,
          matchedDisplayName: matchedUser.displayName,
          sharedArtists: match.sharedArtists,
          sharedGenres: match.sharedGenres,
          similarityScore: match.similarityScore,
          weekId: match.week
        }
      };
      
      // Add message to batch
      const messageRef = db.collection('conversations').doc(conversationId).collection('messages').doc(messageId);
      batch.set(messageRef, botMessage);
      
      // Update conversation metadata
      const conversationRef = db.collection('conversations').doc(conversationId);
      batch.update(conversationRef, {
        lastMessage: message,
        lastTimestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Mark match as message sent
      const matchRef = db.collection('weeklyMatches').doc(match.id);
      batch.update(matchRef, { botMessageSent: true });
      
    } catch (error) {
      console.error(`Error creating match message for ${match.userId}:`, error);
    }
  }
  
  await batch.commit();
}

/**
 * Get or create bot conversation with user
 */
async function getOrCreateBotConversation(userId: string): Promise<string> {
  const participantKey = [BOT_USER_ID, userId].sort().join('_');
  
  // Check if conversation exists
  const query = db.collection('conversations')
    .where('participantKey', '==', participantKey)
    .limit(1);
  
  const snapshot = await query.get();
  
  if (!snapshot.empty) {
    return snapshot.docs[0].id;
  }
  
  // Create new conversation
  const conversationId = db.collection('conversations').doc().id;
  const conversation = {
    id: conversationId,
    participantIds: [BOT_USER_ID, userId],
    participantKey,
    inboxFor: [userId], // Bot conversations appear in user's inbox immediately
    requestFor: [], // No request needed for bot conversations
    lastMessage: null,
    lastTimestamp: null,
    lastReadAtByUser: {},
    conversationType: 'bot'
  };
  
  await db.collection('conversations').doc(conversationId).set(conversation);
  return conversationId;
}

/**
 * Generate personalized match message
 */
function generateMatchMessage(matchedUser: UserProfile, sharedArtists: string[]): string {
  const firstName = matchedUser.displayName.split(' ')[0] || matchedUser.username;
  
  let message = `🎵 You should connect with ${firstName}! `;
  
  if (sharedArtists.length > 0) {
    if (sharedArtists.length === 1) {
      message += `You both love ${sharedArtists[0]}.`;
    } else if (sharedArtists.length === 2) {
      message += `You both love ${sharedArtists[0]} and ${sharedArtists[1]}.`;
    } else {
      const firstTwo = sharedArtists.slice(0, 2).join(', ');
      message += `You both love ${firstTwo}, and ${sharedArtists.length - 2} other artists.`;
    }
  } else {
    message += 'You have similar music taste!';
  }
  
  message += '\n\nTap their name to start a conversation! 💬';
  
  return message;
}

/**
 * Generate weekly statistics
 */
function generateWeeklyStats(matches: WeeklyMatch[], totalEligibleUsers: number, processingTime: number, week: string): MatchmakingStats {
  const uniqueMatches = matches.length / 2; // Each match is stored twice
  
  const averageSimilarity = matches.length > 0 ? 
    matches.reduce((sum, match) => sum + match.similarityScore, 0) / matches.length : 0;
  
  // Get top shared artists and genres
  const allSharedArtists = matches.flatMap(match => match.sharedArtists);
  const allSharedGenres = matches.flatMap(match => match.sharedGenres);
  
  const artistCounts: Record<string, number> = {};
  for (const artist of allSharedArtists) {
    artistCounts[artist] = (artistCounts[artist] || 0) + 1;
  }
  
  const genreCounts: Record<string, number> = {};
  for (const genre of allSharedGenres) {
    genreCounts[genre] = (genreCounts[genre] || 0) + 1;
  }
  
  const topArtists = Object.entries(artistCounts)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 10)
    .map(([artist]) => artist);
  
  const topGenres = Object.entries(genreCounts)
    .sort(([,a], [,b]) => b - a)
    .slice(0, 5)
    .map(([genre]) => genre);
  
  return {
    week,
    totalEligibleUsers,
    totalMatches: uniqueMatches,
    averageSimilarityScore: averageSimilarity,
    responseRate: 0.0, // Will be calculated later based on user responses
    successRate: 0.0, // Will be calculated later based on connections
    topSharedArtists: topArtists,
    topSharedGenres: topGenres,
    processingTime,
    timestamp: admin.firestore.Timestamp.now()
  };
}

/**
 * Save weekly statistics to Firestore
 */
async function saveWeeklyStats(stats: MatchmakingStats): Promise<void> {
  try {
    await db.collection('matchmakingStats').doc(stats.week).set(stats);
    console.log('✅ Saved weekly matchmaking statistics');
  } catch (error) {
    console.error('❌ Error saving weekly stats:', error);
  }
}

/**
 * Get current week identifier (format: YYYY-W##)
 */
function getCurrentWeekId(): string {
  const now = new Date();
  const year = now.getFullYear();
  
  // Calculate week number
  const start = new Date(year, 0, 1);
  const days = Math.floor((now.getTime() - start.getTime()) / (24 * 60 * 60 * 1000));
  const weekNumber = Math.ceil((days + start.getDay() + 1) / 7);
  
  return `${year}-W${weekNumber.toString().padStart(2, '0')}`;
}
