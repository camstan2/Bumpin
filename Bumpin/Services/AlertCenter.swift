import Foundation
import SwiftUI

/// Simple user-facing alert that can be surfaced anywhere in the app.
struct UserAlert: Identifiable, Equatable {
    enum Style {
        case info, success, warning, error
        
        var background: Color {
            switch self {
            case .info: return Color.blue.opacity(0.85)
            case .success: return Color.green.opacity(0.85)
            case .warning: return Color.orange.opacity(0.9)
            case .error: return Color.red.opacity(0.9)
            }
        }
    }
    
    let id = UUID()
    let message: String
    let style: Style
}

/// Shared alert presenter for lightweight toast-style alerts.
@MainActor
final class AlertCenter: ObservableObject {
    static let shared = AlertCenter()
    
    @Published private(set) var currentAlert: UserAlert?
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    func showToast(_ message: String,
                   style: UserAlert.Style = .info,
                   duration: TimeInterval = 2.5) {
        dismissTask?.cancel()
        currentAlert = UserAlert(message: message, style: style)
        
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                if self?.currentAlert?.message == message {
                    self?.currentAlert = nil
                }
            }
        }
    }
    
    func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        currentAlert = nil
    }
}

