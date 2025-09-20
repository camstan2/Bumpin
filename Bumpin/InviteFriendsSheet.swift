import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct InviteFriendsSheet: View {
    let partyId: String?
    let partyName: String?
    @State private var friends: [UserProfile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedToInvite: Set<String> = []
    @State private var currentUserId: String? = Auth.auth().currentUser?.uid
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Invite Friends")
                    .font(.title2)
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
                List(friends) { friend in
                    HStack {
                        if let url = friend.profilePictureUrl, let imageUrl = URL(string: url) {
                            AsyncImage(url: imageUrl) { phase in
                                if let img = phase.image {
                                    img.resizable().scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.circle")
                                        .resizable().scaledToFit()
                                        .foregroundColor(.purple.opacity(0.5))
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle")
                                .resizable().scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.purple.opacity(0.5))
                        }
                        VStack(alignment: .leading) {
                            Text(friend.displayName)
                                .font(.headline)
                            Text("@\(friend.username)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            if selectedToInvite.contains(friend.uid) {
                                selectedToInvite.remove(friend.uid)
                            } else {
                                selectedToInvite.insert(friend.uid)
                            }
                        }) {
                            Image(systemName: selectedToInvite.contains(friend.uid) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedToInvite.contains(friend.uid) ? .purple : .gray)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                Button("Invite Selected") {
                    sendInvites()
                }
                .disabled(selectedToInvite.isEmpty)
                .padding()
            }
            .navigationTitle("Invite Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let partyId = partyId {
                        Menu {
                            Button("Copy code") {
                                UIPasteboard.general.string = partyId
                                AnalyticsService.shared.logTap(category: "party_code_copy", id: partyId)
                            }
                            Button("Share link") {
                                let url = DeepLinkParser.buildInviteURL(forCode: partyId) ?? URL(string: "https://example.com/join/\(partyId)")!
                                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let root = scene.windows.first?.rootViewController {
                                    root.present(av, animated: true)
                                }
                                AnalyticsService.shared.logTap(category: "party_invite_share", id: partyId)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share invite")
                    }
                }
            }
            .onAppear(perform: loadFriends)
        }
    }
    
    private func loadFriends() {
        guard let currentUserId else { return }
        isLoading = true
        errorMessage = nil
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).getDocument { snapshot, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            guard let data = snapshot?.data(), let following = data["following"] as? [String], !following.isEmpty else {
                friends = []
                return
            }
            db.collection("users").whereField("uid", in: following).getDocuments { snap, err in
                if let docs = snap?.documents {
                    friends = docs.compactMap { try? $0.data(as: UserProfile.self) }
                } else {
                    friends = []
                }
            }
        }
    }
    
    private func sendInvites() {
        guard let currentUserId, let partyId = partyId, let partyName = partyName else { return }
        let db = Firestore.firestore()
        let hostName = Auth.auth().currentUser?.displayName ?? ""
        let inviteData: [String: Any] = [
            "partyId": partyId,
            "partyName": partyName,
            "hostId": currentUserId,
            "hostName": hostName,
            "timestamp": FieldValue.serverTimestamp()
        ]
        let notificationData: [String: Any] = [
            "type": "party_invite",
            "partyId": partyId,
            "partyName": partyName,
            "hostId": currentUserId,
            "hostName": hostName,
            "timestamp": FieldValue.serverTimestamp()
        ]
        for uid in selectedToInvite {
            db.collection("users").document(uid).collection("partyInvites").addDocument(data: inviteData)
            db.collection("users").document(uid).collection("notifications").addDocument(data: notificationData)
        }
        presentationMode.wrappedValue.dismiss()
    }
} 