import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Admin view to fix terms acceptance for existing users
/// This adds termsAcceptedAt to all users who don't have it
struct FixTermsAcceptanceView: View {
    @State private var isFixing = false
    @State private var fixedCount = 0
    @State private var errorCount = 0
    @State private var statusMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Fix Terms Acceptance")
                .font(.title)
                .fontWeight(.bold)
            
            Text("This will add terms acceptance to all existing users who are missing it.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if isFixing {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text("Fixing users...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if fixedCount > 0 {
                    Text("Fixed: \(fixedCount)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else if showSuccess {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Migration Complete!")
                        .font(.headline)
                    
                    Text("Fixed \(fixedCount) users")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if errorCount > 0 {
                        Text("Errors: \(errorCount)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } else {
                Button(action: fixAllUsers) {
                    Text("Run Migration")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
            
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
    }
    
    private func fixAllUsers() {
        isFixing = true
        showSuccess = false
        fixedCount = 0
        errorCount = 0
        
        Task {
            await performMigration()
        }
    }
    
    private func performMigration() async {
        let db = Firestore.firestore()
        
        do {
            // Get all users who don't have termsAcceptedAt
            let snapshot = try await db.collection("users").getDocuments()
            
            await MainActor.run {
                statusMessage = "Found \(snapshot.documents.count) total users"
            }
            
            for document in snapshot.documents {
                let data = document.data()
                
                // Check if termsAcceptedAt is missing
                if data["termsAcceptedAt"] == nil {
                    do {
                        try await db.collection("users").document(document.documentID).updateData([
                            "termsAcceptedAt": FieldValue.serverTimestamp(),
                            "termsVersion": "1.0"
                        ])
                        
                        await MainActor.run {
                            fixedCount += 1
                            statusMessage = "Fixed user \(fixedCount)..."
                        }
                    } catch {
                        await MainActor.run {
                            errorCount += 1
                            print("❌ Error fixing user \(document.documentID): \(error)")
                        }
                    }
                }
            }
            
            await MainActor.run {
                isFixing = false
                showSuccess = true
                statusMessage = "Migration complete! Fixed \(fixedCount) users."
                print("✅ Terms acceptance migration complete: \(fixedCount) users fixed, \(errorCount) errors")
            }
        } catch {
            await MainActor.run {
                isFixing = false
                statusMessage = "Error: \(error.localizedDescription)"
                print("❌ Migration error: \(error)")
            }
        }
    }
}

#Preview {
    FixTermsAcceptanceView()
}

