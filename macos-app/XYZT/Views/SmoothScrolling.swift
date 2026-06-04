import AppKit
import SwiftUI

/// Standard macOS scroll view behavior (wide legacy scrollers, trackpad momentum).
enum AppScrollStyle {
    static func apply(to scrollView: NSScrollView, scrollerInsets: NSEdgeInsets = NSEdgeInsetsZero) {
        scrollView.scrollerStyle = .legacy
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.usesPredominantAxisScrolling = true
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.contentView.copiesOnScroll = false
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true
        updateScrollerInsets(scrollView: scrollView, scrollerInsets: scrollerInsets)

        scrollView.verticalScroller?.scrollerStyle = .legacy
        scrollView.horizontalScroller?.scrollerStyle = .legacy
    }

    static func updateScrollerInsets(scrollView: NSScrollView, scrollerInsets: NSEdgeInsets) {
        scrollView.scrollerInsets = scrollerInsets
        scrollView.tile()
    }

    static func updateVerticalElasticity(scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        let clip = scrollView.contentView.bounds
        let contentHeight = documentView.frame.height
        let fits = contentHeight <= clip.height + 2
        scrollView.verticalScrollElasticity = fits ? .none : .automatic
    }
}

/// Observes `NSScrollView` clip bounds for distance-from-bottom and elasticity when content fits.
struct AppScrollBoundsObserver: NSViewRepresentable {
    var onDistanceFromBottom: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDistanceFromBottom: onDistanceFromBottom)
    }

    func makeNSView(context: Context) -> AppScrollStyleAnchorView {
        let view = AppScrollStyleAnchorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: AppScrollStyleAnchorView, context: Context) {
        context.coordinator.onDistanceFromBottom = onDistanceFromBottom
        nsView.coordinator = context.coordinator
        nsView.attachIfNeeded()
    }

    final class Coordinator {
        var onDistanceFromBottom: (CGFloat) -> Void
        private var boundsObserver: NSObjectProtocol?

        init(onDistanceFromBottom: @escaping (CGFloat) -> Void) {
            self.onDistanceFromBottom = onDistanceFromBottom
        }

        deinit {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
        }

        func bind(scrollView: NSScrollView) {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self, weak scrollView] _ in
                guard let self, let scrollView else { return }
                self.report(scrollView: scrollView)
            }
            report(scrollView: scrollView)
        }

        func report(scrollView: NSScrollView) {
            AppScrollStyle.updateVerticalElasticity(scrollView: scrollView)
            guard let documentView = scrollView.documentView else { return }
            let clip = scrollView.contentView.bounds
            let contentHeight = documentView.frame.height
            let distance = contentHeight - clip.origin.y - clip.height
            onDistanceFromBottom(max(0, distance))
        }
    }
}

final class AppScrollStyleAnchorView: NSView {
    weak var coordinator: AppScrollBoundsObserver.Coordinator?
    private var didConfigure = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachIfNeeded()
    }

    fileprivate func attachIfNeeded() {
        guard let scrollView = enclosingScrollView else { return }
        if !didConfigure {
            AppScrollStyle.apply(to: scrollView)
            didConfigure = true
        }
        coordinator?.bind(scrollView: scrollView)
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

/// Scrolls an `NSScrollView` to the document bottom (after SwiftUI layout).
enum AppScrollBottomScroller {
    @MainActor
    static func scroll(_ scrollView: NSScrollView, animated: Bool) {
        guard let documentView = scrollView.documentView else { return }
        scrollView.layoutSubtreeIfNeeded()
        documentView.layoutSubtreeIfNeeded()

        let clipView = scrollView.contentView
        let visibleHeight = clipView.bounds.height
        let contentHeight = documentView.frame.height
        let maxOriginY = max(0, contentHeight - visibleHeight)
        let target = NSPoint(x: clipView.bounds.origin.x, y: maxOriginY)

        if animated {
            clipView.animator().setBoundsOrigin(target)
        } else {
            clipView.setBoundsOrigin(target)
        }
        scrollView.reflectScrolledClipView(clipView)
    }
}

/// Fires when `trigger` changes and scrolls the host SwiftUI `ScrollView` to the bottom.
private struct AppScrollToBottomAction: NSViewRepresentable {
    var trigger: Int
    var animated: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger
        guard trigger > 0, let scrollView = nsView.enclosingScrollView else { return }
        DispatchQueue.main.async {
            AppScrollBottomScroller.scroll(scrollView, animated: animated)
            DispatchQueue.main.async {
                AppScrollBottomScroller.scroll(scrollView, animated: false)
            }
        }
    }

    final class Coordinator {
        var lastTrigger = -1
    }
}

extension View {
    func appScrollToBottomOnTrigger(_ trigger: Int, animated: Bool = true) -> some View {
        background {
            AppScrollToBottomAction(trigger: trigger, animated: animated)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

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

    func appScrollBottomObserver(onDistanceFromBottom: @escaping (CGFloat) -> Void) -> some View {
        background {
            AppScrollBoundsObserver(onDistanceFromBottom: onDistanceFromBottom)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}
