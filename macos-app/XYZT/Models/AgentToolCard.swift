import Foundation

enum AgentToolKind: String, Codable, Equatable {
    case thinking
}

struct AgentToolCard: Identifiable, Equatable {
    let id: String
    let kind: AgentToolKind
    var title: String
    var body: String
    var isExpanded: Bool

    static func thinking(id: String) -> AgentToolCard {
        AgentToolCard(
            id: id,
            kind: .thinking,
            title: "Thinking",
            body: "",
            isExpanded: false
        )
    }
}
