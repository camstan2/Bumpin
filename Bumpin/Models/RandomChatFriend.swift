import Foundation

struct RandomChatFriend: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let status: String
    var isInvited: Bool = false
    var hasAccepted: Bool = false
    
    static func == (lhs: RandomChatFriend, rhs: RandomChatFriend) -> Bool {
        return lhs.id == rhs.id
    }
}
