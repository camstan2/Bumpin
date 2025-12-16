# App Store Review Response

## Submission ID: [Your Submission ID from Apple's message]

Hello Apple Review Team,

Thank you for your review. We have addressed all the issues you raised. Please find our responses below:

---

## Guideline 2.1 - App Tracking Transparency

**Issue:** The app uses the AppTrackingTransparency framework, but we are unable to locate the App Tracking Transparency permission request.

**Response:** We have updated our App Privacy information in App Store Connect. Our app does not track users across apps or websites. We do not use the App Tracking Transparency framework because we do not engage in tracking as defined by Apple. Our App Privacy declaration now shows "Data Not Collected," confirming that we do not collect data for tracking purposes.

---

## Guideline 2.5.4 - Background Audio

**Issue:** The app declares support for audio in the UIBackgroundModes key in your Info.plist but we are unable to locate any features that require persistent audio.

**Response:** We have removed the "audio" setting from the UIBackgroundModes key in our Info.plist. The app does not currently have features that require persistent background audio playback. We removed this entitlement to comply with guideline 2.5.4.

---

## Guideline 1.2 - User-Generated Content

**Issue:** Apps with user-generated content must take specific steps to moderate content and prevent abusive behavior. The developer must act on objectionable content reports within 24 hours by removing the content and ejecting the user who provided the offending content.

**Response:** We have implemented a comprehensive content moderation system that ensures all reports are reviewed and acted upon within 24 hours:

**Reporting System:**
- Users can report inappropriate content (logs, reviews, comments, chat messages, user profiles) directly from the app
- Reports are stored in Firestore and immediately visible to administrators
- Duplicate reports and self-reporting are prevented

**Admin Moderation Dashboard:**
- Administrators have access to a real-time moderation dashboard showing all pending reports
- Reports are prioritized by age (urgent flags for reports over 12 hours old)
- Each report displays the content, reporter details, violation reason, and user history

**24-Hour Response Commitment:**
- All reports are reviewed and acted upon within 24 hours
- When objectionable content is confirmed, administrators can:
  - **Remove Content:** The offending content is immediately deleted from Firestore
  - **Warn User:** User receives a warning and violation count is incremented
  - **Mute User:** User is temporarily muted (24 hours) and cannot post new content
  - **Suspend Account:** User account is temporarily suspended (72 hours)
  - **Ban User:** User is permanently banned and cannot access the app

**Enforcement Actions:**
- Content removal: The reported content document is deleted from the appropriate Firestore collection (logs, comments, chatMessages, etc.)
- User ejection: When a user is banned, their account is marked with `isBanned = true` in Firestore, which prevents them from accessing the app
- All moderation actions are logged in an audit trail for accountability

**User Experience:**
- Users see confirmation messages when submitting reports
- Banned/muted users see clear messaging explaining their restriction
- All enforcement actions are tracked and auditable

This system ensures that objectionable content is removed and offending users are ejected within 24 hours as required by guideline 1.2.

---

## Guideline 2.1 - Business Model Questions

**Issue:** We have started our review, but we need additional information to continue. Specifically, it appears your app may access or include paid digital content or services.

**Response:** Bumpin is a completely free social music discovery app with no paid features, subscriptions, or in-app purchases.

**Does your app access any paid content or services?**
No. Bumpin is a free social music discovery app. Users connect their existing Apple Music or Spotify accounts (which they pay for separately through those services), but Bumpin itself does not provide, sell, or require any paid content or services.

**What are the paid content or services?**
N/A - Bumpin does not provide any paid content or services.

**Do individual customers pay for the content or services?**
No. Bumpin is completely free for all users.

**If no, does a company or organization pay for the content or services?**
No. Bumpin does not receive payment from any company or organization for content or services.

**Where do they pay, and what's the payment method?**
N/A - There are no payment transactions in Bumpin.

**If users create an account to use your app, are there fees involved?**
No. Account creation is completely free. Users can sign up using email or Apple Sign-In at no cost.

**How do users obtain an account?**
Users create accounts directly in the app using:
- Email address and password
- Apple Sign-In

No fees, subscriptions, or payments are required to use Bumpin.

---

## Summary

We have addressed all four issues:
1. ✅ Removed tracking declarations from App Privacy
2. ✅ Removed background audio entitlement from Info.plist
3. ✅ Implemented 24-hour content moderation system with content removal and user banning capabilities
4. ✅ Confirmed that Bumpin is a free app with no paid features

We have uploaded a new build (version 1.0) that includes these fixes. We appreciate your thorough review and look forward to approval.

Best regards,
Cameron Stanley
Developer, Bumpin

