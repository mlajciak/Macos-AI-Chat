import Foundation

extension OpenRouterClient {
    static func streamChatCompletion(
        apiKey: String,
        model: String,
        messages: [ChatMessage]
    ) -> AsyncThrowingStream<String, Error> {
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

                    var lineBuffer = ""
                    for try await byte in bytes {
                        lineBuffer.append(Character(UnicodeScalar(byte)))
                        while let newline = lineBuffer.firstIndex(of: "\n") {
                            let line = String(lineBuffer[..<newline])
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            lineBuffer = String(lineBuffer[lineBuffer.index(after: newline)...])
                            if let delta = deltaFromSseLine(line) {
                                continuation.yield(delta)
                            }
                        }
                    }
                    if !lineBuffer.isEmpty, let delta = deltaFromSseLine(lineBuffer) {
                        continuation.yield(delta)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func deltaFromSseLine(_ line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if payload.isEmpty || payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty
        else { return nil }
        return content
    }
}
