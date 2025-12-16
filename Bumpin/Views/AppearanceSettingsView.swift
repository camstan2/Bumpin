import SwiftUI

struct AppearanceSettingsView: View {
    @StateObject private var appearanceManager = AppearanceManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section(
                header: Text("Theme"),
                footer: Text("Choose how Bumpin looks. System will match your iPhone's appearance settings.")
            ) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button(action: {
                        appearanceManager.setAppearance(mode)
                    }) {
                        HStack {
                            Image(systemName: mode.icon)
                                .foregroundColor(iconColor(for: mode))
                                .frame(width: 28)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if appearanceManager.appearancePreference == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Preview Section
            Section(header: Text("Preview")) {
                VStack(spacing: 16) {
                    // Light mode preview
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .overlay(
                                VStack {
                                    Text("Aa")
                                        .font(.title)
                                        .foregroundColor(.primary)
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .frame(height: 80)
                        
                        Text("Light")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Dark mode preview
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black)
                            .overlay(
                                VStack {
                                    Text("Aa")
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .frame(height: 80)
                        
                        Text("Dark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func iconColor(for mode: AppearanceMode) -> Color {
        switch mode {
        case .system: return .purple
        case .light: return .orange
        case .dark: return .indigo
        }
    }
}

