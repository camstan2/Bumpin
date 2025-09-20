# Analytics Events (Phase 4.5)

Use these names/keys consistently across the app. Add common context (appVersion, build, userId, isAdmin, currentTab) if your sink supports it.

## Party funnel
- party_join (tap)
  - props: method (deeplink|universal|discovery|code), id (partyId)
- join_code_prompt (impression)
- join_code_invalid (impression)
- party_invite_share (tap)
  - props: id (partyId), surface (sheet|party_settings)
- party_code_copy (tap)
  - props: id (partyId)

## Discovery
- discovery_tab_view (impression)
  - props: tab (following|friends|nearby|explore)
- discovery_party_impression (impression)
  - props: tab, id (partyId)
- discovery_quick_join (tap)
  - props: tab, id (partyId)

## Search
- search_provider_counts (impression)
- search_result_rank (impression)

## Profile / Logging
- profile_photo_upload_* (impression)
- profile_save_* (tap)
- log_comment_* (tap)

Add new events here as needed; keep naming flat and consistent.

