import Foundation
import FirebaseFirestore

// MARK: - Trending Topics Seed Data

struct TrendingTopicsSeedData {
    
    static let shared = TrendingTopicsSeedData()
    private init() {}
    
    // MARK: - Seed All Categories
    
    func seedAllCategories() async {
        print("🌱 Starting to seed trending topics for all categories...")
        
        for category in TopicCategory.allCases {
            await seedCategory(category)
        }
        
        print("✅ Completed seeding all categories!")
    }
    
    func seedCategory(_ category: TopicCategory) async {
        print("🌱 Seeding \(category.displayName) topics...")
        
        let topics = getTopicsForCategory(category)
        let service = TrendingTopicsService.shared
        
        for (index, topicData) in topics.enumerated() {
            let success = await service.addManualTopic(
                category: category,
                title: topicData.title,
                description: topicData.description,
                keywords: topicData.keywords,
                priority: topicData.priority ?? (10 - index), // Higher priority for earlier topics
                expiresAt: topicData.expiresAt
            )
            
            if success {
                print("✅ Added: \(topicData.title)")
            } else {
                print("❌ Failed to add: \(topicData.title)")
            }
        }
    }
    
    // MARK: - Category-Specific Topics
    
    private func getTopicsForCategory(_ category: TopicCategory) -> [SeedTopicData] {
        switch category {
        case .trending:
            return trendingTopics
        case .movies:
            return movieTopics
        case .tv:
            return movieTopics // Use same topics as movies
        case .sports:
            return sportsTopics
        case .gaming:
            return gamingTopics
        case .music:
            return musicTopics
        case .entertainment:
            return entertainmentTopics
        case .politics:
            return politicsTopics
        case .business:
            return businessTopics
        case .arts:
            return artsTopics
        case .food:
            return foodTopics
        case .lifestyle:
            return lifestyleTopics
        case .education:
            return educationTopics
        case .science:
            return scienceTopics
        case .technology:
            return scienceTopics // Use same topics as science
        case .books:
            return educationTopics // Use same topics as education
        case .travel:
            return lifestyleTopics // Use same topics as lifestyle
        case .fashion:
            return lifestyleTopics // Use same topics as lifestyle
        case .art:
            return artsTopics // Use same topics as arts
        case .worldNews:
            return worldNewsTopics
        case .health:
            return healthTopics
        case .automotive:
            return automotiveTopics
        case .other:
            return trendingTopics // Use same topics as trending
        }
    }
}

// MARK: - Seed Topic Data Structure

struct SeedTopicData {
    let title: String
    let description: String
    let keywords: [String]
    let priority: Int?
    let expiresAt: Date?
    
    init(title: String, description: String, keywords: [String], priority: Int? = nil, expiresAt: Date? = nil) {
        self.title = title
        self.description = description
        self.keywords = keywords
        self.priority = priority
        self.expiresAt = expiresAt
    }
}

// MARK: - Trending Topics Data

private let trendingTopics: [SeedTopicData] = [
    SeedTopicData(
        title: "What's Viral Today",
        description: "Discuss the latest viral trends, memes, and moments taking over the internet",
        keywords: ["viral", "trending", "memes", "internet", "social media"]
    ),
    SeedTopicData(
        title: "Breaking News Discussion",
        description: "Real-time discussion about breaking news and current events",
        keywords: ["breaking news", "current events", "news", "updates"]
    ),
    SeedTopicData(
        title: "Hot Takes & Opinions",
        description: "Share your hottest takes and controversial opinions on trending topics",
        keywords: ["hot takes", "opinions", "controversial", "debate"]
    ),
    SeedTopicData(
        title: "Social Media Buzz",
        description: "What's buzzing on Twitter, TikTok, Instagram, and other platforms",
        keywords: ["social media", "twitter", "tiktok", "instagram", "buzz"]
    ),
    SeedTopicData(
        title: "Celebrity News & Gossip",
        description: "Latest celebrity news, relationships, and entertainment gossip",
        keywords: ["celebrity", "gossip", "entertainment", "news", "relationships"]
    ),
    SeedTopicData(
        title: "Internet Culture",
        description: "Discuss internet culture, online communities, and digital trends",
        keywords: ["internet culture", "online", "digital", "communities"]
    ),
    SeedTopicData(
        title: "Trending Hashtags",
        description: "What hashtags are trending and why they matter",
        keywords: ["hashtags", "trending", "social", "viral"]
    ),
    SeedTopicData(
        title: "Pop Culture Moments",
        description: "Discuss the biggest pop culture moments and their impact",
        keywords: ["pop culture", "moments", "impact", "society"]
    ),
    SeedTopicData(
        title: "Tech & Innovation Buzz",
        description: "Latest tech announcements and innovations making waves",
        keywords: ["tech", "innovation", "announcements", "technology"]
    ),
    SeedTopicData(
        title: "Global Events Impact",
        description: "How global events are shaping conversations worldwide",
        keywords: ["global", "events", "impact", "worldwide", "conversations"]
    )
]

