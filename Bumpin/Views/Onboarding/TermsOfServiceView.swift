import SwiftUI
import WebKit

struct TermsOfServiceView: View {
    @Binding var isPresented: Bool
    @State private var hasScrolledToBottom = false
    @State private var hasAccepted = false
    let onAccept: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                    
                    Text("Terms of Service")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Please read and accept our terms to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Terms Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Zero Tolerance Warning
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("ZERO TOLERANCE POLICY")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                
                                Text("Bumpin has ZERO TOLERANCE for objectionable content, abusive behavior, harassment, or any form of inappropriate conduct. Users who violate these terms will be immediately removed from the platform without warning.")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding()
                            
                            // Web View for Terms
                            TermsWebView(hasScrolledToBottom: $hasScrolledToBottom)
                                .frame(minHeight: 400)
                            
                            // Bottom marker for scroll detection
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .onAppear {
                        // Auto-scroll to bottom after a delay to encourage reading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Acceptance Section
                VStack(spacing: 16) {
                    // Scroll indicator
                    if !hasScrolledToBottom {
                        HStack {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.orange)
                            Text("Please scroll to read the full terms")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Acceptance Toggle
                    Toggle(isOn: $hasAccepted) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I have read and agree to the Terms of Service")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("Including the zero tolerance policy for objectionable content")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .disabled(!hasScrolledToBottom)
                    
                    // Accept Button
                    Button(action: {
                        onAccept()
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                            Text("Accept Terms & Continue")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: hasAccepted ? [.purple, .blue] : [.gray, .gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                    .disabled(!hasAccepted || !hasScrolledToBottom)
                    .scaleEffect(hasAccepted ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 0.2), value: hasAccepted)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled() // Prevent dismissal without acceptance
    }
}

struct TermsWebView: UIViewRepresentable {
    @Binding var hasScrolledToBottom: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        
        // Load local terms file
        if let url = Bundle.main.url(forResource: "terms-of-service", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        let parent: TermsWebView
        
        init(_ parent: TermsWebView) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let frameHeight = scrollView.frame.size.height
            
            // Check if scrolled near bottom (within 50 points)
            if offsetY + frameHeight >= contentHeight - 50 {
                DispatchQueue.main.async {
                    self.parent.hasScrolledToBottom = true
                }
            }
        }
    }
}

// MARK: - Terms Acceptance Tracking

class LegacyTermsAcceptanceManager: ObservableObject {
    @Published var hasAcceptedTerms: Bool {
        didSet {
            UserDefaults.standard.set(hasAcceptedTerms, forKey: "hasAcceptedTerms")
        }
    }
    
    @Published var termsAcceptanceDate: Date? {
        didSet {
            if let date = termsAcceptanceDate {
                UserDefaults.standard.set(date, forKey: "termsAcceptanceDate")
            }
        }
    }
    
    init() {
        self.hasAcceptedTerms = UserDefaults.standard.bool(forKey: "hasAcceptedTerms")
        if let date = UserDefaults.standard.object(forKey: "termsAcceptanceDate") as? Date {
            self.termsAcceptanceDate = date
        }
    }
    
    func acceptTerms() {
        hasAcceptedTerms = true
        termsAcceptanceDate = Date()
        
        // Log acceptance for compliance
        print("✅ Terms accepted at: \(Date())")
        
        // Optional: Send to analytics
        AnalyticsService.shared.logEvent("terms_accepted", parameters: [
            "acceptance_date": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        ])
    }
    
    func requiresTermsAcceptance() -> Bool {
        return !hasAcceptedTerms
    }
}

#Preview {
    TermsOfServiceView(isPresented: .constant(true)) {
        print("Terms accepted!")
    }
}
