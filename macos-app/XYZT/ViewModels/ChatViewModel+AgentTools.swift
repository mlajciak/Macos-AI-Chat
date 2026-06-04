import Foundation

extension ChatViewModel {
    func resolveImagePath(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("data:") {
            return trimmed
        }
        if trimmed.hasPrefix("file://"), let url = URL(string: trimmed) {
            return url.path
        }
        if trimmed.hasPrefix("/") {
            return trimmed
        }
        guard let folder = ProjectCatalog.folderURL(for: selectedProjectId) else {
            return trimmed
        }
        return folder.appendingPathComponent(trimmed).path
    }

    func workspaceContextCardSummary() -> String? {
        guard let prompt = workspaceContextPrompt() else { return nil }
        let maxLen = 2_400
        if prompt.count <= maxLen { return prompt }
        return String(prompt.prefix(maxLen)) + "\n\n[truncated in card preview]"
    }

    func respondToToolApproval(
        messageId: String,
        toolId: String,
        approved: Bool
    ) {
        guard let threadIndex = threads.firstIndex(where: { $0.id == activeThreadId }),
              let messageIndex = threads[threadIndex].session.messages.firstIndex(where: { $0.id == messageId }),
              let toolIndex = threads[threadIndex].session.messages[messageIndex].toolCards.firstIndex(where: { $0.id == toolId })
        else { return }

        var card = threads[threadIndex].session.messages[messageIndex].toolCards[toolIndex]
        guard card.status == .pendingApproval else { return }

        if !approved {
            card.status = .rejected
            card.body = "Command rejected."
            card.isExpanded = true
            threads[threadIndex].session.reduce(.updateToolCard(
                messageId: messageId,
                toolId: toolId,
                card: card
            ))
            persistCurrentProject()
            return
        }

        runPendingCommand(messageId: messageId, toolId: toolId)
    }

    func runPendingCommand(messageId: String, toolId: String) {
        guard let threadIndex = threads.firstIndex(where: { $0.id == activeThreadId }),
              let messageIndex = threads[threadIndex].session.messages.firstIndex(where: { $0.id == messageId }),
              let toolIndex = threads[threadIndex].session.messages[messageIndex].toolCards.firstIndex(where: { $0.id == toolId }),
              let command = threads[threadIndex].session.messages[messageIndex].toolCards[toolIndex].pendingCommand,
              let folder = ProjectCatalog.folderURL(for: selectedProjectId)
        else { return }

        var card = threads[threadIndex].session.messages[messageIndex].toolCards[toolIndex]
        card.status = .running
        card.body = "Running…"
        threads[threadIndex].session.reduce(.updateToolCard(
            messageId: messageId,
            toolId: toolId,
            card: card
        ))
        persistCurrentProject()

        let request = WorkspaceCommandRequest(command: command, reason: card.argsPreview)
        let sandbox = preferences.sandboxCommands
        Task {
            let result = await WorkspaceSandbox.run(
                request: request,
                workingDirectory: folder,
                sandboxEnabled: sandbox
            )
            await MainActor.run {
                self.applyCommandResult(
                    messageId: messageId,
                    toolId: toolId,
                    result: result
                )
            }
        }
    }

    private func applyCommandResult(
        messageId: String,
        toolId: String,
        result: WorkspaceCommandResult
    ) {
        applyGeneration(on: activeThreadId) { thread in
            guard let messageIndex = thread.session.messages.firstIndex(where: { $0.id == messageId }),
                  let toolIndex = thread.session.messages[messageIndex].toolCards.firstIndex(where: { $0.id == toolId })
            else { return }
            var card = thread.session.messages[messageIndex].toolCards[toolIndex]
            let output = """
            Exit code: \(result.exitCode)

            stdout:
            \(result.stdout.isEmpty ? "(empty)" : result.stdout)

            stderr:
            \(result.stderr.isEmpty ? "(empty)" : result.stderr)
            """
            card.body = output
            card.status = result.exitCode == 0 ? .complete : .error
            card.pendingCommand = nil
            card.isExpanded = true
            thread.session.reduce(.updateToolCard(messageId: messageId, toolId: toolId, card: card))
        }
        persistCurrentProject()
    }

