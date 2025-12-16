import SwiftUI

struct GlobalAlertBanner: View {
    @EnvironmentObject private var alertCenter: AlertCenter
    @State private var animateIn: Bool = false
    
    var body: some View {
        VStack {
            if let alert = alertCenter.currentAlert {
                Text(alert.message)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(alert.style.background)
                    .cornerRadius(12)
                    .shadow(radius: 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityLabel(alert.message)
            }
        }
        .padding(.top, 12)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: alertCenter.currentAlert)
    }
}

