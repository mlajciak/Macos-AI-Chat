import Foundation

enum SessionEvent {
    case sendUser(content: String, id: String, createdAt: TimeInterval)
    case appendAssistant(content: String, id: String, createdAt: TimeInterval)
    case startAssistantMessage(id: String, createdAt: TimeInterval)
    case appendAssistantText(id: String, delta: String)
    case startToolCard(messageId: String, card: AgentToolCard)
    case appendToolBody(messageId: String, toolId: String, delta: String)
    case setToolExpanded(messageId: String, toolId: String, isExpanded: Bool)
    case beginAssistantReply
    case completeAssistantReply
    case clear
}

struct ChatSessionState: Codable {
    var messages: [ChatMessage] = []
    var pendingReplyCount = 0

    var isStreaming: Bool { pendingReplyCount > 0 }

    static func create() -> ChatSessionState {
        ChatSessionState()
    }

    mutating func reduce(_ event: SessionEvent) {
        switch event {
        case let .sendUser(content, id, createdAt):
            messages.append(
                ChatMessage(id: id, role: .user, content: content, createdAt: createdAt)
            )
        case let .appendAssistant(content, id, createdAt):
            messages.append(
                ChatMessage(id: id, role: .assistant, content: content, createdAt: createdAt)
            )
        case let .startAssistantMessage(id, createdAt):
            guard !messages.contains(where: { $0.id == id }) else { return }
            messages.append(
                ChatMessage(id: id, role: .assistant, content: "", createdAt: createdAt)
            )
        case let .appendAssistantText(id, delta):
            guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
            messages[index].content += delta
        case let .startToolCard(messageId, card):
            guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
            if messages[index].toolCards.contains(where: { $0.id == card.id }) { return }
            messages[index].toolCards.append(card)
        case let .appendToolBody(messageId, toolId, delta):
            guard let index = messages.firstIndex(where: { $0.id == messageId }),
                  let toolIndex = messages[index].toolCards.firstIndex(where: { $0.id == toolId })
            else { return }
            messages[index].toolCards[toolIndex].body += delta
        case let .setToolExpanded(messageId, toolId, isExpanded):
            guard let index = messages.firstIndex(where: { $0.id == messageId }),
                  let toolIndex = messages[index].toolCards.firstIndex(where: { $0.id == toolId })
            else { return }
            messages[index].toolCards[toolIndex].isExpanded = isExpanded
        case .beginAssistantReply:
            pendingReplyCount += 1
        case .completeAssistantReply:
            pendingReplyCount = max(0, pendingReplyCount - 1)
        case .clear:
            self = .create()
        }
    }

    func lastUserMessage() -> ChatMessage? {
        messages.last { $0.role == .user }
    }
}
