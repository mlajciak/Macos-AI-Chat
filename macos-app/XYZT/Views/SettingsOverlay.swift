import SwiftUI

struct SettingsOverlay: View {
    @Bindable var preferences: AppPreferences
    let usesHudMaterial: Bool
    let onClose: () -> Void

    private var fontSettings: AppFontSettings { preferences.fontSettings }

    var body: some View {
        FloatingMenuOverlay(
            title: "Settings",
            closeHelp: "Close settings",
            usesHudMaterial: usesHudMaterial,
            fontSettings: fontSettings,
            onClose: onClose
        ) {
            SettingsPanelContent(preferences: preferences, usesHudMaterial: usesHudMaterial)
        }
    }
}

// MARK: - Categories (expanded settings window)

enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case openRouter
    case chat
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .chat: "Chat"
        case .appearance: "Appearance"
        }
    }

    var systemImage: String {
        switch self {
        case .openRouter: "key.fill"
        case .chat: "bubble.left.and.bubble.right"
        case .appearance: "paintbrush"
        }
    }
}

/// Expanded window: sidebar categories + detail pane (macOS Settings style).
struct ExpandedSettingsSheet: View {
    @Bindable var preferences: AppPreferences
    @State private var category: SettingsCategory = .openRouter

    private var fontSettings: AppFontSettings { preferences.fontSettings }

