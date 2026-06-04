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
            headerExclusionHeight: FloatingChromeMetrics.headerOverlayHeight(expanded: false),
            isStripMode: false,
            onResizeStarted: onCompactResizeStarted,
            onResizeEnded: onCompactResizeEnded,
            onCollapseToStrip: onCollapseToStrip
        )
    }

    private var compactStripResizeConfig: CompactResizeOverlayConfig {
        CompactResizeOverlayConfig(
            anchor: viewModel.preferences.compactWindowAnchor,
            minSize: NSSize(
                width: ChatWindowController.compactMinSize.width,
                height: ChatWindowController.compactStripSize.height
            ),
            maxSize: NSSize(
                width: ChatWindowController.compactMaxSize.width,
                height: ChatWindowController.compactStripSize.height
            ),
            headerExclusionHeight: 0,
            isStripMode: true,
            onResizeStarted: onCompactResizeStarted,
            onResizeEnded: onCompactResizeEnded,
            onCollapseToStrip: nil
        )
    }

    private var theme: AppThemeColors {
        AppAccentPalette.themeColors(
            hue: viewModel.preferences.primaryColorHue,
            spread: viewModel.preferences.primaryColorIntensity
        )
    }

    var body: some View {
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
        .appAccentEnvironment(viewModel.preferences)
        .appMonoFont()
        .overlay {
            if !isCompactStrip, viewModel.isSettingsOpen {
                SettingsOverlay(
                    preferences: viewModel.preferences,
                    usesHudMaterial: true,
                    onClose: { viewModel.closeOverlays() }
                )
                .appFontContext(viewModel.preferences.fontSettings)
            }
        }
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

    private var compactStripBody: some View {
        CompactPanelChromeHost(resizeConfig: compactStripResizeConfig) {
            CompactStripBarView(
                fontSettings: viewModel.preferences.fontSettings,
                allowsHeaderDrag: viewModel.preferences.compactWindowAnchor == .floating,
                onFloatingDragEnded: onFloatingDragEnded,
                onRestorePanel: onRestoreCompactPanel,
                onExpandWindow: onExpand,
                onClose: onClose
            )
            .zIndex(2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .strokeBorder(theme.overlayStroke, lineWidth: 1)
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
                        onClose: onClose,
                        onFloatingDragEnded: onFloatingDragEnded
                    )
                }
                .compactResizeOverlay(compactPanelResizeConfig)
            } else {
                CompactPanelChromeHost(resizeConfig: compactPanelResizeConfig) {
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
                        .zIndex(2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .strokeBorder(theme.overlayStroke, lineWidth: 1)
        }
    }
}
