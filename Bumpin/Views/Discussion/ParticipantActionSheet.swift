//
//  ParticipantActionSheet.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import FirebaseAuth

struct ParticipantActionSheet: View {
    let participant: TopicParticipant
    let chat: TopicChat
    let discussionType: DiscussionType
    let mutedUsers: Set<String> // Users muted by current user
    let onAction: (ParticipantAction) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private var isHost: Bool {
        chat.hostId == currentUserId
    }
    
    private var isSpeaker: Bool {
        chat.speakers.contains(participant.id)
    }
    
    private var isCurrentUser: Bool {
        participant.id == currentUserId
    }
    
    private var isUserMuted: Bool {
        mutedUsers.contains(participant.id)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Participant Header
                participantHeaderView
                
                Divider()
                    .padding(.horizontal)
                
                // Action Options
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Universal Actions (available to all users)
                        universalActionsSection
                        
                        // Host-Only Actions
                        if isHost && !isCurrentUser {
                            Divider()
                                .padding(.horizontal)
                            
                            hostActionsSection
                        }
                    }
                }
            }
            .navigationTitle("Participant Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Header View
    
    private var participantHeaderView: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: URL(string: participant.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Text(String(participant.name.prefix(1)))
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            // Participant Info
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(participant.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if participant.isHost {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                // Status Indicators
                HStack(spacing: 12) {
                    // Speaking Status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isSpeaker ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(isSpeaker ? "Speaking" : "Listening")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Discussion Type
                    HStack(spacing: 4) {
                        Image(systemName: discussionType == .randomChat ? "person.2" : "text.bubble")
                            .font(.caption)
                        Text(discussionType == .randomChat ? "Random Chat" : "Topic Chat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Universal Actions
    
    private var universalActionsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Actions")
            
            // View Profile
            actionRow(
                icon: "person.circle",
                title: "View Profile",
                subtitle: "See \(participant.name)'s profile",
                color: .blue
            ) {
                onAction(.viewProfile(participant.id))
                dismiss()
            }
            
            // Mute/Unmute for Current User
            if !isCurrentUser {
                actionRow(
                    icon: isUserMuted ? "speaker" : "speaker.slash",
                    title: isUserMuted ? "Unmute for Me" : "Mute for Me",
                    subtitle: isUserMuted ? "You'll hear \(participant.name) again" : "You won't hear \(participant.name)",
                    color: isUserMuted ? .green : .orange
                ) {
                    onAction(.muteForCurrentUser(participant.id))
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Host Actions
    
    private var hostActionsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Host Controls")
            
            // Speaking Permissions
            if isSpeaker {
                actionRow(
                    icon: "mic.slash",
                    title: "Remove Speaking",
                    subtitle: "Move to listeners",
                    color: .orange
                ) {
                    onAction(.removeSpeaking(participant.id))
                    dismiss()
                }
            } else {
                actionRow(
                    icon: "mic",
                    title: "Give Speaking",
                    subtitle: "Allow to speak",
                    color: .green
                ) {
                    onAction(.giveSpeaking(participant.id))
                    dismiss()
                }
            }
            
            // Global Mute (host mutes participant for everyone)
            actionRow(
                icon: "speaker.slash.fill",
                title: "Mute for Everyone",
                subtitle: "No one will hear \(participant.name)",
                color: .red
            ) {
                onAction(.muteForEveryone(participant.id))
                dismiss()
            }
            
            // Kick from Discussion
            actionRow(
                icon: "person.badge.minus",
                title: "Remove from Discussion",
                subtitle: "Kick \(participant.name) out",
                color: .red,
                isDestructive: true
            ) {
                onAction(.kickParticipant(participant.id))
                dismiss()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDestructive ? .red : color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Participant Actions

enum ParticipantAction {
    case viewProfile(String)
    case muteForCurrentUser(String)
    case muteForEveryone(String)
    case giveSpeaking(String)
    case removeSpeaking(String)
    case kickParticipant(String)
}

// MARK: - Preview

#Preview {
    ParticipantActionSheet(
        participant: TopicParticipant(
            id: "user123",
            name: "John Doe",
            profileImageUrl: nil,
            isHost: false
        ),
        chat: TopicChat(
            title: "Marvel Discussion",
            description: "Talk about Marvel movies",
            category: .movies,
            hostId: "host123",
            hostName: "Host User"
        ),
        discussionType: .randomChat,
        mutedUsers: ["user456"], // Example muted users
        onAction: { action in
            print("Action: \(action)")
        }
    )
}
