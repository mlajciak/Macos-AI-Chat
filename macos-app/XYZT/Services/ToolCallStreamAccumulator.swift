import Foundation

struct CompletedToolCall: Equatable {
    let id: String
    let name: String
    let arguments: String
}

/// Assembles streaming OpenRouter `delta.tool_calls` fragments.
final class ToolCallStreamAccumulator {
    private struct PartialCall {
        var id: String?
        var name: String?
        var arguments: String = ""
    }

    private var partials: [Int: PartialCall] = [:]
    private var announcedIds: Set<String> = []

    func ingest(deltaToolCalls: [[String: Any]]) -> (
        starts: [CompletedToolCall],
        argDeltas: [(id: String, delta: String)],
        completed: [CompletedToolCall]
    ) {
        var starts: [CompletedToolCall] = []
        var argDeltas: [(id: String, delta: String)] = []
        var completed: [CompletedToolCall] = []

        for entry in deltaToolCalls {
            let index = entry["index"] as? Int ?? 0
            var partial = partials[index] ?? PartialCall()

            if let id = entry["id"] as? String, !id.isEmpty {
                partial.id = id
            }
            if let function = entry["function"] as? [String: Any] {
                if let name = function["name"] as? String, !name.isEmpty {
                    partial.name = name
                }
                if let argsDelta = function["arguments"] as? String, !argsDelta.isEmpty {
                    partial.arguments += argsDelta
                    if let id = partial.id {
                        argDeltas.append((id: id, delta: argsDelta))
                    }
                }
            }
            partials[index] = partial

            guard let id = partial.id, let name = partial.name else { continue }
            if !announcedIds.contains(id) {
                announcedIds.insert(id)
                starts.append(CompletedToolCall(id: id, name: name, arguments: partial.arguments))
            }
        }

        return (starts, argDeltas, completed)
    }

    func finish() -> [CompletedToolCall] {
        partials.values.compactMap { partial in
            guard let id = partial.id, let name = partial.name else { return nil }
            return CompletedToolCall(id: id, name: name, arguments: partial.arguments)
        }
    }
}
