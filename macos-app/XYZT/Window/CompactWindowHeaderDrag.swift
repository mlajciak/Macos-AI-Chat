import AppKit
import SwiftUI

/// Fills the flexible header band so the compact window can be dragged via `performDrag`.
struct CompactWindowHeaderDragRegion: NSViewRepresentable {
    var isEnabled: Bool

    func makeNSView(context: Context) -> CompactWindowHeaderDragView {
        let view = CompactWindowHeaderDragView()
        view.isEnabled = isEnabled
        return view
    }

    func updateNSView(_ nsView: CompactWindowHeaderDragView, context: Context) {
        nsView.isEnabled = isEnabled
    }
}

final class CompactWindowHeaderDragView: NSView {
    var isEnabled = false

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, bounds.contains(point) else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let window else { return }
        window.performDrag(with: event)
    }
}

extension View {
    /// Draggable header spacer (floating compact position only); keeps toolbar buttons clickable.
    func compactHeaderDragRegion(isEnabled: Bool) -> some View {
        background {
            CompactWindowHeaderDragRegion(isEnabled: isEnabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
