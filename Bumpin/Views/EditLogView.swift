import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct EditLogView: View {
    let log: MusicLog
    @Environment(\.presentationMode) var presentationMode
    @State private var rating: Int
    @State private var review: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var isLiked: Bool
    @State private var isReposted: Bool
    @State private var thumbsDown: Bool
    @State private var isPublic: Bool
    
    let onSave: () -> Void
    
    init(log: MusicLog, onSave: @escaping () -> Void) {
        self.log = log
        self.onSave = onSave
        
        // Initialize state with existing log data
        self._rating = State(initialValue: log.rating ?? 0)
        self._review = State(initialValue: log.review ?? "")
        self._isLiked = State(initialValue: log.isLiked ?? false)
        self._isReposted = State(initialValue: log.thumbsUp ?? false) // Map thumbsUp to repost
        self._thumbsDown = State(initialValue: log.thumbsDown ?? false)
        self._isPublic = State(initialValue: log.isPublic ?? true)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section - Song/Album Info
                    VStack(spacing: 20) {
                        // Album artwork with enhanced styling
                        Group {
                            if let artworkUrl = log.artworkUrl, let url = URL(string: artworkUrl) {
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.system(size: 30))
                                                .foregroundColor(.gray)
                                        )
                                }
                            } else {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .frame(width: 140, height: 140)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                        
                        VStack(spacing: 8) {
                            Text(log.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            Text(log.artistName)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text(log.itemType.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.purple.opacity(0.1))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Rating Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How would you rate this?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        rating = star
                                    }
                                }) {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 32))
                                        .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .scaleEffect(star <= rating ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: rating)
                            }
                            
                            Spacer()
                        }
                        
                        if rating > 0 {
                            Text("\(rating) star\(rating == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick actions")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 20) {
                            // Like Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isLiked.toggle()
                                    if isLiked {
                                        isReposted = false
                                        thumbsDown = false
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 18, weight: .medium))
                                    Text("Like")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(isLiked ? .red : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(isLiked ? Color.red.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isLiked ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Repost Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isReposted.toggle()
                                    if isReposted {
                                        isLiked = false
                                        thumbsDown = false
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: isReposted ? "arrow.2.squarepath" : "arrow.2.squarepath")
                                        .font(.system(size: 18, weight: .medium))
                                    Text("Repost")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(isReposted ? .blue : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(isReposted ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isReposted ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Skip Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    thumbsDown.toggle()
                                    if thumbsDown {
                                        isLiked = false
                                        isReposted = false
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                        .font(.system(size: 18, weight: .medium))
                                    Text("Skip")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(thumbsDown ? .orange : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(thumbsDown ? Color.orange.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(thumbsDown ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Review Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Edit your review (optional)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        TextEditor(text: $review)
                            .frame(minHeight: 120)
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)

                    // Privacy Section
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $isPublic) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Public log")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text(isPublic ? "Visible to followers and in trends" : "Only you can see this log")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                    .padding(.horizontal, 20)
                    
                    // Error Message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Success Message
                    if showSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Log updated successfully!")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Update Button
                    Button(action: updateLog) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Updating...")
                            } else {
                                Text("Update Log")
                            }
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSaving)
                    .buttonStyle(BumpinPrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
    }

    func updateLog() {
        isSaving = true
        errorMessage = nil
        
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to update a log."
            isSaving = false
            return
        }
        
        // Ensure the user owns this log
        guard log.userId == userId else {
            errorMessage = "You can only edit your own logs."
            isSaving = false
            return
        }
        
        // Create updated log with current timestamp for edited logs
        let updatedLog = MusicLog(
            id: log.id,
            userId: userId,
            itemId: log.itemId,
            itemType: log.itemType,
            title: log.title,
            artistName: log.artistName,
            artworkUrl: log.artworkUrl,
            dateLogged: Date(), // Update timestamp to current time when edited
            rating: rating == 0 ? nil : rating,
            review: review.isEmpty ? nil : review,
            notes: log.notes,
            commentCount: log.commentCount,
            helpfulCount: log.helpfulCount,
            unhelpfulCount: log.unhelpfulCount,
            reviewPhotos: log.reviewPhotos,
            isLiked: isLiked,
            thumbsUp: isReposted, // Map repost back to thumbsUp field
            thumbsDown: thumbsDown,
            isPublic: isPublic,
            appleMusicGenres: log.appleMusicGenres, // Preserve existing Apple Music genres
            primaryGenre: log.primaryGenre // Preserve existing primary genre
        )
        
        // Update in Firestore
        do {
            let db = Firestore.firestore()
            try db.collection("logs").document(log.id).setData(from: updatedLog) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Failed to update log: \(error.localizedDescription)"
                        self.isSaving = false
                    } else {
                        print("✅ Successfully updated log")
                        self.showSuccess = true
                        self.onSave() // Callback to refresh data
                        
                        // Dismiss after short delay to show success
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to update log: \(error.localizedDescription)"
                self.isSaving = false
            }
        }
    }
}


