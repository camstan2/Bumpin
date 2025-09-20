# Topic System Setup Guide

This guide will help you set up the new community-driven discussion topic system in your Bumpin app.

## 🚀 Quick Setup

### 1. API Keys Configuration

#### Get Claude API Key
1. Go to [Anthropic Console](https://console.anthropic.com/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Create a new API key
5. Copy the key (starts with `sk-ant-`)

#### Add API Keys to Environment
You have two options for adding your API keys:

**Option A: Environment Variables (Recommended)**
```bash
# Add to your shell profile (~/.zshrc or ~/.bash_profile)
export CLAUDE_API_KEY_DEV="your_dev_api_key_here"
export CLAUDE_API_KEY_STAGING="your_staging_api_key_here" 
export CLAUDE_API_KEY_PROD="your_production_api_key_here"
```

**Option B: Direct Configuration**
Edit `Bumpin/Configuration/AppSecrets.swift` and replace the placeholder values:
```swift
struct Development {
    static let claudeAPIKey = "sk-ant-your-actual-api-key-here"
    // ... other configs
}
```

### 2. Firebase Configuration

#### Development Environment
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `bumpin-4349a`
3. Go to Project Settings > General
4. Add a new iOS app for development
5. Download `GoogleService-Info-Dev.plist`
6. Add it to your Xcode project

#### Staging Environment
1. Create a staging Firebase project or use the same project
2. Download `GoogleService-Info-Staging.plist`
3. Add it to your Xcode project

#### Production Environment
1. Use your existing `GoogleService-Info.plist`
2. Ensure it's properly configured

### 3. Deploy Firestore Rules

Deploy the updated Firestore rules to your Firebase project:

```bash
# Install Firebase CLI if you haven't already
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy rules
firebase deploy --only firestore:rules
```

### 4. Xcode Configuration

#### Add Files to Project
Make sure these files are added to your Xcode project:
- `Models/DiscussionTopic.swift`
- `Models/TopicChatExtensions.swift`
- `Services/TopicService.swift`
- `Services/AITopicManager.swift`
- `Services/ClaudeAPIService.swift`
- `Views/Discussion/TopicCreationView.swift`
- `Views/Discussion/TopicListView.swift`
- `Views/Discussion/TopicSelectionView.swift`
- `Configuration/AppSecrets.swift`

#### Build Settings
1. Open your project in Xcode
2. Select your target
3. Go to Build Settings
4. Add these environment variables:
   - `CLAUDE_API_KEY_DEV`
   - `CLAUDE_API_KEY_STAGING`
   - `CLAUDE_API_KEY_PROD`

## 🔧 Testing the Setup

### 1. Test API Connection
Run this in your app to test the Claude API connection:

```swift
Task {
    do {
        let response = try await ClaudeAPIService.shared.callClaude(prompt: "Hello, test message")
        print("✅ Claude API working: \(response)")
    } catch {
        print("❌ Claude API error: \(error)")
    }
}
```

### 2. Test Topic Creation
1. Open your app
2. Go to Discussion tab
3. Try creating a new topic
4. Check if it appears in the topic list

### 3. Test Firestore Integration
1. Create a topic
2. Check Firebase Console > Firestore
3. Verify the topic appears in the `topics` collection

## 🎯 Usage

### Creating Topics
1. Users can create specific, unique topics
2. AI checks for similar existing topics
3. Topics are automatically categorized
4. Content is moderated before approval

### Discovering Topics
1. Browse by category
2. Search for specific topics
3. View trending topics
4. See topic activity stats

### Joining Discussions
1. Select a topic
2. Join existing discussion or create new one
3. Real-time chat and voice features
4. Topic stats are updated automatically

## 🚨 Troubleshooting

### Common Issues

**"Claude API key not found" error:**
- Check your environment variables are set correctly
- Restart Xcode after setting environment variables
- Verify the API key is valid and has proper permissions

**Firestore permission denied:**
- Deploy the updated Firestore rules
- Check your Firebase project configuration
- Verify user authentication is working

**Topics not appearing:**
- Check Firestore rules are deployed
- Verify the `topics` collection exists
- Check for any console errors

**AI features not working:**
- Verify Claude API key is correct
- Check network connectivity
- Review API usage limits

### Getting Help

1. Check the console for error messages
2. Verify all files are properly added to Xcode
3. Ensure Firebase rules are deployed
4. Test API keys independently

## 📊 Monitoring

### Firebase Console
- Monitor topic creation in Firestore
- Check user engagement metrics
- Review any security rule violations

### Claude API Usage
- Monitor API usage in Anthropic Console
- Set up usage alerts
- Track costs and limits

## 🔄 Next Steps

After setup is complete:

1. **Test thoroughly** - Create topics, join discussions, test all features
2. **Monitor usage** - Watch for any errors or issues
3. **Gather feedback** - Get user feedback on the new topic system
4. **Iterate** - Make improvements based on usage patterns

## 📝 Notes

- The system is designed to be backward compatible with existing discussions
- Old AI-generated topics will continue to work
- New community-driven topics will gradually replace the old system
- All existing discussion features remain unchanged

---

**Need help?** Check the console logs, verify your configuration, and ensure all steps are completed correctly.
