import AppKit
import Foundation

enum FloatingChromeMetrics {
    static func chromeBlurMaterial(usesHudWindow: Bool) -> NSVisualEffectView.Material {
        usesHudWindow ? .hudWindow : .windowBackground
    }

    static let chromeBlurBlendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    /// Reading-width column for expanded window (messages, input, header content).
    static let expandedContentMaxWidth: CGFloat = 720

    static let headerTopPadding: CGFloat = 10
    static let headerBottomPadding: CGFloat = 6
    static let headerBarHeight: CGFloat = 36
    static let expandedTrafficLightInset: CGFloat = 28

    static let topEdgeBlurHeight: CGFloat = 72
    static let bottomEdgeBlurHeight: CGFloat = 28
    static let chromeContentGap: CGFloat = 8

    /// Two-row input interior (message field + model/send row).
    static let inputBarHeight: CGFloat = 88
    static let inputBarPadding: CGFloat = 20

    static var inputOverlayHeight: CGFloat {
        inputBarHeight + inputBarPadding + inputBottomPadding + chromeContentGap
    }

    static func headerScrollInset(expanded: Bool) -> CGFloat {
        let bar = headerTopPadding + headerBarHeight + headerBottomPadding + chromeContentGap
        return expanded ? expandedTrafficLightInset + headerBarHeight + headerBottomPadding + chromeContentGap : bar
    }

    static let inputHorizontalPadding: CGFloat = 12
    static let inputBottomPadding: CGFloat = 10

    /// Matches compact floating panel corners (session/settings overlays).
    static let menuOverlayCornerRadius: CGFloat = 12
}
