import AppKit
import SwiftUI

struct ChromeEdgeBlur: View {
    enum Edge {
        case top
        case bottom
    }

    let edge: Edge
    let height: CGFloat
    let material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    var body: some View {
        VisualEffectBackground(
            material: material,
            blendingMode: blendingMode,
            emphasized: false
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .mask { blurMask }
        .allowsHitTesting(false)
    }

    private var blurMask: LinearGradient {
        switch edge {
        case .top:
            return LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.85), location: 0.25),
                    .init(color: .black.opacity(0.55), location: 0.5),
                    .init(color: .black.opacity(0.25), location: 0.75),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .bottom:
            return LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
