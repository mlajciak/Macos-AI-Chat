import SwiftUI

/// Compact image-model picker for the chat input bar (all enabled image models).
struct ImageModelMenuButton: View {
    @Binding var selectedImageModelId: String
    let models: [ChatModel]
    let fontSettings: AppFontSettings
    let glassMaterial: NSVisualEffectView.Material
    @Environment(\.appThemeColors) private var theme

    private var hasSelection: Bool {
        models.contains(where: { $0.id == selectedImageModelId })
    }

    var body: some View {
        AppFontDropdown(
            fontSettings: fontSettings,
            fullWidth: false,
            arrowEdge: .top,
            glassMaterial: glassMaterial,
            menuMinWidth: 220,
            tooltip: models.isEmpty ? "Add image models in Settings → Models" : "Image model"
        ) {
            Image(systemName: "photo")
                .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                .foregroundStyle(hasSelection ? theme.accent : theme.secondaryMuted)
                .frame(width: AppChrome.compactControlHeight, height: AppChrome.compactControlHeight)
                .background {
                    Circle()
                        .fill(hasSelection ? theme.accentMuted : theme.fieldFill)
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            hasSelection ? theme.accentSelectionStroke : theme.fieldStroke,
                            lineWidth: hasSelection ? 1 : 0.5
                        )
                }
        } menuContent: { close in
            if models.isEmpty {
                Text("Enable in Settings → Models")
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(models) { model in
                    AppDropdownRow(
                        icon: "photo",
                        title: model.name,
                        fontSettings: fontSettings,
                        isSelected: model.id == selectedImageModelId
                    ) {
                        selectedImageModelId = model.id
                        close()
                    }
                }
            }
        }
        .disabled(models.isEmpty)
    }
}
