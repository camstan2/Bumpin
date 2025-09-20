import SwiftUI

struct BlockedUsersView: View {
    @StateObject private var blockingService = BlockingService.shared
    @State private var blockedUsers: [BlockedUserInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedUser: BlockedUserInfo?
    @State private var showUnblockConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading blocked users...")
                        .padding()
                } else if blockedUsers.isEmpty {
                    emptyStateView
                } else {
                    blockedUsersList
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadBlockedUsers()
            }
            .refreshable {
                loadBlockedUsers()
            }
            .confirmationDialog(
                "Unblock User",
                isPresented: $showUnblockConfirmation,
                presenting: selectedUser
            ) { user in
                Button("Unblock @\(user.username)", role: .destructive) {
                    unblockUser(user)
                }
                Button("Cancel", role: .cancel) { }
            } message: { user in
                Text("Are you sure you want to unblock @\(user.username)? They will be able to interact with you again.")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Blocked Users")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Users you block will appear here. You can unblock them at any time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 60)
    }
    
    private var blockedUsersList: some View {
        List {
            ForEach(blockedUsers) { user in
                BlockedUserRow(user: user) {
                    selectedUser = user
                    showUnblockConfirmation = true
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func loadBlockedUsers() {
        isLoading = true
        errorMessage = nil
        
        Task {
            let users = await blockingService.getBlockedUsers()
            
            await MainActor.run {
                self.blockedUsers = users
                self.isLoading = false
            }
        }
    }
    
    private func unblockUser(_ user: BlockedUserInfo) {
        Task {
            let success = await blockingService.unblockUser(userId: user.userId)
            
            await MainActor.run {
                if success {
                    // Remove from local list
                    blockedUsers.removeAll { $0.userId == user.userId }
                } else {
                    errorMessage = "Failed to unblock user. Please try again."
                }
            }
        }
    }
}

struct BlockedUserRow: View {
    let user: BlockedUserInfo
    let onUnblock: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            if let profileUrl = user.profilePictureUrl, let url = URL(string: profileUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(user.username)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    if let reason = user.reason {
                        Text(reason.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    }
                    
                    Text(timeAgoString(from: user.blockedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Unblock Button
            Button(action: onUnblock) {
                Text("Unblock")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Blocked " + formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Settings Integration

struct BlockingSettingsSection: View {
    @StateObject private var blockingService = BlockingService.shared
    @State private var showBlockedUsers = false
    
    var body: some View {
        Section("Privacy & Safety") {
            Button(action: {
                showBlockedUsers = true
            }) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blocked Users")
                            .foregroundColor(.primary)
                        
                        Text("\(blockingService.blockedUsers.count) users blocked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showBlockedUsers) {
            BlockedUsersView()
        }
    }
}

#Preview {
    BlockedUsersView()
}
