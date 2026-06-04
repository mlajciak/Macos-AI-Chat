import SwiftUI

enum MessageListLayout {
    static let horizontalPadding: CGFloat = 12
    /// Text area only when collapsed; expand control sits below the fade.
    static let userMessageCollapsedTextMaxHeight: CGFloat = 96
    static let userMessageBottomFadeHeight: CGFloat = 36
}

struct MessageBubbleView: View {
    let message: ChatMessage
    let fontSettings: AppFontSettings
    var onToolExpandedChange: ((String, Bool) -> Void)?

    private var isUser: Bool { message.role == .user }

    var body: some View {
        if isUser {
            HStack {
                Spacer(minLength: 40)
                UserMessageBubble(content: message.content, fontSettings: fontSettings)
            }
        } else {
            AssistantMessageView(
                message: message,
                fontSettings: fontSettings,
                onToolExpandedChange: onToolExpandedChange
            )
        }
    }
}

private struct AssistantMessageView: View {
    let message: ChatMessage
    let fontSettings: AppFontSettings
    var onToolExpandedChange: ((String, Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(message.toolCards.filter { !$0.body.isEmpty }) { card in
                ToolCardView(
                    card: card,
                    fontSettings: fontSettings
                ) { expanded in
                    onToolExpandedChange?(card.id, expanded)
                }
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .appFont(.body, settings: fontSettings)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UserMessageBubble: View {
    let content: String
    let fontSettings: AppFontSettings
    @State private var isExpanded = false
    @State private var measuredTextHeight: CGFloat = 0

    private var collapsedTextMaxHeight: CGFloat {
        MessageListLayout.userMessageCollapsedTextMaxHeight
    }

    private var bottomFadeHeight: CGFloat {
        MessageListLayout.userMessageBottomFadeHeight
    }

    private var needsTruncation: Bool {
        measuredTextHeight > collapsedTextMaxHeight + 1
    }

    private var collapsedTextHeight: CGFloat {
        min(measuredTextHeight, collapsedTextMaxHeight)
    }

    private var expandedTextHeight: CGFloat? {
        guard needsTruncation, isExpanded else { return nil }
        return measuredTextHeight
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                messageText
                    .frame(height: textFrameHeight, alignment: .top)
                    .mask {
                        if needsTruncation, !isExpanded {
                            textFadeMask
                        } else {
                            Rectangle().fill(Color.black)
                        }
                    }
                    .animation(.easeInOut(duration: 0.28), value: isExpanded)

                if needsTruncation, !isExpanded {
                    expandButton
                        .zIndex(1)
                }
            }

            if needsTruncation, isExpanded {
                collapseButton
            }
        }
        .background { textMeasurementBackground }
        .onPreferenceChange(UserMessageMeasuredHeightKey.self) { height in
            measuredTextHeight = height
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var textFrameHeight: CGFloat? {
        guard needsTruncation else { return nil }
        return isExpanded ? expandedTextHeight : collapsedTextHeight
    }

    private var messageText: some View {
        Text(content)
            .appFont(.body, settings: fontSettings)
            .foregroundStyle(Color.white)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, needsTruncation && !isExpanded ? 10 : 8)
    }

    private var textFadeMask: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black)
            LinearGradient(
                colors: [.black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: bottomFadeHeight)
        }
    }

    private var expandButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                isExpanded = true
            }
        } label: {
            Text("Click to expand")
                .appFont(.caption, settings: fontSettings)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.96))
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private var collapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                isExpanded = false
            }
        } label: {
            Text("Click to collapse")
                .appFont(.caption, settings: fontSettings)
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var textMeasurementBackground: some View {
        messageText
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: UserMessageMeasuredHeightKey.self,
                        value: geometry.size.height
                    )
                }
            }
    }
}

private struct UserMessageMeasuredHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
