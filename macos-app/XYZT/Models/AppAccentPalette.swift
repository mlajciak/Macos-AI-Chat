import SwiftUI

/// Semantic chrome colors derived from system accent and label colors.
struct AppThemeColors: Equatable {
    static let `default` = AppThemeColors()

    var accent: Color { .accentColor }
    var fieldFill: Color { Color.primary.opacity(0.06) }
    var fieldStroke: Color { Color.primary.opacity(0.1) }
    var hoverFill: Color { Color.primary.opacity(0.07) }
    var subtleFill: Color { Color.primary.opacity(0.05) }
    var mutedRowFill: Color { Color.primary.opacity(0.06) }
    var panelFill: Color { Color.primary.opacity(0.08) }
    var overlayStroke: Color { Color.primary.opacity(0.12) }
    var menuStroke: Color { Color.primary.opacity(0.1) }
    var divider: Color { Color.primary.opacity(0.12) }
    var primaryText: Color { .primary }
    var secondary: Color { .secondary }
    var secondaryMuted: Color { Color.secondary.opacity(0.65) }
    var tertiary: Color { Color.secondary.opacity(0.45) }
    var codeBlockFill: Color { Color.primary.opacity(0.06) }
    var codeBlockFillSecondary: Color { Color.primary.opacity(0.04) }
    var accentMuted: Color { accent.opacity(0.12) }
    var accentSelectionFill: Color { accent.opacity(0.18) }
    var accentSelectionStroke: Color { accent.opacity(0.45) }
    var chromeHighlight: Color { Color.white.opacity(0.14) }
    var chromeHighlightHover: Color { Color.white.opacity(0.2) }

    func neutral(_ opacity: Double) -> Color {
        Color.primary.opacity(opacity)
    }
}

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue = Color.accentColor
}

private struct AppThemeColorsKey: EnvironmentKey {
    static let defaultValue = AppThemeColors.default
}

extension EnvironmentValues {
    var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }

    var appThemeColors: AppThemeColors {
        get { self[AppThemeColorsKey.self] }
        set { self[AppThemeColorsKey.self] = newValue }
    }
}

extension View {
    func appAccentEnvironment(_ preferences: AppPreferences) -> some View {
        let theme = AppThemeColors.default
        return appFontEnvironment(preferences)
            .environment(\.appAccentColor, theme.accent)
            .environment(\.appThemeColors, theme)
            .tint(theme.accent)
    }
}
