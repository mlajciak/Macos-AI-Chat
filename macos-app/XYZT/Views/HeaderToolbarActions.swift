import SwiftUI

struct HeaderToolbarActions: View {
    @Bindable var viewModel: ChatViewModel
    let windowAction: WindowAction
    var onClose: (() -> Void)?

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
                tooltip: "New chat session"
            ) {
                viewModel.createNewChat()
            }

            HeaderToolbarIconButton(
                systemImage: "gearshape",
                tooltip: "Settings"
            ) {
                viewModel.toggleSettings()
            }

            HeaderToolbarIconButton(
                systemImage: windowAction.systemImage,
                tooltip: windowAction.tooltip
            ) {
                windowAction.perform()
            }

            if let onClose {
                HeaderToolbarIconButton(
                    systemImage: "xmark",
                    tooltip: "Hide \(AppBranding.name)",
                    iconSize: 11,
                    iconWeight: .semibold
                ) {
                    onClose()
                }
            }
        }
    }
}

private struct HeaderToolbarIconButton: View {
    let systemImage: String
    let tooltip: String
    var iconSize: CGFloat = 12
    var iconWeight: Font.Weight = .medium
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: iconWeight))
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .padding(4)
        .contentShape(Rectangle())
        .macTooltip(tooltip)
        .accessibilityLabel(tooltip)
    }
}
