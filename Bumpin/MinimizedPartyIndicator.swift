//
//  MinimizedPartyIndicator.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI

struct MinimizedPartyIndicator: View {
    @ObservedObject var partyManager: PartyManager
    @State private var isAnimating = false
    @State private var showingDetails = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        if partyManager.isPartyMinimized, let party = partyManager.currentParty {
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Floating party indicator
                    HStack(spacing: 12) {
                        // Music visualization
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.bumpinPurple)
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
                            Text(party.name)
                                .font(.bumpinLabelMedium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if let currentSong = party.currentSong {
                                Text("\(currentSong.title) • \(currentSong.artist)")
                                    .font(.bumpinCaptionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                            } else {
                                Text("\(party.participants.count) participants")
                                    .font(.bumpinCaptionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        // Play/Pause button
                        Button(action: {
                            partyManager.togglePlayback()
                        }) {
                            Image(systemName: partyManager.musicManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.bumpinPurple.opacity(0.3))
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
                        // Restore party with haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            partyManager.restoreParty()
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
                                        partyManager.leaveParty()
                                    }
                                }
                                // Swipe up to restore
                                else if value.translation.height < -50 {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        partyManager.restoreParty()
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
                            partyManager.restoreParty()
                        }) {
                            Label("Open Party", systemImage: "arrow.up.circle")
                        }
                        
                        Button(action: {
                            partyManager.togglePlayback()
                        }) {
                            Label(
                                partyManager.musicManager.isPlaying ? "Pause" : "Play",
                                systemImage: partyManager.musicManager.isPlaying ? "pause.circle" : "play.circle"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            partyManager.leaveParty()
                        }) {
                            Label("Leave Party", systemImage: "rectangle.portrait.and.arrow.right")
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
        
        MinimizedPartyIndicator(partyManager: {
            let manager = PartyManager()
            manager.currentParty = Party(
                name: "Friday Night Vibes",
                hostId: "host123",
                hostName: "John Doe"
            )
            manager.currentParty?.currentSong = Song(
                title: "Blinding Lights",
                artist: "The Weeknd",
                duration: 200
            )
            manager.isPartyMinimized = true
            return manager
        }())
    }
}
