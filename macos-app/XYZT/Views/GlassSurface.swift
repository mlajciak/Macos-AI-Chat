import AppKit
import SwiftUI

/// Frosted-glass panel for floating controls (uses in-window vibrancy).
struct GlassSurface: View {
    var material: NSVisualEffectView.Material = .popover
    var cornerRadius: CGFloat = 14
    var topHighlightOpacity: CGFloat = 0.14
    var bottomHighlightOpacity: CGFloat = 0.04
    var borderTopOpacity: CGFloat = 0.35
    var borderBottomOpacity: CGFloat = 0.08
    var shadowOpacity: Double = 0.2
    var emphasized: Bool = true

    @Environment(\.appThemeColors) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            VisualEffectBackground(material: material, blendingMode: .withinWindow, emphasized: emphasized)
            shape.fill(
                LinearGradient(
                    colors: [
                        theme.chromeHighlightHover.opacity(topHighlightOpacity / 0.14),
                        theme.chromeHighlight.opacity(bottomHighlightOpacity / 0.04),
                        Color.clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blendMode(.plusLighter)

        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        theme.chromeHighlightHover.opacity(borderTopOpacity / 0.35),
                        theme.chromeHighlight.opacity(borderBottomOpacity / 0.08),
                        theme.fieldStroke,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .shadow(color: .black.opacity(shadowOpacity), radius: 18, y: 8)
        .shadow(color: .black.opacity(shadowOpacity * 0.4), radius: 4, y: 2)
    }
}

enum GlassChromeShape {
    case circle
    case capsule
}

/// Frosted glass chip for header controls (resting glass; brighter on hover).
struct GlassChromeBackground: View {
    var material: NSVisualEffectView.Material = .hudWindow
    var shape: GlassChromeShape = .circle
    var isHovered: Bool = false

    @Environment(\.appThemeColors) private var theme

    private var topHighlight: CGFloat { isHovered ? 0.2 : 0.14 }
    private var bottomHighlight: CGFloat { isHovered ? 0.06 : 0.03 }
    private var borderTop: CGFloat { isHovered ? 0.42 : 0.32 }
    private var borderBottom: CGFloat { isHovered ? 0.14 : 0.08 }

    var body: some View {
        let fillGradient = LinearGradient(
            colors: [
                theme.chromeHighlightHover.opacity(isHovered ? 1 : 0.85),
                theme.chromeHighlight.opacity(isHovered ? 0.5 : 0.35),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        let borderGradient = LinearGradient(
            colors: [
                theme.chromeHighlightHover.opacity(borderTop),
                theme.fieldStroke,
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        Group {
            switch shape {
            case .circle:
                glassLayer(
                    fillGradient: fillGradient,
                    borderGradient: borderGradient,
                    clip: Circle(),
                    stroke: Circle()
                )
            case .capsule:
                glassLayer(
                    fillGradient: fillGradient,
                    borderGradient: borderGradient,
                    clip: Capsule(style: .continuous),
                    stroke: Capsule(style: .continuous)
                )
            }
        }
    }

    private func glassLayer<S: InsettableShape>(
        fillGradient: LinearGradient,
        borderGradient: LinearGradient,
        clip: S,
        stroke: S
    ) -> some View {
        ZStack {
            VisualEffectBackground(material: material, blendingMode: .withinWindow, emphasized: isHovered)
            clip.fill(fillGradient).blendMode(.plusLighter)
        }
        .clipShape(clip)
        .overlay {
            stroke.strokeBorder(borderGradient, lineWidth: 0.5)
        }
    }
}

/// Back-compat alias for toolbar chips.
typealias GlassIconHoverBackground = GlassChromeBackground

extension GlassSurface {
    static func input(material: NSVisualEffectView.Material) -> GlassSurface {
        GlassSurface(material: material, cornerRadius: 14)
    }

    static func sessionMenu(material: NSVisualEffectView.Material) -> GlassSurface {
        GlassSurface(
            material: material,
            cornerRadius: 14,
            topHighlightOpacity: 0.07,
            bottomHighlightOpacity: 0.02,
            borderTopOpacity: 0.22,
            borderBottomOpacity: 0.06,
            shadowOpacity: 0.12,
            emphasized: false
        )
    }
}
