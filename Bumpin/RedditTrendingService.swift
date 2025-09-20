import Foundation

// MARK: - Reddit Trending Service

struct RedditTrendingService {
    
    static let shared = RedditTrendingService()
    private init() {}
    
    // MARK: - Reddit API Models
    
    struct RedditPost: Codable {
        let title: String
        let selftext: String?
        let score: Int
        let num_comments: Int
        let created_utc: Double
        let subreddit: String
        let permalink: String
        let url: String?
        
        var createdDate: Date {
            return Date(timeIntervalSince1970: created_utc)
        }
        
        var isRecentlyTrending: Bool {
            let hoursAgo = Date().timeIntervalSince(createdDate) / 3600
            return hoursAgo <= 24 && score > 1000 && num_comments > 50
        }
    }
    
    struct RedditResponse: Codable {
        let data: RedditData
    }
    
    struct RedditData: Codable {
        let children: [RedditChild]
    }
    
    struct RedditChild: Codable {
        let data: RedditPost
    }
    
    // MARK: - Category to Subreddit Mapping
    
    private func getSubredditsForCategory(_ category: TopicCategory) -> [String] {
        switch category {
        case .trending:
            return ["popular", "all", "todayilearned", "askreddit", "news"]
        case .movies:
            return ["movies", "television", "netflix", "marvelstudios", "dc_cinematic"]
        case .tv:
            return ["television", "netflix", "hulu", "amazonprime", "streaming"]
        case .sports:
            return ["sports", "nfl", "nba", "soccer", "baseball", "hockey"]
        case .gaming:
            return ["gaming", "games", "pcgaming", "nintendo", "ps5", "xbox"]
        case .music:
            return ["music", "hiphopheads", "popheads", "listentothis", "wearethemusicians"]
        case .entertainment:
            return ["entertainment", "celebrity", "popculture", "television", "funny"]
        case .politics:
            return ["politics", "worldnews", "politicaldiscussion", "neutralpolitics"]
        case .business:
            return ["business", "entrepreneur", "investing", "stocks", "economics"]
        case .arts:
            return ["art", "design", "photography", "museum", "architecture"]
        case .art:
            return ["art", "design", "photography", "museum", "architecture"]
        case .food:
            return ["food", "cooking", "recipes", "foodporn", "askculinary"]
        case .lifestyle:
            return ["lifestyle", "lifehacks", "getmotivated", "selfimprovement"]
        case .education:
            return ["education", "teachers", "studytips", "university", "learnprogramming"]
        case .science:
            return ["science", "technology", "futurology", "space", "askscience"]
        case .technology:
            return ["technology", "gadgets", "apple", "android", "programming"]
        case .books:
            return ["books", "booksuggestions", "fantasy", "scifi", "literature"]
        case .travel:
            return ["travel", "solotravel", "backpacking", "digitalnomad", "earthporn"]
        case .fashion:
            return ["fashion", "malefashionadvice", "femalefashionadvice", "streetwear", "frugalmalefashion"]
        case .worldNews:
            return ["worldnews", "news", "internationalnews", "europe", "asia"]
        case .health:
            return ["health", "fitness", "loseit", "mentalhealth", "nutrition"]
        case .automotive:
            return ["cars", "automotive", "electricvehicles", "teslamotors", "formula1"]
        case .other:
            return ["askreddit", "todayilearned", "explainlikeimfive", "nostupidquestions", "mildlyinteresting"]
        }
    }
    
    // MARK: - Trend Detection Methods
    
