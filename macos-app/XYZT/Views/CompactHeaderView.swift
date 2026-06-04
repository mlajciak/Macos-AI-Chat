import SwiftUI

/// Shared compact / expanded chat header (path menu + toolbar).
struct ChatPanelHeaderView: View {
    @Bindable var viewModel: ChatViewModel
    let windowAction: HeaderToolbarActions.WindowAction
    var onClose: (() -> Void)?
    var trafficLightsLeadingInset: CGFloat = 0
    var allowsHeaderDrag: Bool = false
    var onFloatingDragEnded: (() -> Void)?

    /// Extra leading on the path chip only (after `headerHorizontalPadding`).
    private var pathExtraLeading: CGFloat {
        guard trafficLightsLeadingInset > 0 else { return 0 }
        return max(0, trafficLightsLeadingInset - FloatingChromeMetrics.headerHorizontalPadding)
    }

    var body: some View {
        ZStack {
            Color.clear
                .compactFloatingHeaderDrag(
                    isEnabled: allowsHeaderDrag,
                    onDragEnded: onFloatingDragEnded
                )

            HStack(alignment: .center, spacing: 8) {
                SessionPathMenu(viewModel: viewModel)
                    .padding(.leading, pathExtraLeading)

                Spacer(minLength: 4)

                CompactHeaderToolbar(
                    viewModel: viewModel,
                    windowAction: windowAction,
                    onClose: onClose
                )
            }
        }
        .frame(height: FloatingChromeMetrics.headerBarHeight)
    }
}

struct CompactHeaderView: View {
    @Bindable var viewModel: ChatViewModel
    let onExpand: () -> Void
    let onClose: () -> Void
    var onFloatingDragEnded: (() -> Void)?

    private var allowsHeaderDrag: Bool {
        viewModel.preferences.compactWindowAnchor == .floating
    }

    var body: some View {
        ChatPanelHeaderView(
            viewModel: viewModel,
            windowAction: .expand(action: onExpand),
            onClose: onClose,
            allowsHeaderDrag: allowsHeaderDrag,
            onFloatingDragEnded: onFloatingDragEnded
        )
    }
}

/// Minimal pill shown when the compact panel collapses; tap to restore the chat panel.
struct CompactStripBarView: View {
    let fontSettings: AppFontSettings
    let allowsHeaderDrag: Bool
    var onFloatingDragEnded: (() -> Void)?
    let onRestorePanel: () -> Void
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        ZStack {
            Color.clear
                .compactFloatingHeaderDrag(
                    isEnabled: allowsHeaderDrag,
                    onDragEnded: onFloatingDragEnded
                )

            Button(action: onRestorePanel) {
                Text(AppBranding.name)
                    .font(fontSettings.font(for: .caption, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .macTooltip("Open \(AppBranding.name)")
            .accessibilityLabel("Open \(AppBranding.name)")
        }
        .frame(
            width: FloatingChromeMetrics.compactStripWidth,
            height: FloatingChromeMetrics.compactStripHeight
        )
    }
}
