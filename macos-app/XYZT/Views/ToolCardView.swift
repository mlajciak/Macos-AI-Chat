import SwiftUI

struct ToolCardView: View {
    let card: AgentToolCard
    let fontSettings: AppFontSettings
    var isStreaming = false
    let onExpandedChange: (Bool) -> Void

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
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(card.title)
                        .font(fontSettings.font(for: .caption, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .semibold))
                        .foregroundStyle(.tertiary)
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
                            .foregroundStyle(.secondary)
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
                .fill(Color.primary.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
        .animation(.easeInOut(duration: 0.2), value: card.isExpanded)
    }

    private var iconName: String {
        switch card.kind {
        case .thinking: "brain.head.profile"
        }
    }
}
