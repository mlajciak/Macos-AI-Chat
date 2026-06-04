import SwiftUI

/// Top-right toolbar on the expanded window detail column (new chat, settings, compact).
struct ExpandedDetailToolbar: View {
    @Bindable var viewModel: ChatViewModel
    let onCompact: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let titlebarTop = max(
                proxy.safeAreaInsets.top,
                FloatingChromeMetrics.expandedWindowTitlebarFallback
            )

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HeaderToolbarActions(
                    viewModel: viewModel,
                    windowAction: .compact(action: onCompact),
                    glassMaterial: .titlebar
                )
                .padding(.trailing, 12)
            }
            .padding(.top, titlebarTop)
            .frame(
                height: titlebarTop + FloatingChromeMetrics.expandedSidebarToolbarBandHeight,
                alignment: .bottom
            )
            .frame(maxWidth: .infinity)
            .background {
                VisualEffectBackground(
                    material: .titlebar,
                    blendingMode: .behindWindow,
                    emphasized: false
                )
            }
        }
        .frame(height: FloatingChromeMetrics.expandedDetailToolbarHeight)
    }
}
