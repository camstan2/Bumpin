import Foundation

enum ArtistNameParser {
    /// Normalizes an artist name for consistent comparisons (case/diacritic insensitive, trimmed).
    static func normalizedKey(_ name: String) -> String {
        return name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale.current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    /// Splits a combined artist string (e.g., "Artist A, Artist B & Artist C") into unique, ordered names.
    static func splitArtists(from combinedName: String) -> [String] {
        guard !combinedName.isEmpty else { return [] }
        
        var normalized = combinedName
        
        // Replace common conjunctions with commas for easier splitting
        let phrasePattern = "(?i)\\s+(feat\\.?|featuring|ft\\.?|with|and|vs\\.|x|×)\\s+"
        normalized = normalized.replacingOccurrences(of: phrasePattern, with: ",", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "[&×/|;+]", with: ",", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: ",+", with: ",", options: .regularExpression)
        
        let rawNames = normalized
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var seen = Set<String>()
        var ordered: [String] = []
        
        for name in rawNames {
            let key = normalizedKey(name)
            if !seen.contains(key) {
                seen.insert(key)
                ordered.append(name)
            }
        }
        
        return ordered
    }
    
    /// Returns normalized tokens for use in Firestore queries.
    static func tokens(from combinedName: String) -> [String] {
        return splitArtists(from: combinedName).map { normalizedKey($0) }
    }
}

