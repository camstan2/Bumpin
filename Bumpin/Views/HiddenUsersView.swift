import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HiddenUsersView: View {
    @State private var hiddenUsers: [String] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if hiddenUsers.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No Hidden Users")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Users you hide from your feed will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section(
                    header: Text("Hidden Users"),
                    footer: Text("\(hiddenUsers.count) user\(hiddenUsers.count == 1 ? "" : "s") hidden")
                ) {
                    ForEach(hiddenUsers, id: \.self) { userId in
                        HiddenUserRow(userId: userId) {
                            unhideUser(userId)
                        }
                    }
                }
            }
        }
        .navigationTitle("Hidden Users")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadHiddenUsers()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadHiddenUsers() {
        isLoading = true
        
        Task {
            guard let uid = Auth.auth().currentUser?.uid else {
                await MainActor.run {
                    hiddenUsers = []
                    isLoading = false
                }
                return
            }
            
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .getDocument()
                
                let hiddenList = (snapshot.data()?["hiddenUsers"] as? [String]) ?? []
                
                await MainActor.run {
                    self.hiddenUsers = hiddenList
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading hidden users: \(error.localizedDescription)")
                await MainActor.run {
                    self.hiddenUsers = []
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func unhideUser(_ userId: String) {
        Task {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .updateData([
                        "hiddenUsers": FieldValue.arrayRemove([userId])
                    ])
                
                await MainActor.run {
                    hiddenUsers.removeAll { $0 == userId }
                }
                
                print("✅ Unhid user: \(userId)")
            } catch {
                print("❌ Error unhiding user: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Hidden User Row

struct HiddenUserRow: View {
    let userId: String
    let onUnhide: () -> Void
    
    @State private var userProfile: UserProfile?
    @State private var isLoading = true
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            profileImageView
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                if let profile = userProfile {
                    Text(profile.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !profile.username.isEmpty {
                        Text("@\(profile.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if isLoading {
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("User ID: \(userId.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Unhide Button
            Button(action: onUnhide) {
                Text("Unhide")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadUserProfile()
        }
    }
    
    // MARK: - Profile Image View
    
    @ViewBuilder
    private var profileImageView: some View {
        if let profile = userProfile, let photoURL = profile.profilePictureUrl, !photoURL.isEmpty, let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                case .empty, .failure:
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(profile.displayName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.orange)
                        )
                @unknown default:
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                }
            }
        } else if let profile = userProfile {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(profile.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.orange)
                )
        } else {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    ProgressView()
                        .scaleEffect(0.7)
                )
        }
    }
    
    private func loadUserProfile() {
        Task {
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("users")
                    .document(userId)
                    .getDocument()
                
                if let profile = try? snapshot.data(as: UserProfile.self) {
                    await MainActor.run {
                        self.userProfile = profile
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Error loading user profile: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        HiddenUsersView()
    }
}

