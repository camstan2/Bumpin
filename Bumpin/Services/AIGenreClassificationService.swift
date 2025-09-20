import Foundation
import SwiftUI
import MusicKit

// MARK: - AI Genre Classification Service

@MainActor
class AIGenreClassificationService: ObservableObject {
    
    // MARK: - Standardized Genre List
    
    static let standardizedGenres = [
        "Hip-Hop", "Pop", "R&B", "Electronic", "Rock", "Indie", 
        "Country", "K-Pop", "Latin", "Jazz", "Classical", "Reggae", 
        "Funk", "Blues", "Alternative", "Other"
    ]
    
    // MARK: - Classification Result
    
    struct ClassificationResult {
        let primaryGenre: String
        let confidence: Double // 0.0 - 1.0
        let reasoning: String?
        let appleMusicGenres: [String]
        let classificationMethod: String
        let timestamp: Date
        
        init(primaryGenre: String, confidence: Double, reasoning: String? = nil, appleMusicGenres: [String], classificationMethod: String = "ai_gpt4") {
            self.primaryGenre = primaryGenre
            self.confidence = confidence
            self.reasoning = reasoning
            self.appleMusicGenres = appleMusicGenres
            self.classificationMethod = classificationMethod
            self.timestamp = Date()
        }
    }
    
    // MARK: - Singleton
    
    static let shared = AIGenreClassificationService()
    
    private init() {}
    
    // MARK: - Classification Methods
    
    /// Classify a song using Apple Music genres with comprehensive mapping
    func classifySong(
        title: String,
        artist: String,
        appleMusicGenres: [String]
    ) async -> ClassificationResult {
        
        // If no Apple Music genres available, use fallback path that still tries MusicKit fetch
        if appleMusicGenres.isEmpty {
            return fallbackClassification(title: title, artist: artist)
        }
        
        // Try to map each Apple Music genre to our standardized genres
        let mappedGenres = appleMusicGenres
            .compactMap { AppleMusicGenreMapping.mapGenre($0) }
            .filter { $0 != "Other" }
        
        // If we successfully mapped at least one genre, use the most common one
        if !mappedGenres.isEmpty {
            let primaryGenre = AppleMusicGenreMapping.getMostCommonGenre(from: mappedGenres)
            return ClassificationResult(
                primaryGenre: primaryGenre,
                confidence: 0.95, // High confidence since we're using Apple Music's own data
                reasoning: "Apple Music genre mapping to standardized categories",
                appleMusicGenres: appleMusicGenres,
                classificationMethod: "apple_music_mapping"
            )
        }
        
        // Fallback to artist-based classification if no genres could be mapped
        return fallbackClassification(title: title, artist: artist)
    }
    
    // MARK: - AI Classification (GPT-4o)
    
    private func aiClassification(
        title: String,
        artist: String,
        appleMusicGenres: [String]
    ) async -> ClassificationResult {
        
        let prompt = buildClassificationPrompt(title: title, artist: artist, appleMusicGenres: appleMusicGenres)
        
        do {
            // Call OpenAI API (you'll need to add your API key)
            let result = try await callOpenAIAPI(prompt: prompt)
            return parseAIResponse(result, appleMusicGenres: appleMusicGenres)
        } catch {
            print("❌ AI Classification failed for '\(title)' by \(artist): \(error)")
            // Fallback to rule-based classification
            return ruleBasedClassification(title: title, artist: artist, appleMusicGenres: appleMusicGenres)
        }
    }
    
    private func buildClassificationPrompt(title: String, artist: String, appleMusicGenres: [String]) -> String {
        let genreList = Self.standardizedGenres.joined(separator: ", ")
        
        return """
        You are a music genre classification expert. Your task is to classify songs into a single primary genre.
        
        Song: "\(title)" by \(artist)
        Apple Music Genres: \(appleMusicGenres.joined(separator: ", "))
        
        Available Genres: \(genreList)
        
        Rules:
        1. Choose exactly ONE primary genre from the available list
        2. Consider the song's dominant musical elements
        3. Think about how fans and the music industry would categorize it
        4. If the song blends genres, pick the most prominent one
        5. Use "Other" only if none of the genres fit well
        
        Respond in this exact JSON format:
        {
            "genre": "chosen_genre",
            "confidence": 0.85,
            "reasoning": "brief explanation"
        }
        """
    }
    
