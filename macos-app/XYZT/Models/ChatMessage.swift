import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: ChatRole
    let content: String
    let createdAt: TimeInterval
}
