import Foundation
import FirebaseFirestore
import FirebaseAuth

class SearchSuggestionsManager: ObservableObject {
    @Published var searchHistory: [String] = []
    @Published var suggestions: [String] = []
    @Published var isLoadingSuggestions = false
    
    private let maxHistoryItems = 10
    private let maxSuggestions = 8
    
    init() {
        loadSearchHistory()
    }
    
    // MARK: - Search History
    
    func addToHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // Remove if already exists
        searchHistory.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        
        // Add to beginning
        searchHistory.insert(trimmedQuery, at: 0)
        
        // Keep only max items
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        saveSearchHistory()
    }
    
    func clearHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    private func loadSearchHistory() {
        guard let user = Auth.auth().currentUser else { return }
        
        Firestore.firestore().collection("users").document(user.uid)
            .getDocument { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data(),
                      let history = data["searchHistory"] as? [String] else { return }
                
                DispatchQueue.main.async {
                    self.searchHistory = history
                }
            }
    }
    
    private func saveSearchHistory() {
        guard let user = Auth.auth().currentUser else { return }
        
        Firestore.firestore().collection("users").document(user.uid)
            .updateData([
                "searchHistory": searchHistory
            ]) { error in
                if let error = error {
                    print("Error saving search history: \(error)")
                }
            }
    }
    
    // MARK: - Search Suggestions
    
    func generateSuggestions(for query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            suggestions = []
            return
        }
        
        isLoadingSuggestions = true
        
        // Combine history matches and common suggestions
        var allSuggestions: [String] = []
        
        // Add history matches
        let historyMatches = searchHistory.filter { 
            $0.lowercased().contains(trimmedQuery.lowercased()) 
        }
        allSuggestions.append(contentsOf: historyMatches)
        
        // Add common music suggestions
        let commonSuggestions = generateCommonSuggestions(for: trimmedQuery)
        allSuggestions.append(contentsOf: commonSuggestions)
        
        // Remove duplicates and limit
        let uniqueSuggestions = Array(Set(allSuggestions))
        suggestions = Array(uniqueSuggestions.prefix(maxSuggestions))
        
        isLoadingSuggestions = false
    }
    
    private func generateCommonSuggestions(for query: String) -> [String] {
        let lowerQuery = query.lowercased()
        var suggestions: [String] = []
        
        // Popular artists
        let popularArtists = [
            "Taylor Swift", "Drake", "The Weeknd", "Bad Bunny", "Ed Sheeran",
            "Ariana Grande", "Post Malone", "Billie Eilish", "Dua Lipa", "Justin Bieber"
        ]
        
        for artist in popularArtists {
            if artist.lowercased().contains(lowerQuery) {
                suggestions.append(artist)
            }
        }
        
        // Popular songs
        let popularSongs = [
            "Blinding Lights", "Shape of You", "Dance Monkey", "Uptown Funk",
            "Despacito", "See You Again", "Sugar", "Shake It Off", "Hello", "All of Me"
        ]
        
        for song in popularSongs {
            if song.lowercased().contains(lowerQuery) {
                suggestions.append(song)
            }
        }
        
        // Popular albums
        let popularAlbums = [
            "Midnights", "Folklore", "Evermore", "Lover", "1989",
            "Views", "Scorpion", "After Hours", "Starboy", "Beauty Behind the Madness"
        ]
        
        for album in popularAlbums {
            if album.lowercased().contains(lowerQuery) {
                suggestions.append(album)
            }
        }
        
        return suggestions
    }
    
    func clearSuggestions() {
        suggestions = []
    }
} 