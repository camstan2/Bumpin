import Foundation
import FirebaseFirestore
import FirebaseAuth

struct ContentReport: Identifiable, Codable {
    let id: String
    let reporterId: String
    let targetType: String // "log" | "user"
    let targetId: String
    let reason: String
    let createdAt: Date
}

enum ReportTarget {
    case log(logId: String)
    case user(userId: String)
}

final class ReportsService {
    static let shared = ReportsService()
    private init() {}
    private let db = Firestore.firestore()

    @discardableResult
    func report(target: ReportTarget, reason: String = "inappropriate") async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let id = UUID().uuidString
        let (type, targetId): (String, String) = {
            switch target {
            case .log(let logId): return ("log", logId)
            case .user(let userId): return ("user", userId)
            }
        }()
        let report = ContentReport(id: id, reporterId: uid, targetType: type, targetId: targetId, reason: reason, createdAt: Date())
        do {
            try db.collection("reports").document(id).setData(from: report)
            return true
        } catch {
            return false
        }
    }
}


