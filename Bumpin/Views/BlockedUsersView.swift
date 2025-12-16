import SwiftUI

struct BlockedUsersView: View {
    @StateObject private var blockedService = BlockedUsersService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showUnblockConfirmation: BlockedUsersService.BlockedUser?
    
    var body: some View {
        Group {
            if blockedService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if blockedService.blockedUsers.isEmpty {
                emptyState
            } else {
                blockedUsersList
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Refresh blocked users list when view appears
            Task {
                await blockedService.loadBlockedUsers()
            }
        }
        .confirmationDialog(
            "Unblock User?",
            isPresented: Binding(
                get: { showUnblockConfirmation != nil },
                set: { if !$0 { showUnblockConfirmation = nil } }
            ),
            presenting: showUnblockConfirmation
        ) { user in
            Button("Unblock \(user.displayName)", role: .destructive) {
                Task {
                    await blockedService.unblockUser(user.id)
                    showUnblockConfirmation = nil
                }
            }
            Button("Cancel", role: .cancel) {
                showUnblockConfirmation = nil
            }
        } message: { user in
            Text("This user will be able to see your profile and interact with you again.")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.slash.fill")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Blocked Users")
                .font(.headline)
            
            Text("Users you block will appear here. They won't be able to see your profile or contact you.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var blockedUsersList: some View {
        List {
            Section(
                header: Text("Blocked Users (\(blockedService.blockedUsers.count))"),
                footer: Text("Blocked users cannot see your profile, posts, or send you messages.")
            ) {
                ForEach(blockedService.blockedUsers) { user in
                    HStack(spacing: 12) {
                        // Profile Picture
                        if let urlString = user.profilePictureURL,
                           let url = URL(string: urlString) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                                .frame(width: 40, height: 40)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Blocked \(user.blockedAt, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showUnblockConfirmation = user
                        }) {
                            Text("Unblock")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

