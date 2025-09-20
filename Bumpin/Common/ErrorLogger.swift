import Foundation
import FirebaseFirestore

// MARK: - Error Logging System

enum ErrorSeverity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct ErrorLog: Codable {
    let id: String
    let timestamp: Date
    let severity: String
    let category: String
    let message: String
    let file: String
    let function: String
    let line: Int
    let stackTrace: String?
    let userInfo: [String: String]?
    
    init(
        severity: ErrorSeverity,
        category: String,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        stackTrace: String? = Thread.callStackSymbols.joined(separator: "\n"),
        userInfo: [String: String]? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.severity = severity.rawValue
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.stackTrace = stackTrace
        self.userInfo = userInfo
    }
}

@MainActor
class ErrorLogger {
    static let shared = ErrorLogger()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func log(
        _ error: Error,
        severity: ErrorSeverity = .medium,
        category: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        userInfo: [String: String]? = nil
    ) {
        let errorLog = ErrorLog(
            severity: severity,
            category: category,
            message: error.localizedDescription,
            file: file,
            function: function,
            line: line,
            userInfo: userInfo
        )
        
        // Log to console
        print("❌ [\(errorLog.severity.uppercased())] \(errorLog.category): \(errorLog.message)")
        print("📍 \(errorLog.file):\(errorLog.line) - \(errorLog.function)")
        if let info = errorLog.userInfo {
            print("ℹ️ Additional Info:", info)
        }
        
        // Log to Firebase
        Task {
            do {
                try await db.collection("error_logs").document(errorLog.id).setData([
                    "timestamp": errorLog.timestamp,
                    "severity": errorLog.severity,
                    "category": errorLog.category,
                    "message": errorLog.message,
                    "file": errorLog.file,
                    "function": errorLog.function,
                    "line": errorLog.line,
                    "stackTrace": errorLog.stackTrace ?? "",
                    "userInfo": errorLog.userInfo ?? [:],
                    "buildNumber": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "",
                    "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? ""
                ])
            } catch {
                print("⚠️ Failed to save error log: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Usage Extension

extension Error {
    func log(
        severity: ErrorSeverity = .medium,
        category: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        userInfo: [String: String]? = nil
    ) {
        Task { @MainActor in
            ErrorLogger.shared.log(
                self,
                severity: severity,
                category: category,
                file: file,
                function: function,
                line: line,
                userInfo: userInfo
            )
        }
    }
}
