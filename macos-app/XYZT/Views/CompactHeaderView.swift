import SwiftUI

/// Shared compact / expanded chat header (path menu + toolbar).
struct ChatPanelHeaderView: View {
    @Bindable var viewModel: ChatViewModel
    let windowAction: HeaderToolbarActions.WindowAction
    var onClose: (() -> Void)?
    var trafficLightsLeadingInset: CGFloat = 0
    var allowsHeaderDrag: Bool = false

    /// Extra leading on the path chip only (after `headerHorizontalPadding`).
    private var pathExtraLeading: CGFloat {
        guard trafficLightsLeadingInset > 0 else { return 0 }
        return max(0, trafficLightsLeadingInset - FloatingChromeMetrics.headerHorizontalPadding)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            SessionPathMenu(viewModel: viewModel)
                .padding(.leading, pathExtraLeading)

            Spacer(minLength: 4)
                .compactHeaderDragRegion(isEnabled: allowsHeaderDrag)

            CompactHeaderToolbar(
                viewModel: viewModel,
                windowAction: windowAction,
                onClose: onClose
            )
        }
        .frame(height: FloatingChromeMetrics.headerBarHeight)
    }
}

struct CompactHeaderView: View {
    @Bindable var viewModel: ChatViewModel
    let onExpand: () -> Void
    let onClose: () -> Void

    private var allowsHeaderDrag: Bool {
        viewModel.preferences.compactWindowAnchor == .floating
    }

    var body: some View {
        ChatPanelHeaderView(
            viewModel: viewModel,
            windowAction: .expand(action: onExpand),
            onClose: onClose,
            allowsHeaderDrag: allowsHeaderDrag
        )
    }
}

/// One-line compact bar shown when the panel is collapsed below minimum height.
struct CompactStripBarView: View {
    let fontSettings: AppFontSettings
    let allowsHeaderDrag: Bool
    let onRestorePanel: () -> Void
    let onExpandWindow: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HeaderToolbarIconButton(
                systemImage: "chevron.up",
                tooltip: "Expand chat panel",
                fontSettings: fontSettings,
                weight: .semibold
            ) {
                onRestorePanel()
            }

            Text(AppBranding.name)
                .appFont(.caption, weight: .medium, settings: fontSettings)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)
                .compactHeaderDragRegion(isEnabled: allowsHeaderDrag)

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
        .padding(.horizontal, 10)
        .frame(height: FloatingChromeMetrics.compactStripHeight)
    }
}
