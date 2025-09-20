import SwiftUI

struct MockQueueStatusView: View {
    @State private var isMatched = false
    @State private var queueTime = "0:05"
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Indicator
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: UUID())
                
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            .padding(.bottom, 8)
            
            Text("Finding your match...")
                .font(.headline)
            
            Text("Queue time: \(queueTime)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(role: .destructive) {
                // Leave queue
            } label: {
                Text("Leave Queue")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .onAppear {
            // Simulate match after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isMatched = true
                }
            }
        }
        .fullScreenCover(isPresented: $isMatched) {
            NavigationStack {
                UnifiedDiscussionView(
                    chat: createMockChat(),
                    discussionType: .randomChat,
                    onClose: {}
                )
            }
        }
    }
    
    private func createMockChat() -> TopicChat {
        var chat = TopicChat(
            title: "Random Chat",
            description: "A randomly matched conversation",
            category: .trending,
            hostId: "host1",
            hostName: "Sarah"
        )
        
        // Add mock participants
        chat.participants = [
            TopicParticipant(id: "host1", name: "Sarah", isHost: true),
            TopicParticipant(id: "user1", name: "You", isHost: false),
            TopicParticipant(id: "user2", name: "Alex", isHost: false),
            TopicParticipant(id: "user3", name: "Jordan", isHost: false)
        ]
        
        // Set up speakers
        chat.speakers = ["host1", "user1"]
        chat.listeners = ["user2", "user3"]
        chat.voiceChatActive = true
        chat.currentDiscussion = "What's your favorite music genre?"
        
        return chat
    }
}

#Preview {
    ZStack {
        Color(.systemGray6).ignoresSafeArea()
        MockQueueStatusView()
            .padding()
    }
}
