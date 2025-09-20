import SwiftUI

// MARK: - Live DJ Streams Discovery (Simplified)

struct LiveDJStreamsView: View {
    @StateObject private var djService = DJStreamService.shared
    @State private var liveStreams: [DJStreamService.DJStream] = []
    @State private var isLoading = true
    @State private var showingDJStream = false
    @State private var selectedStream: DJStreamService.DJStream?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Text("Live DJ Streams")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Start DJ Stream button
                        Button(action: {
                            showingDJStream = true
                        }) {
                            Image(systemName: "music.mic")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    LinearGradient(
                                        colors: [Color.purple, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 16)
                .background(Color(.systemGroupedBackground))
                
                // Content
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Finding live DJ streams...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if liveStreams.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "music.mic")
                            .font(.system(size: 60))
                            .foregroundColor(.purple.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("No Live DJ Streams")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Be the first to start a live DJ stream!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button(action: {
                            showingDJStream = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Start DJ Stream")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(liveStreams) { stream in
                                SimpleDJStreamCard(stream: stream) {
                                    selectedStream = stream
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Live DJ Streams")
            .navigationBarHidden(true)
            .onAppear {
                loadStreams()
            }
        }
        .sheet(item: $selectedStream) { stream in
            DJStreamListenerView(stream: stream)
        }
        .sheet(isPresented: $showingDJStream) {
            DJStreamView()
        }
    }
    
    private func loadStreams() {
        Task {
            isLoading = true
            let streams = await djService.loadLiveStreams()
            await MainActor.run {
                self.liveStreams = streams
                self.isLoading = false
            }
        }
    }
}

// MARK: - Simple DJ Stream Card

struct SimpleDJStreamCard: View {
    let stream: DJStreamService.DJStream
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // DJ profile placeholder
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.mic")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        )
                    
                    // Stream info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stream.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("DJ \(stream.djUsername)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Live indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        
                        Text("\(stream.listenerCount) listeners")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Genre badge
                HStack {
                    Text(stream.genre)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(8)
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - DJ Stream Listener View (Enhanced with Chat)

struct DJStreamListenerView: View {
    let stream: DJStreamService.DJStream
    @StateObject private var chatService = DJChatService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingChat = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("LIVE")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingChat = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "message")
                                .font(.title2)
                                .foregroundColor(.primary)
                            
                            // Chat indicator
                            if chatService.userCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // DJ Profile
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "music.mic")
                                .font(.title)
                                .foregroundColor(.secondary)
                        )
                    
                    VStack(spacing: 8) {
                        Text(stream.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("DJ \(stream.djUsername)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(stream.genre)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(12)
                    }
                }
                
                // Audio Visualizer Placeholder
                VStack(spacing: 16) {
                    Text("Now Playing")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<20, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple.opacity(0.6))
                                .frame(width: 4, height: CGFloat.random(in: 20...80))
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: true)
                        }
                    }
                    .frame(height: 80)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Listener Controls with Chat
                VStack(spacing: 16) {
                    // Volume control
                    HStack {
                        Image(systemName: "speaker.wave.1")
                            .foregroundColor(.secondary)
                        
                        Slider(value: .constant(0.7))
                            .accentColor(.purple)
                        
                        Image(systemName: "speaker.wave.3")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        // Share button
                        Button(action: {
                            // TODO: Implement share functionality
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                }
                
                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingChat) {
            DJLiveChatView(stream: DemoLiveDJStream(
                id: stream.id,
                djName: stream.djUsername,
                title: stream.title,
                genre: stream.genre,
                listenerCount: stream.listenerCount,
                isLive: stream.isLive,
                imageUrl: stream.djProfileImage ?? ""
            ))
        }
        .onAppear {
            Task {
                await chatService.joinChat(streamId: stream.id, isDJ: false)
            }
        }
        .onDisappear {
            chatService.leaveChat()
        }
    }
}

#Preview {
    LiveDJStreamsView()
}