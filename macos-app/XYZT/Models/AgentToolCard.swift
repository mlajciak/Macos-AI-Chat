import Foundation

enum AgentToolKind: String, Codable, Equatable {
    case thinking
    case workspaceContext = "workspace_context"
    case readFile = "read_file"
    case describeFile = "describe_file"
    case generateImage = "generate_image"
    case generate3DAsset = "generate_3d_asset"
    case renderAsset = "render_asset"
    case validateAsset = "validate_asset"
}

struct AgentToolCard: Identifiable, Equatable, Codable {
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
