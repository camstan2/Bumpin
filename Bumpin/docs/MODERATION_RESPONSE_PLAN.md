# Moderation Response Plan

This document summarizes how Bumpin satisfies App Store Guideline 1.2 for user-generated content.

## Reporting Flow

- Every log, review, party, and profile has a “Report” affordance (`ReportContentView` + `ReportingService`).
- Reports are stored in Firestore collections:
  - `contentReports` for specific logs/comments/etc.
  - `userReports` for user-level violations.
- Duplicate self-reports are prevented and each submission captures reporter, offender, and reason.

## Admin Workflow (24-hour SLA)

1. Admins open `AdminModerationDashboard` (gated by `FeatureFlags`/roles).
2. Pending reports stream in real time (`ReportingService.getPendingReports()` / `getPendingUserReports()`).
3. Selecting a report opens the detail view where the admin can choose:
   - Warn user
   - Remove offending content
   - Mute user (temporary)
   - Suspend account (temporary)
   - Ban user
4. Upon resolution, `ReportingService.resolveReport` / `resolveUserReport`:
   - Deletes the flagged content if required.
   - Updates the offender’s Firestore doc with moderation flags (`warningCount`, `isMuted`, `isSuspended`, `isBanned`, etc.).
   - Logs the enforcement in `moderationActions`.
   - Marks the report as resolved with `resolvedBy`, `resolvedAt`, and admin notes.

We review every incoming report and act within 24 hours. Automated alerts (email/Slack) are wired up in `ReportingService` consumers so the admin team is notified as soon as a new report arrives.

## Enforcement Details

- **Warn** – increments `warningCount`, records `lastWarningAt`.
- **Mute** – sets `isMuted = true` with a 24-hour `mutedUntil`.
- **Suspend** – sets `isSuspended = true` with a 72-hour `suspensionExpiresAt`.
- **Ban** – sets `isBanned = true` and removes access indefinitely (sign-in gate checks `isBanned` before presenting the main UI).
- **Content Removal** – deletes the offending Firestore document (`logs`, `comments`, `chatMessages`, etc.).

All enforcement actions are auditable through the `moderationActions` collection, which captures the report ID, acting admin, timestamp, and optional notes.

## User Experience

- Users who are muted/suspended/banned see blocking UI explaining the restriction and providing support contact info.
- Reports submitted by users display a confirmation toast indicating that action will be taken within 24 hours.

This combination of user tools, admin workflow, and enforcement guarantees compliance with Apple’s safety requirements.

