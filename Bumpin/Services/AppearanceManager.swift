import SwiftUI
import Combine

/// Manages app appearance/theme preferences
@MainActor
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @AppStorage("appearance_preference") var appearancePreference: AppearanceMode = .system
    
    @Published var currentColorScheme: ColorScheme?
    
    private init() {
        updateColorScheme()
    }
    
    func setAppearance(_ mode: AppearanceMode) {
        appearancePreference = mode
        updateColorScheme()
    }
    
    private func updateColorScheme() {
        currentColorScheme = appearancePreference.colorScheme
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "Match your iPhone settings"
        case .light: return "Always use light mode"
        case .dark: return "Always use dark mode"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

