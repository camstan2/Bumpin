//
//  MinimizedDJStreamIndicator.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI

struct MinimizedDJStreamIndicator: View {
    @ObservedObject var djService: DJStreamService
    @State private var isAnimating = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        if djService.isStreamMinimized && djService.isStreaming {
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Floating DJ stream indicator
                    floatingIndicatorContent
                        .offset(dragOffset)
                        .scaleEffect(isDragging ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                djService.restoreStream()
                            }
                        }
                        .gesture(dragGesture)
                        .contextMenu {
                            contextMenuContent
                        }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Above tab bar
            }
            .onAppear {
                setupAppearance()
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
    
    // MARK: - Floating Indicator Content
    
    private var floatingIndicatorContent: some View {
        HStack(spacing: 12) {
            // DJ visualization (animated bars)
            audioVisualization
            
            // Stream info
            streamInfoSection
            
            // Microphone icon with level indicator
            microphoneIndicator
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(streamBackground)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Audio Visualization
    
    private var audioVisualization: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(visualizationGradient)
                    .frame(
                        width: 3,
                        height: isAnimating ? CGFloat.random(in: 8...16) : 6
                    )
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
    }
    
    // MARK: - Stream Info Section
    
    private var streamInfoSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("🎧 LIVE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(djService.streamTitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text("\(djService.listenerCount) listeners")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Microphone Indicator
    
    private var microphoneIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 32, height: 32)
            
            Image(systemName: "mic.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .scaleEffect(1 + CGFloat(djService.audioLevel) * 0.3)
                .animation(.easeInOut(duration: 0.1), value: djService.audioLevel)
        }
    }
    
    // MARK: - Background Gradient
    
    private var streamBackground: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.9),
                Color.blue.opacity(0.9)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var visualizationGradient: LinearGradient {
        LinearGradient(
            colors: [Color.purple, Color.blue],
            startPoint: .bottom,
            endPoint: .top
        )
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false
                
                // Snap back to position
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    dragOffset = .zero
                }
                
                // If dragged far enough, dismiss
                if abs(value.translation.width) > 100 || abs(value.translation.height) > 100 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        djService.stopDJStream()
                    }
                }
            }
    }
    
    // MARK: - Context Menu Content
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: {
            djService.restoreStream()
        }) {
            Label("Open Stream", systemImage: "arrow.up.circle")
        }
        
        Button(action: {
            // Toggle mute (if implemented)
        }) {
            Label("Mute", systemImage: "mic.slash")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            djService.stopDJStream()
        }) {
            Label("End Stream", systemImage: "stop.circle")
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupAppearance() {
        isAnimating = true
        
        // Entrance animation
        dragOffset = CGSize(width: 0, height: 100)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            dragOffset = .zero
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        MinimizedDJStreamIndicator(djService: DJStreamService.shared)
    }
}