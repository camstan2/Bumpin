import SwiftUI

// MARK: - Library Section Row
struct LibrarySectionRow: View {
    let section: LibrarySection
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Section icon
                Circle()
                    .fill(section.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: section.icon)
                            .font(.title2)
                            .foregroundColor(section.color)
                    )
                
                // Section info
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if !section.displayCount.isEmpty {
                        Text(section.displayCount)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Library Item Card (for grids)
struct LibraryItemCard: View {
    let item: LibraryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Artwork
                if let artworkUrl = item.artworkURL, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        artworkPlaceholder
                    }
                    .frame(width: 120, height: 120)
                    .cornerRadius(item.itemType == .artist ? 60 : 8)
                    .clipped()
                } else {
                    artworkPlaceholder
                        .frame(width: 120, height: 120)
                        .cornerRadius(item.itemType == .artist ? 60 : 8)
                }
                
                // Title
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 120, alignment: .leading)
                
                // Subtitle
                if item.itemType != .artist {
                    Text(item.artistName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(width: 120, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: item.itemType.icon)
                    .foregroundColor(.gray)
                    .font(.title2)
            )
    }
}

// MARK: - Library Item Row (for lists)
struct LibraryItemRow: View {
    let item: LibraryItem
    let onTap: () -> Void
    let showArtwork: Bool
    
    init(item: LibraryItem, showArtwork: Bool = true, onTap: @escaping () -> Void) {
        self.item = item
        self.showArtwork = showArtwork
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if showArtwork {
                    // Artwork
                    if let artworkUrl = item.artworkURL, let url = URL(string: artworkUrl) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            artworkPlaceholder
                        }
                        .frame(width: 50, height: 50)
                        .cornerRadius(item.itemType == .artist ? 25 : 6)
                        .clipped()
                    } else {
                        artworkPlaceholder
                            .frame(width: 50, height: 50)
                            .cornerRadius(item.itemType == .artist ? 25 : 6)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(item.artistName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let albumName = item.albumName, !albumName.isEmpty, item.itemType == .song {
                        Text(albumName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Type indicator (optional)
                if item.itemType != .song {
                    Text(item.itemType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.itemType.color.opacity(0.15))
                        .foregroundColor(item.itemType.color)
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: item.itemType.icon)
                    .foregroundColor(.gray)
                    .font(.system(size: showArtwork ? 20 : 16))
            )
    }
}

// MARK: - Playlist Card
struct PlaylistCard: View {
    let playlist: LibraryPlaylist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Playlist artwork
                if let artworkUrl = playlist.artworkURL, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        playlistPlaceholder
                    }
                    .frame(width: 120, height: 120)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    playlistPlaceholder
                        .frame(width: 120, height: 120)
                        .cornerRadius(8)
                }
                
                // Playlist name
                Text(playlist.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 120, alignment: .leading)
                
                // Song count
                Text(playlist.displaySubtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var playlistPlaceholder: some View {
        Rectangle()
            .fill(Color.purple.opacity(0.3))
            .overlay(
                Image(systemName: "music.note.list")
                    .foregroundColor(.purple)
                    .font(.title2)
            )
    }
}

// MARK: - Toggleable Playlist Card (Enhanced with visual states)
struct ToggleablePlaylistCard: View {
    let playlist: LibraryPlaylist
    let isSelected: Bool
    let onTap: () -> Void
    let onToggle: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                // Playlist artwork with disabled state styling
                Group {
                    if let artworkUrl = playlist.artworkURL, let url = URL(string: artworkUrl) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            playlistPlaceholder
                        }
                        .frame(width: 120, height: 120)
                        .cornerRadius(8)
                        .clipped()
                    } else {
                        playlistPlaceholder
                            .frame(width: 120, height: 120)
                            .cornerRadius(8)
                    }
                }
                .opacity(isSelected ? 1.0 : 0.5)
                .saturation(isSelected ? 1.0 : 0.3)
                .overlay(
                    // Disabled overlay
                    !isSelected ? 
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 35, height: 35)
                                )
                        )
                    : nil
                )
                
                // Enhanced selection toggle
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticManager.impact(style: .medium)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                onToggle()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.purple : Color.red)
                                    .frame(width: 28, height: 28)
                                    .shadow(color: isSelected ? .purple.opacity(0.3) : .red.opacity(0.3), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: isSelected ? "checkmark" : "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(isPressed ? 0.9 : 1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onLongPressGesture(minimumDuration: 0) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isPressed = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    isPressed = false
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(8)
                
                // Tap area for playlist navigation (only when enabled)
                if isSelected {
                    Button(action: onTap) {
                        Color.clear
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Playlist name with state styling
            Text(playlist.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 120, alignment: .leading)
                .opacity(isSelected ? 1.0 : 0.7)
            
            // Song count with state styling
            HStack(spacing: 4) {
                Text(playlist.displaySubtitle)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .secondary : Color.secondary.opacity(0.6))
                    .lineLimit(1)
                
                Spacer()
                
                // State indicator
                if !isSelected {
                    Text("DISABLED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .frame(width: 120, alignment: .leading)
        }
        .opacity(isSelected ? 1.0 : 0.5) // Visual feedback for selection state
    }
    
    private var playlistPlaceholder: some View {
        Rectangle()
            .fill(Color.purple.opacity(0.3))
            .overlay(
                Image(systemName: "music.note.list")
                    .foregroundColor(.purple)
                    .font(.title2)
            )
    }
}

// MARK: - Recently Added Card
struct RecentlyAddedCard: View {
    let item: LibraryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Artwork
                if let artworkUrl = item.artworkURL, let url = URL(string: artworkUrl) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        artworkPlaceholder
                    }
                    .frame(width: 100, height: 100)
                    .cornerRadius(item.itemType == .artist ? 50 : 6)
                    .clipped()
                } else {
                    artworkPlaceholder
                        .frame(width: 100, height: 100)
                        .cornerRadius(item.itemType == .artist ? 50 : 6)
                }
                
                // Title
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 100, alignment: .leading)
                
                // Subtitle (artist name)
                if item.itemType != .artist {
                    Text(item.artistName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(width: 100, alignment: .leading)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(item.itemType.color.opacity(0.3))
            .overlay(
                Image(systemName: item.itemType.icon)
                    .foregroundColor(item.itemType.color)
                    .font(.system(size: 24))
            )
    }
}

// MARK: - Library Search Bar
struct LibrarySearchBar: View {
    @Binding var searchText: String
    let onSearchChanged: (String) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16))
            
            TextField("Search your library", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { _, newValue in
                    onSearchChanged(newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    onSearchChanged("")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Library Empty State
struct LibraryEmptyState: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Library Loading View
struct LibraryLoadingView: View {
    let message: String
    
    init(message: String = "Loading your library...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.purple)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Library Section Header
struct LibrarySectionHeader: View {
    let title: String
    let subtitle: String?
    let onSeeAll: (() -> Void)?
    
    init(title: String, subtitle: String? = nil, onSeeAll: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.onSeeAll = onSeeAll
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let onSeeAll = onSeeAll {
                Button("See All", action: onSeeAll)
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Library Section Card
struct LibrarySectionCard: View {
    let section: LibrarySection
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                Circle()
                    .fill(section.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: section.icon)
                            .font(.title2)
                            .foregroundColor(section.color)
                    )
                
                // Title only
                VStack(spacing: 4) {
                    Text(section.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

