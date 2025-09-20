import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Content Moderation Service

@MainActor
class ContentModerationService: ObservableObject {
    static let shared = ContentModerationService()
    
    private let db = Firestore.firestore()
    
    // MARK: - Content Filtering
    
    /// Filters content and returns moderation result
    func moderateContent(_ content: String, type: ContentType, userId: String? = nil) async -> ModerationResult {
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanContent.isEmpty else {
            return ModerationResult(isAllowed: false, reason: "Empty content not allowed", severity: .low)
        }
        
        // Check length limits
        if let lengthResult = checkContentLength(cleanContent, type: type) {
            return lengthResult
        }
        
        // Check for profanity and inappropriate content
        if let profanityResult = await checkProfanity(cleanContent) {
            await logViolation(userId: userId, content: cleanContent, type: type, violation: profanityResult.reason)
            return profanityResult
        }
        
        // Check for spam patterns
        if let spamResult = checkSpamPatterns(cleanContent) {
            await logViolation(userId: userId, content: cleanContent, type: type, violation: spamResult.reason)
            return spamResult
        }
        
        // Check for personal information
        if let piiResult = checkPersonalInformation(cleanContent) {
            return piiResult
        }
        
        // Check for hate speech and harassment
        if let hateResult = await checkHateSpeech(cleanContent) {
            await logViolation(userId: userId, content: cleanContent, type: type, violation: hateResult.reason)
            return hateResult
        }
        
        // Content passed all checks
        return ModerationResult(isAllowed: true, reason: "Content approved", severity: .none)
    }
    
    // MARK: - Specific Content Checks
    
    private func checkContentLength(_ content: String, type: ContentType) -> ModerationResult? {
        let maxLength = type.maxLength
        if content.count > maxLength {
            return ModerationResult(
                isAllowed: false,
                reason: "Content exceeds maximum length of \(maxLength) characters",
                severity: .low
            )
        }
        return nil
    }
    
