import Foundation

enum ChatAgentEvent: Equatable {
    case thinkingStart(AgentToolCard)
    case thinkingDelta(cardId: String, delta: String)
    case thinkingEnd(cardId: String)
    case textDelta(String)
    case toolCallStart(AgentToolCard)
    case toolCallArgsDelta(cardId: String, delta: String)
    case toolCallComplete(CompletedToolCall)
    case assistantImages([String])
}

/// Mirrors `@xyzt/agent` agent streaming (`src/agent/agent-stream.ts`).
enum ChatAgent {
    static func streamReply(
        messages: [ChatMessage],
        modelId: String,
        apiKey: String,
        includeTools: Bool = true,
        onEvent: @escaping @MainActor (ChatAgentEvent) -> Void
    ) async throws -> [CompletedToolCall] {
        let parser = AgentStreamParser()
        let toolAccumulator = ToolCallStreamAccumulator()
        var completedCalls: [CompletedToolCall] = []

        for try await chunk in OpenRouterClient.streamChatCompletion(
            apiKey: apiKey,
            model: modelId,
            messages: messages,
            includeTools: includeTools
        ) {
            try Task.checkCancellation()

            if let imageURLs = chunk.imageURLs, !imageURLs.isEmpty {
                await onEvent(.assistantImages(imageURLs))
            }

            if let toolCalls = chunk.toolCalls, !toolCalls.isEmpty {
                let update = toolAccumulator.ingest(deltaToolCalls: toolCalls)
                for start in update.starts {
                    let formatted = AgentToolTitles.formatToolArguments(start.arguments)
                    let card = AgentToolCard.toolCall(
                        id: start.id,
                        functionName: start.name,
                        argsPreview: formatted
                    )
                    await onEvent(.toolCallStart(card))
                }
                for argDelta in update.argDeltas {
                    await onEvent(.toolCallArgsDelta(cardId: argDelta.id, delta: argDelta.delta))
                }
            }

            if let reasoning = chunk.reasoning {
                for event in parser.pushReasoning(reasoning) {
                    try Task.checkCancellation()
                    await onEvent(mapParserEvent(event))
                }
            }
            if let content = chunk.content {
                for event in parser.push(content) {
                    try Task.checkCancellation()
                    await onEvent(mapParserEvent(event))
                }
            }
        }

        try Task.checkCancellation()
        for event in parser.flush() {
            await onEvent(mapParserEvent(event))
        }

        completedCalls = toolAccumulator.finish()
        for call in completedCalls {
            await onEvent(.toolCallComplete(call))
        }
        return completedCalls
    }

    private static func mapParserEvent(_ event: StreamParserEvent) -> ChatAgentEvent {
        switch event {
        case let .thinkingStart(card):
            .thinkingStart(card)
        case let .thinkingDelta(cardId, delta):
            .thinkingDelta(cardId: cardId, delta: delta)
        case let .thinkingEnd(cardId):
            .thinkingEnd(cardId: cardId)
        case let .textDelta(delta):
            .textDelta(delta)
        }
    }

    static func generateTitle(
        firstMessage: String,
        modelId: String,
        apiKey: String
    ) async throws -> String {
        let prompt = """
        Generate a short chat title (3–6 words) for a CAD/engineering assistant conversation.
        Reply with only the title text—no quotes, colons, or punctuation at the ends.

        First user message:
        \(firstMessage)
        """
        let message = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: prompt,
            createdAt: Date().timeIntervalSince1970
        )
        return try await OpenRouterClient.chatCompletion(
            apiKey: apiKey,
            model: modelId,
            messages: [message]
        )
    }
}
