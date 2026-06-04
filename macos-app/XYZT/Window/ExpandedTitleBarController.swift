import AppKit
import SwiftUI

/// Trailing window actions + leading sidebar toggle when the sidebar column is hidden.
@MainActor
final class ExpandedTitleBarController {
    private var leadingAccessory: NSTitlebarAccessoryViewController?
    private var toolbarAccessory: NSTitlebarAccessoryViewController?

    func install(
        on window: NSWindow,
        viewModel: ChatViewModel,
        onCompact: @escaping () -> Void
    ) {
        uninstall(from: window)

        if !viewModel.isExpandedSidebarVisible {
            let leadingHost = NSHostingView(
                rootView: ExpandedTitleBarLeading(viewModel: viewModel)
            )
            configureAccessoryHost(leadingHost)
            let leadingController = NSTitlebarAccessoryViewController()
            leadingController.view = leadingHost
            leadingController.layoutAttribute = .left
            window.addTitlebarAccessoryViewController(leadingController)
            leadingAccessory = leadingController
        }

        let toolbarHost = NSHostingView(
            rootView: ExpandedTitleBarToolbar(
                viewModel: viewModel,
                onCompact: onCompact
            )
        )
        configureAccessoryHost(toolbarHost)
        let toolbarController = NSTitlebarAccessoryViewController()
        toolbarController.view = toolbarHost
        toolbarController.layoutAttribute = .right
        window.addTitlebarAccessoryViewController(toolbarController)
        toolbarAccessory = toolbarController
    }

    func uninstall(from window: NSWindow?) {
        guard let window else {
            leadingAccessory = nil
            toolbarAccessory = nil
            return
        }
        let ours: [NSTitlebarAccessoryViewController?] = [leadingAccessory, toolbarAccessory]
        for index in window.titlebarAccessoryViewControllers.indices.reversed() {
            let accessory = window.titlebarAccessoryViewControllers[index]
            if ours.contains(where: { $0 === accessory }) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
        }
        leadingAccessory = nil
        toolbarAccessory = nil
    }

    private func configureAccessoryHost(_ host: NSHostingView<some View>) {
        host.translatesAutoresizingMaskIntoConstraints = false
        host.setContentHuggingPriority(.required, for: .vertical)
        host.setContentCompressionResistancePriority(.required, for: .vertical)
    }
}

// MARK: - Title bar content

struct ExpandedTitleBarLeading: View {
    @Bindable var viewModel: ChatViewModel

    private var fontSettings: AppFontSettings { viewModel.preferences.fontSettings }

    var body: some View {
        ExpandedSidebarToolbar(
            fontSettings: fontSettings,
            showsHideSidebar: false,
            leadingInset: FloatingChromeMetrics.expandedTitleBarAccessoryLeadingInset,
            topInset: 0,
            onToggleSidebar: { viewModel.toggleExpandedSidebar() }
        )
        .fixedSize()
    }
}

struct ExpandedTitleBarToolbar: View {
    @Bindable var viewModel: ChatViewModel
    let onCompact: () -> Void

    var body: some View {
        HeaderToolbarActions(
            viewModel: viewModel,
            windowAction: .compact(action: onCompact),
            glassMaterial: .titlebar
        )
        .padding(.trailing, 8)
    }
}
