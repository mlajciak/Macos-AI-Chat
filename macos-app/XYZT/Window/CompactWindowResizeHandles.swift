import AppKit
import SwiftUI

struct CompactWindowResizeOverlay: NSViewRepresentable {
    let anchor: CompactWindowAnchor
    let minSize: NSSize
    let maxSize: NSSize
    var isStripMode: Bool = false
    var onResizeStarted: (() -> Void)?
    var onResizeEnded: (() -> Void)?
    var onCollapseToStrip: (() -> Void)?

    func makeNSView(context: Context) -> CompactResizeTrackingView {
        let view = CompactResizeTrackingView()
        view.anchor = anchor
        view.minSize = minSize
        view.maxSize = maxSize
        view.isStripMode = isStripMode
        view.onResizeStarted = onResizeStarted
        view.onResizeEnded = onResizeEnded
        view.onCollapseToStrip = onCollapseToStrip
        return view
    }

    func updateNSView(_ nsView: CompactResizeTrackingView, context: Context) {
        nsView.anchor = anchor
        nsView.minSize = minSize
        nsView.maxSize = maxSize
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
            onResizeEnded?()
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

    private func isPanelResizePoint(_ point: NSPoint) -> Bool {
        switch anchor {
        case .bottomRight:
            return point.y < edgeThickness || point.x < edgeThickness
        case .bottomLeft:
            return point.y < edgeThickness || point.x > bounds.width - edgeThickness
        case .topLeft:
            return point.y > bounds.height - edgeThickness || point.x > bounds.width - edgeThickness
        case .topRight:
            return point.y > bounds.height - edgeThickness || point.x < edgeThickness
        }
    }

    private func isStripResizePoint(_ point: NSPoint) -> Bool {
        switch anchor {
        case .bottomRight, .topRight:
            return point.x < edgeThickness
        case .bottomLeft, .topLeft:
            return point.x > bounds.width - edgeThickness
        }
    }

    private func addPanelResizeRects() {
        switch anchor {
        case .bottomRight:
            addCornerRect(at: .topLeft)
            addEdgeRect(.top)
            addEdgeRect(.left)
        case .bottomLeft:
            addCornerRect(at: .topRight)
            addEdgeRect(.top)
            addEdgeRect(.right)
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
        case .bottomRight, .topRight:
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
        let rect: NSRect = switch corner {
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
        addCursorRect(rect, cursor: cursor(for: corner))
    }

    private func addEdgeRect(_ edge: ViewEdge) {
        let rect: NSRect = switch edge {
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
        case .bottomRight, .topRight:
            return -dx
        case .bottomLeft, .topLeft:
            return dx
        }
    }

    private func verticalDelta(_ dy: CGFloat) -> CGFloat {
        switch anchor {
        case .bottomRight, .bottomLeft:
            return dy
        case .topLeft, .topRight:
            return -dy
        }
    }

    private func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minSize.width), maxSize.width)
    }
}