    private func checkProfanity(_ content: String) async -> ModerationResult? {
        let lowercaseContent = content.lowercased()
        
        // Comprehensive profanity list
        let profanityWords = [
            // Strong profanity
            "fuck", "shit", "bitch", "asshole", "damn", "hell", "crap",
            "piss", "bastard", "whore", "slut", "cunt", "cock", "dick",
            
            // Hate speech terms
            "nigger", "faggot", "retard", "spic", "chink", "kike",
            
            // Sexual content
            "porn", "sex", "nude", "naked", "horny", "masturbate",
            
            // Violence
            "kill", "murder", "suicide", "die", "death", "hurt",
            
            // Drugs
            "cocaine", "heroin", "meth", "weed", "marijuana", "drugs"
        ]
        
        // Check for exact matches and variations
        for word in profanityWords {
            if lowercaseContent.contains(word) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Content contains inappropriate language",
                    severity: .high,
                    flaggedWords: [word]
                )
            }
        }
        
        // Check for leetspeak and character substitutions
        let leetSpeakVariations = [
            ("@", "a"), ("3", "e"), ("1", "i"), ("0", "o"), ("5", "s"),
            ("7", "t"), ("4", "a"), ("!", "i"), ("$", "s")
        ]
        
        var normalizedContent = lowercaseContent
        for (leet, normal) in leetSpeakVariations {
            normalizedContent = normalizedContent.replacingOccurrences(of: leet, with: normal)
        }
        
        for word in profanityWords {
            if normalizedContent.contains(word) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Content contains inappropriate language (obfuscated)",
                    severity: .high,
                    flaggedWords: [word]
                )
            }
        }
        
        return nil
    }
    
    private func checkSpamPatterns(_ content: String) -> ModerationResult? {
        // Check for excessive repetition
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        let wordCounts = Dictionary(grouping: words, by: { $0.lowercased() })
        
        for (word, occurrences) in wordCounts {
            if occurrences.count > 5 && word.count > 2 {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Content appears to be spam (excessive repetition)",
                    severity: .medium
                )
            }
        }
        
        // Check for promotional content
        let promotionalPatterns = [
            "buy now", "click here", "free money", "make money fast",
            "visit my", "check out my", "follow me", "subscribe to",
            "www.", "http", ".com", ".net", ".org"
        ]
        
        let lowercaseContent = content.lowercased()
        for pattern in promotionalPatterns {
            if lowercaseContent.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Content appears to be promotional spam",
                    severity: .medium
                )
            }
        }
        
        return nil
    }
    
    private func checkPersonalInformation(_ content: String) -> ModerationResult? {
        // Email pattern
        let emailRegex = try! NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        if emailRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
            return ModerationResult(
                isAllowed: false,
                reason: "Content contains email address",
                severity: .medium
            )
        }
        
        // Phone number pattern
        let phoneRegex = try! NSRegularExpression(pattern: "\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b")
        if phoneRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
            return ModerationResult(
                isAllowed: false,
                reason: "Content contains phone number",
                severity: .medium
            )
        }
        
        // Social media handles
        let socialPatterns = ["@", "instagram.com", "twitter.com", "tiktok.com", "snapchat"]
        let lowercaseContent = content.lowercased()
        for pattern in socialPatterns {
            if lowercaseContent.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Content contains social media information",
                    severity: .low
                )
            }
        }
        
        return nil
    }
    
    private func checkHateSpeech(_ content: String) async -> ModerationResult? {
        let lowercaseContent = content.lowercased()
        
        // Hate speech patterns
        let hatePatterns = [
            // Racial slurs and discrimination
            "racist", "racism", "white power", "black lives don't matter",
            
            // Religious discrimination
            "muslim terrorist", "jewish conspiracy", "christian fanatic",
            
            // LGBTQ+ discrimination
            "gay agenda", "trans freak", "homo",
            
            // Gender discrimination
            "women belong in kitchen", "men are trash",
            
            // Threats and violence
            "i will kill", "you should die", "kill yourself", "kys",
            "i hope you", "you deserve to die",
            
            // Harassment patterns
            "ugly", "fat", "stupid", "loser", "worthless", "pathetic"
        ]
        
        for pattern in hatePatterns {
            if lowercaseContent.contains(pattern) {
                return ModerationResult(
                    isAllowed: false,
                    reason: "Content contains hate speech or harassment",
                    severity: .high,
                    flaggedWords: [pattern]
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Violation Logging
    
    private func logViolation(userId: String?, content: String, type: ContentType, violation: String) async {
        guard let userId = userId else { return }
        
        let violation = ContentViolation(
            id: UUID().uuidString,
            userId: userId,
            content: content,
            contentType: type,
            violationType: violation,
            timestamp: Date(),
            severity: .medium,
            status: .pending
        )
        
        do {
            try await db.collection("contentViolations").document(violation.id).setData(from: violation)
            
            // Update user violation count
            await updateUserViolationCount(userId: userId)
            
        } catch {
            print("❌ Failed to log content violation: \(error)")
        }
    }
    
    private func updateUserViolationCount(userId: String) async {
        do {
            let userRef = db.collection("users").document(userId)
            try await userRef.updateData([
                "violationCount": FieldValue.increment(Int64(1)),
                "lastViolation": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ Failed to update user violation count: \(error)")
        }
    }
    
    // MARK: - User Status Checking
    
    func checkUserStatus(userId: String) async -> UserModerationStatus {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let violationCount = userDoc.data()?["violationCount"] as? Int ?? 0
            let isBanned = userDoc.data()?["isBanned"] as? Bool ?? false
            let isMuted = userDoc.data()?["isMuted"] as? Bool ?? false
            
            if isBanned {
                return .banned
            } else if isMuted {
                return .muted
            } else if violationCount >= 5 {
                return .restricted
            } else if violationCount >= 3 {
                return .warning
            } else {
                return .good
            }
        } catch {
            print("❌ Failed to check user status: \(error)")
            return .good
        }
    }
    
    // MARK: - Content Pre-filtering
    
    func prefilterContent(_ content: String) -> String {
        var filtered = content
        
        // Remove excessive whitespace
        filtered = filtered.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Remove excessive punctuation
        filtered = filtered.replacingOccurrences(of: "[!]{3,}", with: "!", options: .regularExpression)
        filtered = filtered.replacingOccurrences(of: "[?]{3,}", with: "?", options: .regularExpression)
        
        // Limit consecutive characters
        filtered = filtered.replacingOccurrences(of: "([a-zA-Z])\\1{3,}", with: "$1$1", options: .regularExpression)
        
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Data Models

struct ModerationResult {
    let isAllowed: Bool
    let reason: String
    let severity: ViolationSeverity
    let flaggedWords: [String]
    
    init(isAllowed: Bool, reason: String, severity: ViolationSeverity, flaggedWords: [String] = []) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.severity = severity
        self.flaggedWords = flaggedWords
    }
}

struct ContentViolation: Codable {
    let id: String
    let userId: String
    let content: String
    let contentType: ContentType
    let violationType: String
    let timestamp: Date
    let severity: ViolationSeverity
    var status: ViolationStatus
}

enum ContentType: String, Codable, CaseIterable {
    case review = "review"
    case comment = "comment"
    case chatMessage = "chat_message"
    case partyName = "party_name"
    case username = "username"
    case bio = "bio"
    case topicName = "topic_name"
    case topicDescription = "topic_description"
    
    var maxLength: Int {
        switch self {
        case .review: return 1000
        case .comment: return 500
        case .chatMessage: return 200
        case .partyName: return 50
        case .username: return 30
        case .bio: return 150
        case .topicName: return 100
        case .topicDescription: return 300
        }
    }
}

enum ViolationSeverity: String, Codable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum ViolationStatus: String, Codable {
    case pending = "pending"
    case reviewed = "reviewed"
    case dismissed = "dismissed"
    case confirmed = "confirmed"
}

enum UserModerationStatus {
    case good
    case warning
    case restricted
    case muted
    case banned
}

// MARK: - Content Moderation Extensions

extension ContentModerationService {
    
    /// Quick check for obviously inappropriate content
    func quickFilter(_ content: String) -> Bool {
        let lowercaseContent = content.lowercased()
        let immediateRejectWords = ["fuck", "shit", "nigger", "faggot", "kill yourself", "kys"]
        
        for word in immediateRejectWords {
            if lowercaseContent.contains(word) {
                return false
            }
        }
        return true
    }
    
    /// Moderate music review content
    func moderateReview(_ review: String, userId: String) async -> ModerationResult {
        return await moderateContent(review, type: .review, userId: userId)
    }
    
    /// Moderate chat message content
    func moderateChatMessage(_ message: String, userId: String) async -> ModerationResult {
        return await moderateContent(message, type: .chatMessage, userId: userId)
    }
    
    /// Moderate party name content
    func moderatePartyName(_ name: String, userId: String) async -> ModerationResult {
        return await moderateContent(name, type: .partyName, userId: userId)
    }
    
    /// Moderate username content
    func moderateUsername(_ username: String, userId: String) async -> ModerationResult {
        return await moderateContent(username, type: .username, userId: userId)
    }
}
