# Random Chat Feature Documentation

## Overview
The Random Chat feature allows users to engage in spontaneous voice conversations with other users. It supports both solo and group chats (2v2 and 3v3), with matching preferences and a sophisticated queuing system.

## Features

### Queue Types
- **Solo Chat (1v1)**: Quick match with another individual user
- **Double Chat (2v2)**: Two friends matched with two other friends
- **Triple Chat (3v3)**: Three friends matched with three other friends

### Matching Preferences
- **Gender Preference**: Users can specify preferred match gender (any/male/female)
- **Group Size**: Matches are always made between groups of the same size
- **Wait Time**: Older queue requests are prioritized for fairness

### Queue Management
- Real-time queue status updates
- Queue time tracking
- Group member status tracking
- Automatic timeout after 5 minutes
- Queue statistics (active chats, queued users, average wait time)

### Group Features
- Friend invitation system
- Real-time group formation
- Member acceptance tracking
- No member overlap protection

## Technical Implementation

### Services
- `RandomChatService`: Handles Firebase operations and real-time updates
- `RandomChatMatchingService`: Implements matching algorithm and group handling
- `VoiceChatManager`: Manages voice chat functionality

### ViewModels
- `RandomChatViewModel`: Manages UI state and business logic
- `RandomChatDiscussionViewModel`: Handles active chat session

### Views
- `RandomChatView`: Main view for queue management
- `GroupSizeSelectionView`: Group size selection UI
- `PreferencesSelectionView`: Matching preferences UI
- `InviteFriendsView`: Friend invitation UI
- `QueueStatusView`: Queue status and statistics
- `RandomChatDiscussionView`: Active chat UI

### Data Models
- `QueueRequest`: Queue entry information
- `RandomChatFriend`: Friend model for invitations
- `GenderPreference`: Matching preference enum
- `QueueStatus`: Queue state tracking

## Firebase Structure

### Collections
- `randomChatQueue`: Active queue requests
- `randomChatInvites`: Group formation invitations
- `randomChats`: Active chat sessions

### Security Rules
```javascript
match /randomChatQueue/{requestId} {
  allow read: if isSignedIn();
  allow create: if isSignedIn() && request.resource.data.userId == request.auth.uid;
  allow update: if isSignedIn() && (
    request.auth.uid == resource.data.userId ||
    request.auth.uid in resource.data.groupMembers
  );
  allow delete: if isSignedIn() && request.auth.uid == resource.data.userId;
}
```

## Error Handling
- Queue timeout (5 minutes)
- Network disconnection recovery
- Group formation failures
- Match creation failures
- Voice chat connection issues

## Analytics Events
- Queue join/leave
- Match success/failure
- Group formation
- Chat duration
- Feature usage statistics

## Best Practices
1. Always check queue status before operations
2. Handle network disconnections gracefully
3. Clean up resources on chat end
4. Validate group member status
5. Respect user preferences
6. Monitor queue times
7. Handle edge cases (member dropout, etc.)

## Future Improvements
1. Topic-based matching
2. Language preferences
3. Age range filtering
4. Rating system
5. Blocked user handling
6. Enhanced group permissions
7. Custom ice breakers
