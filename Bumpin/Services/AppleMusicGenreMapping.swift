import Foundation

/// Comprehensive mapping from Apple Music genres to standardized app genres
struct AppleMusicGenreMapping {
    
    /// Build mapping at runtime to avoid duplicate-key crashes. Later groups override earlier ones.
    static let genreMapping: [String: String] = {
        var map: [String: String] = [:]
        func add(_ keys: [String], to category: String) {
            for key in keys { map[key.lowercased()] = category }
        }
        
        // Hip-Hop & Rap
        add([
            "hip hop","hip-hop","rap","trap","drill","grime","gangsta rap","conscious rap",
            "boom bap","alternative hip-hop","alternative hip hop","emo rap","cloud rap","pop rap",
            "southern hip-hop","southern hip hop","west coast hip-hop","west coast hip hop",
            "east coast hip-hop","east coast hip hop","underground hip-hop","underground hip hop",
            "hardcore hip-hop","hardcore hip hop","old school hip-hop","old school hip hop",
            "new school hip-hop","new school hip hop","experimental hip-hop","experimental hip hop",
            "jazz rap","conscious hip-hop","conscious hip hop","political rap","gangsta","crunk",
            "snap","hyphy","bounce","chopped and screwed","chopped & screwed","screwed","chopped"
        ], to: "Hip-Hop")
        
        // Pop
        add([
            "pop","pop rock","power pop","indie pop","synthpop","synth-pop","electropop",
            "electro-pop","dance pop","teen pop","bubblegum pop","art pop","baroque pop",
            "chamber pop","dream pop","jangle pop","twee pop","yacht rock","soft rock",
            "adult contemporary","contemporary pop","mainstream pop","commercial pop","radio pop"
        ], to: "Pop")
        
        // R&B
        add([
            "r&b","rnb","rhythm and blues","rhythm & blues","contemporary r&b","contemporary rnb",
            "neo-soul","neosoul","soul","quiet storm","new jack swing","new jack",
            "urban contemporary","urban","alternative r&b","alternative rnb","indie r&b","indie rnb",
            "pbr&b","pbrnb","progressive r&b","progressive rnb","experimental r&b","experimental rnb",
            "trap soul","trap-soul"
        ], to: "R&B")
        
        // Electronic
        add([
            "electronic","edm","dance","electronic dance music","house","deep house","progressive house",
            "tech house","future house","bass house","tropical house","melodic house","afro house",
            "techno","minimal techno","deep techno","trance","progressive trance","uplifting trance",
            "psytrance","goa trance","dubstep","brostep","future bass","drum and bass","drum & bass",
            "dnb","jungle","breakbeat","ambient","ambient house","chillout","downtempo",
            "trip hop","trip-hop","idm","intelligent dance music","glitch","experimental electronic",
            "industrial","synthwave","retrowave","outrun","vaporwave","future funk","lo-fi","lofi",
            "chill","lounge"
        ], to: "Electronic")
        
        // Rock
        add([
            "rock","alternative rock","indie rock","post-rock","postrock","progressive rock",
            "prog rock","classic rock","hard rock","heavy metal","metal","death metal",
            "black metal","thrash metal","power metal","progressive metal","prog metal",
            "symphonic metal","folk metal","viking metal","doom metal","stoner metal","sludge metal",
            "post-metal","postmetal","metalcore","deathcore","nu metal","rap metal","funk metal",
            "grunge","punk","punk rock","hardcore punk","post-punk","postpunk","new wave",
            "gothic rock","noise rock","math rock","emo","screamo","post-hardcore","posthardcore",
            "garage rock","surf rock","psychedelic rock","psychedelic","acid rock","space rock",
            "krautrock","kraut rock","art rock","experimental rock","avant-garde","avant garde"
        ], to: "Rock")
        
        // Indie
        add([
            "indie","indie folk","indie electronic","indie hip-hop","indie hip hop","bedroom pop",
            "lo-fi indie","lofi indie","chillwave","seapunk","witch house","darkwave","coldwave",
            "minimal wave","post-punk revival","postpunk revival","garage punk","riot grrrl","twee",
            "c86","slowcore","sadcore","midwest emo","emo revival","shoegaze","noise pop"
        ], to: "Indie")
        
        // Country
        add([
            "country","country pop","country rock","alt-country","alt country","alternative country",
            "country folk","americana","bluegrass","honky tonk","outlaw country","progressive country",
            "country blues","western","cowboy","red dirt","texas country","bakersfield sound",
            "nashville sound","countrypolitan"
        ], to: "Country")
        
        // K-Pop
        add([
            "k-pop","kpop","korean pop","korean r&b","korean rnb","korean hip-hop","korean hip hop",
            "korean rock","korean indie","korean electronic","korean folk","korean ballad","korean trot",
            "korean traditional"
        ], to: "K-Pop")
        
        // Latin
        add([
            "latin","latin pop","latin rock","latin hip-hop","latin hip hop","latin r&b","latin rnb",
            "reggaeton","reggaetón","salsa","merengue","bachata","cumbia","ranchera","mariachi",
            "bolero","tango","flamenco","bossa nova","samba","bossa","latin alternative","latin indie",
            "latin electronic","spanish","portuguese","brazilian","mexican","argentine","colombian",
            "cuban","puerto rican","dominican"
        ], to: "Latin")
        
        // Jazz
        add([
            "jazz","bebop","hard bop","cool jazz","west coast jazz","east coast jazz","free jazz",
            "avant-garde jazz","avant garde jazz","fusion","jazz fusion","smooth jazz","contemporary jazz",
            "modern jazz","post-bop","postbop","acid jazz","nu jazz","jazz hip-hop","jazz hip hop",
            "jazz funk","jazz rock","jazz pop","vocal jazz","big band","swing","dixieland","ragtime",
            "gospel","spiritual","soul jazz"
        ], to: "Jazz")
        
        // Classical
        add([
            "classical","baroque","renaissance","medieval","romantic","impressionist",
            "modern classical","contemporary classical","minimalist","post-minimalist","postminimalist",
            "neoclassical","neo-classical","chamber music","orchestral","symphony","concerto","sonata",
            "etude","nocturne","prelude","fugue","cantata","oratorio","opera","ballet","film score",
            "soundtrack","new age","meditation","world","ethnic","traditional"
        ], to: "Classical")
        
        // Reggae
        add([
            "reggae","roots reggae","dancehall","ragga","raggamuffin","lovers rock","rocksteady","ska",
            "2-tone","2 tone","two-tone","two tone","dub"
        ], to: "Reggae")
        
        // Funk
        add([
            "funk","p-funk","pfunk","parliament-funkadelic","parliament funkadelic","jazz funk","jazz-funk",
            "soul funk","soul-funk","psychedelic funk","psychedelic-funk","acid funk","acid-funk",
            "funk rock","funk-rock","funk metal","funk-metal","funk pop","funk-pop","funk rap","funk-rap",
            "g-funk","gfunk","gangsta funk","gangsta-funk","west coast funk","east coast funk","southern funk",
            "new orleans funk","new orleans","nola funk","nola"
        ], to: "Funk")
        
        // Blues
        add([
            "blues","delta blues","chicago blues","electric blues","acoustic blues","country blues","folk blues",
            "blues rock","blues-rock","soul blues","soul-blues","jazz blues","jazz-blues","piano blues",
            "harmonica blues","slide guitar","bottleneck","boogie woogie","boogie-woogie","jump blues",
            "west coast blues","east coast blues","southern blues","memphis blues","st. louis blues","texas blues",
            "louisiana blues","swamp blues","zydeco","cajun","creole","gospel blues","spiritual blues",
            "work song","field holler"
        ], to: "Blues")
        
        // Alternative
        add([
            "alternative","alt","alt rock","alt pop","alt hip-hop","alt hip hop","alt r&b","alt rnb",
            "alt electronic","alt country","alt-country","alt folk","alt metal","alt dance","alt punk",
            "alt indie","underground","bedroom pop","seapunk","witch house","darkwave","coldwave",
            "minimal wave","post-punk revival","postpunk revival","garage punk","riot grrrl","twee","c86",
            "slowcore","sadcore","midwest emo","emo revival","math rock","post-rock","postrock","noise rock",
            "noise","industrial rock","industrial metal","gothic","gothic rock","gothic metal","dark ambient",
            "post-punk","postpunk","future pop","dark pop","lo-fi pop","lofi pop","chill pop","sad pop",
            "emo pop","pop punk","pop-punk","bubblegum pop","teen pop","adult contemporary","contemporary pop",
            "mainstream pop","commercial pop","radio pop"
        ], to: "Alternative")
        
        return map
    }()
    
