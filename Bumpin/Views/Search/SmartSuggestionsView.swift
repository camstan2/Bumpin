import SwiftUI

struct SmartSuggestionsView: View {
    let suggestions: [SearchSuggestion]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button(action: {
                    HapticManager.impact(style: .light)
                    onSelect(suggestion.text)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: suggestion.icon)
                            .foregroundColor(iconColor(for: suggestion.type))
                            .frame(width: 24)
                        
                        Text(suggestion.text)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(.systemGray4))
                        .opacity(0.5),
                    alignment: .bottom
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.systemGray3).opacity(0.3), radius: 8, y: 4)
        )
        .padding(.horizontal)
    }
    
    private func iconColor(for type: SearchSuggestion.SuggestionType) -> Color {
        switch type {
        case .exact:
            return .blue
        case .recent:
            return .gray
        case .suggestion:
            return .purple
        }
    }
}
