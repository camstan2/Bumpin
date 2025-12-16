import Foundation

/// Centralized helper for safely persisting recently tapped search items.
/// Several views (ComprehensiveSearchView, DiaryMainSearchView, LogMusicSearchView)
/// share the same storage key, so keeping the write safeguards in one place
/// prevents the UserDefaults corruption that was causing freezes.
struct RecentlyTappedStore {
    private static let storageKey = "recently_tapped_items"
    private static let hardLimitBytes = 4_000_000 // Absolute limit enforced by CFPreferences
    private static let softLimitBytes = 1_000_000 // Trim aggressively once we cross ~1 MB
    private static let maxItems = 20

    /// Loads items from UserDefaults with corruption protection.
    static func load(key: String = storageKey) -> [RecentlyTappedItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        if data.count >= hardLimitBytes {
            print("🚨 [RecentlyTappedStore] Data corrupt (>=4MB) for key \(key). Clearing store.")
            UserDefaults.standard.removeObject(forKey: key)
            return []
        }

        do {
            var decoded = try JSONDecoder().decode([RecentlyTappedItem].self, from: data)
            if decoded.count > maxItems {
                decoded = Array(decoded.prefix(maxItems))
            }

            if data.count > softLimitBytes {
                print("⚠️ [RecentlyTappedStore] Data is \(data.count) bytes (>1MB) for key \(key). Trimming.")
                decoded = trimAndPersist(decoded, reason: "soft-limit after load", key: key)
            }

            return decoded
        } catch {
            print("❌ [RecentlyTappedStore] Failed to decode data for key \(key): \(error). Clearing store.")
            UserDefaults.standard.removeObject(forKey: key)
            return []
        }
    }

    /// Persists items with size checks. Returns the array that was actually saved
    /// (it may be trimmed if limits were exceeded).
    @discardableResult
    static func save(_ items: [RecentlyTappedItem], key: String = storageKey) -> [RecentlyTappedItem] {
        var trimmedItems = Array(items.prefix(maxItems))

        guard let data = try? JSONEncoder().encode(trimmedItems) else {
            print("❌ [RecentlyTappedStore] Failed to encode recently tapped items.")
            return trimmedItems
        }

        if data.count >= hardLimitBytes {
            print("🚨 [RecentlyTappedStore] Attempting to save \(data.count) bytes (>=4MB) for key \(key). Trimming aggressively.")
            trimmedItems = trimAndPersist(trimmedItems, reason: "hard-limit during save", key: key)
        } else if data.count > softLimitBytes {
            print("⚠️ [RecentlyTappedStore] Data is \(data.count) bytes (>1MB) for key \(key). Trimming.")
            trimmedItems = trimAndPersist(trimmedItems, reason: "soft-limit during save", key: key)
        } else {
            UserDefaults.standard.set(data, forKey: key)
        }

        return trimmedItems
    }

    /// Trims the list to half the max size and persists the trimmed data.
    @discardableResult
    private static func trimAndPersist(_ items: [RecentlyTappedItem], reason: String, key: String) -> [RecentlyTappedItem] {
        let trimmed = Array(items.prefix(maxItems / 2))

        if let trimmedData = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(trimmedData, forKey: key)
            print("✅ [RecentlyTappedStore] Trimmed to \(trimmed.count) items (\(reason)) for key \(key).")
            return trimmed
        } else {
            print("❌ [RecentlyTappedStore] Failed to encode trimmed items for key \(key). Clearing store.")
            UserDefaults.standard.removeObject(forKey: key)
            return []
        }
    }
}