// MARK: - Movies & TV Topics

private let movieTopics: [SeedTopicData] = [
    SeedTopicData(
        title: "Latest Movie Releases",
        description: "Discuss new movies in theaters and streaming platforms",
        keywords: ["movies", "releases", "theaters", "streaming", "new films"]
    ),
    SeedTopicData(
        title: "Netflix & Streaming Shows",
        description: "What's worth watching on Netflix, Hulu, Disney+, and other platforms",
        keywords: ["netflix", "streaming", "shows", "hulu", "disney plus"]
    ),
    SeedTopicData(
        title: "Marvel & DC Universe",
        description: "Discuss the latest superhero movies, shows, and comic book adaptations",
        keywords: ["marvel", "dc", "superhero", "comics", "mcu"]
    ),
    SeedTopicData(
        title: "Oscar & Awards Season",
        description: "Predictions, reactions, and discussions about award shows",
        keywords: ["oscars", "awards", "predictions", "academy awards"]
    ),
    SeedTopicData(
        title: "TV Show Finales",
        description: "Discuss season finales, series endings, and plot twists",
        keywords: ["tv shows", "finales", "endings", "plot twists"]
    ),
    SeedTopicData(
        title: "Horror Movies & Thrillers",
        description: "Share scares, reviews, and recommendations for horror fans",
        keywords: ["horror", "thriller", "scary", "movies", "suspense"]
    ),
    SeedTopicData(
        title: "Anime & Animation",
        description: "Discuss anime series, animated movies, and manga adaptations",
        keywords: ["anime", "animation", "manga", "japanese", "cartoons"]
    ),
    SeedTopicData(
        title: "Movie Theories & Analysis",
        description: "Deep dives into movie plots, theories, and hidden meanings",
        keywords: ["theories", "analysis", "plot", "hidden meanings"]
    ),
    SeedTopicData(
        title: "Classic Films Discussion",
        description: "Revisit and discuss timeless classic movies",
        keywords: ["classic", "films", "timeless", "vintage", "cinema"]
    ),
    SeedTopicData(
        title: "Behind the Scenes",
        description: "Movie production stories, director insights, and filming secrets",
        keywords: ["behind scenes", "production", "director", "filming"]
    )
]

// MARK: - Sports Topics

