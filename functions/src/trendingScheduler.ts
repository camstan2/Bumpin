import * as admin from 'firebase-admin';

function getDb() {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  return admin.firestore();
}

// Minimal interface used by this Cloud Function
interface TrendingTopic {
  id: string
  title: string
  description: string | null
  category: TopicCategory
  keywords: string[]
  source: 'ai' | 'manual' | 'user' | 'external' | 'community'
  popularity: number
  discussionCount: number
  participantCount: number
  messageCount: number
  createdAt: Date | admin.firestore.FieldValue
  lastUpdated: Date | admin.firestore.FieldValue
  lastActivity: Date | null
  isActive: boolean
  priority: number
  expiresAt: Date | null
  externalUrl: string | null
  externalId: string | null
  qualityScore: number
  reportCount: number
  isVerified: boolean
}

type TopicCategory =
  | 'trending'
  | 'movies'
  | 'sports'
  | 'gaming'
  | 'music'
  | 'entertainment'
  | 'politics'
  | 'business'
  | 'arts'
  | 'food'
  | 'lifestyle'
  | 'education'
  | 'science'
  | 'worldNews'
  | 'health'
  | 'automotive';

const ALL_CATEGORIES: TopicCategory[] = [
  'trending',
  'movies',
  'sports',
  'gaming',
  'music',
  'entertainment',
  'politics',
  'business',
  'arts',
  'food',
  'lifestyle',
  'education',
  'science',
  'worldNews',
  'health',
  'automotive',
];

function subredditsFor(category: TopicCategory): string[] {
  switch (category) {
    case 'trending':
      return ['popular', 'all', 'todayilearned', 'askreddit', 'news'];
    case 'movies':
      return ['movies', 'television', 'netflix', 'marvelstudios', 'dc_cinematic'];
    case 'sports':
      return ['sports', 'nfl', 'nba', 'soccer', 'baseball', 'hockey'];
    case 'gaming':
      return ['gaming', 'games', 'pcgaming', 'nintendo', 'ps5', 'xbox'];
    case 'music':
      return ['music', 'hiphopheads', 'popheads', 'listentothis'];
    case 'entertainment':
      return ['entertainment', 'celebrity', 'popculture', 'television', 'funny'];
    case 'politics':
      return ['politics', 'worldnews', 'politicaldiscussion', 'neutralpolitics'];
    case 'business':
      return ['business', 'entrepreneur', 'investing', 'stocks', 'economics'];
    case 'arts':
      return ['art', 'design', 'photography', 'architecture'];
    case 'food':
      return ['food', 'cooking', 'recipes', 'foodporn', 'askculinary'];
    case 'lifestyle':
      return ['lifestyle', 'lifehacks', 'getmotivated', 'selfimprovement'];
    case 'education':
      return ['education', 'teachers', 'studytips', 'university', 'learnprogramming'];
    case 'science':
      return ['science', 'technology', 'futurology', 'space', 'askscience'];
    case 'worldNews':
      return ['worldnews', 'news', 'europe', 'asia'];
    case 'health':
      return ['health', 'fitness', 'loseit', 'mentalhealth', 'nutrition'];
    case 'automotive':
      return ['cars', 'automotive', 'electricvehicles', 'teslamotors', 'formula1'];
  }
}

interface RedditChild { data: RedditPost }
interface RedditPost {
  title: string
  selftext?: string
  score: number
  num_comments: number
  created_utc: number
  subreddit: string
  permalink: string
  url?: string
}

function computePopularity(p: RedditPost): number {
  const scoreWeight = 0.6;
  const commentWeight = 0.3;
  const recencyWeight = 0.1;
  const normalizedScore = Math.min(1, p.score / 10000);
  const normalizedComments = Math.min(1, p.num_comments / 1000);
  const hoursAgo = (Date.now() / 1000 - p.created_utc) / 3600;
  const recencyScore = Math.max(0, 1 - hoursAgo / 24);
  return (
    normalizedScore * scoreWeight +
    normalizedComments * commentWeight +
    recencyScore * recencyWeight
  );
}

function cleanTitle(title: string): string {
  const prefixes = ['[Serious]', '[Discussion]', '[Question]', 'ELI5:', 'TIL:', 'PSA:', 'AMA:', 'TIFU:'];
  let t = title;
  for (const p of prefixes) t = t.replace(p, '').trim();
  if (t.length > 80) t = t.slice(0, 77) + '...';
  return t;
}

