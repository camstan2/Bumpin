import Foundation

class AppleMusicCache {
    static let shared = AppleMusicCache()
    
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Create cache directory
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsDirectory.appendingPathComponent("AppleMusicCache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func store(data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
        
        // Also store to disk for persistence
        let fileURL = cacheDirectory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
        try? data.write(to: fileURL)
    }
    
    func data(forKey key: String) -> Data? {
        // First try memory cache
        if let data = cache.object(forKey: key as NSString) {
            return data as Data
        }
        
        // Then try disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
        if let data = try? Data(contentsOf: fileURL) {
            // Put back in memory cache
            cache.setObject(data as NSData, forKey: key as NSString)
            return data
        }
        
        return nil
    }
    
    func removeData(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
        
        let fileURL = cacheDirectory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clearCache() {
        cache.removeAllObjects()
        
        // Clear disk cache
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    func cacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        
        return totalSize
    }
}
