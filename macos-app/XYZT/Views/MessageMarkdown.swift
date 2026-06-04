import AppKit
import SwiftUI

// MARK: - Views

struct MessageMarkdownView: View {
    let markdown: String
    let fontSettings: AppFontSettings
    var secondary = false
    @Environment(\.appThemeColors) private var theme

    private var blocks: [MessageMarkdownBlock] {
        MessageMarkdownParser.parse(markdown)
    }

    var body: some View {
        Group {
            if blocks.isEmpty, !markdown.isEmpty {
                MessageMarkdown.inlineText(
                    markdown,
                    fontSettings: fontSettings,
                    secondary: secondary,
                    linkColor: linkColor,
                    codeBackground: inlineCodeBackground,
                    textColor: inlineTextColor
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tint(theme.accent)
    }

    private var linkColor: NSColor { NSColor(theme.accent) }
    private var inlineCodeBackground: NSColor { NSColor(theme.neutral(0.14)) }
    private var inlineTextColor: NSColor {
        NSColor(secondary ? theme.secondary : theme.primaryText)
    }

    @ViewBuilder
    private func blockView(_ block: MessageMarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            MessageMarkdown.inlineText(
                text,
                fontSettings: fontSettings,
                secondary: secondary,
                linkColor: linkColor,
                codeBackground: inlineCodeBackground,
                textColor: inlineTextColor
            )
                .font(MessageMarkdown.headingFont(level: level, fontSettings: fontSettings))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .foregroundStyle(secondary ? theme.secondary : theme.primaryText)

        case let .paragraph(text):
            MessageMarkdown.inlineText(
                text,
                fontSettings: fontSettings,
                secondary: secondary,
                linkColor: linkColor,
                codeBackground: inlineCodeBackground,
                textColor: inlineTextColor
            )

        case let .bulletList(items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    MessageMarkdown.listRow(
                        marker: "•",
                        text: item,
                        fontSettings: fontSettings,
                        secondary: secondary,
                        linkColor: linkColor,
                        codeBackground: inlineCodeBackground,
                        textColor: inlineTextColor
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
                        secondary: secondary,
                        linkColor: linkColor,
                        codeBackground: inlineCodeBackground,
                        textColor: inlineTextColor
                    )
                }
            }

        case let .codeBlock(_, code):
            Text(code.trimmingCharacters(in: .newlines))
                .font(MessageMarkdown.codeFont(fontSettings))
                .foregroundStyle(secondary ? theme.secondary : theme.primaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(secondary ? theme.codeBlockFillSecondary : theme.codeBlockFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.fieldStroke, lineWidth: 0.5)
                }
        }
    }
}

enum MessageMarkdown {
    static func inlineText(
        _ markdown: String,
        fontSettings: AppFontSettings,
        secondary: Bool = false,
        linkColor: NSColor = .controlAccentColor,
        codeBackground: NSColor = .secondaryLabelColor.withAlphaComponent(0.14),
        textColor: NSColor = .labelColor
    ) -> Text {
        Text(attributedString(
            from: markdown,
            fontSettings: fontSettings,
            secondary: secondary,
            linkColor: linkColor,
            codeBackground: codeBackground,
            textColor: textColor
        ))
    }

    static func listRow(
        marker: String,
        text: String,
        fontSettings: AppFontSettings,
        secondary: Bool,
        linkColor: NSColor = .controlAccentColor,
        codeBackground: NSColor = .secondaryLabelColor.withAlphaComponent(0.14),
        textColor: NSColor = .labelColor
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(fontSettings.font(for: .body, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: marker.count > 1 ? 20 : 12, alignment: .trailing)
            inlineText(
                text,
                fontSettings: fontSettings,
                secondary: secondary,
                linkColor: linkColor,
                codeBackground: codeBackground,
                textColor: textColor
            )
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
        secondary: Bool = false,
        linkColor: NSColor = .controlAccentColor,
        codeBackground: NSColor = .secondaryLabelColor.withAlphaComponent(0.14),
        textColor: NSColor = .labelColor
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
        applyInlineTypography(
            to: &rendered,
            fontSettings: fontSettings,
            linkColor: linkColor,
            codeBackground: codeBackground,
            textColor: textColor
        )
        return rendered
    }

    private static func applyInlineTypography(
        to rendered: inout AttributedString,
        fontSettings: AppFontSettings,
        linkColor: NSColor,
        codeBackground: NSColor,
        textColor: NSColor
    ) {
        let body = fontSettings.nsFont(for: .body)
        let bold = fontSettings.nsFont(for: .body, weight: .semibold)
        let code = monoNSFont(fontSettings)

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
