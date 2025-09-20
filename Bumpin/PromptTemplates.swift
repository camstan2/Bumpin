import Foundation

// MARK: - Sample Prompt Templates

struct PromptTemplateLibrary {
    
    static let sampleTemplates: [PromptTemplate] = [
        
        // MARK: - Activity Prompts
        PromptTemplate(
            title: "First song you play on vacation",
            description: "That perfect song that kicks off your getaway mood",
            category: .activity,
            tags: ["vacation", "travel", "mood", "first"]
        ),
        
        PromptTemplate(
            title: "Your go-to workout anthem",
            description: "The song that never fails to pump you up during exercise",
            category: .activity,
            tags: ["workout", "exercise", "energy", "motivation"]
        ),
        
        PromptTemplate(
            title: "Perfect song for a road trip",
            description: "Windows down, volume up - what's playing?",
            category: .activity,
            tags: ["road trip", "driving", "adventure", "freedom"]
        ),
        
        PromptTemplate(
            title: "Song that helps you focus while studying",
            description: "Your secret weapon for concentration",
            category: .activity,
            tags: ["study", "focus", "concentration", "productivity"]
        ),
        
        PromptTemplate(
            title: "Best song for cooking dinner",
            description: "What's playing while you're in the kitchen?",
            category: .activity,
            tags: ["cooking", "kitchen", "dinner", "domestic"]
        ),
        
        // MARK: - Mood Prompts
        PromptTemplate(
            title: "Song that instantly cheers you up",
            description: "Your guaranteed mood booster",
            category: .mood,
            tags: ["happy", "uplifting", "mood booster", "positive"]
        ),
        
        PromptTemplate(
            title: "Perfect rainy day song",
            description: "What matches the sound of raindrops?",
            category: .mood,
            tags: ["rain", "cozy", "melancholy", "weather"]
        ),
        
        PromptTemplate(
            title: "Song for when you're feeling confident",
            description: "Your personal power anthem",
            category: .mood,
            tags: ["confidence", "power", "strong", "empowering"]
        ),
        
        PromptTemplate(
            title: "Late night contemplation song",
            description: "For those deep 2 AM thoughts",
            category: .mood,
            tags: ["late night", "contemplative", "deep", "introspective"]
        ),
        
        // MARK: - Nostalgia Prompts
        PromptTemplate(
            title: "Song that takes you back to high school",
            description: "Instant time machine to your teenage years",
            category: .nostalgia,
            tags: ["high school", "teenage", "memories", "throwback"]
        ),
        
        PromptTemplate(
            title: "First song you remember loving",
            description: "Your earliest musical memory",
            category: .nostalgia,
            tags: ["childhood", "first love", "early memory", "discovery"]
        ),
        
        PromptTemplate(
            title: "Song that reminds you of summer 2019",
            description: "The soundtrack to that specific summer",
            category: .nostalgia,
            tags: ["summer", "2019", "specific time", "memories"]
        ),
        
        PromptTemplate(
            title: "Song your parents played constantly",
            description: "The tune that defined your childhood home",
            category: .nostalgia,
            tags: ["parents", "childhood", "family", "home"]
        ),
        
        // MARK: - Social Prompts
        PromptTemplate(
            title: "Best song to sing with friends",
            description: "The ultimate group singalong anthem",
            category: .social,
            tags: ["friends", "singalong", "group", "fun"]
        ),
        
        PromptTemplate(
            title: "Song that would get everyone dancing at a party",
            description: "Guaranteed to fill the dance floor",
            category: .social,
            tags: ["party", "dancing", "crowd pleaser", "energy"]
        ),
        
        PromptTemplate(
            title: "Perfect song for a first date",
            description: "Sets the right mood without being too intense",
            category: .social,
            tags: ["first date", "romantic", "conversation", "atmosphere"]
        ),
        
        PromptTemplate(
            title: "Song that represents your friendship group",
            description: "If your friend group had a theme song",
            category: .social,
            tags: ["friendship", "group identity", "theme song", "bonds"]
        ),
        
        // MARK: - Emotion Prompts
        PromptTemplate(
            title: "Song that makes you feel invincible",
            description: "Like you could conquer the world",
            category: .emotion,
            tags: ["invincible", "powerful", "unstoppable", "strength"]
        ),
        
        PromptTemplate(
            title: "Song for when you need a good cry",
            description: "Sometimes you need to let it all out",
            category: .emotion,
            tags: ["crying", "emotional release", "cathartic", "sadness"]
        ),
        
        PromptTemplate(
            title: "Most romantic song you know",
            description: "Pure love in musical form",
            category: .emotion,
            tags: ["romantic", "love", "intimate", "relationship"]
        ),
        
        PromptTemplate(
            title: "Song that gives you chills every time",
            description: "That spine-tingling moment",
            category: .emotion,
            tags: ["chills", "goosebumps", "powerful", "emotional"]
        ),
        
        // MARK: - Discovery Prompts
        PromptTemplate(
            title: "Hidden gem that deserves more recognition",
            description: "Your secret musical treasure",
            category: .discovery,
            tags: ["hidden gem", "underrated", "discovery", "secret"]
        ),
        
        PromptTemplate(
            title: "Song you discovered through a movie/TV show",
            description: "When the soundtrack introduced you to something amazing",
            category: .discovery,
            tags: ["movie", "TV show", "soundtrack", "discovery"]
        ),
        
        PromptTemplate(
            title: "Best song from an artist you just discovered",
            description: "Your entry point to a new favorite",
            category: .discovery,
            tags: ["new artist", "discovery", "entry point", "exploration"]
        ),
        
        PromptTemplate(
            title: "Song that changed your music taste",
            description: "The track that opened new doors",
            category: .discovery,
            tags: ["game changer", "taste", "evolution", "breakthrough"]
        ),
        
        // MARK: - Genre Prompts
        PromptTemplate(
            title: "Best hip-hop track of all time",
            description: "The pinnacle of the genre",
            category: .genre,
            tags: ["hip-hop", "best of", "classic", "definitive"]
        ),
        
        PromptTemplate(
            title: "Perfect indie rock song",
            description: "Captures the essence of indie rock",
            category: .genre,
            tags: ["indie rock", "perfect", "essence", "definitive"]
        ),
        
        PromptTemplate(
            title: "Electronic song that goes hardest",
            description: "Maximum energy electronic music",
            category: .genre,
            tags: ["electronic", "hard", "energy", "intense"]
        ),
        
        PromptTemplate(
            title: "Country song that even non-country fans love",
            description: "The crossover appeal champion",
            category: .genre,
            tags: ["country", "crossover", "universal appeal", "gateway"]
        ),
        
        // MARK: - Season Prompts
        PromptTemplate(
            title: "Ultimate summer anthem",
            description: "Captures the feeling of endless summer days",
            category: .season,
            tags: ["summer", "anthem", "sunshine", "carefree"]
        ),
        
        PromptTemplate(
            title: "Perfect autumn song",
            description: "Matches the changing leaves and crisp air",
            category: .season,
            tags: ["autumn", "fall", "cozy", "changing seasons"]
        ),
        
        PromptTemplate(
            title: "Winter song that warms your soul",
            description: "Musical comfort for cold days",
            category: .season,
            tags: ["winter", "warm", "comfort", "cozy"]
        ),
        
        PromptTemplate(
            title: "Spring song full of hope",
            description: "New beginnings and fresh starts",
            category: .season,
            tags: ["spring", "hope", "new beginnings", "renewal"]
        ),
        
        // MARK: - Special/Event Prompts
        PromptTemplate(
            title: "New Year's Eve countdown song",
            description: "What should be playing at midnight?",
            category: .special,
            tags: ["new year", "countdown", "celebration", "midnight"]
        ),
        
        PromptTemplate(
            title: "Perfect wedding first dance song",
            description: "The most romantic moment needs the perfect soundtrack",
            category: .special,
            tags: ["wedding", "first dance", "romantic", "special moment"]
        ),
        
        PromptTemplate(
            title: "Graduation ceremony song",
            description: "Celebrating achievements and new chapters",
            category: .special,
            tags: ["graduation", "achievement", "new chapter", "ceremony"]
        ),
        
        PromptTemplate(
            title: "Birthday party anthem",
            description: "Makes everyone feel like celebrating",
            category: .special,
            tags: ["birthday", "celebration", "party", "joy"]
        ),
        
        // MARK: - Random/Fun Prompts
        PromptTemplate(
            title: "Song that sounds like the color blue",
            description: "If blue had a soundtrack, what would it be?",
            category: .random,
            tags: ["synesthesia", "color", "blue", "abstract"]
        ),
        
        PromptTemplate(
            title: "Best song with a number in the title",
            description: "Mathematics meets music",
            category: .random,
            tags: ["numbers", "title", "specific", "quirky"]
        ),
        
        PromptTemplate(
            title: "Song that should be in every movie trailer",
            description: "Epic enough for the big screen",
            category: .random,
            tags: ["movie trailer", "epic", "cinematic", "dramatic"]
        ),
        
        PromptTemplate(
            title: "Most overrated song everyone loves",
            description: "Controversial opinion time",
            category: .random,
            tags: ["overrated", "controversial", "popular", "opinion"]
        ),
        
        PromptTemplate(
            title: "Song that would play during your superhero entrance",
            description: "Your personal theme music",
            category: .random,
            tags: ["superhero", "entrance", "theme", "epic"]
        )
    ]
    
