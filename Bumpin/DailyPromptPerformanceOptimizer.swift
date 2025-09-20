import Foundation
import SwiftUI
import Combine

// MARK: - Daily Prompt Performance Optimizer

class DailyPromptPerformanceOptimizer {
    static let shared = DailyPromptPerformanceOptimizer()
    private init() {}
    
    // MARK: - Caching Configuration
    
    struct CacheConfig {
        static let activePromptTTL: TimeInterval = 300 // 5 minutes
        static let leaderboardTTL: TimeInterval = 60 // 1 minute
        static let userStatsTTL: TimeInterval = 600 // 10 minutes
        static let interactionsTTL: TimeInterval = 30 // 30 seconds
        static let maxCachedResponses = 50
        static let maxCachedComments = 100
    }
    
    // MARK: - Memory Management
    
    /// Optimize memory usage for large response lists
    func optimizeResponseDisplay(_ responses: [PromptResponse]) -> [PromptResponse] {
        // Limit responses shown at once to prevent memory issues
        let maxDisplayed = 20
        return Array(responses.prefix(maxDisplayed))
    }
    
    /// Clean up unused listeners and cached data
    @MainActor
    func cleanupUnusedData(coordinator: DailyPromptCoordinator) {
        // Remove listeners for responses no longer visible
        let visibleResponseIds = Set(coordinator.promptService.promptHistory
            .flatMap { _ in [] as [String] }) // Would contain visible response IDs
        
        // Clean up interaction service cached data
        let cachedResponseIds = Set(coordinator.interactionService.responseLikes.keys)
        let unusedResponseIds = cachedResponseIds.subtracting(visibleResponseIds)
        
        for responseId in unusedResponseIds {
            coordinator.interactionService.stopListenersForResponse(responseId)
        }
    }
    
    // MARK: - Query Optimization
    
    /// Optimize Firestore queries for better performance
    struct QueryOptimizations {
        
        /// Batch user ID queries to minimize round trips
        static func batchUserQueries(_ userIds: [String]) -> [[String]] {
            return userIds.chunked(into: 10) // Firestore 'in' query limit
        }
        
        /// Optimize response fetching with pagination
        static func getOptimalPageSize(deviceType: UIUserInterfaceIdiom) -> Int {
            switch deviceType {
            case .phone:
                return 20
            case .pad:
                return 30
            default:
                return 25
            }
        }
        
        /// Prioritize queries based on user interaction patterns
        static func getPriorityQueries() -> [String] {
            return [
                "activePrompt",      // Highest priority
                "userResponse",      // High priority
                "leaderboard",       // Medium priority
                "friendsResponses",  // Medium priority
                "allResponses"       // Lower priority
            ]
        }
    }
    
    // MARK: - UI Performance
    
    /// Optimize list rendering performance
    func optimizeListRendering() -> some View {
        // Return optimized LazyVStack configuration
        return AnyView(
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                // Pinned headers for better navigation
            }
        )
    }
    
    /// Debounce user input for better performance
    func debounceInput<T: Equatable>(
        _ input: T,
        delay: TimeInterval = 0.3,
        action: @escaping (T) -> Void
    ) -> AnyCancellable {
        
        return Just(input)
            .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { value in
                action(value)
            }
    }
    
    // MARK: - Image Loading Optimization
    
    /// Optimize artwork loading with proper sizing
    func getOptimalImageSize(for context: ImageContext) -> CGSize {
        switch context {
        case .responseCard:
            return CGSize(width: 120, height: 120)
        case .leaderboardRow:
            return CGSize(width: 80, height: 80)
        case .compactCard:
            return CGSize(width: 60, height: 60)
        case .userAvatar:
            return CGSize(width: 40, height: 40)
        }
    }
    
    enum ImageContext {
        case responseCard
        case leaderboardRow
        case compactCard
        case userAvatar
    }
    
    // MARK: - Background Task Optimization
    
    /// Configure background refresh for prompt data
    func configureBackgroundRefresh() {
        // This would integrate with your existing BGRefreshManager
        print("🔄 Configuring background refresh for daily prompts")
        
        // Priority order for background updates:
        // 1. Active prompt status
        // 2. User response status
        // 3. Leaderboard updates
        // 4. Social interactions
    }
    
    // MARK: - Network Optimization
    
    /// Optimize network requests for cellular users
    func optimizeForCellularConnection() -> NetworkOptimizationConfig {
        return NetworkOptimizationConfig(
            reduceImageQuality: true,
            limitConcurrentRequests: 3,
            enableRequestCoalescing: true,
            prefetchOnWiFiOnly: true
        )
    }
    
    struct NetworkOptimizationConfig {
        let reduceImageQuality: Bool
        let limitConcurrentRequests: Int
        let enableRequestCoalescing: Bool
        let prefetchOnWiFiOnly: Bool
    }
    
    // MARK: - Device-Specific Optimizations
    
    /// Optimize based on device capabilities
    func optimizeForDevice() -> DeviceOptimizationConfig {
        let device = UIDevice.current
        let memory = ProcessInfo.processInfo.physicalMemory
        
        return DeviceOptimizationConfig(
            maxCachedItems: memory > 4_000_000_000 ? 100 : 50, // 4GB+ RAM
            enableAnimations: !UIAccessibility.isReduceMotionEnabled,
            imageQuality: memory > 2_000_000_000 ? .high : .medium,
            preloadDistance: device.userInterfaceIdiom == .pad ? 10 : 5
        )
    }
    
    struct DeviceOptimizationConfig {
        let maxCachedItems: Int
        let enableAnimations: Bool
        let imageQuality: ImageQuality
        let preloadDistance: Int
        
        enum ImageQuality {
            case low, medium, high
            
            var compressionQuality: CGFloat {
                switch self {
                case .low: return 0.5
                case .medium: return 0.7
                case .high: return 0.9
                }
            }
        }
    }
}

