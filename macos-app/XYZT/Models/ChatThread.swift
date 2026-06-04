import Foundation

struct ChatThread: Identifiable {
    let id: String
    var title: String
    let projectId: String
    var session: ChatSessionState
    var draft: String = ""
    var lastActiveAt: TimeInterval

    var isRunning: Bool { session.isStreaming }

    static func new(projectId: String, title: String = "New chat") -> ChatThread {
        ChatThread(
            id: UUID().uuidString,
            title: title,
            projectId: projectId,
            session: .create(),
            lastActiveAt: Date().timeIntervalSince1970
        )
    }
}

