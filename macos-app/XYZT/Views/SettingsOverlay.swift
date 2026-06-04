import SwiftUI

struct SettingsOverlay: View {
    @Bindable var preferences: AppPreferences
    let usesHudMaterial: Bool
    let onClose: () -> Void

    var body: some View {
        FloatingMenuOverlay(
            title: "Settings",
            closeHelp: "Close settings",
            usesHudMaterial: usesHudMaterial,
            onClose: onClose
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsFieldRow(label: "Theme") {
                        ThemeSettingsPicker(selection: $preferences.theme)
                    }

                    SettingsFieldRow(label: "Font size") {
                        FontSizeSettingsControl(pointSize: $preferences.bodyPointSize)
                    }

                    SettingsFieldRow(label: "Font family") {
                        FontFamilySettingsPicker(
                            mode: $preferences.fontFamilyMode,
                            customName: $preferences.customFontFamily
                        )
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Layout

private struct SettingsFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum SettingsControlChrome {
    static let cornerRadius: CGFloat = 8
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 8

    static var fieldBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.06))
    }

    static var fieldBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
    }
}

// MARK: - Theme

private struct ThemeSettingsPicker: View {
    @Binding var selection: AppTheme

    var body: some View {
        SettingsIconDropdown(
            icon: selection.icon,
            title: selection.label
        ) {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    selection = theme
                } label: {
                    SettingsDropdownOption(
                        icon: theme.icon,
                        title: theme.label,
                        isSelected: selection == theme
                    )
                }
            }
        }
    }
}

// MARK: - Font size

private struct FontSizeSettingsControl: View {
    @Binding var pointSize: Double

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: $pointSize, in: 8 ... 32, step: 1)

            Text("\(Int(pointSize)) pt")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.horizontal, SettingsControlChrome.horizontalPadding)
        .padding(.vertical, SettingsControlChrome.verticalPadding)
        .background { SettingsControlChrome.fieldBackground }
        .overlay { SettingsControlChrome.fieldBorder }
    }
}

// MARK: - Font family

private struct FontFamilySettingsPicker: View {
    @Binding var mode: AppFontFamilyMode
    @Binding var customName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsIconDropdown(
                icon: mode.icon,
                title: mode.label
            ) {
                ForEach(AppFontFamilyMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        SettingsDropdownOption(
                            icon: option.icon,
                            title: option.label,
                            isSelected: mode == option
                        )
                    }
                }
            }

            if mode == .custom {
                TextField("PostScript or family name", text: $customName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, SettingsControlChrome.horizontalPadding)
                    .padding(.vertical, SettingsControlChrome.verticalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background { SettingsControlChrome.fieldBackground }
                    .overlay { SettingsControlChrome.fieldBorder }
            }
        }
    }
}

// MARK: - Dropdown chrome

private struct SettingsIconDropdown<MenuContent: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            SettingsDropdownLabel(icon: icon, title: title)
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsDropdownLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)

            Text(title)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, SettingsControlChrome.horizontalPadding)
        .padding(.vertical, SettingsControlChrome.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { SettingsControlChrome.fieldBackground }
        .overlay { SettingsControlChrome.fieldBorder }
        .contentShape(RoundedRectangle(cornerRadius: SettingsControlChrome.cornerRadius, style: .continuous))
    }
}

private struct SettingsDropdownOption: View {
    let icon: String
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 16)
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}
