import AppKit
import SwiftUI

struct ConversationLayout<Header: View>: View {
    @Binding var draft: String
    @Binding var selectedModelId: String
    let menuModels: [ChatModel]
    let messages: [ChatMessage]
    let isStreaming: Bool
    let expandedMode: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    var onToolExpandedChange: ((String, String, Bool) -> Void)?
    var usesHudMaterial: Bool = false
    var usesExternalTitleBar: Bool = false
    var compactResizeConfig: CompactResizeOverlayConfig? = nil
    @Environment(\.appFontSettings) private var fontSettings
    @State private var isAtBottom = true
    @State private var scrollToBottomSignal = 0
    @ViewBuilder var header: () -> Header

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
    }

    private var chromeBlurMaterial: NSVisualEffectView.Material {
        FloatingChromeMetrics.chromeBlurMaterial(usesHudWindow: usesHudMaterial)
    }

    private var expandedContentMaxWidth: CGFloat? {
        expandedMode ? FloatingChromeMetrics.expandedContentMaxWidth : nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            MessageListView(
                messages: messages,
                isStreaming: isStreaming,
                scrollToBottomSignal: scrollToBottomSignal,
                onAtBottomChange: { isAtBottom = $0 },
                onToolExpandedChange: onToolExpandedChange,
                topInset: FloatingChromeMetrics.headerScrollInset(
                    expanded: expandedMode,
                    externalTitleBar: usesExternalTitleBar
                ),
                bottomInset: FloatingChromeMetrics.inputOverlayHeight,
                scrollerInsets: FloatingChromeMetrics.conversationScrollerInsets(
                    expanded: expandedMode,
                    externalTitleBar: usesExternalTitleBar
                ),
                contentMaxWidth: expandedContentMaxWidth
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let compactResizeConfig {
                CompactWindowResizeOverlay(
                    anchor: compactResizeConfig.anchor,
                    minSize: compactResizeConfig.minSize,
                    maxSize: compactResizeConfig.maxSize,
                    collapseHeight: compactResizeConfig.collapseHeight,
                    headerExclusionHeight: compactResizeConfig.headerExclusionHeight,
                    isStripMode: compactResizeConfig.isStripMode,
                    onResizeStarted: compactResizeConfig.onResizeStarted,
                    onResizeEnded: compactResizeConfig.onResizeEnded,
                    onCollapseToStrip: compactResizeConfig.onCollapseToStrip
                )
                .zIndex(1)
            }

            if !usesExternalTitleBar {
                FloatingHeaderChrome(
                    expanded: expandedMode,
                    chromeBlurMaterial: chromeBlurMaterial,
                    content: header
                )
                .zIndex(2)
            }

            ZStack(alignment: .bottom) {
                ChromeEdgeBlur(
                    edge: .bottom,
                    height: FloatingChromeMetrics.bottomEdgeBlurHeight,
                    material: chromeBlurMaterial,
                    blendingMode: FloatingChromeMetrics.chromeBlurBlendingMode
                )
                .allowsHitTesting(false)

                VStack(spacing: 8) {
                    if !isAtBottom, !messages.isEmpty {
                        JumpToBottomButton(
                            fontSettings: fontSettings,
                            glassMaterial: glassMaterial
                        ) {
                            scrollToBottomSignal += 1
                        }
                        .frame(maxWidth: expandedContentMaxWidth ?? .infinity)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }

                    ChatInputBar(
                        draft: $draft,
                        selectedModelId: $selectedModelId,
                        menuModels: menuModels,
                        fontSettings: fontSettings,
                        isStreaming: isStreaming,
                        onSend: onSend,
                        onStop: onStop,
                        expandedMode: expandedMode,
                        usesHudMaterial: usesHudMaterial
                    )
                    .padding(.horizontal, FloatingChromeMetrics.inputHorizontalPadding)
                    .padding(.bottom, FloatingChromeMetrics.inputBottomPadding)
                    .frame(maxWidth: expandedContentMaxWidth ?? .infinity)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(1)
            .animation(.easeInOut(duration: 0.18), value: isAtBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ConversationLayout where Header == EmptyView {
    init(
        draft: Binding<String>,
        selectedModelId: Binding<String>,
        menuModels: [ChatModel],
        messages: [ChatMessage],
        isStreaming: Bool,
        expandedMode: Bool,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onToolExpandedChange: ((String, String, Bool) -> Void)? = nil,
        usesHudMaterial: Bool = false,
        usesExternalTitleBar: Bool = false,
        compactResizeConfig: CompactResizeOverlayConfig? = nil
    ) {
        self._draft = draft
        self._selectedModelId = selectedModelId
        self.menuModels = menuModels
        self.messages = messages
        self.isStreaming = isStreaming
        self.expandedMode = expandedMode
        self.onSend = onSend
        self.onStop = onStop
        self.onToolExpandedChange = onToolExpandedChange
        self.usesHudMaterial = usesHudMaterial
        self.usesExternalTitleBar = usesExternalTitleBar
        self.compactResizeConfig = compactResizeConfig
        self.header = { EmptyView() }
    }
}
