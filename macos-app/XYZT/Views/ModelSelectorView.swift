import SwiftUI

struct ModelSelectorView: View {
    @Binding var selectedModelId: String
    let models: [ChatModel]
    let fontSettings: AppFontSettings
    let glassMaterial: NSVisualEffectView.Material
    let isDisabled: Bool

    private var selected: ChatModel? {
        models.first { $0.id == selectedModelId }
    }

    var body: some View {
        AppFontDropdown(
            fontSettings: fontSettings,
            fullWidth: false,
            arrowEdge: .top,
            glassMaterial: glassMaterial,
            menuMinWidth: 220,
            tooltip: models.isEmpty ? "Choose models in Settings" : "Select model"
        ) {
            HStack(spacing: 6) {
                Text(selected?.name ?? "No models")
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .foregroundStyle(models.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .pillRow(height: AppChrome.compactControlHeight)
            .pillBackground(
                height: AppChrome.compactControlHeight,
                fill: Color.white.opacity(0.08),
                stroke: Color.white.opacity(0.16)
            )
        } menuContent: { close in
            if models.isEmpty {
                Text("Add models in Settings")
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(models) { model in
                    AppDropdownRow(
                        icon: nil,
                        title: model.name,
                        fontSettings: fontSettings,
                        isSelected: model.id == selectedModelId
                    ) {
                        selectedModelId = model.id
                        close()
                    }
                }
            }
        }
        .disabled(isDisabled || models.isEmpty)
    }
}
