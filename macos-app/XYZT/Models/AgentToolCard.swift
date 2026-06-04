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
    case runCommand = "run_workspace_command"
}

enum AgentToolStatus: String, Codable, Equatable {
    case running
    case complete
    case error
    case pendingApproval = "pending_approval"
    case rejected
    case cancelled
}

struct AgentToolCard: Identifiable, Equatable, Codable {
    let id: String
    var kind: AgentToolKind
    var title: String
    var body: String
    var argsPreview: String
    var imagePaths: [String]
    var status: AgentToolStatus
    var isExpanded: Bool
    var pendingCommand: String?

    init(
        id: String,
        kind: AgentToolKind,
        title: String,
        body: String = "",
        argsPreview: String = "",
        imagePaths: [String] = [],
        status: AgentToolStatus = .running,
        isExpanded: Bool = false,
        pendingCommand: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.argsPreview = argsPreview
        self.imagePaths = imagePaths
        self.status = status
        self.isExpanded = isExpanded
        self.pendingCommand = pendingCommand
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, title, body, argsPreview, imagePaths, status, isExpanded, pendingCommand
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(AgentToolKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        argsPreview = try container.decodeIfPresent(String.self, forKey: .argsPreview) ?? ""
        imagePaths = try container.decodeIfPresent([String].self, forKey: .imagePaths) ?? []
        status = try container.decodeIfPresent(AgentToolStatus.self, forKey: .status) ?? .complete
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        pendingCommand = try container.decodeIfPresent(String.self, forKey: .pendingCommand)
    }

    static func thinking(id: String) -> AgentToolCard {
        AgentToolCard(
            id: id,
            kind: .thinking,
            title: AgentToolTitles.label(for: .thinking),
            status: .running,
            isExpanded: true
        )
    }

    static func workspaceContext(id: String, summary: String) -> AgentToolCard {
        AgentToolCard(
            id: id,
            kind: .workspaceContext,
            title: AgentToolTitles.label(for: .workspaceContext),
            body: summary,
            status: .complete,
            isExpanded: false
        )
    }

    static func toolCall(id: String, functionName: String, argsPreview: String) -> AgentToolCard {
        let kind = AgentToolTitles.kind(forFunctionName: functionName)
        return AgentToolCard(
            id: id,
            kind: kind,
            title: AgentToolTitles.label(for: kind, functionName: functionName),
            argsPreview: argsPreview,
            status: .running,
            isExpanded: true
        )
    }
}

enum AgentToolTitles {
    static func label(for kind: AgentToolKind, functionName: String? = nil) -> String {
        switch kind {
        case .thinking: "Thinking"
        case .workspaceContext: "Workspace context"
        case .readFile: "Read file"
        case .describeFile: "Describe engineering file"
        case .generateImage: "Generate image reference"
        case .generate3DAsset: "Generate 3D asset"
        case .renderAsset: "Render asset"
        case .validateAsset: "Validate asset"
        case .runCommand: "Run command"
        }
    }

    static func kind(forFunctionName name: String) -> AgentToolKind {
        switch name {
        case "describe_file": .describeFile
        case "generate_image_reference": .generateImage
        case "generate_3d_asset": .generate3DAsset
        case "render_asset": .renderAsset
        case "validate_asset": .validateAsset
        case "run_workspace_command": .runCommand
        case "read_file": .readFile
        default: .describeFile
        }
    }

    static func formatToolArguments(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: pretty, encoding: .utf8)
        else { return trimmed }
        return text
    }

    static func extractImagePaths(from text: String) -> [String] {
        var paths: [String] = []
        let patterns = [
            #"!\[[^\]]*\]\(([^)]+)\)"#,
            #"(?:file://|/)[^\s"'<>]+\.(?:png|jpg|jpeg|gif|webp|heic)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(text.startIndex..., in: text)
            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1,
                      let capture = Range(match.range(at: 1), in: text)
                else { return }
                let path = String(text[capture])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !path.isEmpty, !paths.contains(path) {
                    paths.append(path)
                }
            }
        }
        return paths
    }
}
