import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

struct EditProfileView: View {
    @ObservedObject var userProfileVM: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var nowPlayingManager: NowPlayingManager
    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRankPinnedSongs: Bool = true
    @State private var toastMessage: String?
    @State private var msgHasError: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Edit Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                // Profile Picture Picker
                VStack(spacing: 8) {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.purple, lineWidth: 2))
                            .shadow(radius: 2)
                    } else if let url = userProfileVM.profile?.profilePictureUrl, let imageUrl = URL(string: url) {
                        AsyncImage(url: imageUrl) { phase in
                            if let img = phase.image {
                                img.resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.purple.opacity(0.5))
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.purple, lineWidth: 2))
                        .shadow(radius: 2)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.purple.opacity(0.5))
                    }
                    Button("Change Profile Picture") {
                        showImagePicker = true
                    }
                    .font(.caption)
                }
                .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Display Name", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text("Bio (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Bio (optional)", text: $bio)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    // Rank pinned songs toggle
                    Toggle(isOn: $showRankPinnedSongs) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show ranking on pinned songs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Display 1–3 badges on pinned songs")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                    
                    // Now Playing Toggle
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Now Playing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Display your current song on your profile")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $nowPlayingManager.isEnabled)
                            .labelsHidden()
                    }
                    .padding(.vertical, 8)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    print("[EditProfile] Save button pressed!")
                    saveProfile()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Save Changes")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(msgHasError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: toastMessage)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
            }
            .onAppear {
                print("[EditProfile] View appeared, loading profile data...")
                loadProfileData()
                // Also try to fetch the profile if it's not loaded
                if userProfileVM.profile == nil {
                    print("[EditProfile] No profile in VM, fetching...")
                    userProfileVM.fetchCurrentUserProfile()
                }
            }
            .onChange(of: userProfileVM.profile) { _, newProfile in
                print("[EditProfile] Profile changed in VM, reloading data...")
                loadProfileData()
            }
        }
    }
    
    private func loadProfileData() {
        print("[EditProfile] Loading profile data...")
        if let profile = userProfileVM.profile {
            print("[EditProfile] Profile found: displayName=\(profile.displayName), username=\(profile.username), bio=\(profile.bio ?? "nil")")
            displayName = profile.displayName
            username = profile.username
            bio = profile.bio ?? ""
            showRankPinnedSongs = profile.pinnedSongsRanked ?? true
        } else {
            print("[EditProfile] No profile found, using empty values")
            // Set default values if no profile exists
            displayName = ""
            username = ""
            bio = ""
            showRankPinnedSongs = true
        }
    }
    
    private func saveProfile() {
        guard let user = Auth.auth().currentUser else { 
            print("[EditProfile] No current user found")
            return 
        }
        isLoading = true
        errorMessage = nil
        print("[EditProfile] Saving profile...")
        print("[EditProfile] Current values - displayName: '\(displayName)', username: '\(username)', bio: '\(bio)'")
        var didFinish = false
        // Timeout after 15 seconds
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            if !didFinish {
                isLoading = false
                errorMessage = "Operation timed out. Please check your connection and try again."
                print("[EditProfile] Operation timed out.")
            }
        }
        if let image = profileImage {
            let resized = imageDownscaled(image, maxDimension: 1024)
            uploadProfileImage(resized, for: user.uid) { url in
                // logged inside uploadProfileImage as well with bytes when possible
                saveUserProfile(user: user, profileImageUrl: url ?? userProfileVM.profile?.profilePictureUrl) {
                    didFinish = true
                    timeoutTimer.invalidate()
                }
            }
        } else {
            saveUserProfile(user: user, profileImageUrl: userProfileVM.profile?.profilePictureUrl) {
                didFinish = true
                timeoutTimer.invalidate()
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage, for uid: String, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            completion(nil)
            return
        }
        AnalyticsService.shared.logProfilePhotoUploadStarted(bytes: imageData.count)
        let storageRef = Storage.storage().reference().child("users/\(uid)/profile/profile.jpg")
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("[EditProfile] Error uploading image: \(error.localizedDescription)")
                AnalyticsService.shared.logProfilePhotoUploadFailure(error: error.localizedDescription)
                completion(nil)
                return
            }
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("[EditProfile] Error getting download URL: \(error.localizedDescription)")
                    AnalyticsService.shared.logProfilePhotoUploadFailure(error: error.localizedDescription)
                    completion(nil)
                } else {
                    AnalyticsService.shared.logProfilePhotoUploadSuccess(bytes: imageData.count)
                    completion(url?.absoluteString)
                }
            }
        }
    }

    private func imageDownscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
    
    private func saveUserProfile(user: User, profileImageUrl: String?, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        print("[EditProfile] Saving to Firestore: displayName=\(displayName), username=\(username), bio=\(bio), profilePictureUrl=\(profileImageUrl ?? "nil")")
        db.collection("users").document(user.uid).updateData([
            "displayName": displayName,
            "username": username,
            "bio": bio.isEmpty ? NSNull() : bio,
            "profilePictureUrl": profileImageUrl ?? NSNull(),
            "pinnedSongsRanked": showRankPinnedSongs
        ]) { err in
            isLoading = false
            if let err = err {
                errorMessage = "Failed to save profile: \(err.localizedDescription)"
                print("[EditProfile] Firestore error: \(err.localizedDescription)")
                AnalyticsService.shared.logProfileSaveFailure(error: err.localizedDescription)
                withAnimation { toastMessage = "Save failed"; msgHasError = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { toastMessage = nil } }
            } else {
                print("[EditProfile] Profile updated successfully!")
                userProfileVM.fetchCurrentUserProfile()
                presentationMode.wrappedValue.dismiss()
                AnalyticsService.shared.logProfileSaveSuccess(userId: user.uid)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare(); generator.impactOccurred()
                withAnimation { toastMessage = "Saved"; msgHasError = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { toastMessage = nil } }
            }
            completion()
        }
    }
} 