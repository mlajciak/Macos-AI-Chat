import CoreText
import SwiftUI

enum AppTypography {
    static let regularName = "JetBrainsMono-Regular"
    static let mediumName = "JetBrainsMono-Medium"
    static let defaultFamilyName = "JetBrains Mono"

    static let bodySize: CGFloat = 13
    static let captionSize: CGFloat = 11
    static let headlineSize: CGFloat = 14

    static func registerFonts() {
        for resource in [regularName, mediumName] {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "ttf")
            else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func mono(size: CGFloat, weight: Weight = .regular) -> Font {
        appFont(size: size, weight: weight, settings: AppFontSettings(
            bodyPointSize: size,
            familyMode: .mono,
            customFamilyName: ""
        ))
    }

    static func appFont(size: CGFloat, weight: Weight = .regular, settings: AppFontSettings) -> Font {
        switch settings.familyMode {
        case .system:
            return systemFont(size: size, weight: weight)
        case .mono:
            return bundledMono(size: size, weight: weight)
        case .custom:
            let name = settings.customFamilyName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return systemFont(size: size, weight: weight)
            }
            if isBundledMonoFamily(name) {
                return bundledMono(size: size, weight: weight)
            }
            if weight == .medium {
                return .custom(name, size: size).weight(.medium)
            }
            return .custom(name, size: size)
        }
    }

    static func isBundledMonoFamily(_ name: String) -> Bool {
        let normalized = name.lowercased().replacingOccurrences(of: " ", with: "")
        return normalized == "jetbrainsmono"
            || normalized == regularName.lowercased()
            || normalized == mediumName.lowercased()
            || name == defaultFamilyName
    }

    private static func bundledMono(size: CGFloat, weight: Weight) -> Font {
        .custom(weight == .medium ? mediumName : regularName, size: size)
    }

    private static func systemFont(size: CGFloat, weight: Weight) -> Font {
        switch weight {
        case .regular:
            return .system(size: size)
        case .medium:
            return .system(size: size, weight: .medium)
        }
    }

    enum Weight {
        case regular
        case medium
    }
}

private struct AppFontSettingsKey: EnvironmentKey {
    static let defaultValue = AppFontSettings.default
}

extension EnvironmentValues {
    var appFontSettings: AppFontSettings {
        get { self[AppFontSettingsKey.self] }
        set { self[AppFontSettingsKey.self] = newValue }
    }
}

extension AppFontSettings {
    func font(size: CGFloat, weight: AppTypography.Weight = .regular) -> Font {
        AppTypography.appFont(size: size, weight: weight, settings: self)
    }
}

private struct AppMonoFontModifier: ViewModifier {
    @Environment(\.appFontSettings) private var appFontSettings
    var size: CGFloat?

    func body(content: Content) -> some View {
        content.font(
            appFontSettings.font(size: size ?? appFontSettings.bodyPointSize)
        )
    }
}

extension View {
    func appMonoFont(_ size: CGFloat? = nil) -> some View {
        modifier(AppMonoFontModifier(size: size))
    }

    func appFontEnvironment(_ preferences: AppPreferences) -> some View {
        self
            .environment(\.appFontSettings, preferences.fontSettings)
            .preferredColorScheme(preferences.theme.colorScheme)
    }
}
