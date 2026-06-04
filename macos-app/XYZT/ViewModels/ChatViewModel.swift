import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    var threads: [ChatThread]
    var activeThreadId: String
    var selectedProjectId: String
    var selectedModelId = ""
    var selectedImageModelId = ""
    var isSettingsOpen = false
    var recentlyOpenedProjectIds: [String] = []
    let preferences = AppPreferences()

    private var activeGenerationTask: Task<Void, Never>?

    var draft: String {
        get { activeThread.draft }
        set { mutateActiveThread { $0.draft = newValue } }
    }

    init() {
        threads = []
        activeThreadId = ""
        selectedProjectId = ""
        bootstrapWorkspace()
        syncSelectedModel()
        syncSelectedImageModel()
    }

    var menuModels: [ChatModel] {
        preferences.agentMenuModels
    }

    var imageMenuModels: [ChatModel] {
        preferences.imageMenuModels
    }

    func syncSelectedModel() {
        let models = menuModels
        if models.contains(where: { $0.id == selectedModelId }) { return }
        selectedModelId = models.first?.id ?? ""
    }

    func syncSelectedImageModel() {
        let stored = preferences.selectedImageModelId
        if imageMenuModels.contains(where: { $0.id == stored }) {
            selectedImageModelId = stored
            return
        }
        let fallback = imageMenuModels.first?.id ?? ""
        selectedImageModelId = fallback
        if preferences.selectedImageModelId != fallback {
            preferences.selectedImageModelId = fallback
        }
    }

    var activeThread: ChatThread {
        if let thread = threads.first(where: { $0.id == activeThreadId }) {
            return thread
        }
        return ChatThread.new(projectId: selectedProjectId)
    }

    var activeChatTitle: String {
        activeThread.title
    }

    var session: ChatSessionState {
        activeThread.session
    }

    func selectProject(_ projectId: String) {
        guard ProjectCatalog.isUserProject(projectId) else { return }
        if hasWorkspace, selectedProjectId != projectId {
            persistCurrentProject()
        }
        selectedProjectId = projectId
        recordProjectOpened(projectId)
        loadProjectWorkspace(projectId)
        let projectThreads = threads(for: projectId)
        if let thread = projectThreads.first {
            activeThreadId = thread.id
            touchActiveThread()
        } else {
            let thread = ChatThread.new(projectId: projectId)
            threads.append(thread)
            activeThreadId = thread.id
            persistCurrentProject()
        }
    }

    func send() {
        guard hasWorkspace else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""
        let now = Date().timeIntervalSince1970
        let userMessageId = UUID().uuidString
        let threadId = activeThreadId
        touchActiveThread()
        var needsTitle = false
        mutateActiveThread { thread in
            if thread.title == "New chat" {
                needsTitle = true
                thread.title = Self.titleFromFirstMessage(text)
            }
            thread.session.reduce(.sendUser(content: text, id: userMessageId, createdAt: now))
            thread.session.reduce(.beginAssistantReply)
        }
        if needsTitle {
            scheduleTitleGeneration(userMessage: text, threadId: threadId)
        }

        startGeneration(
            messages: engineeringMessages(for: session.messages, userRequest: text),
            modelId: selectedModelId,
            apiKey: preferences.openRouterApiKey,
            threadId: threadId,
            showWorkspaceCard: preferences.showWorkspaceContextCard
        )
    }

    func stopGeneration() {
        activeGenerationTask?.cancel()
    }

    private func startGeneration(
        messages: [ChatMessage],
        modelId: String,
        apiKey: String,
        threadId: String,
        showWorkspaceCard: Bool
    ) {
        activeGenerationTask?.cancel()
        let replyAt = Date().timeIntervalSince1970
        let assistantId = UUID().uuidString

        activeGenerationTask = Task {
            var startedMessage = false
            var pendingThinkingCard: AgentToolCard?
            var streamingToolId: String?

            defer {
                activeGenerationTask = nil
                finishGeneration(on: threadId)
            }

            do {
                guard preferences.hasOpenRouterApiKey else {
                    throw OpenRouterClient.ClientError.missingApiKey
                }
                guard !modelId.isEmpty else {
                    throw OpenRouterClient.ClientError.http(
                        status: 0,
                        message: "Choose at least one model in Settings."
                    )
                }

                if showWorkspaceCard, let summary = workspaceContextCardSummary() {
                    ensureAssistantMessage(
                        threadId: threadId,
                        assistantId: assistantId,
                        startedMessage: &startedMessage,
                        createdAt: replyAt
                    )
                    let contextCard = AgentToolCard.workspaceContext(
                        id: "workspace-context-\(assistantId)",
                        summary: summary
                    )
                    applyGeneration(on: threadId) { thread in
                        thread.session.reduce(.startToolCard(messageId: assistantId, card: contextCard))
                    }
                }

                let completedCalls = try await ChatAgent.streamReply(
                    messages: messages,
                    modelId: modelId,
                    apiKey: apiKey,
                    includeTools: preferences.enableAgentTools
                ) { event in
                    self.handleAgentEvent(
                        event,
                        threadId: threadId,
                        assistantId: assistantId,
                        startedMessage: &startedMessage,
                        pendingThinkingCard: &pendingThinkingCard,
                        streamingToolId: &streamingToolId
                    )
                }

                if preferences.enableAgentTools, !completedCalls.isEmpty {
                    _ = try await executeToolRound(
                        calls: completedCalls,
                        threadId: threadId,
                        assistantId: assistantId,
                        modelId: modelId,
                        apiKey: apiKey,
                        baseMessages: messages
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.applyGeneration(on: threadId) { thread in
                    if startedMessage {
                        thread.session.reduce(.appendAssistantText(
                            id: assistantId,
                            delta: error.localizedDescription
                        ))
                    } else {
                        thread.session.reduce(.appendAssistant(
                            content: error.localizedDescription,
                            id: assistantId,
                            createdAt: replyAt
                        ))
                    }
                }
            }
        }
    }

    private func ensureAssistantMessage(
        threadId: String,
        assistantId: String,
        startedMessage: inout Bool,
        createdAt: TimeInterval
    ) {
        guard !startedMessage else { return }
        applyGeneration(on: threadId) { thread in
            thread.session.reduce(.startAssistantMessage(id: assistantId, createdAt: createdAt))
        }
        startedMessage = true
    }

    func applyGeneration(on threadId: String, _ block: (inout ChatThread) -> Void) {
        guard let index = threads.firstIndex(where: { $0.id == threadId }) else { return }
        block(&threads[index])
    }

    private func finishGeneration(on threadId: String) {
        applyGeneration(on: threadId) { thread in
            guard thread.session.isStreaming else { return }
            thread.session.reduce(.completeAssistantReply)
        }
        persistCurrentProject()
    }

    func setToolExpanded(messageId: String, toolId: String, isExpanded: Bool) {
        mutateActiveThread { thread in
            thread.session.reduce(.setToolExpanded(
                messageId: messageId,
                toolId: toolId,
                isExpanded: isExpanded
            ))
        }
    }

    func clear() {
        stopGeneration()
        mutateActiveThread { thread in
            thread.session.reduce(.clear)
            thread.title = "New chat"
        }
        draft = ""
    }

    func mutateActiveThread(_ block: (inout ChatThread) -> Void) {
        guard let index = threads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        block(&threads[index])
        persistCurrentProject()
    }

    private static func titleFromFirstMessage(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "New chat" }
        let maxLen = 28
        if trimmed.count <= maxLen { return trimmed }
        return String(trimmed.prefix(maxLen)) + "…"
    }
}
