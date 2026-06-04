import AppKit
import SwiftUI

extension View {
    /// Native macOS tooltip (yellow callout); more reliable than `.help` alone on borderless windows.
    func macTooltip(_ text: String) -> some View {
        background {
            MacTooltipHost(text: text)
        }
    }
}

private struct MacTooltipHost: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.toolTip = text
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = text
    }
}
