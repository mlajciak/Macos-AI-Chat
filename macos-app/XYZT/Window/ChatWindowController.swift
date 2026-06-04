import AppKit
import SwiftUI

@Observable
@MainActor
final class ChatWindowController: NSObject {
    static let compactDefaultSize = NSSize(width: 360, height: 520)
    static let compactMinSize = NSSize(width: 300, height: 380)
    /// Drag below this height (while in the panel) to snap to the one-row strip.
    static let compactCollapseHeight: CGFloat = 220
    static let compactMaxSize = NSSize(width: 560, height: 820)
    private static let transitionHideDelay: TimeInterval = 0.08
    private static let transitionRevealDelay: TimeInterval = 0.14
    static let expandedDefaultSize = NSSize(width: 720, height: 840)
    static let expandedMinSize = NSSize(width: 480, height: 640)
    static let screenInset: CGFloat = 24

    static var compactStripSize: NSSize {
        NSSize(
            width: FloatingChromeMetrics.compactStripWidth,
            height: FloatingChromeMetrics.compactStripHeight
        )
    }

    private(set) var mode: WindowMode = .compact
    private(set) var compactPresentation: CompactPresentation = .panel
    private(set) var isWindowContentVisible = true
    private var window: NSWindow?
    private var hostingView: NSHostingView<ChatRootView>?
    private var savedExpandedFrame: NSRect?
    private var savedCompactPanelSize: NSSize?
    private var isApplyingChrome = false
    private var isUserResizingCompact = false
    private var isCollapsingToStrip = false
    let viewModel = ChatViewModel()

