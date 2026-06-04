import SwiftUI

struct ModelSelectorView: View {
    @Binding var selectedModelId: String
    let isDisabled: Bool
    @Environment(\.appFontSettings) private var appFontSettings

    private var selected: ChatModel {
        ChatModels.model(id: selectedModelId)
    }

    var body: some View {
        Menu {
            ForEach(ChatModels.catalog) { model in
                Button {
                    selectedModelId = model.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name)
                            Text(model.provider)
                                .font(appFontSettings.font(size: appFontSettings.captionPointSize))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.id == selectedModelId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(selected.name)
                        .font(appFontSettings.font(
                            size: appFontSettings.captionPointSize,
                            weight: .medium
                        ))
                        .lineLimit(1)
                    Text(selected.provider)
                        .font(appFontSettings.font(size: max(appFontSettings.captionPointSize - 1, 9)))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
                    }
            }
        }
        .menuStyle(.borderlessButton)
        .disabled(isDisabled)
        .help("Select model")
    }
}
