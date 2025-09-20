import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class MusicLetterboxViewModel: ObservableObject {
    @Published var inboxShares: [MusicShare] = []
    @Published var outboxShares: [MusicShare] = []
    @Published var isLoadingInbox = false
    @Published var isLoadingOutbox = false
    @Published var errorMessage: String?
    @Published var selectedShare: MusicShare?
    @Published var showShareSheet = false
    @Published var showInbox = true // Toggle between inbox and outbox
    
    private var inboxListener: ListenerRegistration?
    private var outboxListener: ListenerRegistration?
    private var currentUserId: String?
    
    init() {
        currentUserId = Auth.auth().currentUser?.uid
        setupListeners()
    }
    
    private func setupListeners() {
        guard let userId = currentUserId else { return }
        
        // Listen for inbox updates
        let db = Firestore.firestore()
        inboxListener = db.collection("music_shares")
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.inboxShares = snapshot?.documents.compactMap { try? $0.data(as: MusicShare.self) } ?? []
                }
            }
        
        // Listen for outbox updates
        outboxListener = db.collection("music_shares")
            .whereField("senderId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.outboxShares = snapshot?.documents.compactMap { try? $0.data(as: MusicShare.self) } ?? []
                }
            }
    }
    
    func shareMusic(with recipientId: String, recipientName: String, recipientUsername: String,
                   musicItemId: String, musicItemType: String, musicTitle: String, musicArtist: String,
                   musicArtworkUrl: String?, message: String?) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let share = MusicShare(
            senderId: currentUser.uid,
            senderName: currentUser.displayName ?? "Unknown",
            senderUsername: "", // Will be fetched from user profile
            senderProfilePictureUrl: nil, // Will be fetched from user profile
            recipientId: recipientId,
            recipientName: recipientName,
            recipientUsername: recipientUsername,
            musicItemId: musicItemId,
            musicItemType: musicItemType,
            musicTitle: musicTitle,
            musicArtist: musicArtist,
            musicArtworkUrl: musicArtworkUrl,
            message: message
        )
        
        // Fetch sender's profile info and update the share
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let data = snapshot?.data() {
                var updatedShare = share
                updatedShare.senderUsername = data["username"] as? String ?? ""
                updatedShare.senderProfilePictureUrl = data["profilePictureUrl"] as? String
                
                MusicShare.createShare(updatedShare) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = error.localizedDescription
                        } else {
                            self.showShareSheet = false
                        }
                    }
                }
            } else {
                // Create share without profile info
                MusicShare.createShare(share) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = error.localizedDescription
                        } else {
                            self.showShareSheet = false
                        }
                    }
                }
            }
        }
    }
    
    func markShareAsRead(_ share: MusicShare) {
        MusicShare.markAsRead(shareId: share.id) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func toggleLike(_ share: MusicShare) {
        guard let userId = currentUserId else { return }
        MusicShare.toggleLike(shareId: share.id, userId: userId) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func deleteShare(_ share: MusicShare) {
        MusicShare.deleteShare(shareId: share.id) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    var unreadCount: Int {
        inboxShares.filter { !$0.isRead }.count
    }
    
    var currentShares: [MusicShare] {
        showInbox ? inboxShares : outboxShares
    }
    
    var isLoading: Bool {
        showInbox ? isLoadingInbox : isLoadingOutbox
    }
    
    deinit {
        inboxListener?.remove()
        outboxListener?.remove()
    }
} 