private let sportsTopics: [SeedTopicData] = [
    SeedTopicData(
        title: "Game Highlights & Reactions",
        description: "Discuss the best plays, moments, and reactions from recent games",
        keywords: ["highlights", "games", "plays", "reactions", "moments"]
    ),
    SeedTopicData(
        title: "Trade Rumors & News",
        description: "Latest trade rumors, signings, and team roster changes",
        keywords: ["trades", "rumors", "signings", "roster", "news"]
    ),
    SeedTopicData(
        title: "Fantasy Sports Strategy",
        description: "Fantasy football, basketball, baseball tips and lineup discussions",
        keywords: ["fantasy", "strategy", "lineup", "tips", "advice"]
    ),
    SeedTopicData(
        title: "Player Performance Analysis",
        description: "Analyze player stats, performances, and career trajectories",
        keywords: ["player", "performance", "stats", "analysis", "careers"]
    ),
    SeedTopicData(
        title: "Season Predictions",
        description: "Predict season outcomes, playoff scenarios, and championship winners",
        keywords: ["predictions", "season", "playoffs", "championship"]
    ),
    SeedTopicData(
        title: "Sports Controversies",
        description: "Discuss controversial calls, decisions, and sports drama",
        keywords: ["controversy", "calls", "decisions", "drama", "refs"]
    ),
    SeedTopicData(
        title: "Olympic & International Sports",
        description: "Olympic games, World Cup, and international competitions",
        keywords: ["olympics", "world cup", "international", "competition"]
    ),
    SeedTopicData(
        title: "College Sports",
        description: "College football, basketball, March Madness, and student athletics",
        keywords: ["college", "march madness", "student", "athletics", "ncaa"]
    ),
    SeedTopicData(
        title: "Sports History & Records",
        description: "Historic moments, record-breaking performances, and sports legends",
        keywords: ["history", "records", "legends", "historic", "moments"]
    ),
    SeedTopicData(
        title: "Sports Technology & Analytics",
        description: "How technology and data analytics are changing sports",
        keywords: ["technology", "analytics", "data", "innovation", "stats"]
    )
]

// MARK: - Gaming Topics

private let gamingTopics: [SeedTopicData] = [
    SeedTopicData(
        title: "New Game Releases",
        description: "Discuss the latest game releases and upcoming titles",
        keywords: ["new games", "releases", "upcoming", "titles", "launch"]
    ),
    SeedTopicData(
        title: "Gaming Tips & Strategies",
        description: "Share tips, tricks, and strategies for popular games",
        keywords: ["tips", "strategies", "tricks", "guides", "help"]
    ),
    SeedTopicData(
        title: "Esports Tournaments",
        description: "Competitive gaming, tournaments, and professional esports",
        keywords: ["esports", "tournaments", "competitive", "professional"]
    ),
    SeedTopicData(
        title: "Gaming Hardware Reviews",
        description: "Reviews and discussions about gaming PCs, consoles, and peripherals",
        keywords: ["hardware", "pc", "console", "peripherals", "reviews"]
    ),
    SeedTopicData(
        title: "Game Development",
        description: "Indie games, game development stories, and behind-the-scenes content",
        keywords: ["development", "indie", "behind scenes", "developers"]
    ),
    SeedTopicData(
        title: "Retro Gaming",
        description: "Classic games, nostalgia, and retro gaming experiences",
        keywords: ["retro", "classic", "nostalgia", "vintage", "old games"]
    ),
    SeedTopicData(
        title: "Gaming Memes & Culture",
        description: "Gaming memes, community culture, and funny moments",
        keywords: ["memes", "culture", "funny", "community", "jokes"]
    ),
    SeedTopicData(
        title: "VR & AR Gaming",
        description: "Virtual and augmented reality gaming experiences",
        keywords: ["vr", "ar", "virtual reality", "augmented", "immersive"]
    ),
    SeedTopicData(
        title: "Mobile Gaming",
        description: "Mobile games, app recommendations, and portable gaming",
        keywords: ["mobile", "apps", "portable", "phone games", "ios"]
    ),
    SeedTopicData(
        title: "Gaming News & Industry",
        description: "Gaming industry news, company updates, and market trends",
        keywords: ["industry", "news", "companies", "market", "trends"]
    )
]

// MARK: - Music Topics

