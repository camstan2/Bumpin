import SwiftUI
#if canImport(UIKit)
extension View {
    /// Dismisses the on-screen keyboard from anywhere in the current window.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
