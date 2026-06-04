import SwiftUI

struct CompactHeaderToolbar: View {
    @Bindable var viewModel: ChatViewModel
    let windowAction: HeaderToolbarActions.WindowAction
    var onClose: (() -> Void)?

    private var fontSettings: AppFontSettings { viewModel.preferences.fontSettings }

    var body: some View {
        HeaderToolbarActions(
            viewModel: viewModel,
            windowAction: windowAction,
            onClose: onClose
        )
    }
}

struct HeaderToolbarActions: View {
    @Bindable var viewModel: ChatViewModel
    let windowAction: WindowAction
    var onClose: (() -> Void)?
    var glassMaterial: NSVisualEffectView.Material = .hudWindow

    private var fontSettings: AppFontSettings { viewModel.preferences.fontSettings }

    enum WindowAction {
        case expand(action: () -> Void)
        case compact(action: () -> Void)

        var systemImage: String {
            switch self {
            case .expand: "arrow.up.left.and.arrow.down.right"
            case .compact: "arrow.down.right.and.arrow.up.left"
            }
        }

        var tooltip: String {
            switch self {
            case .expand: "Expand window"
            case .compact: "Compact window"
            }
        }

        func perform() {
            switch self {
            case let .expand(action), let .compact(action):
                action()
            }
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            HeaderToolbarIconButton(
                systemImage: "square.and.pencil",
                tooltip: "New chat session",
                fontSettings: fontSettings,
                glassMaterial: glassMaterial
            ) {
                viewModel.createNewChat()
            }

            HeaderToolbarIconButton(
                systemImage: "gearshape",
                tooltip: "Settings",
                fontSettings: fontSettings,
                glassMaterial: glassMaterial
            ) {
                viewModel.toggleSettings()
            }

            HeaderToolbarIconButton(
                systemImage: windowAction.systemImage,
                tooltip: windowAction.tooltip,
                fontSettings: fontSettings,
                glassMaterial: glassMaterial
            ) {
                windowAction.perform()
            }

            if let onClose {
                HeaderToolbarIconButton(
                    systemImage: "xmark",
                    tooltip: "Hide window (⌘Q to quit)",
                    fontSettings: fontSettings,
                    weight: .semibold,
                    glassMaterial: glassMaterial
                ) {
                    onClose()
                }
            }
        }
    }
}

struct HeaderToolbarIconButton: View {
    let systemImage: String
    let tooltip: String
    let fontSettings: AppFontSettings
    var weight: AppTypography.Weight = .medium
    var glassMaterial: NSVisualEffectView.Material = .hudWindow
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(fontSettings.font(size: fontSettings.iconPointSize, weight: weight))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background {
                    GlassChromeBackground(
                        material: glassMaterial,
                        shape: .circle,
                        isHovered: isHovered
                    )
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}