private let musicTopics: [SeedTopicData] = [
    SeedTopicData(
        title: "New Album Drops",
        description: "Discuss the latest album releases and first impressions",
        keywords: ["albums", "releases", "drops", "new music", "artists"]
    ),
    SeedTopicData(
        title: "Concert & Festival Experiences",
        description: "Share concert experiences, festival reviews, and live music moments",
        keywords: ["concerts", "festivals", "live music", "experiences", "shows"]
    ),
    SeedTopicData(
        title: "Music Discovery & Recommendations",
        description: "Discover new artists and share music recommendations",
        keywords: ["discovery", "recommendations", "new artists", "hidden gems"]
    ),
    SeedTopicData(
        title: "Artist Collaborations",
        description: "Discuss surprising collaborations and dream artist pairings",
        keywords: ["collaborations", "features", "artists", "pairings"]
    ),
    SeedTopicData(
        title: "Music Production & Beats",
        description: "Talk about production techniques, beats, and music creation",
        keywords: ["production", "beats", "creation", "techniques", "studio"]
    ),
    SeedTopicData(
        title: "Lyrics Analysis & Meaning",
        description: "Analyze song lyrics, meanings, and artistic interpretations",
        keywords: ["lyrics", "meaning", "analysis", "interpretation", "poetry"]
    ),
    SeedTopicData(
        title: "Music Videos & Visuals",
        description: "Discuss music videos, visual aesthetics, and creative direction",
        keywords: ["music videos", "visuals", "aesthetics", "creative", "direction"]
    ),
    SeedTopicData(
        title: "Throwback Music Thursday",
        description: "Nostalgia trips with classic hits and forgotten gems",
        keywords: ["throwback", "classic", "nostalgia", "hits", "gems"]
    ),
    SeedTopicData(
        title: "Genre Deep Dives",
        description: "Explore specific music genres and their evolution",
        keywords: ["genres", "deep dive", "evolution", "history", "style"]
    ),
    SeedTopicData(
        title: "Music Industry News",
        description: "Industry updates, label news, and music business discussions",
        keywords: ["industry", "labels", "business", "news", "updates"]
    )
]

// MARK: - Entertainment Topics

private let entertainmentTopics: [SeedTopicData] = [
    SeedTopicData(
        title: "Celebrity Drama & News",
        description: "Latest celebrity news, drama, and entertainment industry updates",
        keywords: ["celebrity", "drama", "news", "entertainment", "gossip"]
    ),
    SeedTopicData(
        title: "Award Shows & Red Carpet",
        description: "Award show moments, red carpet fashion, and ceremony highlights",
        keywords: ["awards", "red carpet", "fashion", "ceremony", "glamour"]
    ),
    SeedTopicData(
        title: "Reality TV Drama",
        description: "Reality show drama, contestant discussions, and behind-the-scenes tea",
        keywords: ["reality tv", "drama", "contestants", "behind scenes", "tea"]
    ),
    SeedTopicData(
        title: "Comedy & Stand-Up",
        description: "Comedy specials, stand-up performances, and funny entertainment",
        keywords: ["comedy", "stand up", "funny", "humor", "jokes"]
    ),
    SeedTopicData(
        title: "Podcast Recommendations",
        description: "Share and discover great podcasts across all genres",
        keywords: ["podcasts", "recommendations", "audio", "shows", "listen"]
    ),
    SeedTopicData(
        title: "Influencer & Creator Content",
        description: "Discuss content creators, influencers, and social media personalities",
        keywords: ["influencers", "creators", "content", "youtube", "tiktok"]
    ),
    SeedTopicData(
        title: "Entertainment Industry Insights",
        description: "Behind-the-scenes insights into the entertainment business",
        keywords: ["industry", "insights", "business", "behind scenes", "hollywood"]
    ),
    SeedTopicData(
        title: "Viral Challenges & Trends",
        description: "Latest viral challenges, dance trends, and social media phenomena",
        keywords: ["viral", "challenges", "dance", "trends", "phenomena"]
    ),
    SeedTopicData(
        title: "Fan Theories & Speculation",
        description: "Fan theories about shows, movies, and entertainment mysteries",
        keywords: ["fan theories", "speculation", "mysteries", "theories"]
    ),
    SeedTopicData(
        title: "Entertainment Reviews",
        description: "Reviews and ratings of the latest entertainment content",
        keywords: ["reviews", "ratings", "entertainment", "content", "opinions"]
    )
]

// MARK: - Politics Topics

