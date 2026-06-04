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
    var usesHudMaterial: Bool = false
    @Environment(\.appFontSettings) private var fontSettings
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
                topInset: FloatingChromeMetrics.headerScrollInset(expanded: expandedMode),
                bottomInset: FloatingChromeMetrics.inputOverlayHeight,
                contentMaxWidth: expandedContentMaxWidth
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingHeaderChrome(
                expanded: expandedMode,
                chromeBlurMaterial: chromeBlurMaterial,
                contentMaxWidth: expandedContentMaxWidth,
                content: header
            )
            .zIndex(1)

            ZStack(alignment: .bottom) {
                ChromeEdgeBlur(
                    edge: .bottom,
                    height: FloatingChromeMetrics.bottomEdgeBlurHeight,
                    material: chromeBlurMaterial,
                    blendingMode: FloatingChromeMetrics.chromeBlurBlendingMode
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ChatInputBar(
                        draft: $draft,
                        selectedModelId: $selectedModelId,
                        menuModels: menuModels,
                        fontSettings: fontSettings,
                        isStreaming: isStreaming,
                        onSend: onSend,
                        expandedMode: expandedMode,
                        usesHudMaterial: usesHudMaterial
                    )
                    .padding(.horizontal, FloatingChromeMetrics.inputHorizontalPadding)
                    .padding(.bottom, FloatingChromeMetrics.inputBottomPadding)
                    .frame(maxWidth: expandedContentMaxWidth ?? .infinity)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(1)
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
        usesHudMaterial: Bool = false
    ) {
        self._draft = draft
        self._selectedModelId = selectedModelId
        self.menuModels = menuModels
        self.messages = messages
        self.isStreaming = isStreaming
        self.expandedMode = expandedMode
        self.onSend = onSend
        self.usesHudMaterial = usesHudMaterial
        self.header = { EmptyView() }
    }
}
