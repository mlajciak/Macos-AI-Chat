import Foundation

enum ChatRole: String, Codable {
    case system
    case user
    case assistant
}

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: String
    let role: ChatRole
    var content: String
    var toolCards: [AgentToolCard]
    let createdAt: TimeInterval

    init(
        id: String,
        role: ChatRole,
        content: String,
        toolCards: [AgentToolCard] = [],
        createdAt: TimeInterval
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCards = toolCards
        self.createdAt = createdAt
    }

    var hasVisibleContent: Bool {
        !content.isEmpty || toolCards.contains { !$0.body.isEmpty }
    }
}
