import AppKit
import SwiftUI

extension View {
    /// Dock-style help tag anchored to this view's bounds.
    func macTooltip(_ text: String, arrowPointsDown: Bool? = nil) -> some View {
        modifier(MacHelpTagHoverModifier(text: text, arrowPointsDown: arrowPointsDown))
    }
}

// MARK: - SwiftUI hover

private struct MacHelpTagHoverModifier: ViewModifier {
    let text: String
    let arrowPointsDown: Bool?

    @State private var globalFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geo in
                    Color.clear
                        .allowsHitTesting(false)
                        .onAppear {
                            globalFrame = geo.frame(in: .global)
                        }
                        .onChange(of: geo.frame(in: .global)) { _, frame in
                            globalFrame = frame
                        }
                }
            }
            .onHover { hovering in
                guard !text.isEmpty else { return }
                guard globalFrame.width > 1, globalFrame.height > 1 else { return }

                if hovering {
                    MacHelpTagPresenter.scheduleShow(
                        text: text,
                        anchorScreenRect: {
                            MacHelpTagCoordinates.screenRect(globalFrame: globalFrame)
                        },
                        preferredArrowPointsDown: arrowPointsDown
                    )
                } else {
                    MacHelpTagPresenter.cancel()
                }
            }
    }
}

// MARK: - Native icon button (toolbar)

struct MacNativeIconButton: NSViewRepresentable {
    let systemImage: String
    let tooltip: String
    let iconPointSize: CGFloat
    var weight: AppTypography.Weight = .medium
    var symbolColor: NSColor?
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> MacHelpTagButton {
        let button = MacHelpTagButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        configure(button, context: context)
        return button
    }

    func updateNSView(_ button: MacHelpTagButton, context: Context) {
        configure(button, context: context)
    }

    private func configure(_ button: MacHelpTagButton, context: Context) {
        button.image = Self.symbolImage(
            systemImage: systemImage,
            pointSize: iconPointSize,
            weight: weight,
            accessibilityDescription: tooltip
        )
        button.imagePosition = .imageOnly
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
