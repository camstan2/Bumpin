import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Reporting Service

@MainActor
class ReportingService: ObservableObject {
    static let shared = ReportingService()
    
    private let db = Firestore.firestore()
    
    // MARK: - Report Content
    
    func reportContent(
        contentId: String,
        contentType: ReportableContentType,
        reportedUserId: String,
        reportedUsername: String,
        reason: ReportReason,
        additionalDetails: String? = nil
    ) async -> Bool {
        guard let reporterUserId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated")
            return false
        }
        
        // Prevent self-reporting
        if reporterUserId == reportedUserId {
            print("❌ Cannot report own content")
            return false
        }
        
        // Check if user has already reported this content
        if await hasUserReportedContent(contentId: contentId, reporterUserId: reporterUserId) {
            print("❌ User has already reported this content")
            return false
        }
        
        let report = ContentReport(
            id: UUID().uuidString,
            contentId: contentId,
            contentType: contentType,
            reporterUserId: reporterUserId,
            reportedUserId: reportedUserId,
            reportedUsername: reportedUsername,
            reason: reason,
            additionalDetails: additionalDetails,
            timestamp: Date(),
            status: .pending
        )
        
        do {
            try await db.collection("contentReports").document(report.id).setData(from: report)
            
            // Update reported content's report count
            await incrementReportCount(contentId: contentId, contentType: contentType)
            
            // Log analytics
            AnalyticsService.shared.logEvent("content_reported", parameters: [
                "content_type": contentType.rawValue,
                "reason": reason.rawValue,
                "reported_user_id": reportedUserId
            ])
            
            print("✅ Content reported successfully")
            return true
            
        } catch {
            print("❌ Failed to submit report: \(error)")
            return false
        }
    }
    
    // MARK: - Report User
    
    func reportUser(
        userId: String,
        username: String,
        reason: UserReportReason,
        additionalDetails: String? = nil,
        relatedContentId: String? = nil
    ) async -> Bool {
        guard let reporterUserId = Auth.auth().currentUser?.uid else {
            print("❌ User not authenticated")
            return false
        }
        
        // Prevent self-reporting
        if reporterUserId == userId {
            print("❌ Cannot report yourself")
            return false
        }
        
        let report = UserReport(
            id: UUID().uuidString,
            reporterUserId: reporterUserId,
            reportedUserId: userId,
            reportedUsername: username,
            reason: reason,
            additionalDetails: additionalDetails,
            relatedContentId: relatedContentId,
            timestamp: Date(),
            status: .pending
        )
        
        do {
            try await db.collection("userReports").document(report.id).setData(from: report)
            
            // Update user's report count
            await incrementUserReportCount(userId: userId)
            
            // Log analytics
            AnalyticsService.shared.logEvent("user_reported", parameters: [
                "reason": reason.rawValue,
                "reported_user_id": userId
            ])
            
            print("✅ User reported successfully")
            return true
            
        } catch {
            print("❌ Failed to submit user report: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func hasUserReportedContent(contentId: String, reporterUserId: String) async -> Bool {
        do {
            let snapshot = try await db.collection("contentReports")
                .whereField("contentId", isEqualTo: contentId)
                .whereField("reporterUserId", isEqualTo: reporterUserId)
                .limit(to: 1)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            print("❌ Error checking existing reports: \(error)")
            return false
        }
    }
    
    private func incrementReportCount(contentId: String, contentType: ReportableContentType) async {
        let collectionName = contentType.firestoreCollection
        let docRef = db.collection(collectionName).document(contentId)
        
        do {
            try await docRef.updateData([
                "reportCount": FieldValue.increment(Int64(1)),
                "lastReported": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ Failed to increment report count: \(error)")
        }
    }
    
    private func incrementUserReportCount(userId: String) async {
        let userRef = db.collection("users").document(userId)
        
        do {
            try await userRef.updateData([
                "reportCount": FieldValue.increment(Int64(1)),
                "lastReported": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ Failed to increment user report count: \(error)")
        }
    }
    
    // MARK: - Get Reports (for admin)
    
    func getPendingReports() async -> [ContentReport] {
        do {
            let snapshot = try await db.collection("contentReports")
                .whereField("status", isEqualTo: ReportStatus.pending.rawValue)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            return snapshot.documents.compactMap { try? $0.data(as: ContentReport.self) }
        } catch {
            print("❌ Failed to fetch pending reports: \(error)")
            return []
        }
    }
    
    func getPendingUserReports() async -> [UserReport] {
        do {
            let snapshot = try await db.collection("userReports")
                .whereField("status", isEqualTo: ReportStatus.pending.rawValue)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            return snapshot.documents.compactMap { try? $0.data(as: UserReport.self) }
        } catch {
            print("❌ Failed to fetch pending user reports: \(error)")
            return []
        }
    }
    
    // MARK: - Admin Actions
    
    func resolveReport(reportId: String, action: ReportAction, adminNotes: String? = nil) async -> Bool {
        do {
            try await db.collection("contentReports").document(reportId).updateData([
                "status": ReportStatus.resolved.rawValue,
                "action": action.rawValue,
                "adminNotes": adminNotes ?? "",
                "resolvedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ Report resolved with action: \(action.rawValue)")
            return true
        } catch {
            print("❌ Failed to resolve report: \(error)")
            return false
        }
    }
    
    func resolveUserReport(reportId: String, action: UserReportAction, adminNotes: String? = nil) async -> Bool {
        do {
            try await db.collection("userReports").document(reportId).updateData([
                "status": ReportStatus.resolved.rawValue,
                "action": action.rawValue,
                "adminNotes": adminNotes ?? "",
                "resolvedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ User report resolved with action: \(action.rawValue)")
            return true
        } catch {
            print("❌ Failed to resolve user report: \(error)")
            return false
        }
    }
}

// MARK: - Data Models

extension ReportingService {
struct ContentReport: Codable, Identifiable {
    let id: String
    let contentId: String
    let contentType: ReportableContentType
    let reporterUserId: String
    let reportedUserId: String
    let reportedUsername: String
    let reason: ReportReason
    let additionalDetails: String?
    let timestamp: Date
    var status: ReportStatus
    var action: ReportAction?
    var adminNotes: String?
    var resolvedAt: Date?
}
}

struct UserReport: Codable, Identifiable {
    let id: String
    let reporterUserId: String
    let reportedUserId: String
    let reportedUsername: String
    let reason: UserReportReason
    let additionalDetails: String?
    let relatedContentId: String?
    let timestamp: Date
    var status: ReportStatus
    var action: UserReportAction?
    var adminNotes: String?
    var resolvedAt: Date?
}

enum ReportableContentType: String, Codable, CaseIterable {
    case musicReview = "music_review"
    case comment = "comment"
    case chatMessage = "chat_message"
    case partyName = "party_name"
    case username = "username"
    case userBio = "user_bio"
    case topicName = "topic_name"
    case topicDescription = "topic_description"
    
    var firestoreCollection: String {
        switch self {
        case .musicReview: return "logs"
        case .comment: return "comments"
        case .chatMessage: return "chatMessages"
        case .partyName: return "parties"
        case .username, .userBio: return "users"
        case .topicName, .topicDescription: return "topics"
        }
    }
    
    var displayName: String {
        switch self {
        case .musicReview: return "Music Review"
        case .comment: return "Comment"
        case .chatMessage: return "Chat Message"
        case .partyName: return "Party Name"
        case .username: return "Username"
        case .userBio: return "User Bio"
        case .topicName: return "Topic Name"
        case .topicDescription: return "Topic Description"
        }
    }
}

enum ReportReason: String, Codable, CaseIterable {
    case harassment = "harassment"
    case hateSpeech = "hate_speech"
    case inappropriateContent = "inappropriate_content"
    case spam = "spam"
    case violence = "violence"
    case personalInformation = "personal_information"
    case copyrightViolation = "copyright_violation"
    case impersonation = "impersonation"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .harassment: return "Harassment or Bullying"
        case .hateSpeech: return "Hate Speech"
        case .inappropriateContent: return "Inappropriate Content"
        case .spam: return "Spam"
        case .violence: return "Violence or Threats"
        case .personalInformation: return "Sharing Personal Information"
        case .copyrightViolation: return "Copyright Violation"
        case .impersonation: return "Impersonation"
        case .other: return "Other"
        }
    }
    
    var description: String {
        switch self {
        case .harassment: return "Targeting someone with unwelcome behavior"
        case .hateSpeech: return "Content that attacks people based on identity"
        case .inappropriateContent: return "Sexual, violent, or otherwise inappropriate content"
        case .spam: return "Repetitive, promotional, or irrelevant content"
        case .violence: return "Threats of violence or encouraging harm"
        case .personalInformation: return "Sharing someone's private information"
        case .copyrightViolation: return "Using copyrighted content without permission"
        case .impersonation: return "Pretending to be someone else"
        case .other: return "Something else that violates our community guidelines"
        }
    }
}

enum UserReportReason: String, Codable, CaseIterable {
    case harassment = "harassment"
    case abusiveBehavior = "abusive_behavior"
    case hateSpeech = "hate_speech"
    case spam = "spam"
    case impersonation = "impersonation"
    case underage = "underage"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .harassment: return "Harassment"
        case .abusiveBehavior: return "Abusive Behavior"
        case .hateSpeech: return "Hate Speech"
        case .spam: return "Spam Account"
        case .impersonation: return "Impersonation"
        case .underage: return "Underage User"
        case .other: return "Other"
        }
    }
}

enum ReportStatus: String, Codable {
    case pending = "pending"
    case resolved = "resolved"
    case dismissed = "dismissed"
}

enum ReportAction: String, Codable {
    case contentRemoved = "content_removed"
    case userWarned = "user_warned"
    case userMuted = "user_muted"
    case userBanned = "user_banned"
    case noAction = "no_action"
}

enum UserReportAction: String, Codable {
    case userWarned = "user_warned"
    case userMuted = "user_muted"
    case userBanned = "user_banned"
    case accountSuspended = "account_suspended"
    case noAction = "no_action"
}
