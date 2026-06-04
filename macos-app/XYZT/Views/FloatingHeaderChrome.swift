import AppKit
import SwiftUI

struct FloatingHeaderChrome<Content: View>: View {
    let expanded: Bool
    let chromeBlurMaterial: NSVisualEffectView.Material
    var contentMaxWidth: CGFloat?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                Color.clear
                    .frame(height: FloatingChromeMetrics.expandedTrafficLightInset)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            content()
                .padding(.horizontal, 12)
                .padding(.top, expanded ? 0 : FloatingChromeMetrics.headerTopPadding)
                .padding(.bottom, FloatingChromeMetrics.headerBottomPadding)
                .frame(height: FloatingChromeMetrics.headerBarHeight)
                .frame(maxWidth: contentMaxWidth ?? .infinity)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            ChromeEdgeBlur(
                edge: .top,
                height: FloatingChromeMetrics.topEdgeBlurHeight,
                material: chromeBlurMaterial,
                blendingMode: FloatingChromeMetrics.chromeBlurBlendingMode
            )
        }
    }
}
