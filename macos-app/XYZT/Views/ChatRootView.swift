import SwiftUI

private let compactPanelCornerRadius: CGFloat = 12

struct ChatRootView: View {
    @Bindable var viewModel: ChatViewModel
    let mode: WindowMode
    let compactPresentation: CompactPresentation
    let onExpand: () -> Void
    let onCompact: () -> Void
    let onRestoreCompactPanel: () -> Void
    let onClose: () -> Void
    var onCompactResizeStarted: (() -> Void)?
    var onCompactResizeEnded: (() -> Void)?
    var onCollapseToStrip: (() -> Void)?
    var onCompactAnchorChange: (() -> Void)?

    private var isCompactStrip: Bool {
        mode == .compact && compactPresentation == .strip
    }

    var body: some View {
        Group {
            if mode == .expanded {
                ExpandedWindowLayout(viewModel: viewModel)
            } else if isCompactStrip {
                compactStripBody
            } else {
                compactBody
            }
        }
        .appFontEnvironment(viewModel.preferences)
        .appMonoFont()
        .overlay {
            if mode == .compact, !isCompactStrip {
                headerOverlays
                    .appFontContext(viewModel.preferences.fontSettings)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.isSessionBrowserOpen)
        .animation(.easeInOut(duration: 0.22), value: viewModel.isSettingsOpen)
        .animation(.easeInOut(duration: 0.22), value: compactPresentation)
        .animation(.easeInOut(duration: 0.22), value: mode)
        .onChange(of: viewModel.preferences.menuModelIds) { _, _ in
            viewModel.syncSelectedModel()
        }
        .onChange(of: viewModel.preferences.compactWindowAnchor) { _, _ in
            onCompactAnchorChange?()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var headerOverlays: some View {
        if viewModel.isSessionBrowserOpen {
            SessionBrowserOverlay(
                viewModel: viewModel,
                usesHudMaterial: true
            )
        }
        if viewModel.isSettingsOpen {
            SettingsOverlay(
                preferences: viewModel.preferences,
                usesHudMaterial: true,
                onClose: { viewModel.closeOverlays() }
            )
        }
    }

    private var compactStripBody: some View {
        CompactStripBarView(
            fontSettings: viewModel.preferences.fontSettings,
            onRestorePanel: onRestoreCompactPanel,
            onExpandWindow: onExpand,
            onClose: onClose
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            VisualEffectBackground(
                material: .hudWindow,
                blendingMode: .behindWindow,
                emphasized: false
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: compactPanelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compactPanelCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    private var compactBody: some View {
        Group {
            if viewModel.hasWorkspace {
                ConversationLayout(
                    draft: $viewModel.draft,
                    selectedModelId: $viewModel.selectedModelId,
                    menuModels: viewModel.menuModels,
                    messages: viewModel.session.messages,
                    isStreaming: viewModel.session.isStreaming,
                    expandedMode: false,
                    onSend: { viewModel.send() },
                    onStop: { viewModel.stopGeneration() },
                    onToolExpandedChange: { messageId, toolId, expanded in
                        viewModel.setToolExpanded(
                            messageId: messageId,
                            toolId: toolId,
                            isExpanded: expanded
                        )
                    },
                    usesHudMaterial: true
                ) {
                    CompactHeaderView(
                        viewModel: viewModel,
                        onExpand: onExpand,
                        onClose: onClose
                    )
                }
            } else {
                ZStack(alignment: .top) {
                    OpenFolderGateView(
                        fontSettings: viewModel.preferences.fontSettings,
                        onOpenFolder: { viewModel.openProjectFolder() }
                    )
                    FloatingHeaderChrome(
                        expanded: false,
                        chromeBlurMaterial: FloatingChromeMetrics.chromeBlurMaterial(usesHudWindow: true)
                    ) {
                        CompactHeaderView(
                            viewModel: viewModel,
                            onExpand: onExpand,
                            onClose: onClose
                        )
                    }
                }
            }
        }
        .background {
            VisualEffectBackground(
                material: .hudWindow,
                blendingMode: .behindWindow,
                emphasized: false
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: compactPanelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compactPanelCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .overlay {
            CompactWindowResizeOverlay(
                anchor: viewModel.preferences.compactWindowAnchor,
                minSize: NSSize(
                    width: ChatWindowController.compactMinSize.width,
                    height: ChatWindowController.compactMinSize.height
                ),
                maxSize: NSSize(
                    width: ChatWindowController.compactMaxSize.width,
                    height: ChatWindowController.compactMaxSize.height
                ),
                isStripMode: false,
                onResizeStarted: onCompactResizeStarted,
                onResizeEnded: onCompactResizeEnded,
                onCollapseToStrip: onCollapseToStrip
            )
            .allowsHitTesting(true)
        }
    }
}
