import AppKit
import SwiftUI

/// Drag handle for free-floating compact window placement (manual frame updates).
struct CompactWindowHeaderDragRegion: NSViewRepresentable {
    var isEnabled: Bool
    var onDragEnded: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onDragEnded: onDragEnded)
    }

    func makeNSView(context: Context) -> CompactWindowHeaderDragView {
        let view = CompactWindowHeaderDragView()
        view.isEnabled = isEnabled
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: CompactWindowHeaderDragView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.coordinator = context.coordinator
        context.coordinator.onDragEnded = onDragEnded
    }

    final class Coordinator {
        var onDragEnded: (() -> Void)?
        var dragStartFrame: NSRect = .zero
        var dragStartMouse: NSPoint = .zero

        init(onDragEnded: (() -> Void)?) {
            self.onDragEnded = onDragEnded
        }
    }
}

final class CompactWindowHeaderDragView: NSView {
    weak var coordinator: CompactWindowHeaderDragRegion.Coordinator?
    var isEnabled = false

    private var isDragging = false

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, bounds.contains(point) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let window, let coordinator else { return }
        isDragging = true
        coordinator.dragStartFrame = window.frame
        coordinator.dragStartMouse = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let window, let coordinator else { return }

        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - coordinator.dragStartMouse.x
        let dy = mouse.y - coordinator.dragStartMouse.y

        var frame = coordinator.dragStartFrame
        frame.origin.x += dx
        frame.origin.y += dy

        if let screen = window.screen ?? NSScreen.main {
            frame = CompactWindowAnchor.floating.clampedFrame(
                frame,
                in: screen.visibleFrame,
                inset: ChatWindowController.screenInset
            )
        }

        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        coordinator?.onDragEnded?()
    }
}

extension View {
    /// Full-header drag layer for floating compact mode; controls stay clickable above.
    @ViewBuilder
    func compactFloatingHeaderDrag(
        isEnabled: Bool,
        onDragEnded: (() -> Void)? = nil
    ) -> some View {
        if isEnabled {
            overlay {
                CompactWindowHeaderDragRegion(
                    isEnabled: true,
                    onDragEnded: onDragEnded
                )
            }
        } else {
            self
        }
    }
}
