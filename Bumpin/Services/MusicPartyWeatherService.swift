import Foundation
import SwiftUI
import Combine

// MARK: - Music Weather Suggestion Model
struct MusicWeatherSuggestion: Identifiable {
    let id = UUID()
    let songTitle: String
    let artist: String
    let weatherCondition: WeatherCondition
    let confidence: Double // 0.0 to 1.0
    
    var description: String {
        "\(songTitle) by \(artist) - Perfect for \(weatherCondition) weather!"
    }
}

// MARK: - Music Party Weather Service
@MainActor
final class MusicPartyWeatherService: ObservableObject {
    // MARK: - Singleton
    public static let shared = MusicPartyWeatherService()
    
    // MARK: - Published Properties
    @Published private(set) var currentSuggestions: [MusicWeatherSuggestion] = []
    @Published private(set) var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    private let weatherService: WeatherService
    private let partyManager: PartyManager
    private let musicManager: MusicManager
    
    // MARK: - Initialization
    private init() {
        // Initialize dependencies
        self.weatherService = WeatherService.shared
        // Access the PartyManager via global environment when available.
        // Fallback to a fresh instance for non-UI contexts.
        self.partyManager = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController
            .flatMap { vc -> PartyManager? in
                // Attempt to find a SwiftUI environment object root (best-effort)
                return nil
            } ?? PartyManager()
        self.musicManager = MusicManager()
        
        // Setup initial state
        setupWeatherObserver()
        setupErrorHandling()
    }
    
    // MARK: - Setup Methods
    private func setupWeatherObserver() {
        weatherService.$currentWeather
            .sink { [weak self] weatherData in
                guard let self = self,
                      let weather = weatherData else { return }
                
                Task {
                    await self.updateSuggestionsForWeather(weather)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupErrorHandling() {
        weatherService.$error
            .sink { [weak self] error in
                if let error = error {
                    self?.error = error
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Applies the selected suggestion to the current party
    func applySuggestionToParty(_ suggestion: MusicWeatherSuggestion) async {
        guard let party = partyManager.currentParty else {
            error = NSError(domain: "MusicPartyWeatherService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No active party to add music to"
            ])
            return
        }
        
        // Here you would implement the logic to:
        // 1. Search for the song in Apple Music
        // 2. Add it to the party queue
        // For now, we'll just print the action
        print("Adding \(suggestion.songTitle) by \(suggestion.artist) to party \(party.name)")
    }
    
    /// Refreshes the weather-based music suggestions
    func refreshSuggestions() async {
        guard let weather = weatherService.currentWeather else {
            await weatherService.fetchWeather()
            return
        }
        
        await updateSuggestionsForWeather(weather)
    }
    
    // MARK: - Weather Suggestion Methods
    private func updateSuggestionsForWeather(_ weather: WeatherData) async {
        isLoading = true
        defer { isLoading = false }
        
        let suggestions = await getSuggestionsForCondition(weather.condition)
        
        await MainActor.run {
            self.currentSuggestions = suggestions
            self.error = nil
        }
    }
    
    private func getSuggestionsForCondition(_ condition: WeatherCondition) async -> [MusicWeatherSuggestion] {
        // Mock suggestions for now
        switch condition {
        case .sunny:
            return [
                MusicWeatherSuggestion(songTitle: "Walking on Sunshine", artist: "Katrina & The Waves", weatherCondition: condition, confidence: 0.95),
                MusicWeatherSuggestion(songTitle: "Here Comes the Sun", artist: "The Beatles", weatherCondition: condition, confidence: 0.90)
            ]
        case .rainy:
            return [
                MusicWeatherSuggestion(songTitle: "Purple Rain", artist: "Prince", weatherCondition: condition, confidence: 0.85),
                MusicWeatherSuggestion(songTitle: "Set Fire to the Rain", artist: "Adele", weatherCondition: condition, confidence: 0.80)
            ]
        case .cloudy:
            return [
                MusicWeatherSuggestion(songTitle: "Cloudy", artist: "Simon & Garfunkel", weatherCondition: condition, confidence: 0.75),
                MusicWeatherSuggestion(songTitle: "Both Sides Now", artist: "Joni Mitchell", weatherCondition: condition, confidence: 0.70)
            ]
        default:
            return [
                MusicWeatherSuggestion(songTitle: "Perfect Day", artist: "Lou Reed", weatherCondition: condition, confidence: 0.65),
                MusicWeatherSuggestion(songTitle: "Beautiful Day", artist: "U2", weatherCondition: condition, confidence: 0.60)
            ]
        }
    }
}