import SwiftUI

struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<5) { _ in
                HStack(spacing: 16) {
                    // Artwork placeholder
                    ShimmerView()
                        .frame(width: 56, height: 56)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Title placeholder
                        ShimmerView()
                            .frame(height: 16)
                            .frame(width: 120)
                            .cornerRadius(4)
                        
                        // Subtitle placeholder
                        ShimmerView()
                            .frame(height: 14)
                            .frame(width: 80)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Type indicator placeholder
                    ShimmerView()
                        .frame(width: 60, height: 24)
                        .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color(.systemGray4).opacity(0.1), radius: 8, y: 4)
            }
        }
        .padding(.vertical, 8)
    }
}
