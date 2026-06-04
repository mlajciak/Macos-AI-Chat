import SwiftUI

struct JumpToBottomButton: View {
    let fontSettings: AppFontSettings
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down")
                .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jump to bottom")
        .help("Jump to latest messages")
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}
