import AppKit
import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    let isStreaming: Bool
    var scrollToBottomSignal: Int = 0
    var onAtBottomChange: ((Bool) -> Void)?
    var onToolExpandedChange: ((String, String, Bool) -> Void)?
    var onApproveCommand: ((String, String) -> Void)?
    var onRejectCommand: ((String, String) -> Void)?
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    /// When set, message column is capped and centered (expanded window).
    var contentMaxWidth: CGFloat?
    @Environment(\.appFontSettings) private var fontSettings

    @State private var scrollPinTask: Task<Void, Never>?
    @State private var stickToBottom = true

    private static let scrollEndId = "scroll-end"
    private static let atBottomThreshold: CGFloat = 36

    private var scrollContentToken: String {
        guard let last = messages.last else { return "empty" }
        let toolChars = last.toolCards.reduce(0) { $0 + $1.body.count + $1.argsPreview.count }
        return "\(last.id)|\(last.content.count)|\(toolChars)|\(last.toolCards.count)"
    }

    private var activeStreamingToolId: String? {
        guard isStreaming,
              let last = messages.last,
              last.role == .assistant
        else { return nil }
        return last.toolCards.last(where: { $0.status == .running })?.id
            ?? last.toolCards.last?.id
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                fontSettings: fontSettings,
                                isActivelyStreaming: isStreaming
                                    && message.role == .assistant
                                    && message.id == messages.last?.id,
                                streamingToolId: message.id == messages.last?.id
                                    ? activeStreamingToolId
                                    : nil,
                                onToolExpandedChange: { toolId, expanded in
                                    onToolExpandedChange?(message.id, toolId, expanded)
                                },
                                onApproveCommand: { toolId in
                                    onApproveCommand?(message.id, toolId)
                                },
                                onRejectCommand: { toolId in
                                    onRejectCommand?(message.id, toolId)
                                }
                            )
                            .id(message.id)
                        }

                        Color.clear
                            .frame(height: max(bottomInset, 0))
                            .accessibilityHidden(true)
                        Color.clear
                            .frame(height: 1)
                            .id(Self.scrollEndId)
                    }
                    .padding(.horizontal, MessageListLayout.horizontalPadding)
                    .padding(.top, topInset)
                    .frame(maxWidth: contentMaxWidth ?? .infinity)
                    .frame(maxWidth: .infinity)
                    .appScrollStyle()
                    .appScrollBottomObserver { distance in
                        let atBottom = distance <= Self.atBottomThreshold
                        if atBottom {
                            stickToBottom = true
                        } else if !isStreaming {
                            stickToBottom = false
                        }
                        onAtBottomChange?(atBottom)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .appVerticalScrollIndicators()
                .appScrollToBottomOnTrigger(scrollToBottomSignal)
                .onAppear {
                    stickToBottom = true
                    scrollToEnd(proxy: proxy, animated: false)
                }
                .onChange(of: messages.count) { _, _ in
                    stickToBottom = true
                    scrollToEnd(proxy: proxy, animated: false)
                }
                .onChange(of: scrollContentToken) { _, _ in
                    guard stickToBottom || isStreaming else { return }
                    scrollToEnd(proxy: proxy, animated: false, throttle: isStreaming)
                }
                .onChange(of: isStreaming) { _, streaming in
                    if streaming {
                        stickToBottom = true
                        scrollToEnd(proxy: proxy, animated: false)
                    }
                }
                .onChange(of: scrollToBottomSignal) { _, _ in
                    stickToBottom = true
                    scrollToEnd(proxy: proxy, animated: true)
                }
                .onChange(of: viewport.size) { _, _ in
                    guard stickToBottom else { return }
                    scrollToEnd(proxy: proxy, animated: false)
                }
                .onDisappear {
                    scrollPinTask?.cancel()
                }
            }
        }
    }

    private func scrollToEnd(
        proxy: ScrollViewProxy,
        animated: Bool,
        throttle: Bool = false
    ) {
        scrollPinTask?.cancel()
        let perform = {
            let scroll = {
                if let lastId = messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
                proxy.scrollTo(Self.scrollEndId, anchor: .bottom)
            }
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    scroll()
                }
            } else {
                scroll()
            }
        }
        if throttle {
            scrollPinTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(48))
                guard !Task.isCancelled else { return }
                perform()
            }
            return
        }
        DispatchQueue.main.async {
            perform()
            DispatchQueue.main.async {
                perform()
            }
        }
    }
}
