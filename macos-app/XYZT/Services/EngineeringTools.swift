import Foundation

/// OpenRouter tool definitions aligned with `src/agent/engineering-agent.ts`.
enum EngineeringTools {
    static func openRouterPayload() -> [[String: Any]] {
        [
            functionTool(
                name: "describe_file",
                description: "Parse or summarize an existing project file, including CAD/EDA formats when supported.",
                properties: ["path": stringProperty("Project-relative file path.")],
                required: ["path"]
            ),
            functionTool(
                name: "generate_image_reference",
                description: "Generate or edit reference imagery, masks, or texture concepts for later 3D validation.",
                properties: [
                    "prompt": stringProperty(nil),
                    "purpose": enumProperty([
                        "concept", "texture", "mask", "orthographic_reference", "style_reference",
                    ]),
                ],
                required: ["prompt", "purpose"]
            ),
            functionTool(
                name: "generate_3d_asset",
                description: "Generate a candidate 3D asset from text and/or reference images.",
                properties: [
                    "prompt": stringProperty(nil),
                    "output_formats": arrayProperty(items: enumProperty([
                        "glb", "gltf", "obj", "fbx", "stl", "usdz", "usd",
                    ])),
                ],
                required: ["prompt", "output_formats"]
            ),
            functionTool(
                name: "render_asset",
                description: "Render canonical views of a 3D asset for inspection.",
                properties: [
                    "asset_path": stringProperty(nil),
                    "views": arrayProperty(items: enumProperty([
                        "front", "back", "left", "right", "top", "bottom", "three_quarter", "wireframe",
                    ])),
                ],
                required: ["asset_path", "views"]
            ),
            functionTool(
                name: "validate_asset",
                description: "Run deterministic checks on engineering assets.",
                properties: [
                    "asset_path": stringProperty(nil),
                    "checks": arrayProperty(items: enumProperty([
                        "opens", "dimensions", "triangle_count", "manifold", "uvs",
                        "materials", "origin", "file_size",
                    ])),
                ],
                required: ["asset_path", "checks"]
            ),
            functionTool(
                name: "run_workspace_command",
                description: "Run a shell command in the opened project folder. Destructive commands require user approval.",
                properties: [
                    "command": stringProperty("Shell command to run in the project directory."),
                    "reason": stringProperty("Short explanation of why this command is needed."),
                ],
                required: ["command", "reason"]
            ),
        ]
    }

    private static func functionTool(
        name: String,
        description: String,
        properties: [String: Any],
        required: [String]
    ) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required,
                    "additionalProperties": false,
                ] as [String: Any],
            ] as [String: Any],
        ]
    }

    private static func stringProperty(_ description: String?) -> [String: Any] {
        var value: [String: Any] = ["type": "string"]
        if let description { value["description"] = description }
        return value
    }

    private static func enumProperty(_ values: [String]) -> [String: Any] {
        ["type": "string", "enum": values]
    }

    private static func arrayProperty(items: [String: Any]) -> [String: Any] {
        ["type": "array", "items": items]
    }
}
