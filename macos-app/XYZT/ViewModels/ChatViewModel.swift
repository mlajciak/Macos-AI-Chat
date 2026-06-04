import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    var threads: [ChatThread]
    var activeThreadId: String
    var selectedProjectId: String
    var selectedModelId = ""
    var isSessionBrowserOpen = false
    var isSettingsOpen = false
    var isExpandedSidebarVisible = true
    var onExpandedSidebarVisibilityChanged: (() -> Void)?
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
    }

    var menuModels: [ChatModel] {
        preferences.menuModels
    }

    func syncSelectedModel() {
        let models = menuModels
        if models.contains(where: { $0.id == selectedModelId }) { return }
        selectedModelId = models.first?.id ?? ""
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
            messages: session.messages,
            modelId: selectedModelId,
            apiKey: preferences.openRouterApiKey
        )
    }

    func stopGeneration() {
        activeGenerationTask?.cancel()
    }

    private func startGeneration(messages: [ChatMessage], modelId: String, apiKey: String) {
        activeGenerationTask?.cancel()
        let threadId = activeThreadId
        let replyAt = Date().timeIntervalSince1970
        let assistantId = UUID().uuidString

        activeGenerationTask = Task {
            var startedMessage = false
            var pendingThinkingCard: AgentToolCard?

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
                try await ChatAgent.streamReply(
                    messages: messages,
                    modelId: modelId,
                    apiKey: apiKey
                ) { event in
                    switch event {
                    case let .thinkingStart(card):
                        pendingThinkingCard = card
                        if !startedMessage {
                            self.applyGeneration(on: threadId) { thread in
                                thread.session.reduce(.startAssistantMessage(id: assistantId, createdAt: replyAt))
                            }
                            startedMessage = true
                        }
                        self.applyGeneration(on: threadId) { thread in
                            thread.session.reduce(.startToolCard(messageId: assistantId, card: card))
                            thread.session.reduce(.setToolExpanded(
                                messageId: assistantId,
                                toolId: card.id,
                                isExpanded: true
                            ))
                        }
                        pendingThinkingCard = nil
                    case let .thinkingDelta(cardId, delta):
                        if !startedMessage {
                            self.applyGeneration(on: threadId) { thread in
                                thread.session.reduce(.startAssistantMessage(id: assistantId, createdAt: replyAt))
                            }
                            startedMessage = true
                        }
                        self.applyGeneration(on: threadId) { thread in
                            if let pending = pendingThinkingCard {
                                thread.session.reduce(.startToolCard(messageId: assistantId, card: pending))
                                thread.session.reduce(.setToolExpanded(
                                    messageId: assistantId,
                                    toolId: pending.id,
                                    isExpanded: true
                                ))
                                pendingThinkingCard = nil
                            }
                            thread.session.reduce(.appendToolBody(
                                messageId: assistantId,
                                toolId: cardId,
                                delta: delta
                            ))
                        }
                    case .thinkingEnd:
                        pendingThinkingCard = nil
                    case let .textDelta(delta):
                        pendingThinkingCard = nil
                        if !startedMessage {
                            self.applyGeneration(on: threadId) { thread in
                                thread.session.reduce(.startAssistantMessage(id: assistantId, createdAt: replyAt))
                            }
                            startedMessage = true
                        }
                        self.applyGeneration(on: threadId) { thread in
                            thread.session.reduce(.appendAssistantText(id: assistantId, delta: delta))
                        }
                    }
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