    private func callOpenAIAPI(prompt: String) async throws -> String {
        // Check if we have an API key configured
        guard let apiKey = getOpenAIAPIKey(), !apiKey.isEmpty else {
            print("⚠️ OpenAI API key not configured, using enhanced rule-based classification")
            throw NSError(domain: "OpenAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini", // Using mini for cost efficiency
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 150,
            "temperature": 0.3 // Lower temperature for more consistent results
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        guard let content = content else {
            throw NSError(domain: "OpenAI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid API response"])
        }
        
        return content
    }
    
    private func getOpenAIAPIKey() -> String? {
        // Try to get API key from environment or configuration
        // You can set this in your app's configuration or environment variables
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }
    
    private func parseAIResponse(_ response: String, appleMusicGenres: [String]) -> ClassificationResult {
        do {
            let data = response.data(using: .utf8) ?? Data()
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            let genre = json?["genre"] as? String ?? "Other"
            let confidence = json?["confidence"] as? Double ?? 0.5
            let reasoning = json?["reasoning"] as? String
            
            // Validate genre is in our list
            let validGenre = Self.standardizedGenres.contains(genre) ? genre : "Other"
            
            return ClassificationResult(
                primaryGenre: validGenre,
                confidence: min(max(confidence, 0.0), 1.0), // Clamp to 0-1
                reasoning: reasoning,
                appleMusicGenres: appleMusicGenres,
                classificationMethod: "ai_gpt4"
            )
        } catch {
            print("❌ Failed to parse AI response: \(error)")
            return ruleBasedClassification(title: "", artist: "", appleMusicGenres: appleMusicGenres)
        }
    }
    
    // MARK: - Fallback Classifications
    
    private func fallbackClassification(title: String, artist: String) -> ClassificationResult {
        let genre = classifyByArtistFallback(artist: artist)
        return ClassificationResult(
            primaryGenre: genre,
            confidence: 0.3,
            reasoning: "Fallback classification based on artist name",
            appleMusicGenres: [],
            classificationMethod: "fallback_artist"
        )
    }
    
    private func ruleBasedClassification(title: String, artist: String, appleMusicGenres: [String]) -> ClassificationResult {
        // Try to map Apple Music genres to our standardized list
        for appleGenre in appleMusicGenres {
            if let mapped = mapAppleMusicGenreDirectly(appleGenre) {
                return ClassificationResult(
                    primaryGenre: mapped,
                    confidence: 0.7,
                    reasoning: "Rule-based mapping from Apple Music genre",
                    appleMusicGenres: appleMusicGenres,
                    classificationMethod: "rule_based"
                )
            }
        }
        
        // Final fallback
        return fallbackClassification(title: title, artist: artist)
    }
    
    // MARK: - Direct Apple Music Genre Mapping
    
    private func mapAppleMusicGenreDirectly(_ appleMusicGenre: String) -> String? {
        let genre = appleMusicGenre.lowercased()
        
        switch genre {
        case let g where g.contains("hip hop") || g.contains("hip-hop") || g.contains("rap") || 
                        g.contains("trap") || g.contains("drill") || g.contains("grime") ||
                        g.contains("gangsta") || g.contains("conscious rap") || g.contains("boom bap"):
            return "Hip-Hop"
        case let g where g.contains("pop") && !g.contains("k-pop") && !g.contains("synthpop"):
            return "Pop"
        case let g where g.contains("r&b") || g.contains("rnb") || g.contains("soul") ||
                        g.contains("rhythm and blues") || g.contains("neo soul") || g.contains("urban"):
            return "R&B"
        case let g where g.contains("electronic") || g.contains("dance") || g.contains("edm") ||
                        g.contains("techno") || g.contains("house") || g.contains("trance") ||
                        g.contains("dubstep") || g.contains("ambient") || g.contains("synthwave"):
            return "Electronic"
        case let g where g.contains("rock") || g.contains("metal") || g.contains("punk") ||
                        g.contains("grunge") || g.contains("hardcore") || g.contains("alternative rock"):
            return "Rock"
        case let g where g.contains("indie") || g.contains("independent") || g.contains("lo-fi") ||
                        g.contains("bedroom pop") || g.contains("dream pop") || g.contains("shoegaze"):
            return "Indie"
        case let g where g.contains("country") || g.contains("folk") || g.contains("bluegrass") ||
                        g.contains("americana") || g.contains("western") || g.contains("honky tonk"):
            return "Country"
        case let g where g.contains("k-pop") || g.contains("korean pop") || g.contains("k-pop"):
            return "K-Pop"
        case let g where g.contains("latin") || g.contains("reggaeton") || g.contains("spanish") ||
                        g.contains("mexican") || g.contains("salsa") || g.contains("bachata"):
            return "Latin"
        case let g where g.contains("jazz") || g.contains("bebop") || g.contains("swing"):
            return "Jazz"
        case let g where g.contains("classical") || g.contains("orchestral") || g.contains("symphony"):
            return "Classical"
        case let g where g.contains("reggae") || g.contains("dancehall"):
            return "Reggae"
        case let g where g.contains("funk") || g.contains("disco"):
            return "Funk"
        case let g where g.contains("blues") || g.contains("delta blues"):
            return "Blues"
        case let g where g.contains("alternative") && !g.contains("rock"):
            return "Alternative"
        default:
            return nil // Will trigger AI classification
        }
    }
    
    // MARK: - Artist-Based Fallback
    
    private func classifyByArtistFallback(artist: String) -> String {
        let artistLower = artist.lowercased()
        
        // Comprehensive hip-hop artist database
        let hipHopArtists = [
            "trippie redd", "travis scott", "kendrick lamar", "drake", "kanye west", "j cole",
            "lil uzi vert", "playboi carti", "lil baby", "dababy", "migos", "21 savage",
            "lil nas x", "tyler the creator", "asap rocky", "asap ferg", "lil wayne",
            "nicki minaj", "cardi b", "megan thee stallion", "doja cat", "lil tjay",
            "polo g", "lil durk", "roddy ricch", "jack harlow", "lil tecca", "lil mosey",
            "juice wrld", "xxxtentacion", "lil peep", "ski mask", "denzel curry",
            "jpegmafia", "vince staples", "earl sweatshirt", "frank ocean", "kendrick",
            "lil", "young", "big", "mc", "dj", "lil'", "young'", "big'"
        ]
        
        // Check for hip-hop artists
        for hipHopArtist in hipHopArtists {
            if artistLower.contains(hipHopArtist) {
                return "Hip-Hop"
            }
        }
        
        // Pop artists
        let popArtists = [
            "taylor swift", "billie eilish", "ariana grande", "selena gomez", "justin bieber",
            "harry styles", "olivia rodrigo", "dua lipa", "lady gaga", "katy perry",
            "rihanna", "beyonce", "adele", "ed sheeran", "bruno mars", "shawn mendes"
        ]
        
        for popArtist in popArtists {
            if artistLower.contains(popArtist) {
                return "Pop"
            }
        }
        
        // R&B artists
        let rnbArtists = [
            "the weeknd", "bruno mars", "frank ocean", "sza", "h.e.r.", "daniel caesar",
            "giveon", "lucky daye", "snoh aalegra", "jhene aiko", "kehlani", "summer walker"
        ]
        
        for rnbArtist in rnbArtists {
            if artistLower.contains(rnbArtist) {
                return "R&B"
            }
        }
        
        // Rock artists
        let rockArtists = [
            "arctic monkeys", "radiohead", "coldplay", "imagine dragons", "twenty one pilots",
            "fall out boy", "panic at the disco", "my chemical romance", "green day",
            "blink-182", "sum 41", "linkin park", "system of a down", "metallica"
        ]
        
        for rockArtist in rockArtists {
            if artistLower.contains(rockArtist) {
                return "Rock"
            }
        }
        
        // Electronic artists
        let electronicArtists = [
            "skrillex", "deadmau5", "calvin harris", "martin garrix", "david guetta",
            "tiësto", "avicii", "swedish house mafia", "above & beyond", "porter robinson"
        ]
        
        for electronicArtist in electronicArtists {
            if artistLower.contains(electronicArtist) {
                return "Electronic"
            }
        }
        
        // Pattern-based classification for unknown artists
        if artistLower.contains("lil ") || artistLower.contains("young ") || 
           artistLower.contains("big ") || artistLower.hasPrefix("mc ") ||
           artistLower.contains("$") || artistLower.contains("21 ") ||
           artistLower.contains("lil'") || artistLower.contains("young'") {
            return "Hip-Hop"
        }
        
        // Hash-based fallback for truly unknown artists (but with better distribution)
        let fallbackGenres = ["Hip-Hop", "Pop", "R&B", "Rock", "Electronic", "Indie"]
        let hash = abs(artistLower.hashValue)
        return fallbackGenres[hash % fallbackGenres.count]
    }
    
    // MARK: - Real-time Classification for Music Logging
    
    /// Classify a song when user is logging music (real-time)
    func classifyForMusicLog(searchResult: MusicSearchResult) async -> ClassificationResult {
        var genres = searchResult.genreNames ?? []
        // Treat ultra-generic labels as empty
        genres.removeAll { ["Music", "music", "Unknown"].contains($0) }
        
        if genres.isEmpty {
            // Robust fallback: fetch song, then album/artist genres from MusicKit
            let fetched = await fetchGenresFromMusicKit(songId: searchResult.id)
            if !fetched.isEmpty {
                genres = fetched
            }
        }
        
        return await classifySong(
            title: searchResult.title,
            artist: searchResult.artistName,
            appleMusicGenres: genres
        )
    }

    // MARK: - MusicKit fallback genre fetch
    private func fetchGenresFromMusicKit(songId: String) async -> [String] {
        var out: [String] = []
        do {
            // Fetch song
            let songReq = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(songId))
            let songResp = try await songReq.response()
            if let song = songResp.items.first {
                out.append(contentsOf: song.genreNames)
                // Album relationship may not be available in current SDK; skip safely
                // First artist genres
                if let artist = song.artists?.first {
                    let artistReq = MusicCatalogResourceRequest<MusicKit.Artist>(matching: \.id, equalTo: artist.id)
                    if let artistDetails = try? await artistReq.response().items.first {
                        out.append(contentsOf: artistDetails.genreNames ?? [])
                    }
                }
            }
            // If still empty, try a lightweight search with title + artist to gather genres
            if out.isEmpty {
                let term = songResp.items.first.map { "\($0.title) \($0.artistName)" } ?? songId
                var searchReq = MusicCatalogSearchRequest(term: term, types: [MusicKit.Song.self, MusicKit.Artist.self, MusicKit.Album.self])
                searchReq.limit = 3
                if let searchResp = try? await searchReq.response() {
                    if let s = searchResp.songs.first { out.append(contentsOf: s.genreNames) }
                    if let a = searchResp.artists.first { out.append(contentsOf: a.genreNames ?? []) }
                    if let al = searchResp.albums.first { out.append(contentsOf: al.genreNames) }
                }
            }
        } catch {
            print("⚠️ MusicKit fallback fetch failed for songId=\(songId): \(error)")
        }
        // Deduplicate while preserving order
        var seen: Set<String> = []
        let dedup = out.filter { v in
            let lower = v.lowercased()
            if seen.contains(lower) { return false }
            seen.insert(lower)
            return true
        }
        return dedup
    }
}

// MARK: - Classification Extensions

extension AIGenreClassificationService {
    
    /// Batch classify multiple songs efficiently
    func classifyMultipleSongs(_ songs: [(title: String, artist: String, appleMusicGenres: [String])]) async -> [ClassificationResult] {
        var results: [ClassificationResult] = []
        
        // Process in batches to avoid rate limits
        let batchSize = 10
        for batch in songs.chunked(into: batchSize) {
            let batchResults = await withTaskGroup(of: ClassificationResult.self) { group in
                var groupResults: [ClassificationResult] = []
                
                for song in batch {
                    group.addTask {
                        await self.classifySong(
                            title: song.title,
                            artist: song.artist,
                            appleMusicGenres: song.appleMusicGenres
                        )
                    }
                }
                
                for await result in group {
                    groupResults.append(result)
                }
                
                return groupResults
            }
            
            results.append(contentsOf: batchResults)
            
            // Small delay between batches to respect rate limits
            if songs.count > batchSize {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        return results
    }
}

// Note: chunked(into:) extension already exists in the codebase
