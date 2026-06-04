import AppKit
import Foundation

enum FloatingChromeMetrics {
    static func chromeBlurMaterial(usesHudWindow: Bool) -> NSVisualEffectView.Material {
        usesHudWindow ? .hudWindow : .windowBackground
    }

    static let chromeBlurBlendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    /// Reading-width column for expanded window (messages, input, header content).
    static let expandedContentMaxWidth: CGFloat = 720

    static let headerHorizontalPadding: CGFloat = 12
    static let headerTopPadding: CGFloat = 10
    static let headerBottomPadding: CGFloat = 6
    static let headerBarHeight: CGFloat = 36
    /// Single-line collapsed compact bar (chevron + title + window actions).
    static let compactStripHeight: CGFloat = 40
    static let expandedTrafficLightInset: CGFloat = 28
    /// Leading band reserved for traffic lights (sidebar + collapsed detail).
    static let expandedTrafficLightsLeadingWidth: CGFloat = 78
    /// Fallback when SwiftUI safe-area top is not yet measured.
    static let expandedWindowTitlebarFallback: CGFloat = 28
    static let expandedSidebarToolbarBandHeight: CGFloat = 32

    static var expandedSidebarHeaderHeight: CGFloat {
        expandedWindowTitlebarFallback + expandedSidebarToolbarBandHeight
    }

    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 260
    static let sidebarMaxWidth: CGFloat = 320

    static let topEdgeBlurHeight: CGFloat = 72
    static let bottomEdgeBlurHeight: CGFloat = 28
    static let chromeContentGap: CGFloat = 8

    /// Two-row input interior (message field + model/send row).
    static let inputBarHeight: CGFloat = 88
    static let inputBarPadding: CGFloat = 20

    static var inputOverlayHeight: CGFloat {
        inputBarHeight + inputBarPadding + inputBottomPadding + chromeContentGap
    }

    /// Height of the floating header overlay (compact or expanded in-window chrome).
    static func headerOverlayHeight(expanded: Bool) -> CGFloat {
        if expanded {
            return expandedTrafficLightInset + headerBarHeight + headerBottomPadding + chromeContentGap
        }
        return headerTopPadding + headerBarHeight + headerBottomPadding + chromeContentGap
    }

    static func headerScrollInset(expanded: Bool, externalTitleBar: Bool = false) -> CGFloat {
        if expanded && externalTitleBar {
            return headerBottomPadding + chromeContentGap
        }
        return headerOverlayHeight(expanded: expanded)
    }

    /// Insets only the vertical scroller; scroll content still uses full `headerScrollInset` / `inputOverlayHeight`.
    static func conversationScrollerInsets(expanded: Bool, externalTitleBar: Bool) -> NSEdgeInsets {
        let top = externalTitleBar ? 0 : headerOverlayHeight(expanded: expanded)
        return NSEdgeInsets(top: top, left: 0, bottom: inputOverlayHeight, right: 0)
    }

    static let inputHorizontalPadding: CGFloat = 12
    static let inputBottomPadding: CGFloat = 10

    /// Matches compact floating panel corners (session/settings overlays).
    static let menuOverlayCornerRadius: CGFloat = 12
}
