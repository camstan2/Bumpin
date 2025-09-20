import Foundation
import SwiftUI

class SmartSearchManager: ObservableObject {
    // MARK: - Dependencies
    // private let musicSearchManager = MusicSearchManager()
    // private let appleMusicManager = AppleMusicManager()
    // private let libraryManager = AppleMusicLibraryManager()
    private let recentItemsStore = RecentItemsStore()
    // MARK: - Published Properties
    @Published var suggestions: [SearchSuggestion] = []
    @Published var recentSearches: [String] = []
    @Published var isLoading = false
    
    // MARK: - Private Properties
    private var searchTask: Task<Void, Never>?
    private let maxRecentSearches = 10
    private let userDefaults = UserDefaults.standard
    private let recentSearchesKey = "recentSearches"
    
    // MARK: - Initialization
    init() {
        loadRecentSearches()
    }
    
    // MARK: - Public Methods
    func getSuggestions(for query: String) async {
        guard !query.isEmpty else {
            await MainActor.run { suggestions = [] }
            return
        }
        
        // Cancel any existing search
        searchTask?.cancel()
        
        // Create new search task
        searchTask = Task {
            await MainActor.run { isLoading = true }
            
            // Add artificial delay for smooth UI
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Generate fuzzy matches from recent searches
            let fuzzyMatches = recentSearches.filter { search in
                search.localizedCaseInsensitiveContains(query)
            }
            
            // Generate smart suggestions based on query
            var smartSuggestions: [SearchSuggestion] = []
            
            // Add exact match if different from query
            if !query.isEmpty && !fuzzyMatches.contains(query) {
                smartSuggestions.append(SearchSuggestion(
                    text: query,
                    type: .exact,
                    icon: "magnifyingglass"
                ))
            }
            
            // Add fuzzy matches
            fuzzyMatches.forEach { match in
                smartSuggestions.append(SearchSuggestion(
                    text: match,
                    type: .recent,
                    icon: "clock"
                ))
            }
            
            // Add common variations
            let variations = generateVariations(for: query)
            variations.forEach { variation in
                smartSuggestions.append(SearchSuggestion(
                    text: variation,
                    type: .suggestion,
                    icon: "sparkles"
                ))
            }
            
            // Update UI on main thread
            await MainActor.run {
                suggestions = smartSuggestions
                isLoading = false
            }
        }
    }
    
    func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Remove if exists and add to front
        recentSearches.removeAll { $0 == trimmed }
        recentSearches.insert(trimmed, at: 0)
        
        // Keep only maxRecentSearches
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        // Save to UserDefaults
        userDefaults.set(recentSearches, forKey: recentSearchesKey)
    }
    
    func clearRecentSearches() {
        recentSearches = []
        userDefaults.removeObject(forKey: recentSearchesKey)
    }
    
    // MARK: - Private Methods
    private func loadRecentSearches() {
        if let saved = userDefaults.stringArray(forKey: recentSearchesKey) {
            recentSearches = saved
        }
    }
    
    private func generateVariations(for query: String) -> [String] {
        var variations: Set<String> = []
        let words = query.split(separator: " ")
        
        // Handle single word
        if words.count == 1 {
            // Add common prefixes/suffixes
            variations.insert("\(query) remix")
            variations.insert("\(query) live")
            variations.insert("\(query) acoustic")
            variations.insert("\(query) cover")
        }
        // Handle multiple words
        else {
            // Rearrange words
            let permutations = words.permutations()
            permutations.forEach { perm in
                variations.insert(perm.joined(separator: " "))
            }
            
            // Add/remove "the" if not present/present
            if !query.lowercased().hasPrefix("the ") {
                variations.insert("the \(query)")
            } else {
                variations.insert(String(query.dropFirst(4)))
            }
        }
        
        return Array(variations.prefix(3))
    }
}

// MARK: - Search Suggestion Model
struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let icon: String
    
    enum SuggestionType {
        case exact
        case recent
        case suggestion
    }
}

// MARK: - Array Extension for Permutations
extension Array {
    func permutations() -> [[Element]] {
        if count <= 1 { return [self] }
        var perms: [[Element]] = []
        let lastItem = self[count-1]
        let subPerms = Array(self[0..<count-1]).permutations()
        
        for subPerm in subPerms {
            for i in 0...subPerm.count {
                var newPerm = subPerm
                newPerm.insert(lastItem, at: i)
                perms.append(newPerm)
            }
        }
        return perms
    }
}
