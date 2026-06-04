import SwiftUI

struct CompactHeaderView: View {
    @Bindable var viewModel: ChatViewModel
    let onExpand: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            SessionBreadcrumbButton(viewModel: viewModel)

            Spacer(minLength: 4)

            CompactHeaderToolbar(
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
