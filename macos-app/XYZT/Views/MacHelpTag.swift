import AppKit
import SwiftUI

// MARK: - Coordinates

enum MacHelpTagCoordinates {
    /// Converts a view's bounds to screen space (bottom-left origin).
    static func screenRect(for view: NSView) -> NSRect {
        guard let window = view.window else { return .zero }
        guard view.bounds.width > 0.5, view.bounds.height > 0.5 else { return .zero }
        let inWindow = view.convert(view.bounds, to: nil)
        return window.convertToScreen(inWindow)
    }

    /// SwiftUI `.global` frame (top-left origin in window content) → screen rect.
    static func screenRect(globalFrame: CGRect) -> NSRect {
        guard globalFrame.width > 0.5, globalFrame.height > 0.5 else { return .zero }

        let mouse = NSEvent.mouseLocation
        for window in NSApp.windows where window.isVisible {
            guard let contentView = window.contentView else { continue }
            let windowRect = windowRect(fromGlobalFrame: globalFrame, contentHeight: contentView.bounds.height)
            let screenRect = window.convertToScreen(windowRect)
            if screenRect.insetBy(dx: -4, dy: -4).contains(mouse) {
                return screenRect
            }
        }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow, let contentView = window.contentView {
            let windowRect = windowRect(fromGlobalFrame: globalFrame, contentHeight: contentView.bounds.height)
            return window.convertToScreen(windowRect)
        }

        return .zero
    }

    private static func windowRect(fromGlobalFrame frame: CGRect, contentHeight: CGFloat) -> NSRect {
        NSRect(
            x: frame.minX,
            y: contentHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}

// MARK: - Presenter

@MainActor
enum MacHelpTagPresenter {
    private static let showDelay: TimeInterval = 0.45
    private static let gap: CGFloat = 6
    private static let horizontalMargin: CGFloat = 8

    private static var panel: NSPanel?
    private static var hostingView: NSHostingView<MacHelpTagBubble>?
    private static var showWorkItem: DispatchWorkItem?
    private static weak var anchorView: NSView?

    static func scheduleShow(
        text: String,
        anchor: NSView,
        preferredArrowPointsDown: Bool? = nil
    ) {
        cancelPendingShow()
        guard !text.isEmpty, anchor.window != nil else { return }

        anchorView = anchor

        let work = DispatchWorkItem { [weak anchor] in
            guard let anchor, anchorView === anchor else { return }
            let rect = MacHelpTagCoordinates.screenRect(for: anchor)
            guard rect.width > 1, rect.height > 1 else { return }
            show(text: text, anchorScreenRect: rect, preferredArrowPointsDown: preferredArrowPointsDown)
        }
        showWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }

    static func scheduleShow(
        text: String,
        anchorScreenRect: @escaping @MainActor () -> NSRect,
        preferredArrowPointsDown: Bool? = nil
    ) {
        cancelPendingShow()
        guard !text.isEmpty else { return }

        anchorView = nil

        let work = DispatchWorkItem {
            let rect = anchorScreenRect()
            guard rect.width > 1, rect.height > 1 else { return }
            show(text: text, anchorScreenRect: rect, preferredArrowPointsDown: preferredArrowPointsDown)
        }
        showWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: work)
    }

    static func cancel(for anchor: NSView? = nil) {
        if let anchor {
            guard anchorView === anchor else { return }
        }
        cancelPendingShow()
        hide()
    }

    private static func cancelPendingShow() {
        showWorkItem?.cancel()
        showWorkItem = nil
    }

    private static func show(
        text: String,
        anchorScreenRect: NSRect,
        preferredArrowPointsDown: Bool?
    ) {
        let placement = placement(
            anchor: anchorScreenRect,
            preferredArrowPointsDown: preferredArrowPointsDown
        )

        let bubble = MacHelpTagBubble(text: text, arrowPointsDown: placement.arrowPointsDown)
        let hosting: NSHostingView<MacHelpTagBubble>
        if let existing = hostingView {
            existing.rootView = bubble
            hosting = existing
        } else {
            hosting = NSHostingView(rootView: bubble)
            hostingView = hosting
        }

        let panel = ensurePanel()
        panel.contentView = hosting

        let size = measuredSize(for: hosting, text: text)
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.setContentSize(size)

        let origin = clampedOrigin(
            proposed: placement.origin(tagSize: size, anchor: anchorScreenRect),
            tagSize: size
        )
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
    }

    private static func hide() {
        cancelPendingShow()
        anchorView = nil
        panel?.orderOut(nil)
    }

    private static func measuredSize(for hosting: NSHostingView<MacHelpTagBubble>, text: String) -> NSSize {
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 1 || size.height < 1 {
            size = NSString(string: text).size(withAttributes: MacHelpTagMetrics.textAttributes)
            size.width += 24 + 4
            size.height += 12 + MacHelpTagMetrics.arrowHeight + 4
        }
        return NSSize(
            width: ceil(size.width),
            height: ceil(size.height)
        )
    }

    private static func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        self.panel = panel
        return panel
    }

