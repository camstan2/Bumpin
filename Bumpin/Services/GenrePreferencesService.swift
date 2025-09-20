import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Genre Preferences Service

@MainActor
class GenrePreferencesService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var favoriteGenres: Set<String> = []
    @Published var isLoading = false
    @Published var showGenreSettings = false
    
    // MARK: - Available Genres (from AI service)
    
    var allGenres: [String] {
        return AIGenreClassificationService.standardizedGenres
    }
    
    // Default genres for new users
    private let defaultGenres: Set<String> = ["Hip-Hop", "Pop", "R&B", "Electronic", "Rock"]
    
    // UserDefaults key
    private let favoritesKey = "user_favorite_genres"
    
    // MARK: - Singleton
    
    static let shared = GenrePreferencesService()
    
    private init() {
        loadFavoriteGenres()
    }
    
    // MARK: - Public Methods
    
    /// Toggle a genre in/out of favorites
    func toggleGenre(_ genre: String) {
        if favoriteGenres.contains(genre) {
            favoriteGenres.remove(genre)
        } else {
            favoriteGenres.insert(genre)
        }
        saveFavoriteGenres()
        
        print("🎵 Genre preferences updated: \(favoriteGenres.sorted())")
    }
    
    /// Check if a genre is favorited
    func isFavorite(_ genre: String) -> Bool {
        return favoriteGenres.contains(genre)
    }
    
    /// Get favorite genres as sorted array for display
    var favoriteGenresArray: [String] {
        return Array(favoriteGenres).sorted()
    }
    
    /// Reset to default genres
    func resetToDefaults() {
        favoriteGenres = defaultGenres
        saveFavoriteGenres()
    }
    
    /// Select all genres
    func selectAllGenres() {
        favoriteGenres = Set(allGenres)
        saveFavoriteGenres()
    }
    
    /// Clear all selections
    func clearAllGenres() {
        favoriteGenres = []
        saveFavoriteGenres()
    }
    
    // MARK: - Persistence
    
    private func loadFavoriteGenres() {
        isLoading = true
        
        // Try to load from UserDefaults first (local cache)
        if let savedGenres = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoriteGenres = Set(savedGenres)
            print("📱 Loaded favorite genres from UserDefaults: \(favoriteGenres.sorted())")
        } else {
            // Set defaults for new users
            favoriteGenres = defaultGenres
            saveFavoriteGenres()
            print("🆕 New user - set default favorite genres: \(favoriteGenres.sorted())")
        }
        
        isLoading = false
        
        // Also sync with Firestore for cross-device preferences
        syncWithFirestore()
    }
    
    private func saveFavoriteGenres() {
        // Save to UserDefaults for immediate access
        UserDefaults.standard.set(Array(favoriteGenres), forKey: favoritesKey)
        
        // Sync to Firestore for cross-device access
        syncWithFirestore()
    }
    
    private func syncWithFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let genresArray = Array(favoriteGenres)
        
        db.collection("users").document(userId).updateData([
            "favoriteGenres": genresArray,
            "genrePreferencesUpdated": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("⚠️ Failed to sync genre preferences to Firestore: \(error.localizedDescription)")
            } else {
                print("✅ Genre preferences synced to Firestore")
            }
        }
    }
    
    /// Load preferences from Firestore (for cross-device sync)
    func loadFromFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let data = document.data(),
               let firestoreGenres = data["favoriteGenres"] as? [String] {
                
                await MainActor.run {
                    let firestoreSet = Set(firestoreGenres)
                    
                    // Only update if different from current
                    if firestoreSet != favoriteGenres {
                        favoriteGenres = firestoreSet
                        UserDefaults.standard.set(Array(favoriteGenres), forKey: favoritesKey)
                        print("🔄 Synced favorite genres from Firestore: \(favoriteGenres.sorted())")
                    }
                }
            }
        } catch {
            print("⚠️ Failed to load genre preferences from Firestore: \(error.localizedDescription)")
        }
    }
}

// MARK: - Genre Preferences Extensions

extension GenrePreferencesService {
    
    /// Get recommended genres based on user's music logs
    func getRecommendedGenres(from musicLogs: [MusicLog]) -> [String] {
        var genreCounts: [String: Int] = [:]
        
        // Count genres from user's logs
        for log in musicLogs {
            if let primaryGenre = log.primaryGenre {
                genreCounts[primaryGenre, default: 0] += 1
            }
        }
        
        // Return top 5 genres not already favorited
        return genreCounts
            .sorted { $0.value > $1.value }
            .map { $0.key }
            .filter { !favoriteGenres.contains($0) }
            .prefix(5)
            .map { $0 }
    }
    
    /// Check if user has enough genres selected for good experience
    var hasGoodGenreSelection: Bool {
        return favoriteGenres.count >= 3 && favoriteGenres.count <= 8
    }
    
    /// Get suggestion for better genre selection
    var selectionSuggestion: String? {
        if favoriteGenres.count < 3 {
            return "Select at least 3 genres for better recommendations"
        } else if favoriteGenres.count > 10 {
            return "Consider selecting fewer genres for a more focused experience"
        }
        return nil
    }
}
