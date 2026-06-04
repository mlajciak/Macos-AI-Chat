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
    var recentlyOpenedProjectIds: [String] = []
    let preferences = AppPreferences()

    var draft: String {
        get { activeThread.draft }
        set { mutateActiveThread { $0.draft = newValue } }
    }

    init() {
        let seed = ChatThreadCatalog.demoThreads()
        threads = seed
        activeThreadId = seed[0].id
        selectedProjectId = seed[0].projectId
        var seenProjects = Set<String>()
        recentlyOpenedProjectIds = seed.compactMap { thread in
            seenProjects.insert(thread.projectId).inserted ? thread.projectId : nil
        }
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
        threads.first { $0.id == activeThreadId }
            ?? threads[0]
    }

    var activeChatTitle: String {
        activeThread.title
    }

    var session: ChatSessionState {
        activeThread.session
    }

    func selectProject(_ projectId: String) {
        selectedProjectId = projectId
        recordProjectOpened(projectId)
        if let thread = threads.last(where: { $0.projectId == projectId }) {
            activeThreadId = thread.id
            touchActiveThread()
        } else {
            let thread = ChatThread.new(projectId: projectId)
            threads.append(thread)
            activeThreadId = thread.id
        }
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""
        let now = Date().timeIntervalSince1970
        let userMessageId = UUID().uuidString
        touchActiveThread()
        mutateActiveThread { thread in
            if thread.title == "New chat" {
                thread.title = Self.titleFromFirstMessage(text)
            }
            thread.session.reduce(.sendUser(content: text, id: userMessageId, createdAt: now))
            thread.session.reduce(.beginAssistantReply)
        }

        let snapshot = session.messages
        let modelId = selectedModelId
        let apiKey = preferences.openRouterApiKey
        Task {
            let replyAt = Date().timeIntervalSince1970
            let assistantId = UUID().uuidString
            var startedMessage = false
            var pendingThinkingCard: AgentToolCard?

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
                    messages: snapshot,
                    modelId: modelId,
                    apiKey: apiKey
                ) { event in
                    switch event {
                    case let .thinkingStart(card):
                        pendingThinkingCard = card
                    case let .thinkingDelta(cardId, delta):
                        if !startedMessage {
                            self.mutateActiveThread { thread in
                                thread.session.reduce(.startAssistantMessage(id: assistantId, createdAt: replyAt))
                            }
                            startedMessage = true
                        }
                        self.mutateActiveThread { thread in
                            if let pending = pendingThinkingCard {
                                thread.session.reduce(.startToolCard(messageId: assistantId, card: pending))
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
                            self.mutateActiveThread { thread in
                                thread.session.reduce(.startAssistantMessage(id: assistantId, createdAt: replyAt))
                            }
                            startedMessage = true
                        }
                        self.mutateActiveThread { thread in
                            thread.session.reduce(.appendAssistantText(id: assistantId, delta: delta))
                        }
                    }
                }
            } catch {
                self.mutateActiveThread { thread in
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
            self.mutateActiveThread { thread in
                thread.session.reduce(.completeAssistantReply)
            }
        }
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
        mutateActiveThread { thread in
            thread.session.reduce(.clear)
            thread.title = "New chat"
        }
        draft = ""
    }

    func mutateActiveThread(_ block: (inout ChatThread) -> Void) {
        guard let index = threads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        block(&threads[index])
    }

    private static func titleFromFirstMessage(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "New chat" }
        let maxLen = 28
        if trimmed.count <= maxLen { return trimmed }
        return String(trimmed.prefix(maxLen)) + "…"
    }
}
