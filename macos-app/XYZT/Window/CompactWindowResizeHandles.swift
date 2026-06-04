import AppKit
import SwiftUI

struct CompactWindowResizeOverlay: NSViewRepresentable {
    let minSize: NSSize
    let maxSize: NSSize
    var onResizeStarted: (() -> Void)?
    var onResizeEnded: (() -> Void)?

    func makeNSView(context: Context) -> CompactResizeTrackingView {
        let view = CompactResizeTrackingView()
        view.minSize = minSize
        view.maxSize = maxSize
        view.onResizeStarted = onResizeStarted
        view.onResizeEnded = onResizeEnded
        return view
    }

    func updateNSView(_ nsView: CompactResizeTrackingView, context: Context) {
        nsView.minSize = minSize
        nsView.maxSize = maxSize
        nsView.onResizeStarted = onResizeStarted
        nsView.onResizeEnded = onResizeEnded
    }
}

final class CompactResizeTrackingView: NSView {
    var minSize = NSSize(width: 300, height: 380)
    var maxSize = NSSize(width: 560, height: 820)
    var onResizeStarted: (() -> Void)?
    var onResizeEnded: (() -> Void)?

    /// Generous strips so resize wins over the floating header and message list.
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

        let corner = NSRect(x: 0, y: 0, width: cornerLength, height: cornerLength)
        addCursorRect(corner, cursor: Self.topLeadingResizeCursor)

        let top = NSRect(x: cornerLength, y: 0, width: max(0, bounds.width - cornerLength), height: edgeThickness)
        if top.width > 0 { addCursorRect(top, cursor: .resizeUp) }

        let left = NSRect(x: 0, y: cornerLength, width: edgeThickness, height: max(0, bounds.height - cornerLength))
        if left.height > 0 { addCursorRect(left, cursor: .resizeLeft) }
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

        let anchorRight = resizeStartFrame.maxX
        let anchorBottom = resizeStartFrame.minY

        var width = resizeStartFrame.width - dx
        var height = resizeStartFrame.height + dy
        width = min(max(width, minSize.width), maxSize.width)
        height = min(max(height, minSize.height), maxSize.height)

        let origin = NSPoint(x: anchorRight - width, y: anchorBottom)
        window.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard isResizing else { return }
        isResizing = false
        onResizeEnded?()
    }

    private func isResizePoint(_ point: NSPoint) -> Bool {
        let onTop = point.y < edgeThickness
        let onLeft = point.x < edgeThickness
        return onTop || onLeft
    }

    private static var topLeadingResizeCursor: NSCursor {
        if #available(macOS 15.0, *) {
            return NSCursor.frameResize(position: .topLeft, directions: [.inward, .outward])
        }
        return .resizeLeft
    }
}
