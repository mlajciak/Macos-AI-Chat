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
    case general
    case models
    case agent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .models: "Models"
        case .agent: "Agent"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .models: "square.stack.3d.up"
        case .agent: "terminal"
        }
    }
}

/// Expanded window: sidebar categories + detail pane (macOS Settings style).
struct ExpandedSettingsSheet: View {
    @Bindable var preferences: AppPreferences
    @State private var category: SettingsCategory = .general

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
                case .models:
                    ModelsSettingsSection(
                        preferences: preferences,
                        fontSettings: fontSettings
                    )
                case .agent:
                    AgentSettingsSection(
                        preferences: preferences,
                        fontSettings: fontSettings,
                        usesHudMaterial: usesHudMaterial
                    )
                case .general:
                    GeneralSettingsSection(
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

    @State private var expandedCategories: Set<SettingsCategory> = []
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
        case .models:
            ModelsSettingsSection(
                preferences: preferences,
                fontSettings: fontSettings
            )
        case .agent:
            AgentSettingsSection(
                preferences: preferences,
                fontSettings: fontSettings,
                usesHudMaterial: usesHudMaterial
            )
        case .general:
            GeneralSettingsSection(
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

// MARK: - Agent

private struct AgentSettingsSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings
    var usesHudMaterial: Bool = false
    @Environment(\.appThemeColors) private var theme

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsFieldRow(label: "Tools", fontSettings: fontSettings) {
                Toggle("Send tool definitions", isOn: $preferences.enableAgentTools)
                    .toggleStyle(.switch)
                    .font(fontSettings.font(for: .caption))
            }

            SettingsFieldRow(label: "Context", fontSettings: fontSettings) {
                Toggle("Workspace card", isOn: $preferences.showWorkspaceContextCard)
                    .toggleStyle(.switch)
                    .font(fontSettings.font(for: .caption))
            }

            SettingsFieldRow(label: "Thinking", fontSettings: fontSettings) {
                Toggle("Collapse when replying", isOn: $preferences.autoCollapseThinking)
                    .toggleStyle(.switch)
                    .font(fontSettings.font(for: .caption))
            }

            SettingsFieldRow(label: "Sandbox", fontSettings: fontSettings) {
                Toggle("Limit commands to project", isOn: $preferences.sandboxCommands)
                    .toggleStyle(.switch)
                    .font(fontSettings.font(for: .caption))
            }

            SettingsFieldRow(label: "Commands", fontSettings: fontSettings) {
                AppFontDropdown(fontSettings: fontSettings, glassMaterial: glassMaterial) {
                    AppDropdownTriggerLabel(
                        icon: "hand.raised",
                        title: preferences.commandApprovalMode.label,
                        fontSettings: fontSettings
                    )
                } menuContent: { close in
                    ForEach(CommandApprovalMode.allCases) { mode in
                        AppDropdownRow(
                            icon: "terminal",
                            title: mode.label,
                            fontSettings: fontSettings,
                            isSelected: preferences.commandApprovalMode == mode
                        ) {
                            preferences.commandApprovalMode = mode
                            close()
                        }
                    }
                }
            }

        }
    }
}

// MARK: - General

private struct GeneralSettingsSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings
    var usesHudMaterial: Bool = false

    private var glassMaterial: NSVisualEffectView.Material {
        usesHudMaterial ? .hudWindow : .popover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CompactWindowSettingsSection(
                preferences: preferences,
                fontSettings: fontSettings,
                usesHudMaterial: usesHudMaterial
            )

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

// MARK: - Compact window

private struct CompactWindowSettingsSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings
    var usesHudMaterial: Bool = false
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsFieldRow(label: "Screen position", fontSettings: fontSettings) {
                CompactWindowAnchorPicker(
                    selection: $preferences.compactWindowAnchor,
                    fontSettings: fontSettings
                )
            }
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

// MARK: - Models

private struct ModelsSettingsSection: View {
    @Bindable var preferences: AppPreferences
    let fontSettings: AppFontSettings
    @Environment(\.appThemeColors) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsFieldRow(label: "API key", fontSettings: fontSettings) {
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

            OpenRouterUsageChartSection(
                preferences: preferences,
                fontSettings: fontSettings
            )

            ChatTitleModelSettingsSection(
                preferences: preferences,
                fontSettings: fontSettings,
                usesHudMaterial: false
            )

            OpenRouterModelPickerSection(
                kind: .agent,
                preferences: preferences,
                fontSettings: fontSettings
            )

            OpenRouterModelPickerSection(
                kind: .image,
                preferences: preferences,
                fontSettings: fontSettings
            )
        }
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
            }
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
