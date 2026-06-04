import SwiftUI

struct ToolCardView: View {
    let card: AgentToolCard
    let fontSettings: AppFontSettings
    var isStreaming = false
    let onExpandedChange: (Bool) -> Void
    @Environment(\.appThemeColors) private var theme

    private var showsBody: Bool {
        card.isExpanded || isStreaming
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onExpandedChange(!card.isExpanded)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 16)

                    Text(card.title)
                        .font(fontSettings.font(for: .caption, weight: .medium))
                        .foregroundStyle(theme.primaryText)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .semibold))
                        .foregroundStyle(theme.secondaryMuted)
                        .rotationEffect(.degrees(card.isExpanded ? 0 : -90))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsBody {
                Group {
                    if card.body.isEmpty {
                        Text(isStreaming ? "Thinking…" : "No details")
                            .font(fontSettings.font(for: .caption))
                            .foregroundStyle(theme.secondary)
                    } else {
                        MessageMarkdownView(
                            markdown: card.body,
                            fontSettings: fontSettings,
                            secondary: true
                        )
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .padding(.top, 2)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.subtleFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.fieldStroke, lineWidth: 0.5)
        }
        .animation(.easeInOut(duration: 0.2), value: card.isExpanded)
    }

    private var iconName: String {
        switch card.kind {
        case .thinking: "brain.head.profile"
        case .workspaceContext: "folder"
        case .readFile: "doc.text"
        case .describeFile: "doc.text.magnifyingglass"
        case .generateImage: "photo"
        case .generate3DAsset: "cube"
        case .renderAsset: "camera.viewfinder"
        case .validateAsset: "checkmark.seal"
        }
    }
}
