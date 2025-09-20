import SwiftUI

struct DiscussionSettingsView: View {
    @StateObject private var discussionPreferences = DiscussionPreferencesService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    VStack(spacing: 12) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)
                        
                        Text("Discussion Sections")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Choose which discussion sections you want to see in your feed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // Selection suggestion
                    if let suggestion = discussionPreferences.selectionSuggestion {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Quick actions
                    HStack(spacing: 12) {
                        Button("Reset") {
                            discussionPreferences.resetToDefaults()
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                        
                        Button("Select All") {
                            discussionPreferences.enableAllSections()
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                        
                        Button("Clear All") {
                            discussionPreferences.disableAllSections()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal, 20)
                    
                    // Section toggles
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(DiscussionSection.allCases) { section in
                            DiscussionSectionToggleCard(
                                section: section,
                                isEnabled: discussionPreferences.isSectionEnabled(section)
                            ) {
                                discussionPreferences.toggleSection(section)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Discussion Settings")
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

// MARK: - Discussion Section Toggle Card

struct DiscussionSectionToggleCard: View {
    let section: DiscussionSection
    let isEnabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(isEnabled ? section.color.opacity(0.2) : Color(.systemGray6))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: section.icon)
                        .font(.title2)
                        .foregroundColor(isEnabled ? section.color : .gray)
                }
                
                // Section name
                Text(section.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Toggle indicator
                HStack(spacing: 4) {
                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isEnabled ? .green : .gray)
                        .font(.caption)
                    
                    Text(isEnabled ? "Enabled" : "Disabled")
                        .font(.caption2)
                        .foregroundColor(isEnabled ? .green : .gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? section.color.opacity(0.05) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isEnabled ? section.color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isEnabled ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

#Preview {
    DiscussionSettingsView()
}