private let politicsTopics: [SeedTopicData] = [
    SeedTopicData(
        title: "Current Political Events",
        description: "Discuss current political developments and their implications",
        keywords: ["politics", "current events", "government", "policy", "news"]
    ),
    SeedTopicData(
        title: "Election Updates & Analysis",
        description: "Election news, candidate discussions, and voting analysis",
        keywords: ["election", "candidates", "voting", "analysis", "campaigns"]
    ),
    SeedTopicData(
        title: "Policy Discussions",
        description: "In-depth discussions about policies and their real-world impact",
        keywords: ["policy", "legislation", "impact", "government", "law"]
    ),
    SeedTopicData(
        title: "International Relations",
        description: "Global politics, diplomatic relations, and international affairs",
        keywords: ["international", "diplomacy", "global", "relations", "affairs"]
    ),
    SeedTopicData(
        title: "Local Government & Community",
        description: "Local politics, community issues, and grassroots movements",
        keywords: ["local", "community", "grassroots", "movements", "civic"]
    ),
    SeedTopicData(
        title: "Political Commentary",
        description: "Political analysis, commentary, and expert opinions",
        keywords: ["commentary", "analysis", "expert", "opinions", "punditry"]
    ),
    SeedTopicData(
        title: "Voting & Democracy",
        description: "Voting rights, democratic processes, and civic engagement",
        keywords: ["voting", "democracy", "rights", "civic", "engagement"]
    ),
    SeedTopicData(
        title: "Economic Policy Impact",
        description: "How economic policies affect everyday life and communities",
        keywords: ["economic", "policy", "impact", "communities", "economy"]
    ),
    SeedTopicData(
        title: "Social Justice & Rights",
        description: "Social justice movements, civil rights, and equality discussions",
        keywords: ["social justice", "civil rights", "equality", "movements"]
    ),
    SeedTopicData(
        title: "Political History & Context",
        description: "Historical context for current political events and decisions",
        keywords: ["history", "context", "historical", "background", "precedent"]
    )
]

// MARK: - Business Topics

private let businessTopics: [SeedTopicData] = [
    SeedTopicData(
        title: "Startup Success Stories",
        description: "Inspiring startup journeys, funding news, and entrepreneurship tips",
        keywords: ["startup", "entrepreneurship", "funding", "success", "business"]
    ),
    SeedTopicData(
        title: "Stock Market & Investing",
        description: "Market trends, investment strategies, and financial discussions",
        keywords: ["stocks", "investing", "market", "finance", "trading"]
    ),
    SeedTopicData(
        title: "Tech Company Updates",
        description: "Latest news from major tech companies and their impact",
        keywords: ["tech companies", "updates", "apple", "google", "microsoft"]
    ),
    SeedTopicData(
        title: "Economic Trends & Analysis",
        description: "Economic indicators, trends, and their business implications",
        keywords: ["economic", "trends", "analysis", "indicators", "business"]
    ),
    SeedTopicData(
        title: "Remote Work & Future of Work",
        description: "Remote work trends, workplace culture, and future employment",
        keywords: ["remote work", "workplace", "culture", "future", "employment"]
    ),
    SeedTopicData(
        title: "Cryptocurrency & Blockchain",
        description: "Crypto market updates, blockchain technology, and digital assets",
        keywords: ["crypto", "blockchain", "bitcoin", "digital", "assets"]
    ),
    SeedTopicData(
        title: "Business Leadership",
        description: "Leadership strategies, management tips, and executive insights",
        keywords: ["leadership", "management", "executive", "strategy", "tips"]
    ),
    SeedTopicData(
        title: "Industry Disruption",
        description: "How new technologies and companies are disrupting traditional industries",
        keywords: ["disruption", "innovation", "technology", "traditional", "change"]
    ),
    SeedTopicData(
        title: "Sustainability in Business",
        description: "Corporate sustainability, green business practices, and ESG investing",
        keywords: ["sustainability", "green", "esg", "environment", "corporate"]
    ),
    SeedTopicData(
        title: "Small Business Support",
        description: "Small business challenges, solutions, and community support",
        keywords: ["small business", "challenges", "solutions", "support", "local"]
    )
]

// MARK: - Placeholder topics for remaining categories
// (I'll include a few examples for each - you can expand these)

