import SwiftUI
import MusicKit

struct PromptResponseSubmissionView: View {
    let coordinator: DailyPromptCoordinator
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSong: MusicSearchResult?
    @State private var explanation = ""
    @State private var isPublic = true
    @State private var isSubmitting = false
    @State private var showMusicSearch = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isExplanationFocused: Bool
    
    private let maxExplanationLength = 280
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Prompt display
                    promptSection
                    
                    // Song selection
                    songSelectionSection
                    
                    // Explanation section
                    explanationSection
                    
                    // Privacy settings
                    privacySection
                    
                    // Submit button
                    submitSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isExplanationFocused = false
                hideKeyboard()
            }
            .navigationTitle("Your Response")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isExplanationFocused = false
                        hideKeyboard()
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                }
            }
        }
        .fullScreenCover(isPresented: $showMusicSearch) {
            ComprehensiveSearchView()
                .environment(\.promptSelectionMode, true)
                .environment(\.onPromptSongSelected, { musicResult in
                    selectedSong = musicResult
                    showMusicSearch = false
                })
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            coordinator.trackPromptEngagement("response_submission_opened")
        }
    }
    
    // MARK: - Prompt Section
    
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let prompt = coordinator.currentPrompt {
                CategoryBadge(category: prompt.category)
                
                Text(prompt.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let description = prompt.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let timeRemaining = coordinator.formatTimeRemaining() {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                        Text(timeRemaining)
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Song Selection Section
    
    private var songSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Song")
                .font(.headline)
                .fontWeight(.bold)
            
            if let song = selectedSong {
                selectedSongCard(song)
            } else {
                songSelectionButton
            }
        }
    }
    
    private func selectedSongCard(_ song: MusicSearchResult) -> some View {
        HStack(spacing: 16) {
            // Album artwork
            AsyncImage(url: URL(string: song.artworkURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(song.artistName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if !song.albumName.isEmpty {
                    Text(song.albumName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Change button
            Button("Change") {
                showMusicSearch = true
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.1))
            .foregroundColor(.purple)
            .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var songSelectionButton: some View {
        Button(action: {
            showMusicSearch = true
        }) {
            VStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 32))
                    .foregroundColor(.purple)
                
                Text("Select a Song")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                
                Text("Choose the perfect song that matches this prompt")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Explanation Section
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Why This Song? (Optional)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(explanation.count)/\(maxExplanationLength)")
                    .font(.caption)
                    .foregroundColor(explanation.count > maxExplanationLength ? .red : .secondary)
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                if explanation.isEmpty {
                    Text("Share why this song perfectly captures the prompt...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                
                TextEditor(text: $explanation)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray5))
                    .focused($isExplanationFocused)
                    .onChange(of: explanation) { _, newValue in
                        if newValue.count > maxExplanationLength {
                            explanation = String(newValue.prefix(maxExplanationLength))
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(minHeight: 100)
            
            Text("Your explanation will be visible to other users if you make your response public")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                privacyOption(
                    title: "Public Response",
                    description: "Your response will be visible to all users and included in the leaderboard",
                    isSelected: isPublic,
                    action: { isPublic = true }
                )
                
                privacyOption(
                    title: "Private Response",
                    description: "Only you can see your response, but it will still count toward your streak",
                    isSelected: !isPublic,
                    action: { isPublic = false }
                )
            }
        }
    }
    
    private func privacyOption(title: String, description: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .purple : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.purple.opacity(0.1) : Color(.tertiarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Submit Section
    
    private var submitSection: some View {
        VStack(spacing: 16) {
            Button(action: submitResponse) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    
                    Text(isSubmitting ? "Submitting..." : "Submit Response")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canSubmit ? [Color.purple, Color.blue] : [Color.gray, Color.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canSubmit || isSubmitting)
                            .buttonStyle(.plain)
            
            if !canSubmit && selectedSong == nil {
                Text("Please select a song to continue")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSubmit: Bool {
        return selectedSong != nil && !isSubmitting
    }
    
    // MARK: - Actions
    
    private func submitResponse() {
        guard let song = selectedSong,
              let prompt = coordinator.currentPrompt else {
            return
        }
        
        isSubmitting = true
        
        Task {
            let success = await coordinator.submitResponse(
                songId: song.id,
                songTitle: song.title,
                artistName: song.artistName,
                albumName: song.albumName.isEmpty ? nil : song.albumName,
                artworkUrl: song.artworkURL,
                appleMusicUrl: nil, // Could add Apple Music deep link
                explanation: explanation.isEmpty ? nil : explanation,
                isPublic: isPublic
            )
            
            await MainActor.run {
                isSubmitting = false
                
                if success {
                    coordinator.trackPromptEngagement("response_submitted", promptId: prompt.id)
                    dismiss()
                } else {
                    errorMessage = coordinator.errorMessage ?? "Failed to submit response. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    PromptResponseSubmissionView(coordinator: DailyPromptCoordinator())
        .environmentObject(NavigationCoordinator())
}
