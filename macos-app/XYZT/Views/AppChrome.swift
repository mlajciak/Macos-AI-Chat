import SwiftUI

/// Shared pill-shaped controls and scroll behavior.
enum AppChrome {
    static let rowHeight: CGFloat = 32
    static let compactControlHeight: CGFloat = 28

    static var rowRadius: CGFloat { rowHeight / 2 }

    static var compactRadius: CGFloat { compactControlHeight / 2 }
}

extension View {
    func pillRow(height: CGFloat = AppChrome.rowHeight) -> some View {
        frame(height: height)
    }

    @ViewBuilder
    func pillBackground(
        height: CGFloat = AppChrome.rowHeight,
        fill: Color,
        stroke: Color? = nil,
        lineWidth: CGFloat = 0.5
    ) -> some View {
        background {
            Capsule(style: .continuous)
                .fill(fill)
        }
        .overlay {
            if let stroke {
                Capsule(style: .continuous)
                    .strokeBorder(stroke, lineWidth: lineWidth)
            }
        }
        .contentShape(Capsule(style: .continuous))
    }

    /// Visible vertical scroll indicators (macOS).
    func scrollbarsWhenNeeded() -> some View {
        appVerticalScrollIndicators()
    }
}
