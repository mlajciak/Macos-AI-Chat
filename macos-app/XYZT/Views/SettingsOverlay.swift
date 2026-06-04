import SwiftUI

struct SettingsOverlay: View {
    @Bindable var preferences: AppPreferences
    let usesHudMaterial: Bool
    let onClose: () -> Void

    private var fontSettings: AppFontSettings { preferences.fontSettings }

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
    }

    var body: some View {
        FloatingMenuOverlay(
            title: "Settings",
            closeHelp: "Close settings",
            usesHudMaterial: usesHudMaterial,
            fontSettings: fontSettings,
            onClose: onClose
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OpenRouterSettingsSection(
                        preferences: preferences,
                        fontSettings: fontSettings
                    )

                    Divider().opacity(0.35)

                    SettingsFieldRow(label: "Theme", fontSettings: fontSettings) {
                        ThemeSettingsPicker(
                            selection: $preferences.theme,
                            fontSettings: fontSettings,
                            glassMaterial: glassMaterial
                        )
                    }

                    SettingsFieldRow(label: "Font size", fontSettings: fontSettings) {
                        FontSizeSettingsControl(
                            pointSize: $preferences.bodyPointSize,
                            fontSettings: fontSettings
                        )
                    }

                    SettingsFieldRow(label: "Font family", fontSettings: fontSettings) {
                        FontFamilySettingsPicker(
                            mode: $preferences.fontFamilyMode,
                            customName: $preferences.customFontFamily,
                            fontSettings: fontSettings,
                            glassMaterial: glassMaterial
                        )
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .appScrollStyle()
            }
            .scrollbarsWhenNeeded()
        }
    }
}

// MARK: - OpenRouter

private enum OpenRouterModelLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

private struct OpenRouterSettingsSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings

    @State private var models: [OpenRouterClient.Model] = []
    @State private var searchQuery = ""
    @State private var loadState: OpenRouterModelLoadState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsFieldRow(label: "OpenRouter API key", fontSettings: fontSettings) {
                SecureField("sk-or-…", text: $preferences.openRouterApiKey)
                    .textFieldStyle(.plain)
                    .font(fontSettings.font(for: .caption))
                    .padding(.horizontal, AppDropdownChrome.horizontalPadding)
                    .pillRow()
                    .pillBackground(
                        fill: AppDropdownChrome.fieldFill,
                        stroke: AppDropdownChrome.fieldStroke
                    )
            }

            SettingsFieldRow(label: "Models in menu", fontSettings: fontSettings) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(fontSettings.font(for: .caption))
                            .foregroundStyle(.tertiary)

                        TextField("Search models", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(fontSettings.font(for: .caption))
                            .onSubmit { Task { await loadModels() } }
                    }
                    .padding(.horizontal, AppDropdownChrome.horizontalPadding)
                    .pillRow()
                    .pillBackground(
                        fill: AppDropdownChrome.fieldFill,
                        stroke: AppDropdownChrome.fieldStroke
                    )

                    HStack {
                        Text(statusText)
                            .font(fontSettings.font(for: .caption))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Refresh") {
                            Task { await loadModels() }
                        }
                        .buttonStyle(.plain)
                        .font(fontSettings.font(for: .caption, weight: .medium))
                        .disabled(!preferences.hasOpenRouterApiKey || loadState == .loading)
                    }

                    OpenRouterModelListPanel(
                        models: filteredModels,
                        loadState: loadState,
                        fontSettings: fontSettings,
                        isEnabled: { preferences.isMenuModelEnabled($0) },
                        onToggle: { model, enabled in
                            preferences.setMenuModelEnabled(model, enabled: enabled)
                        }
                    )
                }
            }
        }
        .task(id: preferences.openRouterApiKey) {
            guard preferences.hasOpenRouterApiKey else {
                models = []
                loadState = .idle
                return
            }
            await loadModels()
        }
    }

    private var filteredModels: [OpenRouterClient.Model] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return models }
        return models.filter { model in
            let haystack = "\(model.id) \(model.name) \(model.description ?? "")".lowercased()
            return haystack.contains(query)
        }
    }

    private var statusText: String {
        switch loadState {
        case .idle:
            preferences.hasOpenRouterApiKey
                ? "Press Refresh to load models."
                : "Enter an API key to browse models."
        case .loading:
            "Loading models…"
        case .loaded:
            "\(filteredModels.count) shown · \(preferences.menuModelIds.count) in menu"
        case let .failed(message):
            message
        }
    }

    private func loadModels() async {
        guard preferences.hasOpenRouterApiKey else {
            models = []
            loadState = .idle
            return
        }
        loadState = .loading
        do {
            models = try await OpenRouterClient.listModels(
                apiKey: preferences.openRouterApiKey,
                search: nil
            )
            loadState = .loaded
        } catch {
            models = []
            loadState = .failed(error.localizedDescription)
        }
    }
}

private enum OpenRouterModelListChrome {
    static let maxHeight: CGFloat = 220
    static let placeholderHeight: CGFloat = 120
    static let cornerRadius: CGFloat = 10
}

private struct OpenRouterModelListPanel: View {
    let models: [OpenRouterClient.Model]
    let loadState: OpenRouterModelLoadState
    let fontSettings: AppFontSettings
    let isEnabled: (String) -> Bool
    let onToggle: (OpenRouterClient.Model, Bool) -> Void

