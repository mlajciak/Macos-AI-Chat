import AppKit
import SwiftUI

struct ToolCardView: View {
    let card: AgentToolCard
    let fontSettings: AppFontSettings
    var isStreaming = false
    let onExpandedChange: (Bool) -> Void
    var onApproveCommand: (() -> Void)?
    var onRejectCommand: (() -> Void)?
    @Environment(\.appThemeColors) private var theme

    private var isThinking: Bool { card.kind == .thinking }
    private var showsBody: Bool {
        card.isExpanded || isStreaming || card.status == .pendingApproval
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(accentBarColor)
                .frame(width: 2)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 0) {
                headerRow

                if showsBody {
                    detailContent
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                } else if let summary = collapsedSummary {
                    Text(summary)
                        .font(fontSettings.font(size: max(fontSettings.captionPointSize - 1, 9)))
                        .foregroundStyle(theme.tertiary)
                        .lineLimit(1)
                        .padding(.top, 2)
                        .padding(.bottom, 4)
                }
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 4)
        .animation(.easeInOut(duration: 0.18), value: card.isExpanded)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Button {
                onExpandedChange(!card.isExpanded)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(fontSettings.font(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 14)

                    Text(card.title)
                        .font(fontSettings.font(for: .caption, weight: .medium))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    if let badge = statusBadge {
                        Text(badge)
                            .font(fontSettings.font(size: 9, weight: .semibold))
                            .foregroundStyle(badgeForeground)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                Capsule().fill(badgeBackground)
                            }
                    }

                    Spacer(minLength: 0)

                    if card.status == .pendingApproval {
                        HStack(spacing: 4) {
                            toolActionChip("Reject", role: .secondary) { onRejectCommand?() }
                            toolActionChip("Run", role: .primary) { onApproveCommand?() }
                        }
                    } else if hasExpandableContent {
                        Image(systemName: "chevron.right")
                            .font(fontSettings.font(size: 9, weight: .semibold))
                            .foregroundStyle(theme.tertiary)
                            .rotationEffect(.degrees(card.isExpanded ? 90 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if card.status == .pendingApproval, let command = card.pendingCommand {
                ToolInlineMonospace(text: command, fontSettings: fontSettings)
            }

            if !card.argsPreview.isEmpty, card.status != .pendingApproval {
                ToolInlineMonospace(
                    text: card.argsPreview,
                    fontSettings: fontSettings,
                    maxLines: card.isExpanded ? nil : 3
                )
            }

            if !card.imagePaths.isEmpty {
                ToolGeneratedImageGallery(
                    paths: card.imagePaths,
                    fontSettings: fontSettings
                )
            }

            if !card.body.isEmpty || (isStreaming && card.kind == .thinking) {
                if card.body.isEmpty, isStreaming {
                    Text("…")
                        .font(fontSettings.font(for: .caption))
                        .foregroundStyle(theme.tertiary)
                        .italic()
                } else if isThinking {
                    Text(card.body)
                        .font(fontSettings.font(for: .caption))
                        .foregroundStyle(theme.secondary)
                        .italic()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    MessageMarkdownView(
                        markdown: card.body,
                        fontSettings: fontSettings,
                        secondary: true
                    )
                }
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toolActionChip(
        _ title: String,
        role: ToolActionRole,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(fontSettings.font(size: 10, weight: .medium))
                .foregroundStyle(role == .primary ? theme.accent : theme.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    Capsule()
                        .fill(role == .primary ? theme.accentMuted : theme.fieldFill)
                }
        }
        .buttonStyle(.plain)
    }

    private enum ToolActionRole {
        case primary
        case secondary
    }

    private var hasExpandableContent: Bool {
        !card.body.isEmpty
            || !card.argsPreview.isEmpty
            || !card.imagePaths.isEmpty
            || card.pendingCommand != nil
            || isStreaming
    }

    private var collapsedSummary: String? {
        guard !showsBody else { return nil }
        if !card.argsPreview.isEmpty {
            return card.argsPreview
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !card.body.isEmpty {
            return card.body.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private var statusBadge: String? {
        switch card.status {
        case .running: isStreaming ? "…" : nil
        case .pendingApproval: "approve"
        case .error: "failed"
        case .rejected: "rejected"
        default: nil
        }
    }

    private var badgeForeground: Color {
        switch card.status {
        case .pendingApproval: theme.accent
        case .error, .rejected: Color.orange
        default: theme.secondary
        }
    }

    private var badgeBackground: Color {
        switch card.status {
        case .pendingApproval: theme.accentMuted
        case .error, .rejected: Color.orange.opacity(0.15)
        default: theme.fieldFill
        }
    }

    private var accentBarColor: Color {
        if card.status == .pendingApproval { return theme.accent.opacity(0.7) }
        if isThinking { return theme.tertiary.opacity(0.5) }
        switch card.status {
        case .running: return theme.accent.opacity(0.6)
        case .error, .rejected: return Color.orange.opacity(0.7)
        default: return theme.fieldStroke
        }
    }

    private var iconName: String {
        switch card.kind {
        case .thinking: "ellipsis.circle"
        case .workspaceContext: "folder"
        case .readFile: "doc"
        case .describeFile: "doc.text.magnifyingglass"
        case .generateImage: "photo"
        case .generate3DAsset: "cube"
        case .renderAsset: "camera"
        case .validateAsset: "checkmark"
        case .runCommand: "terminal"
        }
    }
}

private struct ToolInlineMonospace: View {
    let text: String
    let fontSettings: AppFontSettings
    var maxLines: Int?
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        Text(text)
            .font(MessageMarkdown.codeFont(fontSettings))
            .foregroundStyle(theme.secondary)
            .lineLimit(maxLines)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ToolGeneratedImageGallery: View {
    let paths: [String]
    let fontSettings: AppFontSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(paths, id: \.self) { path in
                ToolGeneratedImageView(path: path, fontSettings: fontSettings)
            }
        }
    }
}

private struct ToolGeneratedImageView: View {
    let path: String
    let fontSettings: AppFontSettings
    @Environment(\.appThemeColors) private var theme
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else if path.hasPrefix("http://") || path.hasPrefix("https://") {
                AsyncImage(url: URL(string: path)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().frame(maxHeight: 180)
                    case .failure:
                        Text("Load failed")
                            .font(fontSettings.font(for: .caption))
                            .foregroundStyle(theme.tertiary)
                    default:
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { loadImage() }
        .onChange(of: path) { _, _ in loadImage() }
    }

    private func loadImage() {
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return }
        let filePath: String
        if path.hasPrefix("file://"), let url = URL(string: path) {
            filePath = url.path
        } else {
            filePath = path
        }
        image = NSImage(contentsOfFile: filePath)
    }
}
