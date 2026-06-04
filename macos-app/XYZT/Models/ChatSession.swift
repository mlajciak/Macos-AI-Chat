import Foundation

enum SessionEvent {
    case sendUser(content: String, id: String, createdAt: TimeInterval)
    case appendAssistant(content: String, id: String, createdAt: TimeInterval)
    case beginAssistantReply
    case completeAssistantReply
    case clear
}

struct ChatSessionState {
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
