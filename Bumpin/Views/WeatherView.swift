import SwiftUI

struct WeatherView: View {
    // MARK: - Properties
    
    @ObservedObject private var weatherService = WeatherService.shared
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
    }
    
    // MARK: - Subviews
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            headerSection
            
            if weatherService.isLoading {
                loadingSection
            } else if let error = weatherService.error {
                errorSection(error)
            } else {
                contentSection
            }
        }
        .padding()
        .task {
            await weatherService.fetchWeather()
        }
    }
    
    private var headerSection: some View {
        Text("Weather")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    private var loadingSection: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Fetching weather...")
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
    
    private func errorSection(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error fetching weather")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await weatherService.fetchWeather()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    private var contentSection: some View {
        VStack(spacing: 30) {
            // Temperature
            VStack(spacing: 8) {
                if let weather = weatherService.currentWeather {
                    Text("\(Int(weather.temperature))°F")
                        .font(.system(size: 72, weight: .thin))
                } else {
                    Text("--°F")
                        .font(.system(size: 72, weight: .thin))
                }
                if let weather = weatherService.currentWeather {
                    Text(weather.condition.description)
                        .font(.title2)
                        .foregroundColor(.secondary)
                } else {
                    Text("No data")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Details
            HStack(spacing: 40) {
                // Humidity
                if let weather = weatherService.currentWeather {
                    WeatherDetailView(
                        icon: "humidity",
                        value: "\(Int(weather.humidity))%",
                        label: "Humidity"
                    )
                    
                    // Wind Speed
                    WeatherDetailView(
                        icon: "wind",
                        value: String(format: "%.1f mph", weather.windSpeed),
                        label: "Wind"
                    )
                } else {
                    WeatherDetailView(
                        icon: "humidity",
                        value: "--",
                        label: "Humidity"
                    )
                    
                    WeatherDetailView(
                        icon: "wind",
                        value: "--",
                        label: "Wind"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await weatherService.fetchWeather()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct WeatherDetailView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview Provider

#Preview {
    WeatherView()
}
