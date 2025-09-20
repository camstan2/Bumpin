import Foundation
import FirebaseFirestore

class AITopicManager {
    static let shared = AITopicManager()
    private let db = Firestore.firestore()
    private let claudeService = ClaudeAPIService.shared
    
    // MARK: - Topic Similarity Detection
    
    struct SimilarityResult {
        let topic: DiscussionTopic
        let similarityScore: Double
        let matchingFeatures: [String]
        let suggestedAction: SuggestedAction
        
        enum SuggestedAction {
            case join
            case merge
            case keepSeparate
            case suggestAlternative(String)
        }
    }
    
    func findSimilarTopics(to proposedTopic: ProposedTopic) async throws -> [SimilarityResult] {
        // Prepare topic for AI analysis
        let topicFeatures = try await extractTopicFeatures(proposedTopic)
        
        // Get existing topics in the same category
        let existingTopics = try await TopicService.shared.getTopics(for: proposedTopic.category)
        
        var results: [SimilarityResult] = []
        
        for topic in existingTopics {
            let similarity = try await calculateTopicSimilarity(topicFeatures, topic)
            
            if similarity.score > 0.6 { // 60% similarity threshold
                results.append(SimilarityResult(
                    topic: topic,
                    similarityScore: similarity.score,
                    matchingFeatures: similarity.features,
                    suggestedAction: determineSuggestedAction(similarity.score, similarity.features)
                ))
            }
        }
        
        return results.sorted { $0.similarityScore > $1.similarityScore }
    }
    
    func suggestTopicName(_ description: String, category: DiscussionCategory) async throws -> [String] {
        let prompt = """
        Based on this description: "\(description)" in the \(category.displayName) category, 
        suggest 5 specific, engaging topic names that would be good for discussion. 
        Make them concise (under 50 characters) and specific to the topic.
        
        Format as a JSON array of strings.
        """
        
        let response = try await claudeService.callClaude(prompt: prompt)
        return parseTopicSuggestions(response)
    }
    
    func categorizeTopic(_ name: String, _ description: String) async throws -> DiscussionCategory {
        let prompt = """
        Categorize this discussion topic into one of these categories:
        \(DiscussionCategory.allCases.map { "\($0.rawValue): \($0.displayName)" }.joined(separator: ", "))
        
        Topic: "\(name)"
        Description: "\(description)"
        
        Respond with just the category key (e.g., "music", "sports").
        """
        
        let response = try await claudeService.callClaude(prompt: prompt)
        return DiscussionCategory(rawValue: response.trimmingCharacters(in: .whitespacesAndNewlines)) ?? .other
    }
    
    func moderateTopic(_ name: String, _ description: String?) async throws -> TopicModerationResult {
        let prompt = """
        Moderate this discussion topic for appropriateness:
        Name: "\(name)"
        Description: "\(description ?? "")"
        
        Check for:
        - Inappropriate content
        - Spam or promotional content
        - Offensive language
        - Copyright violations
        - Misleading information
        
        Respond with JSON: {"approved": boolean, "reason": "string", "suggestions": ["string"]}
        """
        
        let response = try await claudeService.callClaude(prompt: prompt)
        return parseModerationResult(response)
    }
    
    // MARK: - Private Methods
    
    private func extractTopicFeatures(_ topic: ProposedTopic) async throws -> TopicFeatures {
        let prompt = """
        Extract key features from this discussion topic:
        Name: "\(topic.name)"
        Category: "\(topic.category.displayName)"
        Description: "\(topic.description ?? "")"
        Tags: \(topic.tags.joined(separator: ", "))
        
        Extract:
        1. Main concepts (3-5 key concepts)
        2. Keywords (5-10 important keywords)
        3. Topic type (specific, general, trending, etc.)
        4. Target audience
        
        Respond with JSON format.
        """
        
        let response = try await claudeService.callClaude(prompt: prompt)
        return parseTopicFeatures(response)
    }
    
    private func calculateTopicSimilarity(_ features1: TopicFeatures, _ topic2: DiscussionTopic) async throws -> SimilarityAnalysis {
        let prompt = """
        Compare these two discussion topics for similarity:
        
        Topic 1 Features:
        \(features1.toJSONString())
        
        Topic 2:
        Name: "\(topic2.name)"
        Description: "\(topic2.description ?? "")"
        Tags: \(topic2.tags.joined(separator: ", "))
        
        Calculate similarity score (0.0 to 1.0) and list matching features.
        
        Respond with JSON: {"score": number, "features": ["string"]}
        """
        
        let response = try await claudeService.callClaude(prompt: prompt)
        return parseSimilarityAnalysis(response)
    }
    
    private func determineSuggestedAction(_ score: Double, _ features: [String]) -> SimilarityResult.SuggestedAction {
        if score > 0.9 {
            return .merge
        } else if score > 0.8 {
            return .join
        } else if score > 0.6 {
            return .suggestAlternative("Consider joining existing discussion")
        } else {
            return .keepSeparate
        }
    }
    
    // MARK: - Parsing Methods
    
    private func parseTopicSuggestions(_ response: String) -> [String] {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return json
    }
    
    private func parseTopicFeatures(_ response: String) -> TopicFeatures {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return TopicFeatures()
        }
        
        return TopicFeatures(
            concepts: json["concepts"] as? [String] ?? [],
            keywords: json["keywords"] as? [String] ?? [],
            topicType: json["topicType"] as? String ?? "general",
            targetAudience: json["targetAudience"] as? String ?? "general"
        )
    }
    
    private func parseSimilarityAnalysis(_ response: String) -> SimilarityAnalysis {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return SimilarityAnalysis(score: 0.0, features: [])
        }
        
        return SimilarityAnalysis(
            score: json["score"] as? Double ?? 0.0,
            features: json["features"] as? [String] ?? []
        )
    }
    
    private func parseModerationResult(_ response: String) -> TopicModerationResult {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return TopicModerationResult(approved: false, reason: "Unable to parse moderation result", suggestions: [])
        }
        
        return TopicModerationResult(
            approved: json["approved"] as? Bool ?? false,
            reason: json["reason"] as? String ?? "No reason provided",
            suggestions: json["suggestions"] as? [String] ?? []
        )
    }
}

// MARK: - Supporting Types

struct TopicFeatures {
    let concepts: [String]
    let keywords: [String]
    let topicType: String
    let targetAudience: String
    
    init(concepts: [String] = [], keywords: [String] = [], topicType: String = "general", targetAudience: String = "general") {
        self.concepts = concepts
        self.keywords = keywords
        self.topicType = topicType
        self.targetAudience = targetAudience
    }
    
    func toJSONString() -> String {
        let dict: [String: Any] = [
            "concepts": concepts,
            "keywords": keywords,
            "topicType": topicType,
            "targetAudience": targetAudience
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return string
    }
}

struct SimilarityAnalysis {
    let score: Double
    let features: [String]
}

struct TopicModerationResult {
    let approved: Bool
    let reason: String
    let suggestions: [String]
}