    private struct Placement {
        let arrowPointsDown: Bool

        func origin(tagSize: NSSize, anchor: NSRect) -> NSPoint {
            let x = anchor.midX - tagSize.width / 2
            if arrowPointsDown {
                return NSPoint(x: x, y: anchor.maxY + MacHelpTagPresenter.gap)
            }
            return NSPoint(x: x, y: anchor.minY - MacHelpTagPresenter.gap - tagSize.height)
        }
    }

    private static func placement(
        anchor: NSRect,
        preferredArrowPointsDown: Bool?
    ) -> Placement {
        if let preferredArrowPointsDown {
            return Placement(arrowPointsDown: preferredArrowPointsDown)
        }

        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let spaceAbove = anchor.maxY - visible.minY
        let spaceBelow = visible.maxY - anchor.minY
        let estimatedHeight: CGFloat = 32

        if spaceAbove >= estimatedHeight + gap {
            return Placement(arrowPointsDown: true)
        }
        if spaceBelow >= estimatedHeight + gap {
            return Placement(arrowPointsDown: false)
        }
        return spaceAbove >= spaceBelow
            ? Placement(arrowPointsDown: true)
            : Placement(arrowPointsDown: false)
    }

    private static func clampedOrigin(proposed: NSPoint, tagSize: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first {
            $0.frame.contains(NSPoint(x: proposed.x + tagSize.width / 2, y: proposed.y + tagSize.height / 2))
        } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero

        var origin = proposed
        let maxX = visible.maxX - tagSize.width - horizontalMargin
        let minX = visible.minX + horizontalMargin
        origin.x = min(max(origin.x, minX), maxX)

        let maxY = visible.maxY - tagSize.height - horizontalMargin
        let minY = visible.minY + horizontalMargin
        origin.y = min(max(origin.y, minY), maxY)

        return origin
    }
}

// MARK: - Metrics

private enum MacHelpTagMetrics {
    static let arrowWidth: CGFloat = 14
    static let arrowHeight: CGFloat = 7
    static let font = NSFont.systemFont(ofSize: 12, weight: .medium)
    static var textAttributes: [NSAttributedString.Key: Any] { [.font: font] }
}

// MARK: - Bubble

private struct MacHelpTagBubble: View {
    let text: String
    let arrowPointsDown: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !arrowPointsDown {
                MacHelpTagArrow(pointingDown: false)
                    .frame(width: MacHelpTagMetrics.arrowWidth, height: MacHelpTagMetrics.arrowHeight)
            }

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MacHelpTagColors.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    Capsule(style: .continuous)
                        .fill(MacHelpTagColors.fill)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(MacHelpTagColors.border, lineWidth: 0.5)
                }

            if arrowPointsDown {
                MacHelpTagArrow(pointingDown: true)
                    .frame(width: MacHelpTagMetrics.arrowWidth, height: MacHelpTagMetrics.arrowHeight)
            }
        }
        .fixedSize()
        .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
    }
}

private enum MacHelpTagColors {
    static var fill: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.22, alpha: 1)
                : .white
        }))
    }

    static var border: Color {
        Color(nsColor: .separatorColor).opacity(0.55)
    }

    static var text: Color {
        Color(nsColor: .labelColor)
    }
}

private struct MacHelpTagArrow: View {
    let pointingDown: Bool

    var body: some View {
        MacHelpTagArrowShape(pointingDown: pointingDown)
            .fill(MacHelpTagColors.fill)
            .overlay {
                MacHelpTagArrowShape(pointingDown: pointingDown)
                    .stroke(MacHelpTagColors.border, lineWidth: 0.5)
            }
    }
}

private struct MacHelpTagArrowShape: Shape {
    let pointingDown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointingDown {
            path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.midX - rect.width / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + rect.width / 2, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Toolbar button

final class MacHelpTagButton: NSButton {
    var helpTagText: String = "" {
        didSet {
            toolTip = nil
            setAccessibilityLabel(helpTagText)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        guard !helpTagText.isEmpty else { return }
        MacHelpTagPresenter.scheduleShow(text: helpTagText, anchor: self)
    }

    override func mouseExited(with event: NSEvent) {
        MacHelpTagPresenter.cancel(for: self)
    }
}
