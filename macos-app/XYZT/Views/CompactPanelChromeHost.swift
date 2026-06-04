import SwiftUI

/// In-window resize overlay below header chrome (`zIndex` 1); header stays at 2.
struct CompactPanelChromeHost<Content: View>: View {
    let resizeConfig: CompactResizeOverlayConfig?
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            content()

            if let resizeConfig {
                CompactWindowResizeOverlay(
                    anchor: resizeConfig.anchor,
                    minSize: resizeConfig.minSize,
                    maxSize: resizeConfig.maxSize,
                    headerExclusionHeight: resizeConfig.headerExclusionHeight,
                    isStripMode: resizeConfig.isStripMode,
                    onResizeStarted: resizeConfig.onResizeStarted,
                    onResizeEnded: resizeConfig.onResizeEnded,
                    onCollapseToStrip: resizeConfig.onCollapseToStrip
                )
                .zIndex(1)
            }
        }
    }
}
