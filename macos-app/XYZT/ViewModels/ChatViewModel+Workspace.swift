import Foundation

extension ChatViewModel {
    private enum WorkspaceKeys {
        static let recentProjectIds = "xyzt.recentProjectIds"
    }

    fileprivate enum EngineeringContext {
        static let maxFiles = 12
        static let maxPreviewBytes = 2_500
        static let maxContextCharacters = 18_000
        static let skippedDirectories: Set<String> = [
            ".git",
            ".xyzt",
            ".build",
            "DerivedData",
            "build",
            "dist",
            "node_modules",
        ]
        static let engineeringExtensions: Set<String> = [
            "iges",
            "igs",
            "kicad_pcb",
            "kicad_sch",
            "net",
            "step",
            "stp",
        ]
        static let textExtensions: Set<String> = [
            "c",
            "cc",
            "cpp",
            "css",
            "go",
            "h",
            "hpp",
            "html",
            "java",
            "js",
            "json",
            "jsx",
            "md",
            "py",
            "rs",
            "sh",
            "swift",
            "ts",
            "tsx",
            "txt",
            "xml",
            "yaml",
            "yml",
        ]
    }

    /// A user-opened folder is selected and on disk.
    var hasWorkspace: Bool {
        ProjectCatalog.isUserProject(selectedProjectId)
            && ProjectCatalog.folderURL(for: selectedProjectId) != nil
    }

    func engineeringMessages(for messages: [ChatMessage], userRequest: String) -> [ChatMessage] {
        var prepared: [ChatMessage] = [
            ChatMessage(
                id: "xyzt-engineering-system",
                role: .system,
                content: Self.engineeringSystemPrompt(userRequest: userRequest),
                createdAt: 0
            ),
        ]
        if let context = workspaceContextPrompt() {
            prepared.append(
                ChatMessage(
                    id: "xyzt-workspace-context",
                    role: .system,
                    content: context,
                    createdAt: 0
                )
            )
        }
        prepared.append(contentsOf: messages)
        return prepared
    }

    func workspaceContextPrompt() -> String? {
        guard let folderURL = ProjectCatalog.folderURL(for: selectedProjectId) else { return nil }
        let snapshots = Self.workspaceSnapshots(in: folderURL)
        guard !snapshots.isEmpty else { return nil }
        var sections: [String] = [
            "Workspace context from the currently opened folder:",
            folderURL.path,
            "",
            "Use these existing files as factual context. If the task needs a file that is not included, ask to inspect it or use a file-reading tool before changing behavior.",
        ]
        var remainingCharacters = EngineeringContext.maxContextCharacters
        for snapshot in snapshots {
            guard remainingCharacters > 0 else { break }
            let section = snapshot.promptSection(maxCharacters: remainingCharacters)
            sections.append(section)
            remainingCharacters -= section.count
        }
        return sections.joined(separator: "\n\n")
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

    private static func engineeringSystemPrompt(userRequest: String) -> String {
        """
        You are XYZT, an engineering agent for existing software and engineering assets.
        Work from the actual workspace files, keep file-level changes reviewable, and validate with tests, builds, or deterministic checks when possible.
        For CAD, EDA, and 3D work, prefer editable source representations such as source code, CAD scripts, STEP/IGES summaries, KiCad data, Blender Python, USD, or scene graphs.
        Use image generation only as an artifact-producing tool: create references, textures, masks, or concepts, then compare rendered outputs and validation reports against the request. Do not treat image prompts or generated concepts as proof that a 3D asset is correct.
        For 3D modeling, iterate through candidate asset generation, rendered multi-view inspection, deterministic validation, and source edits until the artifact satisfies the request or the remaining issue is explicit.

        Current user request:
        \(userRequest)
        """
    }

    private static func workspaceSnapshots(in folderURL: URL) -> [WorkspaceSnapshot] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var snapshots: [WorkspaceSnapshot] = []
        for case let fileURL as URL in enumerator {
            if snapshots.count >= EngineeringContext.maxFiles { break }
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true {
                if EngineeringContext.skippedDirectories.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard let kind = WorkspaceSnapshot.Kind(fileURL: fileURL) else { continue }
            let relativePath = relativePath(for: fileURL, under: folderURL)
            let size = values?.fileSize ?? 0
            let preview = previewText(from: fileURL, maxBytes: EngineeringContext.maxPreviewBytes)
            snapshots.append(WorkspaceSnapshot(
                relativePath: relativePath,
                kind: kind,
                sizeBytes: size,
                preview: preview
            ))
        }
        return snapshots
    }

    private static func relativePath(for fileURL: URL, under folderURL: URL) -> String {
        let folderPath = folderURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(folderPath) else { return fileURL.lastPathComponent }
        let start = filePath.index(filePath.startIndex, offsetBy: folderPath.count)
        return String(filePath[start...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func previewText(from fileURL: URL, maxBytes: Int) -> String {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return "" }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: maxBytes)
        guard let text = String(data: data, encoding: .utf8) else {
            return "[binary preview unavailable]"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadRecentProjectIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: WorkspaceKeys.recentProjectIds) ?? []
    }

    static func saveRecentProjectIds(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: WorkspaceKeys.recentProjectIds)
    }
}

private struct WorkspaceSnapshot {
    enum Kind: String {
        case engineering = "engineering representation candidate"
        case source = "source/text file"

        init?(fileURL: URL) {
            let ext = fileURL.pathExtension.lowercased()
            if ChatViewModel.EngineeringContext.engineeringExtensions.contains(ext) {
                self = .engineering
            } else if ChatViewModel.EngineeringContext.textExtensions.contains(ext) {
                self = .source
            } else {
                return nil
            }
        }
    }

    let relativePath: String
    let kind: Kind
    let sizeBytes: Int
    let preview: String

    func promptSection(maxCharacters: Int) -> String {
        var lines = [
            "## \(relativePath)",
            "Kind: \(kind.rawValue)",
            "Size: \(sizeBytes) bytes",
        ]
        if preview.isEmpty {
            lines.append("Preview unavailable.")
        } else {
            lines.append("Preview:")
            lines.append(String(preview.prefix(max(0, maxCharacters - lines.joined(separator: "\n").count - 16))))
        }
        return lines.joined(separator: "\n")
    }
}
