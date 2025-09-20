import Foundation
import Combine

// MARK: - Recent tapped items (song/artist/album/user/list)
enum RecentItemType: String, Codable { case song, artist, album, user, list }

struct RecentItem: Codable, Identifiable, Equatable {
    let id: String
    let type: RecentItemType
    let itemId: String
    let title: String
    let subtitle: String // artist name or @username or list desc
    let artworkURL: String?
    let date: Date
    
    init(id: String = UUID().uuidString,
         type: RecentItemType,
         itemId: String,
         title: String,
         subtitle: String,
         artworkURL: String?,
         date: Date = Date()) {
        self.id = id
        self.type = type
        self.itemId = itemId
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.date = date
    }
}

final class RecentItemsStore: ObservableObject {
    @Published private(set) var items: [RecentItem] = []
    private let defaultsKey = "recent_items_tapped"
    private let maxItems = 50
    
    init() { load() }
    
    func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) {
            self.items = decoded.sorted { $0.date > $1.date }
        }
    }
    
    func upsert(_ item: RecentItem) {
        var list = items
        list.removeAll { $0.type == item.type && $0.itemId == item.itemId }
        list.insert(item, at: 0)
        if list.count > maxItems { list = Array(list.prefix(maxItems)) }
        items = list
        persist()
    }
    
    func remove(atOffsets offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persist()
    }
    
    func remove(_ item: RecentItem) {
        items.removeAll { $0.type == item.type && $0.itemId == item.itemId }
        persist()
    }
    
    func clear() { items = []; persist() }
    
    // Simple sort: most recent first
    func sortedItems() -> [RecentItem] { items.sorted { $0.date > $1.date } }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
