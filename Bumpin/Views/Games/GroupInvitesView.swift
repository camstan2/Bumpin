import SwiftUI

struct GroupInvitesView: View {
    @StateObject private var gameService = GameService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if gameService.groupInvites.isEmpty {
                    emptyInvitesView
                } else {
                    invitesListView
                }
            }
            .navigationTitle("Group Invites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await gameService.fetchGroupInvites()
            }
        }
    }
    
    private var emptyInvitesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.open")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Group Invites")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("When friends invite you to join their game groups, they'll appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var invitesListView: some View {
        List {
            ForEach(gameService.groupInvites) { invite in
                GroupInviteRow(invite: invite) {
                    Task {
                        await gameService.fetchGroupInvites()
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct GroupInviteRow: View {
    let invite: GroupInvite
    let onUpdate: () -> Void
    
    @StateObject private var gameService = GameService.shared
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Game type icon
                Image(systemName: invite.gameType.iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(invite.fromUserName) invited you")
                        .font(.headline)
                    
                    Text("to join \(invite.gameType.displayName) group")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(timeAgoText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if invite.isExpired {
                    Text("Expired")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            if !invite.isExpired {
                HStack(spacing: 12) {
                    Button("Decline") {
                        declineInvite()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isProcessing)
                    
                    Button("Accept") {
                        acceptInvite()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isProcessing)
                }
            }
        }
        .padding(.vertical, 8)
        .opacity(invite.isExpired ? 0.6 : 1.0)
    }
    
    private var timeAgoText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: invite.createdAt, relativeTo: Date())
    }
    
    private func acceptInvite() {
        Task {
            isProcessing = true
            
            do {
                try await gameService.acceptGroupInvite(invite)
                onUpdate()
            } catch {
                print("❌ Error accepting invite: \(error)")
            }
            
            isProcessing = false
        }
    }
    
    private func declineInvite() {
        Task {
            isProcessing = true
            
            do {
                try await gameService.declineGroupInvite(invite)
                onUpdate()
            } catch {
                print("❌ Error declining invite: \(error)")
            }
            
            isProcessing = false
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    GroupInvitesView()
}
