import Foundation
import CoreLocation

// Weather data models
struct WeatherData {
    let temperature: Double
    let condition: WeatherCondition
    let description: String
    let humidity: Double    // 0-100
    let windSpeed: Double   // mph
    let location: CLLocation?
    let timestamp: Date
}

enum WeatherCondition: String {
    case sunny = "sunny"
    case rainy = "rainy"
    case cloudy = "cloudy"
    case snowy = "snowy"
    case stormy = "stormy"
    case clear = "clear"
    
    var description: String {
        switch self {
        case .sunny: return "Sunny"
        case .rainy: return "Rainy"
        case .cloudy: return "Cloudy"
        case .snowy: return "Snowy"
        case .stormy: return "Stormy"
        case .clear: return "Clear"
        }
    }
}

@MainActor
class WeatherService: ObservableObject {
    static let shared = WeatherService()
    
    @Published private(set) var currentWeather: WeatherData?
    @Published var error: Error?
    @Published private(set) var isLoading = false
    
    private var locationManager: CLLocationManager?
    private var weatherUpdateTimer: Timer?
    
    private init() {
        setupLocationManager()
        startWeatherUpdates()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager?.requestWhenInUseAuthorization()
    }
    
    private func startWeatherUpdates() {
        // Update weather every 15 minutes
        weatherUpdateTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task {
                await self?.updateWeather()
            }
        }
        
        // Initial update
        Task {
            await updateWeather()
        }
    }
    
    enum WeatherServiceError: Error { case locationUnavailable }

    func fetchWeather() async {
        isLoading = true
        defer { isLoading = false }
        await updateWeather()
    }
    
    private func updateWeather() async {
        guard let location = locationManager?.location else {
            handleError(WeatherServiceError.locationUnavailable)
            return
        }
        
        do {
            // Simulate weather fetch for now
            // TODO: Integrate with actual weather API
            let weather = simulateWeatherData(for: location)
            await MainActor.run {
                self.currentWeather = weather
                self.error = nil
            }
        } catch {
            handleError(error)
        }
    }
    
    private func simulateWeatherData(for location: CLLocation) -> WeatherData {
        let conditions: [WeatherCondition] = [.sunny, .rainy, .cloudy, .clear]
        let randomCondition = conditions.randomElement() ?? .clear
        
        return WeatherData(
            temperature: Double.random(in: 60...80),
            condition: randomCondition,
            description: randomCondition.description,
            humidity: Double.random(in: 30...90),
            windSpeed: Double.random(in: 0...15),
            location: location,
            timestamp: Date()
        )
    }
    
    func handleError(_ error: Error) {
        Task { @MainActor in
            self.error = error
        }
    }
}