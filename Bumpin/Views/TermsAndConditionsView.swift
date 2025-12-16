import SwiftUI
import WebKit

struct TermsAndConditionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "terms-of-service", withExtension: "html") {
                WebView(url: url)
                    .navigationTitle("Terms and Conditions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                dismiss()
                            }
                        }
                    }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Terms Not Found")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Unable to load terms and conditions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .navigationTitle("Terms and Conditions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TermsAndConditionsView()
    }
}

