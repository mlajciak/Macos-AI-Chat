import SwiftUI

struct ChatRootView: View {
    @Bindable var viewModel: ChatViewModel
    let mode: WindowMode
    let compactPresentation: CompactPresentation
    let isContentVisible: Bool
    let onExpand: () -> Void
    let onCompact: () -> Void
    let onRestoreCompactPanel: () -> Void
    let onClose: () -> Void
    var onCompactResizeStarted: (() -> Void)?
    var onCompactResizeEnded: (() -> Void)?
    var onCollapseToStrip: (() -> Void)?
    var onCompactAnchorChange: (() -> Void)?
    var onFloatingDragEnded: (() -> Void)?

    private var isCompactStrip: Bool {
        mode == .compact && compactPresentation == .strip
    }

    private var compactPanelResizeConfig: CompactResizeOverlayConfig {
        CompactResizeOverlayConfig(
            anchor: viewModel.preferences.compactWindowAnchor,
            minSize: NSSize(
                width: ChatWindowController.compactMinSize.width,
                height: ChatWindowController.compactMinSize.height
            ),
            maxSize: NSSize(
                width: ChatWindowController.compactMaxSize.width,
                height: ChatWindowController.compactMaxSize.height
            ),
            collapseHeight: ChatWindowController.compactCollapseHeight,
            headerExclusionHeight: FloatingChromeMetrics.headerOverlayHeight(expanded: false),
            isStripMode: false,
            onResizeStarted: onCompactResizeStarted,
            onResizeEnded: onCompactResizeEnded,
            onCollapseToStrip: onCollapseToStrip
        )
    }

    private var theme: AppThemeColors { .default }

    var body: some View {
        compactWindowChrome {
            ZStack {
                windowChromeBackground

                Group {
                    if mode == .expanded {
                        ExpandedWindowLayout(
                            viewModel: viewModel,
                            onCompact: onCompact
                        )
                    } else if isCompactStrip {
                        compactStripBody
                    } else {
                        compactBody
                    }
                }
            }
        }
        .opacity(isContentVisible ? 1 : 0)
        .allowsHitTesting(isContentVisible)
        .animation(.easeOut(duration: 0.22), value: isContentVisible)
        .appAccentEnvironment(viewModel.preferences)
        .appMonoFont()
        .overlay {
            if isContentVisible, !isCompactStrip, viewModel.isSettingsOpen {
                SettingsOverlay(
                    preferences: viewModel.preferences,
                    usesHudMaterial: true,
                    onClose: { viewModel.closeOverlays() }
                )
                .appFontContext(viewModel.preferences.fontSettings)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.isSettingsOpen)
        .onChange(of: viewModel.preferences.menuModelIds) { _, _ in
            viewModel.syncSelectedModel()
        }
        .onChange(of: viewModel.preferences.compactWindowAnchor) { _, _ in
            onCompactAnchorChange?()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func compactWindowChrome<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if mode == .compact {
            if isCompactStrip {
                content()
                    .clipShape(Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(theme.overlayStroke, lineWidth: 1)
                    }
            } else {
                content()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: FloatingChromeMetrics.menuOverlayCornerRadius,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: FloatingChromeMetrics.menuOverlayCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(theme.overlayStroke, lineWidth: 1)
                    }
            }
        } else {
            content()
        }
    }

    @ViewBuilder
    private var windowChromeBackground: some View {
        if mode == .compact {
            VisualEffectBackground(
                material: .hudWindow,
                blendingMode: .behindWindow,
                emphasized: false
            )
        }
    }

    @ViewBuilder
    private func compactResizeOverlayView(_ config: CompactResizeOverlayConfig) -> some View {
        CompactWindowResizeOverlay(
            anchor: config.anchor,
            minSize: config.minSize,
            maxSize: config.maxSize,
            collapseHeight: config.collapseHeight,
            headerExclusionHeight: config.headerExclusionHeight,
            isStripMode: config.isStripMode,
            onResizeStarted: config.onResizeStarted,
            onResizeEnded: config.onResizeEnded,
            onCollapseToStrip: config.onCollapseToStrip
        )
        .zIndex(1)
    }

    private var compactStripBody: some View {
        CompactStripBarView(
            fontSettings: viewModel.preferences.fontSettings,
            allowsHeaderDrag: viewModel.preferences.compactWindowAnchor == .floating,
            onFloatingDragEnded: onFloatingDragEnded,
            onRestorePanel: onRestoreCompactPanel
        )
        .frame(
            width: FloatingChromeMetrics.compactStripWidth,
            height: FloatingChromeMetrics.compactStripHeight
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    usesHudMaterial: true,
                    compactResizeConfig: compactPanelResizeConfig
                ) {
                    CompactHeaderView(
                        viewModel: viewModel,
                        onExpand: onExpand,
                        onClose: onClose,
                        onFloatingDragEnded: onFloatingDragEnded
                    )
                }
            } else {
                ZStack(alignment: .top) {
                    compactResizeOverlayView(compactPanelResizeConfig)

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
                    .zIndex(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
