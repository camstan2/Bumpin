import SwiftUI

/// A small floating action button (circular purple “+”) that can be overlaid on any screen.
struct PlusFAB: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.purple))
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1)
        PlusFAB { print("Tapped") }
    }
}
