import SwiftUI
import FirebaseAuth

struct ListenLaterView: View {
    @StateObject private var listenLaterService = ListenLaterService.shared
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedSection: ListenLaterItemType = .song
    @State private var showAddToListenLater = false
    @State private var currentIndex: Int = 0
    
    // Tab configuration
    private let sections: [ListenLaterItemType] = [.song, .album, .artist]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Selector
                tabSelector
                
                // Swipeable Content
                TabView(selection: $currentIndex) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        sectionContent(for: section)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                .onChange(of: currentIndex) { _, newIndex in
                    if newIndex < sections.count {
                        selectedSection = sections[newIndex]
                    }
                }
            }
            .navigationTitle("Listen Later")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        clearCurrentSection()
                    }
                    .foregroundColor(.purple)
                    .disabled(getCurrentSectionItems().isEmpty)
                }
            }
            .overlay(
                // Purple Plus Button
                purplePlusButton,
                alignment: .bottomTrailing
            )
        }
        .onAppear {
            listenLaterService.loadAllSections()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ListenLaterItemAdded"))) { notification in
            print("📢 ListenLaterView received ListenLaterItemAdded notification")
            // Force refresh the service
            listenLaterService.refreshAllSections()
        }
        .sheet(isPresented: $showAddToListenLater) {
            AddToListenLaterView(
                selectedSection: selectedSection,
                listenLaterService: listenLaterService
            )
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentIndex = index
                        selectedSection = section
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.system(size: 16, weight: .medium))
                            Text(section.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(currentIndex == index ? .purple : .secondary)
                        
                        // Underline indicator
                        Rectangle()
                            .fill(currentIndex == index ? Color.purple : Color.clear)
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Section Content
    private func sectionContent(for section: ListenLaterItemType) -> some View {
        let items = listenLaterService.getItems(for: section)
        let isLoading = listenLaterService.isLoading(for: section)
        
        return Group {
            if isLoading {
                loadingView
            } else if items.isEmpty {
                emptyStateView(for: section)
            } else {
                itemsList(items: items, section: section)
            }
        }
        .refreshable {
            listenLaterService.loadAllSections()
        }
    }
    
    // MARK: - Items List
    private func itemsList(items: [ListenLaterItem], section: ListenLaterItemType) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    ListenLaterItemRow(
                        item: item,
                        onTap: {
                            navigateToProfile(item: item)
                        },
                        onRemove: {
                            Task {
                                await listenLaterService.removeItem(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private func emptyStateView(for section: ListenLaterItemType) -> some View {
        VStack(spacing: 24) {
            Image(systemName: section.icon)
                .font(.system(size: 60))
                .foregroundColor(section.color.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No \(section.displayName) Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Add \(section.displayName.lowercased()) you want to listen to later")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showAddToListenLater = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add \(section.displayName)")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(section.color)
                .clipShape(Capsule())
                .shadow(color: section.color.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Purple Plus Button
    private var purplePlusButton: some View {
        Button(action: {
            showAddToListenLater = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100) // Account for tab bar
    }
    
    // MARK: - Helper Methods
    private func getCurrentSectionItems() -> [ListenLaterItem] {
        return listenLaterService.getItems(for: selectedSection)
    }
    
    private func clearCurrentSection() {
        Task {
            await listenLaterService.clearSection(selectedSection)
        }
    }
    
    private func navigateToProfile(item: ListenLaterItem) {
        switch item.itemType {
        case .song, .album:
            let trendingItem = TrendingItem(
                title: item.title,
                subtitle: item.artistName,
                artworkUrl: item.artworkUrl,
                logCount: item.totalRatings,
                averageRating: item.averageRating,
                itemType: item.itemType.rawValue,
                itemId: item.itemId
            )
            navigationCoordinator.navigateToMusicProfile(trendingItem)
        case .artist:
            navigationCoordinator.navigateToArtistProfile(item.artistName)
        }
    }
}

// MARK: - Listen Later Item Row
struct ListenLaterItemRow: View {
    let item: ListenLaterItem
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var showRemoveConfirmation = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 16) {
                // Artwork with enhanced styling
                AsyncImage(url: URL(string: item.artworkUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [item.itemType.color.opacity(0.4), item.itemType.color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: item.itemType.icon)
                                .font(.title2)
                                .foregroundColor(item.itemType.color)
                        )
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: item.itemType.color.opacity(0.2), radius: 3, x: 0, y: 2)
                
                // Content with improved typography
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if item.itemType != .artist {
                        Text(item.artistName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Enhanced rating display
                    HStack(spacing: 8) {
                        if let averageRating = item.averageRating, averageRating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", averageRating))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.1))
                            .clipShape(Capsule())
                            
                            Text("(\(item.totalRatings) ratings)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No ratings yet")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        // Item type badge
                        Text(item.itemType.displayName.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(item.itemType.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.itemType.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Remove button with better styling
                Button(action: {
                    showRemoveConfirmation = true
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red.opacity(0.8))
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 24, height: 24)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: isPressed ? 1 : 4, x: 0, y: isPressed ? 1 : 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .confirmationDialog(
            "Remove from Listen Later",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onRemove()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove \"\(item.title)\" from your Listen Later list?")
        }
    }
}

// MARK: - Preview
#Preview {
    ListenLaterView()
        .environmentObject(NavigationCoordinator())
}
