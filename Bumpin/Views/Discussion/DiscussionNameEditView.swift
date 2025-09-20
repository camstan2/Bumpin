//
//  DiscussionNameEditView.swift
//  Bumpin
//
//  Created by AI Assistant
//

import SwiftUI

struct DiscussionNameEditView: View {
    @Binding var discussionName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var showingError = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.purple)
                    
                    Text("Edit Discussion Name")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose a clear and descriptive name for your discussion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Text Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discussion Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter discussion name...", text: $discussionName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            saveDiscussionName()
                        }
                    
                    Text("Maximum 50 characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if showingError {
                        Text("Discussion name cannot be empty")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDiscussionName()
                    }
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                    .disabled(discussionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveDiscussionName() {
        let trimmedName = discussionName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            showingError = true
            return
        }
        
        // Limit to 50 characters
        let finalName = String(trimmedName.prefix(50))
        onSave(finalName)
    }
}

#Preview {
    DiscussionNameEditView(
        discussionName: .constant("Sample Discussion"),
        onSave: { _ in },
        onCancel: { }
    )
}
