import SwiftUI

struct BlockUserView: View {
    let userId: String
    let username: String
    let profilePictureUrl: String?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var blockingService = BlockingService.shared
    @State private var selectedReason: BlockReason = .harassment
    @State private var isBlocking = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        // User Profile
                        VStack(spacing: 12) {
                            if let profileUrl = profilePictureUrl, let url = URL(string: profileUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(String(username.prefix(1)).uppercased())
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            Text("@\(username)")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // Warning Icon
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("Block User")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Blocking @\(username) will prevent them from:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // What blocking does
                    VStack(alignment: .leading, spacing: 12) {
                        BlockingFeatureRow(
                            icon: "message.slash",
                            title: "Messaging you",
                            description: "They won't be able to send you direct messages"
                        )
                        
                        BlockingFeatureRow(
                            icon: "eye.slash",
                            title: "Seeing your content",
                            description: "Your reviews, posts, and activity will be hidden from them"
                        )
                        
                        BlockingFeatureRow(
                            icon: "person.crop.circle.badge.minus",
                            title: "Joining your parties",
                            description: "They won't be able to join parties you host"
                        )
                        
                        BlockingFeatureRow(
                            icon: "bubble.left.and.bubble.right.slash",
                            title: "Commenting on your posts",
                            description: "They won't be able to comment on your reviews or posts"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Reason Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Why are you blocking this user?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(BlockReason.allCases, id: \.self) { reason in
                                BlockReasonCard(
                                    reason: reason,
                                    isSelected: selectedReason == reason
                                ) {
                                    selectedReason = reason
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Warning
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Important")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        
                        Text("You can unblock users at any time in your settings. Blocking is mutual - you won't see their content either.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Error/Success Messages
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                    }
                    
                    if showSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("User blocked successfully")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100) // Space for button
            }
            .navigationTitle("Block User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                // Block Button
                Button(action: blockUser) {
                    HStack {
                        if isBlocking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "hand.raised.fill")
                        }
                        Text(isBlocking ? "Blocking..." : "Block User")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isBlocking || showSuccess)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )
            }
        }
    }
    
    private func blockUser() {
        isBlocking = true
        errorMessage = nil
        
        Task {
            let success = await blockingService.blockUser(
                userId: userId,
                username: username,
                reason: selectedReason
            )
            
            await MainActor.run {
                isBlocking = false
                
                if success {
                    showSuccess = true
                    
                    // Auto-dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                } else {
                    errorMessage = "Failed to block user. Please try again."
                }
            }
        }
    }
}

struct BlockingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct BlockReasonCard: View {
    let reason: BlockReason
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(reason.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .red : .gray)
                        .font(.title2)
                }
                
                Text(reason.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.red.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Block User Button Component

struct BlockUserButton: View {
    let userId: String
    let username: String
    let profilePictureUrl: String?
    
    @StateObject private var blockingService = BlockingService.shared
    @State private var showBlockSheet = false
    
    var body: some View {
        if blockingService.isUserBlocked(userId) {
            // Show unblock button if already blocked
            Button(action: {
                Task {
                    await blockingService.unblockUser(userId: userId)
                }
            }) {
                Label("Unblock", systemImage: "hand.raised.slash")
                    .foregroundColor(.green)
            }
        } else {
            // Show block button
            Button(action: {
                showBlockSheet = true
            }) {
                Label("Block User", systemImage: "hand.raised")
                    .foregroundColor(.red)
            }
            .sheet(isPresented: $showBlockSheet) {
                BlockUserView(
                    userId: userId,
                    username: username,
                    profilePictureUrl: profilePictureUrl
                )
            }
        }
    }
}

#Preview {
    BlockUserView(
        userId: "test-user-id",
        username: "testuser",
        profilePictureUrl: nil
    )
}
