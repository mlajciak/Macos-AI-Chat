import Foundation

/// Mirrors `@xyzt/core` OpenRouter client (`core/src/openrouter.ts`).
enum OpenRouterClient {
    static let apiBase = URL(string: "https://openrouter.ai/api/v1")!

    struct Model: Identifiable, Decodable, Hashable {
        let id: String
        let name: String
        let description: String?

        var provider: String { Self.providerLabel(id: id) }

        static func providerLabel(id: String) -> String {
            guard let slash = id.firstIndex(of: "/") else { return "OpenRouter" }
            let provider = id[..<slash]
            return provider
                .split(whereSeparator: { $0 == "-" || $0 == "_" })
                .map { part in
                    part.isEmpty ? "" : part.prefix(1).uppercased() + part.dropFirst()
                }
                .joined(separator: " ")
        }
    }

    enum ClientError: LocalizedError {
        case missingApiKey
        case invalidResponse
        case http(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .missingApiKey:
                "Add your OpenRouter API key in Settings."
            case .invalidResponse:
                "OpenRouter returned an unexpected response."
            case let .http(_, message):
                message
            }
        }
    }

    static func listModels(
        apiKey: String,
        search: String? = nil
    ) async throws -> [Model] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.missingApiKey
        }

        var components = URLComponents(
            url: apiBase.appendingPathComponent("models"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "output_modalities", value: "text")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppBranding.openRouterReferrer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(AppBranding.name, forHTTPHeaderField: "X-Title")

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(data: data, response: response)

        struct Payload: Decodable {
            let data: [Model]?
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let models = payload.data ?? []
        let query = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !query.isEmpty else { return models }
        return models.filter { model in
            let haystack = "\(model.id) \(model.name) \(model.description ?? "")".lowercased()
            return haystack.contains(query)
        }
    }

    static func chatCompletion(
        apiKey: String,
        model: String,
        messages: [ChatMessage]
    ) async throws -> String {
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
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(data: data, response: response)

        struct Payload: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message?
            }
            let choices: [Choice]?
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let content = payload.choices?.first?.message?.content,
              !content.isEmpty
        else {
            throw ClientError.invalidResponse
        }
        return content
    }

    private static func throwIfNeeded(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = parseErrorMessage(data: data) ?? "OpenRouter request failed (\(http.statusCode))"
            throw ClientError.http(status: http.statusCode, message: message)
        }
    }

    private static func parseErrorMessage(data: Data) -> String? {
        struct ErrorBody: Decodable {
            struct Detail: Decodable {
                let message: String?
            }
            let error: Detail?
        }
        return (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error?.message
    }
}
