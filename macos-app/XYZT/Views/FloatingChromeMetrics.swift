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
    static var headerTopPadding: CGFloat { headerHorizontalPadding }
    static let headerBottomPadding: CGFloat = 6
    static let headerBarHeight: CGFloat = 36
    /// Minimal pill shown when the compact panel collapses to one row.
    static let compactStripHeight: CGFloat = 32
    static let compactStripWidth: CGFloat = 72
    static var compactStripCornerRadius: CGFloat { compactStripHeight / 2 }
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

    /// Header chrome band (padding + bar); excludes the fade gap below.
    static func headerChromeHeight(expanded: Bool) -> CGFloat {
        if expanded {
            return expandedTrafficLightInset + headerBarHeight + headerBottomPadding
        }
        return headerTopPadding + headerBarHeight + headerBottomPadding
    }

    /// Height of the floating header overlay (compact or expanded in-window chrome).
    static func headerOverlayHeight(expanded: Bool) -> CGFloat {
        headerChromeHeight(expanded: expanded) + chromeContentGap
    }

    static func headerScrollInset(expanded: Bool, externalTitleBar: Bool = false) -> CGFloat {
        if expanded && externalTitleBar {
            return headerBottomPadding + chromeContentGap
        }
        return headerOverlayHeight(expanded: expanded)
    }

    static let inputHorizontalPadding: CGFloat = 12
    static let inputBottomPadding: CGFloat = 10

    /// Matches compact floating panel corners (session/settings overlays).
    static let menuOverlayCornerRadius: CGFloat = 12
}
