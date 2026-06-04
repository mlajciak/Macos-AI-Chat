import Foundation

/// Persists chat threads under `<project>/.xyzt/sessions.json`.
enum ProjectSessionStore {
    private static let workspaceDirName = ".xyzt"
    private static let sessionsFileName = "sessions.json"

    struct PersistedWorkspace: Codable {
        var threads: [PersistedThread]
        var activeThreadId: String?
    }

    struct PersistedThread: Codable {
        var id: String
        var title: String
        var projectId: String
        var draft: String
        var lastActiveAt: TimeInterval
        var messages: [ChatMessage]
        var pendingReplyCount: Int
    }

    static func load(from projectFolder: URL) -> PersistedWorkspace {
        let fileURL = sessionsFileURL(in: projectFolder)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(PersistedWorkspace.self, from: data)
        else {
            return PersistedWorkspace(threads: [], activeThreadId: nil)
        }
        return decoded
    }

    @discardableResult
    static func save(_ workspace: PersistedWorkspace, to projectFolder: URL) -> Bool {
        let dirURL = projectFolder.appendingPathComponent(workspaceDirName, isDirectory: true)
        let fileURL = sessionsFileURL(in: projectFolder)
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(workspace)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func threads(from workspace: PersistedWorkspace) -> [ChatThread] {
        workspace.threads.map { persisted in
            var session = ChatSessionState()
            session.messages = persisted.messages
            session.pendingReplyCount = persisted.pendingReplyCount
            return ChatThread(
                id: persisted.id,
                title: persisted.title,
                projectId: persisted.projectId,
                session: session,
                draft: persisted.draft,
                lastActiveAt: persisted.lastActiveAt
            )
        }
    }

    static func workspace(
        from threads: [ChatThread],
        activeThreadId: String?
    ) -> PersistedWorkspace {
        PersistedWorkspace(
            threads: threads.map { thread in
                PersistedThread(
                    id: thread.id,
                    title: thread.title,
                    projectId: thread.projectId,
                    draft: thread.draft,
                    lastActiveAt: thread.lastActiveAt,
                    messages: thread.session.messages,
                    pendingReplyCount: thread.session.pendingReplyCount
                )
            },
            activeThreadId: activeThreadId
        )
    }

    private static func sessionsFileURL(in projectFolder: URL) -> URL {
        projectFolder
            .appendingPathComponent(workspaceDirName, isDirectory: true)
            .appendingPathComponent(sessionsFileName, isDirectory: false)
    }
}
