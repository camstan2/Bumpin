import Foundation
import os.log

/// Centralized logging utility so we can control verbosity across modules.
enum LogCategory: String {
    case general = "general"
    case socialFeed = "social_feed"
    case musicLog = "music_log"
    case auth = "auth"
    case networking = "networking"
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

struct AppLogger {
    private static var loggers: [LogCategory: Logger] = [:]
    
    private static func logger(for category: LogCategory) -> Logger {
        if let existing = loggers[category] { return existing }
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bumpin.app",
                            category: category.rawValue)
        loggers[category] = logger
        return logger
    }
    
    static func log(_ message: String,
                    level: LogLevel = .debug,
                    category: LogCategory = .general) {
        let logger = logger(for: category)
        
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
    
    static func debug(_ message: String, category: LogCategory = .general) {
        log(message, level: .debug, category: category)
    }
    
    static func info(_ message: String, category: LogCategory = .general) {
        log(message, level: .info, category: category)
    }
    
    static func warning(_ message: String, category: LogCategory = .general) {
        log(message, level: .warning, category: category)
    }
    
    static func error(_ message: String, category: LogCategory = .general) {
        log(message, level: .error, category: category)
    }
}

