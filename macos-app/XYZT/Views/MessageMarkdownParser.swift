import Foundation

/// Block-level markdown segments for chat rendering.
enum MessageMarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bulletList([String])
    case orderedList([String])
    case codeBlock(language: String?, code: String)
    case image(url: String, alt: String)
}

enum MessageMarkdownParser {
    static func parse(_ markdown: String) -> [MessageMarkdownBlock] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard !normalized.isEmpty else { return [] }

        var blocks: [MessageMarkdownBlock] = []
        var index = normalized.startIndex

        while index < normalized.endIndex {
            if normalized[index...].hasPrefix("```") {
                if let (block, next) = parseCodeFence(in: normalized, from: index) {
                    blocks.append(block)
                    index = next
                    continue
                }
            }

            let lineEnd = normalized.lineEnd(startingAt: index)
            let line = String(normalized[index ..< lineEnd])
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index = normalized.nextLineStart(after: lineEnd)
                continue
            }

            if let level = headingLevel(trimmed) {
                let text = String(trimmed.drop(while: { $0 == "#" || $0 == " " }))
                blocks.append(.heading(level: level, text: text))
                index = normalized.nextLineStart(after: lineEnd)
                continue
            }

            if let image = markdownImage(in: trimmed) {
                blocks.append(.image(url: image.url, alt: image.alt))
                index = normalized.nextLineStart(after: lineEnd)
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let (items, next) = parseBulletList(in: normalized, from: index)
                blocks.append(.bulletList(items))
                index = next
                continue
            }

            if let match = orderedListMarker(in: trimmed) {
                let (items, next) = parseOrderedList(in: normalized, from: index, markerLength: match)
                blocks.append(.orderedList(items))
                index = next
                continue
            }

            let (paragraph, next) = parseParagraph(in: normalized, from: index)
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph))
            }
            index = next
        }

        return blocks
    }

    private static func parseCodeFence(
        in text: String,
        from start: String.Index
    ) -> (MessageMarkdownBlock, String.Index)? {
        var index = text.index(start, offsetBy: 3, limitedBy: text.endIndex) ?? text.endIndex
        var language = ""
        while index < text.endIndex, text[index] != "\n" {
            language.append(text[index])
            index = text.index(after: index)
        }
        if index < text.endIndex {
            index = text.index(after: index)
        }

        var code = ""
        while index < text.endIndex {
            if text[index...].hasPrefix("```") {
                let closeEnd = text.index(index, offsetBy: 3, limitedBy: text.endIndex) ?? text.endIndex
                var next = closeEnd
                if next < text.endIndex, text[next] == "\n" {
                    next = text.index(after: next)
                }
                let lang = language.trimmingCharacters(in: .whitespacesAndNewlines)
                return (.codeBlock(language: lang.isEmpty ? nil : lang, code: code), next)
            }
            let lineEnd = text.lineEnd(startingAt: index)
            code.append(contentsOf: text[index ..< lineEnd])
            index = text.nextLineStart(after: lineEnd)
            if index < text.endIndex, text[index...].hasPrefix("```") == false {
                code.append("\n")
            }
        }

        return (.codeBlock(language: nil, code: code), text.endIndex)
    }

    private static func parseBulletList(
        in text: String,
        from start: String.Index
    ) -> ([String], String.Index) {
        var items: [String] = []
        var index = start

        while index < text.endIndex {
            let lineEnd = text.lineEnd(startingAt: index)
            let line = String(text[index ..< lineEnd])
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            guard let item = bulletItemText(trimmed) else { break }
            items.append(item)
            index = text.nextLineStart(after: lineEnd)
        }

        return (items, index)
    }

    private static func parseOrderedList(
        in text: String,
        from start: String.Index,
        markerLength: Int
    ) -> ([String], String.Index) {
        var items: [String] = []
        var index = start

        while index < text.endIndex {
            let lineEnd = text.lineEnd(startingAt: index)
            let line = String(text[index ..< lineEnd])
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            guard orderedListMarker(in: trimmed) != nil else { break }
            let itemStart = trimmed.index(trimmed.startIndex, offsetBy: markerLength)
            items.append(String(trimmed[itemStart...]).trimmingCharacters(in: .whitespaces))
            index = text.nextLineStart(after: lineEnd)
        }

        return (items, index)
    }

    private static func parseParagraph(
        in text: String,
        from start: String.Index
    ) -> (String, String.Index) {
        var lines: [String] = []
        var index = start

        while index < text.endIndex {
            if text[index...].hasPrefix("```") { break }

            let lineEnd = text.lineEnd(startingAt: index)
            let line = String(text[index ..< lineEnd])
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty { break }
            if headingLevel(trimmed) != nil { break }
            if bulletItemText(trimmed) != nil { break }
            if orderedListMarker(in: trimmed) != nil { break }

            lines.append(trimmed)
            index = text.nextLineStart(after: lineEnd)
        }

        return (lines.joined(separator: "\n"), index)
    }

    private static func headingLevel(_ line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1 ... 6).contains(hashes) else { return nil }
        guard line.count > hashes, line[line.index(line.startIndex, offsetBy: hashes)] == " " else {
            return nil
        }
        return hashes
    }

    private static func bulletItemText(_ line: String) -> String? {
        for prefix in ["- ", "* ", "+ "] where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count))
        }
        return nil
    }

    private static func orderedListMarker(in line: String) -> Int? {
        var digits = 0
        for character in line {
            if character.isNumber {
                digits += 1
            } else {
                break
            }
        }
        guard digits > 0 else { return nil }
        let markerEnd = line.index(line.startIndex, offsetBy: digits)
        guard markerEnd < line.endIndex, line[markerEnd] == "." else { return nil }
        let afterDot = line.index(after: markerEnd)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        return digits + 2
    }

    static func markdownImage(in line: String) -> (alt: String, url: String)? {
        guard line.hasPrefix("!["),
              let closeBracket = line.firstIndex(of: "]"),
              line.index(after: closeBracket) < line.endIndex,
              line[line.index(after: closeBracket)] == "(",
              let closeParen = line.lastIndex(of: ")"),
              closeParen > closeBracket
        else { return nil }
        let altStart = line.index(line.startIndex, offsetBy: 2)
        let alt = String(line[altStart ..< closeBracket])
        let urlStart = line.index(after: closeBracket)
        let url = String(line[line.index(after: urlStart) ..< closeParen])
            .trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return nil }
        return (alt, url)
    }
}

private extension String {
    func lineEnd(startingAt index: String.Index) -> String.Index {
        var end = index
        while end < endIndex, self[end] != "\n" {
            end = self.index(after: end)
        }
        return end
    }

    func nextLineStart(after lineEnd: String.Index) -> String.Index {
        guard lineEnd < endIndex, self[lineEnd] == "\n" else { return lineEnd }
        return index(after: lineEnd)
    }
}
