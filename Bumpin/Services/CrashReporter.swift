import Foundation
import UIKit
import os.log

class CrashReporter {
    static let shared = CrashReporter()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bumpin.app", category: "CrashReporter")
    
    private init() {
        setupExceptionHandler()
    }
    
    private func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }
        
        signal(SIGABRT) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        
        signal(SIGILL) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        
        signal(SIGSEGV) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        
        signal(SIGFPE) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        
        signal(SIGBUS) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        
        signal(SIGPIPE) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
    }
    
    private func handleException(_ exception: NSException) {
        let crashInfo = CrashInfo(
            type: .exception,
            name: exception.name.rawValue,
            reason: exception.reason ?? "Unknown reason",
            stackTrace: exception.callStackSymbols.joined(separator: "\n"),
            timestamp: Date()
        )
        
        reportCrash(crashInfo)
    }
    
    private func handleSignal(_ signal: Int32) {
        let crashInfo = CrashInfo(
            type: .signal,
            name: "Signal \(signal)",
            reason: signalDescription(signal),
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            timestamp: Date()
        )
        
        reportCrash(crashInfo)
    }
    
    private func signalDescription(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT - Abort signal"
        case SIGILL: return "SIGILL - Illegal instruction"
        case SIGSEGV: return "SIGSEGV - Segmentation violation"
        case SIGFPE: return "SIGFPE - Floating point exception"
        case SIGBUS: return "SIGBUS - Bus error"
        case SIGPIPE: return "SIGPIPE - Broken pipe"
        default: return "Unknown signal"
        }
    }
    
    private func reportCrash(_ crashInfo: CrashInfo) {
        // Log to system
        logger.critical("💥 CRASH DETECTED: \(crashInfo.name) - \(crashInfo.reason)")
        
        // Save crash report locally
        saveCrashReport(crashInfo)
        
        // Report to analytics
        AnalyticsService.shared.logCrash(
            error: "\(crashInfo.name): \(crashInfo.reason)",
            stackTrace: crashInfo.stackTrace
        )
        
        // In a production app, you would also send this to your crash reporting service
        // For example: Firebase Crashlytics, Sentry, etc.
    }
    
    private func saveCrashReport(_ crashInfo: CrashInfo) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let crashReportsDirectory = documentsDirectory.appendingPathComponent("CrashReports")
        
        try? FileManager.default.createDirectory(at: crashReportsDirectory, withIntermediateDirectories: true)
        
        let filename = "crash_\(Int(crashInfo.timestamp.timeIntervalSince1970)).txt"
        let fileURL = crashReportsDirectory.appendingPathComponent(filename)
        
        let crashReport = """
        BUMPIN CRASH REPORT
        ===================
        
        Timestamp: \(crashInfo.timestamp)
        Type: \(crashInfo.type.rawValue)
        Name: \(crashInfo.name)
        Reason: \(crashInfo.reason)
        
        Stack Trace:
        \(crashInfo.stackTrace)
        
        Device Info:
        - iOS Version: \(UIDevice.current.systemVersion)
        - Device Model: \(UIDevice.current.model)
        - App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        - Build Number: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
        """
        
        try? crashReport.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func logNonFatalError(_ error: Error, context: String) {
        logger.error("⚠️ NON-FATAL ERROR in \(context): \(error.localizedDescription)")
        
        AnalyticsService.shared.logError(error: error, context: context)
    }
    
    func getPendingCrashReports() -> [URL] {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let crashReportsDirectory = documentsDirectory.appendingPathComponent("CrashReports")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: crashReportsDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "txt" }
        } catch {
            return []
        }
    }
    
    func clearCrashReports() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let crashReportsDirectory = documentsDirectory.appendingPathComponent("CrashReports")
        
        try? FileManager.default.removeItem(at: crashReportsDirectory)
    }
    
    func setUserId(_ userId: String?) {
        // Set user ID for crash reporting
        // This would typically be used with Firebase Crashlytics or similar service
        print("🔧 CrashReporter: Setting user ID to \(userId ?? "nil")")
    }
    
    func setKey(_ key: String, value: String) {
        // Set custom key-value pair for crash reporting
        // This would typically be used with Firebase Crashlytics or similar service
        print("🔧 CrashReporter: Setting key \(key) to \(value)")
    }
    
    func logMessage(_ message: String) {
        // Log custom message for crash reporting
        // This would typically be used with Firebase Crashlytics or similar service
        logger.info("CrashReporter Message: \(message)")
    }
}

// MARK: - Data Models

struct CrashInfo {
    let type: CrashType
    let name: String
    let reason: String
    let stackTrace: String
    let timestamp: Date
}

enum CrashType: String {
    case exception = "Exception"
    case signal = "Signal"
}
