import AppKit
import Foundation

/// Screen corner for the compact panel, or free-floating placement (draggable header).
enum CompactWindowAnchor: String, CaseIterable, Identifiable, Codable {
    case bottomRight
    case bottomLeft
    case topLeft
    case topRight
    case floating

    var id: String { rawValue }

    static let `default`: CompactWindowAnchor = .bottomRight

    var usesCornerSnap: Bool {
        self != .floating
    }

    var label: String {
        switch self {
        case .bottomRight: "Bottom right"
        case .bottomLeft: "Bottom left"
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .floating: "Floating"
        }
    }

    var systemImage: String {
        switch self {
        case .bottomRight: "arrow.down.right"
        case .bottomLeft: "arrow.down.left"
        case .topLeft: "arrow.up.left"
        case .topRight: "arrow.up.right"
        case .floating: "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    /// Resize behavior for the compact overlay (floating uses bottom-right pinning).
    var resizeAnchor: CompactWindowAnchor {
        switch self {
        case .floating: .bottomRight
        default: self
        }
    }

    /// Fixed window corner that stays on screen when snapping or resizing.
    func pinnedCorner(in frame: NSRect) -> NSPoint {
        switch resizeAnchor {
        case .bottomRight:
            NSPoint(x: frame.maxX, y: frame.minY)
        case .bottomLeft:
            NSPoint(x: frame.minX, y: frame.minY)
        case .topLeft:
            NSPoint(x: frame.minX, y: frame.maxY)
        case .topRight:
            NSPoint(x: frame.maxX, y: frame.maxY)
        case .floating:
            NSPoint(x: frame.maxX, y: frame.minY)
        }
    }

    func frame(pinnedTo corner: NSPoint, size: NSSize) -> NSRect {
        switch resizeAnchor {
        case .bottomRight:
            NSRect(
                x: corner.x - size.width,
                y: corner.y,
                width: size.width,
                height: size.height
            )
        case .bottomLeft:
            NSRect(x: corner.x, y: corner.y, width: size.width, height: size.height)
        case .topLeft:
            NSRect(
                x: corner.x,
                y: corner.y - size.height,
                width: size.width,
                height: size.height
            )
        case .topRight:
            NSRect(
                x: corner.x - size.width,
                y: corner.y - size.height,
                width: size.width,
                height: size.height
            )
        case .floating:
            NSRect(
                x: corner.x - size.width,
                y: corner.y,
                width: size.width,
                height: size.height
            )
        }
    }

    func snappedFrame(size: NSSize, in visible: NSRect, inset: CGFloat) -> NSRect {
        let corner: NSPoint = switch self {
        case .bottomRight:
            NSPoint(x: visible.maxX - inset, y: visible.minY + inset)
        case .bottomLeft:
            NSPoint(x: visible.minX + inset, y: visible.minY + inset)
        case .topLeft:
            NSPoint(x: visible.minX + inset, y: visible.maxY - inset)
        case .topRight:
            NSPoint(x: visible.maxX - inset, y: visible.maxY - inset)
        case .floating:
            NSPoint(x: visible.maxX - inset, y: visible.minY + inset)
        }
        return frame(pinnedTo: corner, size: size)
    }

    func clampedFrame(_ frame: NSRect, in visible: NSRect, inset: CGFloat) -> NSRect {
        var result = frame
        let minX = visible.minX + inset
        let maxX = visible.maxX - inset - frame.width
        let minY = visible.minY + inset
        let maxY = visible.maxY - inset - frame.height

        if maxX >= minX {
            result.origin.x = min(max(frame.origin.x, minX), maxX)
        } else {
            result.origin.x = minX
        }

        if maxY >= minY {
            result.origin.y = min(max(frame.origin.y, minY), maxY)
        } else {
            result.origin.y = minY
        }

        return result
    }
}