    func handleAgentEvent(
        _ event: ChatAgentEvent,
        threadId: String,
        assistantId: String,
        startedMessage: inout Bool,
        pendingThinkingCard: inout AgentToolCard?,
        streamingToolId: inout String?
    ) {
        switch event {
        case let .thinkingStart(card):
            pendingThinkingCard = card
            ensureAssistantMessage(threadId: threadId, assistantId: assistantId, startedMessage: &startedMessage)
            applyGeneration(on: threadId) { thread in
                thread.session.reduce(.startToolCard(messageId: assistantId, card: card))
                thread.session.reduce(.setToolExpanded(
                    messageId: assistantId,
                    toolId: card.id,
                    isExpanded: true
                ))
            }
            streamingToolId = card.id
            pendingThinkingCard = nil
        case let .thinkingDelta(cardId, delta):
            ensureAssistantMessage(threadId: threadId, assistantId: assistantId, startedMessage: &startedMessage)
            applyGeneration(on: threadId) { thread in
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
            streamingToolId = cardId
        case let .thinkingEnd(cardId):
            pendingThinkingCard = nil
            if preferences.autoCollapseThinking {
                applyGeneration(on: threadId) { thread in
                    thread.session.reduce(.setToolExpanded(
                        messageId: assistantId,
                        toolId: cardId,
                        isExpanded: false
                    ))
                }
            }
            if streamingToolId == cardId { streamingToolId = nil }
        case let .textDelta(delta):
            pendingThinkingCard = nil
            ensureAssistantMessage(threadId: threadId, assistantId: assistantId, startedMessage: &startedMessage)
            applyGeneration(on: threadId) { thread in
                thread.session.reduce(.appendAssistantText(id: assistantId, delta: delta))
            }
        case let .toolCallStart(card):
            ensureAssistantMessage(threadId: threadId, assistantId: assistantId, startedMessage: &startedMessage)
            applyGeneration(on: threadId) { thread in
                thread.session.reduce(.startToolCard(messageId: assistantId, card: card))
            }
            streamingToolId = card.id
        case let .toolCallArgsDelta(cardId, delta):
            ensureAssistantMessage(threadId: threadId, assistantId: assistantId, startedMessage: &startedMessage)
            applyGeneration(on: threadId) { thread in
                thread.session.reduce(.appendToolArgs(
                    messageId: assistantId,
                    toolId: cardId,
                    delta: delta
                ))
            }
            streamingToolId = cardId
        case let .toolCallComplete(call):
            finalizeToolCall(
                threadId: threadId,
                assistantId: assistantId,
                call: call
            )
            streamingToolId = nil
        case let .assistantImages(urls):
            ensureAssistantMessage(threadId: threadId, assistantId: assistantId, startedMessage: &startedMessage)
            let paths = urls.map { resolveImagePath($0) }
            applyGeneration(on: threadId) { thread in
                thread.session.reduce(.appendAssistantImages(id: assistantId, paths: paths))
            }
        }
    }

    private func ensureAssistantMessage(
        threadId: String,
        assistantId: String,
        startedMessage: inout Bool
    ) {
        guard !startedMessage else { return }
        applyGeneration(on: threadId) { thread in
            thread.session.reduce(.startAssistantMessage(
                id: assistantId,
                createdAt: Date().timeIntervalSince1970
            ))
        }
        startedMessage = true
    }

    private func finalizeToolCall(
        threadId: String,
        assistantId: String,
        call: CompletedToolCall
    ) {
        let formatted = AgentToolTitles.formatToolArguments(call.arguments)
        let imagePaths = AgentToolTitles.extractImagePaths(from: formatted)
        applyGeneration(on: threadId) { thread in
            guard let messageIndex = thread.session.messages.firstIndex(where: { $0.id == assistantId }),
                  let toolIndex = thread.session.messages[messageIndex].toolCards.firstIndex(where: { $0.id == call.id })
            else { return }
            var card = thread.session.messages[messageIndex].toolCards[toolIndex]
            card.argsPreview = formatted
            card.imagePaths = imagePaths
            card.isExpanded = true

            if card.kind == .runCommand,
               let data = call.arguments.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let command = json["command"] as? String {
                card.pendingCommand = command
                let needsApproval = WorkspaceSandbox.needsApproval(
                    command: command,
                    mode: preferences.commandApprovalMode,
                    sandboxEnabled: preferences.sandboxCommands
                )
                if needsApproval {
                    card.status = .pendingApproval
                    card.body = (json["reason"] as? String) ?? "Waiting for approval to run this command."
                } else {
                    card.status = .running
                    card.body = "Running…"
                }
            } else {
                card.status = .complete
                card.body = stubToolResult(for: call)
            }
            thread.session.reduce(.updateToolCard(
                messageId: assistantId,
                toolId: call.id,
                card: card
            ))
        }
        persistCurrentProject()

        if let threadIndex = threads.firstIndex(where: { $0.id == threadId }),
           let messageIndex = threads[threadIndex].session.messages.firstIndex(where: { $0.id == assistantId }),
           let toolIndex = threads[threadIndex].session.messages[messageIndex].toolCards.firstIndex(where: { $0.id == call.id }) {
            let card = threads[threadIndex].session.messages[messageIndex].toolCards[toolIndex]
            if card.kind == .runCommand, card.status == .running {
                runPendingCommand(messageId: assistantId, toolId: call.id)
            }
        }
    }

    private func stubToolResult(for call: CompletedToolCall) -> String {
        switch call.name {
        case "describe_file":
            return "File inspection is queued. Re-run with workspace context or open the file in the project tree."
        case "generate_image_reference":
            return "Image reference requested. Output paths will appear here when generation is wired to a provider."
        case "generate_3d_asset":
            return "3D asset generation requested. Candidate files will appear under the project when a provider is connected."
        case "render_asset":
            return "Render requested. View images will attach to this card when rendering is available."
        case "validate_asset":
            return "Validation requested. Structured check results will appear here when validation runs."
        default:
            return "Tool \(call.name) completed."
        }
    }

    func executeToolRound(
        calls: [CompletedToolCall],
        threadId: String,
        assistantId: String,
        modelId: String,
        apiKey: String,
        baseMessages: [ChatMessage]
    ) async throws -> Bool {
        var toolMessages: [ChatMessage] = []
        let now = Date().timeIntervalSince1970

        for call in calls where call.name == "run_workspace_command" {
            guard let data = call.arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let command = json["command"] as? String,
                  let folder = ProjectCatalog.folderURL(for: selectedProjectId)
            else { continue }

            if WorkspaceSandbox.needsApproval(
                command: command,
                mode: preferences.commandApprovalMode,
                sandboxEnabled: preferences.sandboxCommands
            ) {
                continue
            }

            let result = await WorkspaceSandbox.run(
                request: WorkspaceCommandRequest(
                    command: command,
                    reason: json["reason"] as? String ?? ""
                ),
                workingDirectory: folder,
                sandboxEnabled: preferences.sandboxCommands
            )
            let content = """
            Command: \(command)
            Exit code: \(result.exitCode)
            stdout:\n\(result.stdout)
            stderr:\n\(result.stderr)
            """
            toolMessages.append(ChatMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: content,
                createdAt: now
            ))
        }

        guard !toolMessages.isEmpty else { return false }

        var followUp = baseMessages
        followUp.append(contentsOf: toolMessages)
        _ = try await ChatAgent.streamReply(
            messages: engineeringMessages(for: followUp, userRequest: ""),
            modelId: modelId,
            apiKey: apiKey,
            includeTools: preferences.enableAgentTools
        ) { event in
            var started = true
            var pending: AgentToolCard?
            var streamingId: String?
            self.handleAgentEvent(
                event,
                threadId: threadId,
                assistantId: assistantId,
                startedMessage: &started,
                pendingThinkingCard: &pending,
                streamingToolId: &streamingId
            )
        }
        return true
    }
}
