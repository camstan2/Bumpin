import Foundation
import SwiftUI

// MARK: - Discussion Section Types

enum DiscussionSection: String, CaseIterable, Identifiable {
    case trending = "trending"
    case movies = "movies"
    case sports = "sports"
    case gaming = "gaming"
    case music = "music"
    case entertainment = "entertainment"
    case politics = "politics"
    case business = "business"
    case arts = "arts"
    case food = "food"
    case lifestyle = "lifestyle"
    case education = "education"
    case science = "science"
    case worldNews = "worldNews"
    case health = "health"
    case automotive = "automotive"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .trending: return "Trending"
        case .movies: return "Movies & TV"
        case .sports: return "Sports"
        case .gaming: return "Gaming"
        case .music: return "Music"
        case .entertainment: return "Entertainment"
        case .politics: return "Politics"
        case .business: return "Business"
        case .arts: return "Arts & Culture"
        case .food: return "Food & Dining"
        case .lifestyle: return "Lifestyle"
        case .education: return "Education"
        case .science: return "Science & Tech"
        case .worldNews: return "World News"
        case .health: return "Health & Fitness"
        case .automotive: return "Automotive"
        }
    }
    
    var icon: String {
        switch self {
        case .trending: return "flame.fill"
        case .movies: return "tv.fill"
        case .sports: return "sportscourt.fill"
        case .gaming: return "gamecontroller.fill"
        case .music: return "music.note"
        case .entertainment: return "star.fill"
        case .politics: return "building.columns.fill"
        case .business: return "briefcase.fill"
        case .arts: return "paintbrush.fill"
        case .food: return "fork.knife"
        case .lifestyle: return "heart.fill"
        case .education: return "graduationcap.fill"
        case .science: return "atom"
        case .worldNews: return "globe"
        case .health: return "cross.fill"
        case .automotive: return "car.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .trending: return .orange
        case .movies: return .purple
        case .sports: return .green
        case .gaming: return .pink
        case .music: return .blue
        case .entertainment: return .yellow
        case .politics: return .red
        case .business: return .gray
        case .arts: return .indigo
        case .food: return .brown
        case .lifestyle: return .cyan
        case .education: return .teal
        case .science: return .mint
        case .worldNews: return .blue
        case .health: return .green
        case .automotive: return .orange
        }
    }
    
    static var defaultEnabledSections: Set<DiscussionSection> {
        // Default to the original 4 sections that were already implemented
        return [.trending, .sports, .politics, .movies]
    }
}

// MARK: - Discussion Preferences Service

@MainActor
class DiscussionPreferencesService: ObservableObject {
    
    static let shared = DiscussionPreferencesService()
    
    @Published var enabledSections: Set<DiscussionSection> = []
    @Published var showDiscussionSettings = false
    
    private let userDefaults = UserDefaults.standard
    private let enabledSectionsKey = "discussion_enabled_sections"
    
    private init() {
        loadEnabledSections()
    }
    
    // MARK: - Public Methods
    
    func isSectionEnabled(_ section: DiscussionSection) -> Bool {
        return enabledSections.contains(section)
    }
    
    func toggleSection(_ section: DiscussionSection) {
        if enabledSections.contains(section) {
            enabledSections.remove(section)
        } else {
            enabledSections.insert(section)
        }
        saveEnabledSections()
    }
    
    func enableAllSections() {
        enabledSections = DiscussionSection.defaultEnabledSections
        saveEnabledSections()
    }
    
    func disableAllSections() {
        enabledSections = []
        saveEnabledSections()
    }
    
    func resetToDefaults() {
        enabledSections = DiscussionSection.defaultEnabledSections
        saveEnabledSections()
    }
    
    var enabledSectionsArray: [DiscussionSection] {
        return DiscussionSection.allCases.filter { enabledSections.contains($0) }
    }
    
    var selectionSuggestion: String? {
        let count = enabledSections.count
        let total = DiscussionSection.allCases.count
        
        if count == 0 {
            return "Select at least one section to see discussions"
        } else if count == 1 {
            return "Consider adding more sections for variety"
        } else if count == total {
            return "All sections enabled - you'll see everything!"
        } else {
            return "\(count) of \(total) sections enabled"
        }
    }
    
    // MARK: - Private Methods
    
    private func loadEnabledSections() {
        if let savedData = userDefaults.data(forKey: enabledSectionsKey),
           let decodedSections = try? JSONDecoder().decode([String].self, from: savedData) {
            enabledSections = Set(decodedSections.compactMap { DiscussionSection(rawValue: $0) })
        } else {
            // First time user - enable all sections by default
            enabledSections = DiscussionSection.defaultEnabledSections
            saveEnabledSections()
        }
    }
    
    private func saveEnabledSections() {
        let sectionsArray = enabledSections.map { $0.rawValue }
        if let encodedData = try? JSONEncoder().encode(sectionsArray) {
            userDefaults.set(encodedData, forKey: enabledSectionsKey)
        }
    }
}
