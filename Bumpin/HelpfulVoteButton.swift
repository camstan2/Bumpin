import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HelpfulVoteButton: View {
    let logId: String
    @State private var userVote: ReviewHelpfulVote?
    @State private var helpfulCount: Int = 0
    @State private var unhelpfulCount: Int = 0
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Helpful button
            Button(action: { voteHelpful() }) {
                HStack(spacing: 4) {
                    Image(systemName: userVote?.isHelpful == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(userVote?.isHelpful == true ? .green : .secondary)
                        .symbolEffect(.bounce, value: userVote?.isHelpful == true)
                    Text("\(helpfulCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .scaleEffect(userVote?.isHelpful == true ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: userVote?.isHelpful)
            .animation(.smooth, value: helpfulCount)
            .disabled(isLoading)
            
            // Unhelpful button
            Button(action: { voteUnhelpful() }) {
                HStack(spacing: 4) {
                    Image(systemName: userVote?.isHelpful == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundColor(userVote?.isHelpful == false ? .red : .secondary)
                        .symbolEffect(.bounce, value: userVote?.isHelpful == false)
                    Text("\(unhelpfulCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .scaleEffect(userVote?.isHelpful == false ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: userVote?.isHelpful)
            .animation(.smooth, value: unhelpfulCount)
            .disabled(isLoading)
        }
        .onAppear {
            loadVoteData()
        }
    }
    
    private func voteHelpful() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Haptic feedback
        LogEngagementHaptics.helpful()
        
        isLoading = true
        
        ReviewHelpfulVote.updateVote(logId: logId, userId: userId, isHelpful: true) { error in
            DispatchQueue.main.async {
                isLoading = false
                if error == nil {
                    loadVoteData()
                }
            }
        }
    }
    
    private func voteUnhelpful() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Haptic feedback
        LogEngagementHaptics.unhelpful()
        
        isLoading = true
        
        ReviewHelpfulVote.updateVote(logId: logId, userId: userId, isHelpful: false) { error in
            DispatchQueue.main.async {
                isLoading = false
                if error == nil {
                    loadVoteData()
                }
            }
        }
    }
    
    private func loadVoteData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Load user's vote
        ReviewHelpfulVote.getUserVote(logId: logId, userId: userId) { vote, error in
            DispatchQueue.main.async {
                if let vote = vote {
                    self.userVote = vote
                }
            }
        }
        
        // Load counts directly from the log document
        let db = Firestore.firestore()
        db.collection("logs").document(logId).getDocument { document, error in
            DispatchQueue.main.async {
                if let data = document?.data() {
                    self.helpfulCount = data["helpfulCount"] as? Int ?? 0
                    self.unhelpfulCount = data["unhelpfulCount"] as? Int ?? 0
                }
            }
        }
    }
}

#if DEBUG
struct HelpfulVoteButton_Previews: PreviewProvider {
    static var previews: some View {
        HelpfulVoteButton(logId: "preview-log-id")
    }
}
#endif 