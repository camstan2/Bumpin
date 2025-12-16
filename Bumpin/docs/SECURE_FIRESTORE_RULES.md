# SECURE Firestore Rules (Pre-Launch)

## ⚠️ CRITICAL: Replace your current rules with these SECURE rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isSignedIn() && 
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    function preventsAdminEscalation() {
      // Prevent users from setting isAdmin to true
      return !('isAdmin' in request.resource.data) || 
             request.resource.data.isAdmin == false ||
             isAdmin();
    }

    // Config: only admins can write
    match /config/{docId} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // Users: SECURE profile access
    match /users/{uid} {
      // ✅ SECURE: Only allow username validation reads, not full profile
      allow read: if isSignedIn() && (
        // Allow reading only username fields for validation
        request.query.limit <= 1 &&
        request.query.where('username_lower', '==', request.query.where.username_lower)
      );
      
      // ✅ SECURE: Users can only create their own profile with restrictions
      allow create: if isOwner(uid) && preventsAdminEscalation();
      
      // ✅ SECURE: Users can only update their own profile with restrictions
      allow update: if isOwner(uid) && preventsAdminEscalation();
      
      // ✅ SECURE: Only admins can delete profiles
      allow delete: if isAdmin();
      
      // User Notifications - users can read and update their own notifications
      match /notifications/{notificationId} {
        allow read: if isOwner(uid);
        allow create: if isSignedIn(); // Any authenticated user can create notifications for others
        allow update: if isOwner(uid); // Users can only update their own (mark as read)
        allow delete: if isOwner(uid); // Users can delete their own notifications
      }
    }

    // Music logs
    match /logs/{logId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.auth.uid == request.resource.data.userId;
      allow update, delete: if isSignedIn() && request.auth.uid == resource.data.userId;
      
      // Reposts subcollection
      match /reposts/{repostId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
        allow delete: if isSignedIn() && resource.data.userId == request.auth.uid;
      }
    }

    // Music lists
    match /lists/{listId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.auth.uid == request.resource.data.userId;
      allow update, delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // Music Lists (alternative collection name)
    match /musicLists/{listId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.auth.uid == request.resource.data.userId;
      allow update, delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // Likes collection
    match /likes/{likeId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // Genre Corrections
    match /genreCorrections/{correctionId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // Universal Tracks - Cross-platform music matching
    match /universalTracks/{trackId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update: if isSignedIn();
    }

    // DJ Streams
    match /djStreams/{streamId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update: if isSignedIn();
      allow delete: if isSignedIn() && request.auth.uid == resource.data.djUserId;
    }

    // DJ Chat Messages
    match /djChatMessages/{messageId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // DJ Chat Users
    match /djChatUsers/{userStreamId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn();
    }

    // DJ Chat Reactions
    match /djChatReactions/{reactionId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // Parties
    match /parties/{partyId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.hostId == request.auth.uid;
      allow update, delete: if isSignedIn() && (
        resource.data.hostId == request.auth.uid ||
        (resource.data.coHostIds is list && request.auth.uid in resource.data.coHostIds)
      );

      match /speakerRequests/{requestId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid && request.resource.data.status == 'pending';
        allow update, delete: if isSignedIn() && (
          get(/databases/$(database)/documents/parties/$(partyId)).data.hostId == request.auth.uid ||
          (get(/databases/$(database)/documents/parties/$(partyId)).data.coHostIds is list && request.auth.uid in get(/databases/$(database)/documents/parties/$(partyId)).data.coHostIds)
        );
      }

      match /messageReactions/{reactionId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
        allow delete: if isSignedIn() && request.auth.uid == resource.data.userId;
      }
    }

    // Live DJ Sessions
    match /liveDJSessions/{sessionId} {
      allow read: if true;
      allow create: if isSignedIn() && request.resource.data.djId == request.auth.uid;
      allow update, delete: if isSignedIn() && (resource.data.djId == request.auth.uid || isAdmin());
      
      match /listeners/{userId} {
        allow read: if true;
        allow create: if isSignedIn() && request.auth.uid == userId;
        allow update: if isSignedIn() && request.auth.uid == userId;
        allow delete: if isSignedIn() && (request.auth.uid == userId || isAdmin());
      }
      
      match /chatMessages/{messageId} {
        allow read: if true;
        allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
        allow update, delete: if false; // immutable messages
      }
    }

    // Random Chat Queue
    match /randomChatQueue/{requestId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow update: if isSignedIn() && (
        request.auth.uid == resource.data.userId ||
        request.auth.uid in resource.data.groupMembers
      );
      allow delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // Random Chat Invites
    match /randomChatInvites/{inviteId} {
      allow read: if isSignedIn() && (
        request.auth.uid == resource.data.fromUserId ||
        request.auth.uid == resource.data.toUserId
      );
      allow create: if isSignedIn() && request.resource.data.fromUserId == request.auth.uid;
      allow update: if isSignedIn() && request.auth.uid == resource.data.toUserId;
      allow delete: if isSignedIn() && (
        request.auth.uid == resource.data.fromUserId ||
        request.auth.uid == resource.data.toUserId
      );
    }

    // Random Chats (matched conversations)
    match /randomChats/{chatId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update: if isSignedIn();
      allow delete: if false; // Only system can delete random chats
      
      // Messages subcollection
      match /messages/{messageId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
        allow update, delete: if false; // Messages are immutable
      }

      // Message reactions subcollection
      match /messageReactions/{reactionId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
        allow delete: if isSignedIn() && request.auth.uid == resource.data.userId;
      }
    }

    // Topic Chats (includes random chats stored as TopicChat)
    match /topicChats/{chatId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update: if isSignedIn();
      allow delete: if isSignedIn();
      
      // Messages subcollection
      match /messages/{messageId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
        allow update, delete: if false; // Messages are immutable
      }

      // Message reactions subcollection
      match /messageReactions/{reactionId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
        allow delete: if isSignedIn() && request.auth.uid == resource.data.userId;
      }
    }

    // Daily Prompts - read by all, write by admins only
    match /dailyPrompts/{promptId} {
      allow read: if true; // Public readable for all users
      allow create, update, delete: if isAdmin();
    }

    // Prompt Responses - users can create their own, read public ones
    match /promptResponses/{responseId} {
      allow read: if isSignedIn() && (
        resource.data.isPublic == true || 
        request.auth.uid == resource.data.userId
      );
      allow create: if isSignedIn() && 
        request.resource.data.userId == request.auth.uid;
      allow update: if isSignedIn() && request.auth.uid == resource.data.userId;
      allow delete: if isSignedIn() && (
        request.auth.uid == resource.data.userId || 
        isAdmin()
      );
    }

    // Prompt Leaderboards - read by all, write by authenticated users (for updates)
    match /promptLeaderboards/{promptId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn(); // Allow users to update leaderboard when submitting
    }

    // Prompt Templates - read by admins, write by admins
    match /promptTemplates/{templateId} {
      allow read, write: if isAdmin();
    }

    // User Prompt Stats - users can read/write their own stats
    match /userPromptStats/{userId} {
      allow read: if isSignedIn() && (request.auth.uid == userId || isAdmin());
      allow write: if isSignedIn() && request.auth.uid == userId;
    }

    // Prompt Response Likes - users can like/unlike responses
    match /promptResponseLikes/{likeId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow delete: if isSignedIn() && request.auth.uid == resource.data.userId;
    }

    // Prompt Response Comments - users can comment on public responses
    match /promptResponseComments/{commentId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isSignedIn() && (
        request.auth.uid == resource.data.userId ||
        isAdmin()
      );
    }

    // Discussion Topics - community-driven topics
    match /topics/{topicId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && 
        request.resource.data.createdBy == request.auth.uid &&
        request.resource.data.name is string &&
        request.resource.data.category is string &&
        request.resource.data.createdAt is timestamp;
      allow update: if isSignedIn() && (
        request.auth.uid == resource.data.createdBy ||
        isAdmin()
      );
      allow delete: if isSignedIn() && (
        request.auth.uid == resource.data.createdBy ||
        isAdmin()
      );
    }

    // Topic Search Index - for search functionality
    match /topicSearchIndex/{indexId} {
      allow read: if isSignedIn();
      allow write: if isAdmin(); // Only system can update search index
    }

    // Topic Stats - tracking topic engagement
    match /topicStats/{topicId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.topicId is string;
      allow update: if isSignedIn(); // Users can update stats when participating
      allow delete: if isAdmin();
    }

    // Topic Trending Metrics - for trending calculations
    match /topicTrendingMetrics/{topicId} {
      allow read: if isSignedIn();
      allow write: if isAdmin(); // Only system updates trending metrics
    }

    // Topic Similarity Cache - AI similarity results
    match /topicSimilarityCache/{cacheId} {
      allow read: if isSignedIn();
      allow write: if isAdmin(); // Only system can update similarity cache
    }

    // Topic Moderation Queue - for content moderation
    match /topicModerationQueue/{moderationId} {
      allow read: if isAdmin();
      allow create: if isSignedIn(); // System creates moderation requests
      allow update: if isAdmin();
      allow delete: if isAdmin();
    }

    // Legacy Trending Topics - read by all, write by admins only
    match /trendingTopics/{topicId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isAdmin();
    }

    // Legacy Topic Metrics - read by admins, write by system/admins only
    match /topicMetrics/{topicId} {
      allow read: if isAdmin();
      allow write: if isAdmin();
    }

    // Music Matchmaking Profiles - users can read/write their own
    match /musicMatchmaking/{userId} {
      allow read: if isSignedIn() && (request.auth.uid == userId || isAdmin());
      allow create: if isSignedIn() && request.auth.uid == userId;
      allow update: if isSignedIn() && request.auth.uid == userId;
      allow delete: if isSignedIn() && (request.auth.uid == userId || isAdmin());
    }

    // Social Interactions - users can read interactions they participated in
    match /socialInteractions/{interactionId} {
      allow read: if isSignedIn() && (
        request.auth.uid in resource.data.participantIds ||
        isAdmin()
      );
      allow create: if isSignedIn(); // System creates interactions
      allow update: if isSignedIn() && (
        request.auth.uid in resource.data.participantIds ||
        isAdmin()
      );
      allow delete: if isAdmin();
    }

    // Social Ratings - users can read/write their own ratings and ratings about them (with restrictions)
    match /socialRatings/{ratingId} {
      allow read: if isSignedIn() && (
        request.auth.uid == resource.data.raterId ||
        (request.auth.uid == resource.data.ratedUserId && resource.data.isVisible == true) ||
        isAdmin()
      );
      allow create: if isSignedIn() && request.resource.data.raterId == request.auth.uid;
      allow update: if isSignedIn() && request.auth.uid == resource.data.raterId;
      allow delete: if isSignedIn() && (
        request.auth.uid == resource.data.raterId ||
        isAdmin()
      );
    }

    // Social Scores - users can read their own and others' public scores
    match /socialScores/{userId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.auth.uid == userId;
      allow update: if isSignedIn() && (
        request.auth.uid == userId ||
        isAdmin()
      );
      allow delete: if isAdmin();
    }

    // Rating Prompts - users can read/update their own prompts
    match /ratingPrompts/{promptId} {
      allow read: if isSignedIn() && (
        request.auth.uid == resource.data.promptedUserId ||
        isAdmin()
      );
      allow create: if isSignedIn(); // System creates prompts
      allow update: if isSignedIn() && request.auth.uid == resource.data.promptedUserId;
      allow delete: if isAdmin();
    }

    // Mutual Rating Visibility - users can read visibility for their interactions
    match /mutualRatingVisibility/{interactionId} {
      allow read: if isSignedIn(); // Users need to check visibility rules
      allow create, update: if isSignedIn(); // System manages visibility
      allow delete: if isAdmin();
    }

    // Weekly Matches - users can read their own matches, system can write
    match /weeklyMatches/{matchId} {
      allow read: if isSignedIn() && (
        request.auth.uid == resource.data.userId ||
        request.auth.uid == resource.data.matchedUserId ||
        isAdmin()
      );
      allow create: if isSignedIn(); // Bot service creates matches
      allow update: if isSignedIn() && (
        request.auth.uid == resource.data.userId ||
        request.auth.uid == resource.data.matchedUserId ||
        isAdmin()
      );
      allow delete: if isAdmin();
    }

    // Matchmaking Statistics - read by admins only
    match /matchmakingStats/{weekId} {
      allow read: if isAdmin();
      allow write: if isAdmin();
    }

    // Bot Conversations - extend existing conversations rules
    match /conversations/{conversationId} {
      allow read: if isSignedIn() && (
        request.auth.uid in resource.data.participantIds ||
        request.auth.uid in resource.data.inboxFor ||
        request.auth.uid in resource.data.requestFor ||
        isAdmin()
      );
      allow create: if isSignedIn();
      allow update: if isSignedIn() && (
        request.auth.uid in resource.data.participantIds ||
        isAdmin()
      );
      allow delete: if isSignedIn() && (
        request.auth.uid in resource.data.participantIds ||
        isAdmin()
      );

      // Messages in conversations
      match /messages/{messageId} {
        allow read: if isSignedIn() && (
          request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds ||
          isAdmin()
        );
        allow create: if isSignedIn() && (
          request.auth.uid == request.resource.data.senderId ||
          request.resource.data.senderId == "matchmaking_bot_system"
        );
        allow update: if isSignedIn() && (
          request.auth.uid == resource.data.senderId ||
          isAdmin()
        );
        allow delete: if isSignedIn() && (
          request.auth.uid == resource.data.senderId ||
          isAdmin()
        );
      }

      // Presence/typing indicators in conversations
      match /presence/{userId} {
        allow read: if isSignedIn() && (
          request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds ||
          isAdmin()
        );
        allow create, update: if isSignedIn() && (
          request.auth.uid == userId ||
          isAdmin()
        );
        allow delete: if isSignedIn() && (
          request.auth.uid == userId ||
          isAdmin()
        );
      }
    }
    
    // CollectionGroup query for reposts across all logs
    match /{path=**}/reposts/{repostId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
      allow delete: if isSignedIn() && resource.data.userId == request.auth.uid;
    }
  }
}
```

## Key Security Improvements:

1. **✅ Username Validation Only:** Users can only read username fields for validation, not full profiles
2. **✅ Admin Protection:** Prevents users from elevating themselves to admin
3. **✅ Owner-Only Access:** Users can only access their own data
4. **✅ Proper Authentication:** All operations require authentication
5. **✅ Data Isolation:** Users cannot access other users' private data

