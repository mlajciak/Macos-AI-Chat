import Foundation

extension ChatViewModel {
    private enum WorkspaceKeys {
        static let recentProjectIds = "xyzt.recentProjectIds"
    }

    /// A user-opened folder is selected and on disk.
    var hasWorkspace: Bool {
        ProjectCatalog.isUserProject(selectedProjectId)
            && ProjectCatalog.folderURL(for: selectedProjectId) != nil
    }

    func bootstrapWorkspace() {
        ProjectCatalog.bootstrapRegisteredFolders()
        recentlyOpenedProjectIds = Self.loadRecentProjectIds()
        guard let projectId = recentlyOpenedProjectIds.first,
              ProjectCatalog.isUserProject(projectId)
        else {
            threads = []
            activeThreadId = ""
            selectedProjectId = ""
            return
        }
        selectedProjectId = projectId
        loadProjectWorkspace(projectId)
        let projectThreads = threads(for: projectId)
        if projectThreads.isEmpty {
            let thread = ChatThread.new(projectId: projectId)
            threads.append(thread)
            activeThreadId = thread.id
            persistCurrentProject()
        } else if !projectThreads.contains(where: { $0.id == activeThreadId }) {
            activeThreadId = projectThreads[0].id
        }
    }

    func persistCurrentProject() {
        guard hasWorkspace,
              let folderURL = ProjectCatalog.folderURL(for: selectedProjectId)
        else { return }
        let projectThreads = threads(for: selectedProjectId)
        let workspace = ProjectSessionStore.workspace(
            from: projectThreads,
            activeThreadId: activeThreadId
        )
        ProjectSessionStore.save(workspace, to: folderURL)
        Self.saveRecentProjectIds(recentlyOpenedProjectIds)
    }

    func loadProjectWorkspace(_ projectId: String) {
        guard let folderURL = ProjectCatalog.folderURL(for: projectId) else { return }
        let stored = ProjectSessionStore.load(from: folderURL)
        let loaded = ProjectSessionStore.threads(from: stored)
        replaceThreads(for: projectId, with: loaded)
        if projectId == selectedProjectId,
           let savedActive = stored.activeThreadId,
           threads.contains(where: { $0.id == savedActive }) {
            activeThreadId = savedActive
        }
    }

    func replaceThreads(for projectId: String, with newThreads: [ChatThread]) {
        threads.removeAll { $0.projectId == projectId }
        threads.append(contentsOf: newThreads)
    }

    func resolvedTitleModelId() -> String? {
        switch preferences.chatTitleModelSource {
        case .selectedChatModel:
            let id = selectedModelId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, menuModels.contains(where: { $0.id == id }) else { return nil }
            return id
        case .custom:
            let id = preferences.chatTitleCustomModelId.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : id
        }
    }

    func scheduleTitleGeneration(userMessage: String, threadId: String) {
        guard let modelId = resolvedTitleModelId(),
              preferences.hasOpenRouterApiKey
        else { return }

        let apiKey = preferences.openRouterApiKey
        Task {
            do {
                let title = try await ChatAgent.generateTitle(
                    firstMessage: userMessage,
                    modelId: modelId,
                    apiKey: apiKey
                )
                let sanitized = Self.sanitizeGeneratedTitle(title)
                guard !sanitized.isEmpty else { return }
                applyGeneration(on: threadId) { thread in
                    thread.title = sanitized
                }
                persistCurrentProject()
            } catch {
                // Keep truncated fallback title.
            }
        }
    }

    static func sanitizeGeneratedTitle(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\""), text.hasSuffix("\""), text.count >= 2 {
            text = String(text.dropFirst().dropLast())
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let maxLen = 48
        if text.count > maxLen {
            text = String(text.prefix(maxLen)) + "…"
        }
        return text
    }

    private static func loadRecentProjectIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: WorkspaceKeys.recentProjectIds) ?? []
    }

    static func saveRecentProjectIds(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: WorkspaceKeys.recentProjectIds)
    }
}
