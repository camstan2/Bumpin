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
        self.artworkURL = RecentItem.sanitizedArtworkURL(artworkURL)
        self.date = date
    }
    
    private static func sanitizedArtworkURL(_ urlString: String?) -> String? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        
        if urlString.hasPrefix("data:image") {
            print("⚠️ [RecentItem] Dropping inline artwork URL (data URI too large)")
            return nil
        }
        
        if urlString.count > 4096 {
            print("⚠️ [RecentItem] Dropping artwork URL longer than 4096 characters")
            return nil
        }
        
        return urlString
    }
}

final class RecentItemsStore: ObservableObject {
    @Published private(set) var items: [RecentItem] = []
    private let defaultsKey = "recent_items_tapped"
    private let maxItems = 30 // Reduced from 50 to prevent UserDefaults bloat
    private let maxDataSize = 1_000_000 // 1MB max (UserDefaults limit is 4MB, but stay well below)
    
    init() { load() }
    
    func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            print("📦 No existing recent items data found - starting fresh")
            return
        }
        
        // Check data size
        let dataSizeMB = Double(data.count) / 1_048_576.0 // Convert to MB
        let dataSizeKB = Double(data.count) / 1024.0
        
        print("📦 Loading recent items: \(dataSizeKB) KB (\(String(format: "%.2f", dataSizeMB)) MB)")
        
        // Critical: If data is corrupted (>= 4MB), clear it immediately
        if data.count >= 4_000_000 {
            print("🚨 CRITICAL: Recent items data is corrupted (\(String(format: "%.2f", dataSizeMB)) MB >= 4MB limit)")
            print("🗑️  Clearing corrupted data to prevent app freeze...")
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            UserDefaults.standard.synchronize()
            self.items = []
            print("✅ Corrupted data cleared successfully - starting fresh")
            return
        }
        
        // Try to decode the data
        do {
            let decoded = try JSONDecoder().decode([RecentItem].self, from: data)
            // Sanitize any oversized artwork URLs that may have been written by old versions
            let sanitized = decoded.map { item -> RecentItem in
                if let url = item.artworkURL {
                    if url.hasPrefix("data:image") || url.count > 4096 {
                        var modified = item
                        modified = RecentItem(id: item.id, type: item.type, itemId: item.itemId, title: item.title, subtitle: item.subtitle, artworkURL: nil, date: item.date)
                        return modified
                    }
                }
                return item
            }
            if sanitized != decoded {
                // Persist sanitized version to ensure corruption is cleared
                if let safeData = try? JSONEncoder().encode(sanitized) {
                    UserDefaults.standard.set(safeData, forKey: defaultsKey)
                }
            }
            self.items = sanitized.sorted { $0.date > $1.date }
            print("✅ Successfully loaded \(self.items.count) recent items")
            
            // If data is too large (but under 4MB), trim it
            if data.count > maxDataSize {
                print("⚠️ Recent items data too large (\(dataSizeKB) KB), trimming to \(maxItems/2) items")
                self.items = Array(self.items.prefix(maxItems / 2))
                persist()
            }
        } catch {
            print("❌ Failed to decode recent items data: \(error)")
            print("🗑️  Clearing corrupted data...")
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            UserDefaults.standard.synchronize()
            self.items = []
            print("✅ Cleared corrupted data - starting fresh")
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
        guard let data = try? JSONEncoder().encode(items) else {
            print("❌ Failed to encode recent items")
            return
        }
        
        let dataSizeKB = Double(data.count) / 1024.0
        let dataSizeMB = Double(data.count) / 1_048_576.0
        
        // Critical safety check: prevent corruption
        if data.count >= 4_000_000 {
            print("🚨 CRITICAL: Attempting to save \(String(format: "%.2f", dataSizeMB)) MB (>= 4MB limit)!")
            print("🛑 BLOCKING save to prevent corruption - trimming to \(maxItems/2) items")
            let trimmedItems = Array(items.prefix(maxItems / 2))
            
            if let trimmedData = try? JSONEncoder().encode(trimmedItems) {
                let trimmedSizeKB = Double(trimmedData.count) / 1024.0
                print("✅ Trimmed to \(trimmedItems.count) items (\(trimmedSizeKB) KB)")
                UserDefaults.standard.set(trimmedData, forKey: defaultsKey)
                items = trimmedItems
                logUserDefaultsWrite(key: defaultsKey, size: trimmedData.count)
            }
            return
        }
        
        // Safety check: if data is too large, trim items
        if data.count > maxDataSize {
            print("⚠️ Recent items data too large (\(dataSizeKB) KB), trimming...")
            let trimmedItems = Array(items.prefix(maxItems / 2))
            
            if let trimmedData = try? JSONEncoder().encode(trimmedItems) {
                let trimmedSizeKB = Double(trimmedData.count) / 1024.0
                print("✅ Trimmed to \(trimmedItems.count) items (\(trimmedSizeKB) KB)")
                UserDefaults.standard.set(trimmedData, forKey: defaultsKey)
                items = trimmedItems
                logUserDefaultsWrite(key: defaultsKey, size: trimmedData.count)
            }
        } else {
            print("💾 Saving \(items.count) recent items (\(dataSizeKB) KB)")
            UserDefaults.standard.set(data, forKey: defaultsKey)
            logUserDefaultsWrite(key: defaultsKey, size: data.count)
        }
    }
    
    // MARK: - Comprehensive Logging
    
    private func logUserDefaultsWrite(key: String, size: Int) {
        let sizeKB = Double(size) / 1024.0
        let sizeMB = Double(size) / 1_048_576.0
        
        // Log individual writes if they're large (over 500KB)
        if size > 500_000 {
            print("📊 [UserDefaults Write] key: \(key), size: \(String(format: "%.2f", sizeMB)) MB (\(Int(sizeKB)) KB)")
        }
        
        // Note: Total UserDefaults size logging removed to prevent crashes
        // Individual write protection (blocks >= 4MB, trims > 1MB) is sufficient
    }
}
