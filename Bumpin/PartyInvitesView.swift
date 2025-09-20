import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PartyInvite: Identifiable, Codable {
    var id: String { inviteId }
    let inviteId: String
    let partyId: String
    let partyName: String
    let hostId: String
    let hostName: String
    let timestamp: Date?
}

struct PartyInvitesView: View {
    @State private var invites: [PartyInvite] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentUserId: String? = Auth.auth().currentUser?.uid
    @State private var selectedInvite: PartyInvite? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Party Invites")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                if isLoading {
                    ProgressView()
                        .padding()
                }
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                if invites.isEmpty && !isLoading {
                    Text("No pending invites.")
                        .foregroundColor(.secondary)
                        .padding()
                }
                List(invites) { invite in
                    Button(action: { selectedInvite = invite }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(invite.partyName)
                                .font(.headline)
                            Text("From: \(invite.hostName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let date = invite.timestamp {
                                Text("Invited: \(date.formatted(.dateTime.month().day().hour().minute()))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Invites")
            .onAppear(perform: loadInvites)
            .sheet(item: $selectedInvite) { invite in
                VStack(spacing: 24) {
                    Text("Join \(invite.partyName)?")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Invited by \(invite.hostName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Join Party") {
                        // Join party logic can be implemented here
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    Button("Dismiss") {
                        selectedInvite = nil
                    }
                    .foregroundColor(.red)
                }
                .padding()
            }
        }
    }
    
    private func loadInvites() {
        guard let currentUserId else { return }
        isLoading = true
        errorMessage = nil
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).collection("partyInvites").order(by: "timestamp", descending: true).getDocuments { snapshot, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            if let docs = snapshot?.documents {
                invites = docs.compactMap { doc in
                    let data = doc.data()
                    return PartyInvite(
                        inviteId: doc.documentID,
                        partyId: data["partyId"] as? String ?? "",
                        partyName: data["partyName"] as? String ?? "",
                        hostId: data["hostId"] as? String ?? "",
                        hostName: data["hostName"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue()
                    )
                }
            } else {
                invites = []
            }
        }
    }
} 