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

    private var isCompactStrip: Bool {
        mode == .compact && compactPresentation == .strip
    }

    var body: some View {
        Group {
            if mode == .compact {
                if isCompactStrip {
                    compactStripBody
                } else {
                    compactBody
                }
            } else {
                expandedBody
            }
        }
        .appFontEnvironment(viewModel.preferences)
        .appMonoFont()
        .overlay {
            if !isCompactStrip {
                headerOverlays(usesHudMaterial: mode == .compact)
                    .appFontContext(viewModel.preferences.fontSettings)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.isSessionBrowserOpen)
        .animation(.easeInOut(duration: 0.22), value: viewModel.isSettingsOpen)
        .animation(.easeInOut(duration: 0.22), value: compactPresentation)
        .onChange(of: viewModel.preferences.menuModelIds) { _, _ in
            viewModel.syncSelectedModel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func headerOverlays(usesHudMaterial: Bool) -> some View {
        if viewModel.isSessionBrowserOpen {
            SessionBrowserOverlay(
                viewModel: viewModel,
                usesHudMaterial: usesHudMaterial
            )
        }
        if viewModel.isSettingsOpen {
            SettingsOverlay(
                preferences: viewModel.preferences,
                usesHudMaterial: usesHudMaterial,
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
        .overlay {
            CompactWindowResizeOverlay(
                minSize: ChatWindowController.compactStripSize,
                maxSize: NSSize(
                    width: ChatWindowController.compactMaxSize.width,
                    height: ChatWindowController.compactStripSize.height
                ),
                isStripMode: true,
                onResizeStarted: onCompactResizeStarted,
                onResizeEnded: onCompactResizeEnded
            )
            .allowsHitTesting(true)
        }
    }

    private var compactBody: some View {
        ConversationLayout(
            draft: $viewModel.draft,
            selectedModelId: $viewModel.selectedModelId,
            menuModels: viewModel.menuModels,
            messages: viewModel.session.messages,
            isStreaming: viewModel.session.isStreaming,
            expandedMode: false,
            onSend: { viewModel.send() },
            onToolExpandedChange: { messageId, toolId, expanded in
                viewModel.setToolExpanded(messageId: messageId, toolId: toolId, isExpanded: expanded)
            },
            usesHudMaterial: true
        ) {
            CompactHeaderView(
                viewModel: viewModel,
                onExpand: onExpand,
                onClose: onClose
            )
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

    private var expandedBody: some View {
        ConversationLayout(
            draft: $viewModel.draft,
            selectedModelId: $viewModel.selectedModelId,
            menuModels: viewModel.menuModels,
            messages: viewModel.session.messages,
            isStreaming: viewModel.session.isStreaming,
            expandedMode: true,
            onSend: { viewModel.send() },
            onToolExpandedChange: { messageId, toolId, expanded in
                viewModel.setToolExpanded(messageId: messageId, toolId: toolId, isExpanded: expanded)
            },
            usesHudMaterial: false
        ) {
            ExpandedFloatingHeaderView(
                viewModel: viewModel,
                onCompact: onCompact
            )
        }
        .background {
            VisualEffectBackground(
                material: .windowBackground,
                blendingMode: .behindWindow,
                emphasized: false
            )
        }
    }
}
