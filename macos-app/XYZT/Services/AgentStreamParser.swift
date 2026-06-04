import Foundation

/// Mirrors `@xyzt/agent` stream parser (`src/agent/stream-parser.ts`).
enum StreamParserEvent: Equatable {
    case thinkingStart(AgentToolCard)
    case thinkingDelta(cardId: String, delta: String)
    case thinkingEnd(cardId: String)
    case textDelta(String)
}

final class AgentStreamParser {
    private enum Mode {
        case seek
        case think
        case text
    }

    private static let thinkOpen = ["<", "think", ">"].joined()
    private static let thinkClose = ["<", "/", "think", ">"].joined()

    private var mode: Mode = .seek
    private var carry = ""
    private var thinkingCard: AgentToolCard?
    private var nextToolId = 0

    /// Reasoning tokens from OpenRouter (`delta.reasoning` / `reasoning_details`).
    func pushReasoning(_ delta: String) -> [StreamParserEvent] {
        guard !delta.isEmpty else { return [] }
        var events: [StreamParserEvent] = []
        if mode != .think {
            beginThinking(&events)
        }
        events.append(contentsOf: thinkingDelta(delta))
        return events
    }

    func push(_ delta: String) -> [StreamParserEvent] {
        guard !delta.isEmpty else { return [] }
        var events: [StreamParserEvent] = []
        if mode == .think {
            events.append(contentsOf: endThinking())
        }
        var rest = carry + delta
        carry = ""

        while !rest.isEmpty {
            switch mode {
            case .seek:
                guard let openIdx = rest.range(of: Self.thinkOpen)?.lowerBound else {
                    let partial = Self.stripPartialSuffix(rest, tag: Self.thinkOpen)
                    carry = partial.suffix
                    if !partial.text.isEmpty {
                        events.append(.textDelta(partial.text))
                        mode = .text
                    }
                    rest = ""
                    break
                }
                let prefix = String(rest[..<openIdx])
                if !prefix.isEmpty { events.append(.textDelta(prefix)) }
                let afterOpen = rest.index(openIdx, offsetBy: Self.thinkOpen.count, limitedBy: rest.endIndex) ?? rest.endIndex
                rest = String(rest[afterOpen...])
                beginThinking(&events)
            case .think:
                guard let closeIdx = rest.range(of: Self.thinkClose)?.lowerBound else {
                    let partial = Self.stripPartialSuffix(rest, tag: Self.thinkClose)
                    carry = partial.suffix
                    if !partial.text.isEmpty {
                        events.append(contentsOf: thinkingDelta(partial.text))
                    }
                    rest = ""
                    break
                }
                let chunk = String(rest[..<closeIdx])
                if !chunk.isEmpty { events.append(contentsOf: thinkingDelta(chunk)) }
                let afterClose = rest.index(closeIdx, offsetBy: Self.thinkClose.count, limitedBy: rest.endIndex) ?? rest.endIndex
                rest = String(rest[afterClose...])
                events.append(contentsOf: endThinking())
            case .text:
                events.append(.textDelta(rest))
                rest = ""
            }
        }

        return events
    }

    func flush() -> [StreamParserEvent] {
        var events: [StreamParserEvent] = []
        if !carry.isEmpty {
            switch mode {
            case .think:
                events.append(contentsOf: thinkingDelta(carry))
            case .text, .seek:
                events.append(.textDelta(carry))
            }
            carry = ""
        }
        if mode == .think {
            events.append(contentsOf: endThinking())
        }
        return events
    }

    private func beginThinking(_ events: inout [StreamParserEvent]) {
        mode = .think
        nextToolId += 1
        let card = AgentToolCard.thinking(id: "thinking-\(nextToolId)")
        thinkingCard = card
        events.append(.thinkingStart(card))
    }

    private func thinkingDelta(_ text: String) -> [StreamParserEvent] {
        guard var card = thinkingCard, !text.isEmpty else { return [] }
        card.body += text
        thinkingCard = card
        return [.thinkingDelta(cardId: card.id, delta: text)]
    }

    private func endThinking() -> [StreamParserEvent] {
        guard let card = thinkingCard else {
            mode = .text
            return []
        }
        thinkingCard = nil
        mode = .text
        return [.thinkingEnd(cardId: card.id)]
    }

    private static func stripPartialSuffix(_ text: String, tag: String) -> (text: String, suffix: String) {
        guard tag.count > 1 else { return (text, "") }
        for length in stride(from: tag.count - 1, through: 1, by: -1) {
            let prefix = String(tag.prefix(length))
            if text.hasSuffix(prefix) {
                return (String(text.dropLast(length)), prefix)
            }
        }
        return (text, "")
    }
}
