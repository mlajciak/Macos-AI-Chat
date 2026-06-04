import AppKit
import SwiftUI

struct ChatInputTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let fontSettings: AppFontSettings
    var expandedMode: Bool
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        AppScrollStyle.apply(to: scrollView)

        let textView = ChatInputNSTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.expandedMode = expandedMode
        textView.applyFont(fontSettings)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.applyHeight(for: textView, forceMin: true)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        textView.expandedMode = expandedMode
        textView.onSubmit = onSubmit
        textView.applyFont(fontSettings)

        if textView.string != text {
            textView.string = text
            if text.isEmpty {
                context.coordinator.resetToMinHeight()
            } else {
                context.coordinator.applyHeight(for: textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputTextView
        weak var textView: ChatInputNSTextView?
        weak var scrollView: NSScrollView?

        init(parent: ChatInputTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHeight(for: textView)
        }

        func resetToMinHeight() {
            guard let textView, let scrollView else { return }
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            applyHeight(for: textView, forceMin: true)
        }

        func applyHeight(for textView: NSTextView, forceMin: Bool = false) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return }

            layoutManager.ensureLayout(for: textContainer)
            let used = layoutManager.usedRect(for: textContainer)
            let inset = textView.textContainerInset.height * 2
            let minH = ChatInputMetrics.minHeight(for: parent.fontSettings)
            let maxH = ChatInputMetrics.maxHeight(for: parent.fontSettings)

            let contentHeight = used.height + inset + 2
            let next = forceMin ? minH : min(max(contentHeight, minH), maxH)
            if abs(parent.height - next) > 0.5 {
                parent.height = next
            }

            let documentHeight = max(contentHeight, next)
            var frame = textView.frame
            frame.size.width = scrollView?.contentSize.width ?? frame.width
            frame.size.height = documentHeight
            textView.frame = frame
            textView.minSize = NSSize(width: 0, height: documentHeight)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: documentHeight)

            updateScrollerVisibility(contentHeight: documentHeight, visibleHeight: next)
            scrollView?.reflectScrolledClipView(scrollView?.contentView ?? NSClipView())
        }

        private func updateScrollerVisibility(contentHeight: CGFloat, visibleHeight: CGFloat) {
            guard let scrollView else { return }
            let needsScroll = contentHeight > visibleHeight + 1
            scrollView.hasVerticalScroller = needsScroll
            scrollView.verticalScroller?.isHidden = !needsScroll
        }
    }
}

final class ChatInputNSTextView: NSTextView {
    var expandedMode = false
    var onSubmit: (() -> Void)?

    func applyFont(_ settings: AppFontSettings) {
        font = settings.nsFont(for: .body)
        textColor = .textColor
        insertionPointColor = .textColor
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if expandedMode {
                if flags.contains(.command) {
                    onSubmit?()
                    return
                }
            } else if flags.contains(.shift) {
                super.keyDown(with: event)
                return
            } else {
                onSubmit?()
                return
            }
        }
        super.keyDown(with: event)
    }
}
