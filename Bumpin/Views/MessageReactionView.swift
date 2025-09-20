//
//  MessageReactionView.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI

struct MessageReactionView: View {
    let reactions: [ReactionSummary]
    let onReactionTapped: (String) -> Void
    
    var body: some View {
        if !reactions.isEmpty {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 60), spacing: 8)
            ], spacing: 8) {
                ForEach(reactions) { reaction in
                    ReactionBubble(
                        reaction: reaction,
                        onTapped: {
                            onReactionTapped(reaction.emoji)
                        }
                    )
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Individual Reaction Bubble

struct ReactionBubble: View {
    let reaction: ReactionSummary
    let onTapped: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTapped) {
            HStack(spacing: 4) {
                Text(reaction.emoji)
                    .font(.system(size: 16))
                
                Text("\(reaction.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(reaction.hasCurrentUser ? .white : .primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(reaction.hasCurrentUser ? Color.bumpinPurple : Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                reaction.hasCurrentUser ? Color.bumpinPurple.opacity(0.3) : Color(.systemGray4),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0.0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        )
    }
}

// MARK: - Reaction Users Tooltip

struct ReactionUsersTooltip: View {
    let reaction: ReactionSummary
    let usernames: [String] // Pass in the usernames for the reaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(reaction.emoji)
                    .font(.title2)
                
                Text("\(reaction.count) reaction\(reaction.count == 1 ? "" : "s")")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(usernames.enumerated()), id: \.offset) { index, username in
                    Text(username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        MessageReactionView(
            reactions: [
                ReactionSummary(emoji: "😂", reactions: [
                    MessageReaction(messageId: "1", emoji: "😂", userId: "user1", username: "John"),
                    MessageReaction(messageId: "1", emoji: "😂", userId: "user2", username: "Jane")
                ], currentUserId: "user1"),
                ReactionSummary(emoji: "❤️", reactions: [
                    MessageReaction(messageId: "1", emoji: "❤️", userId: "user3", username: "Bob")
                ], currentUserId: "user1"),
                ReactionSummary(emoji: "🔥", reactions: [
                    MessageReaction(messageId: "1", emoji: "🔥", userId: "user1", username: "Current")
                ], currentUserId: "user1")
            ],
            onReactionTapped: { emoji in
                print("Tapped reaction: \(emoji)")
            }
        )
        .padding()
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