    var isCompactStrip: Bool {
        mode == .compact && compactPresentation == .strip
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = KeyableWindow(
            contentRect: NSRect(origin: .zero, size: Self.compactDefaultSize),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.title = AppBranding.name
        window = win
        installContent()
        applyCompactChrome()
        snapCompactToAnchor()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggleMode() {
        setMode(mode == .compact ? .expanded : .compact)
    }

    func setMode(_ newMode: WindowMode) {
        guard let window, newMode != mode else { return }

        viewModel.closeOverlays()

        performWindowTransition(animateFrame: true) {
            if newMode == .expanded {
                self.savedCompactPanelSize = window.frame.size
                self.mode = .expanded
                self.compactPresentation = .panel
                self.applyExpandedChrome()
                if let saved = self.savedExpandedFrame {
                    window.setFrame(saved, display: true, animate: true)
                } else {
                    self.centerExpanded(window)
                }
                NSApp.setActivationPolicy(.regular)
            } else {
                self.savedExpandedFrame = window.frame
                self.mode = .compact
                self.compactPresentation = .panel
                self.applyCompactChrome()
                if let saved = self.savedCompactPanelSize {
                    self.resizeCompactWindow(
                        to: NSSize(
                            width: min(max(saved.width, Self.compactMinSize.width), Self.compactMaxSize.width),
                            height: min(max(saved.height, Self.compactMinSize.height), Self.compactMaxSize.height)
                        ),
                        animate: true
                    )
                }
                self.snapCompactToAnchor(animate: true)
            }
            self.refreshContent()
        }
    }

    func collapseToStrip() {
        guard mode == .compact, compactPresentation == .panel, let window else { return }
        guard !isCollapsingToStrip else { return }

        isCollapsingToStrip = true
        isUserResizingCompact = false
        savedCompactPanelSize = window.frame.size
        viewModel.closeOverlays()

        performWindowTransition(animateFrame: false) {
            self.compactPresentation = .strip
            self.isApplyingChrome = true
            self.applyCompactSizeLimits(for: .strip)
            self.resizeCompactWindow(to: Self.compactStripSize, animate: false)
            self.isApplyingChrome = false
            self.applyCompactWindowMask()
            self.snapCompactToAnchor(animate: false)
            self.refreshContent()
            self.isCollapsingToStrip = false
        }
    }

    func restoreCompactPanel() {
        guard mode == .compact, compactPresentation == .strip, let window else { return }

        performWindowTransition(animateFrame: true) {
            self.compactPresentation = .panel
            self.isApplyingChrome = true
            self.applyCompactSizeLimits(for: .panel)
            let restored = self.savedCompactPanelSize ?? Self.compactDefaultSize
            self.resizeCompactWindow(
                to: NSSize(
                    width: min(max(restored.width, Self.compactMinSize.width), Self.compactMaxSize.width),
                    height: min(max(restored.height, Self.compactMinSize.height), Self.compactMaxSize.height)
                ),
                animate: true
            )
            self.isApplyingChrome = false
            self.applyCompactWindowMask()
            self.snapCompactToAnchor(animate: true)
            self.refreshContent()
        }
    }

    func hideWindow() {
        window?.orderOut(nil)
    }

    private func installContent() {
        guard let window else { return }
        let root = makeRootView()
        if let hostingView {
            hostingView.rootView = root
        } else {
            let host = NSHostingView(rootView: root)
            host.translatesAutoresizingMaskIntoConstraints = false
            window.contentView = host
            hostingView = host
        }
    }

    private func refreshContent() {
        installContent()
    }

    private func performWindowTransition(
        animateFrame: Bool,
        _ changes: @escaping () -> Void
    ) {
        isWindowContentVisible = false
        refreshContent()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.transitionHideDelay * 1_000_000_000))
            changes()
            let revealDelay = animateFrame ? Self.transitionRevealDelay : Self.transitionHideDelay
            try? await Task.sleep(nanoseconds: UInt64(revealDelay * 1_000_000_000))
            isWindowContentVisible = true
            refreshContent()
        }
    }

    private func makeRootView() -> ChatRootView {
        ChatRootView(
            viewModel: viewModel,
            mode: mode,
            compactPresentation: compactPresentation,
            isContentVisible: isWindowContentVisible,
            onExpand: { [weak self] in self?.setMode(.expanded) },
            onCompact: { [weak self] in self?.setMode(.compact) },
            onRestoreCompactPanel: { [weak self] in self?.restoreCompactPanel() },
            onClose: { [weak self] in self?.hideWindow() },
            onCompactResizeStarted: { [weak self] in self?.isUserResizingCompact = true },
            onCompactResizeEnded: { [weak self] in
                self?.isUserResizingCompact = false
                self?.finishCompactGeometryChange()
            },
            onCollapseToStrip: { [weak self] in self?.collapseToStrip() },
            onCompactAnchorChange: { [weak self] in
                self?.handleCompactAnchorPreferenceChange()
            },
            onFloatingDragEnded: { [weak self] in
                self?.finishCompactGeometryChange()
            }
        )
    }

    private func handleCompactAnchorPreferenceChange() {
        guard mode == .compact, let window else { return }

        isApplyingChrome = true
        defer { isApplyingChrome = false }

        let anchor = viewModel.preferences.compactWindowAnchor
        if anchor == .floating {
            let frame = clampedCompactFrame(window.frame)
            window.setFrame(frame, display: true, animate: true)
            persistFloatingCompactOrigin(from: frame)
        } else {
            snapCompactToAnchor(animate: true)
        }
        refreshContent()
    }

    private func applyCompactChrome() {
        guard let window else { return }
        isApplyingChrome = true
        defer { isApplyingChrome = false }

        window.styleMask = [.borderless, .resizable, .fullSizeContentView]
        window.title = AppBranding.name
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.level = .floating
        window.isMovable = false
        window.isMovableByWindowBackground = false
        applyCompactSizeLimits(for: compactPresentation)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        applyCompactWindowMask()
        snapCompactToAnchor()
    }

    private func applyCompactSizeLimits(for presentation: CompactPresentation) {
        guard let window else { return }
        switch presentation {
        case .panel:
            // Allow shrinking below panel min so `windowWillResize` can snap to strip.
            window.minSize = NSSize(
                width: Self.compactMinSize.width,
                height: Self.compactStripSize.height
            )
            window.maxSize = Self.compactMaxSize
        case .strip:
            window.minSize = Self.compactStripSize
            window.maxSize = Self.compactStripSize
        }
    }

    private func resizeCompactWindow(to size: NSSize, animate: Bool) {
        guard let window else { return }
        let anchor = viewModel.preferences.compactWindowAnchor
        let frame: NSRect
        if anchor == .floating {
            var next = window.frame
            next.size = size
            frame = clampedCompactFrame(next)
        } else {
            let pinned = anchor.pinnedCorner(in: window.frame)
            frame = anchor.frame(pinnedTo: pinned, size: size)
        }
        window.setFrame(frame, display: true, animate: animate)
    }

    private func applyExpandedChrome() {
        guard let window else { return }
        isApplyingChrome = true
        defer { isApplyingChrome = false }

        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = ""
        window.subtitle = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar = nil
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        window.level = .normal
        window.isMovable = true
        window.isMovableByWindowBackground = false
        window.minSize = Self.expandedMinSize
        window.maxSize = NSSize(width: 10_000, height: 10_000)
        window.isOpaque = true
        window.backgroundColor = NSColor.windowBackgroundColor
        window.hasShadow = true
        window.collectionBehavior = [.fullScreenPrimary]

        let size = window.frame.size
        if size.width < Self.expandedMinSize.width || size.height < Self.expandedMinSize.height {
            window.setContentSize(
                NSSize(
                    width: max(Self.expandedMinSize.width, size.width),
                    height: max(Self.expandedMinSize.height, size.height)
                )
            )
        }

        clearCompactWindowMask()
    }

    private func applyCompactWindowMask() {
        guard mode == .compact, let hostingView else { return }
        hostingView.wantsLayer = true
        let radius = compactPresentation == .strip
            ? FloatingChromeMetrics.compactStripCornerRadius
            : FloatingChromeMetrics.menuOverlayCornerRadius
        hostingView.layer?.cornerRadius = radius
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
    }

    private func clearCompactWindowMask() {
        guard let hostingView else { return }
        hostingView.layer?.cornerRadius = 0
        hostingView.layer?.masksToBounds = false
    }

    func snapCompactToAnchor(animate: Bool = false) {
        guard mode == .compact, let window else { return }
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let anchor = viewModel.preferences.compactWindowAnchor
        let visible = screen.visibleFrame
        let frame: NSRect

        if anchor == .floating {
            if let saved = viewModel.preferences.compactFloatingWindowOrigin {
                var restored = NSRect(origin: saved, size: window.frame.size)
                restored = anchor.clampedFrame(restored, in: visible, inset: Self.screenInset)
                frame = restored
            } else {
                frame = anchor.clampedFrame(window.frame, in: visible, inset: Self.screenInset)
            }
            persistFloatingCompactOrigin(from: frame)
        } else {
            frame = anchor.snappedFrame(
                size: window.frame.size,
                in: visible,
                inset: Self.screenInset
            )
        }

        window.setFrame(frame, display: true, animate: animate)
    }

    func finishCompactGeometryChange() {
        guard mode == .compact else { return }
        if viewModel.preferences.compactWindowAnchor == .floating {
            guard let window else { return }
            let frame = clampedCompactFrame(window.frame)
            window.setFrame(frame, display: true, animate: false)
            persistFloatingCompactOrigin(from: frame)
        } else {
            snapCompactToAnchor()
        }
    }

    private func clampedCompactFrame(_ frame: NSRect) -> NSRect {
        guard let window else { return frame }
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return frame }
        return viewModel.preferences.compactWindowAnchor.clampedFrame(
            frame,
            in: screen.visibleFrame,
            inset: Self.screenInset
        )
    }

    private func persistFloatingCompactOrigin(from frame: NSRect) {
        guard viewModel.preferences.compactWindowAnchor == .floating else { return }
        viewModel.preferences.compactFloatingWindowOrigin = frame.origin
    }

    private func centerExpanded(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = NSRect(origin: .zero, size: Self.expandedDefaultSize)
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        window.setFrame(frame, display: true, animate: true)
    }
}

