import Foundation

/// One SSE chunk from OpenRouter chat completions.
struct ChatStreamChunk: Equatable {
    var content: String?
    var reasoning: String?
    var toolCalls: [[String: Any]]?
    var imageURLs: [String]?

    static func == (lhs: ChatStreamChunk, rhs: ChatStreamChunk) -> Bool {
        lhs.content == rhs.content
            && lhs.reasoning == rhs.reasoning
            && (lhs.toolCalls?.count ?? 0) == (rhs.toolCalls?.count ?? 0)
            && lhs.imageURLs == rhs.imageURLs
    }
}

extension OpenRouterClient {
    static func streamChatCompletion(
        apiKey: String,
        model: String,
        messages: [ChatMessage],
        includeTools: Bool = true
    ) -> AsyncThrowingStream<ChatStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw ClientError.missingApiKey
                    }

                    var request = URLRequest(url: apiBase.appendingPathComponent("chat/completions"))
                    request.httpMethod = "POST"
                    OpenRouterClient.applyAuthHeaders(to: &request, apiKey: apiKey)

                    var payload: [String: Any] = [
                        "model": model,
                        "messages": wireMessages(from: messages),
                        "stream": true,
                    ]
                    if includeTools {
                        payload["tools"] = EngineeringTools.openRouterPayload()
                        payload["tool_choice"] = "auto"
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

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

    static func wireMessages(from messages: [ChatMessage]) -> [[String: Any]] {
        messages.map { message in
            var entry: [String: Any] = [
                "role": message.role.rawValue,
                "content": message.content,
            ]
            if !message.attachmentImagePaths.isEmpty {
                var parts: [[String: Any]] = [
                    ["type": "text", "text": message.content],
                ]
                for path in message.attachmentImagePaths {
                    parts.append([
                        "type": "image_url",
                        "image_url": ["url": imageURLString(for: path)],
                    ])
                }
                entry["content"] = parts
            }
            return entry
        }
    }

    private static func imageURLString(for path: String) -> String {
        if path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("data:") {
            return path
        }
        let url = URL(fileURLWithPath: path)
        return url.absoluteString
    }

    /// Parses one SSE `data:` line; exposed for unit tests.
    static func chunkFromSseLine(_ line: String) -> ChatStreamChunk? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty || payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let choice = choices.first
        else { return nil }

        var content: String?
        var reasoning: String?
        var toolCalls: [[String: Any]]?
        var imageURLs: [String]?

        if let delta = choice["delta"] as? [String: Any] {
            content = (delta["content"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            reasoning = reasoningText(from: delta)
            toolCalls = delta["tool_calls"] as? [[String: Any]]
            imageURLs = extractImageURLs(from: delta)
        }

        if let message = choice["message"] as? [String: Any] {
            if content == nil {
                content = extractTextContent(from: message["content"])
            }
            if toolCalls == nil {
                toolCalls = message["tool_calls"] as? [[String: Any]]
            }
            if imageURLs == nil {
                imageURLs = extractImageURLs(from: message)
            }
        }

        guard content != nil || reasoning != nil || toolCalls != nil || imageURLs != nil else {
            return nil
        }
        return ChatStreamChunk(
            content: content,
            reasoning: reasoning,
            toolCalls: toolCalls,
            imageURLs: imageURLs
        )
    }

    static func extractTextContent(from value: Any?) -> String? {
        switch value {
        case let text as String:
            return text.isEmpty ? nil : text
        case let parts as [[String: Any]]:
            let joined = parts.compactMap { part -> String? in
                guard part["type"] as? String == "text" else { return nil }
                return part["text"] as? String
            }.joined()
            return joined.isEmpty ? nil : joined
        default:
            return nil
        }
    }

    static func extractImageURLs(from payload: [String: Any]) -> [String]? {
        var urls: [String] = []
        if let parts = payload["content"] as? [[String: Any]] {
            for part in parts {
                guard part["type"] as? String == "image_url",
                      let imageURL = part["image_url"] as? [String: Any],
                      let url = imageURL["url"] as? String,
                      !url.isEmpty
                else { continue }
                urls.append(url)
            }
        }
        if let images = payload["images"] as? [String] {
            urls.append(contentsOf: images.filter { !$0.isEmpty })
        }
        return urls.isEmpty ? nil : urls
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
