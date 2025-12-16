# Social Login Setup Guide (Apple & Google Sign In)

## Overview
This guide walks you through the complete setup process for Apple Sign In and Google Sign In in your Bumpin app.

---

## ✅ What's Already Done

### Code Implementation
- ✅ Apple Sign In service created (`Services/AppleSignInService.swift`)
- ✅ Google Sign In service created (`Services/GoogleSignInService.swift`)
- ✅ Social login buttons added to LoginSignupView
- ✅ Apple Sign In capability added to entitlements
- ✅ Firebase Auth integration complete
- ✅ User profile creation for social logins

---

## 🍎 Apple Sign In Setup

### 1. Enable in Xcode (Already Done)
The entitlements file has been updated with:
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

### 2. Apple Developer Portal Configuration

#### Step 2.1: Enable Sign in with Apple for Your App ID
1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click on **Identifiers**
4. Select your app's **App ID** (e.g., `com.cameronstanley.Bumpin`)
5. Scroll down and check **Sign in with Apple**
6. Click **Configure** if needed
7. Click **Save**

#### Step 2.2: Update Provisioning Profiles
1. In the Developer Portal, go to **Profiles**
2. Select your **Development** and **Distribution** profiles
3. Click **Edit**
4. Re-generate the profile (it will automatically include the new capability)
5. Download and install the updated profiles in Xcode

#### Step 2.3: Verify in Xcode
1. Open your project in Xcode
2. Select your target → **Signing & Capabilities**
3. You should see **Sign in with Apple** capability
4. If not, click **+ Capability** and add **Sign in with Apple**

### 3. Firebase Console Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **Bumpin** project
3. Go to **Authentication** → **Sign-in method**
4. Click on **Apple**
5. Toggle **Enable**
6. (Optional) Add your Apple Developer Team ID for better integration
7. Click **Save**

---

## 🔵 Google Sign In Setup

### 1. Install Google Sign-In SDK

The app already imports `GoogleSignIn`, but you may need to add it via Swift Package Manager if not already installed:

#### Option A: Swift Package Manager (Recommended)
1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter: `https://github.com/google/GoogleSignIn-iOS`
3. Select version **7.0.0** or later
4. Click **Add Package**

#### Option B: CocoaPods (If using)
Add to your `Podfile`:
```ruby
pod 'GoogleSignIn'
```
Then run `pod install`

### 2. Google Cloud Console Setup

#### Step 2.1: Create OAuth 2.0 Client IDs
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one)
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client ID**

