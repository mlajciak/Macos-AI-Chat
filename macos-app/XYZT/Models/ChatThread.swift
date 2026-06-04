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

enum ChatThreadCatalog {
    static func demoThreads() -> [ChatThread] {
        let now = Date().timeIntervalSince1970
        return [
            ChatThread(
                id: "chat-mount-holes",
                title: "Mount holes",
                projectId: ProjectCatalog.defaultProject.id,
                session: .create(),
                lastActiveAt: now - 4 * 60
            ),
            ChatThread(
                id: "chat-bracket-export",
                title: "STEP export",
                projectId: ProjectCatalog.defaultProject.id,
                session: .create(),
                lastActiveAt: now - 38 * 60
            ),
            ChatThread(
                id: "chat-drc",
                title: "DRC review",
                projectId: "sensor-board",
                session: .create(),
                lastActiveAt: now - 12 * 60
            ),
            ChatThread(
                id: "chat-sensor-power",
                title: "Power routing",
                projectId: "sensor-board",
                session: .create(),
                lastActiveAt: now - 3 * 60 * 60
            ),
            ChatThread(
                id: "chat-new",
                title: "New chat",
                projectId: "demo-folder",
                session: .create(),
                lastActiveAt: now - 90
            ),
        ]
    }
}
