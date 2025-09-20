import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Simple, read-only viewer for a single MusicLog.
/// Optional `onEdit` allows callers to show an Edit action.
struct LogDetailView: View {
    let log: MusicLog
    let onEdit: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    // Comments pagination state
    @State private var comments: [ReviewComment] = []
    @State private var isLoadingComments = false
    @State private var hasMoreComments = true
    @State private var lastCommentsSnapshot: DocumentSnapshot?
    private let commentsPageSize = 25
    
    init(log: MusicLog, onEdit: (() -> Void)? = nil) {
        self.log = log
        self.onEdit = onEdit
    }

    // MARK: - Subviews
    private var artworkSection: some View {
        VStack(spacing: 24) {
            // Artwork + title
            if let url = log.artworkUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { Color.gray.opacity(0.3) }
                .frame(width: 140, height: 140)
                .cornerRadius(12)
            }

            VStack(spacing: 4) {
                Text(log.title).font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                Text(log.artistName).font(.subheadline).foregroundColor(.secondary)
            }
        }
    }
    
    private var ratingSection: some View {
        HStack(spacing: 4) {
            if Auth.auth().currentUser?.uid == log.userId {
                ForEach(1...5, id: \.self) { idx in
                    Button(action: { updateRatingInline(idx) }) {
                        Image(systemName: idx <= (log.rating ?? 0) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                ForEach(1...5, id: \.self) { idx in
                    Image(systemName: idx <= (log.rating ?? 0) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
            }
        }.font(.title3)
    }
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comments")
                    .font(.headline)
                if let count = log.commentCount, count > 0 {
                    Text("(\(count))").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(comments) { c in
                    CommentRowView(comment: c, logId: log.id, onDelete: { commentId in
                        comments.removeAll { $0.id == commentId }
                    })
                }

                if isLoadingComments {
                    ProgressView().padding(.vertical, 8)
                } else if hasMoreComments {
                    Button("Load more") { loadMoreComments() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal)
        .onAppear { if comments.isEmpty { loadMoreComments(initial: true) } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    artworkSection
                    ratingSection

                    if let review = log.review, !review.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Review").font(.headline)
                            Text(review)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }.padding(.horizontal)
                    }

                    if let date = log.dateLogged as Date? {
                        Text("Logged on \(date.formatted(.dateTime.month().day().year()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    commentsSection

                    // Composer
                    CommentComposerView(logId: log.id, onCommentSent: { new in
                        comments.append(new)
                    })
                }
                .padding()
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if let onEdit = onEdit { Button("Edit") { onEdit() } }
                    }
                }
            }
        }
    }

    private func loadMoreComments(initial: Bool = false) {
        if isLoadingComments || !hasMoreComments { return }
        isLoadingComments = true
        let db = Firestore.firestore()
        var query: Query = db.collection("logs").document(log.id)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .limit(to: commentsPageSize)
        if let lastSnap = lastCommentsSnapshot {
            query = query.start(afterDocument: lastSnap)
        }
        query.getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoadingComments = false
                if let error = error {
                    print("Failed to load comments: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                let new = docs.compactMap { try? $0.data(as: ReviewComment.self) }
                self.comments.append(contentsOf: new)
                self.lastCommentsSnapshot = docs.last
                self.hasMoreComments = new.count == self.commentsPageSize
            }
        }
    }
    
    private func updateRatingInline(_ newValue: Int) {
        guard Auth.auth().currentUser?.uid == log.userId else { return }
        var updated = log
        updated.rating = newValue
        MusicLog.updateLog(updated) { _ in }
    }
}

// MARK: - Comment Composer
// MARK: - Comment Row View
private struct CommentRowView: View {
    let comment: ReviewComment
    let logId: String
    let onDelete: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let urlStr = comment.userProfilePictureUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.gray.opacity(0.2) }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    Circle().fill(Color.gray.opacity(0.25)).frame(width: 28, height: 28)
                }
                Text(comment.username)
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(comment.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if Auth.auth().currentUser?.uid == comment.userId {
                    Menu {
                        Button(role: .destructive) {
                            ReviewComment.deleteComment(logId: logId, commentId: comment.id) { err in
                                DispatchQueue.main.async {
                                    if err == nil {
                                        AnalyticsService.shared.logComments(action: "delete", contentId: logId)
                                        onDelete(comment.id)
                                    }
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
            Text(comment.text)
                .font(.body)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Comment Composer View
private struct CommentComposerView: View {
    let logId: String
    var onCommentSent: (ReviewComment) -> Void
    @State private var text: String = ""
    @State private var isSending = false
    @State private var showMentionBar = false
    @State private var candidates: [Friend] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showMentionBar, !candidates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(candidates, id: \.id) { f in
                            Button(action: { selectMention(f) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "at")
                                    Text(f.name)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }
            HStack(spacing: 8) {
                TextField("Add a comment...", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onChange(of: text, initial: false) { _, _ in updateMentionCandidates() }
                Button(action: send) {
                    if isSending { ProgressView() } else { Image(systemName: "paperplane.fill") }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal)
        }
    }
    
    private func updateMentionCandidates() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // Use following list as friend suggestions
        guard let atIdx = text.lastIndex(of: "@") else { showMentionBar = false; candidates = []; return }
        let after = text.index(after: atIdx)
        let suffix = text[after...]
        let allowed = CharacterSet.alphanumerics
        var token = ""
        for s in suffix.unicodeScalars { if allowed.contains(s) { token.unicodeScalars.append(s) } else { break } }
        if token.isEmpty && suffix.isEmpty { showMentionBar = false; candidates = []; return }
        let q = token.lowercased()
        Firestore.firestore().collection("users").document(uid).getDocument { snap, _ in
            let following = (snap?.data()? ["following"] as? [String]) ?? []
            if following.isEmpty { DispatchQueue.main.async { self.showMentionBar = false; self.candidates = [] }; return }
            let batches = following.chunked(into: 10)
            var all: [Friend] = []
            let group = DispatchGroup()
            for batch in batches {
                group.enter()
                Firestore.firestore().collection("users").whereField("uid", in: batch).getDocuments { s, _ in
                    defer { group.leave() }
                    let users = s?.documents.compactMap { try? $0.data(as: UserProfile.self) } ?? []
                    all.append(contentsOf: users.map { Friend(id: $0.uid, name: $0.displayName) })
                }
            }
            group.notify(queue: .main) {
                let filtered = all.filter { $0.name.replacingOccurrences(of: " ", with: "").lowercased().hasPrefix(q) }
                self.candidates = Array(filtered.prefix(10))
                self.showMentionBar = !self.candidates.isEmpty
            }
        }
    }
    
    private func selectMention(_ f: Friend) {
        // Replace last @token with @Name
        guard let atIdx = text.lastIndex(of: "@") else { return }
        let after = text.index(after: atIdx)
        let suffix = text[after...]
        let allowed = CharacterSet.alphanumerics
        var len = 0
        for s in suffix.unicodeScalars { if allowed.contains(s) { len += 1 } else { break } }
        let tokenEnd = text.index(after, offsetBy: len, limitedBy: text.endIndex) ?? text.endIndex
        let prefix = text[..<atIdx]
        let remainder = text[tokenEnd...]
        text = String(prefix) + "@" + f.name.replacingOccurrences(of: " ", with: "") + " " + String(remainder)
        showMentionBar = false
        candidates = []
    }
    
    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let user = Auth.auth().currentUser else { return }
        isSending = true
        // Fetch optional profile image
        Firestore.firestore().collection("users").document(user.uid).getDocument { snap, _ in
            let url = snap?.data()? ["profilePictureUrl"] as? String
            let comment = ReviewComment(logId: logId, userId: user.uid, username: user.displayName ?? "You", userProfilePictureUrl: url, text: trimmed)
            ReviewComment.addComment(comment) { err in
                DispatchQueue.main.async {
                    isSending = false
                    if err == nil {
                        AnalyticsService.shared.logComments(action: "create", contentId: logId)
                        onCommentSent(comment)
                        text = ""
                    }
                }
            }
        }
    }
}

#Preview {
    LogDetailView(log: MusicLog(id: "1", userId: "u", itemId: "s", itemType: "song", title: "Song", artistName: "Artist", artworkUrl: nil, dateLogged: Date(), rating: 4, review: "Great", notes: nil, commentCount: 42, helpfulCount: nil, unhelpfulCount: nil, reviewPhotos: nil, isLiked: nil, thumbsUp: nil, thumbsDown: nil))
}
