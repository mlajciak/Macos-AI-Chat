import SwiftUI

struct CompactHeaderView: View {
    @Bindable var viewModel: ChatViewModel
    let onExpand: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            SessionBreadcrumbButton(viewModel: viewModel)

            Spacer(minLength: 4)

            HeaderToolbarActions(
                viewModel: viewModel,
                windowAction: .expand(action: onExpand),
                onClose: onClose
            )
        }
        .frame(height: FloatingChromeMetrics.headerBarHeight)
    }
}

/// One-line compact bar shown when the panel is collapsed below minimum height.
struct CompactStripBarView: View {
    let fontSettings: AppFontSettings
    let onRestorePanel: () -> Void
    let onExpandWindow: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            MacNativeIconButton(
                systemImage: "chevron.up",
                tooltip: "Expand chat panel",
                iconPointSize: fontSettings.iconPointSize,
                weight: .semibold,
                action: onRestorePanel
            )
            .frame(width: 24, height: 24)
            .accessibilityLabel("Expand chat panel")

            Text(AppBranding.name)
                .appFont(.caption, weight: .medium, settings: fontSettings)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            CompactWindowToolbar(
                fontSettings: fontSettings,
                onExpandWindow: onExpandWindow,
                onClose: onClose
            )
        }
        .padding(.horizontal, 10)
        .frame(height: FloatingChromeMetrics.compactStripHeight)
    }
}

struct ExpandedFloatingHeaderView: View {
    @Bindable var viewModel: ChatViewModel
    let onCompact: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            SessionBreadcrumbButton(viewModel: viewModel)
            Spacer()
            HeaderToolbarActions(
                viewModel: viewModel,
                windowAction: .compact(action: onCompact)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
