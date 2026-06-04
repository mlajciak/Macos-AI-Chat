import SwiftUI

/// Expanded window leading column: full-height sidebar under traffic lights + session tree.
struct ExpandedSidebarColumn: View {
    @Bindable var viewModel: ChatViewModel

    private var fontSettings: AppFontSettings { viewModel.preferences.fontSettings }

    var body: some View {
        GeometryReader { proxy in
            let titlebarTop = max(
                proxy.safeAreaInsets.top,
                FloatingChromeMetrics.expandedWindowTitlebarFallback
            )

            VStack(spacing: 0) {
                ExpandedSidebarToolbar(
                    fontSettings: fontSettings,
                    showsHideSidebar: true,
                    leadingInset: FloatingChromeMetrics.expandedTrafficLightsLeadingWidth,
                    topInset: titlebarTop,
                    onToggleSidebar: { viewModel.toggleExpandedSidebar() }
                )

                SessionProjectTree(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                VisualEffectBackground(
                    material: .sidebar,
                    blendingMode: .behindWindow,
                    emphasized: false
                )
            }
        }
    }
}

/// Toolbar band in the sidebar column (traffic-light row + sidebar toggle).
struct ExpandedSidebarToolbar: View {
    let fontSettings: AppFontSettings
    let showsHideSidebar: Bool
    var leadingInset: CGFloat = FloatingChromeMetrics.expandedTrafficLightsLeadingWidth
    var topInset: CGFloat = FloatingChromeMetrics.expandedWindowTitlebarFallback
    let onToggleSidebar: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            SidebarToggleButton(
                systemImage: showsHideSidebar ? "sidebar.leading" : "sidebar.trailing",
                tooltip: showsHideSidebar ? "Hide sidebar" : "Show sidebar",
                fontSettings: fontSettings,
                glassMaterial: .titlebar,
                action: onToggleSidebar
            )

            Spacer(minLength: 0)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, 10)
        .frame(height: FloatingChromeMetrics.expandedSidebarToolbarBandHeight)
        .frame(maxWidth: .infinity)
        .padding(.top, topInset)
    }
}

struct SidebarToggleButton: View {
    let systemImage: String
    let tooltip: String
    let fontSettings: AppFontSettings
    var glassMaterial: NSVisualEffectView.Material = .titlebar
    let action: () -> Void

    var body: some View {
        HeaderToolbarIconButton(
            systemImage: systemImage,
            tooltip: tooltip,
            fontSettings: fontSettings,
            glassMaterial: glassMaterial,
            action: action
        )
    }
}