extension ChatWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if mode == .compact {
            hideWindow()
            return false
        }
        return true
    }

    func windowWillResize(_ sender: NSWindow, to frame: NSRect) -> NSRect {
        guard mode == .compact,
              compactPresentation == .panel,
              !isApplyingChrome,
              !isCollapsingToStrip
        else { return frame }

        guard frame.height < Self.compactCollapseHeight else { return frame }

        let anchor = viewModel.preferences.compactWindowAnchor
        let pinned = anchor.pinnedCorner(in: sender.frame)
        let stripFrame = anchor.frame(
            pinnedTo: pinned,
            size: Self.compactStripSize
        )

        collapseToStrip()
        return stripFrame
    }

    func windowDidResize(_ notification: Notification) {
        hostingView?.needsLayout = true
        hostingView?.layoutSubtreeIfNeeded()
        guard mode == .compact, let window else { return }

        if compactPresentation == .panel,
           window.frame.height < Self.compactCollapseHeight,
           !isApplyingChrome,
           !isCollapsingToStrip
        {
            collapseToStrip()
            return
        }

        guard !isApplyingChrome, !isUserResizingCompact else { return }
        finishCompactGeometryChange()
    }

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingChrome, mode == .compact else { return }
        finishCompactGeometryChange()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard mode == .compact else { return }
        finishCompactGeometryChange()
    }
}
