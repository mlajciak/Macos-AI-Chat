import SwiftUI

private let compactPanelCornerRadius: CGFloat = 12

struct ChatRootView: View {
    @Bindable var viewModel: ChatViewModel
    let mode: WindowMode
    let onExpand: () -> Void
    let onCompact: () -> Void
    let onClose: () -> Void
    var onCompactResizeStarted: (() -> Void)?
    var onCompactResizeEnded: (() -> Void)?

    var body: some View {
        Group {
            if mode == .compact {
                compactBody
            } else {
                expandedBody
            }
        }
        .overlay {
            headerOverlays(usesHudMaterial: mode == .compact)
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.isSessionBrowserOpen)
        .animation(.easeInOut(duration: 0.22), value: viewModel.isSettingsOpen)
        .animation(.easeInOut(duration: 0.22), value: viewModel.preferences.bodyPointSize)
        .animation(.easeInOut(duration: 0.22), value: viewModel.preferences.fontFamilyMode)
        .animation(.easeInOut(duration: 0.22), value: viewModel.preferences.customFontFamily)
        .animation(.easeInOut(duration: 0.22), value: viewModel.preferences.theme)
        .appFontEnvironment(viewModel.preferences)
        .appMonoFont()
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

    private var compactBody: some View {
        ConversationLayout(
            draft: $viewModel.draft,
            selectedModelId: $viewModel.selectedModelId,
            messages: viewModel.session.messages,
            isStreaming: viewModel.session.isStreaming,
            expandedMode: false,
            onSend: { viewModel.send() },
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
                onResizeStarted: onCompactResizeStarted,
                onResizeEnded: onCompactResizeEnded
            )
            .allowsHitTesting(true)
        }
    }

    private var expandedBody: some View {
        ConversationLayout(
            draft: $viewModel.draft,
            selectedModelId: $viewModel.selectedModelId,
            messages: viewModel.session.messages,
            isStreaming: viewModel.session.isStreaming,
            expandedMode: true,
            onSend: { viewModel.send() },
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
