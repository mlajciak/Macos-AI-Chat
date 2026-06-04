import AppKit
import SwiftUI

struct CompactWindowResizeOverlay: NSViewRepresentable {
    let anchor: CompactWindowAnchor
    let minSize: NSSize
    let maxSize: NSSize
    var headerExclusionHeight: CGFloat = 0
    var isStripMode: Bool = false
    var onResizeStarted: (() -> Void)?
    var onResizeEnded: (() -> Void)?
    var onCollapseToStrip: (() -> Void)?

    func makeNSView(context: Context) -> CompactResizeTrackingView {
        let view = CompactResizeTrackingView()
        view.anchor = anchor.resizeAnchor
        view.minSize = minSize
        view.maxSize = maxSize
        view.headerExclusionHeight = headerExclusionHeight
        view.isStripMode = isStripMode
        view.onResizeStarted = onResizeStarted
        view.onResizeEnded = onResizeEnded
        view.onCollapseToStrip = onCollapseToStrip
        return view
    }

    func updateNSView(_ nsView: CompactResizeTrackingView, context: Context) {
        nsView.anchor = anchor.resizeAnchor
        nsView.minSize = minSize
        nsView.maxSize = maxSize
        nsView.headerExclusionHeight = headerExclusionHeight
        nsView.isStripMode = isStripMode
        nsView.onResizeStarted = onResizeStarted
        nsView.onResizeEnded = onResizeEnded
        nsView.onCollapseToStrip = onCollapseToStrip
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

final class CompactResizeTrackingView: NSView {
    var anchor: CompactWindowAnchor = .bottomRight
    var minSize = NSSize(width: 300, height: 380)
    var maxSize = NSSize(width: 560, height: 820)
    var headerExclusionHeight: CGFloat = 0
    var isStripMode = false
    var onResizeStarted: (() -> Void)?
    var onResizeEnded: (() -> Void)?
    var onCollapseToStrip: (() -> Void)?

    private let edgeThickness: CGFloat = 28
    private let cornerLength: CGFloat = 40

    private var resizeStartFrame: NSRect = .zero
    private var resizeStartMouse: NSPoint = .zero
    private var isResizing = false

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isResizePoint(point) ? self : nil
    }

    override func resetCursorRects() {
        discardCursorRects()
        guard bounds.width > 0, bounds.height > 0 else { return }

        if isStripMode {
            addStripResizeRects()
            return
        }

        addPanelResizeRects()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let window, isResizePoint(point) else { return }
        isResizing = true
        onResizeStarted?()
        resizeStartFrame = window.frame
        resizeStartMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard isResizing, let window else { return }

        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - resizeStartMouse.x
        let dy = mouse.y - resizeStartMouse.y
        let pinned = anchor.pinnedCorner(in: resizeStartFrame)

        if isStripMode {
            let width = clampedWidth(resizeStartFrame.width + horizontalDelta(dx))
            let frame = anchor.frame(pinnedTo: pinned, size: NSSize(width: width, height: resizeStartFrame.height))
            window.setFrame(frame, display: true)
            return
        }

        let rawHeight = resizeStartFrame.height + verticalDelta(dy)
        if rawHeight < minSize.height {
            isResizing = false
            onCollapseToStrip?()
            return
        }

        let width = clampedWidth(resizeStartFrame.width + horizontalDelta(dx))
        let height = min(max(rawHeight, minSize.height), maxSize.height)
        let frame = anchor.frame(
            pinnedTo: pinned,
            size: NSSize(width: width, height: height)
        )
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard isResizing else { return }
        isResizing = false
        onResizeEnded?()
    }

    // MARK: - Hit regions (opposite corner/edges from screen anchor)

    private func isResizePoint(_ point: NSPoint) -> Bool {
        if isStripMode {
            return isStripResizePoint(point)
        }
        return isPanelResizePoint(point)
    }

    private func isInHeaderBand(_ point: NSPoint) -> Bool {
        headerExclusionHeight > 0 && point.y < headerExclusionHeight
    }

    private func isPanelResizePoint(_ point: NSPoint) -> Bool {
        if isInHeaderBand(point) { return false }

        switch anchor {
        case .bottomRight, .floating:
            return point.x < edgeThickness
                || point.y < edgeThickness
        case .bottomLeft:
            return point.x > bounds.width - edgeThickness
                || point.y < edgeThickness
        case .topLeft:
            return point.y > bounds.height - edgeThickness
                || point.x > bounds.width - edgeThickness
        case .topRight:
            return point.y > bounds.height - edgeThickness
                || point.x < edgeThickness
        }
    }

    private func isStripResizePoint(_ point: NSPoint) -> Bool {
        if isInHeaderBand(point) { return false }

        switch anchor {
        case .bottomRight, .topRight, .floating:
            return point.x < edgeThickness
        case .bottomLeft, .topLeft:
            return point.x > bounds.width - edgeThickness
        }
    }

    private func addPanelResizeRects() {
        switch anchor {
        case .bottomRight, .floating:
            addCornerRect(at: .topLeft)
            addEdgeRect(.left)
            addEdgeRect(.top)
        case .bottomLeft:
            addCornerRect(at: .topRight)
            addEdgeRect(.right)
            addEdgeRect(.top)
        case .topLeft:
            addCornerRect(at: .bottomRight)
            addEdgeRect(.bottom)
            addEdgeRect(.right)
        case .topRight:
            addCornerRect(at: .bottomLeft)
            addEdgeRect(.bottom)
            addEdgeRect(.left)
        }
    }

    private func addStripResizeRects() {
        switch anchor {
        case .bottomRight, .topRight, .floating:
            addEdgeRect(.left)
        case .bottomLeft, .topLeft:
            addEdgeRect(.right)
        }
    }

    private enum ViewCorner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private enum ViewEdge {
        case top, left, right, bottom
    }

    private func addCornerRect(at corner: ViewCorner) {
        var rect: NSRect = switch corner {
        case .topLeft:
            NSRect(x: 0, y: 0, width: cornerLength, height: cornerLength)
        case .topRight:
            NSRect(x: bounds.width - cornerLength, y: 0, width: cornerLength, height: cornerLength)
        case .bottomLeft:
            NSRect(x: 0, y: bounds.height - cornerLength, width: cornerLength, height: cornerLength)
        case .bottomRight:
            NSRect(
                x: bounds.width - cornerLength,
                y: bounds.height - cornerLength,
                width: cornerLength,
                height: cornerLength
            )
        }

        if headerExclusionHeight > 0, corner == .topLeft || corner == .topRight {
            rect.origin.y = headerExclusionHeight
        }

        addCursorRect(rect, cursor: cursor(for: corner))
    }

    private func addEdgeRect(_ edge: ViewEdge) {
        var rect: NSRect = switch edge {
        case .top:
            NSRect(x: cornerLength, y: 0, width: max(0, bounds.width - cornerLength * 2), height: edgeThickness)
        case .bottom:
            NSRect(
                x: cornerLength,
                y: bounds.height - edgeThickness,
                width: max(0, bounds.width - cornerLength * 2),
                height: edgeThickness
            )
        case .left:
            NSRect(x: 0, y: cornerLength, width: edgeThickness, height: max(0, bounds.height - cornerLength * 2))
        case .right:
            NSRect(
                x: bounds.width - edgeThickness,
                y: cornerLength,
                width: edgeThickness,
                height: max(0, bounds.height - cornerLength * 2)
            )
        }

        if headerExclusionHeight > 0 {
            switch edge {
            case .left, .right:
                rect.origin.y = headerExclusionHeight
                rect.size.height = max(0, bounds.height - cornerLength - headerExclusionHeight)
            case .top:
                return
            case .bottom:
                break
            }
        }

        guard rect.width > 0, rect.height > 0 else { return }
        addCursorRect(rect, cursor: cursor(for: edge))
    }

    private func cursor(for corner: ViewCorner) -> NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition = switch corner {
            case .topLeft: .topLeft
            case .topRight: .topRight
            case .bottomLeft: .bottomLeft
            case .bottomRight: .bottomRight
            }
            return NSCursor.frameResize(position: position, directions: [.inward, .outward])
        }
        return .resizeLeft
    }

    private func cursor(for edge: ViewEdge) -> NSCursor {
        switch edge {
        case .top, .bottom: .resizeUp
        case .left, .right: .resizeLeft
        }
    }

    private func horizontalDelta(_ dx: CGFloat) -> CGFloat {
        switch anchor {
        case .bottomRight, .topRight, .floating:
            return -dx
        case .bottomLeft, .topLeft:
            return dx
        }
    }

    private func verticalDelta(_ dy: CGFloat) -> CGFloat {
        switch anchor {
        case .bottomRight, .bottomLeft, .floating:
            return dy
        case .topLeft, .topRight:
            return -dy
        }
    }

    private func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minSize.width), maxSize.width)
    }
}

// MARK: - Environment

struct CompactResizeOverlayConfig {
    let anchor: CompactWindowAnchor
    let minSize: NSSize
    let maxSize: NSSize
    let headerExclusionHeight: CGFloat
    let isStripMode: Bool
    var onResizeStarted: (() -> Void)?
    var onResizeEnded: (() -> Void)?
    var onCollapseToStrip: (() -> Void)?
}

private struct CompactResizeOverlayConfigKey: EnvironmentKey {
    static let defaultValue: CompactResizeOverlayConfig? = nil
}

extension EnvironmentValues {
    var compactResizeOverlayConfig: CompactResizeOverlayConfig? {
        get { self[CompactResizeOverlayConfigKey.self] }
        set { self[CompactResizeOverlayConfigKey.self] = newValue }
    }
}

extension View {
    /// Passes resize config to `ConversationLayout` / compact hosts; overlay stays below header (`zIndex` 1 vs 2).
    func compactResizeOverlay(_ config: CompactResizeOverlayConfig?) -> some View {
        environment(\.compactResizeOverlayConfig, config)
    }
}
