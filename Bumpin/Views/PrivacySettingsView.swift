import SwiftUI

struct PrivacySettingsView: View {
    @StateObject private var privacyService = PrivacySettingsService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            // Profile Visibility Section
            Section(
                header: Text("Profile Visibility"),
                footer: Text(privacyService.profileVisibility.description)
            ) {
                ForEach(ProfileVisibility.allCases) { visibility in
                    Button(action: {
                        privacyService.profileVisibility = visibility
                    }) {
                        HStack {
                            Image(systemName: visibility.icon)
                                .foregroundColor(iconColor(for: visibility))
                                .frame(width: 24)
                            
                            Text(visibility.displayName)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if privacyService.profileVisibility == visibility {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Logs Visibility Section
            Section(
                header: Text("Music Logs Visibility"),
                footer: Text(privacyService.logsVisibility.description)
            ) {
                ForEach(LogsVisibility.allCases) { visibility in
                    Button(action: {
                        privacyService.logsVisibility = visibility
                    }) {
                        HStack {
                            Image(systemName: visibility == .everyone ? "music.note" : visibility == .friends ? "person.2.fill" : "lock.fill")
                                .foregroundColor(visibility == .everyone ? .purple : visibility == .friends ? .blue : .gray)
                                .frame(width: 24)
                            
                            Text(visibility.displayName)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if privacyService.logsVisibility == visibility {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Messaging Privacy Section
            Section(
                header: Text("Messages"),
                footer: Text(privacyService.whoCanMessage.description)
            ) {
                ForEach(MessagingPrivacy.allCases) { privacy in
                    Button(action: {
                        privacyService.whoCanMessage = privacy
                    }) {
                        HStack {
                            Image(systemName: privacy == .everyone ? "message.fill" : privacy == .friends ? "message.badge.fill" : "message.slash.fill")
                                .foregroundColor(privacy == .everyone ? .green : privacy == .friends ? .blue : .red)
                                .frame(width: 24)
                            
                            Text(privacy.displayName)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if privacyService.whoCanMessage == privacy {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Activity Status Section
            Section(
                header: Text("Activity Status"),
                footer: Text("Let friends see when you're active on Bumpin")
            ) {
                Toggle(isOn: $privacyService.showActivityStatus) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(privacyService.showActivityStatus ? .green : .gray)
                            .frame(width: 24)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Activity Status")
                                .font(.subheadline)
                            Text(privacyService.showActivityStatus ? "Friends can see when you're active" : "Your activity is hidden")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if privacyService.isLoading {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task {
                            await privacyService.savePrivacySettings()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func iconColor(for visibility: ProfileVisibility) -> Color {
        switch visibility {
        case .public: return .green
        case .friends: return .blue
        case .private: return .red
        }
    }
}

