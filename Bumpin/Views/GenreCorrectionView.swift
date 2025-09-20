import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GenreCorrectionView: View {
    let log: MusicLog
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedGenre: String
    @State private var isSaving = false
    @State private var showSuccess = false
    
    let onSave: () -> Void
    
    // Available genres for correction
    let availableGenres = [
        "Hip-Hop", "Pop", "R&B", "Electronic", "Rock", "Indie", 
        "Country", "K-Pop", "Latin", "Jazz", "Classical", "Reggae", 
        "Funk", "Blues", "Alternative", "Other"
    ]
    
    init(log: MusicLog, onSave: @escaping () -> Void) {
        self.log = log
        self.onSave = onSave
        
        // Initialize with current genre (user corrected > primary > classified)
        let currentGenre = log.userCorrectedGenre ?? log.primaryGenre ?? "Other"
        self._selectedGenre = State(initialValue: currentGenre)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    // Album artwork
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
                    .frame(width: 120, height: 120)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
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
                    }
                }
                .padding(.horizontal, 20)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Current Classification Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Classification")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if let method = log.classificationMethod {
                            HStack {
                                Text("Method:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(method.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        if let confidence = log.genreConfidenceScore {
                            HStack {
                                Text("Confidence:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(confidence * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(confidence > 0.8 ? .green : confidence > 0.5 ? .orange : .red)
                            }
                        }
                        
                        if let appleMusicGenres = log.appleMusicGenres {
                            HStack {
                                Text("Apple Music:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(appleMusicGenres.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                
                // Genre Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select correct genre")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(availableGenres, id: \.self) { genre in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGenre = genre
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(selectedGenre == genre ? Color.purple : Color.clear)
                                        .frame(width: 8, height: 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.purple, lineWidth: 2)
                                        )
                                    
                                    Text(genre)
                                        .font(.subheadline)
                                        .fontWeight(selectedGenre == genre ? .semibold : .medium)
                                    
                                    Spacer()
                                }
                                .foregroundColor(selectedGenre == genre ? .purple : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedGenre == genre ? Color.purple.opacity(0.1) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedGenre == genre ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Success Message
                if showSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Genre updated successfully!")
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Save Button
                Button(action: saveCorrection) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                            Text("Updating...")
                        } else {
                            Text("Update Genre")
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
            .navigationTitle("Correct Genre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func saveCorrection() {
        isSaving = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            isSaving = false
            return
        }
        
        // Update the log with user correction
        let db = Firestore.firestore()
        let updateData: [String: Any] = [
            "userCorrectedGenre": selectedGenre,
            "classificationMethod": "user_corrected",
            "genreConfidenceScore": 1.0 // User corrections have 100% confidence
        ]
        
        db.collection("logs").document(log.id).updateData(updateData) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error updating genre: \(error.localizedDescription)")
                    self.isSaving = false
                } else {
                    print("✅ Genre correction saved: \(self.log.title) → \(self.selectedGenre)")
                    
                    // Phase 3: Learn from user correction
                    self.learnFromCorrection()
                    
                    self.showSuccess = true
                    self.onSave()
                    
                    // Dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
                self.isSaving = false
            }
        }
    }
    
    private func learnFromCorrection() {
        // Phase 3: Store user correction for learning
        let db = Firestore.firestore()
        let learningData: [String: Any] = [
            "userId": Auth.auth().currentUser?.uid ?? "",
            "artistName": log.artistName.lowercased(),
            "correctedGenre": selectedGenre,
            "originalGenre": log.primaryGenre ?? "unknown",
            "timestamp": Date(),
            "songTitle": log.title
        ]
        
        db.collection("genreCorrections").addDocument(data: learningData) { error in
            if let error = error {
                print("❌ Error storing genre correction: \(error.localizedDescription)")
            } else {
                print("🧠 Genre correction stored for learning: \(log.artistName) → \(selectedGenre)")
            }
        }
    }
}