    /// Fetch trending posts from Reddit for a specific category
    func fetchTrendingPosts(for category: TopicCategory, limit: Int = 25) async -> [RedditPost] {
        let subreddits = getSubredditsForCategory(category)
        var allPosts: [RedditPost] = []
        
        for subreddit in subreddits.prefix(3) { // Limit to 3 subreddits to avoid rate limiting
            do {
                let posts = try await fetchPostsFromSubreddit(subreddit, limit: limit / 3)
                allPosts.append(contentsOf: posts)
            } catch {
                print("❌ Failed to fetch from r/\(subreddit): \(error)")
            }
        }
        
        // Filter and sort by trending criteria
        return allPosts
            .filter { $0.isRecentlyTrending }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Convert Reddit posts to TrendingTopic suggestions
    func generateTopicSuggestions(for category: TopicCategory) async -> [TrendingTopic] {
        let posts = await fetchTrendingPosts(for: category, limit: 15)
        
        return posts.compactMap { post in
            // Extract topic from Reddit post
            let topicTitle = extractTopicFromPost(post)
            guard !topicTitle.isEmpty else { return nil }
            
            let keywords = extractKeywordsFromPost(post)
            let popularity = calculatePopularityFromPost(post)
            
            return TrendingTopic(
                title: topicTitle,
                description: "Trending topic from Reddit: \(post.title)",
                category: category,
                keywords: keywords,
                source: .ai
            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchPostsFromSubreddit(_ subreddit: String, limit: Int) async throws -> [RedditPost] {
        let urlString = "https://www.reddit.com/r/\(subreddit)/hot.json?limit=\(limit)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bumpin-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(RedditResponse.self, from: data)
        
        return response.data.children.map { $0.data }
    }
    
    private func extractTopicFromPost(_ post: RedditPost) -> String {
        let title = post.title
        
        // Clean up the title to make it a good discussion topic
        var cleanTitle = title
        
        // Remove common Reddit prefixes
        let prefixesToRemove = ["[Serious]", "[Discussion]", "[Question]", "ELI5:", "TIL:", "PSA:", "AMA:", "TIFU:"]
        for prefix in prefixesToRemove {
            cleanTitle = cleanTitle.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Limit length
        if cleanTitle.count > 80 {
            cleanTitle = String(cleanTitle.prefix(77)) + "..."
        }
        
        return cleanTitle
    }
    
    private func extractKeywordsFromPost(_ post: RedditPost) -> [String] {
        let text = (post.title + " " + (post.selftext ?? "")).lowercased()
        
        // Simple keyword extraction (could be enhanced with NLP)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 } // Filter short words
            .filter { !commonWords.contains($0) } // Filter common words
            .prefix(5) // Limit to 5 keywords
        
        return Array(words)
    }
    
    private func calculatePopularityFromPost(_ post: RedditPost) -> Double {
        // Calculate popularity based on Reddit metrics
        let scoreWeight = 0.6
        let commentWeight = 0.3
        let recencyWeight = 0.1
        
        let normalizedScore = min(1.0, Double(post.score) / 10000.0) // Normalize against 10k upvotes
        let normalizedComments = min(1.0, Double(post.num_comments) / 1000.0) // Normalize against 1k comments
        
        let hoursAgo = Date().timeIntervalSince(post.createdDate) / 3600.0
        let recencyScore = max(0.0, 1.0 - (hoursAgo / 24.0)) // Decay over 24 hours
        
        return (normalizedScore * scoreWeight) + 
               (normalizedComments * commentWeight) + 
               (recencyScore * recencyWeight)
    }
    
    // Common words to filter out when extracting keywords
    private let commonWords: Set<String> = [
        "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "from", "about", "into", "through", "during", "before", "after", "above", "below",
        "up", "down", "out", "off", "over", "under", "again", "further", "then", "once",
        "here", "there", "when", "where", "why", "how", "all", "any", "both", "each",
        "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only",
        "own", "same", "so", "than", "too", "very", "can", "will", "just", "should",
        "now", "what", "this", "that", "these", "those", "they", "them", "their",
        "would", "could", "should", "might", "must", "shall", "may", "need", "want"
    ]
}

// MARK: - Background Update Service

class TrendingTopicsUpdateService {
    
    static let shared = TrendingTopicsUpdateService()
    private init() {}
    
    /// Run comprehensive trending topics update
    func runFullUpdate() async {
        print("🔄 Starting comprehensive trending topics update...")
        
        // Update metrics for existing topics
        await TrendingTopicsService.shared.updateAllTopicMetrics()
        
        // Run AI trend detection for enabled categories
        for category in TopicCategory.allCases {
            await runCategoryUpdate(category: category)
        }
        
        print("✅ Comprehensive update completed!")
    }
    
    private func runCategoryUpdate(category: TopicCategory) async {
        print("🔄 Updating \(category.displayName) trends...")
        
        // Fetch Reddit suggestions
        let redditSuggestions = await RedditTrendingService.shared.generateTopicSuggestions(for: category)
        
        // Add high-quality suggestions to Firebase
        let service = TrendingTopicsService.shared
        
        for suggestion in redditSuggestions.prefix(5) { // Add up to 5 AI suggestions per category
            let success = await service.addManualTopic(
                category: category,
                title: suggestion.title,
                description: suggestion.description,
                keywords: suggestion.keywords,
                priority: 3 // Lower priority than manual topics
            )
            
            if success {
                print("✅ Added AI topic: \(suggestion.title)")
            }
        }
    }
    
    /// Schedule periodic updates (call from app delegate or background task)
    func schedulePeriodicUpdates() {
        // This would typically be called from a background task
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.runFullUpdate()
            }
        }
    }
}
