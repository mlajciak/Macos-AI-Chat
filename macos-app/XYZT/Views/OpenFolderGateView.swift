import SwiftUI

struct OpenFolderGateView: View {
    let fontSettings: AppFontSettings
    let onOpenFolder: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("Open a project folder")
                .font(fontSettings.font(for: .headline, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Sessions and chat history are saved in `.xyzt` inside the folder you choose.")
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Button(action: onOpenFolder) {
                Text("Open folder…")
                    .font(fontSettings.font(for: .caption, weight: .semibold))
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, FloatingChromeMetrics.headerScrollInset(expanded: false))
    }
}
