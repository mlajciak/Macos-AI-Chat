import AppKit
import SwiftUI

/// Leading sidebar toggle in the system title bar when the sidebar column is hidden.
@MainActor
final class ExpandedTitleBarController {
    private var leadingAccessory: NSTitlebarAccessoryViewController?

    func install(on window: NSWindow, viewModel: ChatViewModel) {
        uninstall(from: window)

        guard !viewModel.isExpandedSidebarVisible else { return }

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

    func uninstall(from window: NSWindow?) {
        guard let window else {
            leadingAccessory = nil
            return
        }
        if let leadingAccessory,
           let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === leadingAccessory }) {
            window.removeTitlebarAccessoryViewController(at: index)
        }
        self.leadingAccessory = nil
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
