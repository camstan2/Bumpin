import SwiftUI
import FirebaseFirestore

struct RepostersListView: View {
    let logId: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var reposters: [ReposterInfo] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && reposters.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reposters.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No reposts yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(reposters) { reposter in
                        HStack(spacing: 12) {
                            // Avatar
                            if let profileUrl = reposter.profile?.profilePictureUrl, let url = URL(string: profileUrl) {
                                CachedAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(reposter.profile?.username.prefix(1) ?? "U").uppercased())
                                            .font(.headline)
                                            .foregroundColor(.purple)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reposter.profile?.username ?? "User")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(timeAgoString(from: reposter.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Reposts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadReposters()
            }
        }
    }
    
    private func loadReposters() {
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            let db = Firestore.firestore()
            
            do {
                // Get all reposts for this log
                let snapshot = try await db.collection("logs")
                    .document(logId)
                    .collection("reposts")
                    .order(by: "timestamp", descending: true)
                    .getDocuments()
                
                var repostersList: [ReposterInfo] = []
                
                for doc in snapshot.documents {
                    guard let userId = doc.data()["userId"] as? String,
                          let timestamp = (doc.data()["timestamp"] as? Timestamp)?.dateValue() else {
                        continue
                    }
                    
                    // Fetch user profile from cache
                    let profile = await UserProfileCache.shared.getProfile(userId: userId)
                    
                    repostersList.append(ReposterInfo(
                        id: doc.documentID,
                        userId: userId,
                        timestamp: timestamp,
                        profile: profile
                    ))
                }
                
                await MainActor.run {
                    self.reposters = repostersList
                    self.isLoading = false
                }
                
            } catch {
                print("❌ Error loading reposters: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y ago"
        } else if let months = components.month, months > 0 {
            return "\(months)mo ago"
        } else if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "just now"
        }
    }
}

struct ReposterInfo: Identifiable {
    let id: String
    let userId: String
    let timestamp: Date
    let profile: UserProfile?
}