    var body: some View {
        Group {
            switch loadState {
            case .loaded where !models.isEmpty:
                scrollableModelList
            default:
                placeholderBox
            }
        }
    }

    private var scrollableModelList: some View {
        modelListChrome(fixedHeight: OpenRouterModelListChrome.maxHeight) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(models, id: \.id) { model in
                        OpenRouterModelRow(
                            model: model,
                            isEnabled: isEnabled(model.id),
                            fontSettings: fontSettings
                        ) { enabled in
                            onToggle(model, enabled)
                        }
                    }
                }
                .appScrollStyle()
            }
            .scrollbarsWhenNeeded()
        }
    }

    private var placeholderBox: some View {
        modelListChrome(fixedHeight: OpenRouterModelListChrome.placeholderHeight) {
            placeholderContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func modelListChrome<Content: View>(
        fixedHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: OpenRouterModelListChrome.cornerRadius, style: .continuous)
                .fill(AppDropdownChrome.fieldFill)
            RoundedRectangle(cornerRadius: OpenRouterModelListChrome.cornerRadius, style: .continuous)
                .strokeBorder(AppDropdownChrome.fieldStroke, lineWidth: 0.5)

            content()
                .padding(6)
        }
        .frame(height: fixedHeight)
    }

    @ViewBuilder
    private var placeholderContent: some View {
        switch loadState {
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .loaded:
            Text("No models match your search.")
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(.tertiary)
        case .idle, .failed:
            Text(idleOrErrorMessage)
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        default:
            EmptyView()
        }
    }

    private var idleOrErrorMessage: String {
        if case let .failed(message) = loadState { return message }
        return "Load models with Refresh above."
    }
}

private struct OpenRouterModelRow: View {
    private static let rowHeight: CGFloat = 36

    let model: OpenRouterClient.Model
    let isEnabled: Bool
    let fontSettings: AppFontSettings
    let onToggle: (Bool) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onToggle(!isEnabled)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary.opacity(0.65))
                    .frame(width: 16, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.name)
                        .font(fontSettings.font(for: .caption, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(model.id)
                        .font(fontSettings.font(size: max(fontSettings.captionPointSize - 1, 9)))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(rowFill)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var rowFill: Color {
        if isEnabled {
            return Color.accentColor.opacity(0.1)
        }
        if isHovered {
            return Color.primary.opacity(0.06)
        }
        return .clear
    }
}

// MARK: - Layout

private struct SettingsFieldRow<Content: View>: View {
    let label: String
    let fontSettings: AppFontSettings
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(fontSettings.font(for: .caption, weight: .medium))
                .foregroundStyle(.secondary)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Theme

private struct ThemeSettingsPicker: View {
    @Binding var selection: AppTheme
    let fontSettings: AppFontSettings
    let glassMaterial: NSVisualEffectView.Material

    var body: some View {
        AppFontDropdown(fontSettings: fontSettings, glassMaterial: glassMaterial) {
            AppDropdownTriggerLabel(
                icon: selection.icon,
                title: selection.label,
                fontSettings: fontSettings
            )
        } menuContent: { close in
            ForEach(AppTheme.allCases) { theme in
                AppDropdownRow(
                    icon: theme.icon,
                    title: theme.label,
                    fontSettings: fontSettings,
                    isSelected: selection == theme
                ) {
                    selection = theme
                    close()
                }
            }
        }
    }
}

// MARK: - Font size

private struct FontSizeSettingsControl: View {
    @Binding var pointSize: Double
    let fontSettings: AppFontSettings

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: $pointSize, in: 8 ... 32, step: 1)

            Text("\(Int(pointSize)) pt")
                .font(fontSettings.font(for: .caption))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.horizontal, AppDropdownChrome.horizontalPadding)
        .pillRow()
        .pillBackground(
            fill: AppDropdownChrome.fieldFill,
            stroke: AppDropdownChrome.fieldStroke
        )
    }
}

// MARK: - Font family

private struct FontFamilySettingsPicker: View {
    @Binding var mode: AppFontFamilyMode
    @Binding var customName: String
    let fontSettings: AppFontSettings
    let glassMaterial: NSVisualEffectView.Material

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppFontDropdown(fontSettings: fontSettings, glassMaterial: glassMaterial) {
                AppDropdownTriggerLabel(
                    icon: mode.icon,
                    title: mode.label,
                    fontSettings: fontSettings
                )
            } menuContent: { close in
                ForEach(AppFontFamilyMode.allCases) { option in
                    AppDropdownRow(
                        icon: option.icon,
                        title: option.label,
                        fontSettings: fontSettings,
                        isSelected: mode == option
                    ) {
                        mode = option
                        close()
                    }
                }
            }

            if mode == .custom {
                TextField("PostScript or family name", text: $customName)
                    .textFieldStyle(.plain)
                    .font(fontSettings.font(for: .caption))
                    .padding(.horizontal, AppDropdownChrome.horizontalPadding)
                    .pillRow()
                    .pillBackground(
                        fill: AppDropdownChrome.fieldFill,
                        stroke: AppDropdownChrome.fieldStroke
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
