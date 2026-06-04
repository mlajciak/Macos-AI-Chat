import AppKit
import SwiftUI

/// Standard macOS scroll view behavior (wide legacy scrollers, trackpad momentum).
enum AppScrollStyle {
    static func apply(to scrollView: NSScrollView) {
        scrollView.scrollerStyle = .legacy
        scrollView.autohidesScrollers = true
        scrollView.usesPredominantAxisScrolling = true
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.contentView.copiesOnScroll = false
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        scrollView.verticalScroller?.scrollerStyle = .legacy
        scrollView.horizontalScroller?.scrollerStyle = .legacy
    }
}

/// Attaches once when embedded in a SwiftUI `ScrollView` and applies `AppScrollStyle`.
private struct AppScrollStyleConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> AppScrollStyleAnchorView {
        AppScrollStyleAnchorView()
    }

    func updateNSView(_ nsView: AppScrollStyleAnchorView, context: Context) {
        nsView.attachIfNeeded()
    }
}

private final class AppScrollStyleAnchorView: NSView {
    private var didConfigure = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachIfNeeded()
    }

    fileprivate func attachIfNeeded() {
        guard !didConfigure, let scrollView = enclosingScrollView else { return }
        AppScrollStyle.apply(to: scrollView)
        didConfigure = true
    }
}

extension View {
    /// Standard macOS scrollers and trackpad scrolling for SwiftUI `ScrollView` content.
    func appScrollStyle() -> some View {
        background {
            AppScrollStyleConfigurator()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    func appVerticalScrollIndicators() -> some View {
        scrollIndicators(.visible, axes: .vertical)
    }
}
