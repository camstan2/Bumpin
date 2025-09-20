# Daily Prompts Feature - Setup Guide

## Phase 1 Complete: Data Architecture & Models ✅

### Files Created

1. **`DailyPrompt.swift`** - Core data models and Firestore operations
2. **`PromptResponseInteractions.swift`** - Like/comment system for responses
3. **`PromptTemplates.swift`** - Pre-built prompt templates and generation helpers
4. **`firestore.rules`** - Updated security rules for new collections

### Data Models Overview

#### Core Models
- `DailyPrompt` - The daily question/theme
- `PromptResponse` - User's song selection + explanation
- `PromptLeaderboard` - Aggregated results and rankings
- `SongRanking` - Individual song performance in leaderboard

#### Interaction Models
- `PromptResponseLike` - Users can like responses
- `PromptResponseComment` - Users can comment on responses
- `PromptResponseCommentLike` - Users can like comments

#### Template & Analytics Models
- `PromptTemplate` - Reusable prompt templates
- `PromptStats` - Analytics and engagement metrics
- `UserPromptStats` - Individual user statistics and streaks

### Firebase Collections Structure

```
/dailyPrompts/{promptId}
├── id: String
├── title: String
├── description: String?
├── date: Date
├── isActive: Bool
├── category: PromptCategory
├── totalResponses: Int
└── featuredSongs: [String]

/promptResponses/{responseId}
├── promptId: String
├── userId: String
├── songId: String (Apple Music ID)
├── songTitle: String
├── artistName: String
├── explanation: String?
├── submittedAt: Date
├── likeCount: Int
└── commentCount: Int

/promptLeaderboards/{promptId}
├── songRankings: [SongRanking]
├── totalResponses: Int
├── lastUpdated: Date
└── topGenres: [String]

/promptResponseLikes/{likeId}
├── responseId: String
├── userId: String
└── createdAt: Date

/promptResponseComments/{commentId}
├── responseId: String
├── userId: String
├── text: String
├── createdAt: Date
└── likeCount: Int
```

### Required Firebase Indexes

Add these composite indexes to Firestore:

```javascript
// Collection: promptResponses
// Fields: promptId (Ascending), isPublic (Ascending), submittedAt (Descending)

// Collection: promptResponses  
// Fields: promptId (Ascending), isHidden (Ascending), submittedAt (Descending)

// Collection: promptResponseLikes
// Fields: responseId (Ascending), userId (Ascending)

// Collection: promptResponseComments
// Fields: responseId (Ascending), isHidden (Ascending), createdAt (Ascending)

// Collection: dailyPrompts
// Fields: isActive (Ascending), isArchived (Ascending), date (Descending)

// Collection: dailyPrompts
// Fields: category (Ascending), date (Descending)
```

### Security Rules Added

- **Daily Prompts**: Public read access, admin-only write
- **Prompt Responses**: Users can create their own, read public ones
- **Leaderboards**: Public read access, admin/system write only
- **Likes/Comments**: Standard social interaction permissions
- **Templates**: Admin-only access for management

### Prompt Categories

10 categories with associated icons and colors:
- 🙂 **Mood** - Emotional state prompts
- 🏃 **Activity** - Situation-based prompts  
- 🔄 **Nostalgia** - Memory and throwback prompts
- 🎵 **Genre** - Music style specific prompts
- 🍃 **Season** - Weather and seasonal prompts
- ❤️ **Emotion** - Feeling-based prompts
- 🔍 **Discovery** - Hidden gems and new finds
- 👥 **Social** - Group and relationship prompts
- ⭐ **Special** - Holiday and event prompts
- 🔀 **Random** - Creative and abstract prompts

### Sample Prompt Templates

50+ pre-built prompt templates across all categories, including:

**Popular Examples:**
- "First song you play on vacation"
- "Your go-to workout anthem" 
- "Song that instantly cheers you up"
- "Song that takes you back to high school"
- "Best song to sing with friends"
- "Hidden gem that deserves more recognition"

**Smart Generation:**
- Seasonal prompts based on current month
- Weekday-specific prompts (Monday motivation, Friday celebration)
- Holiday-aware prompts (Valentine's, Halloween, Christmas)

### Next Steps - Phase 2

1. **Backend Service Layer**
   - `DailyPromptService` - Core CRUD operations
   - Real-time listeners for active prompts
   - Leaderboard calculation logic
   - Analytics integration

2. **Admin Management**
   - Prompt creation interface
   - Scheduling system
   - Analytics dashboard
   - Content moderation tools

3. **Cloud Functions** (Optional but Recommended)
   - Automatic prompt activation/deactivation
   - Leaderboard aggregation
   - Push notifications for new prompts
   - Response analytics calculation

### Integration Points

**Existing Systems:**
- Uses `MusicManager` for song selection
- Integrates with `AnalyticsService` for tracking
- Follows existing Firebase patterns
- Leverages current user authentication
- Compatible with social feed architecture

**Apple Music Integration:**
- Stores Apple Music song IDs
- Caches song metadata (title, artist, artwork)
- Supports deep linking to Apple Music
- Uses existing search functionality

### Performance Considerations

**Caching Strategy:**
- Active prompt cached locally
- Leaderboard results cached with TTL
- User response status cached
- Template library cached on app start

**Real-time Updates:**
- Live leaderboard updates
- Response count updates
- New prompt notifications
- Friend response notifications

### Content Moderation

**Automated:**
- Text filtering for explanations
- Spam detection for repeated responses
- Rate limiting for submissions

**Manual:**
- Admin review queue
- User reporting system
- Hidden/archived response management
- Community guidelines enforcement

This completes Phase 1 of the Daily Prompts feature implementation. The data architecture is production-ready and follows your app's existing patterns and conventions.
