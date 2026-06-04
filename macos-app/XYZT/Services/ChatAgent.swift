import Foundation

/// Mirrors `@xyzt/agent` agent streaming (`src/agent/agent-stream.ts`).
enum ChatAgent {
    static func streamReply(
        messages: [ChatMessage],
        modelId: String,
        apiKey: String,
        onEvent: @escaping @MainActor (StreamParserEvent) -> Void
    ) async throws {
        let parser = AgentStreamParser()
        for try await chunk in OpenRouterClient.streamChatCompletion(
            apiKey: apiKey,
            model: modelId,
            messages: messages
        ) {
            try Task.checkCancellation()
            if let reasoning = chunk.reasoning {
                for event in parser.pushReasoning(reasoning) {
                    try Task.checkCancellation()
                    await onEvent(event)
                }
            }
            if let content = chunk.content {
                for event in parser.push(content) {
                    try Task.checkCancellation()
                    await onEvent(event)
                }
            }
        }
        try Task.checkCancellation()
        for event in parser.flush() {
            await onEvent(event)
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