    // MARK: - Helper Functions
    
    static func templatesForCategory(_ category: PromptCategory) -> [PromptTemplate] {
        return sampleTemplates.filter { $0.category == category }
    }
    
    static func randomTemplate() -> PromptTemplate? {
        return sampleTemplates.randomElement()
    }
    
    static func templatesWithTag(_ tag: String) -> [PromptTemplate] {
        return sampleTemplates.filter { $0.tags.contains(tag) }
    }
    
    static func searchTemplates(_ searchTerm: String) -> [PromptTemplate] {
        let lowercaseSearch = searchTerm.lowercased()
        return sampleTemplates.filter { template in
            template.title.lowercased().contains(lowercaseSearch) ||
            template.description?.lowercased().contains(lowercaseSearch) == true ||
            template.tags.contains { $0.lowercased().contains(lowercaseSearch) }
        }
    }
}

// MARK: - Prompt Generation Helpers

struct PromptGenerator {
    
    // Generate prompts based on current events, seasons, etc.
    static func generateSeasonalPrompt() -> PromptTemplate? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        
        switch month {
        case 12, 1, 2: // Winter
            return PromptTemplateLibrary.templatesForCategory(.season).first { $0.tags.contains("winter") }
        case 3, 4, 5: // Spring
            return PromptTemplateLibrary.templatesForCategory(.season).first { $0.tags.contains("spring") }
        case 6, 7, 8: // Summer
            return PromptTemplateLibrary.templatesForCategory(.season).first { $0.tags.contains("summer") }
        case 9, 10, 11: // Fall
            return PromptTemplateLibrary.templatesForCategory(.season).first { $0.tags.contains("autumn") }
        default:
            return nil
        }
    }
    
    // Generate prompts based on day of week
    static func generateWeekdayPrompt() -> PromptTemplate? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        switch weekday {
        case 1: // Sunday
            return PromptTemplate(
                title: "Perfect Sunday morning song",
                description: "Lazy weekend vibes",
                category: .mood,
                tags: ["sunday", "morning", "lazy", "weekend"]
            )
        case 2: // Monday
            return PromptTemplate(
                title: "Monday motivation song",
                description: "Get the week started right",
                category: .mood,
                tags: ["monday", "motivation", "week start", "energy"]
            )
        case 6: // Friday
            return PromptTemplate(
                title: "Friday celebration song",
                description: "Weekend is here!",
                category: .mood,
                tags: ["friday", "celebration", "weekend", "relief"]
            )
        default:
            return PromptTemplateLibrary.randomTemplate()
        }
    }
    
    // Generate prompts based on holidays
    static func generateHolidayPrompt() -> PromptTemplate? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let day = calendar.component(.day, from: Date())
        
        // Valentine's Day
        if month == 2 && day == 14 {
            return PromptTemplate(
                title: "Most romantic Valentine's Day song",
                description: "Love is in the air",
                category: .special,
                tags: ["valentine", "romantic", "love", "holiday"]
            )
        }
        
        // Halloween
        if month == 10 && day == 31 {
            return PromptTemplate(
                title: "Spookiest Halloween song",
                description: "Perfect for trick-or-treating",
                category: .special,
                tags: ["halloween", "spooky", "scary", "october"]
            )
        }
        
        // Christmas season
        if month == 12 && day >= 20 {
            return PromptTemplate(
                title: "Best Christmas song that isn't 'All I Want for Christmas Is You'",
                description: "Holiday spirit without the obvious choice",
                category: .special,
                tags: ["christmas", "holiday", "winter", "festive"]
            )
        }
        
        return nil
    }
}
