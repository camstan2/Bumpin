import SwiftUI

struct AboutSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        List {
            // App Info Section
            Section(header: Text("App Information")) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Version")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    Text("Build")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(buildNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Legal Section
            Section(header: Text("Legal")) {
                Button(action: {
                    // Open Terms of Service
                    if let url = URL(string: "https://bumpin-4349a.web.app/terms.html") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        Text("Terms of Service")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Open Privacy Policy
                    if let url = URL(string: "https://bumpin-4349a.web.app/privacy.html") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        Text("Privacy Policy")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Support Section
            Section(header: Text("Support")) {
                Button(action: {
                    // Open support email
                    if let url = URL(string: "mailto:support@bumpin.app") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Contact Support")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Open website
                    if let url = URL(string: "https://bumpin.app") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        Text("Website")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Credits Section
            Section(header: Text("")) {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                    
                    Text("Bumpin")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Share your music taste with the world")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Made with ❤️")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

