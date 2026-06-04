import Foundation

/// One SSE chunk from OpenRouter chat completions (content and/or reasoning).
struct ChatStreamChunk: Equatable {
    var content: String?
    var reasoning: String?
}

extension OpenRouterClient {
    static func streamChatCompletion(
        apiKey: String,
        model: String,
        messages: [ChatMessage]
    ) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw ClientError.missingApiKey
                    }

                    var request = URLRequest(url: apiBase.appendingPathComponent("chat/completions"))
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(AppBranding.openRouterReferrer, forHTTPHeaderField: "HTTP-Referer")
                    request.setValue(AppBranding.name, forHTTPHeaderField: "X-Title")

                    let wireMessages: [[String: String]] = messages.map {
                        ["role": $0.role.rawValue, "content": $0.content]
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: [
                        "model": model,
                        "messages": wireMessages,
                        "stream": true,
                    ])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse,
                       !(200 ... 299).contains(http.statusCode) {
                        var collected = Data()
                        for try await byte in bytes { collected.append(byte) }
                        let message = parseErrorMessage(data: collected)
                            ?? "OpenRouter request failed (\(http.statusCode))"
                        throw ClientError.http(status: http.statusCode, message: message)
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let chunk = chunkFromSseLine(trimmed) {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Parses one SSE `data:` line; exposed for unit tests.
    static func chunkFromSseLine(_ line: String) -> ChatStreamChunk? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty || payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any]
        else { return nil }

        let content = (delta["content"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let reasoning = reasoningText(from: delta)
        guard content != nil || reasoning != nil else { return nil }
        return ChatStreamChunk(content: content, reasoning: reasoning)
    }

    /// Legacy helper for tests that only care about `delta.content`.
    static func deltaFromSseLine(_ line: String) -> String? {
        chunkFromSseLine(line)?.content
    }

    static func reasoningText(from delta: [String: Any]) -> String? {
        if let reasoning = delta["reasoning"] as? String, !reasoning.isEmpty {
            return reasoning
        }
        guard let details = delta["reasoning_details"] as? [[String: Any]] else {
            return nil
        }
        let parts = details.compactMap { detail -> String? in
            if let text = detail["text"] as? String, !text.isEmpty { return text }
            if let summary = detail["summary"] as? String, !summary.isEmpty { return summary }
            return nil
        }
        let joined = parts.joined()
        return joined.isEmpty ? nil : joined
    }
}
