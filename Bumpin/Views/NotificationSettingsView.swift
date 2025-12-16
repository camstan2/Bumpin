import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationPreferencesService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSystemSettingsAlert = false
    
    var body: some View {
        List {
            // Master Toggle Section
            Section(
                header: Text("Push Notifications"),
                footer: Text(notificationService.pushNotificationsEnabled ? 
                    "Notifications are enabled. You can customize which types you receive below." :
                    "Push notifications are disabled in your device settings. Tap to enable.")
            ) {
                Button(action: {
                    if notificationService.pushNotificationsEnabled {
                        showSystemSettingsAlert = true
                    } else {
                        Task {
                            _ = await notificationService.requestNotificationPermission()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: notificationService.pushNotificationsEnabled ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notificationService.pushNotificationsEnabled ? .green : .red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Notifications")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(notificationService.pushNotificationsEnabled ? "Notifications enabled" : "Tap to enable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if notificationService.pushNotificationsEnabled {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Individual Notification Types
            if notificationService.pushNotificationsEnabled {
                Section(header: Text("Social Notifications")) {
                    NotificationToggleRow(
                        icon: "heart.fill",
                        color: .red,
                        title: "Likes & Reactions",
                        description: "When someone likes your posts or logs",
                        isOn: $notificationService.likesEnabled
                    )
                    
                    NotificationToggleRow(
                        icon: "bubble.left.fill",
                        color: .blue,
                        title: "Comments",
                        description: "When someone comments on your content",
                        isOn: $notificationService.commentsEnabled
                    )
                    
                    NotificationToggleRow(
                        icon: "person.badge.plus.fill",
                        color: .green,
                        title: "New Followers",
                        description: "When someone follows you",
                        isOn: $notificationService.followersEnabled
                    )
                    
                    NotificationToggleRow(
                        icon: "flame.fill",
                        color: .orange,
                        title: "Social Feed",
                        description: "Trending content and friend activity",
                        isOn: $notificationService.socialFeedEnabled
                    )
                }
                
                Section(header: Text("Messages & Matchmaking")) {
                    NotificationToggleRow(
                        icon: "message.fill",
                        color: .purple,
                        title: "Messages",
                        description: "New direct messages and replies",
                        isOn: $notificationService.messagesEnabled
                    )
                    
                    NotificationToggleRow(
                        icon: "heart.text.square.fill",
                        color: .pink,
                        title: "Matchmaking",
                        description: "New music matches and recommendations",
                        isOn: $notificationService.matchmakingEnabled
                    )
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if notificationService.isLoading {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task {
                            await notificationService.savePreferences()
                            dismiss()
                        }
                    }
                }
            }
        }
        .alert("Manage in Settings", isPresented: $showSystemSettingsAlert) {
            Button("Open Settings") {
                notificationService.openSystemSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To change notification permissions, please visit your device Settings app.")
        }
    }
}

// MARK: - Notification Toggle Row

struct NotificationToggleRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

