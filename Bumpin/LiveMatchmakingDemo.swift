import SwiftUI
import FirebaseAuth

// MARK: - Live Matchmaking Demo

struct LiveMatchmakingDemo: View {
    @State private var showingDemoConversation = false
    @State private var selectedDemo: DemoType = .weeklyMatch
    @State private var animateMessage = false
    
    enum DemoType: String, CaseIterable {
        case weeklyMatch = "Weekly Match"
        case conversation = "Full Conversation"
        case userFlow = "User Journey"
        
        var icon: String {
            switch self {
            case .weeklyMatch: return "heart.text.square.fill"
            case .conversation: return "message.fill"
            case .userFlow: return "arrow.right.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Demo header
                    demoHeader
                    
                    // Demo type selector
                    demoTypeSelector
                    
                    // Main demo content
                    mainDemoContent
                    
                    // Interactive elements
                    interactiveSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("Live Demo")
            .navigationBarTitleDisplayMode(.large)
        .onAppear {
            print("🎭 LiveMatchmakingDemo appeared - starting animations")
            // Start animation after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    animateMessage = true
                }
            }
        }
        }
        .sheet(isPresented: $showingDemoConversation) {
            LiveDemoConversationView()
        }
    }
    
    // MARK: - Demo Header
    
    private var demoHeader: some View {
        VStack(spacing: 16) {
            // Animated bot avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(animateMessage ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateMessage)
                
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(animateMessage ? 5 : -5))
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateMessage)
            }
            
            VStack(spacing: 8) {
                Text("Music Matchmaking Bot")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Live Interactive Demo")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("See exactly how users will experience magical music connections")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Demo Type Selector
    
    private var demoTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Demo Experience")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                ForEach(DemoType.allCases, id: \.self) { type in
                    DemoTypeButton(
                        type: type,
                        isSelected: selectedDemo == type,
                        action: { 
                            withAnimation(.spring()) {
                                selectedDemo = type
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Main Demo Content
    
    @ViewBuilder
    private var mainDemoContent: some View {
        switch selectedDemo {
        case .weeklyMatch:
            weeklyMatchDemo
        case .conversation:
            conversationDemo
        case .userFlow:
            userFlowDemo
        }
    }
    
    // MARK: - Weekly Match Demo
    
    private var weeklyMatchDemo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📱 How It Appears in Messages")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Simulated Messages list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Messages")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Segmented control
                HStack {
                    Text("Inbox")
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    
                    Text("Requests")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Bot conversation (animated)
                HStack(spacing: 12) {
                    // Bot avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                        
                        // Bot badge
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 18, y: -18)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Music Matchmaking Bot")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("BOT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            Text("Just now")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("🎵 You've got a new music match! Meet Alex...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .scaleEffect(animateMessage ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateMessage)
                
                // Regular conversations
                VStack(spacing: 8) {
                    ConversationRow(
                        initial: "SC",
                        name: "Sarah Chen",
                        message: "That playlist you shared is amazing! 🎵",
                        time: "2m",
                        color: .green
                    )
                    
                    ConversationRow(
                        initial: "AJ",
                        name: "Alex Johnson",
                        message: "Thanks for the concert rec!",
                        time: "1h",
                        color: .blue
                    )
                }
                .padding(.top, 8)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Conversation Demo
    
    private var conversationDemo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💬 Full Bot Conversation")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: { showingDemoConversation = true }) {
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                    
                    Text("Open Live Conversation Demo")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Experience the full bot conversation with rich match details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - User Flow Demo
    
    private var userFlowDemo: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎯 Complete User Journey")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                UserFlowStep(
                    number: 1,
                    title: "User Opts In",
                    description: "Settings → Music Matchmaking → Enable",
                    icon: "gearshape.fill",
                    color: .blue
                )
                
                UserFlowStep(
                    number: 2,
                    title: "Set Preferences",
                    description: "Choose gender identity and dating preferences",
                    icon: "heart.fill",
                    color: .pink
                )
                
                UserFlowStep(
                    number: 3,
                    title: "Weekly Match",
                    description: "Every Thursday 1 PM - Bot sends perfect match",
                    icon: "calendar.badge.clock",
                    color: .orange
                )
                
                UserFlowStep(
                    number: 4,
                    title: "Rich Match Details",
                    description: "Compatibility score + shared music interests",
                    icon: "music.note.list",
                    color: .purple
                )
                
                UserFlowStep(
                    number: 5,
                    title: "Instant Connection",
                    description: "View Profile or Say Hi - start chatting!",
                    icon: "message.fill",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Interactive Section
    
    private var interactiveSection: some View {
        VStack(spacing: 16) {
            Text("🎮 Interactive Elements")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Animated compatibility score
                HStack {
                    Text("Live Compatibility Calculation:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .foregroundColor(.purple)
                        
                        Text("\(Int.random(in: 75...95))%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                                // Triggers view refresh for random number
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Sample action buttons
                HStack(spacing: 12) {
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle")
                            Text("View Profile")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(20)
                    }
                    
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "message")
                            Text("Say Hi")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct DemoTypeButton: View {
    let type: LiveMatchmakingDemo.DemoType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .purple)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.purple : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ConversationRow: View {
    let initial: String
    let name: String
    let message: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initial)
                        .font(.headline)
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct UserFlowStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.subheadline)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Live Demo Conversation View

struct LiveDemoConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [DemoMessage] = []
    @State private var currentMessageIndex = 0
    @State private var showTypingIndicator = false
    
    struct DemoMessage {
        let id = UUID()
        let isBot: Bool
        let content: DemoMessageContent
        let delay: Double
        
        enum DemoMessageContent {
            case text(String)
            case match(name: String, username: String, similarity: Double, artists: [String], genres: [String])
            case typing
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Bot header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Music Matchmaking Bot")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Your weekly music matches")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text("BOT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(messages, id: \.id) { message in
                                DemoMessageView(message: message)
                                    .id(message.id)
                            }
                            
                            if showTypingIndicator {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input (disabled for demo)
                HStack(spacing: 8) {
                    TextField("Message...", text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    
                    Button("Send") { }
                        .disabled(true)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .navigationTitle("Live Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Restart") { startDemo() }
                }
            }
        }
        .onAppear {
            startDemo()
        }
    }
    
    private func startDemo() {
        messages = []
        currentMessageIndex = 0
        showTypingIndicator = false
        
        let demoMessages: [DemoMessage] = [
            DemoMessage(isBot: true, content: .text("👋 Welcome! I'm your Music Matchmaking Bot. I help connect people through their shared love of music."), delay: 1.0),
            DemoMessage(isBot: true, content: .text("🎵 I've found someone special who shares your incredible music taste..."), delay: 3.0),
            DemoMessage(isBot: true, content: .match(
                name: "Alex Johnson",
                username: "alexmusic",
                similarity: 0.87,
                artists: ["Taylor Swift", "The Weeknd", "Billie Eilish"],
                genres: ["Pop", "Alternative", "R&B"]
            ), delay: 2.0),
            DemoMessage(isBot: true, content: .text("You both gave 'Anti-Hero' by Taylor Swift a 5-star rating! That's a perfect conversation starter 🌟"), delay: 4.0)
        ]
        
        animateMessages(demoMessages)
    }
    
    private func animateMessages(_ demoMessages: [DemoMessage]) {
        guard currentMessageIndex < demoMessages.count else { return }
        
        let message = demoMessages[currentMessageIndex]
        
        // Show typing indicator
        showTypingIndicator = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + message.delay) {
            showTypingIndicator = false
            
            withAnimation(.easeInOut(duration: 0.3)) {
                messages.append(message)
            }
            
            currentMessageIndex += 1
            
            // Continue with next message
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animateMessages(demoMessages)
            }
        }
    }
}

struct DemoMessageView: View {
    let message: LiveDemoConversationView.DemoMessage
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                // Bot header
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundColor(.purple)
                        .font(.caption)
                    
                    Text("Music Matchmaking Bot")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Text(Date(), style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Message content
                switch message.content {
                case .text(let text):
                    Text(text)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                
                case .match(let name, let username, let similarity, let artists, let genres):
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🎵 You've got a new music match!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        // Match card
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text(name.prefix(1).uppercased())
                                            .font(.headline)
                                            .foregroundColor(.purple)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("@\(username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "waveform")
                                            .font(.caption2)
                                            .foregroundColor(.purple)
                                        
                                        Text("\(Int(similarity * 100))% music match")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                            .fontWeight(.medium)
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            // Shared interests
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "music.note")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                    
                                    Text("What you have in common:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Artists:")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                        Spacer()
                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(artists, id: \.self) { artist in
                                                Text(artist)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue.opacity(0.1))
                                                    .foregroundColor(.blue)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                    
                                    HStack {
                                        Text("Genres:")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                        Spacer()
                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(genres, id: \.self) { genre in
                                                Text(genre)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.green.opacity(0.1))
                                                    .foregroundColor(.green)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Action buttons
                            HStack(spacing: 12) {
                                Button(action: {}) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.circle")
                                            .font(.caption)
                                        Text("View Profile")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(16)
                                }
                                
                                Button(action: {}) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "message")
                                            .font(.caption)
                                        Text("Say Hi")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.purple)
                                    .cornerRadius(16)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                
                case .typing:
                    TypingIndicator()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.purple.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 320, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.purple.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
            
            Text("typing...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Preview

#Preview {
    LiveMatchmakingDemo()
}