private let artsTopics: [SeedTopicData] = [
    SeedTopicData(title: "Art Exhibition Reviews", description: "Reviews and discussions of current art exhibitions", keywords: ["art", "exhibitions", "reviews", "galleries"]),
    SeedTopicData(title: "Creative Projects", description: "Share and discuss creative art projects", keywords: ["creative", "projects", "art", "design"]),
    SeedTopicData(title: "Artist Spotlights", description: "Spotlight emerging and established artists", keywords: ["artists", "spotlight", "emerging", "talent"])
]

private let foodTopics: [SeedTopicData] = [
    SeedTopicData(title: "Recipe Sharing", description: "Share your favorite recipes and cooking tips", keywords: ["recipes", "cooking", "tips", "food"]),
    SeedTopicData(title: "Restaurant Reviews", description: "Review local restaurants and dining experiences", keywords: ["restaurants", "reviews", "dining", "local"]),
    SeedTopicData(title: "Food Trends", description: "Latest food trends and culinary innovations", keywords: ["food trends", "culinary", "innovations", "new"])
]

private let lifestyleTopics: [SeedTopicData] = [
    SeedTopicData(title: "Wellness Tips", description: "Share wellness tips and healthy lifestyle advice", keywords: ["wellness", "healthy", "lifestyle", "tips"]),
    SeedTopicData(title: "Life Hacks", description: "Useful life hacks and productivity tips", keywords: ["life hacks", "productivity", "tips", "useful"]),
    SeedTopicData(title: "Personal Growth", description: "Personal development and growth discussions", keywords: ["personal growth", "development", "self improvement"])
]

private let educationTopics: [SeedTopicData] = [
    SeedTopicData(title: "Study Tips", description: "Effective study techniques and academic advice", keywords: ["study", "tips", "academic", "learning"]),
    SeedTopicData(title: "Online Learning", description: "Online courses, MOOCs, and digital education", keywords: ["online", "courses", "moocs", "digital", "education"]),
    SeedTopicData(title: "Career Advice", description: "Career guidance and professional development", keywords: ["career", "advice", "professional", "development"])
]

private let scienceTopics: [SeedTopicData] = [
    SeedTopicData(title: "Scientific Breakthroughs", description: "Latest scientific discoveries and breakthroughs", keywords: ["science", "breakthroughs", "discoveries", "research"]),
    SeedTopicData(title: "Tech Innovations", description: "Cutting-edge technology and innovation discussions", keywords: ["tech", "innovations", "technology", "cutting edge"]),
    SeedTopicData(title: "Space Exploration", description: "Space missions, astronomy, and cosmic discoveries", keywords: ["space", "astronomy", "missions", "cosmic"])
]

private let worldNewsTopics: [SeedTopicData] = [
    SeedTopicData(title: "Global Events", description: "Major global events and their worldwide impact", keywords: ["global", "events", "worldwide", "impact"]),
    SeedTopicData(title: "International Relations", description: "International politics and diplomatic relations", keywords: ["international", "politics", "diplomacy", "relations"]),
    SeedTopicData(title: "Cultural Exchange", description: "Cultural exchanges and international understanding", keywords: ["cultural", "exchange", "international", "understanding"])
]

private let healthTopics: [SeedTopicData] = [
    SeedTopicData(title: "Fitness Routines", description: "Share workout routines and fitness tips", keywords: ["fitness", "workout", "routines", "exercise"]),
    SeedTopicData(title: "Mental Health Support", description: "Mental health awareness and support discussions", keywords: ["mental health", "support", "awareness", "wellness"]),
    SeedTopicData(title: "Nutrition Advice", description: "Nutrition tips and healthy eating discussions", keywords: ["nutrition", "healthy eating", "diet", "food"])
]

private let automotiveTopics: [SeedTopicData] = [
    SeedTopicData(title: "Car Reviews", description: "Latest car reviews and automotive comparisons", keywords: ["cars", "reviews", "automotive", "vehicles"]),
    SeedTopicData(title: "Electric Vehicles", description: "EV news, reviews, and the future of electric transportation", keywords: ["electric", "ev", "tesla", "vehicles", "green"]),
    SeedTopicData(title: "Auto Shows & Reveals", description: "Auto show coverage and new vehicle reveals", keywords: ["auto shows", "reveals", "new cars", "exhibitions"])
]
