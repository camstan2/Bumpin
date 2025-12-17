import SwiftUI
import WebKit

struct TermsOfServiceView: View {
    @Binding var isPresented: Bool
    @State private var hasScrolledToBottom = false
    @State private var hasAccepted = false
    let onAccept: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var contentPadding: CGFloat {
        isIPad ? 40 : 16
    }
    
    private var maxContentWidth: CGFloat {
        isIPad ? 800 : .infinity
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: isIPad ? 50 : 40))
                            .foregroundColor(.purple)
                        
                        Text("Terms of Service")
                            .font(isIPad ? .largeTitle : .title)
                            .fontWeight(.bold)
                        
                        Text("Please read and accept our terms to continue")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(contentPadding)
                    .frame(maxWidth: .infinity)
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
                                .padding(contentPadding)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal, contentPadding)
                                .padding(.top, contentPadding)
                                
                                // WebView with Terms
                                TermsWebView(hasScrolledToBottom: $hasScrolledToBottom)
                                    .frame(minHeight: isIPad ? 500 : 400)
                                    .padding(.horizontal, contentPadding)
                                
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                        }
                        .onAppear {
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
                        if !hasScrolledToBottom {
                            HStack {
                                Image(systemName: "arrow.down")
                                    .foregroundColor(.orange)
                                Text("Please scroll to read the full terms")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, contentPadding)
                        }
                        
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
                        .disabled(!hasAccepted)
                        .scaleEffect(hasAccepted ? 1.0 : 0.95)
                        .animation(.easeInOut(duration: 0.2), value: hasAccepted)
                    }
                    .padding(contentPadding)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                }
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Terms WebView
struct TermsWebView: UIViewRepresentable {
    @Binding var hasScrolledToBottom: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        // Load local terms HTML file
        if let url = Bundle.main.url(forResource: "terms-of-service", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            // Fallback: load inline terms
            let fallbackHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        padding: 20px;
                        line-height: 1.6;
                        color: #333;
                    }
                    @media (prefers-color-scheme: dark) {
                        body { color: #eee; background: transparent; }
                    }
                    h2 { color: #8B5CF6; }
                    h3 { color: #666; }
                    @media (prefers-color-scheme: dark) {
                        h3 { color: #aaa; }
                    }
                </style>
            </head>
            <body>
                <h2>Terms of Service</h2>
                <p>Welcome to Bumpin. By using our app, you agree to these terms.</p>
                
                <h3>1. User Conduct</h3>
                <p>You agree to use Bumpin responsibly and respectfully. Any form of harassment, hate speech, or objectionable content is strictly prohibited.</p>
                
                <h3>2. Content Guidelines</h3>
                <p>Users are responsible for all content they share. We reserve the right to remove any content that violates our community guidelines.</p>
                
                <h3>3. Privacy</h3>
                <p>We respect your privacy. Please review our Privacy Policy for details on how we collect and use your data.</p>
                
                <h3>4. Account Termination</h3>
                <p>We may terminate accounts that violate these terms without prior notice.</p>
                
                <h3>5. Changes to Terms</h3>
                <p>We may update these terms from time to time. Continued use of the app constitutes acceptance of any changes.</p>
                
                <p style="margin-top: 40px; color: #888;">Last updated: January 2025</p>
            </body>
            </html>
            """
            webView.loadHTMLString(fallbackHTML, baseURL: nil)
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var parent: TermsWebView
        
        init(_ parent: TermsWebView) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let scrollViewHeight = scrollView.frame.size.height
            
            // Check if scrolled near bottom (within 50 points)
            if offsetY + scrollViewHeight >= contentHeight - 50 {
                DispatchQueue.main.async {
                    self.parent.hasScrolledToBottom = true
                }
            }
        }
    }
}

#Preview {
    TermsOfServiceView(isPresented: .constant(true)) {
        print("Terms accepted")
    }
}
