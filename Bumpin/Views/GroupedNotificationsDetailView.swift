import SwiftUI
import FirebaseFirestore

/// Detail view showing all individual notifications from a grouped notification
struct GroupedNotificationsDetailView: View {
    let groupedNotification: GroupedNotification
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserId: String?
    @State private var showUserProfile = false
    @State private var selectedLog: MusicLog?
    @State private var showComments = false
    
    var body: some View {
        ZStack {
            // Always show background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Enhanced Header with log info
                    VStack(spacing: 16) {
                        // Album artwork
                        if let imageUrl = groupedNotification.contextImageUrl, 
                           !imageUrl.isEmpty,
                           let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    placeholderArtwork
                                case .empty:
                                    ProgressView()
                                        .frame(width: 140, height: 140)
                                @unknown default:
                                    placeholderArtwork
                                }
                            }
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        } else {
                            placeholderArtwork
                        }
                        
                        // Title and subtitle
                        VStack(spacing: 6) {
                            if let title = groupedNotification.contextTitle, !title.isEmpty {
                                Text(title)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                            } else {
                                Text("Music Log")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let subtitle = groupedNotification.contextSubtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Action count
                            HStack(spacing: 6) {
                                Image(systemName: groupedNotification.type.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(groupedNotification.type.color)
                                
                                Text(actionText)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(groupedNotification.type.color)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    
                    Divider()
                    
                    // List of users who interacted
                    if groupedNotification.notifications.isEmpty {
                        // Empty state (should never happen but just in case)
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No notifications")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(groupedNotification.notifications) { notification in
                                NotificationDetailRow(
                                    notification: notification,
                                    onUserTap: {
                                        if let userId = notification.fromUserId {
                                            selectedUserId = userId
                                            showUserProfile = true
                                        }
                                    }
                                )
                                
                                if notification.id != groupedNotification.notifications.last?.id {
                                    Divider()
                                        .padding(.leading, 70)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(groupTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                    }
                    .foregroundColor(.purple)
                }
            }
        }
        .fullScreenCover(isPresented: $showUserProfile) {
            if let userId = selectedUserId {
                UserProfileView(userId: userId, showFullProfile: false)
            }
        }
    }
    
    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 140, height: 140)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var actionText: String {
        let count = groupedNotification.count
        switch groupedNotification.type {
        case .musicLogLiked:
            return "\(count) \(count == 1 ? "like" : "likes")"
        case .musicLogReposted:
            return "\(count) \(count == 1 ? "repost" : "reposts")"
        case .musicLogDisliked:
            return "\(count) \(count == 1 ? "dislike" : "dislikes")"
        default:
            return "\(count) interactions"
        }
    }
    
    private var groupTitle: String {
        switch groupedNotification.type {
        case .musicLogLiked:
            return "Likes"
        case .musicLogReposted:
            return "Reposts"
        case .musicLogDisliked:
            return "Dislikes"
        default:
            return "Interactions"
        }
    }
}

/// Row showing a single user interaction
struct NotificationDetailRow: View {
    let notification: AppNotification
    let onUserTap: () -> Void
    
    var body: some View {
        Button(action: onUserTap) {
            HStack(spacing: 12) {
                // Profile picture with better styling
                Group {
                    if let profilePictureUrl = notification.fromUserProfilePictureUrl,
                       !profilePictureUrl.isEmpty,
                       let url = URL(string: profilePictureUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                defaultProfileIcon
                            @unknown default:
                                defaultProfileIcon
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        defaultProfileIcon
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Display name (purple to indicate tappable)
                    if let displayName = notification.fromUserName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    } else {
                        Text("Unknown User")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    // Username
                    if let username = notification.fromUserUsername, !username.isEmpty {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Timestamp
                    Text(timeAgo(from: notification.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Read indicator
                    if !notification.isRead {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text("New")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(notification.isRead ? Color.clear : Color.blue.opacity(0.03))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var defaultProfileIcon: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            )
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            if day == 1 {
                return "Yesterday"
            } else if day < 7 {
                return "\(day)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
}
