import AppKit
import SwiftUI

extension View {
    /// Native macOS help tag (reliable placement vs. custom overlay).
    func macTooltip(_ text: String, arrowPointsDown: Bool? = nil) -> some View {
        help(text)
    }
}

// MARK: - Native icon button (toolbar)

struct MacNativeIconButton: NSViewRepresentable {
    let systemImage: String
    let tooltip: String
    let iconPointSize: CGFloat
    var diameter: CGFloat = 28
    var weight: AppTypography.Weight = .medium
    var symbolColor: NSColor?
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> MacHelpTagButton {
        let button = MacHelpTagButton(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        button.controlDiameter = diameter
        configure(button, context: context)
        return button
    }

    func updateNSView(_ button: MacHelpTagButton, context: Context) {
        button.controlDiameter = diameter
        configure(button, context: context)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: MacHelpTagButton, context: Context) -> CGSize? {
        CGSize(width: diameter, height: diameter)
    }

    private func configure(_ button: MacHelpTagButton, context: Context) {
        button.image = Self.symbolImage(
            systemImage: systemImage,
            pointSize: iconPointSize,
            weight: weight,
            accessibilityDescription: tooltip
        )
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.isBordered = false
        button.bezelStyle = .inline
        button.setButtonType(.momentaryChange)
        button.focusRingType = .none
        button.helpTagText = tooltip
        button.contentTintColor = symbolColor
        button.target = context.coordinator
        button.action = #selector(Coordinator.pressed)
    }

    static func symbolImage(
        systemImage: String,
        pointSize: CGFloat,
        weight: AppTypography.Weight,
        accessibilityDescription: String
    ) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight.nsSymbolWeight)
        return NSImage(systemSymbolName: systemImage, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(config)
    }

    final class Coordinator: NSObject {
        let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func pressed() {
            action()
        }
    }
}

private extension AppTypography.Weight {
    var nsSymbolWeight: NSFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}
