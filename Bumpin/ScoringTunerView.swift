import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ScoringTunerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var weights: [String: Double] = [
        "shortQueryPrefixMultiplier": 1.0,
        "shortQueryWordStartMultiplier": 1.0,
        "shortQueryProviderBoostMultiplier": 1.0
    ]
    @State private var keysOrder: [String] = [
        "shortQueryPrefixMultiplier",
        "shortQueryWordStartMultiplier",
        "shortQueryProviderBoostMultiplier"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Weights") {
                    ForEach(keysOrder, id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Stepper(value: Binding(
                                get: { weights[key] ?? 1.0 },
                                set: { weights[key] = $0 }
                            ), in: 0.0...5.0, step: 0.05) {
                                Text(String(format: "%.2f", weights[key] ?? 1.0))
                                    .monospacedDigit()
                            }
                            .fixedSize()
                        }
                    }
                }

                if let info = infoMessage {
                    Section {
                        Text(info).foregroundColor(.green)
                    }
                }
                if let err = errorMessage {
                    Section {
                        Text(err).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Scoring Tuner")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isLoading ? "Saving..." : "Save") { Task { await save() } }
                        .disabled(isLoading)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        guard await isAdmin() else { await MainActor.run { errorMessage = "Admin only" }; return }
        await MainActor.run { isLoading = true; errorMessage = nil; infoMessage = nil }
        do {
            let snapshot = try await Firestore.firestore().collection("config").document("scoring").getDocument()
            if let data = snapshot.data() {
                var newWeights: [String: Double] = weights
                for (k, v) in data {
                    if let d = v as? Double { newWeights[k] = d }
                    if !keysOrder.contains(k) { keysOrder.append(k) }
                }
                await MainActor.run { self.weights = newWeights }
            }
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to load: \(error.localizedDescription)"
            }
        }
    }

    private func save() async {
        guard await isAdmin() else { await MainActor.run { errorMessage = "Admin only" }; return }
        await MainActor.run { isLoading = true; errorMessage = nil; infoMessage = nil }
        do {
            try await Firestore.firestore().collection("config").document("scoring").setData(weights)
            await MainActor.run {
                isLoading = false
                infoMessage = "Saved successfully"
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
    private func isAdmin() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        do {
            let snap = try await Firestore.firestore().collection("users").document(uid).getDocument()
            return (snap.data()? ["isAdmin"] as? Bool) == true
        } catch { return false }
    }
}


