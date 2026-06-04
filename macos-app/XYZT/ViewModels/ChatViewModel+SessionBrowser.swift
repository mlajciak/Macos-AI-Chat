import AppKit
import Foundation

extension ChatViewModel {
    var activeProject: Project {
        ProjectCatalog.project(id: selectedProjectId)
    }

    /// User-opened folders ordered by most recently opened or touched.
    var recentProjects: [Project] {
        var seen = Set<String>()
        var ordered: [String] = []
        for id in recentlyOpenedProjectIds where ProjectCatalog.isUserProject(id) {
            guard seen.insert(id).inserted else { continue }
            ordered.append(id)
        }
        let byActivity = Set(threads.map(\.projectId).filter { ProjectCatalog.isUserProject($0) })
        for id in byActivity.sorted(by: { projectLastActive($0) > projectLastActive($1) }) {
            guard seen.insert(id).inserted else { continue }
            ordered.append(id)
        }
        return ordered.map { ProjectCatalog.project(id: $0) }
    }

    func threads(for projectId: String) -> [ChatThread] {
        threads
            .filter { $0.projectId == projectId }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    func createNewChat() {
        guard hasWorkspace else {
            openProjectFolder()
            return
        }
        let thread = ChatThread.new(projectId: selectedProjectId)
        threads.insert(thread, at: 0)
        activeThreadId = thread.id
        recordProjectOpened(selectedProjectId)
        persistCurrentProject()
        closeOverlays()
        draft = ""
    }

    func selectThread(_ threadId: String) {
        guard let thread = threads.first(where: { $0.id == threadId }) else { return }
        if hasWorkspace, selectedProjectId != thread.projectId {
            persistCurrentProject()
        }
        activeThreadId = threadId
        selectedProjectId = thread.projectId
        recordProjectOpened(thread.projectId)
        touchActiveThread()
        persistCurrentProject()
        closeOverlays()
    }

    func deleteThread(_ threadId: String) {
        guard hasWorkspace,
              let index = threads.firstIndex(where: { $0.id == threadId })
        else { return }
        let projectId = threads[index].projectId
        let wasActive = threadId == activeThreadId
        threads.remove(at: index)
        let remaining = threads(for: projectId)
        if remaining.isEmpty {
            let thread = ChatThread.new(projectId: projectId)
            threads.append(thread)
            activeThreadId = thread.id
        } else if wasActive {
            activeThreadId = remaining[0].id
        }
        persistCurrentProject()
    }

    func recordProjectOpened(_ projectId: String) {
        recentlyOpenedProjectIds.removeAll { $0 == projectId }
        recentlyOpenedProjectIds.insert(projectId, at: 0)
        Self.saveRecentProjectIds(recentlyOpenedProjectIds)
    }

    func openProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a project folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let project = ProjectCatalog.registerUserFolder(at: url)
        selectProject(project.id)
        persistCurrentProject()
        closeOverlays()
    }

    func touchActiveThread() {
        let now = Date().timeIntervalSince1970
        mutateActiveThread { $0.lastActiveAt = now }
    }

    private func projectLastActive(_ projectId: String) -> TimeInterval {
        threads
            .filter { $0.projectId == projectId }
            .map(\.lastActiveAt)
            .max() ?? 0
    }
}

enum SessionRelativeTime {
    static func label(since epoch: TimeInterval, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince1970 - epoch))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) h ago" }
        let days = hours / 24
        return "\(days) d ago"
    }
}
