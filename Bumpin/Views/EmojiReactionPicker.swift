//
//  EmojiReactionPicker.swift
//  Bumpin
//
//  Created by Cam Stanley on 6/28/25.
//

import SwiftUI

struct EmojiReactionPicker: View {
    let onEmojiSelected: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var showCustomEmojiPicker = false
    @State private var customEmoji = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Popular reactions
            VStack(spacing: 16) {
                Text("React with an emoji")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                // Popular emoji grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 12) {
                    ForEach(PopularReactions.getPopularEmojis(), id: \.self) { emoji in
                        Button(action: {
                            onEmojiSelected(emoji)
                        }) {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            Circle()
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                )
                                .scaleEffect(1.0)
                                .animation(.easeInOut(duration: 0.1), value: emoji)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                
                // Custom emoji button
                Button(action: {
                    showCustomEmojiPicker = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 16, weight: .medium))
                        Text("Choose emoji")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.bumpinPurple)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.bumpinPurple.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.bumpinPurple.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.top, 8)
                
                // Cancel button
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                        )
                }
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .sheet(isPresented: $showCustomEmojiPicker) {
            CustomEmojiPickerView { selectedEmoji in
                onEmojiSelected(selectedEmoji)
                showCustomEmojiPicker = false
            }
        }
    }
}

// MARK: - Custom Emoji Picker View

struct CustomEmojiPickerView: View {
    let onEmojiSelected: (String) -> Void
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    // Extended emoji categories
    private let emojiCategories: [String: [String]] = [
        "Smileys": ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "☺️", "😚", "😙", "🥲", "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬", "🤥", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "🥴", "😵", "🤯", "🤠", "🥳", "🥸", "😎", "🤓", "🧐"],
        "Hearts": ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟"],
        "Gestures": ["👍", "👎", "👌", "🤌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👏", "🙌", "👐", "🤲", "🤝", "🙏"],
        "Faces": ["🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "😮", "😯", "😲", "😳", "🥱", "😖", "😣", "😞", "😟", "😕"],
        "Fire & Energy": ["🔥", "⚡", "💥", "💫", "⭐", "🌟", "✨", "💯", "🚀", "💪", "🎯", "🎉", "🎊", "🥇", "🏆", "🎖️", "🏅"]
    ]
    
    private var filteredEmojis: [String] {
        if searchText.isEmpty {
            return emojiCategories.values.flatMap { $0 }
        } else {
            return emojiCategories.values.flatMap { $0 }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search emojis", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 12) {
                        ForEach(filteredEmojis, id: \.self) { emoji in
                            Button(action: {
                                onEmojiSelected(emoji)
                                dismiss()
                            }) {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(Color(.systemGray6))
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Preview

#Preview {
    EmojiReactionPicker(
        onEmojiSelected: { emoji in
            print("Selected emoji: \(emoji)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .padding()
}
