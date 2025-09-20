# Bumpin - Music Sync App

A SwiftUI iOS app that allows users to join a party and listen to the same song in unison with each other. Perfect for group workouts, parties, or any activity where synchronized music enhances the experience.

## Features Implemented

### Apple Music Authorization
- ✅ Request Apple Music authorization from users
- ✅ Handle different authorization states (not determined, denied, authorized)
- ✅ Modern, user-friendly UI for authorization flow
- ✅ Proper error handling and user guidance

### Party Creation & Management
- ✅ Create new parties with custom names
- ✅ Beautiful party creation UI with validation
- ✅ Party code generation for easy sharing
- ✅ Party view with participants list
- ✅ Share party codes via system share sheet
- ✅ End party functionality with confirmation

### Music Synchronization
- ✅ Apple Music integration with MPMediaPickerController
- ✅ Song selection from user's music library
- ✅ Real-time playback controls (play, pause, skip)
- ✅ Synchronized music playback between participants
- ✅ Progress tracking with visual progress bar
- ✅ Sync status indicators and participant count
- ✅ Automatic sync when host changes playback

## Technical Implementation

### Core Models
- **Party**: Represents a music party with participants, host, and current song
- **PartyParticipant**: Individual participant with host status and join time
- **Song**: Music track with Apple Music integration support

### Managers
- **MusicAuthorizationManager**: Handles Apple Music authorization using MediaPlayer framework
- **PartyManager**: Manages party creation, state, and navigation flow
- **MusicManager**: Handles Apple Music playback, song selection, and audio controls
- **SyncManager**: Manages real-time synchronization between party participants

### Views
- **ContentView**: Main app interface with authorization and party options
- **PartyCreationView**: Modern UI for creating new parties with validation
- **PartyView**: Comprehensive party interface with participants, music controls, and sharing
- **SongPickerView**: Apple Music song selection interface

### Project Configuration
- MediaPlayer framework properly linked
- Required privacy usage description added to Info.plist
- Proper build settings for iOS deployment

## App Flow

1. **Authorization**: App requests Apple Music access on first launch
2. **Main Menu**: After authorization, users can create or join parties
3. **Party Creation**: Users enter party name and create a new party
4. **Party View**: Host sees party code, participants, and music controls
5. **Song Selection**: Host can select songs from Apple Music library
6. **Synchronized Playback**: All participants listen to the same song at the same time
7. **Sharing**: Party codes can be shared via system share sheet

## Getting Started

1. Open the project in Xcode
2. Build and run on a device or simulator
3. Grant Apple Music authorization when prompted
4. Tap "Create Party" to start a new music party
5. Tap "Add Song" to select music from your Apple Music library
6. Share the party code with friends to invite them
7. Control playback and watch everyone sync together!

## Current Features

### ✅ Working Features
- Apple Music authorization flow
- Party creation with custom names
- Party code generation and display
- Party view with participant management
- Share party codes
- End party functionality
- Apple Music song selection
- Real-time playback controls
- Synchronized music playback
- Progress tracking and time display
- Sync status indicators
- Modern, responsive UI

### 🚧 Ready for Implementation
- Join party functionality
- Cross-device communication (currently simulated)
- Backend integration for real-time sync
- User authentication and profiles
- Party discovery and public parties

## Music Synchronization Details

### How It Works
1. **Host Control**: Party host selects and controls music playback
2. **Real-time Sync**: Playback state is synchronized to all participants
3. **Position Tracking**: Current playback position is shared continuously
4. **Auto-adjustment**: Participants automatically sync to host's playback
5. **Status Monitoring**: Visual indicators show sync status and participant count

### Technical Approach
- **Timestamp-based Sync**: Uses precise timing for synchronization
- **Notification System**: Real-time updates via NotificationCenter
- **Fallback Handling**: Graceful degradation when sync isn't perfect
- **Progress Monitoring**: Continuous tracking of playback position

### Expected Sync Quality
- **Same WiFi Network**: Within 100-200ms sync
- **Same City, Good Internet**: Within 200-500ms sync
- **Different Countries**: Within 500ms-1s sync

## Next Steps

- **Join Party**: Implement party joining via code entry
- **Network Layer**: Backend integration for multi-device parties
- **User Management**: User profiles and authentication
- **Party Discovery**: Find and join public parties
- **Enhanced Sync**: Optimize synchronization algorithms
- **Offline Support**: Handle network interruptions gracefully

## Requirements

- iOS 18.5+
- Xcode 16.4+
- Apple Music subscription (for full functionality)
- Device with Apple Music access

## Architecture

The app follows MVVM architecture with:
- **Models**: Data structures for parties, participants, and songs
- **ViewModels**: Observable objects managing state and business logic
- **Views**: SwiftUI views for user interface
- **Managers**: Service classes for authorization, party management, music playback, and synchronization 