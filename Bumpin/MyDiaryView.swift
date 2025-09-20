import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MyDiaryView: View {
    @State private var logs: [MusicLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLog: MusicLog?
    @State private var showingEditView = false
    @State private var logToEdit: MusicLog?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView().padding()
                }
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).padding()
                }
                if logs.isEmpty && !isLoading {
                    Text("No music logs yet. Start logging your music!")
                        .foregroundColor(.secondary)
                        .padding()
                }
                List(logs) { log in
                    Button(action: { selectedLog = log }) {
                        EnhancedReviewView(log: log, showFullDetails: false)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("My Diary")
            .onAppear(perform: fetchLogs)
            .sheet(item: $selectedLog) { log in
                NavigationView {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 16) {
                            EnhancedReviewView(log: log, showFullDetails: true)
                        }
                        .padding()
                    }
                    .navigationTitle("Review")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .navigationBarItems(
                        leading: Button("Close") {
                            selectedLog = nil
                        },
                        trailing: Button("Edit") {
                            logToEdit = log
                            showingEditView = true
                            selectedLog = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showingEditView) {
                if let log = logToEdit {
                    LogMusicView()
                        .onDisappear {
                            // Refresh logs after editing
                            fetchLogs()
                        }
                }
            }
        }
    }
    
    private func fetchLogs() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to view your diary."
            return
        }
        isLoading = true
        errorMessage = nil
        MusicLog.fetchLogsForUser(userId: userId) { logs, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    // Don't show Firestore index errors in UI - they should be handled in Firebase console
                    if !error.localizedDescription.contains("index") && !error.localizedDescription.contains("create_composite") {
                        errorMessage = error.localizedDescription
                    } else {
                        print("⚠️ Firestore index needed: \(error.localizedDescription)")
                    }
                } else {
                    self.logs = logs ?? []
                }
            }
        }
    }
}

// Updated log detail view with comments (legacy; kept for reference)
struct LogDetailViewLegacy: View {
    let log: MusicLog
    let onEdit: () -> Void
    @State private var comments: [ReviewComment] = []
    @State private var newCommentText = ""
    @State private var isLoadingComments = false
    @State private var isAddingComment = false
    @State private var showingComments = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                    // Music Info Section
                    VStack(spacing: 16) {
                if let url = log.artworkUrl, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 120, height: 120)
                    .cornerRadius(12)
                }
                Text(log.title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(log.artistName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                if let rating = log.rating {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.title3)
                        }
                    }
                }
                        Text("Listened on \(log.dateLogged, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Like button for the music item
                        HStack(spacing: 20) {
                            LikeButton(
                                itemId: log.itemId,
                                itemType: log.itemType == "song" ? .song : .album,
                                itemTitle: log.title,
                                itemArtist: log.artistName,
                                itemArtworkUrl: log.artworkUrl,
                                showCount: true
                            )
                            
                            // Like button for the review (if there is one)
                            if log.review != nil && !log.review!.isEmpty {
                                LikeButton(
                                    itemId: log.id,
                                    itemType: .review,
                                    itemTitle: "Review of \(log.title)",
                                    itemArtist: log.artistName,
                                    itemArtworkUrl: log.artworkUrl,
                                    showCount: true
                                )
                            }
                        }
                    }
                    
                    // Review Section
                    if let review = log.review, !review.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Review")
                                    .font(.headline)
                                Spacer()
                            }
                    Text(review)
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                    }
                    
                    // Comments Section
                    if log.review != nil && !log.review!.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Comments")
                                    .font(.headline)
                                if let commentCount = log.commentCount, commentCount > 0 {
                                    Text("(\(commentCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(showingComments ? "Hide" : "Show") {
                                    showingComments.toggle()
                                    if showingComments && comments.isEmpty {
                                        loadComments()
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            if showingComments {
                                // Add Comment Section
                                VStack(spacing: 8) {
                                    TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .lineLimit(3)
                                    
                                    HStack {
                Spacer()
                                        Button("Post Comment") {
                                            addComment()
            }
                                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingComment)
                                        .buttonStyle(.borderedProminent)
                                        .tint(.purple)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                
                                // Comments List
                                if isLoadingComments {
                                    ProgressView()
                                        .padding()
                                } else if comments.isEmpty {
                                    Text("No comments yet. Be the first to comment!")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .padding()
                                } else {
                                    LazyVStack(alignment: .leading, spacing: 12) {
                                        ForEach(comments) { comment in
                                            CommentView(comment: comment)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        onEdit()
                    }
                }
            }
        }
        .onAppear {
            if showingComments {
                loadComments()
            }
        }
    }
    
    private func loadComments() {
        isLoadingComments = true
        ReviewComment.fetchCommentsForLog(logId: log.id, limit: 25) { fetchedComments, error in
            DispatchQueue.main.async {
                isLoadingComments = false
                if let error = error {
                    print("Error loading comments: \(error)")
                } else {
                    comments = fetchedComments ?? []
                }
            }
        }
    }
    
    private func addComment() {
        guard let currentUser = Auth.auth().currentUser,
              !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isAddingComment = true
        
        // Get user profile info for the comment
        Firestore.firestore().collection("users").document(currentUser.uid).getDocument { snapshot, error in
            let username = snapshot?.data()?["username"] as? String ?? "Unknown User"
            let profilePictureUrl = snapshot?.data()?["profilePictureUrl"] as? String
            
            let comment = ReviewComment(
                logId: log.id,
                userId: currentUser.uid,
                username: username,
                userProfilePictureUrl: profilePictureUrl,
                text: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            ReviewComment.addComment(comment) { error in
                DispatchQueue.main.async {
                    isAddingComment = false
                    if let error = error {
                        print("Error adding comment: \(error)")
                    } else {
                        newCommentText = ""
                        loadComments() // Refresh comments
                    }
                }
            }
        }
    }
}

// Comment View Component
struct CommentView: View {
    let comment: ReviewComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Picture
            if let url = comment.userProfilePictureUrl, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.gray)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            }
            
            // Comment Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(comment.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.text)
                    .font(.body)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// For preview
#Preview {
    MyDiaryView()
} 