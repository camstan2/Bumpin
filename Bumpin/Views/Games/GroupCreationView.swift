import SwiftUI
import FirebaseAuth

struct GroupCreationView: View {
    let gameType: GameType
    let onGroupCreated: (PlayerGroup) -> Void
    let onCancel: () -> Void
    
    @StateObject private var gameService = GameService.shared
    @State private var friends: [Friend] = []
    @State private var selectedFriends: Set<String> = []
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                
                if isLoading {
                    ProgressView("Loading friends...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    friendsSelectionSection
                }
                
                Spacer()
                
                createGroupButton
            }
            .padding()
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .onAppear {
            loadFriends()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: gameType.iconName)
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Create \(gameType.displayName) Group")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Invite friends to join your group before queuing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var friendsSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Friends")
                    .font(.headline)
                
                Spacer()
                
                Text("\(selectedFriends.count)/\(gameType.maxPlayers - 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if friends.isEmpty {
                emptyFriendsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(friends, id: \.id) { friend in
                            friendRow(friend)
                        }
                    }
                }
            }
        }
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Friends Found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("You can still create a group and queue solo, or add friends later")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func friendRow(_ friend: Friend) -> some View {
        HStack {
            // Profile image placeholder
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(friend.name.prefix(1)))
                        .font(.headline)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Online") // TODO: Get real status
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button(action: {
                toggleFriendSelection(friend)
            }) {
                Image(systemName: selectedFriends.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(selectedFriends.contains(friend.id) ? .blue : .gray)
            }
            .disabled(selectedFriends.count >= gameType.maxPlayers - 1 && !selectedFriends.contains(friend.id))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var createGroupButton: some View {
        Button(action: createGroup) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "person.2.fill")
                }
                
                Text(selectedFriends.isEmpty ? "Create Solo Group" : "Create Group & Send Invites")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
    }
    
    private func toggleFriendSelection(_ friend: Friend) {
        if selectedFriends.contains(friend.id) {
            selectedFriends.remove(friend.id)
        } else if selectedFriends.count < gameType.maxPlayers - 1 {
            selectedFriends.insert(friend.id)
        }
    }
    
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        // TODO: Replace with actual friend loading logic
        // For now, use mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.friends = [
                Friend(id: "friend1", name: "Alex Johnson"),
                Friend(id: "friend2", name: "Sarah Wilson"),
                Friend(id: "friend3", name: "Mike Chen"),
                Friend(id: "friend4", name: "Emma Davis"),
                Friend(id: "friend5", name: "Ryan Taylor")
            ]
            self.isLoading = false
        }
    }
    
    private func createGroup() {
        Task {
            do {
                isLoading = true
                
                // Create the group
                let group = try await gameService.createPlayerGroup(gameType: gameType)
                
                // Send invites to selected friends
                for friendId in selectedFriends {
                    if let friend = friends.first(where: { $0.id == friendId }) {
                        try await gameService.inviteFriendToGroup(friendId, friendName: friend.name)
                    }
                }
                
                await MainActor.run {
                    onGroupCreated(group)
                }
                
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    GroupCreationView(
        gameType: .imposter,
        onGroupCreated: { _ in },
        onCancel: { }
    )
}
