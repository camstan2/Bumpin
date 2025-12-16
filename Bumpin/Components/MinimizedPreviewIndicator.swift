//
//  MinimizedPreviewIndicator.swift
//  Bumpin
//
//  Created by AI Assistant
//

import SwiftUI

struct MinimizedPreviewIndicator: View {
    @ObservedObject var previewService = PreviewPlayerService.shared
    @State private var isAnimating = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    // Navigation state to return to song profile
    @State private var navigateToProfile = false
    
    var body: some View {
        if shouldShowIndicator {
            VStack {
                Spacer()
                
                HStack {
                    // Floating preview indicator
                    HStack(spacing: 12) {
                        // Sound wave visualization
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.blue)
                                    .frame(width: 3, height: isAnimating && previewService.isPlaying ? 12 : 6)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                        value: isAnimating && previewService.isPlaying
                                    )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(previewService.currentSongTitle ?? "Preview")
                                .font(.bumpinLabelMedium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                Text(previewService.currentArtistName ?? "")
                                    .font(.bumpinCaptionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                                
                                if previewService.isPlaying {
                                    Text("•")
                                        .font(.bumpinCaptionSmall)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text(timeDisplay)
                                        .font(.bumpinCaptionSmall)
                                        .foregroundColor(.white.opacity(0.8))
                                        .monospacedDigit()
                                }
                            }
                        }
                        
                        // Play/Pause button
                        Button(action: {
                            previewService.togglePlayPause()
                        }) {
                            Image(systemName: previewService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.3))
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
                                            colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .scaleEffect(isDragging ? 0.95 : 1.0)
                    .offset(dragOffset)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
                    .onTapGesture {
                        // Navigate back to song profile with haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            navigateToSongProfile()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                isDragging = true
                            }
                            .onEnded { value in
                                isDragging = false
                                
                                // Swipe right OR left to dismiss (stop preview)
                                if value.translation.width > 100 {
                                    // Swipe right
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                                    impactFeedback.impactOccurred()
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        dragOffset.width = UIScreen.main.bounds.width
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        previewService.stop()
                                        dragOffset = .zero
                                    }
                                } else if value.translation.width < -100 {
                                    // Swipe left
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                                    impactFeedback.impactOccurred()
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        dragOffset.width = -UIScreen.main.bounds.width
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        previewService.stop()
                                        dragOffset = .zero
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
                    .contextMenu {
                        Button(action: {
                            navigateToSongProfile()
                        }) {
                            Label("Open Song", systemImage: "music.note")
                        }
                        
                        Button(action: {
                            previewService.togglePlayPause()
                        }) {
                            Label(
                                previewService.isPlaying ? "Pause" : "Play",
                                systemImage: previewService.isPlaying ? "pause.circle" : "play.circle"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            previewService.stop()
                        }) {
                            Label("Stop Preview", systemImage: "stop.circle")
                        }
                    }
                    
                    Spacer()
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
    
    // MARK: - Helper Properties
    
    private var shouldShowIndicator: Bool {
        // Show if there's a preview playing or paused AND we have song info
        return (previewService.isPlaying || previewService.currentPreviewUrl != nil) &&
               previewService.currentSongTitle != nil
    }
    
    private var timeDisplay: String {
        let current = Int(previewService.currentTime)
        return "\(current)"
    }
    
    // MARK: - Navigation
    
    private func navigateToSongProfile() {
        // For now, just provide haptic feedback
        // In a full implementation, you would navigate to the song profile using the itemId
        // This would require integration with your navigation system
        print("📱 Navigate to song profile: \(previewService.currentItemId ?? "unknown")")
        
        // Post notification that can be caught by the app to handle navigation
        if let itemId = previewService.currentItemId {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToSongProfile"),
                object: nil,
                userInfo: ["itemId": itemId]
            )
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        MinimizedPreviewIndicator()
    }
    .onAppear {
        // Simulate a playing preview
        let service = PreviewPlayerService.shared
        service.currentSongTitle = "Gangstas"
        service.currentArtistName = "Pop Smoke"
        service.isPlaying = true
        service.currentTime = 15.0
    }
}