#### Step 2.2: Configure iOS Client
1. Application type: **iOS**
2. Name: `Bumpin iOS`
3. Bundle ID: `com.cameronstanley.Bumpin` (must match your Xcode project)
4. Click **Create**
5. **Save the Client ID** (you'll need it for Firebase)

#### Step 2.3: (Optional) Create Web Client ID for Firebase
1. Click **Create Credentials** → **OAuth 2.0 Client ID** again
2. Application type: **Web application**
3. Name: `Bumpin Web (Firebase)`
4. Authorized redirect URIs: (Firebase will provide these)
5. Click **Create**
6. **Save this Client ID too**

### 3. Firebase Console Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your **Bumpin** project
3. Go to **Authentication** → **Sign-in method**
4. Click on **Google**
5. Toggle **Enable**
6. **Web SDK configuration** should show your Client ID (from `GoogleService-Info.plist`)
7. If prompted, enter the **Web Client ID** from Step 2.3
8. Click **Save**

### 4. Update GoogleService-Info.plist

Your `GoogleService-Info.plist` should already contain:
- `CLIENT_ID` (used by the Google Sign-In SDK)
- `REVERSED_CLIENT_ID` (used for URL scheme)

**Verify these exist:**
```xml
<key>CLIENT_ID</key>
<string>YOUR_CLIENT_ID_HERE</string>
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.YOUR_REVERSED_ID</string>
```

### 5. Add URL Scheme to Info.plist

1. Open `Info.plist` in Xcode
2. Add a new URL Type:
   - **Identifier**: `com.googleusercontent.apps.YOUR_CLIENT_ID`
   - **URL Schemes**: `com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID` (from GoogleService-Info.plist)

**Or add this XML to Info.plist:**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

---

## 🧪 Testing

### Apple Sign In
1. Build and run on a **real device** (won't work in simulator)
2. Tap **Continue with Apple**
3. Sign in with your Apple ID
4. Choose whether to share or hide email
5. Verify user is created in Firebase Console → Authentication

### Google Sign In
1. Build and run (works in simulator and device)
2. Tap **Continue with Google**
3. Select your Google account
4. Grant permissions
5. Verify user is created in Firebase Console → Authentication

---

## 🔍 Troubleshooting

### Apple Sign In Issues

**"Invalid client" or "Unauthorized" error:**
- Verify App ID has Sign in with Apple enabled
- Re-download provisioning profiles
- Clean build folder (Cmd+Shift+K) and rebuild

**"Account already exists" error:**
- This user email is already registered via email/password
- Users cannot mix auth methods for the same email
- Consider enabling account linking in Firebase

### Google Sign In Issues

**"Missing CLIENT_ID" error:**
- Verify `GoogleService-Info.plist` is in your project
- Check that `CLIENT_ID` key exists in the plist
- Rebuild the project

**"Invalid client" or sign-in immediately fails:**
- Verify OAuth Client ID bundle matches your app's bundle ID exactly
- Check URL scheme is correctly added to Info.plist
- Make sure `REVERSED_CLIENT_ID` matches what's in GoogleService-Info.plist

**"Sign in cancelled" message in console:**
- This is normal if user taps "Cancel" - not an error

**Google Sign-In button has no logo:**
- You need to add `google_logo.png` to Assets.xcassets
- Download from: https://developers.google.com/identity/branding-guidelines
- Or replace with SF Symbol: `Image(systemName: "g.circle.fill")`

---

## 📦 Assets Needed

### Google Logo
The Google button references `Image("google_logo")`. You need to:

1. Download the official Google logo from [Google Brand Resources](https://developers.google.com/identity/branding-guidelines)
2. Add to **Assets.xcassets**:
   - Right-click in Assets.xcassets
   - New Image Set → Name it `google_logo`
   - Drag the logo file into 1x, 2x, and 3x slots

**Alternative:** Use SF Symbol instead (already available):
Edit `GoogleSignInService.swift` line with the Image to:
```swift
Image(systemName: "g.circle.fill")
    .resizable()
    .frame(width: 20, height: 20)
```

---

## ✅ Verification Checklist

Before considering setup complete:

### Apple Sign In
- [ ] App ID has "Sign in with Apple" capability enabled
- [ ] Entitlements file includes Apple Sign In
- [ ] Firebase Console has Apple provider enabled
- [ ] Tested on real device (simulator won't work)
- [ ] User appears in Firebase Authentication console

### Google Sign In
- [ ] GoogleSignIn SDK installed (via SPM or CocoaPods)
- [ ] OAuth 2.0 Client ID created in Google Cloud Console
- [ ] Bundle ID matches exactly in Google Cloud Console
- [ ] `GoogleService-Info.plist` has CLIENT_ID and REVERSED_CLIENT_ID
- [ ] URL scheme added to Info.plist
- [ ] Firebase Console has Google provider enabled
- [ ] Google logo asset added (or SF Symbol used)
- [ ] Tested and user appears in Firebase Authentication console

---

## 🎯 What Users Will See

### Sign Up Flow (Social)
1. User taps "Continue with Apple" or "Continue with Google"
2. System auth screen appears
3. User authenticates with their Apple ID / Google account
4. **New users:** Profile automatically created with:
   - Name from Apple/Google (if provided)
   - Email (if shared)
   - Profile picture from Google (if available)
   - Username auto-generated from email
5. User is immediately logged in - **no email verification needed** ✅
6. **Email verification banner will NOT show** for social login users

### Login Flow (Social)
1. Returning user taps "Continue with Apple" or "Continue with Google"
2. System recognizes existing credentials
3. User is logged in instantly (one tap)

---

## 🔐 Security Notes

- **Apple Sign In:** Emails are pre-verified by Apple
- **Google Sign In:** Emails are pre-verified by Google
- Users who sign up via social login will have `authProvider` set to `"apple"` or `"google"` in Firestore
- Users can choose to "Hide My Email" with Apple - respect this privacy choice
- Social login users have `emailVerified: true` set automatically

---

## 📱 Next Steps

Once setup is complete:
1. Test both social login methods thoroughly
2. Verify users appear in Firebase Console → Authentication
3. Check that user profiles are created correctly in Firestore
4. Test the email verification banner (should NOT appear for social logins)
5. Consider adding account linking for users who want to merge accounts

---

## 💡 Future Enhancements

Consider adding:
- Account linking (connect social login to existing email/password account)
- Profile completion prompt for social sign-ins (bio, username customization)
- Multiple auth methods for same user
- Sign out from social accounts when user logs out


