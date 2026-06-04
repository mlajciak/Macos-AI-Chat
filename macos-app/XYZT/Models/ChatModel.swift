import Foundation

struct ChatModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String

    init(id: String, name: String, provider: String) {
        self.id = id
        self.name = name
        self.provider = provider
    }

    init(openRouter model: OpenRouterClient.Model) {
        id = model.id
        name = model.name
        provider = model.provider
    }
}

enum ChatModelCatalog {
    static func menuModels(
        menuModelIds: [String],
        labels: [String: String]
    ) -> [ChatModel] {
        menuModelIds.map { id in
            let name = labels[id] ?? id
            return ChatModel(
                id: id,
                name: name,
                provider: OpenRouterClient.Model.providerLabel(id: id)
            )
        }
    }

    static func model(
        id: String,
        menuModelIds: [String],
        labels: [String: String]
    ) -> ChatModel? {
        menuModels(menuModelIds: menuModelIds, labels: labels).first { $0.id == id }
    }
}
