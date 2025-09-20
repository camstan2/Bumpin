import SwiftUI

struct PartyCreationVotingView: View {
    let chat: TopicChat
    @ObservedObject var viewModel: UnifiedDiscussionViewModel
    let onPartyCreated: (Party) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var hasVoted = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Create a Party?")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Turn this discussion into a music party where everyone can listen together")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Voting Progress
                VStack(spacing: 16) {
                    HStack {
                        Text("Votes Needed")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.currentVotes)/\(viewModel.requiredVotes)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                    
                    ProgressView(value: Double(viewModel.currentVotes), total: Double(viewModel.requiredVotes))
                        .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                        .scaleEffect(y: 2)
                    
                    HStack {
                        Text("Time Remaining")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.votingTimeRemaining)s")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(viewModel.votingTimeRemaining <= 10 ? .red : .secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Participants and their votes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Participants")
                        .font(.headline)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(chat.participants, id: \.id) { participant in
                            ParticipantVoteRowView(
                                participant: participant,
                                hasVoted: false // This would come from Firestore in real implementation
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Vote Buttons
                VStack(spacing: 12) {
                    if !hasVoted {
                        Button {
                            viewModel.voteForParty()
                            hasVoted = true
                            HapticFeedback.matchFound()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Vote Yes")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            hasVoted = true
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Vote No")
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("You voted!")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationTitle("Party Vote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: viewModel.currentVotes) { _, newValue in
            if newValue >= viewModel.requiredVotes {
                // Voting passed!
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    dismiss()
                }
            }
        }
    }
}

struct ParticipantVoteRowView: View {
    let participant: TopicParticipant
    let hasVoted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.purple)
                        .font(.caption)
                )
            
            Text(participant.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if participant.isHost {
                Text("HOST")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            if hasVoted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "clock.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    let mockChat = TopicChat(
        title: "Music Discussion",
        description: "Talk about your favorite artists",
        category: .music,
        hostId: "host1",
        hostName: "Sarah"
    )
    
    let mockViewModel = UnifiedDiscussionViewModel()
    
    PartyCreationVotingView(
        chat: mockChat,
        viewModel: mockViewModel,
        onPartyCreated: { _ in }
    )
}
