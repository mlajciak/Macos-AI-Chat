import SwiftUI

/// Expanded window uses the same in-window chrome as compact (floating header + modal settings).
struct ExpandedWindowLayout: View {
    @Bindable var viewModel: ChatViewModel
    let onCompact: () -> Void

    private var chromeBlurMaterial: NSVisualEffectView.Material {
        FloatingChromeMetrics.chromeBlurMaterial(usesHudWindow: true)
    }

    var body: some View {
        Group {
            if viewModel.hasWorkspace {
                ConversationLayout(
                    draft: $viewModel.draft,
                    selectedModelId: $viewModel.selectedModelId,
                    selectedImageModelId: $viewModel.selectedImageModelId,
                    menuModels: viewModel.menuModels,
                    imageMenuModels: viewModel.imageMenuModels,
                    messages: viewModel.session.messages,
                    isStreaming: viewModel.session.isStreaming,
                    expandedMode: true,
                    onSend: { viewModel.send() },
                    onStop: { viewModel.stopGeneration() },
                    onToolExpandedChange: { messageId, toolId, expanded in
                        viewModel.setToolExpanded(
                            messageId: messageId,
                            toolId: toolId,
                            isExpanded: expanded
                        )
                    },
                    onApproveCommand: { messageId, toolId in
                        viewModel.respondToToolApproval(
                            messageId: messageId,
                            toolId: toolId,
                            approved: true
                        )
                    },
                    onRejectCommand: { messageId, toolId in
                        viewModel.respondToToolApproval(
                            messageId: messageId,
                            toolId: toolId,
                            approved: false
                        )
                    },
                    usesHudMaterial: true
                ) {
                    ChatPanelHeaderView(
                        viewModel: viewModel,
                        windowAction: .compact(action: onCompact),
                        trafficLightsLeadingInset: FloatingChromeMetrics.expandedTrafficLightsLeadingWidth
                    )
                }
            } else {
                ZStack(alignment: .top) {
                    OpenFolderGateView(
                        fontSettings: viewModel.preferences.fontSettings,
                        onOpenFolder: { viewModel.openProjectFolder() }
                    )
                    FloatingHeaderChrome(
                        expanded: true,
                        chromeBlurMaterial: chromeBlurMaterial
                    ) {
                        ChatPanelHeaderView(
                            viewModel: viewModel,
                            windowAction: .compact(action: onCompact),
                            trafficLightsLeadingInset: FloatingChromeMetrics.expandedTrafficLightsLeadingWidth
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.closeOverlays()
        }
    }
}