    var body: some View {
        NavigationSplitView {
            List(selection: $category) {
                ForEach(SettingsCategory.allCases) { item in
                    Label {
                        Text(item.title)
                            .font(fontSettings.font(for: .body))
                    } icon: {
                        Image(systemName: item.systemImage)
                            .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    }
                    .tag(item)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 168, ideal: 200, max: 240)
        } detail: {
            SettingsCategoryDetail(
                category: category,
                preferences: preferences,
                usesHudMaterial: false
            )
            .navigationTitle(category.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 640, minHeight: 520)
        .appAccentEnvironment(preferences)
    }
}

struct SettingsCategoryDetail: View {
    let category: SettingsCategory
    @Bindable var preferences: AppPreferences
    var usesHudMaterial: Bool = false

    private var fontSettings: AppFontSettings { preferences.fontSettings }

    var body: some View {
        ScrollView {
            Group {
                switch category {
                case .openRouter:
                    OpenRouterSettingsSection(
                        preferences: preferences,
                        fontSettings: fontSettings
                    )
                case .chat:
                    VStack(alignment: .leading, spacing: 16) {
                        CompactWindowSettingsSection(
                            preferences: preferences,
                            fontSettings: fontSettings,
                            usesHudMaterial: usesHudMaterial
                        )
                        ChatTitleModelSettingsSection(
                            preferences: preferences,
                            fontSettings: fontSettings,
                            usesHudMaterial: usesHudMaterial
                        )
                    }
                case .appearance:
                    AppearanceSettingsSection(
                        preferences: preferences,
                        fontSettings: fontSettings,
                        usesHudMaterial: usesHudMaterial
                    )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appScrollStyle()
        }
        .scrollbarsWhenNeeded()
    }
}

/// Settings fields without overlay chrome (compact overlay: collapsible categories).
struct SettingsPanelContent: View {
    @Bindable var preferences: AppPreferences
    var usesHudMaterial: Bool = false

    @State private var expandedCategories: Set<SettingsCategory> = [.openRouter]
    @Environment(\.appThemeColors) private var theme

    private var fontSettings: AppFontSettings { preferences.fontSettings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(SettingsCategory.allCases) { category in
                    SettingsCollapsibleCategory(
                        category: category,
                        fontSettings: fontSettings,
                        isExpanded: categoryExpanded(category)
                    ) {
                        categorySectionContent(category)
                    }

                    if category != SettingsCategory.allCases.last {
                        Rectangle()
                            .fill(theme.divider)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .appScrollStyle()
        }
        .scrollbarsWhenNeeded()
    }

    private func categoryExpanded(_ category: SettingsCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedCategories.insert(category)
                    } else {
                        expandedCategories.remove(category)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func categorySectionContent(_ category: SettingsCategory) -> some View {
        switch category {
        case .openRouter:
            OpenRouterSettingsSection(
                preferences: preferences,
                fontSettings: fontSettings
            )
        case .chat:
            VStack(alignment: .leading, spacing: 16) {
                CompactWindowSettingsSection(
                    preferences: preferences,
                    fontSettings: fontSettings,
                    usesHudMaterial: usesHudMaterial
                )
                ChatTitleModelSettingsSection(
                    preferences: preferences,
                    fontSettings: fontSettings,
                    usesHudMaterial: usesHudMaterial
                )
            }
        case .appearance:
            AppearanceSettingsSection(
                preferences: preferences,
                fontSettings: fontSettings,
                usesHudMaterial: usesHudMaterial
            )
        }
    }
}

private struct SettingsCollapsibleCategory<Content: View>: View {
    let category: SettingsCategory
    let fontSettings: AppFontSettings
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: category.systemImage)
                        .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 18)

                    Text(category.title)
                        .font(fontSettings.font(for: .body, weight: .medium))
                        .foregroundStyle(theme.primaryText)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(fontSettings.font(size: fontSettings.smallIconPointSize, weight: .semibold))
                        .foregroundStyle(theme.secondaryMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .macTooltip(isExpanded ? "Collapse \(category.title)" : "Expand \(category.title)")

            if isExpanded {
                content()
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Compact window

private struct CompactWindowSettingsSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings
    var usesHudMaterial: Bool = false
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsFieldRow(label: "Screen position", fontSettings: fontSettings) {
                Text(
                    preferences.compactWindowAnchor == .floating
                        ? "Drag the compact window by its header to place it anywhere on screen."
                        : "Where the compact chat panel sits on your display."
                )
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            CompactWindowAnchorPicker(
                selection: $preferences.compactWindowAnchor,
                fontSettings: fontSettings
            )
        }
    }
}

private struct CompactWindowAnchorPicker: View {
    @Binding var selection: CompactWindowAnchor
    let fontSettings: AppFontSettings
    @Environment(\.appThemeColors) private var theme

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var cornerAnchors: [CompactWindowAnchor] {
        CompactWindowAnchor.allCases.filter(\.usesCornerSnap)
    }

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cornerAnchors) { anchor in
                    anchorButton(anchor)
                }
            }
            anchorButton(.floating)
        }
    }

    private func anchorButton(_ anchor: CompactWindowAnchor) -> some View {
        Button {
            selection = anchor
        } label: {
            HStack(spacing: 6) {
                Image(systemName: anchor.systemImage)
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                Text(anchor.label)
                    .font(fontSettings.font(for: .caption, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .foregroundStyle(selection == anchor ? theme.accent : theme.primaryText)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selection == anchor ? theme.accentSelectionFill : theme.fieldFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        selection == anchor ? theme.accentSelectionStroke : theme.fieldStroke,
                        lineWidth: selection == anchor ? 1 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Appearance

private struct AppearanceSettingsSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings
    var usesHudMaterial: Bool = false

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
    @Environment(\.appThemeColors) private var theme

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
                        fill: theme.fieldFill,
                        stroke: theme.fieldStroke
                    )
            }

            SettingsFieldRow(label: "Models in menu", fontSettings: fontSettings) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(fontSettings.font(for: .caption))
                            .foregroundStyle(theme.tertiary)

                        TextField("Search models", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(fontSettings.font(for: .caption))
                            .onSubmit { Task { await loadModels() } }
                    }
                    .padding(.horizontal, AppDropdownChrome.horizontalPadding)
                    .pillRow()
                    .pillBackground(
                        fill: theme.fieldFill,
                        stroke: theme.fieldStroke
                    )

                    HStack {
                        Text(statusText)
                            .font(fontSettings.font(for: .caption))
                            .foregroundStyle(theme.secondary)
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
    @Environment(\.appThemeColors) private var theme

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
                .fill(theme.fieldFill)
            RoundedRectangle(cornerRadius: OpenRouterModelListChrome.cornerRadius, style: .continuous)
                .strokeBorder(theme.fieldStroke, lineWidth: 0.5)

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
                .foregroundStyle(theme.tertiary)
        case .idle, .failed:
            Text(idleOrErrorMessage)
                .font(fontSettings.font(for: .caption))
                .foregroundStyle(theme.tertiary)
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

    @Environment(\.appThemeColors) private var theme
    @State private var isHovered = false

    var body: some View {
        Button {
            onToggle(!isEnabled)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(fontSettings.font(size: fontSettings.iconPointSize, weight: .medium))
                    .foregroundStyle(isEnabled ? theme.accent : theme.secondaryMuted)
                    .frame(width: 16, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.name)
                        .font(fontSettings.font(for: .caption, weight: .medium))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Text(model.id)
                        .font(fontSettings.font(size: max(fontSettings.captionPointSize - 1, 9)))
                        .foregroundStyle(theme.secondary)
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
            return theme.accentMuted
        }
        if isHovered {
            return theme.mutedRowFill
        }
        return .clear
    }
}

// MARK: - Chat title model

private struct ChatTitleModelSettingsSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings
    var usesHudMaterial: Bool = false
    @Environment(\.appThemeColors) private var theme

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsFieldRow(label: "Chat title generation", fontSettings: fontSettings) {
                Text("After your first message, the app can ask OpenRouter for a short session title.")
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsFieldRow(label: "Title model", fontSettings: fontSettings) {
                AppFontDropdown(fontSettings: fontSettings, glassMaterial: glassMaterial) {
                    AppDropdownTriggerLabel(
                        icon: "textformat",
                        title: preferences.chatTitleModelSource.label,
                        fontSettings: fontSettings
                    )
                } menuContent: { close in
                    ForEach(ChatTitleModelSource.allCases) { source in
                        AppDropdownRow(
                            icon: source == .selectedChatModel ? "bubble.left.and.bubble.right" : "character.cursor.ibeam",
                            title: source.label,
                            fontSettings: fontSettings,
                            isSelected: preferences.chatTitleModelSource == source
                        ) {
                            preferences.chatTitleModelSource = source
                            close()
                        }
                    }
                }
            }

            if preferences.chatTitleModelSource == .custom {
                SettingsFieldRow(label: "Custom model ID", fontSettings: fontSettings) {
                    TextField("openai/gpt-4o-mini", text: $preferences.chatTitleCustomModelId)
                        .textFieldStyle(.plain)
                        .font(fontSettings.font(for: .caption))
                        .padding(.horizontal, AppDropdownChrome.horizontalPadding)
                        .pillRow()
                        .pillBackground(
                            fill: theme.fieldFill,
                            stroke: theme.fieldStroke
                        )
                }
            } else {
                Text("Uses the model selected in the chat input. If none is selected, the first message is truncated for the title.")
                    .font(fontSettings.font(for: .caption))
                    .foregroundStyle(theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Layout

private struct SettingsFieldRow<Content: View>: View {
    let label: String
    let fontSettings: AppFontSettings
    @ViewBuilder var content: () -> Content
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(fontSettings.font(for: .caption, weight: .medium))
                .foregroundStyle(theme.secondary)

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
                .foregroundStyle(theme.secondary)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.horizontal, AppDropdownChrome.horizontalPadding)
        .pillRow()
        .pillBackground(
            fill: theme.fieldFill,
            stroke: theme.fieldStroke
        )
    }

    @Environment(\.appThemeColors) private var theme
}

// MARK: - Font family

private struct FontFamilySettingsPicker: View {
    @Binding var mode: AppFontFamilyMode
    @Binding var customName: String
    let fontSettings: AppFontSettings
    let glassMaterial: NSVisualEffectView.Material
    @Environment(\.appThemeColors) private var theme

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
                        fill: theme.fieldFill,
                        stroke: theme.fieldStroke
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
