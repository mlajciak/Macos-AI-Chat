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
