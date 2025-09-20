import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EnhancedReviewView: View {
    let log: MusicLog
    let showFullDetails: Bool
    @State private var showingComments = false
    @State private var comments: [ReviewComment] = []
    @State private var newCommentText = ""
    @State private var isLoadingComments = false
    @State private var isAddingComment = false
    @State private var friendLikers: [UserLike] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with music info and rating
            HStack(spacing: 12) {
                // Artwork
                if let url = log.artworkUrl, let imageUrl = URL(string: url) {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(log.artistName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        // Rating stars (inline editable for owner)
                        if let uid = Auth.auth().currentUser?.uid, uid == log.userId {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: { updateRating(star) }) {
                                        Image(systemName: star <= (log.rating ?? 0) ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        } else if let rating = log.rating {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                            }
                        }
                        
                        // Review length indicator
                        if log.reviewLength != .none {
                            Text(log.reviewLength.displayText)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(log.reviewLength.color.opacity(0.2))
                                .foregroundColor(log.reviewLength.color)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Relative time + privacy badge
                        HStack(spacing: 6) {
                            Text(timeAgoString(from: log.dateLogged))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if log.isPublic == false {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill").font(.caption2)
                                    Text("Private").font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            
            // Review text
            if let review = log.review, !review.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(review)
                        .font(.body)
                        .lineLimit(showFullDetails ? nil : 5)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    // Review photos (if any)
                    if let photos = log.reviewPhotos, !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photos, id: \.self) { photoUrl in
                                    if let url = URL(string: photoUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.2))
                                        }
                                        .frame(width: 80, height: 80)
                                        .cornerRadius(8)
                                        .clipped()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            // Interaction buttons + friend likers preview
            HStack(spacing: 20) {
                // Like button for the review
                LikeButton(
                    itemId: log.id,
                    itemType: .review,
                    itemTitle: "Review of \(log.title)",
                    itemArtist: log.artistName,
                    itemArtworkUrl: log.artworkUrl,
                    showCount: true
                )
                // Friend likers (mutuals) avatar preview
                if !friendLikers.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(friendLikers.prefix(3), id: \.id) { like in
                            // We don't have username/pfp on UserLike by default; optional future enhancement to denormalize.
                            // For now, render colored circles as placeholders or fetch minimal profile if needed.
                            Circle()
                                .fill(Color.purple.opacity(0.25))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Text(String(like.userId.prefix(1)).uppercased())
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                )
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        }
                    }
                    .padding(.leading, 4)
                    .accessibilityLabel("Friends who liked")
                }
                
                // Helpful/Unhelpful buttons
                HelpfulVoteButton(logId: log.id)
                
                Spacer()
                
                // Comment button
                Button(action: { showingComments.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .foregroundColor(.secondary)
                        if let commentCount = log.commentCount, commentCount > 0 {
                            Text("\(commentCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Report button (only show for other users' content)
                if let currentUserId = Auth.auth().currentUser?.uid, currentUserId != log.userId {
                    ReportButton(
                        contentId: log.id,
                        contentType: .musicReview,
                        reportedUserId: log.userId,
                        reportedUsername: "User", // You might want to fetch this
                        contentPreview: log.review
                    )
                }
            }
            .onAppear { loadFriendLikersPreview() }
            
            // Comments section (if expanded)
            if showingComments {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    // Add comment field
                    HStack(spacing: 8) {
                        TextField("Add a comment...", text: $newCommentText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: addComment) {
                            if isAddingComment {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Post")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingComment)
                    }
                    
                    // Comments list
                    if isLoadingComments {
                        ProgressView()
                            .frame(maxWidth: .infinity)
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
                .onAppear {
                    if comments.isEmpty {
                        loadComments()
                    }
                }
            }
            // Inline friends' comments preview (limit 2) when not expanded
            if !showingComments {
                FriendsCommentsPreview(log: log, maxCount: 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Relative Time Formatting
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago" }
        let hours = minutes / 60
        if hours < 24 { return hours == 1 ? "1 hour ago" : "\(hours) hours ago" }
        let days = hours / 24
        if days < 7 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        if days == 7 { return "One week ago" }

        let calendar = Calendar.current
        let yearOfDate = calendar.component(.year, from: date)
        let yearNow = calendar.component(.year, from: now)

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.doesRelativeDateFormatting = false
        formatter.dateFormat = yearOfDate == yearNow ? "MMMM d" : "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func loadFriendLikersPreview() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snap, _ in
            let data = snap?.data() ?? [:]
            let followingIds = (data["following"] as? [String]) ?? []
            let followerIds = (data["followers"] as? [String]) ?? []
            let mutuals = Set(followingIds).intersection(Set(followerIds))
            UserLike.getItemLikes(itemId: log.id, itemType: .review) { likes, _ in
                let likes = likes ?? []
                let filtered = likes.filter { mutuals.contains($0.userId) }
                // Optional: sort recency
                let sorted = filtered.sorted { $0.createdAt > $1.createdAt }
                self.friendLikers = Array(sorted.prefix(3))
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

    // Quick inline rating update
    private func updateRating(_ newValue: Int) {
        guard Auth.auth().currentUser?.uid == log.userId else { return }
        var updated = log
        updated.rating = newValue
        MusicLog.updateLog(updated) { _ in }
    }
}

// CommentView is already defined in MyDiaryView.swift, so we reuse it here

#if DEBUG
struct EnhancedReviewView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleLog = MusicLog(
            id: "sample-id",
            userId: "user-id",
            itemId: "song-id",
            itemType: "song",
            title: "Sample Song",
            artistName: "Sample Artist",
            artworkUrl: nil,
            dateLogged: Date(),
            rating: 4,
            review: "This is a sample review that demonstrates the enhanced review display component with multiple lines of text to show how it looks.",
            notes: nil,
            commentCount: 3,
            helpfulCount: 5,
            unhelpfulCount: 1,
            reviewPhotos: nil
        )
        
        EnhancedReviewView(log: sampleLog, showFullDetails: true)
            .padding()
    }
}
#endif 