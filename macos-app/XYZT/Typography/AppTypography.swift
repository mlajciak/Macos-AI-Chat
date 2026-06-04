import AppKit
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
            return .custom(name, size: size).weight(weight.systemWeight)
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
        let usesMedium = weight == .medium || weight == .semibold || weight == .bold
        return .custom(usesMedium ? mediumName : regularName, size: size)
    }

    private static func systemFont(size: CGFloat, weight: Weight) -> Font {
        .system(size: size, weight: weight.systemWeight)
    }

    enum Weight {
        case regular
        case medium
        case bold
        case semibold

        var systemWeight: Font.Weight {
            switch self {
            case .regular: .regular
            case .medium: .medium
            case .bold: .bold
            case .semibold: .semibold
            }
        }
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

enum AppFontRole {
    case body
    case caption
    case headline
}

extension AppFontSettings {
    /// SF Symbol scale aligned to caption/body roles.
    var iconPointSize: CGFloat { max(captionPointSize - 1, 9) }

    var smallIconPointSize: CGFloat { max(captionPointSize - 2, 8) }

    func pointSize(for role: AppFontRole) -> CGFloat {
        switch role {
        case .body: bodyPointSize
        case .caption: captionPointSize
        case .headline: headlinePointSize
        }
    }

    func font(for role: AppFontRole, weight: AppTypography.Weight = .regular) -> Font {
        font(size: pointSize(for: role), weight: weight)
    }

    func font(size: CGFloat, weight: AppTypography.Weight = .regular) -> Font {
        AppTypography.appFont(size: size, weight: weight, settings: self)
    }

    func nsFont(for role: AppFontRole, weight: AppTypography.Weight = .regular) -> NSFont {
        let size = pointSize(for: role)
        switch familyMode {
        case .system:
            return NSFont.systemFont(ofSize: size, weight: weight.nsWeight)
        case .mono:
            let name = weight.usesBundledMedium
                ? AppTypography.mediumName
                : AppTypography.regularName
            return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight.nsWeight)
        case .custom:
            let trimmed = customFamilyName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return NSFont.systemFont(ofSize: size, weight: weight.nsWeight)
            }
            if AppTypography.isBundledMonoFamily(trimmed) {
                let name = weight.usesBundledMedium
                    ? AppTypography.mediumName
                    : AppTypography.regularName
                return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
            }
            return NSFont(name: trimmed, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight.nsWeight)
        }
    }
}

extension AppTypography.Weight {
    var nsWeight: NSFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .bold: .bold
        case .semibold: .semibold
        }
    }

    var usesBundledMedium: Bool {
        self == .medium || self == .semibold || self == .bold
    }
}

enum ChatInputMetrics {
    static let minLineCount: CGFloat = 1
    static let maxLineCount: CGFloat = 4
    static let verticalInset: CGFloat = 4

    static func lineHeight(for settings: AppFontSettings) -> CGFloat {
        ceil(settings.nsFont(for: .body).ascender - settings.nsFont(for: .body).descender)
    }

    static func minHeight(for settings: AppFontSettings) -> CGFloat {
        lineHeight(for: settings) * minLineCount + verticalInset
    }

    static func maxHeight(for settings: AppFontSettings) -> CGFloat {
        lineHeight(for: settings) * maxLineCount + verticalInset
    }
}

private struct AppFontRoleModifier: ViewModifier {
    @Environment(\.appFontSettings) private var environmentSettings
    var settings: AppFontSettings?
    let role: AppFontRole
    let weight: AppTypography.Weight

    private var resolvedSettings: AppFontSettings {
        settings ?? environmentSettings
    }

    func body(content: Content) -> some View {
        content.font(resolvedSettings.font(for: role, weight: weight))
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
    func appFont(
        _ role: AppFontRole,
        weight: AppTypography.Weight = .regular,
        settings: AppFontSettings? = nil
    ) -> some View {
        modifier(AppFontRoleModifier(settings: settings, role: role, weight: weight))
    }

    /// Applies user font settings to SF Symbols (same family/size as text).
    func appIcon(
        _ role: AppFontRole = .caption,
        weight: AppTypography.Weight = .medium,
        settings: AppFontSettings? = nil
    ) -> some View {
        appFont(role, weight: weight, settings: settings)
    }

    func appMonoFont(_ size: CGFloat? = nil) -> some View {
        modifier(AppMonoFontModifier(size: size))
    }

    func appFontContext(_ settings: AppFontSettings) -> some View {
        environment(\.appFontSettings, settings)
    }

    func appFontEnvironment(_ preferences: AppPreferences) -> some View {
        appFontContext(preferences.fontSettings)
            .preferredColorScheme(preferences.theme.colorScheme)
    }
}
