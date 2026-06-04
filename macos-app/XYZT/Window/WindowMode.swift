import Foundation

enum WindowMode: String {
    case compact
    case expanded
}

/// Compact floating window can show the full chat panel or a one-line strip.
enum CompactPresentation: String, Equatable {
    case panel
    case strip
}
