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

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            VisualEffectBackground(material: material, blendingMode: .withinWindow, emphasized: emphasized)
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(topHighlightOpacity),
                        Color.white.opacity(bottomHighlightOpacity),
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
                        Color.white.opacity(borderTopOpacity),
                        Color.white.opacity(borderBottomOpacity),
                        Color.primary.opacity(0.1),
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
