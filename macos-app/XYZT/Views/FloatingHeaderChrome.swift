import AppKit
import SwiftUI

struct FloatingHeaderChrome<Content: View>: View {
    let expanded: Bool
    let chromeBlurMaterial: NSVisualEffectView.Material
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
                .padding(.horizontal, FloatingChromeMetrics.headerHorizontalPadding)
                .padding(.top, expanded ? 0 : FloatingChromeMetrics.headerTopPadding)
                .padding(.bottom, FloatingChromeMetrics.headerBottomPadding)
                .frame(height: FloatingChromeMetrics.headerBarHeight)
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
        .contentShape(Rectangle())
    }
}
