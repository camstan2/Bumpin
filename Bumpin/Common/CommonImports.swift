// Common imports for Bumpin app
import Foundation
import SwiftUI
import Combine

// Firebase imports
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// Location imports
import CoreLocation
import MapKit

// Media imports
import MediaPlayer
import AVFoundation
import MusicKit

// MARK: - Common Type Aliases
typealias FirestoreDocument = DocumentSnapshot
typealias FirestoreQuery = Query
typealias UserID = String
typealias PartyID = String

// MARK: - Common Extensions
extension View {
    /// Applies common styling to buttons throughout the app
    func bumpinButtonStyle() -> some View {
        self.buttonStyle(.borderedProminent)
            .tint(.purple)
    }
    
    /// Common shadow style used throughout the app
    func bumpinShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// Theme colors are now defined in PartyView.swift to avoid redeclaration
extension Color {
    static let bumpinBackground = Color(.systemBackground)
    static let bumpinSecondaryBackground = Color(.systemGray6)
}

// MARK: - Common Error Handling
enum BumpinError: Error {
    case networkError(String)
    case authenticationError(String)
    case databaseError(String)
    case invalidInput(String)
    case unexpectedError(String)
    
    var localizedDescription: String {
        switch self {
        case .networkError(let message): return "Network Error: \(message)"
        case .authenticationError(let message): return "Auth Error: \(message)"
        case .databaseError(let message): return "Database Error: \(message)"
        case .invalidInput(let message): return "Invalid Input: \(message)"
        case .unexpectedError(let message): return "Unexpected Error: \(message)"
        }
    }
}

// MARK: - Common Protocols
protocol ErrorHandling {
    func handle(_ error: Error)
    func showError(_ message: String)
}

extension ErrorHandling {
    func handle(_ error: Error) {
        print("❌ Error: \(error.localizedDescription)")
        showError(error.localizedDescription)
    }
}

// Card style is now defined in PartyView.swift to avoid redeclaration