    /// Maps an Apple Music genre to our standardized genre
    static func mapGenre(_ appleMusicGenre: String) -> String? {
        let raw = appleMusicGenre.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        
        // Ignore overly-generic labels
        let ignore: Set<String> = ["music", "misc", "miscellaneous", "various", "unknown"]
        if ignore.contains(raw) { return nil }
        
        // Split combined labels like "hip-hop/rap" or "r&b/soul"
        let separators = CharacterSet(charactersIn: "/,&|")
        var candidates = raw.components(separatedBy: separators).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if candidates.isEmpty { candidates = [raw] }
        // Include the original full string as last resort
        if !candidates.contains(raw) { candidates.append(raw) }
        
        // 1) Exact matches
        for g in candidates {
            if let mapped = genreMapping[g] { return mapped }
        }
        
        // 2) Contains-based matches (candidate must contain key, not the reverse)
        for g in candidates {
            for (apple, std) in genreMapping {
                if g.contains(apple) { return std }
            }
        }
        
        return nil
    }
    
    /// Get the most common genre from a list of mapped genres
    static func getMostCommonGenre(from genres: [String]) -> String {
        let counts = Dictionary(grouping: genres, by: { $0 }).mapValues { $0.count }
        if counts.isEmpty { return "Other" }
        // Deterministic priority order to break ties
        let priority = [
            "Hip-Hop","Pop","R&B","Electronic","Rock","Indie",
            "Latin","Country","K-Pop","Jazz","Classical","Reggae",
            "Funk","Blues","Alternative","Other"
        ]
        // Find max count
        let maxCount = counts.values.max() ?? 1
        // Among those with maxCount, pick the first by priority
        for p in priority {
            if counts[p] == maxCount { return p }
        }
        // Fallback to any
        return genres.first ?? "Other"
    }
}