// Note: chunked(into:) extension already exists in UserProfileViewModel

// MARK: - Performance Monitoring

class DailyPromptPerformanceMonitor: ObservableObject {
    @Published var loadingTimes: [String: TimeInterval] = [:]
    @Published var errorCounts: [String: Int] = [:]
    @Published var memoryUsage: Double = 0.0
    
    private var startTimes: [String: Date] = [:]
    
    func startTiming(_ operation: String) {
        startTimes[operation] = Date()
    }
    
    func endTiming(_ operation: String) {
        guard let startTime = startTimes[operation] else { return }
        let duration = Date().timeIntervalSince(startTime)
        loadingTimes[operation] = duration
        
        // Track in analytics
        DailyPromptAnalytics.shared.trackLoadingPerformance(operation, loadTime: duration)
        
        startTimes.removeValue(forKey: operation)
    }
    
    func recordError(_ operation: String, error: Error) {
        errorCounts[operation] = (errorCounts[operation] ?? 0) + 1
        
        // Track in analytics
        DailyPromptAnalytics.shared.trackError(operation, errorMessage: error.localizedDescription)
    }
    
    func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }
    }
}

// MARK: - Performance Testing View

struct DailyPromptPerformanceTestView: View {
    @StateObject private var monitor = DailyPromptPerformanceMonitor()
    @StateObject private var coordinator = DailyPromptCoordinator()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Memory usage
                    VStack(spacing: 8) {
                        Text("Memory Usage")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("\(String(format: "%.1f", monitor.memoryUsage)) MB")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    
                    // Loading times
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Loading Performance")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        ForEach(Array(monitor.loadingTimes.keys.sorted()), id: \.self) { operation in
                            HStack {
                                Text(operation)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                if let time = monitor.loadingTimes[operation] {
                                    Text("\(String(format: "%.2f", time))s")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(time > 1.0 ? .red : .green)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    
                    // Performance test buttons
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        
                        performanceTestButton("Load Prompt") {
                            monitor.startTiming("loadPrompt")
                            Task {
                                await coordinator.promptService.loadActivePrompt()
                                await MainActor.run {
                                    monitor.endTiming("loadPrompt")
                                }
                            }
                        }
                        
                        performanceTestButton("Load Leaderboard") {
                            monitor.startTiming("loadLeaderboard")
                            Task {
                                if let promptId = coordinator.currentPrompt?.id {
                                    await coordinator.promptService.loadPromptLeaderboard(promptId: promptId)
                                }
                                await MainActor.run {
                                    monitor.endTiming("loadLeaderboard")
                                }
                            }
                        }
                        
                        performanceTestButton("Memory Check") {
                            monitor.updateMemoryUsage()
                        }
                        
                        performanceTestButton("Stress Test") {
                            stressTestPerformance()
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Performance Testing")
            .onAppear {
                monitor.updateMemoryUsage()
            }
        }
    }
    
    private func performanceTestButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func stressTestPerformance() {
        monitor.startTiming("stressTest")
        
        Task {
            // Simulate multiple concurrent operations
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<10 {
                    group.addTask {
                        await coordinator.promptService.loadPromptHistory(limit: 10)
                    }
                }
            }
            
            await MainActor.run {
                monitor.endTiming("stressTest")
                monitor.updateMemoryUsage()
            }
        }
    }
}

#Preview {
    DailyPromptPerformanceTestView()
}
