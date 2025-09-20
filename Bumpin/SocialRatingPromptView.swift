import SwiftUI
import FirebaseAuth

/// Main view for displaying and handling social rating prompts
struct SocialRatingPromptView: View {
    let ratingPrompt: RatingPrompt
    let targetUserProfile: UserProfile
    @StateObject private var socialScoringService = SocialScoringService.shared
    
    @State private var selectedRating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    @State private var showingSkipConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    private let maxCommentLength = 150
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ProfileDesignSystem.Spacing.xxl) {
                    // Header section
                    headerSection
                    
                    // User info section
                    userInfoSection
                    
                    // Rating section
                    ratingSection
                    
                    // Comment section (optional)
                    commentSection
                    
                    // Mutual visibility explanation
                    mutualVisibilitySection
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding(.horizontal, ProfileDesignSystem.Spacing.lg)
                .padding(.bottom, ProfileDesignSystem.Spacing.xxxxl)
            }
            .navigationTitle("Rate Interaction")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        showingSkipConfirmation = true
                    }
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                }
            }
        }
        .confirmationDialog("Skip Rating", isPresented: $showingSkipConfirmation) {
            Button("Skip", role: .destructive) {
                Task {
                    await handleSkipRating()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You won't be able to see their rating if you skip. Are you sure?")
        }
        .alert("Rating Submitted", isPresented: $showingConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thanks for your feedback! You can now see their rating once they rate you back.")
        }
        .disabled(isSubmitting)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(ProfileDesignSystem.Colors.primary)
            
            Text("Rate Your Interaction")
                .font(ProfileDesignSystem.Typography.displaySmall)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            Text(ratingPrompt.interactionContext)
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, ProfileDesignSystem.Spacing.lg)
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        HStack(spacing: ProfileDesignSystem.Spacing.md) {
            // Profile image
            AsyncImage(url: URL(string: targetUserProfile.profilePictureUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(ProfileDesignSystem.Colors.surface)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.xs) {
                Text(targetUserProfile.displayName)
                    .font(ProfileDesignSystem.Typography.headlineSmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                Text("@\(targetUserProfile.username)")
                    .font(ProfileDesignSystem.Typography.bodySmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                
                // Show their social score if available
                if let socialScore = targetUserProfile.socialScore,
                   let totalRatings = targetUserProfile.totalSocialRatings,
                   totalRatings > 0 {
                    HStack(spacing: ProfileDesignSystem.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(ProfileDesignSystem.Colors.ratingActive)
                        
                        Text(String(format: "%.1f", socialScore))
                            .font(ProfileDesignSystem.Typography.captionLarge)
                            .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                        
                        Text("(\(totalRatings) ratings)")
                            .font(ProfileDesignSystem.Typography.captionMedium)
                            .foregroundColor(ProfileDesignSystem.Colors.textTertiary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(ProfileDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                .fill(ProfileDesignSystem.Colors.surfaceElevated)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Rating Section
    
    private var ratingSection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.lg) {
            Text("How was your interaction?")
                .font(ProfileDesignSystem.Typography.headlineMedium)
                .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
            
            // Star rating selector
            HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                ForEach(1...10, id: \.self) { rating in
                    RatingStarButton(
                        rating: rating,
                        selectedRating: $selectedRating,
                        isSelected: rating <= selectedRating
                    )
                }
            }
            
            // Rating description
            if selectedRating > 0 {
                Text(ratingDescription(for: selectedRating))
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(ProfileDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                .fill(ProfileDesignSystem.Colors.surfaceElevated)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Comment Section
    
    private var commentSection: some View {
        VStack(alignment: .leading, spacing: ProfileDesignSystem.Spacing.md) {
            HStack {
                Text("Add a comment (optional)")
                    .font(ProfileDesignSystem.Typography.headlineSmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(comment.count)/\(maxCommentLength)")
                    .font(ProfileDesignSystem.Typography.captionMedium)
                    .foregroundColor(comment.count > maxCommentLength * 8 / 10 ? ProfileDesignSystem.Colors.warning : ProfileDesignSystem.Colors.textTertiary)
            }
            
            TextField("Share your thoughts about this interaction...", text: $comment, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .font(ProfileDesignSystem.Typography.bodyMedium)
                .lineLimit(3...6)
                .padding(ProfileDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                        .fill(ProfileDesignSystem.Colors.surface)
                )
                .onChange(of: comment) { _, newValue in
                    if newValue.count > maxCommentLength {
                        comment = String(newValue.prefix(maxCommentLength))
                    }
                }
        }
        .padding(ProfileDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                .fill(ProfileDesignSystem.Colors.surfaceElevated)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Mutual Visibility Section
    
    private var mutualVisibilitySection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.sm) {
            HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                Image(systemName: "eye.fill")
                    .foregroundColor(ProfileDesignSystem.Colors.info)
                    .font(.system(size: 16))
                
                Text("Mutual Rating Visibility")
                    .font(ProfileDesignSystem.Typography.headlineSmall)
                    .foregroundColor(ProfileDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            Text("You'll only see their rating after you rate them. This encourages honest feedback from both sides.")
                .font(ProfileDesignSystem.Typography.bodySmall)
                .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(ProfileDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                .fill(ProfileDesignSystem.Colors.info.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.small)
                        .stroke(ProfileDesignSystem.Colors.info.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: ProfileDesignSystem.Spacing.md) {
            // Submit button
            Button(action: {
                Task {
                    await handleSubmitRating()
                }
            }) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isSubmitting ? "Submitting..." : "Submit Rating")
                        .font(ProfileDesignSystem.Typography.bodyLarge)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                        .fill(selectedRating > 0 ? ProfileDesignSystem.Colors.primary : ProfileDesignSystem.Colors.textTertiary)
                )
            }
            .buttonStyle(BumpinPrimaryButtonStyle())
            .disabled(selectedRating == 0 || isSubmitting)
            
            // Skip button
            Button(action: {
                showingSkipConfirmation = true
            }) {
                Text("Skip for now")
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .foregroundColor(ProfileDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: ProfileDesignSystem.CornerRadius.medium)
                            .stroke(ProfileDesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(BumpinButtonStyle())
            .disabled(isSubmitting)
        }
    }
    
    // MARK: - Helper Functions
    
    private func ratingDescription(for rating: Int) -> String {
        switch rating {
        case 1...2:
            return "Poor interaction - not enjoyable"
        case 3...4:
            return "Below average - some issues"
        case 5...6:
            return "Average - okay interaction"
        case 7...8:
            return "Good - enjoyable interaction"
        case 9...10:
            return "Excellent - really great time!"
        default:
            return ""
        }
    }
    
    private func handleSubmitRating() async {
        guard selectedRating > 0 else { return }
        
        isSubmitting = true
        
        do {
            let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalComment = trimmedComment.isEmpty ? nil : trimmedComment
            
            try await socialScoringService.submitRating(
                for: ratingPrompt.id,
                rating: selectedRating,
                comment: finalComment
            )
            
            await MainActor.run {
                showingConfirmation = true
            }
            
        } catch {
            print("Error submitting rating: \(error)")
            // Could show error alert here
        }
        
        isSubmitting = false
    }
    
    private func handleSkipRating() async {
        isSubmitting = true
        
        do {
            try await socialScoringService.skipRating(for: ratingPrompt.id)
            
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            print("Error skipping rating: \(error)")
        }
        
        isSubmitting = false
    }
}

// MARK: - Rating Star Button Component

struct RatingStarButton: View {
    let rating: Int
    @Binding var selectedRating: Int
    let isSelected: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedRating = rating
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "star.fill" : "star")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isSelected ? ProfileDesignSystem.Colors.ratingActive : ProfileDesignSystem.Colors.ratingInactive)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                Text("\(rating)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? ProfileDesignSystem.Colors.ratingActive : ProfileDesignSystem.Colors.textTertiary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 32, height: 40)
    }
}

// MARK: - Rating Prompt Container View

/// Container view that manages the display of rating prompts
struct SocialRatingPromptContainer: View {
    @StateObject private var socialScoringService = SocialScoringService.shared
    @StateObject private var userProfileViewModel = UserProfileViewModel()
    
    @State private var selectedPrompt: RatingPrompt?
    @State private var targetUserProfile: UserProfile?
    @State private var isLoadingProfile = false
    
    var body: some View {
        Group {
            if !socialScoringService.pendingRatingPrompts.isEmpty {
                // Show floating prompt indicator
                FloatingRatingPromptIndicator(
                    promptCount: socialScoringService.pendingRatingPrompts.count,
                    onTap: {
                        showNextPrompt()
                    }
                )
            }
        }
        .sheet(item: $selectedPrompt) { prompt in
            if let profile = targetUserProfile {
                SocialRatingPromptView(
                    ratingPrompt: prompt,
                    targetUserProfile: profile
                )
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        loadTargetUserProfile(for: prompt)
                    }
            }
        }
    }
    
    private func showNextPrompt() {
        guard let prompt = socialScoringService.pendingRatingPrompts.first else { return }
        selectedPrompt = prompt
        loadTargetUserProfile(for: prompt)
    }
    
    private func loadTargetUserProfile(for prompt: RatingPrompt) {
        guard !isLoadingProfile else { return }
        
        isLoadingProfile = true
        
        Task {
            do {
                let profile = try await userProfileViewModel.fetchUserProfile(userId: prompt.targetUserId)
                
                await MainActor.run {
                    targetUserProfile = profile
                    isLoadingProfile = false
                }
            } catch {
                print("Error loading target user profile: \(error)")
                await MainActor.run {
                    isLoadingProfile = false
                }
            }
        }
    }
}

// MARK: - Floating Rating Prompt Indicator

struct FloatingRatingPromptIndicator: View {
    let promptCount: Int
    let onTap: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ProfileDesignSystem.Spacing.sm) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("\(promptCount) rating\(promptCount == 1 ? "" : "s")")
                    .font(ProfileDesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, ProfileDesignSystem.Spacing.lg)
            .padding(.vertical, ProfileDesignSystem.Spacing.md)
            .background(
                Capsule()
                    .fill(ProfileDesignSystem.Colors.primary)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(BumpinButtonStyle())
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    let samplePrompt = RatingPrompt(
        interactionId: "sample-interaction",
        promptedUserId: "user1",
        targetUserId: "user2",
        interactionType: .discussion,
        interactionContext: "Discussion about favorite albums"
    )
    
    let sampleUser = UserProfile(
        uid: "user2",
        email: "user2@example.com",
        username: "musiclover",
        displayName: "Music Lover",
        createdAt: Date(),
        profilePictureUrl: nil,
        profileHeaderUrl: nil,
        bio: "Love discovering new music!",
        followers: [],
        following: [],
        isVerified: false,
        roles: [],
        reportCount: 0,
        violationCount: 0,
        locationSharingWith: [],
        showNowPlaying: true,
        nowPlayingSong: nil,
        nowPlayingArtist: nil,
        nowPlayingAlbumArt: nil,
        nowPlayingUpdatedAt: nil,
        pinnedSongs: [],
        pinnedArtists: [],
        pinnedAlbums: [],
        pinnedLists: [],
        pinnedSongsRanked: false,
        pinnedArtistsRanked: false,
        pinnedAlbumsRanked: false,
        pinnedListsRanked: false,
        matchmakingOptIn: false,
        matchmakingGender: nil,
        matchmakingPreferredGender: nil,
        matchmakingLastActive: nil,
        socialScore: 8.5,
        totalSocialRatings: 23,
        socialBadges: ["first_rating", "social_starter"],
        socialScoreLastUpdated: Date()
    )
    
    SocialRatingPromptView(
        ratingPrompt: samplePrompt,
        targetUserProfile: sampleUser
    )
}
