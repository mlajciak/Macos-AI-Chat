import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    var onToolExpandedChange: ((String, String, Bool) -> Void)?
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    /// When set, message column is capped and centered (expanded window).
    var contentMaxWidth: CGFloat?
    @Environment(\.appFontSettings) private var fontSettings

    private var scrollAnchorId: String {
        if let last = messages.last, last.role == .assistant, last.hasVisibleContent {
            return last.id
        }
        return "scroll-end"
    }

    private var scrollContentToken: String {
        guard let last = messages.last else { return "" }
        let toolChars = last.toolCards.reduce(0) { $0 + $1.body.count }
        return "\(last.id)|\(last.content.count)|\(toolChars)|\(last.toolCards.count)"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if messages.isEmpty {
                        Text("Ask anything…")
                            .appFont(.body, settings: fontSettings)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                fontSettings: fontSettings,
                                onToolExpandedChange: { toolId, expanded in
                                    onToolExpandedChange?(message.id, toolId, expanded)
                                }
                            )
                            .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 4)
                        .id("scroll-end")
                }
                .padding(.horizontal, MessageListLayout.horizontalPadding)
                .padding(.top, topInset)
                .padding(.bottom, bottomInset)
                .frame(maxWidth: contentMaxWidth ?? .infinity)
                .frame(maxWidth: .infinity)
                .appScrollStyle()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentMargins(.top, topInset, for: .scrollIndicators)
            .contentMargins(.bottom, bottomInset, for: .scrollIndicators)
            .appVerticalScrollIndicators()
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: scrollContentToken) { _, _ in scrollToBottom(proxy) }
            .onChange(of: isStreaming) { _, streaming in
                if streaming { scrollToBottom(proxy) }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(scrollAnchorId, anchor: .bottom)
        }
    }
}
