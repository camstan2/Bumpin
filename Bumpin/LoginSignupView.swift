//
//  LoginSignupView.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct LoginSignupView: View {
    @State private var isSignupMode = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var profileImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text(isSignupMode ? "Sign Up" : "Log In")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if isSignupMode {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disableAutocorrection(true)
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
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
                            } else {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.purple.opacity(0.5))
                            }
                            Button("Choose Profile Picture") {
                                showImagePicker = true
                            }
                            .font(.caption)
                        }
                        .padding(.top, 8)
                        
                        // Bio Field
                        TextField("Bio (optional)", text: $bio)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal, 30)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: handleAuth) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(isSignupMode ? "Sign Up" : "Log In")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                .disabled(isLoading || !isFormValid)
                .padding(.horizontal, 30)
                
                Button(action: { isSignupMode.toggle() }) {
                    Text(isSignupMode ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                        .font(.body)
                        .foregroundColor(.purple)
                }
                .padding(.bottom, 40)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage)
            }
        }
    }
    
    private var isFormValid: Bool {
        if isSignupMode {
            return !email.isEmpty && !password.isEmpty && !username.isEmpty && !displayName.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func handleAuth() {
        errorMessage = nil
        isLoading = true
        if isSignupMode {
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    isLoading = false
                    errorMessage = error.localizedDescription
                } else if let user = result?.user {
                    // Optionally update display name
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = displayName
                    changeRequest.commitChanges { _ in }
                    // Handle profile image upload if provided
                    if let image = profileImage {
                        uploadProfileImage(image, for: user.uid) { url in
                            saveUserProfile(user: user, profileImageUrl: url)
                        }
                    } else {
                        saveUserProfile(user: user, profileImageUrl: nil)
                    }
                }
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage, for uid: String, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(nil)
            return
        }
        let storageRef = Storage.storage().reference().child("profile_pictures/")
            .child("\(uid).jpg")
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                completion(nil)
                return
            }
            storageRef.downloadURL { url, error in
                completion(url?.absoluteString)
            }
        }
    }
    
    private func saveUserProfile(user: User, profileImageUrl: String?) {
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).setData([
            "uid": user.uid,
            "email": user.email ?? "",
            "username": username,
            "username_lower": username.lowercased(),
            "displayName": displayName,
            "displayName_lower": displayName.lowercased(),
            "bio": bio.isEmpty ? NSNull() : bio,
            "profilePictureUrl": profileImageUrl ?? NSNull(),
            "createdAt": FieldValue.serverTimestamp(),
            "followers": [],
            "following": [],
            "isVerified": false,
            "roles": []
        ]) { err in
            isLoading = false
            if let err = err {
                errorMessage = "Failed to save profile: \(err.localizedDescription)"
            }
        }
    }
}

#Preview {
    LoginSignupView()
} 