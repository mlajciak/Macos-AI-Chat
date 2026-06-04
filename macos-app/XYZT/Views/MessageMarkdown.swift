import AppKit
import SwiftUI

// MARK: - Views

struct MessageMarkdownView: View {
    let markdown: String
    let fontSettings: AppFontSettings
    var secondary = false

    private var blocks: [MessageMarkdownBlock] {
        MessageMarkdownParser.parse(markdown)
    }

    var body: some View {
        Group {
            if blocks.isEmpty, !markdown.isEmpty {
                MessageMarkdown.inlineText(markdown, fontSettings: fontSettings, secondary: secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(.accentColor)
    }

    @ViewBuilder
    private func blockView(_ block: MessageMarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            MessageMarkdown.inlineText(text, fontSettings: fontSettings, secondary: secondary)
                .font(MessageMarkdown.headingFont(level: level, fontSettings: fontSettings))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .foregroundStyle(secondary ? Color.secondary : Color.primary)

        case let .paragraph(text):
            MessageMarkdown.inlineText(text, fontSettings: fontSettings, secondary: secondary)

        case let .bulletList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    MessageMarkdown.listRow(
                        marker: "•",
                        text: item,
                        fontSettings: fontSettings,
                        secondary: secondary
                    )
                }
            }

        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    MessageMarkdown.listRow(
                        marker: "\(index + 1).",
                        text: item,
                        fontSettings: fontSettings,
                        secondary: secondary
                    )
                }
            }

        case let .codeBlock(_, code):
            Text(code.trimmingCharacters(in: .newlines))
                .font(MessageMarkdown.codeFont(fontSettings))
                .foregroundStyle(secondary ? Color.secondary : Color.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(secondary ? 0.05 : 0.07))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
}

enum MessageMarkdown {
    static func inlineText(
        _ markdown: String,
        fontSettings: AppFontSettings,
        secondary: Bool = false
    ) -> Text {
        Text(attributedString(from: markdown, fontSettings: fontSettings, secondary: secondary))
    }

    static func listRow(
        marker: String,
        text: String,
        fontSettings: AppFontSettings,
        secondary: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(fontSettings.font(for: .body, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: marker.count > 1 ? 20 : 12, alignment: .trailing)
            inlineText(text, fontSettings: fontSettings, secondary: secondary)
        }
    }

    static func headingFont(level: Int, fontSettings: AppFontSettings) -> Font {
        let size: CGFloat = switch level {
        case 1: fontSettings.headlinePointSize + 5
        case 2: fontSettings.headlinePointSize + 2
        case 3: fontSettings.headlinePointSize
        case 4: fontSettings.bodyPointSize + 2
        default: fontSettings.bodyPointSize + 1
        }
        return fontSettings.font(size: size)
    }

    static func codeFont(_ fontSettings: AppFontSettings) -> Font {
        var mono = fontSettings
        mono.familyMode = .mono
        return mono.font(for: .body)
    }

    static func attributedString(
        from markdown: String,
        fontSettings: AppFontSettings,
        secondary: Bool = false
    ) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard var rendered = try? AttributedString(markdown: markdown, options: options) else {
            var plain = AttributedString(markdown)
            plain.font = fontSettings.nsFont(for: .body)
            if secondary {
                plain.foregroundColor = NSColor.secondaryLabelColor
            }
            return plain
        }
        applyInlineTypography(to: &rendered, fontSettings: fontSettings, secondary: secondary)
        return rendered
    }

    private static func applyInlineTypography(
        to rendered: inout AttributedString,
        fontSettings: AppFontSettings,
        secondary: Bool
    ) {
        let body = fontSettings.nsFont(for: .body)
        let bold = fontSettings.nsFont(for: .body, weight: .semibold)
        let code = monoNSFont(fontSettings)
        let codeBackground = NSColor.secondaryLabelColor.withAlphaComponent(0.14)
        let textColor = secondary ? NSColor.secondaryLabelColor : NSColor.labelColor
        let linkColor = NSColor.controlAccentColor

        for run in rendered.runs {
            let range = run.range

            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) {
                    rendered[range].font = code
                    rendered[range].backgroundColor = codeBackground
                } else if intent.contains(.stronglyEmphasized) {
                    rendered[range].font = bold
                    rendered[range].foregroundColor = textColor
                } else if intent.contains(.emphasized) {
                    rendered[range].font = italicFont(body)
                    rendered[range].foregroundColor = textColor
                } else {
                    rendered[range].font = body
                    rendered[range].foregroundColor = textColor
                }
                continue
            }

            if run.link != nil {
                rendered[range].font = body
                rendered[range].foregroundColor = linkColor
                continue
            }

            rendered[range].font = body
            rendered[range].foregroundColor = textColor
        }
    }

    private static func monoNSFont(_ settings: AppFontSettings) -> NSFont {
        var mono = settings
        mono.familyMode = .mono
        return mono.nsFont(for: .body)
    }

    private static func italicFont(_ font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
}
