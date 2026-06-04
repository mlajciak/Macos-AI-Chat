import Foundation

/// Mirrors `@xyzt/core` agent streaming (`core/src/agent-stream.ts`).
enum ChatAgent {
    static func streamReply(
        messages: [ChatMessage],
        modelId: String,
        apiKey: String,
        onEvent: @escaping @MainActor (StreamParserEvent) -> Void
    ) async throws {
        let parser = AgentStreamParser()
        for try await delta in OpenRouterClient.streamChatCompletion(
            apiKey: apiKey,
            model: modelId,
            messages: messages
        ) {
            for event in parser.push(delta) {
                await onEvent(event)
            }
        }
        for event in parser.flush() {
            await onEvent(event)
        }
    }
}
