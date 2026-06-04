import AppKit
import Foundation

/// Screen corner where the compact floating panel is anchored.
enum CompactWindowAnchor: String, CaseIterable, Identifiable, Codable {
    case bottomRight
    case bottomLeft
    case topLeft
    case topRight

    var id: String { rawValue }

    static let `default`: CompactWindowAnchor = .bottomRight

    var label: String {
        switch self {
        case .bottomRight: "Bottom right"
        case .bottomLeft: "Bottom left"
        case .topLeft: "Top left"
        case .topRight: "Top right"
        }
    }

    var systemImage: String {
        switch self {
        case .bottomRight: "arrow.down.right"
        case .bottomLeft: "arrow.down.left"
        case .topLeft: "arrow.up.left"
        case .topRight: "arrow.up.right"
        }
    }

    /// Fixed window corner that stays on screen when snapping or resizing.
    func pinnedCorner(in frame: NSRect) -> NSPoint {
        switch self {
        case .bottomRight:
            NSPoint(x: frame.maxX, y: frame.minY)
        case .bottomLeft:
            NSPoint(x: frame.minX, y: frame.minY)
        case .topLeft:
            NSPoint(x: frame.minX, y: frame.maxY)
        case .topRight:
            NSPoint(x: frame.maxX, y: frame.maxY)
        }
    }

    func frame(pinnedTo corner: NSPoint, size: NSSize) -> NSRect {
        switch self {
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
        }
        return frame(pinnedTo: corner, size: size)
    }
}
