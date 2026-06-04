import Foundation

/// Mirrors `@xyzt/core` agent (`core/src/agent.ts`).
enum ChatAgent {
    static func reply(
        messages: [ChatMessage],
        modelId: String,
        apiKey: String
    ) async throws -> String {
        try await OpenRouterClient.chatCompletion(
            apiKey: apiKey,
            model: modelId,
            messages: messages
        )
    }
}
