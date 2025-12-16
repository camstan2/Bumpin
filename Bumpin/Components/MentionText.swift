import SwiftUI
import FirebaseFirestore

// MARK: - Mention Text View

/// A view that displays text with tappable @mentions in purple
struct MentionText: View {
    let text: String
    let font: Font
    let color: Color
    let mentionColor: Color
    let onMentionTap: (String) -> Void
    
    init(
        _ text: String,
        font: Font = .body,
        color: Color = .primary,
        mentionColor: Color = .purple,
        onMentionTap: @escaping (String) -> Void = { _ in }
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.mentionColor = mentionColor
        self.onMentionTap = onMentionTap
    }
    
    var body: some View {
        let components = parseText()
        
        components.reduce(Text("")) { result, component in
            switch component {
            case .text(let str):
                return result + Text(str)
                    .font(font)
                    .foregroundColor(color)
            case .mention(let username):
                return result + Text("@\(username)")
                    .font(font)
                    .foregroundColor(mentionColor)
                    .underline()
            }
        }
    }
    
    private func parseText() -> [TextComponent] {
        var components: [TextComponent] = []
        let pattern = "@([a-zA-Z0-9_]+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        var lastIndex = text.startIndex
        
        for match in matches {
            // Add text before mention
            if let matchRange = Range(match.range, in: text) {
                if lastIndex < matchRange.lowerBound {
                    let textBefore = String(text[lastIndex..<matchRange.lowerBound])
                    components.append(.text(textBefore))
                }
                
                // Add mention
                if let usernameRange = Range(match.range(at: 1), in: text) {
                    let username = String(text[usernameRange])
                    components.append(.mention(username))
                }
                
                lastIndex = matchRange.upperBound
            }
        }
        
        // Add remaining text
        if lastIndex < text.endIndex {
            let remainingText = String(text[lastIndex...])
            components.append(.text(remainingText))
        }
        
        return components
    }
    
    private enum TextComponent {
        case text(String)
        case mention(String)
    }
}

// MARK: - Interactive Mention Text View

/// A view that displays text with tappable @mentions that navigate to user profiles
struct InteractiveMentionText: View {
    let text: String
    let font: Font
    let color: Color
    let mentionColor: Color
    
    @State private var selectedUsername: String?
    @State private var showUserProfile = false
    @State private var selectedUserId: String?
    @Environment(\.dismiss) private var dismiss
    
    init(
        _ text: String,
        font: Font = .body,
        color: Color = .primary,
        mentionColor: Color = .purple
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.mentionColor = mentionColor
    }
    
    var body: some View {
        let components = parseText()
        
        HStack(spacing: 0) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                switch component {
                case .text(let str):
                    Text(str)
                        .font(font)
                        .foregroundColor(color)
                case .mention(let username):
                    Button(action: {
                        handleMentionTap(username: username)
                    }) {
                        Text("@\(username)")
                            .font(font)
                            .foregroundColor(mentionColor)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showUserProfile) {
            if let userId = selectedUserId {
                NavigationView {
                    UserProfileView(userId: userId, showFullProfile: false)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: { showUserProfile = false }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                }
            } else {
                // Fallback in case userId is nil
                VStack {
                    ProgressView()
                    Text("Loading profile...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func handleMentionTap(username: String) {
        selectedUsername = username
        print("🔍 [MentionTap] Tapped on username: '\(username)' (length: \(username.count))")
        
        // Remove @ if it's included in the username (defensive)
        let cleanUsername = username.hasPrefix("@") ? String(username.dropFirst()) : username
        print("🔍 [MentionTap] Clean username: '\(cleanUsername)'")
        
        // Fetch user ID for username
        Task {
            let db = Firestore.firestore()
            do {
                print("🔍 [MentionTap] Querying Firestore for username: '\(cleanUsername)'...")
                let snapshot = try await db.collection("users")
                    .whereField("username", isEqualTo: cleanUsername)
                    .limit(to: 1)
                    .getDocuments()
                
                print("🔍 [MentionTap] Query returned \(snapshot.documents.count) documents")
                
                if let doc = snapshot.documents.first {
                    print("✅ [MentionTap] Found user ID: \(doc.documentID)")
                    if let foundUsername = doc.data()["username"] as? String {
                        print("✅ [MentionTap] Confirmed username from Firestore: '\(foundUsername)'")
                    }
                    await MainActor.run {
                        selectedUserId = doc.documentID
                        showUserProfile = true
                        print("✅ [MentionTap] Showing user profile")
                    }
                } else {
                    print("❌ [MentionTap] No user found with username: '\(cleanUsername)'")
                }
            } catch {
                print("❌ [MentionTap] Error fetching user profile for '\(cleanUsername)': \(error)")
            }
        }
    }
    
    private func parseText() -> [TextComponent] {
        var components: [TextComponent] = []
        let pattern = "@([a-zA-Z0-9_]+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        var lastIndex = text.startIndex
        
        for match in matches {
            // Add text before mention
            if let matchRange = Range(match.range, in: text) {
                if lastIndex < matchRange.lowerBound {
                    let textBefore = String(text[lastIndex..<matchRange.lowerBound])
                    components.append(.text(textBefore))
                }
                
                // Add mention
                if let usernameRange = Range(match.range(at: 1), in: text) {
                    let username = String(text[usernameRange])
                    components.append(.mention(username))
                }
                
                lastIndex = matchRange.upperBound
            }
        }
        
        // Add remaining text
        if lastIndex < text.endIndex {
            let remainingText = String(text[lastIndex...])
            components.append(.text(remainingText))
        }
        
        return components
    }
    
    private enum TextComponent {
        case text(String)
        case mention(String)
    }
}