function extractKeywords(post: RedditPost): string[] {
  const common = new Set([
    'the','and','or','but','in','on','at','to','for','of','with','by','from','about','into','through','during','before','after','above','below','up','down','out','off','over','under','again','further','then','once','here','there','when','where','why','how','all','any','both','each','few','more','most','other','some','such','no','nor','not','only','own','same','so','than','too','very','can','will','just','should','now','what','this','that','these','those','they','them','their','would','could','should','might','must','shall','may','need','want'
  ]);
  const text = (post.title + ' ' + (post.selftext || '')).toLowerCase();
  return text
    .split(/\s+/)
    .filter(w => w.length > 3 && !common.has(w))
    .slice(0, 5);
}

async function fetchSubreddit(sub: string, limit: number): Promise<RedditPost[]> {
  const url = `https://www.reddit.com/r/${sub}/hot.json?limit=${limit}&raw_json=1`;
  const res = await fetch(url, { 
    headers: { 
      'User-Agent': 'Mozilla/5.0 (compatible; BumpinBot/1.0)',
      'Accept': 'application/json'
    } 
  });
  if (!res.ok) throw new Error(`Reddit ${sub} ${res.status}`);
  const json = await res.json();
  const children: RedditChild[] = json?.data?.children || [];
  return children.map(c => c.data);
}

function makeId(category: string, title: string): string {
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40);
  return `${category}_${slug}`;
}

function generateFallbackTopics(category: TopicCategory): TrendingTopic[] {
  const fallbackTopics: Record<TopicCategory, string[]> = {
    trending: ["What's trending today", "Viral moments", "Breaking news", "Hot takes"],
    movies: ["Latest releases", "Oscar buzz", "Marvel vs DC", "Netflix hits"],
    sports: ["Game highlights", "Trade rumors", "Player performances", "Season predictions"],
    gaming: ["New releases", "Gaming tips", "Esports tournaments", "Hardware news"],
    music: ["New albums", "Concert experiences", "Music discovery", "Artist collabs"],
    entertainment: ["Celebrity news", "Award shows", "TV finales", "Entertainment gossip"],
    politics: ["Current events", "Policy discussions", "Election updates", "Political analysis"],
    business: ["Market trends", "Startup news", "Tech earnings", "Economic updates"],
    arts: ["Art exhibitions", "Creative projects", "Artist spotlights", "Cultural events"],
    food: ["Recipe sharing", "Restaurant reviews", "Food trends", "Cooking tips"],
    lifestyle: ["Wellness tips", "Life hacks", "Personal growth", "Productivity"],
    education: ["Learning resources", "Study tips", "Academic discussions", "Online courses"],
    science: ["Scientific breakthroughs", "Tech innovations", "Research findings", "Future tech"],
    worldNews: ["Global events", "International news", "World politics", "Cultural exchanges"],
    health: ["Fitness routines", "Mental health", "Nutrition advice", "Wellness trends"],
    automotive: ["Car reviews", "Auto shows", "Electric vehicles", "Racing updates"]
  };

  return fallbackTopics[category].map((title, index) => ({
    id: makeId(category, title),
    title,
    description: `AI-generated trending topic for ${category}`,
    category,
    keywords: [title.toLowerCase()],
    source: 'ai' as const,
    popularity: 0.5 + (index * 0.1),
    discussionCount: 0,
    participantCount: 0,
    messageCount: 0,
    createdAt: new Date(),
    lastUpdated: new Date(),
    lastActivity: null,
    isActive: true,
    priority: 3,
    expiresAt: null,
    externalUrl: null,
    externalId: null,
    qualityScore: 0.5,
    reportCount: 0,
    isVerified: false,
  }));
}

export async function runTrendingUpdateOnce() {
  console.log('🚀 Starting trending topics update...');
  const db = getDb();
  
  // Generate topics for all enabled categories
  for (const category of ALL_CATEGORIES) {
    console.log(`📝 Generating topics for ${category}...`);
    const topics = generateFallbackTopics(category).slice(0, 10);

    const batch = db.batch();
    for (const topic of topics) {
      const ref = db.collection('trendingTopics').doc(topic.id);
      batch.set(ref, {
        ...topic,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
    console.log(`✅ Added ${topics.length} topics for ${category}`);
  }
  console.log('🎉 Trending topics update completed!');
}


