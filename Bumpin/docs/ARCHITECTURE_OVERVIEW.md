## Bumpin Architecture Overview

This document captures the current top-level structure of the app after the Step&nbsp;2 cleanup (shared logger/alerts + centralized log/social services) and highlights the feature-flag switches that gate unfinished surfaces such as the party & discussion tabs.

---

### 1. Launch & Dependency Graph
- `BumpinApp.swift` is the only `@main` entry point. It:
  - Configures Firebase at launch.
  - Creates shared environment objects (`AlertCenter.shared`, `MusicAuthorizationManager.shared`, `SocialSession.shared`, etc.).
  - Wraps the root SwiftUI tree in `GlobalAlertBanner`, so any screen can show toast alerts.
- `MainTabScaffold.swift` renders the tab bar. The list of tabs is derived from `FeatureFlags` (see §5), so turning off the party/discussion rails automatically hides those tabs without touching UI code.

```
BumpinApp
 └── MainTabScaffold (feature-flag-aware tabs)
      ├── SocialFeedView
      ├── Diary / MyDiaryView
      ├── Ratings / MyRatingsView
      └── (Optional tabs: Home / Discussion)
```

---

### 2. Shared Infrastructure
| Surface | Location | Notes |
| --- | --- | --- |
| Global logging | `Common/AppLogger.swift` | Wraps `os.Logger` with category & level enums. All modules call `AppLogger.debug/info/warning/error` instead of `print`, so logs remain structured even in release builds. |
| User-facing alerts | `Services/AlertCenter.swift` + `Common/GlobalAlertBanner.swift` | `AlertCenter` is a singleton `ObservableObject`. Views call `alertCenter.showToast(...)`; the banner automatically dismisses itself. |
| Music log data access | `Services/MusicLogStore.swift` | `actor` that encapsulates all Firestore reads/writes for `MusicLog` + comment/helpful subcollections. View models call the async APIs (e.g., `MusicLogStore.shared.fetchLogs(forUserId:)`) so we get thread-safety and consistent error handling. |
| Social feed data access | `Services/SocialFeedService.swift` | Firestore & MusicKit bridge for the social feed. Responsibilities: trending queries, friends-popular aggregations, genre rails, creator spotlight, now-playing fetchers, weekly logs, and the “new posts” listener. `SocialFeedViewModel` now manipulates UI state only. |
| Friends metadata | `FriendsPopularService.swift` | Used by `SocialFeedViewModel` to hydrate “friend avatars” for items. It now leans on `MusicLogStore`/`SocialFeedService` for data but still owns the UI-specific formatting. |

All of the above services are pure Swift types without SwiftUI dependencies, which makes them testable and re-usable from previews or other targets.

---

### 3. View Models vs. Views
- **View models stay thin**: `SocialFeedViewModel`, `ItemLogsViewModel`, `UserProfileViewModel`, etc., now delegate Firestore access to the services above. Their responsibilities are limited to:
  - Managing `@Published` UI state.
  - Filtering data based on user preferences (hidden users, blocked lists, feature flags).
  - Triggering side-effects such as `UserPreferencesService.shared.loadHiddenUsers()`.
- **Views focus on rendering**: SwiftUI views (`SocialFeedView`, `MyDiaryView`, `EnhancedReviewView`, etc.) subscribe to the published properties and display the results. When user interactions occur (pull-to-refresh, “show more”, etc.), the view simply calls into the appropriate view model method.
- **Concurrency pattern**: Every async Firestore call runs inside `Task`/`TaskGroup` helpers and uses `async`/`await`. Cancellation is honored (e.g., `MyDiaryView` cancels the previous fetch task before starting a new one).

---

### 4. Error & Alert Flow
1. Service throws an error (e.g., Firestore missing index).
2. View model catches it, logs details via `AppLogger`.
3. When the error is user-facing, the view model calls `alertCenter.showToast("message", style: .error)`.
4. `AlertCenter` publishes a `UserAlert`, triggering `GlobalAlertBanner` to animate a toast at the top of the UI.

This flow ensures we never show raw Firestore errors to the user, yet we still retain detailed logs for debugging.

---

### 5. Feature Flags
`FeatureFlags.swift` drives the initial tab layout and a few in-progress surfaces. Toggle these carefully before shipping:

| Flag | Default | Effect |
| --- | --- | --- |
| `showExploreTab` | `false` | Hides the “Explore” rail inside the social feed. Set to `true` when the Explore design is approved. |
| `showHomeTab` | `false` | Hides the Party/Sync Home tab in the main nav. For launch we keep it off. |
| `showDiscussionTab` | `false` | Hides the Discussion tab. Turn on when discussion rooms are ready. |
| `adminCanSeeAllFeatures` | `false` | If `true`, admin accounts bypass the other flags so QA can see work-in-progress tabs without flipping consumer-facing switches. |

**How to add a new flag**
1. Declare it in `FeatureFlags` with documentation.
2. Inject the flag where the feature is rendered (e.g., tab list or section `if FeatureFlags.someFlag`).
3. Keep the flag `false` by default so builds are deterministic.

---

### 6. Adding New Social Feed Logic
1. **Add/extend helper inside `SocialFeedService`**. Keep network/Firestore logic here.
2. **Expose a thin method on the view model** that calls the helper and stores the result in `@Published` properties.
3. **Update the SwiftUI view** to read those properties. Avoid direct Firestore usage from the view.
4. **Log and alert** through `AppLogger` + `AlertCenter` if the call is user-visible.

This pattern keeps Firestore knowledge in one place and prevents regressions when we add indexes or swap backends.

---

### 7. Where to Go Next
- **Step 3 (documentation)**: keep this file updated whenever we add new cross-cutting services or flags.
- **Party / Discussion surfaces**: when it’s time to re-enable them, guard the tabs with feature flags and apply the same service/view-model split to keep the codebase consistent.

Let me know if you need deeper docs for the diary/rating modules or background audio stack—happy to expand this guide.

