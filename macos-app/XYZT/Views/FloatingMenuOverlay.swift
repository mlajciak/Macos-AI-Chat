import AppKit
import SwiftUI

/// Full-window frosted overlay (session browser, settings, …).
struct FloatingMenuOverlay<Content: View>: View {
    let title: String
    let closeHelp: String
    let usesHudMaterial: Bool
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
    }

    private var headerTopPadding: CGFloat {
        usesHudMaterial
            ? FloatingChromeMetrics.headerTopPadding
            : FloatingChromeMetrics.expandedTrafficLightInset
    }

    private var cornerRadius: CGFloat {
        FloatingChromeMetrics.menuOverlayCornerRadius
    }

    var body: some View {
        ZStack(alignment: .top) {
            SessionMenuBackdrop(material: glassMaterial)

            VStack(alignment: .leading, spacing: 0) {
                menuHeader
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(usesHudMaterial ? 0.12 : 0.1), lineWidth: 1)
        }
        .transition(.opacity)
        .zIndex(100)
    }

    private var menuHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(closeHelp)
            .accessibilityLabel(closeHelp)
        }
        .frame(height: FloatingChromeMetrics.headerBarHeight)
        .padding(.horizontal, 12)
        .padding(.top, headerTopPadding)
        .padding(.bottom, 4)
    }
}

/// Light frosted fill — blur only, minimal tint.
struct SessionMenuBackdrop: View {
    let material: NSVisualEffectView.Material

    var body: some View {
        ZStack {
            VisualEffectBackground(
                material: material,
                blendingMode: .withinWindow,
                emphasized: false
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
        }
    }
}
