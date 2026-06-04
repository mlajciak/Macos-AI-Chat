import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    /// When set, message column is capped and centered (expanded window).
    var contentMaxWidth: CGFloat?
    @Environment(\.appFontSettings) private var fontSettings

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if messages.isEmpty {
                        Text("Ask anything (demo mode)")
                            .appFont(.body, settings: fontSettings)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message, fontSettings: fontSettings)
                                .id(message.id)
                        }
                    }

                    if isStreaming {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking…")
                                .appFont(.caption, settings: fontSettings)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .id("streaming-indicator")
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
            .onChange(of: isStreaming) { _, streaming in
                if streaming { scrollToBottom(proxy) }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        let target = isStreaming ? "streaming-indicator" : "scroll-end"
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}
