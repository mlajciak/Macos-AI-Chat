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
    var attachmentImagePaths: [String]
    let createdAt: TimeInterval

    init(
        id: String,
        role: ChatRole,
        content: String,
        toolCards: [AgentToolCard] = [],
        attachmentImagePaths: [String] = [],
        createdAt: TimeInterval
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCards = toolCards
        self.attachmentImagePaths = attachmentImagePaths
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, role, content, toolCards, attachmentImagePaths, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        role = try container.decode(ChatRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        toolCards = try container.decodeIfPresent([AgentToolCard].self, forKey: .toolCards) ?? []
        attachmentImagePaths = try container.decodeIfPresent([String].self, forKey: .attachmentImagePaths) ?? []
        createdAt = try container.decode(TimeInterval.self, forKey: .createdAt)
    }

    var hasVisibleContent: Bool {
        !content.isEmpty
            || !attachmentImagePaths.isEmpty
            || toolCards.contains {
                !$0.body.isEmpty || !$0.argsPreview.isEmpty || !$0.imagePaths.isEmpty
            }
    }
}
