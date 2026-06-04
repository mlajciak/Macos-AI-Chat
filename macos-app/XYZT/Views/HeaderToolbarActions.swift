import SwiftUI

struct HeaderToolbarActions: View {
    @Bindable var viewModel: ChatViewModel
    let windowAction: WindowAction
    var onClose: (() -> Void)?

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
        HStack(spacing: 0) {
            HeaderToolbarIconButton(
                systemImage: "square.and.pencil",
                tooltip: "New chat session",
                fontSettings: fontSettings
            ) {
                viewModel.createNewChat()
            }

            HeaderToolbarIconButton(
                systemImage: "gearshape",
                tooltip: "Settings",
                fontSettings: fontSettings
            ) {
                viewModel.toggleSettings()
            }

            HeaderToolbarIconButton(
                systemImage: windowAction.systemImage,
                tooltip: windowAction.tooltip,
                fontSettings: fontSettings
            ) {
                windowAction.perform()
            }

            if let onClose {
                HeaderToolbarIconButton(
                    systemImage: "xmark",
                    tooltip: "Hide \(AppBranding.name)",
                    fontSettings: fontSettings,
                    weight: .semibold
                ) {
                    onClose()
                }
            }
        }
    }
}

/// Expand-to-full-window and hide — used on the collapsed compact strip.
struct CompactWindowToolbar: View {
    let fontSettings: AppFontSettings
    let onExpandWindow: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HeaderToolbarIconButton(
                systemImage: "arrow.up.left.and.arrow.down.right",
                tooltip: "Expand window",
                fontSettings: fontSettings
            ) {
                onExpandWindow()
            }

            HeaderToolbarIconButton(
                systemImage: "xmark",
                tooltip: "Hide \(AppBranding.name)",
                fontSettings: fontSettings,
                weight: .semibold
            ) {
                onClose()
            }
        }
    }
}

struct HeaderToolbarIconButton: View {
    let systemImage: String
    let tooltip: String
    let fontSettings: AppFontSettings
    var weight: AppTypography.Weight = .medium
    let action: () -> Void

    var body: some View {
        MacNativeIconButton(
            systemImage: systemImage,
            tooltip: tooltip,
            iconPointSize: fontSettings.iconPointSize,
            weight: weight,
            action: action
        )
        .frame(width: 24, height: 24)
        .accessibilityLabel(tooltip)
    }
}
