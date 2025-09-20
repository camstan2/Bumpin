import SwiftUI
import FirebaseAuth

struct InviteFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RandomChatViewModel
    @State private var searchText = ""
    
    private var filteredFriends: [RandomChatFriend] {
        if searchText.isEmpty {
            return viewModel.friends
        }
        return viewModel.friends.filter { friend in
            friend.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredFriends) { friend in
                        RandomChatFriendRowView(friend: friend, viewModel: viewModel)
                    }
                } header: {
                    Text("Select Friends")
                } footer: {
                    Text("Invite \(viewModel.groupSize - 1) friend\(viewModel.groupSize > 2 ? "s" : "") to join your group")
                }
                
                Section {
                    Button {
                        viewModel.startGroupQueue()
                        dismiss()
                    } label: {
                        HStack {
                            Text("Start Group Queue")
                                .foregroundColor(viewModel.canStartGroupQueue ? .white : .secondary)
                            if !viewModel.canStartGroupQueue {
                                Spacer()
                                Text("\(viewModel.acceptedFriendsCount)/\(viewModel.groupSize - 1)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.canStartGroupQueue)
                    .listRowBackground(viewModel.canStartGroupQueue ? Color.purple : Color(.systemGray5))
                }
            }
            .searchable(text: $searchText, prompt: "Search friends")
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct RandomChatFriendRowView: View {
    let friend: RandomChatFriend
    @ObservedObject var viewModel: RandomChatViewModel
    
    var body: some View {
        HStack {
            // Avatar (placeholder)
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                )
            
            // Friend info
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .fontWeight(.medium)
                Text(friend.status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Invite status
            if friend.isInvited {
                if friend.hasAccepted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("Pending")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            } else {
                Button {
                    viewModel.inviteFriend(friend)
                } label: {
                    Text("Invite")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
