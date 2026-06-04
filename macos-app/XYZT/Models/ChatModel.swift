import Foundation

struct ChatModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
}

enum ChatModels {
    static let catalog: [ChatModel] = [
        ChatModel(id: "demo", name: "Demo", provider: "Local"),
        ChatModel(id: "claude-sonnet", name: "Claude Sonnet", provider: "Anthropic"),
        ChatModel(id: "gpt-4o-mini", name: "GPT-4o mini", provider: "OpenAI"),
        ChatModel(id: "gemini-flash", name: "Gemini Flash", provider: "Google"),
    ]

    static let defaultModel = catalog[0]

    static func model(id: String) -> ChatModel {
        catalog.first { $0.id == id } ?? defaultModel
    }
}
