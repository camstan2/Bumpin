import SwiftUI

struct MusicPartyWeatherView: View {
    // MARK: - Properties
    @StateObject private var weatherMusicService = MusicPartyWeatherService.shared
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Weather Music")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        refreshButton
                    }
                }
        }
        .alert("Error", isPresented: .constant(weatherMusicService.error != nil)) {
            Button("OK") {
                weatherMusicService.error = nil
            }
        } message: {
            if let error = weatherMusicService.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Subviews
    private var mainContent: some View {
        Group {
            if weatherMusicService.isLoading {
                loadingView
            } else if weatherMusicService.currentSuggestions.isEmpty {
                emptyStateView
            } else {
                suggestionsList
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Finding the perfect songs for this weather...")
                .foregroundStyle(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("No music suggestions yet")
                .font(.headline)
            
            Text("Tap refresh to get weather-based music suggestions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var suggestionsList: some View {
        List(weatherMusicService.currentSuggestions) { suggestion in
            suggestionRow(for: suggestion)
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refresh()
        }
    }
    
    private func suggestionRow(for suggestion: MusicWeatherSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(suggestion.songTitle)
                        .font(.headline)
                    Text(suggestion.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await weatherMusicService.applySuggestionToParty(suggestion)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
            
            HStack {
                Image(systemName: "cloud.sun.fill")
                Text(suggestion.weatherCondition.description)
                Spacer()
                Text("Confidence: \(Int(suggestion.confidence * 100))%")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var refreshButton: some View {
        Button(action: refresh) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(weatherMusicService.isLoading)
    }
    
    // MARK: - Actions
    private func refresh() {
        Task {
            await weatherMusicService.refreshSuggestions()
        }
    }
}
