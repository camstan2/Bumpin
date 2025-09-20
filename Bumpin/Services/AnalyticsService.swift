import Foundation
import Firebase

class AnalyticsService {
    static let shared = AnalyticsService()
    
    var globalContext: (() -> [String: Any])?
    
    private init() {}
    
    // MARK: - Event Logging
    
    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        // Analytics.logEvent(name, parameters: parameters)
        print("📊 Analytics: \(name) \(parameters ?? [:])")
    }
    
    func logScreenView(_ screenName: String, screenClass: String? = nil) {
        // Analytics.logEvent(AnalyticsEventScreenView, parameters: [
        //     AnalyticsParameterScreenName: screenName,
        //     AnalyticsParameterScreenClass: screenClass ?? screenName
        // ])
        print("📊 Screen View: \(screenName) (\(screenClass ?? screenName))")
    }
    
    // MARK: - User Events
    
    func logUserSignUp(method: String) {
        logEvent("sign_up", parameters: [
            "method": method
        ])
    }
    
    func logUserLogin(method: String) {
        logEvent("login", parameters: [
            "method": method
        ])
    }
    
    // MARK: - Music Events
    
    func logMusicSearch(query: String, resultCount: Int) {
        logEvent("music_search", parameters: [
            "query": query,
            "result_count": resultCount
        ])
    }
    
    func logMusicLog(itemType: String, rating: Int?) {
        var params: [String: Any] = ["item_type": itemType]
        if let rating = rating {
            params["rating"] = rating
        }
        logEvent("music_logged", parameters: params)
    }
    
    func logMusicPlay(itemId: String, itemType: String) {
        logEvent("music_play", parameters: [
            "item_id": itemId,
            "item_type": itemType
        ])
    }
    
    // MARK: - Social Events
    
    func logLike(itemId: String, itemType: String) {
        logEvent("content_liked", parameters: [
            "item_id": itemId,
            "item_type": itemType
        ])
    }
    
    func logComment(itemId: String, itemType: String) {
        logEvent("comment_added", parameters: [
            "item_id": itemId,
            "item_type": itemType
        ])
    }
    
    func logFollow(userId: String) {
        logEvent("user_followed", parameters: [
            "followed_user_id": userId
        ])
    }
    
    // MARK: - Party Events
    
    func logPartyCreated(isPublic: Bool, participantCount: Int) {
        logEvent("party_created", parameters: [
            "is_public": isPublic,
            "participant_count": participantCount
        ])
    }
    
    func logPartyJoined(partyId: String, joinMethod: String) {
        logEvent("party_joined", parameters: [
            "party_id": partyId,
            "join_method": joinMethod
        ])
    }
    
    func logDJSessionStarted(sessionId: String) {
        logEvent("dj_session_started", parameters: [
            "session_id": sessionId
        ])
    }
    
    // MARK: - Safety Events
    
    func logContentReported(contentType: String, reason: String) {
        logEvent("content_reported", parameters: [
            "content_type": contentType,
            "reason": reason
        ])
    }
    
    func logUserBlocked(blockedUserId: String, reason: String) {
        logEvent("user_blocked", parameters: [
            "blocked_user_id": blockedUserId,
            "reason": reason
        ])
    }
    
    func logContentFiltered(contentType: String, reason: String) {
        logEvent("content_filtered", parameters: [
            "content_type": contentType,
            "reason": reason
        ])
    }
    
    // MARK: - UI Events
    
    func logTap(category: String, id: String) {
        logEvent("ui_tap", parameters: [
            "category": category,
            "element_id": id
        ])
    }
    
    func logSwipe(direction: String, screen: String) {
        logEvent("ui_swipe", parameters: [
            "direction": direction,
            "screen": screen
        ])
    }
    
    // MARK: - Business Events
    
    func logAdmissionMode(mode: String) {
        logEvent("admission_mode_selected", parameters: [
            "mode": mode
        ])
    }
    
    func logQueuePermission(mode: String) {
        logEvent("queue_permission_selected", parameters: [
            "mode": mode
        ])
    }
    
    // MARK: - Error Events
    
    func logError(error: Error, context: String) {
        logEvent("app_error", parameters: [
            "error_description": error.localizedDescription,
            "context": context
        ])
    }
    
    func logCrash(error: String, stackTrace: String? = nil) {
        var params: [String: Any] = ["error": error]
        if let stackTrace = stackTrace {
            params["stack_trace"] = stackTrace
        }
        logEvent("app_crash", parameters: params)
    }
    
    // MARK: - User Properties
    
    func setUserProperty(_ value: String?, forName name: String) {
        // Analytics.setUserProperty(value, forName: name)
        print("📊 User Property: \(name) = \(value ?? "nil")")
    }
    
    func setUserId(_ userId: String) {
        // Analytics.setUserID(userId)
        print("📊 User ID: \(userId)")
    }
    
    // MARK: - Party Events (Additional)
    
    func logPartyJoin(method: String, partyId: String) {
        logEvent("party_joined", parameters: [
            "join_method": method,
            "party_id": partyId
        ])
    }
    
    func logJoinCodeInvalid(code: String) {
        logEvent("join_code_invalid", parameters: [
            "code": code
        ])
    }
    
    func logDJ(action: String, props: [String: Any]) {
        logEvent("dj_\(action)", parameters: props)
    }
    
    func logOfflineQueue(length: Int) {
        logEvent("offline_queue_processed", parameters: [
            "queue_length": length
        ])
    }
    
    func logQueueAction(action: String, groupSize: Int? = nil, parameters: [String: Any] = [:]) {
        var params = parameters
        params["action"] = action
        if let groupSize = groupSize { params["group_size"] = groupSize }
        logEvent("queue_action", parameters: params)
    }
    
    func logSpeakerRequest(action: String, partyId: String? = nil, userId: String? = nil) {
        var params: [String: Any] = ["action": action]
        if let partyId = partyId { params["party_id"] = partyId }
        if let userId = userId { params["user_id"] = userId }
        logEvent("speaker_request", parameters: params)
    }
    
    func logImpression(category: String, id: String) {
        logEvent("impression", parameters: [
            "category": category,
            "id": id
        ])
    }
    
    func logDiscoveryQuickJoin(tab: String? = nil, partyId: String) {
        var params: [String: Any] = ["party_id": partyId]
        if let tab = tab { params["tab"] = tab }
        logEvent("discovery_quick_join", parameters: params)
    }
    
    func logDiscoveryPartyImpression(tab: String? = nil, partyId: String, position: Int? = nil) {
        var params: [String: Any] = ["party_id": partyId]
        if let tab = tab { params["tab"] = tab }
        if let position = position { params["position"] = position }
        logEvent("discovery_party_impression", parameters: params)
    }
    
    func logDiscoveryCache(event: String, source: String, hit: Bool, ageMs: Int? = nil) {
        var params: [String: Any] = [
            "event": event,
            "source": source,
            "hit": hit
        ]
        if let ageMs = ageMs { params["age_ms"] = ageMs }
        logEvent("discovery_cache", parameters: params)
    }
    
    func logEngagement(action: String, contentType: String, contentId: String, logId: String? = nil) {
        var params: [String: Any] = [
            "action": action,
            "content_type": contentType,
            "content_id": contentId
        ]
        if let logId = logId { params["log_id"] = logId }
        logEvent("engagement", parameters: params)
    }
    
    func logComments(action: String, contentId: String) {
        logEvent("comments", parameters: [
            "action": action,
            "content_id": contentId
        ])
    }
    
    func logDiscoveryListenerError(source: String, error: String) {
        logEvent("discovery_listener_error", parameters: [
            "source": source,
            "error": error
        ])
    }
    
    func logTiming(event: String, time: TimeInterval, parameters: [String: Any] = [:]) {
        var params = parameters
        params["event"] = event
        params["time"] = time
        logEvent("timing", parameters: params)
    }
    
    func logDiscoveryTabView(tab: String) {
        logEvent("discovery_tab_view", parameters: [
            "tab": tab
        ])
    }
    
    func logDiscoveryLifecycle(event: String, tab: String) {
        logEvent("discovery_lifecycle", parameters: [
            "event": event,
            "tab": tab
        ])
    }
    
    func logDiscoveryLoadMore(tab: String, page: Int) {
        logEvent("discovery_load_more", parameters: [
            "tab": tab,
            "page": page
        ])
    }
    
    func logDiscoveryRetry(tab: String, attempt: Int) {
        logEvent("discovery_retry", parameters: [
            "tab": tab,
            "attempt": attempt
        ])
    }
    
    func logModeration(action: String, targetUserId: String? = nil, partyId: String? = nil, contentId: String? = nil, reason: String? = nil) {
        var params: [String: Any] = ["action": action]
        if let targetUserId = targetUserId { params["target_user_id"] = targetUserId }
        if let partyId = partyId { params["party_id"] = partyId }
        if let contentId = contentId { params["content_id"] = contentId }
        if let reason = reason { params["reason"] = reason }
        logEvent("moderation", parameters: params)
    }
    
    func logPartyUpdateFailed(partyId: String, error: String) {
        logEvent("party_update_failed", parameters: [
            "party_id": partyId,
            "error": error
        ])
    }
    
    func logPartyUpdateSaved(partyId: String) {
        logEvent("party_update_saved", parameters: [
            "party_id": partyId
        ])
    }
    
    func logMatchCreated(matchId: String, userIds: [String]) {
        logEvent("match_created", parameters: [
            "match_id": matchId,
            "user_count": userIds.count
        ])
    }
    
    func logProfilePhotoUploadStarted(bytes: Int? = nil) {
        var params: [String: Any] = [:]
        if let bytes = bytes { params["bytes"] = bytes }
        logEvent("profile_photo_upload_started", parameters: params)
    }
    
    func logProfilePhotoUploadFailure(error: String) {
        logEvent("profile_photo_upload_failure", parameters: [
            "error": error
        ])
    }
    
    func logProfileSaveFailure(error: String) {
        logEvent("profile_save_failure", parameters: [
            "error": error
        ])
    }
    
    func logProfilePhotoUploadSuccess(bytes: Int? = nil) {
        var params: [String: Any] = [:]
        if let bytes = bytes { params["bytes"] = bytes }
        logEvent("profile_photo_upload_success", parameters: params)
    }
    
    func logProfileSaveSuccess(userId: String? = nil) {
        var params: [String: Any] = [:]
        if let userId = userId { params["user_id"] = userId }
        logEvent("profile_save_success", parameters: params)
    }
}
