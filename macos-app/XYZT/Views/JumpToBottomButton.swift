import AppKit
import SwiftUI

struct JumpToBottomButton: View {
    let fontSettings: AppFontSettings
    var glassMaterial: NSVisualEffectView.Material = .hudWindow
    let action: () -> Void

    var body: some View {
        HeaderToolbarIconButton(
            systemImage: "arrow.down",
            tooltip: "Jump to latest messages",
            fontSettings: fontSettings,
            weight: .semibold,
            glassMaterial: glassMaterial,
            action: action
        )
    }
}
