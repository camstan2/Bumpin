//
//  MinimizedDiscussionIndicator.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI

struct MinimizedDiscussionIndicator: View {
    @ObservedObject var discussionManager: DiscussionManager
    @State private var isAnimating = false
    @State private var showingDetails = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        if discussionManager.isDiscussionMinimized, let discussion = discussionManager.currentDiscussion {
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Floating discussion indicator
                    HStack(spacing: 12) {
                        // Voice visualization
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(discussionManager.isSpeaking ? Color.green : Color.bumpinPurple)
                                    .frame(width: 3, height: isAnimating ? 12 : 6)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: isAnimating
                                    )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(discussion.title)
                                .font(.bumpinLabelMedium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                // Discussion type indicator
                                Image(systemName: discussionManager.currentDiscussionType == .randomChat ? "person.2" : "text.bubble")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("\(discussion.participants.count) participants")
                                    .font(.bumpinCaptionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                if let currentDiscussion = discussion.currentDiscussion {
                                    Text("• \(currentDiscussion)")
                                        .font(.bumpinCaptionSmall)
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        // Mute/Unmute button
                        Button(action: {
                            discussionManager.toggleMute()
                        }) {
                            Image(systemName: discussionManager.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(discussionManager.isMuted ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .buttonStyle(BumpinButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.bumpinPurple.opacity(0.6), Color.bumpinPurpleLight.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .scaleEffect(showingDetails ? 1.05 : (isDragging ? 0.95 : 1.0))
                    .offset(dragOffset)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingDetails)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
                    .onTapGesture {
                        // Restore discussion with haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            discussionManager.restoreDiscussion()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                isDragging = true
                                
                                // Haptic feedback on drag start
                                if abs(value.translation.width) > 10 || abs(value.translation.height) > 10 {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
                            .onEnded { value in
                                isDragging = false
                                
                                // Swipe to dismiss (right swipe)
                                if value.translation.width > 100 {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                                    impactFeedback.impactOccurred()
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        dragOffset.width = UIScreen.main.bounds.width
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        discussionManager.leaveDiscussion()
                                    }
                                }
                                // Swipe up to restore
                                else if value.translation.height < -50 {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        discussionManager.restoreDiscussion()
                                    }
                                }
                                // Return to original position
                                else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                    .onLongPressGesture(minimumDuration: 0.1) {
                        // Show details on long press
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            showingDetails = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                showingDetails = false
                            }
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            discussionManager.restoreDiscussion()
                        }) {
                            Label("Open Discussion", systemImage: "arrow.up.circle")
                        }
                        
                        Button(action: {
                            discussionManager.toggleMute()
                        }) {
                            Label(
                                discussionManager.isMuted ? "Unmute" : "Mute",
                                systemImage: discussionManager.isMuted ? "mic.fill" : "mic.slash.fill"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            discussionManager.leaveDiscussion()
                        }) {
                            Label("Leave Discussion", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Above tab bar
            }
            .onAppear {
                isAnimating = true
                
                // Entrance animation
                dragOffset = CGSize(width: 0, height: 100)
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    dragOffset = .zero
                }
            }
            .onDisappear {
                isAnimating = false
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        MinimizedDiscussionIndicator(discussionManager: {
            let manager = DiscussionManager()
            var mockChat = TopicChat(
                title: "Marvel Phase 5 Discussion",
                description: "Discuss the latest Marvel movies",
                category: .movies,
                hostId: "host123",
                hostName: "John"
            )
            mockChat.id = "test123"
            mockChat.participants = [
                TopicParticipant(id: "user1", name: "John", profileImageUrl: nil),
                TopicParticipant(id: "user2", name: "Sarah", profileImageUrl: nil),
                TopicParticipant(id: "user3", name: "Mike", profileImageUrl: nil)
            ]
            mockChat.currentDiscussion = "What's your favorite Marvel movie?"
            manager.currentDiscussion = mockChat
            manager.currentDiscussionType = .randomChat
            manager.isDiscussionMinimized = true
            return manager
        }())
    }
}
